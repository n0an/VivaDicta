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
    @Environment(\.openURL) private var openURL
    @State private var processingStage: ProcessingStage = .waitingToStart
    @State private var showFullAccessPrompt = false

    let controller: KeyboardInputViewController

    private var hasFullAccess: Bool {
        controller.hasFullAccess
    }

    private var keyboardVC: KeyboardViewController? {
        controller as? KeyboardViewController
    }

    var body: some View {
        ZStack {
            // Main keyboard content - fades out when full access prompt is shown
            Group {
                // Text processing state takes priority
                if dictationState.textProcessingPhase != .idle {
                    TextProcessingStateView(
                        phase: dictationState.textProcessingPhase,
                        onCancel: {
                            keyboardVC?.textProcessor.cancel()
                            dictationState.textProcessingPhase = .idle
                        }
                    )
                } else if dictationState.activeTab == .textProcessing {
                    RewriteModesView(
                        onModeSelected: { mode in
                            guard let vc = keyboardVC else { return }
                            vc.textProcessor.processText(
                                proxy: vc.textDocumentProxy,
                                mode: mode,
                                dictationState: dictationState
                            )
                        },
                        onOpenApp: {
                            openMainApp()
                        },
                        onBackspace: { controller.textDocumentProxy.deleteBackward() },
                        onNewline: { controller.textDocumentProxy.insertText("\n") },
                        onSpace: { controller.textDocumentProxy.insertText(" ") }
                    )
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
                                        controller: keyboardVC,
                                        hasFullAccess: hasFullAccess,
                                        onShowFullAccessPrompt: {
                                            withAnimation(.spring(duration: 0.35)) {
                                                showFullAccessPrompt = true
                                            }
                                        }
                                    )
                                    .environment(self.dictationState)
                                }
                            )
                        }
                    }
                }
            }
            .opacity(showFullAccessPrompt ? 0 : 1)

            // Full access prompt overlay with slide-up animation
            if showFullAccessPrompt {
                FullAccessPromptView(onDismiss: {
                    withAnimation(.spring(duration: 0.35)) {
                        showFullAccessPrompt = false
                    }
                })
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
    }

    private func openMainApp() {
        var urlString = "vivadicta://activate-for-keyboard"
        if let hostId = keyboardVC?.hostApplicationBundleId {
            if let encodedHostId = hostId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?hostId=\(encodedHostId)"
            }
        }
        if let url = URL(string: urlString) {
            openURL(url)
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
                .foregroundStyle(.orange)
                .padding(.bottom, 10)

            // Error message
            Text("Error")
                .font(.system(size: 24, weight: .semibold))

            Text(errorMessage)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Dismiss button
            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 44)
                    .background(Color.blue)
                    .cornerRadius(22)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}
