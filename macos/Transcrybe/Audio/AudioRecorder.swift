//
//  AudioRecorder.swift
//  Transcrybe
//
//  Uses AVAudioRecorder for reliable microphone input on macOS
//

import AVFoundation
import Combine
import os

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
