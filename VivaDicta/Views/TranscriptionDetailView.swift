//
//  TranscriptionDetailView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI
import CoreSpotlight

private enum TextDisplayType: String, CaseIterable {
    case original = "Original"
    case enhanced = "Enhanced"
}

enum ProcessingState: Equatable {
    case idle
    case transcribing
    case enhancing
}

struct TranscriptionDetailView: View {

    var transcription: Transcription
    var appState: AppState

    @State private var selectedTextType: TextDisplayType = .enhanced
    @State private var spotlightTask: Task<Void, Never>?
    
    @State private var isExpanded: Bool = false
    @Namespace private var namespace

    @State private var processingState: ProcessingState = .idle
    @State private var processingTask: Task<Void, Never>?

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
        let audioDirectory = URL.documentsDirectory.appendingPathComponent("Audio")
        let url = audioDirectory.appendingPathComponent(audioFileName)
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
                if let audioFileName = transcription.audioFileName {
                    AudioPlayerView(audioFileName: audioFileName)
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
                        .cornerRadius(6)
                }

                // Segmented control - only show if enhanced text exists
                if hasEnhancedText {
                    Picker("Text type", selection: $selectedTextType) {
                        ForEach(TextDisplayType.allCases, id: \.self) { type in
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
        .onAppear {
            let activity = appState.userActivity(for: transcription)
            activity.becomeCurrent()

            // Update Spotlight ranking for frequently accessed items
            spotlightTask = Task {
                await appState.updateSpotlightRanking(for: transcription)
            }
        }
        .onDisappear {
            spotlightTask?.cancel()
            spotlightTask = nil
            processingTask?.cancel()
            processingTask = nil
        }
        .animation(.spring, value: isExpanded)
    }

    private var textContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(displayedText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .lineSpacing(2)
                .textSelection(.enabled)
        }
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
            AnimatedCopyButton(textToCopy: displayedText)
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    
    
    
    @ViewBuilder
    private func retranscribeButton(expandDirection: LiquidButtonExpandDirection) -> some View {
        
        HStack {
            Spacer()
            
            if #available(iOS 26.0, *) {
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
                            isExpanded = true
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
                
            } else { // iOS 18 Fallback
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

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()

            DisclosureGroup("Meta Info") {
                VStack(alignment: .leading, spacing: 10) {
                    metadataRow(icon: "hourglass", label: "Audio Duration", value: transcription.getDurationFormatted(transcription.audioDuration))
                    if transcription.audioFileName != nil {
                        metadataRow(icon: "doc.fill", label: "Audio File Size", value: transcription.getAudioFileSizeFormatted())
                    }
                    if let modelName = transcription.transcriptionModelName {
                        metadataRow(icon: "cpu.fill", label: "Transcription Model", value: modelName)
                    }
                    if let aiModel = transcription.aiEnhancementModelName {
                        metadataRow(icon: "sparkles", label: "Enhancement Model", value: aiModel)
                    }
                    if let promptName = transcription.promptName {
                        metadataRow(icon: "text.bubble.fill", label: "Prompt Used", value: promptName)
                    }
                    if let duration = transcription.transcriptionDuration {
                        metadataRow(icon: "clock.fill", label: "Transcription Time", value: transcription.getDurationFormatted(duration))
                        metadataRow(icon: "figure.run.circle.fill", label: "Transcription Factor", value: transcription.getFactor(audioDuration: transcription.audioDuration, transcriptionDuration: duration))
                    }
                    if let duration = transcription.enhancementDuration {
                        metadataRow(icon: "clock.fill", label: "Enhancement Time", value: transcription.getDurationFormatted(duration))
                    }
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

    // MARK: - Actions

    private func collapseIfExpanded() {
        if isExpanded {
            isExpanded = false
        }
    }

    private func retranscribe() {
        guard let audioURL = audioURL else { return }

        processingTask = Task {
            processingState = .transcribing

            do {
                let transcriptionStart = Date()
                let newText = try await appState.transcriptionManager.transcribe(audioURL: audioURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                transcription.text = newText
                transcription.transcriptionModelName = appState.transcriptionManager.getCurrentTranscriptionModel()?.displayName
                transcription.transcriptionDuration = transcriptionDuration

                // Update Spotlight index
                await appState.updateTranscriptionInSpotlight(transcription)

            } catch {
                // Handle error silently for now
            }

            processingState = .idle
        }
    }

    private func enhance() {
        guard !transcription.text.isEmpty else { return }

        processingTask = Task {
            processingState = .enhancing

            do {
                let (enhancedText, duration, promptName) = try await appState.aiService.enhance(transcription.text)

                transcription.enhancedText = enhancedText
                transcription.aiEnhancementModelName = appState.aiService.selectedMode.aiModel
                transcription.promptName = promptName
                transcription.enhancementDuration = duration

                // Switch to enhanced view
                selectedTextType = .enhanced

                // Update Spotlight index
                await appState.updateTranscriptionInSpotlight(transcription)

            } catch {
                // Handle error silently for now
            }

            processingState = .idle
        }
    }

    private func retranscribeAndEnhance() {
        guard let audioURL = audioURL else { return }

        processingTask = Task {
            processingState = .transcribing

            do {
                // Step 1: Transcribe
                let transcriptionStart = Date()
                let newText = try await appState.transcriptionManager.transcribe(audioURL: audioURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                transcription.text = newText
                transcription.transcriptionModelName = appState.transcriptionManager.getCurrentTranscriptionModel()?.displayName
                transcription.transcriptionDuration = transcriptionDuration

                // Step 2: Enhance (if AI is configured)
                if appState.aiService.isProperlyConfigured() {
                    processingState = .enhancing

                    let (enhancedText, duration, promptName) = try await appState.aiService.enhance(newText)

                    transcription.enhancedText = enhancedText
                    transcription.aiEnhancementModelName = appState.aiService.selectedMode.aiModel
                    transcription.promptName = promptName
                    transcription.enhancementDuration = duration

                    // Switch to enhanced view
                    selectedTextType = .enhanced
                }

                // Update Spotlight index
                await appState.updateTranscriptionInSpotlight(transcription)

            } catch {
                // Handle error silently for now
            }

            processingState = .idle
        }
    }
}

#Preview {
    TranscriptionDetailView(
        transcription: Transcription.mockData[2],
        appState: AppState()
    )
}
