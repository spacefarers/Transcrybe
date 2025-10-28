//
//  Services.swift
//  Transcrybe
//
//  Services: audio recording, transcription, keyboard monitoring, text insertion, and model management
//

import Foundation
import AVFoundation
import Combine
import os
import Cocoa
import ApplicationServices

// MARK: - Audio Recording

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?

    private let logger = Logger(subsystem: "com.transcryb.audio", category: "recorder")
    private var audioRecorder: AVAudioRecorder?

    override init() {
        super.init()
        logger.info("AudioRecorder initialized")
    }

    func startRecording() -> Bool {
        guard !isRecording else { return false }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            // Configure audio settings for recording
            let audioSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,  // 16kHz for Whisper
                AVNumberOfChannelsKey: 1,   // Mono
                AVLinearPCMBitDepthKey: 16, // 16-bit
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            // Create AVAudioRecorder - this is the key difference for macOS
            // AVAudioRecorder directly accesses the microphone
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)

            guard let recorder = audioRecorder else {
                logger.error("✗ Failed to create audio recorder")
                return false
            }

            // Set delegate to track recording state
            recorder.delegate = self

            // Start recording
            let success = recorder.record()

            if success {
                self.recordingURL = fileURL
                self.isRecording = true
                logger.info("✓ Audio recording started with AVAudioRecorder: \(fileName)")
                logger.info("  Sample Rate: 16000 Hz, Channels: 1, Bit Depth: 16-bit")
                return true
            } else {
                logger.error("✗ Failed to start AVAudioRecorder")
                return false
            }

        } catch {
            logger.error("✗ Failed to create AVAudioRecorder: \(error.localizedDescription)")
            return false
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else {
            logger.error("✗ Not currently recording")
            return nil
        }

        guard let recorder = audioRecorder else {
            logger.error("✗ No audio recorder found")
            return nil
        }

        // Stop the recorder
        recorder.stop()
        self.isRecording = false

        guard let fileURL = recordingURL else {
            logger.error("✗ No recording URL set")
            return nil
        }

        do {
            // Get file info
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int ?? 0

            logger.info("✓ Recording stopped and saved: \(fileURL.lastPathComponent) (\(fileSize) bytes)")

            return fileURL
        } catch {
            logger.error("✗ Error getting file attributes: \(error.localizedDescription)")
            return fileURL  // Still return URL even if we can't get file info
        }
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            logger.info("✓ Audio recorder finished successfully")
        } else {
            logger.error("✗ Audio recorder finished with error")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        logger.error("✗ Audio recorder encode error: \(error?.localizedDescription ?? "Unknown")")
    }
}

// MARK: - Whisper Wrapper

class WhisperContext {
    private let logger = Logger(subsystem: "com.transcryb.whisper", category: "wrapper")
    private var modelPath: String
    private var bridge: WhisperBridge?

    init?(modelPath: String) {
        self.modelPath = modelPath
        guard FileManager.default.fileExists(atPath: modelPath) else {
            logger.error("Model file not found at: \(modelPath)")
            return nil
        }

        // Initialize whisper via Objective-C bridge
        guard let bridge = WhisperBridge(modelPath: modelPath) else {
            logger.error("Failed to initialize Whisper context from model: \(modelPath)")
            return nil
        }

        self.bridge = bridge

        logger.info("✓ Whisper model prepared: \(modelPath)")
    }

    func transcribe(audioSamples: [Float]) -> String? {
        guard let bridge = bridge else {
            logger.error("Whisper bridge not initialized")
            return nil
        }

        logger.info("Starting transcription with \(audioSamples.count) audio samples...")

        // Convert Float array to NSNumber array for Objective-C
        let numberArray: [NSNumber] = audioSamples.map { NSNumber(value: $0) }

        // Call transcription via bridge
        if let result = bridge.transcribeAudioSamples(numberArray) {
            logger.info("✓ Transcription completed. Result length: \(result.count) characters")
            return result
        } else {
            logger.error("Transcription returned nil")
            return nil
        }
    }
}

