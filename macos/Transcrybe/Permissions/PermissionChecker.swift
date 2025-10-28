//
//  PermissionChecker.swift
//  Transcrybe
//
//  Centralized permission checking utilities
//

import Foundation
import ApplicationServices
import Cocoa
import AVFoundation

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
