//
//  RecordingIndicatorView.swift
//  Transcrybe
//
//  Created by Michael Yang on 10/27/25.
//

import SwiftUI

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
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)

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
                    .shadow(color: .red.opacity(0.45), radius: 10, x: 0, y: 0)
            } else if isProcessing {
                Circle()
                    .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                    .blur(radius: 0.5)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 0)
            }
        }
        .padding(8)
    }
}

// Content view that manages window visibility
struct RecordingIndicatorWindowContent: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var transcriptionService: TranscriptionService
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
        .onChange(of: audioRecorder.isRecording) { _, _ in
            windowManager.updateWindowVisibility(shouldShowIndicator)
        }
        .onChange(of: transcriptionService.isTranscribing) { _, _ in
            windowManager.updateWindowVisibility(shouldShowIndicator)
        }
        .onChange(of: transcriptionService.isAwaitingInsertion) { _, _ in
            windowManager.updateWindowVisibility(shouldShowIndicator)
        }
        .onAppear {
            windowManager.updateWindowVisibility(shouldShowIndicator)
        }
    }
}

#Preview {
    RecordingIndicatorView(isRecording: true, isProcessing: false)
}
