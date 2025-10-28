//
//  TranscrybeApp.swift
//  Transcrybe
//
//  Created by Michael Yang on 10/27/25.
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
        // Settings window - only created when explicitly opened via openWindow()
        WindowGroup(id: "settings") {
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
        }
        .windowStyle(.hiddenTitleBar)
        .onChange(of: keyboardMonitor.isFunctionPressed) { oldValue, newValue in
            handleFunctionKeyChange(oldValue: oldValue, newValue: newValue)
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Transcrybe") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        // Menu bar item
        MenuBarExtra("Transcrybe", systemImage: "microphone.fill") {
            VStack(spacing: 8) {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    // Try to focus existing window; if it doesn't exist or isn't visible, open a new one
                    if !settingsWindowManager.focusSettingsWindowIfOpen() {
                        settingsWindowManager.shouldShowSettings = true
                        openWindow(id: "settings")
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
        }

        // Floating recording indicator window
        Window("Recording Indicator", id: "recording-indicator") {
            RecordingIndicatorWindowContent(
                audioRecorder: audioRecorder,
                transcriptionService: transcriptionService,
                windowManager: indicatorWindowManager
            )
            .frame(width: 80, height: 80)
            .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottom)
    }
}

struct AppRootView: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var transcriptionService: TranscriptionService
    @ObservedObject var keyboardMonitor: KeyboardMonitor
    @ObservedObject var settingsWindowManager: SettingsWindowManager
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var hotKeyManager: HotKeyManager
    @ObservedObject var launchOnStartupManager: LaunchOnStartupManager
    @Binding var isFirstLaunch: Bool
    @State private var hasStartedPermissionFlow = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if permissionManager.isPermissionFlowComplete {
                ContentView(
                    audioRecorder: audioRecorder,
                    transcriptionService: transcriptionService,
                    keyboardMonitor: keyboardMonitor,
                    modelManager: modelManager,
                    hotKeyManager: hotKeyManager,
                    launchOnStartupManager: launchOnStartupManager
                )
                    .environmentObject(permissionManager)
                    .environmentObject(audioRecorder)
                    .environmentObject(transcriptionService)
                    .environmentObject(keyboardMonitor)
            } else {
                PermissionFlowView(permissionManager: permissionManager)
            }
        }
        .onAppear {
            // Record the window number so we can track it
            if let window = NSApplication.shared.windows.first(where: { !$0.title.isEmpty && $0.level != .mainMenu }) {
                settingsWindowManager.recordSettingsWindowID(window.windowNumber)

                // On first launch, dismiss the window if settings shouldn't show
                if isFirstLaunch && !settingsWindowManager.shouldShowSettings {
                    dismissWindow(id: "settings")
                    isFirstLaunch = false
                }
            }
        }
        .task {
            if !hasStartedPermissionFlow {
                hasStartedPermissionFlow = true
                permissionManager.startPermissionFlow()
            }
        }
        .onDisappear {
            settingsWindowManager.shouldShowSettings = false
            isFirstLaunch = false
        }
        .onChange(of: permissionManager.isPermissionFlowComplete) { oldValue, newValue in
            if newValue && !oldValue {
                // Permissions just granted - reinitialize keyboard monitor, set hotkey manager, and load default model
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    keyboardMonitor.setHotKeyManager(hotKeyManager)
                    keyboardMonitor.reinitialize()

                    // Load default model if installed, so transcription service is ready
                    if modelManager.isModelInstalled("base") {
                        transcriptionService.loadModel("base", from: modelManager)
                    }
                }
            }
        }
    }
}

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
