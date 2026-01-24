//
//  TranscriptionDetailView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI
import CoreSpotlight

private enum TextDisplayType: String, CaseIterable, Identifiable {
    var id: Self { self }

    case original = "Original"
    case enhanced = "Enhanced"
}

struct TranscriptionDetailView: View {
    var transcription: Transcription
    @Environment(AppState.self) var appState

    @State private var selectedTextType: TextDisplayType = .enhanced
//    @State private var spotlightTask: Task<Void, Never>?
    
    @State private var isExpanded: Bool = false
    @Namespace private var namespace

    @State private var processingState: RecordingState = .idle
    @State private var processingTask: Task<Void, Never>?
    @State private var isShimmering: Bool = false
    @State private var showGuardrailAlert: Bool = false
    @State private var isMetaInfoExpanded: Bool = false

    // Ripple effect state for processing animations
    @State private var rippleEffectTimer: Timer?
    @State private var rippleEffectTrigger = false

    private var hasEnhancedText: Bool {
        transcription.enhancedText != nil
    }

    private var displayedText: String {
        if selectedTextType == .enhanced, let enhancedText = transcription.enhancedText {
            return enhancedText
        }
        return transcription.text
    }

    private var audioURL: URL? {
        guard let audioFileName = transcription.audioFileName, !audioFileName.isEmpty else { return nil }
        let url = FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var canRetranscribe: Bool {
        audioURL != nil && processingState == .idle
    }

    private var canEnhance: Bool {
        !transcription.text.isEmpty && processingState == .idle && appState.aiService.isProperlyConfigured()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed header section
            VStack(alignment: .leading, spacing: 8) {
                if let audioURL = audioURL {
                    AudioPlayerView(audioFileName: audioURL.lastPathComponent)
                        .padding(.bottom, 8)
                }

                HStack {
                    Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()

                    Text(transcription.getDurationFormatted(transcription.audioDuration))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(.rect(cornerRadius: 6))
                }

                // Segmented control - only show if enhanced text exists
                if hasEnhancedText {
                    Picker("Text type", selection: $selectedTextType) {
                        ForEach(TextDisplayType.allCases) { type in
                            if type == .enhanced {
                                Label(type.rawValue, systemImage: "sparkles")
                            } else {
                                Text(type.rawValue)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .onChange(of: selectedTextType) { _, _ in
                        HapticManager.selectionChanged()
                        isMetaInfoExpanded = false
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical)

            // ViewThatFits chooses the layout that fits available space
            ViewThatFits(in: .vertical) {
                // Option 1: Everything fits - no scroll, metadata flows below text
                // Button expands DOWN because there's space below
                VStack(alignment: .leading, spacing: 0) {
                    textContentView
                    copyButton
                    retranscribeButton(expandDirection: .down)
                    Spacer()
                    metadataSection
                }
                .padding(.horizontal)
                .contentShape(.rect)
                .onTapGesture {
                    collapseIfExpanded()
                }

                // Option 2: Content too tall - text scrolls, metadata fixed at bottom
                // Button expands UP because metadata is fixed below
                VStack(spacing: 0) {
                    ScrollView {
                        textContentView
                            .padding(.horizontal)
                    }
                    .onScrollPhaseChange { _, newPhase in
                        if newPhase == .interacting || newPhase == .decelerating {
                            collapseIfExpanded()
                        }
                    }

                    copyButton
                        .padding(.horizontal)

                    retranscribeButton(expandDirection: .up)
                        .padding(.horizontal)

                    metadataSection
                        .padding(.horizontal)
                }
                .contentShape(.rect)
                .onTapGesture {
                    collapseIfExpanded()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                shareMenu
            }
        }
        .onAppear {
            let activity = appState.userActivity(for: transcription)
            activity.becomeCurrent()

            // Update Spotlight ranking for frequently accessed items
//            spotlightTask = Task {
//                await appState.updateSpotlightRanking(for: transcription)
//            }
        }
        .onDisappear {
//            spotlightTask?.cancel()
//            spotlightTask = nil
            processingTask?.cancel()
            processingTask = nil
            rippleEffectTimer?.invalidate()
            rippleEffectTimer = nil
        }
        .animation(.spring, value: isExpanded)
        .animation(.easeInOut, value: processingState)
        .allowsHitTesting(processingState == .idle)
        .overlay {
            if processingState == .transcribing || processingState == .enhancing {
                GeometryReader { geometry in
                    AnimatedMeshGradient()
                        .onAppear {
                            rippleEffectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
                                Task { @MainActor in
                                    if processingState == .transcribing || processingState == .enhancing {
                                        rippleEffectTrigger.toggle()
                                    }
                                }
                            })
                            rippleEffectTimer?.fire()
                        }
                        .onDisappear {
                            rippleEffectTimer?.invalidate()
                            rippleEffectTimer = nil
                        }
                        .mask(
                            RoundedRectangle(cornerRadius: 44, style: .continuous)
                                .stroke(lineWidth: 44)
                                .blur(radius: 22)
                        )
                        .ignoresSafeArea()
                        .modifier(RippleEffect(at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2), trigger: rippleEffectTrigger))
                }
            }
        }
        .overlay {
            if processingState == .transcribing || processingState == .enhancing {
                HudView(
                    state: processingState,
                    onCancel: {
                        cancelProcessing()
                    }
                )
            }
        }
        .animation(.default, value: processingState)
        .alert(
            "AI Safety Guardrail Triggered",
            isPresented: $showGuardrailAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple's on-device AI blocked this content due to safety guidelines. Consider using a cloud AI provider for this type of content.")
        }
    }

    private var textContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(displayedText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .lineSpacing(2)
                .textSelection(.enabled)
                .redacted(reason: processingState != .idle ? .placeholder : [])
        }
        .modifier(ConditionalShimmer(isActive: isShimmering))
    }

    private var copyButton: some View {
        HStack {
            if selectedTextType == .enhanced && hasEnhancedText {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                    Text("Enhanced")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.blue)
                }
            } else {
                Text("Original")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            AnimatedCopyButton(textToCopy: displayedText) {
                triggerCopyAnimation()
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func triggerCopyAnimation() {
        isShimmering = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            isShimmering = false
        }
    }
    
    
    
    @ViewBuilder
    private func retranscribeButton(expandDirection: LiquidButtonExpandDirection) -> some View {
        
        HStack {
            Spacer()
            
            if #available(iOS 26.0, *) {
                
                if !appState.aiService.isProperlyConfigured() { // Only 1 option - transcribe - run it right away
                    Button {
                        retranscribe()
                    } label: {
                        HStack {
                            if processingState != .idle {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20, weight: .medium))
                            }
                            
                            Text(processingState == .transcribing ? "Transcribing..." :
                                    processingState == .enhancing ? "Enhancing..." : "Regenerate")
                            .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .frame(height: 40)
                    }
                    .glassEffect(.regular.tint(.green.opacity(0.2)).interactive())
                    .buttonStyle(.plain)
                    .disabled(processingState != .idle)
                    
                } else { // Expand button to show 3 options
                    GlassEffectContainer(spacing: 18) {
                        if isExpanded {
                            VStack(alignment: .trailing, spacing: 18) {
                                
                                HStack {
                                    Text("Transcribe + Enhance")
                                        .transition(.move(edge: .leading))
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 200, alignment: .trailing)
                                    
                                    Button {
                                        isExpanded = false
                                        retranscribeAndEnhance()
                                    } label: {
                                        
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundStyle(.green)
                                            .font(.system(size: 28, weight: .medium))
                                            .frame(width: 40, height: 40)
                                    }
                                    .glassEffect(.regular.tint(.green.opacity(0.2)).interactive())
                                    .glassEffectID("both", in: namespace)
                                    .buttonStyle(.plain)
                                    .disabled(!canRetranscribe)
                                }
                                
                                
                                HStack {
                                    Text("Transcribe")
                                        .transition(.move(edge: .leading))
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 100, alignment: .trailing)
                                    
                                    Button {
                                        isExpanded = false
                                        retranscribe()
                                    } label: {
                                        
                                        Image(systemName: "waveform.mid")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundStyle(.orange)
                                            .frame(width: 40, height: 40)
                                    }
                                    .glassEffect(.regular.tint(.orange.opacity(0.2)).interactive())
                                    .glassEffectID("transcribe", in: namespace)
                                    .buttonStyle(.plain)
                                    .disabled(!canRetranscribe)
                                }
                                
                                HStack {
                                    Text("Enhance")
                                        .transition(.move(edge: .leading))
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 100, alignment: .trailing)
                                    
                                    Button {
                                        isExpanded = false
                                        enhance()
                                    } label: {
                                        
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.teal)
                                            .font(.system(size: 20, weight: .medium))
                                            .frame(width: 40, height: 40)
                                    }
                                    .glassEffect(.regular.tint(.teal.opacity(0.2)).interactive())
                                    .glassEffectID("enhance", in: namespace)
                                    .buttonStyle(.plain)
                                    .disabled(!canEnhance)
                                }
                            }
                            
                        } else {
                            
                            Button {
                                HapticManager.lightImpact()
                                isExpanded = true
                                isMetaInfoExpanded = false
                            } label: {
                                HStack {
                                    if processingState != .idle {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 20, weight: .medium))
                                    }
                                    
                                    Text(processingState == .transcribing ? "Transcribing..." :
                                            processingState == .enhancing ? "Enhancing..." : "Regenerate")
                                    .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .frame(height: 40)
                            }
                            .glassEffect(.regular.tint(.green.opacity(0.2)).interactive())
                            .glassEffectID("regenerate", in: namespace)
                            .buttonStyle(.plain)
                            .disabled(processingState != .idle)
                        }
                        
                    }
                }
                
                
                
                
            } else { // iOS 18 Fallback
                
                if !appState.aiService.isProperlyConfigured() {
                    simpleRetranscribeButton
                } else {
                    HStack {
                        Text("Regenerate")
                            .font(.system(size: 14).weight(.medium))
                            .foregroundStyle(.secondary)
                            .opacity(isExpanded ? 0 : 1)
                        
                        // Full liquid button with 3 options
                        LiquidActionButtonView(
                            isExpanded: $isExpanded,
                            processingState: processingState,
                            canRetranscribe: canRetranscribe,
                            canEnhance: canEnhance,
                            expandDirection: expandDirection,
                            onRetranscribeAndEnhance: {
                                isExpanded = false
                                retranscribeAndEnhance()
                            },
                            onRetranscribe: {
                                isExpanded = false
                                retranscribe()
                            },
                            onEnhance: {
                                isExpanded = false
                                enhance()
                            }
                        )
                    }
                }
            }
        }
    }

    /// Simple retranscribe button for iOS 18 when AI enhancement is not available
    private var simpleRetranscribeButton: some View {
        Button {
            retranscribe()
        } label: {
            HStack {
                if processingState != .idle {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .medium))
                }

                Text(processingState == .transcribing ? "Transcribing..." : "Regenerate")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.green.opacity(0.2))
                    .shadow(color: .white.opacity(0.2), radius: 0, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.2), radius: 0, x: 1, y: 1)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 4, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canRetranscribe)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()

            DisclosureGroup("Meta Info", isExpanded: $isMetaInfoExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    metadataRow(icon: "hourglass", label: "Audio Duration", value: transcription.getDurationFormatted(transcription.audioDuration))
                    
                    #if DEBUG
                    if audioURL != nil {
                        metadataRow(icon: "doc.fill", label: "Audio File Size", value: transcription.getAudioFileSizeFormatted())
                    }
                    #endif
                    
                    if let providerName = transcription.transcriptionProviderName {
                        metadataRow(icon: "waveform", label: "Transcription Provider", value: providerName)
                    }
                    if let modelName = transcription.transcriptionModelName {
                        metadataRow(icon: "character.bubble", label: "Transcription Model", value: modelName)
                    }
                    
                    if let providerName = transcription.aiProviderName {
                        Divider()
                        metadataRow(icon: "sparkles", label: "AI Provider", value: providerName)
                    }
                    if let aiModel = transcription.aiEnhancementModelName {
                        metadataRow(icon: "wand.and.sparkles", label: "AI Model", value: aiModel)
                    }
                    if let promptName = transcription.promptName {
                        metadataRow(icon: "text.bubble.fill", label: "Prompt Used", value: promptName)
                    }
                    #if DEBUG
                    if let duration = transcription.transcriptionDuration {
                        metadataRow(icon: "clock.fill", label: "Transcription Time", value: transcription.getDurationFormatted(duration))
                        metadataRow(icon: "figure.run.circle.fill", label: "Transcription Factor", value: transcription.getFactor(audioDuration: transcription.audioDuration, transcriptionDuration: duration))
                    }
                    if let duration = transcription.enhancementDuration {
                        metadataRow(icon: "clock.fill", label: "Enhancement Time", value: transcription.getDurationFormatted(duration))
                    }
                    #endif
                }
                .padding(.top, 10)
            }
            .padding(.vertical)
        }
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var shareMenu: some View {
        Menu {
            Section("Share") {
                if let enhancedText = transcription.enhancedText {
                    ShareLink(item: enhancedText) {
                        Label("Enhanced Text", systemImage: "sparkles")
                    }
                }

                ShareLink(item: transcription.text) {
                    Label("Original Text", systemImage: "text.alignleft")
                }

                if let audioURL = audioURL {
                    Divider()
                    ShareLink(
                        item: audioURL,
                        preview: SharePreview(
                            "Recording \(transcription.timestamp.formatted(date: .abbreviated, time: .shortened))",
                            image: Image(systemName: "waveform")
                        )
                    ) {
                        Label("Audio Recording", systemImage: "waveform")
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .offset(y: -2)
        }
        .accessibilityLabel("Share Transcription")
    }

    // MARK: - Actions

    private func collapseIfExpanded() {
        if isExpanded {
            isExpanded = false
        }
    }

    private func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        processingState = .idle
    }

    private func retranscribe() {
        guard let audioURL = audioURL else { return }
        HapticManager.lightImpact()
        isMetaInfoExpanded = false

        processingTask = Task {
            processingState = .transcribing

            do {
                let transcriptionStart = Date()
                let newText = try await appState.transcriptionManager.transcribe(audioURL: audioURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                transcription.text = newText
                transcription.transcriptionModelName = appState.transcriptionManager.getCurrentTranscriptionModel()?.displayName
                transcription.transcriptionProviderName = appState.transcriptionManager.currentMode.transcriptionProvider.displayName
                transcription.transcriptionDuration = transcriptionDuration

                // Update Spotlight index (non-blocking to avoid SwiftData actor isolation issues)
                let entity = transcription.entity
                Task.detached {
                    await appState.updateTranscriptionEntityInSpotlight(entity)
                }

                HapticManager.heartbeat()

                // Request app rating after successful retranscribe
                RateAppManager.requestReviewIfAppropriate()
            } catch is CancellationError {
                // Task was cancelled, don't show error haptic
            } catch {
                if Task.isCancelled { return }
                HapticManager.error()
            }

            processingState = .idle
        }
    }

    private func enhance() {
        guard !transcription.text.isEmpty else { return }
        HapticManager.lightImpact()
        isMetaInfoExpanded = false

        processingTask = Task {
            processingState = .enhancing

            do {
                let (enhancedText, duration, promptName) = try await appState.aiService.enhance(transcription.text)

                transcription.enhancedText = enhancedText
                transcription.aiEnhancementModelName = appState.aiService.selectedMode.aiModel
                transcription.aiProviderName = appState.aiService.selectedMode.aiProvider?.displayName
                transcription.promptName = promptName
                transcription.enhancementDuration = duration

                // Switch to enhanced view
                selectedTextType = .enhanced

                // Update Spotlight index (non-blocking to avoid SwiftData actor isolation issues)
                let entity = transcription.entity
                Task.detached {
                    await appState.updateTranscriptionEntityInSpotlight(entity)
                }

                HapticManager.heartbeat()

                // Request app rating after successful enhance
                RateAppManager.requestReviewIfAppropriate()
            } catch is CancellationError {
                // Task was cancelled, don't show error haptic
            } catch let error as AppleFoundationModelError {
                // Don't return early - let processingState be reset
                if case .guardrailViolation = error {
                    showGuardrailAlert = true
                }
                HapticManager.error()
            } catch {
                // Don't return early - let processingState be reset
                HapticManager.error()
            }

            processingState = .idle
        }
    }

    private func retranscribeAndEnhance() {
        guard let audioURL = audioURL else { return }
        HapticManager.lightImpact()
        isMetaInfoExpanded = false

        processingTask = Task {
            processingState = .transcribing

            do {
                // Step 1: Transcribe
                let transcriptionStart = Date()
                let newText = try await appState.transcriptionManager.transcribe(audioURL: audioURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                transcription.text = newText
                transcription.transcriptionModelName = appState.transcriptionManager.getCurrentTranscriptionModel()?.displayName
                transcription.transcriptionProviderName = appState.transcriptionManager.currentMode.transcriptionProvider.displayName
                transcription.transcriptionDuration = transcriptionDuration

                // Step 2: Enhance (if AI is configured)
                if appState.aiService.isProperlyConfigured() {
                    processingState = .enhancing

                    do {
                        let (enhancedText, duration, promptName) = try await appState.aiService.enhance(newText)

                        transcription.enhancedText = enhancedText
                        transcription.aiEnhancementModelName = appState.aiService.selectedMode.aiModel
                        transcription.aiProviderName = appState.aiService.selectedMode.aiProvider?.displayName
                        transcription.promptName = promptName
                        transcription.enhancementDuration = duration

                        // Switch to enhanced view
                        selectedTextType = .enhanced
                    } catch let error as AppleFoundationModelError {
                        if case .guardrailViolation = error {
                            showGuardrailAlert = true
                        }
                        // Transcription still saved, just without enhancement
                    } catch {
                        // Enhancement failed, transcription still saved
                    }
                }

                // Update Spotlight index (non-blocking to avoid SwiftData actor isolation issues)
                let entity = transcription.entity
                Task.detached {
                    await appState.updateTranscriptionEntityInSpotlight(entity)
                }

                HapticManager.heartbeat()

                // Request app rating after successful retranscribe and enhance
                RateAppManager.requestReviewIfAppropriate()
            } catch is CancellationError {
                // Task was cancelled, don't show error haptic
            } catch {
                // Don't return early - let processingState be reset
                HapticManager.error()
            }

            processingState = .idle
        }
    }
}

#Preview {
    TranscriptionDetailView(transcription: Transcription.mockData[0])
        .environment(AppState())
}
