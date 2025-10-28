//
//  HotKeyManager.swift
//  Transcrybe
//
//  Manages custom hotkey configuration and persistence
//

import Foundation
import Combine
import os
import Cocoa

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
