//
//  KeyboardViewController.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import UIKit
import DesignSystem
import KeyboardKit
import SwiftUI
import AppGroup
import os
import AICore

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

        // If the main app delegated an Obsidian open (because the
        // transcription originated from the keyboard and `UIPasteboard`
        // writes from a backgrounded main app are unreliable), run it here:
        // write the clipboard from this foregrounded-host context and let
        // KeyboardCustomView open the URL via SwiftUI's openURL.
        if let handoff = AppGroupCoordinator.shared.consumePendingObsidianHandoff() {
            ClipboardManager.copyToClipboard(handoff.clipboardText)
            logger.logInfo("⌨️ Obsidian: opening delegated \(handoff.url.absoluteString)")
            dictationState.pendingObsidianURL = handoff.url
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
        setupKeyboardKit(for: keyboardApp) { [weak self] result in
            self?.logger.logInfo("Keyboard setup result: \(String(describing: result))")
        }

        // Replace the standard action handler with our subclass that intercepts
        // the EN/RU language toggle key. Must run after `setupKeyboardKit(for:)`,
        // since that is what installs the default services.
        services.actionHandler = VivaDictaActionHandler(controller: self)

        // Configure haptic feedback based on user preference
        state.feedbackContext.settings.isHapticFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardHapticFeedbackEnabled

        // Configure sound feedback based on user preference
        state.feedbackContext.settings.isAudioFeedbackEnabled = AppGroupCoordinator.shared.isKeyboardSoundFeedbackEnabled

        // Start resolving the host app now so the answer is already cached by
        // the time the user taps a button that hands off to the main app.
        startResolvingHostApplicationBundleId()
    }

    // MARK: - Host Application

    /// The in-flight (or finished) host app resolution for this keyboard session.
    ///
    /// KeyboardKit's synchronous `hostApplicationBundleId` returns `nil` from
    /// iOS 26.4 on - Apple removed the API behind it - and it is gone entirely
    /// in KeyboardKit 11. KeyboardKit 10.9 replaced it with an async resolver
    /// that has to be activated and then polled, so the bundle ID is no longer
    /// available as an instant property read.
    ///
    /// The task is deliberately *not* backed by
    /// `KeyboardContext.hostApplicationBundleId`. That property is persisted to
    /// the App Group and therefore outlives both this controller and the
    /// extension process, so reading it can hand back the bundle ID of the app
    /// the keyboard was in *last* time - which teleports the user into the
    /// wrong app.
    private var hostApplicationBundleIdTask: Task<String?, Never>?

    /// The host app's bundle ID, waiting up to `timeout` for a resolution that
    /// is still in flight.
    ///
    /// Resolution starts in `viewDidLoad`, so in practice this returns
    /// immediately. The bound only matters when the user taps within the first
    /// moments of the keyboard appearing, where stalling the button would feel
    /// worse than falling back to the main app's manual return prompt.
    func hostApplicationBundleId(waitingUpTo timeout: Duration = .seconds(1)) async -> String? {
        guard let task = hostApplicationBundleIdTask else { return nil }
        return await withTaskGroup(of: String?.self) { group in
            group.addTask { await task.value }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// The host app's bundle ID for a handoff to the main app, resolved afresh.
    ///
    /// KeyboardKit's resolver lags a change of host app. In a device capture it
    /// returned a bundle ID for an app that had been terminated for three
    /// seconds and was never the current host, 1.3s after the keyboard moved
    /// into a different app - and the main app duly relaunched that app. Every
    /// resolution in the same capture that was taken 8s or more after its host
    /// appeared was correct.
    ///
    /// The value cached at `viewDidLoad` is therefore the one most likely to be
    /// wrong, since it is taken the instant the keyboard reaches a new host. A
    /// handoff re-resolves, and falls back to the cached answer only when the
    /// fresh one cannot be had inside `timeout`.
    func hostApplicationBundleIdForHandoff(waitingUpTo timeout: Duration = .seconds(1)) async -> String? {
        let cached = hostApplicationBundleIdTask
        startResolvingHostApplicationBundleId()

        if let fresh = await hostApplicationBundleId(waitingUpTo: timeout) {
            return fresh
        }

        guard let cached else { return nil }
        logger.logNotice("🏠 Fresh host resolution timed out; falling back to the cached one")
        return await cached.value
    }

    private func startResolvingHostApplicationBundleId() {
        hostApplicationBundleIdTask = Task { [weak self] in
            guard let self else { return nil }
            let bundleId: String?
            do {
                bundleId = try await resolveHostApplicationBundleId()
            } catch {
                logger.logError("🏠 Failed to resolve host app: \(error.localizedDescription)")
                return nil
            }

            // KeyboardKit persists `hostApplicationBundleId` to the App Group
            // and, per its Host article, "will not sync the bundle ID to the
            // KeyboardContext unless absolutely necessary". Nothing here reads
            // it back - the handoff URL carries this task's value instead - so
            // writing it would only seed the *next* keyboard session with this
            // session's host. Clear it, so neither this session nor a value
            // left behind by an earlier build can outlive the keyboard.
            state.keyboardContext.hostApplicationBundleId = nil

            // `.notice` rather than `.info`: info-level entries are memory
            // backed and die with the extension process, so a wrong host was
            // invisible in any log captured after the fact.
            logger.logNotice("🏠 Resolved host app: \(bundleId ?? "nil")")
            return bundleId
        }
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
        // The host app ID rides along as a query parameter so the main app can
        // hand the user straight back once the mic is warm. Resolving it is
        // async since KeyboardKit 10.9, but has normally already finished here.
        // Doc - https://docs.keyboardkit.com/documentation/keyboardkit/host-article
        Task {
            let hostId = await controller?.hostApplicationBundleIdForHandoff()
            guard let url = URL.keyboardHandoff(
                "vivadicta://record-for-keyboard",
                hostId: hostId
            ) else { return }
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

// MARK: - Keyboard Hand-off URLs

extension URL {
    /// Builds a `vivadicta://` deep link that hands the keyboard's work over to
    /// the main app, tagging it with the host app's bundle ID when one is known.
    ///
    /// The main app reads `hostId` to teleport the user straight back to where
    /// they were typing. Without it, it falls back to asking them to switch
    /// back by hand, so an unresolved host degrades the flow rather than
    /// breaking it.
    static func keyboardHandoff(_ base: String, hostId: String?) -> URL? {
        guard let hostId,
              let encoded = hostId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return URL(string: base) }
        return URL(string: "\(base)?hostId=\(encoded)")
    }
}
