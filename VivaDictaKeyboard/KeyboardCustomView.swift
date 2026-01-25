//
//  KeyboardCustomView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.05
//

import SwiftUI
import KeyboardKit

struct KeyboardCustomView: View {

    @Environment(KeyboardDictationState.self) var dictationState
    @State private var processingStage: ProcessingStage = .waitingToStart
    @State private var showFullAccessPrompt = false

    let controller: KeyboardInputViewController

    private var hasFullAccess: Bool {
        controller.hasFullAccess
    }

    var body: some View {
        Group {
            if showFullAccessPrompt {
                FullAccessPromptView(onDismiss: {
                    showFullAccessPrompt = false
                })
            } else {
                switch dictationState.uiState {
                case .recording:
                    RecordingStateView(dictationState: dictationState)

                case .processing:
                    ProcessingStateView(
                        processingStage: processingStage,
                        onCancel: {
                            // Cancel processing and notify main app to stop and reschedule session
                            dictationState.errorMessage = nil
                            dictationState.transcriptionStatus = .idle
                            dictationState.requestCancelRecording()
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
                            // Clear error and return to keyboard
                            dictationState.errorMessage = nil
                            dictationState.transcriptionStatus = .idle
                            AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
                        }
                    )

                case .notReady, .ready:
                    // Show normal keyboard for idle and ready states
                    VStack(spacing: 0) {
                        KeyboardView(
//                            state: controller.state,
                            services: controller.services,
                            buttonContent: { $0.view },
                            buttonView: { $0.view },
                            collapsedView: { $0.view },
                            emojiKeyboard: { $0.view },
                            toolbar: { _ in
                                VivaDictaKeyboardToolbarView(
                                    controller: controller as? KeyboardViewController,
                                    hasFullAccess: hasFullAccess,
                                    onShowFullAccessPrompt: { showFullAccessPrompt = true }
                                )
                                .environment(self.dictationState)
                            }
                        )
                    }
                }
            }
        }
    }

    private func updateProcessingStage() {
        switch dictationState.transcriptionStatus {
        case .transcribing:
            processingStage = .transcribing
        case .enhancing:
            processingStage = .enhancingWithAI
        case .error:
            if let errorMsg = dictationState.errorMessage {
                processingStage = .error(errorMsg)
            } else {
                processingStage = .error("Processing failed")
            }
        case .completed:
            processingStage = .completed
            // When completed, the keyboard will automatically return to idle
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
