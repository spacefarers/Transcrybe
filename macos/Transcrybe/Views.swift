//
//  Views.swift
//  Transcrybe
//
//  All UI views and components
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - App Root View

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
            }

            // Always set isFirstLaunch to false when the window appears - this is the first actual launch
            isFirstLaunch = false
        }
        .task {
            if !hasStartedPermissionFlow {
                hasStartedPermissionFlow = true
                permissionManager.startPermissionFlow()
            }
        }
        .onDisappear {
            settingsWindowManager.shouldShowSettings = false
            settingsWindowManager.clearSettingsWindowID()
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

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var transcriptionService: TranscriptionService
    @ObservedObject var keyboardMonitor: KeyboardMonitor
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var launchOnStartupManager: LaunchOnStartupManager
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var selectedModelId: String = "base"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var hasInitializedModel = false

    private let userDefaults = UserDefaults.standard
    private let selectedModelKey = "SelectedModel"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Transcrybe")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Whisper transcription at your fingertip. Hold fn and start talking!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.controlBackgroundColor))
            .border(Color(.separatorColor), width: 1)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    // Model Setup Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Whisper Model", systemImage: "waveform.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Picker("Select Model", selection: $selectedModelId) {
                            ForEach(modelManager.availableModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                        .onChange(of: selectedModelId) { oldValue, newValue in
                            handleModelSelection(newValue)
                        }

                        // Model descriptions and status
                        if let selectedModel = modelManager.availableModels.first(where: { $0.id == selectedModelId }) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedModel.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)

                                HStack(spacing: 12) {
                                    // Status indicator
                                    HStack(spacing: 6) {
                                        Image(systemName: selectedModel.isInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                            .foregroundStyle(selectedModel.isInstalled ? .green : .orange)
                                        Text(selectedModel.isInstalled ? "Installed" : "Not installed")
                                            .font(.caption)
                                            .fontWeight(.medium)

                                        // Uninstall button (only show if installed)
                                        if selectedModel.isInstalled {
                                            Button(action: {
                                                modelManager.uninstallModel(selectedModelId)
                                            }) {
                                                Image(systemName: "trash.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Uninstall model")
                                        }
                                    }

                                    Spacer()

                                    // Download button (only show if not installed)
                                    if !selectedModel.isInstalled {
                                        Button(action: {
                                            modelManager.downloadModel(selectedModelId) { success in
                                                if success {
                                                    handleModelSelection(selectedModelId)
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.down.circle")
                                                Text("Download")
                                            }
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }

                                // Download Progress
                                if modelManager.isDownloading, let currentModel = modelManager.currentDownloadingModel, currentModel == selectedModelId {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            ProgressView(value: modelManager.downloadProgress)
                                            Text("\(Int(modelManager.downloadProgress * 100))%")
                                                .font(.caption)
                                                .monospacedDigit()
                                        }
                                        Text("Downloading...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Error message
                                if let errorMessage = modelManager.errorMessage {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .frame(width: 16)
                                        Text(errorMessage)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                    // Launch on Startup Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("System Integration", systemImage: "gearshape.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Toggle("Launch on Startup", isOn: $launchOnStartupManager.isEnabled)
                            .onChange(of: launchOnStartupManager.isEnabled) { oldValue, newValue in
                                launchOnStartupManager.setLaunchOnStartup(newValue)
                            }
                            .font(.caption)

                        Text("Automatically launch Transcrybe when your Mac starts up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                    // Error Message
                    if let errorMessage = transcriptionService.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 16)
                                Text("Error")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(16)
            }

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Alert", isPresented: $showAlert, actions: {
            Button("OK") { }
        }, message: {
            Text(alertMessage)
        })
        .onAppear {
            // Initialize model state on first appearance
            if !hasInitializedModel {
                hasInitializedModel = true

                // Load saved model selection from UserDefaults
                if let savedModel = userDefaults.string(forKey: selectedModelKey) {
                    selectedModelId = savedModel
                }

                // Check if selected model is installed, but don't auto-download
                if modelManager.isModelInstalled(selectedModelId) {
                    transcriptionService.loadModel(selectedModelId, from: modelManager)
                }
            }
        }
        .onChange(of: selectedModelId) { oldValue, newValue in
            // Save model selection and load if installed
            userDefaults.setValue(newValue, forKey: selectedModelKey)
            handleModelSelection(newValue)
        }
    }

    private func handleModelSelection(_ modelId: String) {
        // Only load if already installed, otherwise just wait for user to click download
        if modelManager.isModelInstalled(modelId) {
            transcriptionService.loadModel(modelId, from: modelManager)
        }
    }
}

// MARK: - Permission Flow View

struct PermissionFlowView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Verifying Permissions")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Checking permissions required to use Transcrybe...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PermissionStepIndicator(
                    stepNumber: 1,
                    title: "Microphone Access",
                    isActive: permissionManager.currentPermissionStep == 0
                )

                PermissionStepIndicator(
                    stepNumber: 2,
                    title: "Accessibility",
                    isActive: permissionManager.currentPermissionStep == 1
                )
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Why we need these permissions:")
                    .fontWeight(.semibold)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.blue)
                        Text("Microphone - To record your audio")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "accessibility.fill")
                            .foregroundStyle(.blue)
                        Text("Accessibility - To detect Function key & insert text")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            Text("Follow the system prompts to grant each permission.\nIf you deny any permission, the app will exit.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 500)
    }
}

struct PermissionStepIndicator: View {
    let stepNumber: Int
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            Text(title)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .primary : .secondary)

            Spacer()

            if isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Recording Indicator View

struct RecordingIndicatorView: View {
    let isRecording: Bool
    let isProcessing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.92),
                            Color.black.opacity(0.75)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 32
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            if isRecording {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .transition(.scale)
            } else if isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(0.9)
                    .transition(.opacity)
            }
        }
        .frame(width: 64, height: 64)
        .overlay(alignment: .center) {
            if isRecording {
                Circle()
                    .stroke(Color.red.opacity(0.85), lineWidth: 3)
                    .blur(radius: 0.5)
            } else if isProcessing {
                Circle()
                    .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                    .blur(radius: 0.5)
            }
        }
    }
}

struct RecordingIndicatorWindowContent: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var transcriptionService: TranscriptionService
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var windowManager: IndicatorWindowManager

    private var isProcessing: Bool {
        transcriptionService.isTranscribing || transcriptionService.isAwaitingInsertion
    }

    private var shouldShowIndicator: Bool {
        audioRecorder.isRecording || isProcessing
    }

    var body: some View {
        ZStack {
            if shouldShowIndicator {
                RecordingIndicatorView(
                    isRecording: audioRecorder.isRecording,
                    isProcessing: isProcessing
                )
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onChange(of: audioRecorder.isRecording) { _, newValue in
            if newValue {
                windowManager.updateWindowVisibility(true)
            } else if !transcriptionService.isTranscribing && !transcriptionService.isAwaitingInsertion {
                // Recording stopped and not transcribing/inserting - hide if no other activity
                windowManager.updateWindowVisibility(false)
            }
        }
        .onChange(of: transcriptionService.isTranscribing) { _, newValue in
            windowManager.updateWindowVisibility(newValue)
        }
        .onChange(of: transcriptionService.isAwaitingInsertion) { _, newValue in
            if !newValue && !audioRecorder.isRecording && !transcriptionService.isTranscribing {
                // All done - hide indicator
                windowManager.updateWindowVisibility(false)
            }
        }
    }
}
