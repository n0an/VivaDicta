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
    @ObservedObject private var keyboardContext: KeyboardContext
    @State private var processingStage: ProcessingStage = .waitingToStart
    @State private var showFullAccessPrompt = false
    /// Mirrors `AppGroupCoordinator.shared.isCurrentlyRussian` so that taps on
    /// the EN/RU toggle key invalidate the view (UserDefaults writes don't
    /// trigger SwiftUI updates by themselves). Updated by the
    /// `.vivaDictaLanguageToggled` notification.
    @State private var isCurrentlyRussian = AppGroupCoordinator.shared.isCurrentlyRussian
    /// Mirrors `AppGroupCoordinator.shared.isRussianLayoutEnabled`. Refreshed on
    /// `onAppear` so changes made in Settings while the keyboard was offscreen
    /// are picked up the next time the keyboard becomes active.
    @State private var isRussianLayoutEnabled = AppGroupCoordinator.shared.isRussianLayoutEnabled

    let controller: KeyboardInputViewController

    init(controller: KeyboardInputViewController) {
        self.controller = controller
        self._keyboardContext = ObservedObject(wrappedValue: controller.state.keyboardContext)
    }

    private var hasFullAccess: Bool {
        controller.hasFullAccess
    }

    private var keyboardVC: KeyboardViewController? {
        controller as? KeyboardViewController
    }

    /// Whether the keyboard should currently render the Russian letter rows.
    /// True only when the user has the Russian layout enabled AND has tapped
    /// the EN/RU toggle to switch to Russian.
    private var useRussianLayout: Bool {
        isRussianLayoutEnabled && isCurrentlyRussian
    }

    /// Resolves the keyboard layout for the current rendering pass.
    ///
    /// Layout selection:
    /// - QWERTY (Latin) without Russian enabled: return `nil` so `KeyboardView`
    ///   regenerates the standard layout internally on every context change.
    ///   This preserves the dynamic shift action (`KeyboardAction.shift`
    ///   encodes the current case in its associated value, so a frozen layout
    ///   breaks shift cycling).
    /// - AZERTY (Latin): rewrite letter rows on every render. Reading
    ///   `keyboardContext` via `@ObservedObject` forces re-render when the
    ///   case changes, which gives us a fresh `.standard(for:)` layout with
    ///   the correct shift action.
    /// - Russian (when EN/RU toggle is on the Russian side): rewrite to ЙЦУКЕН.
    ///
    /// Letter-row rewrites are only applied to `.alphabetic`. The numeric
    /// (`123`) and symbolic (`#+=`) layouts also contain `.character` items
    /// (digits, punctuation), so rewriting them would corrupt those inputs.
    ///
    /// The EN/RU toggle key is only injected when `isRussianLayoutEnabled` is
    /// `true` - English-only users see no UI changes.
    private var currentLayout: KeyboardLayout? {
        // When Russian is disabled and the user is on QWERTY, return nil so
        // KeyboardKit handles everything natively (cheapest path).
        if !isRussianLayoutEnabled, AppGroupCoordinator.shared.keyboardLayoutStyle == .qwerty {
            return nil
        }

        let base = KeyboardLayout.standard(for: keyboardContext)
        guard keyboardContext.keyboardType == .alphabetic else {
            return base
        }

        var result: KeyboardLayout
        if useRussianLayout {
            result = RussianLayout.rewrite(base)
        } else {
            switch AppGroupCoordinator.shared.keyboardLayoutStyle {
            case .qwerty: result = base
            case .azerty: result = AzertyLayout.rewrite(base)
            }
        }

        if isRussianLayoutEnabled {
            injectLanguageToggle(into: &result)
        }
        return result
    }

    /// Inserts a `.custom("vd-lang-toggle")` item into the bottom row,
    /// immediately to the left of space. We anchor on `.space` rather than
    /// `.nextKeyboard` because iOS 18+ system custom keyboards often render
    /// the globe outside KeyboardKit's row (as a system-level input switcher),
    /// which would make `.nextKeyboard` absent and the insertion silently fail.
    ///
    /// `.percentage(0.1)` keeps the key narrow (10% of total keyboard width,
    /// roughly globe-key sized) so the space bar keeps most of the row.
    private func injectLanguageToggle(into layout: inout KeyboardLayout) {
        let action = KeyboardAction.custom(named: vivaDictaLanguageToggleActionName)
        let item = layout.createIdealItem(for: action, width: .percentage(0.1))
        layout.itemRows.insert(item, before: .space)
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
                                buttonContent: { params in
                                    if case .custom(let name) = params.item.action,
                                       name == vivaDictaLanguageToggleActionName {
                                        Text(useRussianLayout ? "EN" : "RU")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary)
                                    } else {
                                        params.view
                                    }
                                },
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
                                if useRussianLayout {
                                    return RussianCallouts.actionsBuilder(params)
                                }
                                switch AppGroupCoordinator.shared.keyboardLayoutStyle {
                                case .azerty: return AzertyCallouts.actionsBuilder(params)
                                case .qwerty: return params.standardActions()
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
        .onChange(of: dictationState.pendingObsidianURL) { _, newURL in
            guard let url = newURL else { return }
            openURL(url)
            dictationState.pendingObsidianURL = nil
        }
        .onAppear {
            // Settings may have been changed while the keyboard was offscreen.
            isRussianLayoutEnabled = AppGroupCoordinator.shared.isRussianLayoutEnabled
            isCurrentlyRussian = AppGroupCoordinator.shared.isCurrentlyRussian
        }
        .onReceive(NotificationCenter.default.publisher(for: .vivaDictaLanguageToggled)) { _ in
            isCurrentlyRussian = AppGroupCoordinator.shared.isCurrentlyRussian
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
