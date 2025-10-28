import Foundation
import Combine
import os
import AVFoundation

class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    @Published var isAwaitingInsertion = false

    private let logger = Logger(subsystem: "com.transcryb.transcription", category: "service")
    private var whisperContext: WhisperContext?
    private var modelPath: String?

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

    func transcribeAudio(fileURL: URL, completion: @escaping (String?, Error?) -> Void) {
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
