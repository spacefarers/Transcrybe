//
//  State.swift
//  Transcryb
//
//  State management: permissions, hotkey, startup, and UI state managers
//

import Foundation
import AVFoundation
import Combine
import os
import Cocoa
import ApplicationServices
import ServiceManagement
import AppKit

// MARK: - Permission Checking Utilities

struct PermissionChecker {
    /// Check if accessibility is trusted
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility trust (triggers system prompt)
    static func requestAccessibilityTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Check current microphone authorization status
    static func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Request microphone access (triggers system prompt if needed)
    static func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Open accessibility settings in System Settings
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open microphone settings in System Settings
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Polling

class PermissionPoller {
    /// Poll for accessibility trust with configurable attempts and interval
    static func pollAccessibilityTrust(
        maxAttempts: Int = 60,
        interval: TimeInterval = 0.5,
        completion: @escaping (Bool) -> Void
    ) {
        var attempts = 0

        // Use a recursive DispatchQueue.main.asyncAfter loop instead of a Timer.
        // This is more resilient to run loop mode changes when modal system
        // prompts (like the Accessibility permission dialog) are active.
        func check() {
            let trusted = PermissionChecker.isAccessibilityTrusted()
            attempts += 1

            // If trusted, complete successfully
            if trusted {
                DispatchQueue.main.async {
                    completion(true)
                }
                return
            }

            // If max attempts reached, fail
            if attempts >= maxAttempts {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            // Otherwise, schedule the next check
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                check()
            }
        }

        // Start the first check
        check()
    }
}

// MARK: - Permission Manager

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
        PermissionChecker.microphoneAuthorizationStatus() == .authorized
    }

    private func requestMicrophonePermissionFlow(completion: @escaping () -> Void) {
        logger.info("Step 1/2: Requesting Microphone permission via system prompt...")

        PermissionChecker.requestMicrophoneAccess { [weak self] granted in
            guard let self = self else { return }

            if granted {
                self.logger.info("✓ Microphone permission granted")
                self.hasMicrophonePermission = true
                self.currentPermissionStep += 1
                self.requestNextPermission(completion: completion)
            } else {
                self.logger.error("✗ Microphone permission denied")
                self.showPermissionDeniedAlert(for: "Microphone")
            }
        }
    }

    // MARK: - Accessibility Permission

    private func requestAccessibilityPermissionFlow(completion: @escaping () -> Void) {
        logger.info("Step 2/2: Requesting Accessibility permission via system prompt...")

        PermissionChecker.requestAccessibilityTrust()

        // Poll for accessibility trust
        PermissionPoller.pollAccessibilityTrust { [weak self] trusted in
            guard let self = self else { return }

            if trusted {
                self.logger.info("✓ Accessibility permission granted")
                self.hasAccessibilityPermission = true
                self.currentPermissionStep += 1
                self.requestNextPermission(completion: completion)
            } else {
                self.logger.error("✗ Accessibility permission denied")
                self.showPermissionDeniedAlert(for: "Accessibility")
            }
        }
    }

    // MARK: - Alert Management

    private func showPermissionDeniedAlert(for permission: String) {
        let alert = NSAlert()
        alert.messageText = "Permission Not Granted"
        alert.informativeText = "\(permission) permission was not granted. Transcryb cannot function without this permission.\n\nPlease grant \(permission) access in System Settings, then relaunch Transcryb."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")

        alert.runModal()
        if permission == "Microphone" {
            PermissionChecker.openMicrophoneSettings()
        } else if permission == "Accessibility" {
            PermissionChecker.openAccessibilitySettings()
        }
        quitApp()
    }

    private func quitApp() {
        logger.info("Quitting app due to permission requirements")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - Hot Key Manager

class HotKeyManager: NSObject, ObservableObject {
    /// Hotkey is fixed to the Function key only
    private let activationModifiers: NSEvent.ModifierFlags = .function
    private let activationKeyCode: UInt16 = 0 // 0 = modifier-only

    private let logger = Logger(subsystem: "com.transcryb.hotkey", category: "manager")

    override init() {
        super.init()
        logger.info("HotKeyManager initialized - Using Function key as activation hotkey")
    }

    // MARK: - Hotkey Detection

    /// Check if the current event flags match the Function key activation
    func isHotKeyPressed(flags: NSEvent.ModifierFlags, keyCode: UInt16?) -> Bool {
        // Only check if Function modifier is pressed (we ignore keyCode since it's modifier-only)
        return activationModifiers.isSubset(of: flags)
    }
}

// MARK: - Launch On Startup Manager

class LaunchOnStartupManager: NSObject, ObservableObject {
    @Published var isEnabled = false

    private let logger = Logger(subsystem: "com.transcryb.launch", category: "manager")
    private let userDefaults = UserDefaults.standard
    private let launchOnStartupKey = "LaunchOnStartup"
    private let appIdentifier = "com.transcryb.Transcryb"

    override init() {
        super.init()
        loadLaunchOnStartupSetting()
    }

    private func loadLaunchOnStartupSetting() {
        isEnabled = userDefaults.bool(forKey: launchOnStartupKey)
        logger.info("Loaded launch on startup setting: \(self.isEnabled)")
    }

    func setLaunchOnStartup(_ enabled: Bool) {
        do {
            if enabled {
                // Register app to launch on startup
                try SMAppService.mainApp.register()
                userDefaults.setValue(true, forKey: launchOnStartupKey)
                logger.info("✓ App registered to launch on startup")
            } else {
                // Unregister app from launch on startup
                try SMAppService.mainApp.unregister()
                userDefaults.setValue(false, forKey: launchOnStartupKey)
                logger.info("✓ App unregistered from launch on startup")
            }

            DispatchQueue.main.async {
                self.isEnabled = enabled
            }
        } catch {
            logger.error("Failed to update launch on startup: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isEnabled = !enabled  // Revert on failure
            }
        }
    }
}

// MARK: - Indicator Window Manager

class IndicatorWindowManager: ObservableObject {
    @Published private(set) var isWindowVisible = false

    func updateWindowVisibility(_ shouldBeVisible: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if shouldBeVisible {
                self.showWindowIfAvailable()
            } else {
                self.hideWindowIfNeeded()
            }
        }
    }

    private func showWindowIfAvailable() {
        guard let window = indicatorWindow else { return }

        configure(window)
        resizeToFitContent(window)
        position(window)

        window.alphaValue = 1.0
        window.orderFrontRegardless()
        isWindowVisible = true
    }

    private func hideWindowIfNeeded() {
        guard let window = indicatorWindow else { return }

        window.orderOut(nil)
        isWindowVisible = false
    }

    private var indicatorWindow: NSWindow? {
        NSApplication.shared.windows.first(where: { $0.title == "Recording Indicator" })
    }

    private func configure(_ window: NSWindow) {
        // Make window truly chrome-less and transparent
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Disable interaction and window management
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = true
        window.isExcludedFromWindowsMenu = true

        // Window level and behavior
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Hide standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.invalidateShadow()
    }

    private func resizeToFitContent(_ window: NSWindow) {
        guard let contentView = window.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize

        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        window.setContentSize(fittingSize)
        window.contentMinSize = fittingSize
        window.contentMaxSize = fittingSize
    }

    private func position(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        let windowFrame = window.frame
        let xOrigin = screen.visibleFrame.midX - (windowFrame.width / 2)
        let yOffset: CGFloat = 52 // distance from bottom of the screen
        let yOrigin = screen.visibleFrame.minY + yOffset

        window.setFrameOrigin(NSPoint(x: xOrigin, y: yOrigin))
    }
}
