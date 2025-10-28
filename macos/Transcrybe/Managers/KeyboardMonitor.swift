//
//  KeyboardMonitor.swift
//  Transcrybe
//
//  Monitors Function key presses globally via CGEvent tap
//

import Cocoa
import Combine
import os

class KeyboardMonitor: NSObject, ObservableObject {
    @Published var isFunctionPressed = false

    private let logger = Logger(subsystem: "com.transcryb.keyboard", category: "monitor")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var hotKeyManager: HotKeyManager?
    private var currentModifiers: NSEvent.ModifierFlags = []

    override init() {
        super.init()
        setupEventTap()
    }

    /// Set the hotkey manager to use for custom hotkey detection
    func setHotKeyManager(_ manager: HotKeyManager) {
        self.hotKeyManager = manager
    }

    /// Reinitialize the event tap (useful when permissions change)
    func reinitialize() {
        logger.info("Reinitializing keyboard monitor...")
        setupEventTap()
    }

    private func setupEventTap() {
        // Remove existing tap if any
        teardownEventTap()

        let mask =
            (CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.keyUp.rawValue))

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let `self` = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                self.handle(event: event, type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            logger.error("Failed to create CGEvent tap. Ensure Accessibility permission is granted.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)

        logger.info("✓ CGEvent tap successfully installed for Function key detection")
    }

    private func teardownEventTap() {
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
        let modifiers = modifierFlags(from: event.flags)
        currentModifiers = modifiers

        let keyCode: UInt16?
        if type == .keyDown || type == .keyUp {
            keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        } else {
            keyCode = nil
        }

        let hotKeyPressed = evaluateHotKey(type: type, modifiers: modifiers, keyCode: keyCode)

        if hotKeyPressed != isFunctionPressed {
            DispatchQueue.main.async { [weak self] in
                self?.isFunctionPressed = hotKeyPressed
                self?.logger.info("Hotkey \(hotKeyPressed ? "PRESSED" : "RELEASED")")
            }
        }
    }

    private func modifierFlags(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var nsFlags: NSEvent.ModifierFlags = []

        if flags.contains(.maskCommand) {
            nsFlags.insert(.command)
        }
        if flags.contains(.maskAlternate) {
            nsFlags.insert(.option)
        }
        if flags.contains(.maskShift) {
            nsFlags.insert(.shift)
        }
        if flags.contains(.maskControl) {
            nsFlags.insert(.control)
        }
        if flags.contains(.maskSecondaryFn) {
            nsFlags.insert(.function)
        }

        return nsFlags
    }

    private func evaluateHotKey(type: CGEventType, modifiers: NSEvent.ModifierFlags, keyCode: UInt16?) -> Bool {
        guard let hotKeyManager = hotKeyManager else {
            return modifiers.contains(.function)
        }

        let recordedKeyCode = hotKeyManager.recordedKeyCode
        let recordedModifiers = hotKeyManager.recordedModifiers

        if recordedKeyCode == 0 {
            return hotKeyManager.isHotKeyPressed(flags: modifiers, keyCode: nil)
        }

        switch type {
        case .keyDown:
            guard let keyCode = keyCode else { return false }
            return hotKeyManager.isHotKeyPressed(flags: modifiers, keyCode: keyCode)

        case .keyUp:
            guard let keyCode = keyCode else { return false }
            if keyCode == recordedKeyCode {
                return false
            }
            // Key up for a different key – maintain state if modifiers still held
            return isFunctionPressed && recordedModifiers.isSubset(of: modifiers)

        case .flagsChanged:
            if !recordedModifiers.isSubset(of: modifiers) {
                return false
            }
            return isFunctionPressed

        default:
            return isFunctionPressed
        }
    }

    deinit {
        teardownEventTap()
        logger.info("Keyboard monitor deinitialized")
    }
}