class AudioConverter {
    static func convertAudioToFloat32(from audioFileURL: URL) -> [Float]? {
        let logger = Logger(subsystem: "com.transcryb.whisper", category: "converter")

        do {
            logger.info("Reading audio file: \(audioFileURL.lastPathComponent)")

            // Read the audio file
            let audioFile = try AVAudioFile(forReading: audioFileURL)
            let format = audioFile.processingFormat
            let totalFrames = Int(audioFile.length)

            logger.info("Audio file info: \(format.sampleRate)Hz, \(format.channelCount) channels, \(totalFrames) frames")

            guard totalFrames > 0 else {
                logger.error("✗ Audio file has 0 frames")
                return nil
            }

            // Create a compatible format for reading
            guard let readFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: format.channelCount, interleaved: false) else {
                logger.error("✗ Could not create read format")
                return nil
            }

            // Create buffer to read into
            guard let buffer = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: AVAudioFrameCount(totalFrames)) else {
                logger.error("✗ Could not create audio buffer with capacity \(totalFrames)")
                return nil
            }

            // Read the entire file
            try audioFile.read(into: buffer)
            let actualFrames = Int(buffer.frameLength)

            logger.info("Read \(actualFrames) frames from audio file")

            guard actualFrames > 0 else {
                logger.error("✗ Buffer has 0 frames after reading")
                return nil
            }

            // Convert to float mono samples
            var monoSamples = [Float]()
            monoSamples.reserveCapacity(actualFrames)

            let channelCount = Int(readFormat.channelCount)

            if let floatData = buffer.floatChannelData {
                // Average channels to mono
                for frame in 0..<actualFrames {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += floatData[channel][frame]
                    }
                    let avgSample = sum / Float(channelCount)
                    monoSamples.append(avgSample)
                }
            } else {
                logger.error("✗ Could not get float channel data from buffer")
                return nil
            }

            logger.info("✓ Audio converted successfully. Samples: \(monoSamples.count)")
            return monoSamples
        } catch {
            logger.error("✗ Error reading audio: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Transcription Service

class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    @Published var isAwaitingInsertion = false

    private let logger = Logger(subsystem: "com.transcryb.transcription", category: "service")
    private var whisperContext: WhisperContext?
    private var modelPath: String?
    private var isCancelled = false

    func setModelPath(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            logger.error("Model file not found at: \(path)")
            errorMessage = "Model file not found at: \(path)"
            return
        }

        self.modelPath = path
        self.whisperContext = WhisperContext(modelPath: path)

        if whisperContext == nil {
            errorMessage = "Failed to initialize Whisper with model at: \(path)"
        } else {
            logger.info("✓ Model loaded successfully: \(path)")
            errorMessage = nil
        }
    }

    func loadModel(_ modelId: String, from modelManager: ModelManager) {
        let modelPath = modelManager.getModelPath(modelId)
        setModelPath(modelPath)
    }

    func cancelTranscription() {
        isCancelled = true
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.isAwaitingInsertion = false
            self.transcribedText = ""
        }
        logger.info("Transcription cancelled by user")
    }

    func transcribeAudio(fileURL: URL, completion: @escaping (String?, Error?) -> Void) {
        isCancelled = false

        guard let context = whisperContext else {
            let error = NSError(
                domain: "TranscriptionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Whisper model not loaded. Please specify the model path."]
            )
            DispatchQueue.main.async {
                self.errorMessage = "Whisper model not loaded. Please specify the model path."
                self.isTranscribing = false
            }
            completion(nil, error)
            return
        }

        // Check audio file duration
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            // Reject recordings shorter than 0.5 seconds
            if duration < 0.5 {
                let error = NSError(
                    domain: "TranscriptionService",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Recording too short (less than 0.5 seconds)"]
                )
                DispatchQueue.main.async {
                    self.isTranscribing = false
                }
                self.logger.info("Recording rejected: duration \(String(format: "%.2f", duration))s (minimum 0.5s required)")
                completion(nil, error)
                return
            }

            self.logger.info("Recording accepted: duration \(String(format: "%.2f", duration))s")
        } catch {
            let nsError = NSError(
                domain: "TranscriptionService",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read audio file duration: \(error.localizedDescription)"]
            )
            DispatchQueue.main.async {
                self.isTranscribing = false
            }
            completion(nil, nsError)
            return
        }

        DispatchQueue.main.async {
            self.isTranscribing = true
            self.isAwaitingInsertion = false
            self.errorMessage = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Convert audio to float32 samples at 16kHz
            guard let audioSamples = AudioConverter.convertAudioToFloat32(from: fileURL) else {
                let error = NSError(
                    domain: "TranscriptionService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert audio file"]
                )
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to convert audio file"
                    self?.isTranscribing = false
                    self?.isAwaitingInsertion = false
                }
                self?.logger.error("Audio conversion failed")
                completion(nil, error)
                return
            }

            // Check if cancelled before transcribing
            if self?.isCancelled == true {
                DispatchQueue.main.async {
                    self?.isTranscribing = false
                    self?.isAwaitingInsertion = false
                }
                return
            }

            self?.logger.info("Audio converted successfully. Samples: \(audioSamples.count)")

            // Transcribe using Whisper framework
            guard let transcribedText = context.transcribe(audioSamples: audioSamples) else {
                let error = NSError(
                    domain: "TranscriptionService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Transcription failed"]
                )
                DispatchQueue.main.async {
                    self?.errorMessage = "Transcription failed"
                    self?.isTranscribing = false
                    self?.isAwaitingInsertion = false
                }
                self?.logger.error("Transcription failed")
                completion(nil, error)
                return
            }

            // Check if cancelled after transcribing
            if self?.isCancelled == true {
                DispatchQueue.main.async {
                    self?.isTranscribing = false
                    self?.isAwaitingInsertion = false
                }
                return
            }

            self?.logger.info("Transcription completed successfully")
            DispatchQueue.main.async {
                self?.transcribedText = transcribedText
                self?.isTranscribing = false
                self?.isAwaitingInsertion = true
            }
            completion(transcribedText, nil)
        }
    }
}

