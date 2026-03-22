//
//  KeyboardViewController.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import UIKit
import KeyboardKit
import SwiftUI
import os

class KeyboardViewController: KeyboardInputViewController {

    let dictationState = KeyboardDictationState()
    let textProcessor = KeyboardTextProcessor()

    private func handleTranscription(_ text: String) {
        guard !text.isEmpty else { return }

        let finalText: String
        if dictationState.vivaModeManager.selectedVivaMode.isSmartInsertEnabled {
            let context = TextInsertionFormatter.getInsertionContext(from: textDocumentProxy)
            finalText = TextInsertionFormatter.formatTextForInsertion(text, context: context)
        } else {
            finalText = text
        }

        textDocumentProxy.insertText(finalText)

        AppGroupCoordinator.shared.recordKeyboardSuccessfulUse()

        if AppGroupCoordinator.shared.isKeepTranscriptInClipboardEnabled {
            ClipboardManager.copyToClipboard(finalText)
        }
    }
    
    
    // MARK: - Properties
    let logger = Logger(category: .keyboardExtension)
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dictationState.onTranscriptionReady = { [weak self] text in
            self?.handleTranscription(text)
        }

        dictationState.start()
        
        // Create keyboard app configuration
        let keyboardApp = KeyboardApp(
            name: "VivaDicta Keyboard",
            appGroupId: AppGroupCoordinator.shared.appGroupId,
            deepLinks: .init(app: "vivadicta://")
        )

        // Setup the keyboard
        setup(for: keyboardApp) { [weak self] result in
            self?.logger.logInfo("Keyboard setup result: \(String(describing: result))")
        }

        // Configure haptic feedback based on user preference
        state.feedbackContext.settings.isHapticFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled
        
        // Configure sound feedback based on user preference
        state.feedbackContext.settings.isAudioFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled
    }
    
    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()

        // Setup the keyboard view with our custom view that switches based on state
        setupKeyboardView { [weak self] controller in
            KeyboardCustomView(controller: controller)
                .environment(self?.dictationState ?? KeyboardDictationState())
        }
    }
    
    deinit {
        dictationState.stop()
    }

}


// MARK: - Keyboard Tab Toggle
struct KeyboardTabToggle: View {
    @Bindable var dictationState: KeyboardDictationState

    private var icon: String {
        dictationState.activeTab == .keyboard ? "sparkles" : "keyboard"
    }

    @State private var isGlowAnimating = false

    var body: some View {
        Button {
            HapticManager.selectionChanged()
            dictationState.activeTab = dictationState.activeTab == .keyboard
                ? .textProcessing : .keyboard
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(AngularGradient(colors: [.teal, .pink, .teal], center: .center, angle: .degrees(isGlowAnimating ? 360 : 0)))
                        .blur(radius: 10)
                        .onAppear {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                isGlowAnimating = true
                            }
                        }
                        .onDisappear {
                            isGlowAnimating = false
                        }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffectColor(isInteractive: true, color: .indigo, opacity: 0.7)
    }
}

// MARK: - Mode Cycle Selector
struct ModeCycleSelector: View {
    @Bindable var dictationState: KeyboardDictationState

    private var modes: [VivaMode] {
        dictationState.vivaModeManager.availableVivaModes
    }

    private var selectedMode: VivaMode {
        dictationState.vivaModeManager.selectedVivaMode
    }

    private var currentIndex: Int {
        modes.firstIndex(where: { $0.id == selectedMode.id }) ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left arrow - cycle backwards
            Button {
                cycleModes(forward: false)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous mode")
            .accessibilityHint("Tap to switch to previous mode")

            // Mode name
            Text(selectedMode.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 100)
            .accessibilityLabel("Current mode: \(selectedMode.name)")
            .accessibilityValue("\(currentIndex + 1) of \(modes.count)")
            

            // Right arrow - cycle forward
            Button {
                cycleModes(forward: true)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next mode")
            .accessibilityHint("Tap to switch to next mode")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.quaternary, in: .capsule)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let horizontal = value.translation.width
                    guard abs(horizontal) > abs(value.translation.height) else { return }
                    cycleModes(forward: horizontal < 0)
                }
        )
    }

    private func cycleModes(forward: Bool) {
        HapticManager.selectionChanged()
        guard modes.count > 1 else { return }

        let newIndex: Int
        if forward {
            newIndex = (currentIndex + 1) % modes.count
        } else {
            newIndex = (currentIndex - 1 + modes.count) % modes.count
        }

        dictationState.vivaModeManager.selectedVivaMode = modes[newIndex]
    }
}


struct VivaDictaKeyboardToolbarView: View {
    @Environment(KeyboardDictationState.self) var dictationState
    @Environment(\.openURL) private var openURL

    weak var controller: KeyboardViewController?
    var hasFullAccess: Bool = true
    var onShowFullAccessPrompt: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Tab segmented control + Mode selector on the left
            HStack(spacing: 16) {
                KeyboardTabToggle(dictationState: dictationState)
                ModeCycleSelector(dictationState: dictationState)
            }

            Spacer()

            // Always show MicButton - it handles notReady state by opening main app
            if #available(iOS 26.0, *) {
                MicButton(
                    fontSize: 34,
                    padding: 6,
                    backgroundColor: .orange.opacity(0.5),
                    borderWidth: 0,
                    onTapAction: handleMic)
                    .glassEffect(.regular.tint(.orange.opacity(1.0)).interactive())
            } else {
                MicButton(
                    fontSize: 36,
                    padding: 0,
                    backgroundColor: .orange,
                    borderWidth: 0.5,
                    onTapAction: handleMic)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func handleMic() {
        HapticManager.mediumImpact()

        // Check for full access first
        guard hasFullAccess else {
            onShowFullAccessPrompt?()
            return
        }

        guard dictationState.uiState != .notReady else {
            openMainAppForHotMic()
            return
        }

        if dictationState.uiState == .error {
            clearErrorState()
        }

        if dictationState.uiState == .ready {
            // Start recording when mic is tapped and ready
            dictationState.requestStartRecording()
        } else if dictationState.uiState == .recording {
            // If already recording, stop it
            dictationState.requestStopRecording()
        }
    }

    private func openMainAppForHotMic() {
        // Build URL with hostId as query parameter
        var urlString = "vivadicta://record-for-keyboard"
        if let hostId = controller?.hostApplicationBundleId {
            // URL encode the hostId to handle special characters
            // Doc - https://docs.keyboardkit.com/documentation/keyboardkit/host-article#Host-Application-Bundle-Identifier
            if let encodedHostId = hostId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?hostId=\(encodedHostId)"
            }
        }

        if let url = URL(string: urlString) {
            controller?.logger.logInfo("📱 Opening main app with URL: \(url.absoluteString)")
            openURL(url)
        }
    }

    private func clearErrorState() {
        dictationState.errorMessage = nil
        dictationState.transcriptionStatus = .idle
        AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
    }
    
    var toolbarBackgroundColor: Color {
        switch dictationState.uiState {
        case .notReady:
            return Color(.systemGray5)
        case .ready:
            return Color.green.opacity(0.15)
        case .recording:
            return Color.red.opacity(0.15)
        case .processing:
            return Color.primary.opacity(0.1)
        case .error:
            return Color.orange.opacity(0.15)
        }
    }
}
