//
//  State.swift
//  Transcrybe
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

    /// Test if microphone is accessible
    static func testMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mic_test_\(UUID().uuidString).wav")
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            _ = try AVAudioRecorder(url: tempURL, settings: audioSettings)
            completion(true)
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            completion(false)
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
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            attempts += 1
            let trusted = PermissionChecker.isAccessibilityTrusted()
            if trusted || attempts >= maxAttempts {
                timer.invalidate()
                DispatchQueue.main.async {
                    completion(trusted)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
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

// MARK: - Hot Key Manager

class HotKeyManager: NSObject, ObservableObject {
    @Published var recordedModifiers: NSEvent.ModifierFlags = .function
    @Published var recordedKeyCode: UInt16 = 0
    @Published var recordedKeyDisplay: String = "fn"

    private let logger = Logger(subsystem: "com.transcryb.hotkey", category: "manager")
    private let userDefaults = UserDefaults.standard
    private let hotkeyModifiersKey = "HotKeyModifiers"
    private let hotkeyKeyCodeKey = "HotKeyKeyCode"
    private let hotkeyDisplayKey = "HotKeyDisplay"

    override init() {
        super.init()
        loadHotKeyFromDefaults()
    }

    // MARK: - Persistence

    private func loadHotKeyFromDefaults() {
        if let savedModifiers = userDefaults.value(forKey: hotkeyModifiersKey) as? UInt {
            recordedModifiers = NSEvent.ModifierFlags(rawValue: savedModifiers)
        }

        if let savedKeyCode = userDefaults.value(forKey: hotkeyKeyCodeKey) as? Int {
            recordedKeyCode = UInt16(savedKeyCode)
        } else {
            recordedKeyCode = 0
        }

        if let savedDisplay = userDefaults.string(forKey: hotkeyDisplayKey) {
            recordedKeyDisplay = savedDisplay
        }

        logger.info("Loaded hotkey from defaults: \(self.recordedKeyDisplay)")
    }

    func saveHotKey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, display: String) {
        self.recordedModifiers = modifiers
        self.recordedKeyCode = keyCode
        self.recordedKeyDisplay = display

        userDefaults.setValue(modifiers.rawValue, forKey: hotkeyModifiersKey)
        userDefaults.setValue(Int(keyCode), forKey: hotkeyKeyCodeKey)
        userDefaults.setValue(display, forKey: hotkeyDisplayKey)

        logger.info("Saved hotkey: \(display)")
    }

    // MARK: - Hotkey Detection

    /// Check if the current event flags match the configured hotkey (for keyboard tap)
    func isHotKeyPressed(flags: NSEvent.ModifierFlags, keyCode: UInt16?) -> Bool {
        if recordedKeyCode == 0 {
            // Modifier-only hotkey (e.g., Function key)
            return recordedModifiers.isSubset(of: flags)
        }

        guard let keyCode = keyCode else {
            return false
        }

        return keyCode == recordedKeyCode && recordedModifiers.isSubset(of: flags)
    }

    func resetToDefault() {
        saveHotKey(modifiers: .function, keyCode: 0, display: "fn")
        logger.info("Reset hotkey to default (Function)")
    }
}

// MARK: - HotKey Recording Controller

final class HotKeyRecordingController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var onUpdate: ((NSEvent.ModifierFlags, UInt16?, String?, NSEvent.SpecialKey?) -> Void)?
    private var onCommit: ((NSEvent.ModifierFlags, UInt16?, String?, NSEvent.SpecialKey?) -> Void)?

    func begin(
        onUpdate: @escaping (NSEvent.ModifierFlags, UInt16?, String?, NSEvent.SpecialKey?) -> Void,
        onCommit: @escaping (NSEvent.ModifierFlags, UInt16?, String?, NSEvent.SpecialKey?) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onCommit = onCommit

        teardown()

        let mask =
            (CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.keyUp.rawValue))

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let selfRef = Unmanaged<HotKeyRecordingController>.fromOpaque(userInfo).takeUnretainedValue()
                selfRef.handle(event: event, type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func end() {
        teardown()
        onUpdate = nil
        onCommit = nil
    }

    private func teardown() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(event: CGEvent, type: CGEventType) {
        // Build NSEvent-like flags set from CGEventFlags, including Function
        var flags: NSEvent.ModifierFlags = []
        let cg = event.flags
        if cg.contains(.maskCommand) { flags.insert(.command) }
        if cg.contains(.maskAlternate) { flags.insert(.option) }
        if cg.contains(.maskShift) { flags.insert(.shift) }
        if cg.contains(.maskControl) { flags.insert(.control) }
        if cg.contains(.maskSecondaryFn) { flags.insert(.function) }

        let keyCode: UInt16? = (type == .keyDown || type == .keyUp)
            ? UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            : nil

        // Try to infer characters and a specialKey for display
        var chars: String?
        var specialKey: NSEvent.SpecialKey?
        if let nsEvent = NSEvent(cgEvent: event) {
            chars = nsEvent.charactersIgnoringModifiers
            specialKey = nsEvent.specialKey
        }

        switch type {
        case .keyDown:
            onUpdate?(flags, keyCode, chars, specialKey)
            onCommit?(flags, keyCode, chars, specialKey)   // commit on first keyDown
        case .flagsChanged:
            onUpdate?(flags, nil, nil, nil)
            // If user releases all modifiers without typing a key, commit a modifier-only hotkey
            if flags.isEmpty {
                onCommit?(flags, nil, nil, nil)
            }
        default:
            break
        }
    }
}

// MARK: - Launch On Startup Manager

class LaunchOnStartupManager: NSObject, ObservableObject {
    @Published var isEnabled = false

    private let logger = Logger(subsystem: "com.transcryb.launch", category: "manager")
    private let userDefaults = UserDefaults.standard
    private let launchOnStartupKey = "LaunchOnStartup"
    private let appIdentifier = "com.transcryb.Transcrybe"

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
        window.orderFront(nil)
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
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isExcludedFromWindowsMenu = true
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        window.styleMask.remove(.resizable)
        window.styleMask.remove(.miniaturizable)
        window.styleMask.remove(.closable)
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
