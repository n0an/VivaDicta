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

    private var currentLayout: KeyboardLayout {
        let base = KeyboardLayout.standard(for: controller.state.keyboardContext)
        return base.applying(AppGroupCoordinator.shared.keyboardLayoutStyle)
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
                } else if dictationState.activeTab == .recentNotes {
                    RecentNotesView(
                        onNoteSelected: { text in
                            controller.textDocumentProxy.insertText(text)
                            HapticManager.heartbeat()
                        },
                        onOpenApp: {
                            openMainApp()
                        },
                        onBackspace: { controller.textDocumentProxy.deleteBackward() },
                        onDeleteWord: { deleteWordBeforeCursor() },
                        onNewline: { controller.textDocumentProxy.insertText("\n") },
                        onSpace: { controller.textDocumentProxy.insertText(" ") },
                        onRevert: { charCount in
                            for _ in 0..<charCount {
                                controller.textDocumentProxy.deleteBackward()
                            }
                            HapticManager.lightImpact()
                        }
                    )
                } else if dictationState.activeTab == .textProcessing {
                    RewriteModesView(
                        onPresetSelected: { mode, presetId in
                            guard let vc = keyboardVC else { return }
                            vc.textProcessor.processText(
                                proxy: vc.textDocumentProxy,
                                mode: mode,
                                presetId: presetId,
                                dictationState: dictationState
                            )
                        },
                        onOpenApp: {
                            openMainApp()
                        },
                        onBackspace: { controller.textDocumentProxy.deleteBackward() },
                        onDeleteWord: { deleteWordBeforeCursor() },
                        onNewline: { controller.textDocumentProxy.insertText("\n") },
                        onSpace: { controller.textDocumentProxy.insertText(" ") }
                    )
                } else {
                    switch dictationState.uiState {
                    case .recording:
                        RecordingStateView(
                            dictationState: dictationState,
                            onBackspace: { controller.textDocumentProxy.deleteBackward() },
                            onDeleteWord: { deleteWordBeforeCursor() },
                            onNewline: { controller.textDocumentProxy.insertText("\n") },
                            onSpace: { controller.textDocumentProxy.insertText(" ") }
                        )

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
                                layout: currentLayout,
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
                            .keyboardCalloutActions { params in
                                switch AppGroupCoordinator.shared.keyboardLayoutStyle {
                                case .azerty: AzertyCallouts.actionsBuilder(params)
                                case .qwerty: params.standardActions()
                                }
                            }
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

    private func deleteWordBeforeCursor() {
        let proxy = controller.textDocumentProxy
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else {
            proxy.deleteBackward()
            return
        }
        // Walk backward: skip trailing whitespace, then skip the word
        var index = before.endIndex
        // Skip trailing whitespace
        while index > before.startIndex {
            let prev = before.index(before: index)
            if !before[prev].isWhitespace { break }
            index = prev
        }
        // Skip word characters
        while index > before.startIndex {
            let prev = before.index(before: index)
            if before[prev].isWhitespace { break }
            index = prev
        }
        let charsToDelete = max(before.distance(from: index, to: before.endIndex), 1)
        for _ in 0..<charsToDelete {
            proxy.deleteBackward()
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
