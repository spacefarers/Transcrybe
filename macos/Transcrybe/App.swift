//
//  App.swift
//  Transcrybe
//
//  Entry point and main application orchestration
//

import SwiftUI
import AVFoundation
import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    static let settingsWindowOpenedNotification = NSNotification.Name("settingsWindowOpened")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as accessory app (invisible in Command+Tab)
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class SettingsWindowManager: ObservableObject {
    @Published var shouldShowSettings = false
    private var settingsWindowID: Int?

    func focusSettingsWindowIfOpen() -> Bool {
        // Search for settings window: look for a window that's either visible or recently created
        // Exclude the menu bar and the main window
        let potentialWindows = NSApplication.shared.windows.filter { window in
            window.isVisible &&
            !window.title.isEmpty &&
            window != NSApplication.shared.mainWindow &&
            window.level != .mainMenu
        }

        if let settingsWindow = potentialWindows.first {
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindowID = settingsWindow.windowNumber
            NSApp.activate(ignoringOtherApps: true)
            return true
        }
        return false
    }

    func settingsWindowExists() -> Bool {
        // Check if the settings window still exists
        if let windowID = settingsWindowID {
            return NSApplication.shared.windows.contains { $0.windowNumber == windowID }
        }
        return false
    }

    func recordSettingsWindowID(_ windowNumber: Int) {
        settingsWindowID = windowNumber
    }

    func clearSettingsWindowID() {
        settingsWindowID = nil
    }
}

@main
struct TranscrybeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var indicatorWindowManager = IndicatorWindowManager()
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    @StateObject private var accessibilityManager = AccessibilityManager()
    @StateObject private var settingsWindowManager = SettingsWindowManager()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var hotKeyManager = HotKeyManager()
    @StateObject private var launchOnStartupManager = LaunchOnStartupManager()
    @State private var didActuallyStartRecording = false
    @State private var isFirstLaunch = true
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Singleton Settings scene - platform handles window management
        Settings {
            AppRootView(
                permissionManager: permissionManager,
                audioRecorder: audioRecorder,
                transcriptionService: transcriptionService,
                keyboardMonitor: keyboardMonitor,
                settingsWindowManager: settingsWindowManager,
                modelManager: modelManager,
                hotKeyManager: hotKeyManager,
                launchOnStartupManager: launchOnStartupManager,
                isFirstLaunch: $isFirstLaunch
            )
                .environmentObject(audioRecorder)
                .environmentObject(transcriptionService)
                .environmentObject(keyboardMonitor)
                .frame(minWidth: 500, minHeight: 600)
        }

        // Menu bar item
        MenuBarExtra("Transcrybe", systemImage: "microphone.fill") {
            VStack(spacing: 8) {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    // Find and focus settings window, or trigger keyboard shortcut to create it
                    if let settingsWindow = NSApplication.shared.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
                        settingsWindow.makeKeyAndOrderFront(nil)
                    } else {
                        // Trigger the keyboard shortcut to open Settings
                        let event = NSEvent.keyEvent(
                            with: .keyDown,
                            location: .zero,
                            modifierFlags: [.command],
                            timestamp: Date().timeIntervalSince1970,
                            windowNumber: 0,
                            context: nil,
                            characters: ",",
                            charactersIgnoringModifiers: ",",
                            isARepeat: false,
                            keyCode: 43
                        )
                        NSApplication.shared.sendEvent(event!)
                    }
                }) {
                    Label("Settings", systemImage: "gear")
                }

                Divider()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit Transcrybe", systemImage: "power")
                }
            }
            .padding(8)
            .onAppear {
                // Open settings window on first launch (menu bar is always visible on app launch)
                if isFirstLaunch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Trigger the keyboard shortcut to open Settings
                        let event = NSEvent.keyEvent(
                            with: .keyDown,
                            location: .zero,
                            modifierFlags: [.command],
                            timestamp: Date().timeIntervalSince1970,
                            windowNumber: 0,
                            context: nil,
                            characters: ",",
                            charactersIgnoringModifiers: ",",
                            isARepeat: false,
                            keyCode: 43
                        )
                        NSApplication.shared.sendEvent(event!)
                    }
                }
            }
        }

        // Floating recording indicator window
        Window("Recording Indicator", id: "recording-indicator") {
            RecordingIndicatorWindowContent(
                audioRecorder: audioRecorder,
                transcriptionService: transcriptionService,
                permissionManager: permissionManager,
                windowManager: indicatorWindowManager
            )
            .frame(width: 80, height: 80)
            .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottom)
        .onChange(of: audioRecorder.isRecording) { oldValue, newValue in
            keyboardMonitor.isRecording = newValue
        }
        .onChange(of: keyboardMonitor.isFunctionPressed) { oldValue, newValue in
            handleFunctionKeyChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: keyboardMonitor.isEscapePressed) { oldValue, newValue in
            if newValue {
                // Escape key pressed - cancel everything
                if audioRecorder.isRecording {
                    // Stop recording immediately
                    _ = audioRecorder.stopRecording()
                    didActuallyStartRecording = false
                    // Hide indicator immediately
                    indicatorWindowManager.updateWindowVisibility(false)
                } else if transcriptionService.isTranscribing || transcriptionService.isAwaitingInsertion {
                    // Cancel transcription or insertion
                    transcriptionService.cancelTranscription()
                }
            }
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Transcrybe") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

// MARK: - Function Key Handler

extension TranscrybeApp {
    private func handleFunctionKeyChange(oldValue: Bool, newValue: Bool) {
        if !oldValue && newValue {
            // Function key pressed

            // Prevent triggering if transcription is already underway
            if transcriptionService.isTranscribing {
                didActuallyStartRecording = false
                return
            }

            let didStart = audioRecorder.startRecording()
            didActuallyStartRecording = didStart

            if didStart {
                openWindow(id: "recording-indicator")
            }
        } else if oldValue && !newValue {
            // Function key released

            // Only process if we actually started recording in response to the press
            guard didActuallyStartRecording else {
                didActuallyStartRecording = false
                return
            }

            if let audioFile = audioRecorder.stopRecording() {
                transcriptionService.transcribeAudio(fileURL: audioFile) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            transcriptionService.isAwaitingInsertion = false
                        } else if let result = result, !result.isEmpty && !isBlankAudio(result) {
                            // Ensure the indicator window is available while we finish insertion
                            openWindow(id: "recording-indicator")
                            transcriptionService.isAwaitingInsertion = true

                            // Automatically insert at cursor after successful transcription
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.accessibilityManager.insertTextAtCursor(result)
                                transcriptionService.isAwaitingInsertion = false
                            }
                        } else {
                            transcriptionService.isAwaitingInsertion = false
                        }
                    }
                }
            }

            didActuallyStartRecording = false
        }
    }

    private func isBlankAudio(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lowerText = trimmed.lowercased()

        return lowerText.contains("[blank_audio]") ||
               lowerText.contains("blank audio") ||
               trimmed.isEmpty ||
               trimmed == "[BLANK_AUDIO]" ||
               trimmed == "[blank_audio]"
    }
}
