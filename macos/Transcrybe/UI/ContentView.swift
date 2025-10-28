//
//  ContentView.swift
//  Transcrybe
//
//  Created by Michael Yang on 10/27/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var transcriptionService: TranscriptionService
    @ObservedObject var keyboardMonitor: KeyboardMonitor
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var hotKeyManager: HotKeyManager
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
                Text("Whisper transcription at your fingertip")
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

                    // Hotkey Configuration Section
                    HotKeyRecorderView(hotKeyManager: hotKeyManager)
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

#Preview {
    ContentView(
        audioRecorder: AudioRecorder(),
        transcriptionService: TranscriptionService(),
        keyboardMonitor: KeyboardMonitor(),
        modelManager: ModelManager(),
        hotKeyManager: HotKeyManager(),
        launchOnStartupManager: LaunchOnStartupManager()
    )
}
