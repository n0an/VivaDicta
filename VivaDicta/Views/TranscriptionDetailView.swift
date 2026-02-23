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
    @State private var generatingPresetId: String?

    // Ripple effect state for processing animations
    @State private var rippleEffectTimer: Timer?
    @State private var rippleEffectTrigger = false

    private var sortedVariations: [TranscriptionVariation] {
        (transcription.variations ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    private var hasVariations: Bool {
        !(transcription.variations ?? []).isEmpty
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
        if let variation = sortedVariations.first(where: { $0.presetId == selectedChipId }) {
            return PresetCatalog.displayName(for: variation.presetId, fallback: variation.presetDisplayName)
        }
        return "Original"
    }

    private var audioURL: URL? {
        guard let audioFileName = transcription.audioFileName, !audioFileName.isEmpty else { return nil }
        let url = FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var canRetranscribe: Bool {
        audioURL != nil && processingState == .idle
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
                if hasVariations {
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
            bottomActionBar
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerSheet(
                presetManager: appState.presetManager,
                existingVariationIds: Set(sortedVariations.map(\.presetId)),
                onSelect: { preset in
                    showPresetPicker = false
                    generateVariation(preset: preset)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                shareMenu
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
            Text(displayedText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .lineSpacing(2)
                .textSelection(.enabled)
                .redacted(reason: processingState != .idle ? .placeholder : [])
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

                // Button 2: AI Presets picker
                Button {
                    showPresetPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
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
                                        .stroke(lineWidth: 1)
                                        .fill(Color.white)
                                        .blur(radius: 1)
                                        .blendMode(.overlay)
                                )
                                .clipShape(.capsule)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(generatingPresetId != nil || !appState.aiService.isProperlyConfigured())

                Spacer()

                // Button 3: Copy
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

    private func triggerCopyAnimation() {
        isShimmering = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            isShimmering = false
        }
    }

    private var shareMenu: some View {
        Menu {
            Section("Share") {
                // Share currently selected text (if it's a variation)
                if selectedIsVariation {
                    ShareLink(item: displayedText) {
                        Label {
                            Text(selectedLabel)
                        } icon: {
                            PresetIconView(icon: PresetCatalog.icon(for: selectedChipId))
                        }
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
        processingState = .idle
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
            HStack(spacing: 6) {
                // "Original" chip — always present
                variationChip(id: "original", label: "Original", icon: nil)

                // One chip per existing variation
                ForEach(sortedVariations, id: \.id) { variation in
                    variationChip(
                        id: variation.presetId,
                        label: PresetCatalog.displayName(for: variation.presetId, fallback: variation.presetDisplayName),
                        icon: PresetCatalog.icon(for: variation.presetId),
                        isLoading: generatingPresetId == variation.presetId
                    )
                }

                // "+" button to add new variation
                addVariationButton
            }
        }
        .scrollIndicators(.hidden)
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
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private var addVariationButton: some View {
        Button {
            showPresetPicker = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(generatingPresetId != nil || !appState.aiService.isProperlyConfigured())
    }

    // MARK: - Generate Variation

    private func regenerateSelectedVariation() {
        guard let preset = appState.presetManager.preset(for: selectedChipId) else { return }
        generateVariation(preset: preset)
    }

    private func generateVariation(preset: Preset) {
        generatingPresetId = preset.id
        HapticManager.lightImpact()

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedChipId = preset.id
        }

        processingTask = Task {
            processingState = .enhancing

            do {
                let (resultText, duration) = try await appState.aiService.generateVariation(
                    text: transcription.text,
                    preset: preset
                )

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

                generatingPresetId = nil

                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedChipId = preset.id
                }

                HapticManager.heartbeat()
            } catch is CancellationError {
                generatingPresetId = nil
            } catch {
                generatingPresetId = nil
                enhancementErrorMessage = error.localizedDescription
                showEnhancementErrorAlert = true
                HapticManager.error()
            }

            processingState = .idle
        }
    }
}

// MARK: - Preset Picker Sheet

private struct PresetPickerSheet: View {
    let presetManager: PresetManager
    let existingVariationIds: Set<String>
    let onSelect: (Preset) -> Void

    @State private var filter: PresetFilter = .all
    @State private var selectedCategory: String?

    private var typeFilteredPresets: [Preset] {
        switch filter {
        case .all: presetManager.presets
        case .system: presetManager.presets.filter(\.isBuiltIn)
        case .custom: presetManager.presets.filter { !$0.isBuiltIn }
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
                        selectedCategory: $selectedCategory
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(filteredCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(filteredPresets.filter { $0.category == category }) { preset in
                            presetRow(preset)
                        }
                    }
                }
            }
            .onChange(of: filter) { _, _ in
                selectedCategory = nil
            }
            .navigationTitle("AI Rewrite")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        let exists = existingVariationIds.contains(preset.id)
        return Button {
            onSelect(preset)
        } label: {
            HStack(spacing: 10) {
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

#if DEBUG || QA
#Preview {
    TranscriptionDetailView(transcription: Transcription.mockData[0])
        .environment(AppState())
}
#endif
