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

        let mode = dictationState.vivaModeManager.selectedVivaMode
        if mode.obsidianEnabled,
           let output = ObsidianURLBuilder.build(text: finalText, mode: mode, presetName: nil) {
            ClipboardManager.copyToClipboard(output.clipboardText)
            logger.logInfo("⌨️ Obsidian: queueing \(output.url.absoluteString)")
            dictationState.pendingObsidianURL = output.url
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
        switch dictationState.activeTab {
        case .keyboard: "sparkles"
        case .textProcessing: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .recentNotes: "keyboard"
        }
    }

    @State private var isGlowAnimating = false

    var body: some View {
        Button {
            HapticManager.selectionChanged()
            switch dictationState.activeTab {
            case .keyboard: dictationState.activeTab = .textProcessing
            case .textProcessing: dictationState.activeTab = .recentNotes
            case .recentNotes: dictationState.activeTab = .keyboard
            }
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
        .glassCapsule(fallback: .quaternary)
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
            // Tab switcher button + Mode selector on the left
            HStack(spacing: 24) {
                KeyboardTabToggle(dictationState: dictationState)
                ModeCycleSelector(dictationState: dictationState)
            }

            Spacer()

            // Always show MicButton - it handles notReady state by opening main app
            KeyboardMicButton(onTapAction: handleMic)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
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

private struct KeyboardMicButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let onTapAction: () -> Void

    var body: some View {
        Button {
            onTapAction()
        } label: {
            icon
                .padding(16)
                .background(background)
        }
        .accessibilityLabel("Record")
    }

    private var icon: some View {
        
        Image(systemName: "microphone.fill")
            .font(.system(size: 26))
            .foregroundStyle(.white)
        
    }

    @ViewBuilder
    private var background: some View {
        if #available(iOS 26, *) {
            styledBackground
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            styledBackground
        }
    }

    @ViewBuilder
    private var styledBackground: some View {
        if colorScheme == .dark {
            KeyboardDarkMicGradientBackground()
        } else {
            KeyboardLightMicGradientBackground()
        }
    }
}

private struct KeyboardDarkMicGradientBackground: View {
    var body: some View {
        ZStack {
            // Keep a static gradient under the mesh so keyboard rendering glitches
            // fall back to color instead of a black ring.
            LinearGradient(
                colors: [.red, .purple, .indigo, .blue, .mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            KeyboardAnimatedMeshGradient()
        }
        .mask(
            Circle()
                .stroke(lineWidth: 12)
                .blur(radius: 5)
        )
        .blendMode(.lighten)
        .overlay(
            Circle()
                .stroke(lineWidth: 1.5)
                .fill(Color.white)
                .blur(radius: 1)
                .blendMode(.overlay)
        )
        .overlay(
            Circle()
                .stroke(lineWidth: 0.4)
                .fill(Color.white)
                .blur(radius: 0.3)
                .blendMode(.overlay)
        )
        .background(.black)
        .clipShape(.circle)
    }
}

private struct KeyboardLightMicGradientBackground: View {
    var body: some View {
        ZStack {
            // Keep a static gradient under the mesh so keyboard rendering glitches
            // fall back to color instead of a washed-out circle.
            LinearGradient(
                colors: [.blue, .indigo, .purple, .orange, .mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            KeyboardAnimatedMeshGradient2()
        }
        .overlay(
            Circle()
                .stroke(lineWidth: 3)
                .fill(Color.black.opacity(0.7))
                .blur(radius: 2)
                .blendMode(.overlay)
        )
        .overlay(
            Circle()
                .stroke(lineWidth: 1)
                .fill(Color.black.opacity(1.0))
                .blur(radius: 1)
                .blendMode(.overlay)
        )
        .clipShape(.circle)
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
    }
}

private struct KeyboardAnimatedMeshGradient: View {
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
            MeshGradient(width: 3, height: 3, points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                [keyboardSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), keyboardSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                [keyboardSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), keyboardSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                [keyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), keyboardSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                [keyboardSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), keyboardSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                [keyboardSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), keyboardSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                [keyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), keyboardSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
            ], colors: [
                .red, .purple, .indigo,
                .orange, .white, .blue,
                .yellow, .black, .mint
            ])
        }
    }
}

private struct KeyboardAnimatedMeshGradient2: View {
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
            MeshGradient(width: 3, height: 3, points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                [keyboardSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), keyboardSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                [keyboardSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), keyboardSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                [keyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), keyboardSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                [keyboardSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), keyboardSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                [keyboardSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), keyboardSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                [keyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), keyboardSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
            ], colors: [
                .blue, .red, .orange,
                .orange, .indigo, .red,
                .cyan, .purple, .mint
            ])
        }
    }
}

private func keyboardSinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
    let amplitude = (range.upperBound - range.lowerBound) / 2
    let midPoint = (range.upperBound + range.lowerBound) / 2
    return midPoint + amplitude * sin(timeScale * t + offset)
}
