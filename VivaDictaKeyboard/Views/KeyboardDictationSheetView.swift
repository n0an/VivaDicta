//
//  KeyboardDictationSheetView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.13
//

import SwiftUI

struct KeyboardDictationSheetView: View {

    @Environment(KeyboardDictationState.self) var dictationState

    let onCancelTapped: () -> Void
    let onStopTapped: () -> Void

    @State private var processingStage: ProcessingStage = .waitingToStart

    var body: some View {
        ZStack {
            // Background color
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            // Content based on state
            Group {
                switch dictationState.uiState {
                case .recording:
                    RecordingStateView(
                        flowModeManager: dictationState.flowModeManager,
                        onCancelTapped: {
                            dictationState.requestCancelRecording()
                            onCancelTapped()
                        },
                        onStopTapped: {
                            dictationState.requestStopRecording()
                            onStopTapped()
                        }
                    )

                case .processing:
                    ProcessingStateView(
                        processingStage: $processingStage,
                        onCancel: {
                            // Cancel processing if possible
                            onCancelTapped()
                        }
                    )
                    .onAppear {
                        updateProcessingStage()
                    }
                    .onChange(of: dictationState.transcriptionStatus) { _, _ in
                        updateProcessingStage()
                    }

                case .error:
                    ErrorStateView(
                        errorMessage: dictationState.errorMessage ?? "An error occurred",
                        onDismiss: {
                            onCancelTapped()
                        }
                    )

                case .notReady, .ready:
                    // These states shouldn't show the sheet
                    // but if they do, show a loading indicator
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()

                        Text("Initializing...")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        // Auto-dismiss if we're in an unexpected state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onCancelTapped()
                        }
                    }
                }
            }
        }
    }

    private func updateProcessingStage() {
        switch dictationState.transcriptionStatus {
        case .transcribing:
            processingStage = .transcribing
        case .error:
            if let errorMsg = dictationState.errorMessage {
                processingStage = .error(errorMsg)
            } else {
                processingStage = .error("Processing failed")
            }
        case .completed:
            processingStage = .completed
            // Auto-dismiss after a short delay when completed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onStopTapped()
            }
        default:
            processingStage = .waitingToStart
        }
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let errorMessage: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .padding(.bottom, 10)

            // Error message
            Text("Error")
                .font(.system(size: 24, weight: .semibold))

            Text(errorMessage)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Dismiss button
            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(Color.blue)
                    .cornerRadius(22)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}
