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

struct TranscriptionDetailView: View {

    var transcription: Transcription
    var appState: AppState

    @State private var selectedTextType: TextDisplayType = .enhanced
    @State private var spotlightTask: Task<Void, Never>?

    private var hasEnhancedText: Bool {
        transcription.enhancedText != nil
    }

    private var displayedText: String {
        if selectedTextType == .enhanced, let enhancedText = transcription.enhancedText {
            return enhancedText
        }
        return transcription.text
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
                VStack(alignment: .leading, spacing: 0) {
                    textContentView
                    copyButton
                    metadataSection
                    Spacer()
                }
                .padding(.horizontal)

                // Option 2: Content too tall - text scrolls, metadata fixed at bottom
                VStack(spacing: 0) {
                    ScrollView {
                        textContentView
                            .padding(.horizontal)
                    }
                    
                    copyButton
                        .padding(.horizontal)
                    
                    metadataSection
                        .padding(.horizontal)
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
        }
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
}

#Preview {
    TranscriptionDetailView(
        transcription: Transcription.mockData[2],
        appState: AppState()
    )
}
