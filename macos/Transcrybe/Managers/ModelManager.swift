//
//  ModelManager.swift
//  Transcrybe
//
//  Manages downloading and storing Whisper models locally
//

import Foundation
import Combine
import os

class ModelManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var availableModels: [WhisperModel] = []
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var currentDownloadingModel: String?
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "com.transcryb.models", category: "manager")
    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var downloadCompletion: ((Bool) -> Void)?

    // Supported models (three most useful ones)
    static let supportedModels: [WhisperModel] = [
        WhisperModel(id: "tiny", displayName: "Tiny (Fast) 39MB", description: "Fastest but least accurate. ~39MB"),
        WhisperModel(id: "base", displayName: "Base (Balanced) 140MB", description: "Good balance of speed and accuracy. ~140MB"),
        WhisperModel(id: "small", displayName: "Small (Accurate) 446MB", description: "More accurate but slower. ~466MB"),
    ]

    private let modelsDirectory: URL

    override init() {
        // Create models directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        modelsDirectory = appSupport.appendingPathComponent("Transcrybe/Models", isDirectory: true)

        super.init()

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Setup download session (foreground, not background - works with sandbox)
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)

        // Scan for existing models
        refreshAvailableModels()

        logger.info("ModelManager initialized. Models directory: \(self.modelsDirectory.path)")
    }

    func refreshAvailableModels() {
        availableModels = ModelManager.supportedModels.map { model in
            var updatedModel = model
            updatedModel.isInstalled = isModelInstalled(model.id)
            updatedModel.filePath = getModelPath(model.id)
            return updatedModel
        }

        logger.info("Available models refreshed: \(self.availableModels.map { $0.id }.joined(separator: ", "))")
    }

    func isModelInstalled(_ modelId: String) -> Bool {
        let modelPath = getModelPath(modelId)
        let exists = FileManager.default.fileExists(atPath: modelPath)
        if exists {
            logger.info("✓ Model '\(modelId)' is installed at: \(modelPath)")
        } else {
            logger.debug("✗ Model '\(modelId)' not found")
        }
        return exists
    }

    func getModelPath(_ modelId: String) -> String {
        return modelsDirectory.appendingPathComponent("ggml-\(modelId).bin").path
    }

    func downloadModel(_ modelId: String, completion: @escaping (Bool) -> Void) {
        // Check if already installed
        if isModelInstalled(modelId) {
            logger.info("Model '\(modelId)' already installed, skipping download")
            completion(true)
            return
        }

        guard availableModels.contains(where: { $0.id == modelId }) else {
            logger.error("Model '\(modelId)' not found in available models")
            errorMessage = "Model not found"
            completion(false)
            return
        }

        logger.info("Starting download of model: \(modelId)")
        DispatchQueue.main.async {
            self.isDownloading = true
            self.currentDownloadingModel = modelId
            self.downloadProgress = 0
            self.errorMessage = nil
        }

        downloadCompletion = completion
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(modelId).bin"

        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            errorMessage = "Invalid URL"
            DispatchQueue.main.async {
                self.isDownloading = false
            }
            completion(false)
            return
        }

        logger.info("Downloading from: \(urlString)")
        downloadTask = downloadSession?.downloadTask(with: url)
        downloadTask?.resume()
    }

    func uninstallModel(_ modelId: String) {
        let modelPath = getModelPath(modelId)
        let modelURL = URL(fileURLWithPath: modelPath)

        do {
            try FileManager.default.removeItem(at: modelURL)
            logger.info("✓ Model '\(modelId)' uninstalled successfully")
            refreshAvailableModels()
        } catch {
            logger.error("✗ Failed to uninstall model '\(modelId)': \(error.localizedDescription)")
            errorMessage = "Failed to uninstall model: \(error.localizedDescription)"
        }
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let modelId = currentDownloadingModel else {
            logger.error("Download completed but no model ID set")
            return
        }

        let destinationPath = getModelPath(modelId)
        let destinationURL = URL(fileURLWithPath: destinationPath)

        do {
            // Remove existing file if present
            try? FileManager.default.removeItem(at: destinationURL)

            // Move downloaded file to destination
            try FileManager.default.moveItem(at: location, to: destinationURL)

            logger.info("✓ Model '\(modelId)' downloaded successfully to: \(destinationPath)")

            DispatchQueue.main.async {
                self.isDownloading = false
                self.currentDownloadingModel = nil
                self.downloadProgress = 0
                self.refreshAvailableModels()
                self.downloadCompletion?(true)
            }
        } catch {
            logger.error("Failed to save downloaded model: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isDownloading = false
                self.currentDownloadingModel = nil
                self.errorMessage = "Failed to save model: \(error.localizedDescription)"
                self.downloadCompletion?(false)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
            let mbWritten = Double(totalBytesWritten) / (1024 * 1024)
            let mbTotal = Double(totalBytesExpectedToWrite) / (1024 * 1024)
            self.logger.debug("Download progress: \(String(format: "%.1f", mbWritten))/\(String(format: "%.1f", mbTotal)) MB")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Download failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isDownloading = false
                self.currentDownloadingModel = nil
                self.errorMessage = "Download failed: \(error.localizedDescription)"
                self.downloadCompletion?(false)
            }
        }
    }
}

struct WhisperModel: Identifiable {
    let id: String
    let displayName: String
    let description: String
    var isInstalled: Bool = false
    var filePath: String = ""

    var filename: String {
        "ggml-\(id).bin"
    }
}