// MARK: - Keyboard Monitor

class KeyboardMonitor: NSObject, ObservableObject {
    @Published var isFunctionPressed = false
    @Published var isEscapePressed = false
    @Published var isRecording = false

    private let logger = Logger(subsystem: "com.transcryb.keyboard", category: "monitor")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var hotKeyManager: HotKeyManager?
    private var currentModifiers: NSEvent.ModifierFlags = []

    private let escapeKeyCode: UInt16 = 53  // Escape key code

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
                let shouldConsume = self.handle(event: event, type: type)
                // Return nil to consume event, or the event to let it pass through
                return shouldConsume ? nil : Unmanaged.passUnretained(event)
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

    private func handle(event: CGEvent, type: CGEventType) -> Bool {
        let modifiers = modifierFlags(from: event.flags)
        currentModifiers = modifiers

        let keyCode: UInt16?
        if type == .keyDown || type == .keyUp {
            keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        } else {
            keyCode = nil
        }

        // Handle Escape key - consume it if recording
        if let keyCode = keyCode, keyCode == escapeKeyCode {
            let isEscapeDown = type == .keyDown
            if isEscapeDown != isEscapePressed {
                DispatchQueue.main.async { [weak self] in
                    self?.isEscapePressed = isEscapeDown
                    if isEscapeDown {
                        self?.logger.info("Escape key PRESSED")
                    }
                }
            }
            // Consume Escape key on keyDown if recording
            if isEscapeDown && isRecording {
                return true  // Consume the event
            }
        }

        // Only evaluate function key on flagsChanged events
        // This prevents arrow keys and other regular keys from triggering hotkey detection
        if type == .flagsChanged {
            let isFunctionNowPressed = modifiers.contains(.function)

            if isFunctionNowPressed != isFunctionPressed {
                DispatchQueue.main.async { [weak self] in
                    self?.isFunctionPressed = isFunctionNowPressed
                    self?.logger.info("Function key \(isFunctionNowPressed ? "PRESSED" : "RELEASED")")
                }
            }
        }

        return false  // Don't consume other events
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

    deinit {
        teardownEventTap()
        logger.info("Keyboard monitor deinitialized")
    }
}

// MARK: - Accessibility Manager

final class AccessibilityManager: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.transcryb.accessibility", category: "manager")

