//
//  PermissionManager.swift
//  Transcrybe
//
//  Unified permission management - checks, requests, and orchestrates permission flow
//

import AVFoundation
import Combine
import os
import Cocoa
import ApplicationServices

class PermissionManager: NSObject, ObservableObject {
    @Published var hasMicrophonePermission = false
    @Published var hasAccessibilityPermission = false
    @Published var isPermissionFlowComplete = false
    @Published var currentPermissionStep = 0

    private let logger = Logger(subsystem: "com.transcryb.permissions", category: "manager")

    // Permission steps for flow orchestration
    private enum PermissionStep: Int {
        case microphone = 0
        case accessibility = 1
        case complete = 2
    }

    override init() {
        super.init()
        logger.info("PermissionManager initialized")

        // Check if permissions are already granted from a previous session
        if areAllPermissionsGranted() {
            logger.info("✓ All permissions already granted from previous session")
            hasMicrophonePermission = true
            hasAccessibilityPermission = true
            isPermissionFlowComplete = true
        }
    }

    // MARK: - Permission Flow Orchestration

    /// Start the sequential permission request flow
    func startPermissionFlow(completion: @escaping () -> Void = {}) {
        logger.info("Checking permissions...")

        // Check if all permissions are already granted
        if areAllPermissionsGranted() {
            logger.info("✓ All permissions already granted, skipping permission flow")
            isPermissionFlowComplete = true
            completion()
            return
        }

        logger.info("Starting permission flow...")
        currentPermissionStep = 0
        requestNextPermission(completion: completion)
    }

    private func areAllPermissionsGranted() -> Bool {
        let microphoneGranted = checkMicrophonePermissionSync()
        let accessibilityGranted = PermissionChecker.isAccessibilityTrusted()

        logger.info("Permission status - Microphone: \(microphoneGranted), Accessibility: \(accessibilityGranted)")

        return microphoneGranted && accessibilityGranted
    }

    private func requestNextPermission(completion: @escaping () -> Void = {}) {
        let step = PermissionStep(rawValue: currentPermissionStep)

        switch step {
        case .microphone:
            if hasMicrophonePermission {
                logger.info("✓ Microphone permission already granted, skipping")
                currentPermissionStep += 1
                requestNextPermission(completion: completion)
            } else {
                requestMicrophonePermissionFlow(completion: completion)
            }

        case .accessibility:
            if PermissionChecker.isAccessibilityTrusted() {
                logger.info("✓ Accessibility permission already granted, skipping")
                hasMicrophonePermission = checkMicrophonePermissionSync()
                hasAccessibilityPermission = PermissionChecker.isAccessibilityTrusted()
                currentPermissionStep += 1
                requestNextPermission(completion: completion)
            } else {
                requestAccessibilityPermissionFlow(completion: completion)
            }

        case .complete:
            logger.info("✓ All permissions granted!")
            hasMicrophonePermission = checkMicrophonePermissionSync()
            hasAccessibilityPermission = PermissionChecker.isAccessibilityTrusted()
            isPermissionFlowComplete = true
            completion()

        case .none:
            logger.error("Unknown permission step")
            quitApp()
        }
    }

    // MARK: - Microphone Permission

    private func checkMicrophonePermissionSync() -> Bool {
        PermissionChecker.testMicrophoneAccess { _ in }
        // Note: synchronous check for initialization
        var result = false
        PermissionChecker.testMicrophoneAccess { granted in
            result = granted
        }
        // Give it a moment to complete
        Thread.sleep(forTimeInterval: 0.1)
        return result
    }

    private func requestMicrophonePermissionFlow(completion: @escaping () -> Void) {
        logger.info("Step 1/2: Requesting Microphone permission...")

        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "Transcrybe needs access to your microphone to record audio for transcription.\n\nClick 'Grant' to enable microphone access in System Settings, or 'Quit' to exit the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Grant")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            PermissionChecker.openMicrophoneSettings()
            PermissionChecker.testMicrophoneAccess { [weak self] granted in
                if granted {
                    self?.logger.info("✓ Microphone permission granted")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.currentPermissionStep += 1
                        self?.requestNextPermission(completion: completion)
                    }
                } else {
                    self?.logger.error("✗ Microphone permission denied")
                    self?.showPermissionDeniedAlert(for: "Microphone")
                }
            }
        } else {
            logger.info("User chose to quit during microphone permission request")
            quitApp()
        }
    }

    // MARK: - Accessibility Permission

    private func requestAccessibilityPermissionFlow(completion: @escaping () -> Void) {
        logger.info("Step 2/2: Requesting Accessibility permission...")

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Transcrybe needs accessibility permission to monitor the Function key globally and insert transcribed text at the cursor automatically.\n\nClick 'Grant' to enable accessibility access in System Settings, or 'Quit' to exit the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Grant")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            PermissionChecker.requestAccessibilityTrust()
            PermissionChecker.openAccessibilitySettings()

            // Poll for accessibility trust
            PermissionPoller.pollAccessibilityTrust { [weak self] trusted in
                if trusted {
                    self?.logger.info("✓ Accessibility permission granted")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.currentPermissionStep += 1
                        self?.requestNextPermission(completion: completion)
                    }
                } else {
                    self?.logger.error("✗ Accessibility permission denied")
                    self?.showPermissionDeniedAlert(for: "Accessibility")
                }
            }
        } else {
            logger.info("User chose to quit during accessibility permission request")
            quitApp()
        }
    }

    // MARK: - Alert Management

    private func showPermissionDeniedAlert(for permission: String) {
        let alert = NSAlert()
        alert.messageText = "Permission Not Granted"
        alert.informativeText = "\(permission) permission was not granted. Transcrybe cannot function without this permission.\n\nThe app will now quit."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")

        alert.runModal()
        quitApp()
    }

    private func quitApp() {
        logger.info("Quitting app due to permission requirements")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }
}
