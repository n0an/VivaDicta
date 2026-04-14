//
//  TranscriptionDetailView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct TranscriptionDetailView: View {
    var transcription: Transcription
    var initialVariationPresetId: String?
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// "original" or a variation's presetId
    @State private var selectedChipId: String = "original"

    @State private var processingState: RecordingState = .idle
    @State private var processingTask: Task<Void, Never>?
    @State private var isShimmering: Bool = false
    @State private var showGuardrailAlert: Bool = false
    @State private var showEnhancementErrorAlert: Bool = false
    @State private var enhancementErrorMessage: String = ""
    @State private var showPresetPicker: Bool = false
    @State private var showExtractedRemindersSheet: Bool = false
    @State private var showMetaInfo: Bool = false
    @State private var showConfigureAI: Bool = false
    @State private var showConfigureChat: Bool = false
    @State private var generatingPresetId: String?
    @State private var streamingVariationPresetId: String?
    @State private var streamingVariationText: String = ""
    @State private var showTextEditor: Bool = false
    @State private var showTagPicker: Bool = false
    @State private var showChat: Bool = false
    @State private var chatViewModel: ChatViewModel?

    // Ripple effect state for processing animations
    @State private var rippleEffectTimer: Timer?
    @State private var rippleEffectTrigger = false

    private var sortedVariations: [TranscriptionVariation] {
        (transcription.variations ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    private var hasVariations: Bool {
        !(transcription.variations ?? []).isEmpty
    }

    private var showsVariationChipBar: Bool {
        hasVariations || temporaryGeneratingPreset != nil
    }

    private var displayedText: String {
        if selectedChipId == "original" {
            return transcription.text
        }
        if let variation = sortedVariations.first(where: { $0.presetId == selectedChipId }) {
            return variation.text
        }
        return transcription.text
    }

    private var selectedIsVariation: Bool {
        selectedChipId != "original"
    }

    private var selectedLabel: String {
        if selectedChipId == "original" { return "Original" }
        if generatingPresetId == selectedChipId,
           let preset = appState.presetManager.preset(for: selectedChipId) {
            return preset.name
        }
        if let variation = sortedVariations.first(where: { $0.presetId == selectedChipId }) {
            return PresetCatalog.displayName(for: variation.presetId, fallback: variation.presetDisplayName)
        }
        return "Original"
    }

    private var isAIConfigured: Bool {
        appState.aiService.isProperlyConfigured()
    }

    private var canOpenAISheet: Bool {
        isAIConfigured || ReminderExtractionService(aiService: appState.aiService).canExtractReminders()
    }
    
    
    @ViewBuilder
    private var aiRewriteButtonLabel: some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("AI")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(canOpenAISheet ? .white : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if canOpenAISheet {
                    if colorScheme == .dark {
                        // Dark mode: edge-glow HUD style
                        AnimatedMeshGradient()
                            .mask(
                                Capsule()
                                    .stroke(lineWidth: 14)
                                    .blur(radius: 6)
                            )
                            .blendMode(.lighten)
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 2)
                                    .fill(Color.white)
                                    .blur(radius: 1.5)
                                    .blendMode(.overlay)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 0.5)
                                    .fill(Color.white)
                                    .blur(radius: 0.5)
                                    .blendMode(.overlay)
                            )
                            .background(.black)
                            .clipShape(.capsule)
                            .glassEffect(.clear.interactive(), in: .capsule)
                    } else {
                        // Light mode: full gradient fill
                        AnimatedMeshGradient2()
                        
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 3)
                                    .fill(Color.black.opacity(0.7))
                                    .blur(radius: 2)
                                    .blendMode(.overlay)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 1)
                                    .fill(Color.black.opacity(1.0))
                                    .blur(radius: 1)
                                    .blendMode(.overlay)
                            )
                            .clipShape(.capsule)
                            .glassEffect(.clear.interactive(), in: .capsule)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                } else {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .glassEffect(.clear.interactive(), in: .capsule)
                }
            }

        } else {
            // ios 18
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("AI")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(canOpenAISheet ? .white : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if canOpenAISheet {
                    if colorScheme == .dark {
                        // Dark mode: edge-glow HUD style
                        AnimatedMeshGradient()
                            .mask(
                                Capsule()
                                    .stroke(lineWidth: 14)
                                    .blur(radius: 6)
                            )
                            .blendMode(.lighten)
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 2)
                                    .fill(Color.white)
                                    .blur(radius: 1.5)
                                    .blendMode(.overlay)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 0.5)
                                    .fill(Color.white)
                                    .blur(radius: 0.5)
                                    .blendMode(.overlay)
                            )
                            .background(.black)
                            .clipShape(.capsule)
                    } else {
                        // Light mode: full gradient fill
                        AnimatedMeshGradient2()
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 3)
                                    .fill(Color.black.opacity(0.7))
                                    .blur(radius: 2)
                                    .blendMode(.overlay)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(lineWidth: 1)
                                    .fill(Color.black.opacity(1.0))
                                    .blur(radius: 1)
                                    .blendMode(.overlay)
                            )
                            .clipShape(.capsule)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                } else {
                    Capsule()
                        .fill(Color(.systemGray5))
                }
            }

        }
    }

    @ViewBuilder
    private var chatButtonLabel: some View {
        if #available(iOS 26.0, *) {
            
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isAIConfigured ? Color.white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isAIConfigured {
                        
                        if colorScheme == .dark {
                            AnimatedMeshGradient2()
                                .mask {
                                    Capsule()
                                        .strokeBorder(lineWidth: 3)
                                        .blur(radius: 1)
                                }
                                .glassEffect(.regular.tint(.blue.opacity(0.35)).interactive())

                        } else {
                            AnimatedMeshGradient()
                                .mask {
                                    Capsule()
                                        .strokeBorder(lineWidth: 3)
                                }
                                .glassEffect(.regular.tint(.blue.opacity(0.75)).interactive())
                                .blur(radius: 1)
                        }
                        
                    } else {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .glassEffect(.clear.interactive(), in: .capsule)
                    }
                }
            
        } else {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isAIConfigured ? .primary : .secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(isAIConfigured ? .blue : Color(.systemGray5))
                }
        }
        
    }

    private var audioURL: URL? {
        guard let audioFileName = transcription.audioFileName, !audioFileName.isEmpty else { return nil }
        let url = FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var canRetranscribe: Bool {
        audioURL != nil && processingState == .idle
    }

    private var activeStreamingText: String? {
        guard processingState == .enhancing,
              streamingVariationPresetId == selectedChipId else {
            return nil
        }

        return streamingVariationText
    }

    private var shouldShowProcessingGlowOverlay: Bool {
        processingState == .transcribing || processingState == .enhancing
    }

    private var shouldShowProcessingHUD: Bool {
        processingState == .transcribing || (processingState == .enhancing && activeStreamingText == nil)
    }

    private var shouldShowStreamingCancelButton: Bool {
        processingState == .enhancing && streamingVariationPresetId != nil
    }

    private var temporaryGeneratingPreset: Preset? {
        guard let generatingPresetId,
              sortedVariations.contains(where: { $0.presetId == generatingPresetId }) == false else {
            return nil
        }

        return appState.presetManager.preset(for: generatingPresetId)
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

                // Chip bar for text variations
                if showsVariationChipBar {
                    variationChipBar
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                }
            }
            .padding(.horizontal)
            .padding(.vertical)

            ScrollView {
                textContentView
                    .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                TranscriptionTagChipsView(
                    transcription: transcription,
                    showTagPicker: $showTagPicker
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .glassEffectOrMaterial()

                bottomActionBar
            }
        }
        .sheet(isPresented: $showMetaInfo) {
            MetaInfoSheet(
                transcription: transcription,
                selectedVariation: selectedIsVariation
                    ? sortedVariations.first(where: { $0.presetId == selectedChipId })
                    : nil
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerSheet(
                presetManager: appState.presetManager,
                existingVariationIds: Set(sortedVariations.map(\.presetId)),
                onReviewExtractedTasks: transcription.pendingExtractedReminderDrafts.isEmpty ? nil : {
                    showPresetPicker = false
                    showExtractedRemindersSheet = true
                },
                onExtractTasks: canOpenAISheet ? {
                    showPresetPicker = false
                    extractReminderSuggestions()
                } : nil,
                onSelect: { preset in
                    showPresetPicker = false
                    generateVariation(preset: preset)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showExtractedRemindersSheet) {
            ExtractedRemindersSheet(transcription: transcription)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTextEditor) {
            TextEditSheet(
                text: displayedText,
                title: selectedLabel
            ) { updatedText in
                saveEditedText(updatedText)
            }
        }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet(transcription: transcription)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showConfigureAI) {
            ConfigureAISheet {
                showConfigureAI = false
                appState.shouldNavigateToModeSettings = true
            }
            .presentationDetents([.height(240)])
        }
        .sheet(isPresented: $showConfigureChat) {
            ConfigureChatSheet {
                showConfigureChat = false
                appState.shouldNavigateToModeSettings = true
            }
            .presentationDetents([.height(240)])
        }
        .fullScreenCover(isPresented: $showChat) {
            if let vm = chatViewModel {
                ChatView(viewModel: vm)
            }
        }
        .onChange(of: showChat) { _, isShowing in
            if isShowing, chatViewModel == nil {
                let conversation = findOrCreateConversation(for: transcription)
                chatViewModel = ChatViewModel(
                    conversation: conversation,
                    transcription: transcription,
                    aiService: appState.aiService,
                    modelContext: modelContext
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VivaModePicker(
                    modes: appState.aiService.modes,
                    selectedModeName: Binding(
                        get: { appState.aiService.selectedModeName },
                        set: { appState.aiService.selectedModeName = $0 }
                    )
                )
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button("Info", systemImage: "info.circle") {
                        showMetaInfo = true
                    }
                    shareMenu
                }
            }
        }
        .onAppear {
            // Auto-select chip: initial preset from search, or latest variation, or "original"
            if let presetId = initialVariationPresetId,
               sortedVariations.contains(where: { $0.presetId == presetId }) {
                selectedChipId = presetId
            } else if let latest = sortedVariations.last {
                selectedChipId = latest.presetId
            } else {
                selectedChipId = "original"
            }

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
        .animation(.easeInOut, value: processingState)
        .allowsHitTesting(processingState == .idle)
        .overlay {
            if shouldShowProcessingGlowOverlay {
                GeometryReader { geometry in
                    AnimatedMeshGradient()
                        .onAppear {
                            rippleEffectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
                                Task { @MainActor in
                                    if shouldShowProcessingGlowOverlay {
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
            if shouldShowProcessingHUD {
                HudView(
                    state: processingState,
                    onCancel: {
                        cancelProcessing()
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if shouldShowStreamingCancelButton {
                StreamingCancelButton {
                    cancelProcessing()
                }
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .alert(
            "AI Processing Failed",
            isPresented: $showEnhancementErrorAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(enhancementErrorMessage)
        }
    }

    private var textContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let activeStreamingText {
                if activeStreamingText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView()
                        Text("Generating variation...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(activeStreamingText)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
            } else if processingState != .idle {
                // Lightweight placeholder to avoid expensive CoreText layout on large text
                Text("The art of writing is the art of discovering what you believe. Every word you speak is a seed, and every thought refined becomes a garden of clarity and understanding.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .lineSpacing(2)
                    .redacted(reason: .placeholder)
            } else {
                Text(displayedText)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .lineSpacing(2)
                    .textSelection(.enabled)
            }
        }
        .modifier(ConditionalShimmer(isActive: isShimmering))
    }


    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                // Button 1: Retranscribe (Original) / Regenerate (Variation)
                Button {
                    HapticManager.lightImpact()
                    if selectedIsVariation {
                        regenerateSelectedVariation()
                    } else {
                        retranscribe()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }
                .disabled(selectedIsVariation
                          ? (appState.presetManager.preset(for: selectedChipId) == nil ||
                             generatingPresetId != nil ||
                             !appState.aiService.isProperlyConfigured())
                          : !canRetranscribe)

                Spacer()

                // Button: Tag picker
                Button {
                    HapticManager.lightImpact()
                    showTagPicker = true
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Button 2: AI Presets picker
                Button {
                    HapticManager.lightImpact()
                    if canOpenAISheet {
                        showPresetPicker = true
                    } else {
                        showConfigureAI = true
                    }
                } label: {
                    aiRewriteButtonLabel
                }
                .buttonStyle(.plain)
                .disabled(generatingPresetId != nil)

                Spacer()
                
                // Button 3: Chat with Note
                Button {
                    HapticManager.lightImpact()
                    if isAIConfigured {
                        if chatViewModel == nil {
                            let conversation = findOrCreateConversation(for: transcription)
                            chatViewModel = ChatViewModel(
                                conversation: conversation,
                                transcription: transcription,
                                aiService: appState.aiService,
                                modelContext: modelContext
                            )
                        }
                        showChat = true
                    } else {
                        showConfigureChat = true
                    }
                } label: {
                    chatButtonLabel
                }
                .buttonStyle(.plain)
                
                Spacer()

                // Button 4: Edit / Append
                Menu {
                    Button("Edit Selected Text", systemImage: "pencil") {
                        HapticManager.lightImpact()
                        showTextEditor = true
                    }

                    Button("Append with Voice", systemImage: "mic") {
                        startVoiceAppend()
                    }
                    .disabled(appState.recordViewModel.recordingState != .idle)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Button 5: Copy
                Button {
                    UIPasteboard.general.string = displayedText
                    HapticManager.success()
                    triggerCopyAnimation()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 4)
        }
        .background(.bar)
    }

    private func findOrCreateConversation(for transcription: Transcription) -> ChatConversation {
        if let existing = transcription.chatConversations?.first {
            return existing
        }
        let conversation = ChatConversation()
        conversation.transcription = transcription
        modelContext.insert(conversation)
        return conversation
    }

    private func triggerCopyAnimation() {
        isShimmering = true
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            isShimmering = false
        }
    }

    private var shareMenu: some View {
        Menu {
            Section("Share") {
                // Share currently selected text (if it's a variation)
                if selectedIsVariation {
                    let presetIcon = PresetCatalog.icon(for: selectedChipId)
                    let menuIcon = UIImage(systemName: presetIcon) != nil ? presetIcon : "sparkles"
                    ShareLink(item: displayedText) {
                        Label(selectedLabel, systemImage: menuIcon)
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

    private func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        resetStreamingState()
        processingState = .idle
    }

    private func saveEditedText(_ updatedText: String) {
        if selectedChipId == "original" {
            transcription.text = updatedText
        } else if let variation = sortedVariations.first(where: { $0.presetId == selectedChipId }) {
            variation.text = updatedText
            // Keep enhancedText in sync if this is the latest variation
            if variation.presetId == sortedVariations.last?.presetId {
                transcription.enhancedText = updatedText
            }
        }

        // Update Spotlight index
        let entity = transcription.entity
        Task.detached {
            await appState.updateTranscriptionEntityInSpotlight(entity)
        }

        // Re-index for RAG Smart Search
        Task { await RAGIndexingService.shared.indexTranscription(transcription) }

        HapticManager.success()
    }

    private func startVoiceAppend() {
        HapticManager.lightImpact()
        selectedChipId = "original"
        appState.pendingRecordingDestination = .appendToTranscription(id: transcription.id)
        appState.shouldStartRecording = true
    }

    private func retranscribe() {
        guard let audioURL = audioURL else { return }
        HapticManager.lightImpact()

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

                // Re-index for RAG Smart Search
                Task { await RAGIndexingService.shared.indexTranscription(transcription) }

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

    // MARK: - Variation Chip Bar

    private var variationChipBar: some View {
        ScrollView(.horizontal) {
            Group {
                if #available(iOS 26, *) {
                    GlassEffectContainer(spacing: 6) {
                        variationChipRow
                    }
                } else {
                    variationChipRow
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var variationChipRow: some View {
        HStack(spacing: 6) {
            variationChip(id: "original", label: "Original", icon: nil)

            ForEach(sortedVariations, id: \.id) { variation in
                variationChip(
                    id: variation.presetId,
                    label: PresetCatalog.displayName(for: variation.presetId, fallback: variation.presetDisplayName),
                    icon: PresetCatalog.icon(for: variation.presetId),
                    isLoading: generatingPresetId == variation.presetId
                )
            }

            if let temporaryGeneratingPreset {
                variationChip(
                    id: temporaryGeneratingPreset.id,
                    label: temporaryGeneratingPreset.name,
                    icon: PresetCatalog.icon(for: temporaryGeneratingPreset.id),
                    isLoading: true
                )
            }

            addVariationButton
        }
    }

    private func variationChip(id: String, label: String, icon: String?, isLoading: Bool = false) -> some View {
        let isSelected = selectedChipId == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedChipId = id
            }
            HapticManager.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else if let icon {
                    PresetIconView(icon: icon, fontSize: 11)
                }
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .glassCapsule(
                tint: isSelected ? Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.8) : nil,
                fallback: isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6)
            )
        }
        .buttonStyle(.plain)
    }

    private var addVariationButton: some View {
        Button {
            if isAIConfigured {
                showPresetPicker = true
            } else {
                showConfigureAI = true
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(.secondary)
            .glassCapsule(fallback: Color(.systemGray6))
        }
        .buttonStyle(.plain)
        .disabled(generatingPresetId != nil)
    }

    // MARK: - Generate Variation

    private func regenerateSelectedVariation() {
        guard let preset = appState.presetManager.preset(for: selectedChipId) else { return }
        generateVariation(preset: preset)
    }

    private func extractReminderSuggestions() {
        HapticManager.lightImpact()
        cancelProcessing()
        processingState = .enhancing

        let service = ReminderExtractionService(aiService: appState.aiService)
        processingTask = Task {
            do {
                _ = try await service.extractAndPersist(
                    for: transcription,
                    modelContext: modelContext
                )

                guard !Task.isCancelled else { return }
                processingState = .idle
                showExtractedRemindersSheet = true
            } catch is CancellationError {
                processingState = .idle
            } catch {
                processingState = .idle
                enhancementErrorMessage = error.localizedDescription
                showEnhancementErrorAlert = true
            }
        }
    }

    private func generateVariation(preset: Preset) {
        let shouldStreamResponse = appState.aiService.currentModeSupportsResponseStreaming
        generatingPresetId = preset.id
        streamingVariationPresetId = shouldStreamResponse ? preset.id : nil
        streamingVariationText = ""
        HapticManager.lightImpact()
        if shouldStreamResponse {
            HapticManager.prepareStreaming()
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedChipId = preset.id
        }

        processingTask = Task {
            processingState = .enhancing

            do {
                let (resultText, duration): (String, TimeInterval)
                if shouldStreamResponse {
                    (resultText, duration) = try await appState.aiService.generateVariation(
                        text: transcription.text,
                        preset: preset,
                        onPartialResult: { partialText in
                            let previousText = streamingVariationText
                            if previousText.isEmpty, partialText.isEmpty == false {
                                HapticManager.streamingStart()
                            } else if partialText.count > previousText.count {
                                HapticManager.streamingPulse()
                            }
                            streamingVariationText = partialText
                        }
                    )
                } else {
                    (resultText, duration) = try await appState.aiService.generateVariation(
                        text: transcription.text,
                        preset: preset
                    )
                }

                // Check if a variation with this presetId already exists (regeneration)
                if let existing = sortedVariations.first(where: { $0.presetId == preset.id }) {
                    existing.text = resultText
                    existing.createdAt = Date()
                    existing.aiModelName = appState.aiService.selectedMode.aiModel
                    existing.aiProviderName = appState.aiService.selectedMode.aiProvider?.displayName
                    existing.processingDuration = duration
                    existing.aiRequestSystemMessage = appState.aiService.lastSystemMessageSent
                    existing.aiRequestUserMessage = appState.aiService.lastUserMessageSent
                } else {
                    let variation = TranscriptionVariation(
                        presetId: preset.id,
                        presetDisplayName: preset.name,
                        text: resultText,
                        aiModelName: appState.aiService.selectedMode.aiModel,
                        aiProviderName: appState.aiService.selectedMode.aiProvider?.displayName,
                        processingDuration: duration,
                        aiRequestSystemMessage: appState.aiService.lastSystemMessageSent,
                        aiRequestUserMessage: appState.aiService.lastUserMessageSent
                    )
                    variation.transcription = transcription
                    modelContext.insert(variation)
                }

                transcription.enhancedText = resultText

                // Update Spotlight index (non-blocking to avoid SwiftData actor isolation issues)
                let entity = transcription.entity
                Task.detached {
                    await appState.updateTranscriptionEntityInSpotlight(entity)
                }

                resetStreamingState()
                generatingPresetId = nil

                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedChipId = preset.id
                }

                HapticManager.heartbeat()
                RateAppManager.requestReviewIfAppropriate()
            } catch is CancellationError {
                resetStreamingState()
                generatingPresetId = nil
            } catch AppleFoundationModelError.guardrailViolation {
                resetStreamingState()
                generatingPresetId = nil
                showGuardrailAlert = true
                HapticManager.error()
            } catch AppleFoundationModelError.refusal(let reason) {
                resetStreamingState()
                generatingPresetId = nil
                enhancementErrorMessage = "The AI declined to respond: \(reason)"
                showEnhancementErrorAlert = true
                HapticManager.error()
            } catch {
                resetStreamingState()
                generatingPresetId = nil
                enhancementErrorMessage = error.localizedDescription
                showEnhancementErrorAlert = true
                HapticManager.error()
            }

            processingState = .idle
        }
    }

    private func resetStreamingState() {
        streamingVariationPresetId = nil
        streamingVariationText = ""
    }
}

// MARK: - Configure AI Sheet

private struct StreamingCancelButton: View {
    let onCancel: () -> Void

    var body: some View {
        Button("Cancel", systemImage: "xmark.circle.fill") {
            HapticManager.lightImpact()
            onCancel()
        }
        .font(.subheadline.weight(.medium))
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct ConfigureAISheet: View {
    let onOpenSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("AI Processing Not Configured")
                .font(.title3.bold())

            Text("Set up an AI provider in your mode settings to use AI text processing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                onOpenSettings()
            } label: {
                Text("Open Mode Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
    }
}

private struct ConfigureChatSheet: View {
    let onOpenSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Chat Not Available")
                .font(.title3.bold())

            Text("Set up an AI provider in your mode settings to chat with your notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                onOpenSettings()
            } label: {
                Text("Open Mode Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Meta Info Sheet

private struct MetaInfoSheet: View {
    let transcription: Transcription
    let selectedVariation: TranscriptionVariation?

    var body: some View {
        NavigationStack {
            List {
                Section("Recording") {
                    metadataRow(icon: "hourglass", label: "Audio Duration", value: transcription.getDurationFormatted(transcription.audioDuration))

                    #if DEBUG
                    if transcription.audioFileName != nil {
                        metadataRow(icon: "doc.fill", label: "Audio File Size", value: transcription.getAudioFileSizeFormatted(), debugOnly: true)
                    }
                    #endif
                }

                Section("Transcription") {
                    if let providerName = transcription.transcriptionProviderName {
                        metadataRow(icon: "waveform", label: "Provider", value: providerName)
                    }
                    if let modelName = transcription.transcriptionModelName {
                        metadataRow(icon: "character.bubble", label: "Model", value: modelName)
                    }
                    #if DEBUG
                    if let duration = transcription.transcriptionDuration {
                        metadataRow(icon: "clock.fill", label: "Time", value: transcription.getDurationFormatted(duration), debugOnly: true)
                        metadataRow(icon: "figure.run.circle.fill", label: "Factor", value: transcription.getFactor(audioDuration: transcription.audioDuration, transcriptionDuration: duration), debugOnly: true)
                    }
                    #endif
                }

                if let variation = selectedVariation {
                    Section("AI Processing") {
                        if let providerName = variation.aiProviderName {
                            metadataRow(icon: "sparkles", label: "Provider", value: providerName)
                        }
                        if let modelName = variation.aiModelName {
                            metadataRow(icon: "wand.and.sparkles", label: "Model", value: modelName)
                        }
                        metadataRow(icon: "text.bubble.fill", label: "Preset", value: variation.presetDisplayName)
                        #if DEBUG
                        if let duration = variation.processingDuration {
                            metadataRow(icon: "clock.fill", label: "Processing Time", value: transcription.getDurationFormatted(duration), debugOnly: true)
                        }
                        #endif
                    }
                } else {
                    if transcription.aiProviderName != nil || transcription.aiEnhancementModelName != nil || transcription.promptName != nil {
                        Section("AI Processing") {
                            if let providerName = transcription.aiProviderName {
                                metadataRow(icon: "sparkles", label: "Provider", value: providerName)
                            }
                            if let aiModel = transcription.aiEnhancementModelName {
                                metadataRow(icon: "wand.and.sparkles", label: "Model", value: aiModel)
                            }
                            if let promptName = transcription.promptName {
                                metadataRow(icon: "text.bubble.fill", label: "Preset", value: promptName)
                            }
                            #if DEBUG
                            if let duration = transcription.enhancementDuration {
                                metadataRow(icon: "clock.fill", label: "Processing Time", value: transcription.getDurationFormatted(duration), debugOnly: true)
                            }
                            #endif
                        }
                    }
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func metadataRow(icon: String, label: String, value: String, debugOnly: Bool = false) -> some View {
        let tintColor: Color = debugOnly ? .orange : .secondary
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.medium))
                .foregroundStyle(tintColor)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(debugOnly ? .orange : .primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(tintColor)
        }
    }
}

// MARK: - Preset Picker Sheet

private struct PresetPickerSheet: View {
    let presetManager: PresetManager
    let existingVariationIds: Set<String>
    let onReviewExtractedTasks: (() -> Void)?
    let onExtractTasks: (() -> Void)?
    let onSelect: (Preset) -> Void

    @State private var filter: PresetFilter = .all
    @State private var selectedCategory: String?
    @State private var searchText = ""

    private var typeFilteredPresets: [Preset] {
        let byType: [Preset] = switch filter {
        case .all: presetManager.visiblePresets
        case .system: presetManager.visiblePresets.filter(\.isBuiltIn)
        case .custom: presetManager.visiblePresets.filter { !$0.isBuiltIn }
        }
        guard !searchText.isEmpty else { return byType }
        return byType.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.presetDescription.localizedStandardContains(searchText)
        }
    }

    private var allCategories: [String] {
        var seen = Set<String>()
        return typeFilteredPresets.compactMap { preset in
            if seen.contains(preset.category) { return nil }
            seen.insert(preset.category)
            return preset.category
        }
    }

    private var filteredPresets: [Preset] {
        if selectedCategory == CategoryChipsView.favoritesFilter {
            return typeFilteredPresets.filter(\.isFavorite)
        }
        guard let selectedCategory else { return typeFilteredPresets }
        return typeFilteredPresets.filter { $0.category == selectedCategory }
    }

    private var filteredCategories: [String] {
        var seen = Set<String>()
        return filteredPresets.compactMap { preset in
            if seen.contains(preset.category) { return nil }
            seen.insert(preset.category)
            return preset.category
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let onExtractTasks {
                    Section("Smart Actions") {
                        if let onReviewExtractedTasks {
                            Button {
                                onReviewExtractedTasks()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "tray.full")
                                        .frame(width: 20)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Review Reminder Suggestions")
                                            .font(.body)
                                        Text("Open the reminder suggestions already extracted from this note.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .tint(.primary)
                        }

                        Button {
                            onExtractTasks()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checklist")
                                    .frame(width: 20)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Extract Tasks to Reminders")
                                        .font(.body)
                                    Text("Find reminder suggestions in this note and review them before importing to Apple Reminders.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .tint(.primary)
                    }
                }

                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(PresetFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    CategoryChipsView(
                        categories: allCategories,
                        selectedCategory: $selectedCategory,
                        showFavorites: presetManager.hasVisibleFavorites
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listSectionSpacing(0)

                if typeFilteredPresets.isEmpty, onExtractTasks == nil {
                    ContentUnavailableView {
                        Label(searchText.isEmpty ? "No Visible Presets" : "No Presets Found", systemImage: "eye.slash")
                    } description: {
                        Text(searchText.isEmpty
                             ? "Unhide presets in AI Presets to show them here."
                             : "Try a different search or filter.")
                    }
                } else {
                    if selectedCategory == nil {
                        let favorites = typeFilteredPresets.filter(\.isFavorite)
                        if !favorites.isEmpty {
                            Section("Favorites") {
                                ForEach(favorites) { preset in
                                    presetRow(preset)
                                }
                            }
                        }
                    }

                    ForEach(filteredCategories, id: \.self) { category in
                        Section(category) {
                            ForEach(filteredPresets.filter { $0.category == category }) { preset in
                                presetRow(preset)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search presets")
            .onChange(of: filter) { _, _ in
                selectedCategory = nil
            }
            .onChange(of: presetManager.hasVisibleFavorites) {
                if !presetManager.hasVisibleFavorites && selectedCategory == CategoryChipsView.favoritesFilter {
                    selectedCategory = nil
                }
            }
            .navigationTitle("AI Actions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        let exists = existingVariationIds.contains(preset.id)
        return Button {
            onSelect(preset)
        } label: {
            HStack(spacing: 10) {
                if !preset.isBuiltIn {
                    Capsule()
                        .fill(.orange)
                        .frame(width: 4)
                }

                PresetIconView(icon: preset.icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body)
                    if !preset.presetDescription.isEmpty {
                        Text(preset.presetDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    presetManager.toggleFavorite(presetId: preset.id)
                } label: {
                    Image(systemName: preset.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(preset.isFavorite ? .red : .secondary.opacity(0.4))
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)

                if exists {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
    }
}

// MARK: - Text Edit Sheet

private struct TextEditSheet: View {
    let text: String
    let title: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editableText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $editableText)
                .focused($isFocused)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .contentMargins(.bottom, 100, for: .scrollContent)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .onAppear {
                    editableText = text
                    isFocused = true
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if #available(iOS 26, *) {
                            Button(role: .cancel) {
                                HapticManager.lightImpact()
                                dismiss()
                            }
                        } else {
                            Button("Cancel") {
                                HapticManager.lightImpact()
                                dismiss()
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if #available(iOS 26, *) {
                            Button(role: .confirm) {
                                onSave(editableText)
                                dismiss()
                            }
                            .tint(.blue)
                            .disabled(editableText == text)
                        } else {
                            Button("Done") {
                                onSave(editableText)
                                dismiss()
                            }
                            .disabled(editableText == text)
                        }
                    }
                }
        }
    }
}

#if DEBUG || QA
#Preview {
    TranscriptionDetailView(transcription: Transcription.mockData[0])
        .environment(AppState())
}
#endif