    // Public API
    func insertTextAtCursor(_ text: String) {
        // Small delay so focus can settle after UI actions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self = self else { return }

            // Check if a text input field is actually focused
            guard self.isTextInputFieldFocused() else {
                self.logger.info("No text input field focused, skipping insertion")
                return
            }

            self.requestAXTrustIfNeeded()

            if self.typeUnicode(text) {
                self.logger.info("Inserted via Unicode typing")
            } else {
                self.logger.error("Unicode typing failed")
            }
        }
    }

    /// Check if a text input field is currently focused
    private func isTextInputFieldFocused() -> Bool {
        guard let systemWideAE = AXUIElementCreateSystemWide() as AXUIElement? else {
            return false
        }

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideAE,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success else {
            return false
        }

        let element = focusedElement as! AXUIElement

        // Check if the focused element is editable
        var isEditable: AnyObject?
        let editResult = AXUIElementCopyAttributeValue(
            element,
            kAXEditableAncestorAttribute as CFString,
            &isEditable
        )

        // If element has an editable ancestor, it's likely editable
        if editResult == .success && isEditable != nil {
            return true
        }

        // Also check the role of the focused element
        var role: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &role
        )

        if roleResult == .success, let roleString = role as? NSString {
            let editableRoles: [String] = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                kAXComboBoxRole as String
            ]

            for editableRole in editableRoles {
                if roleString.isEqual(to: editableRole) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Unicode typing

    /// Types the full string by sending Unicode payload key events.
    /// Splits into UTF-16 chunks to avoid IOHID payload and IME edge cases.
    private func typeUnicode(_ text: String) -> Bool {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return false }

        // Use a conservative chunk size. 120–200 UTF-16 units is typically safe.
        // This avoids very large event payloads that some apps ignore.
        let utf16 = Array(text.utf16)
        let chunkSize = 160
        var ok = true

        var i = 0
        while i < utf16.count {
            let end = min(i + chunkSize, utf16.count)
            let slice = utf16[i..<end]
            // Ensure we do not split surrogate pairs
            let safeEnd = adjustForSurrogateSplit(utf16: utf16, start: i, proposedEnd: end)
            let finalSlice = utf16[i..<safeEnd]

            if !sendUnicodeChunk(src: src, utf16Chunk: Array(finalSlice)) {
                ok = false
                break
            }
            i = safeEnd
            // Tiny pause can improve reliability in some apps
            usleep(1_000)
        }

        return ok
    }

    /// Prevent splitting a surrogate pair at the boundary.
    private func adjustForSurrogateSplit(utf16: [UInt16], start: Int, proposedEnd: Int) -> Int {
        guard proposedEnd < utf16.count else { return proposedEnd }
        let last = utf16[proposedEnd - 1]
        let next = utf16[proposedEnd]
        // High surrogate range D800–DBFF, low surrogate DC00–DFFF
        let isHighSurrogate = 0xD800...0xDBFF ~= last
        let isLowSurrogate = 0xDC00...0xDFFF ~= next
        if isHighSurrogate && isLowSurrogate {
            return proposedEnd + 1
        }
        return proposedEnd
    }

    /// Sends a single keyDown+keyUp pair carrying the Unicode payload.
    private func sendUnicodeChunk(src: CGEventSource, utf16Chunk: [UInt16]) -> Bool {
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else {
            return false
        }

        // Attach Unicode payload
        var chunkCopy = utf16Chunk
        down.keyboardSetUnicodeString(stringLength: chunkCopy.count, unicodeString: &chunkCopy)
        up.keyboardSetUnicodeString(stringLength: 0, unicodeString: nil)

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Permissions

    /// CGEvent posting requires Accessibility permission.
    private func requestAXTrustIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}

// MARK: - Model Manager

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
