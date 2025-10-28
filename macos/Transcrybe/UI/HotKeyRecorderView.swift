//
//  HotKeyRecorderView.swift
//  Transcrybe
//
//  Allows users to record custom hotkeys by pressing keys
//

import SwiftUI
import Cocoa

struct HotKeyRecorderView: View {
    @ObservedObject var hotKeyManager: HotKeyManager
    @State private var isRecording = false
    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var lastNonEmptyModifiers: NSEvent.ModifierFlags = []
    @State private var currentKeyCode: UInt16?
    @State private var recordingDisplay: String?
    @State private var recordingMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hotkey", systemImage: "keyboard.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Click the input box and then press your desired key combination")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Hotkey input box
            HStack(spacing: 8) {
                VStack(alignment: .leading) {
                    Text("Current hotkey:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: startRecording) {
                        HStack(spacing: 8) {
                            Image(systemName: isRecording ? "record.circle.fill" : "waveform.circle")
                                .foregroundStyle(isRecording ? .red : .primary)

                            Text(isRecording ? (recordingDisplay ?? "Recording... Press keys") : hotKeyManager.recordedKeyDisplay)
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(minWidth: 120, alignment: .leading)

                            Spacer()

                            if isRecording {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isRecording ? Color.red.opacity(0.1) : Color(.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Reset button
            Button(action: {
                hotKeyManager.resetToDefault()
                isRecording = false
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Default (fn)")
                }
                .font(.caption)
                .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
    }

    private func startRecording() {
        if isRecording {
            stopRecordingSession()
        } else {
            beginRecordingSession()
        }
    }

    private func beginRecordingSession() {
        currentModifiers = []
        lastNonEmptyModifiers = []
        currentKeyCode = nil
        recordingDisplay = nil
        isRecording = true
        setupGlobalEventMonitor()
    }

    private func stopRecordingSession() {
        isRecording = false
        recordingDisplay = nil
        currentModifiers = []
        lastNonEmptyModifiers = []
        currentKeyCode = nil
        teardownEventMonitor()
    }

    private func setupGlobalEventMonitor() {
        // Use global event monitor that captures ALL keyboard events, even when app is in background
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            self.handleKeyEvent(event)
        }

        recordingMonitor = monitor
    }

    private func teardownEventMonitor() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        let normalizedModifiers = normalizedModifiers(from: event.modifierFlags)

        switch event.type {
        case .flagsChanged:
            DispatchQueue.main.async {
                self.handleModifierChange(normalizedModifiers)
            }

        case .keyDown:
            let keyCode = event.keyCode
            let characters = event.charactersIgnoringModifiers
            let specialKey = event.specialKey

            DispatchQueue.main.async {
                self.handleKeyDown(modifiers: normalizedModifiers, keyCode: keyCode, characters: characters, specialKey: specialKey)
            }

        default:
            break
        }
    }

    private func handleModifierChange(_ newModifiers: NSEvent.ModifierFlags) {
        let previousModifiers = currentModifiers
        currentModifiers = newModifiers

        if !newModifiers.isEmpty {
            if countModifierFlags(newModifiers) >= countModifierFlags(previousModifiers) {
                lastNonEmptyModifiers = newModifiers
            }
            recordingDisplay = formatHotKey(modifiers: newModifiers, keyCode: currentKeyCode, characters: nil, specialKey: nil)
            return
        }

        // Modifiers cleared while recording
        if currentKeyCode == nil, !lastNonEmptyModifiers.isEmpty {
            let display = formatHotKey(modifiers: lastNonEmptyModifiers, keyCode: nil, characters: nil, specialKey: nil)
            recordingDisplay = display
            hotKeyManager.saveHotKey(modifiers: lastNonEmptyModifiers, keyCode: 0, display: display)
            stopRecordingSession()
        } else {
            recordingDisplay = nil
        }
    }

    private func handleKeyDown(
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16,
        characters: String?,
        specialKey: NSEvent.SpecialKey?
    ) {
        currentModifiers = modifiers
        lastNonEmptyModifiers = modifiers
        currentKeyCode = keyCode

        let display = formatHotKey(modifiers: modifiers, keyCode: keyCode, characters: characters, specialKey: specialKey)
        recordingDisplay = display
        hotKeyManager.saveHotKey(modifiers: modifiers, keyCode: keyCode, display: display)
        stopRecordingSession()
    }

    private func normalizedModifiers(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        let relevant: NSEvent.ModifierFlags = [.command, .option, .shift, .control, .function]
        return flags.intersection(relevant)
    }

    private func countModifierFlags(_ flags: NSEvent.ModifierFlags) -> Int {
        var count = 0
        if flags.contains(.command) { count += 1 }
        if flags.contains(.option) { count += 1 }
        if flags.contains(.shift) { count += 1 }
        if flags.contains(.control) { count += 1 }
        if flags.contains(.function) { count += 1 }
        return count
    }

    private func formatHotKey(
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16?,
        characters: String?,
        specialKey: NSEvent.SpecialKey?
    ) -> String {
        var parts: [String] = []

        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.function) {
            parts.append("fn")
        }

        if let keyCode = keyCode {
            let keyName = displayName(for: keyCode, characters: characters, specialKey: specialKey)
            if !keyName.isEmpty {
                parts.append(keyName)
            }
        }

        if parts.isEmpty {
            return "None"
        }

        return parts.joined(separator: " ")
    }

    private func displayName(for keyCode: UInt16, characters: String?, specialKey: NSEvent.SpecialKey?) -> String {
        if let specialKey = specialKey {
            switch specialKey {
            case .carriageReturn:
                return "Return"
            case .tab:
                return "Tab"
            case .delete:
                return "Delete"
            case .home:
                return "Home"
            case .end:
                return "End"
            case .pageUp:
                return "Page Up"
            case .pageDown:
                return "Page Down"
            case .leftArrow:
                return "←"
            case .rightArrow:
                return "→"
            case .upArrow:
                return "↑"
            case .downArrow:
                return "↓"
            case .f1:
                return "F1"
            case .f2:
                return "F2"
            case .f3:
                return "F3"
            case .f4:
                return "F4"
            case .f5:
                return "F5"
            case .f6:
                return "F6"
            case .f7:
                return "F7"
            case .f8:
                return "F8"
            case .f9:
                return "F9"
            case .f10:
                return "F10"
            case .f11:
                return "F11"
            case .f12:
                return "F12"
            default:
                break
            }
        }

        // Handle common keys by keyCode
        switch keyCode {
        case 49:  // Space
            return "Space"
        case 53:  // Escape
            return "Esc"
        case 51:  // Forward Delete
            return "Forward Delete"
        default:
            break
        }

        if let characters = characters?.trimmingCharacters(in: .whitespacesAndNewlines), !characters.isEmpty {
            if characters.count == 1 {
                return characters.uppercased()
            } else {
                return characters.uppercased()
            }
        }

        // Fallback to key code representation
        return "Key \(keyCode)"
    }
}

#Preview {
    HotKeyRecorderView(hotKeyManager: HotKeyManager())
        .padding()
}
