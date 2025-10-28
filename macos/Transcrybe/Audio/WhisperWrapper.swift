import Foundation
import AVFoundation
import os

// Swift wrapper around Whisper via Objective-C bridge
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
