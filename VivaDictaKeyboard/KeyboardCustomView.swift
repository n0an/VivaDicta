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

    let controller: KeyboardInputViewController
//    let stateManager: KeyboardStateManager?
//    let appStateViewModel: AppStateViewModel?

    let onCancelRecording: () -> Void
    let onStopRecording: () -> Void
    let onCancelProcessing: () -> Void
    let onRecordTapped: () -> Void

    var body: some View {
        Group {
            switch dictationState.uiState {
            case .recording:
                RecordingStateView(
                    onCancelTapped: {
                        dictationState.requestCancelRecording()
                        onCancelRecording()
                    },
                    onStopTapped: {
                        dictationState.requestStopRecording()
                        onStopRecording()
                    }
                )

            case .processing:
                ProcessingStateView(
                    processingStage: $processingStage,
                    onCancel: {
                        // Cancel processing if possible
                        onCancelProcessing()
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
                        state: controller.state,
                        services: controller.services,
                        buttonContent: { $0.view },
                        buttonView: { $0.view },
                        collapsedView: { $0.view },
                        emojiKeyboard: { $0.view },
                        toolbar: { _ in
                            VivaDictaKeyboardToolbarView()
                                .environment(self.dictationState)
                        }
                    )
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
