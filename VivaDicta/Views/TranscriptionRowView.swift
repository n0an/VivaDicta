//
//  TranscriptionRowView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI
import SwiftData

struct TranscriptionRowView: View {
    let transcription: Transcription
    let isNewlyInserted: Bool
    let allTags: [TranscriptionTag]
    let semanticScore: Float?

    @Environment(\.colorScheme) var colorScheme
    @State private var showGradient = false
    @State private var showCopied = false

    private var displayText: String {
        transcription.enhancedText ?? transcription.text
    }

    private var assignedTags: [TranscriptionTag] {
        let assignedIds = Set((transcription.tagAssignments ?? []).map(\.tagId))
        return allTags.filter { assignedIds.contains($0.id) }
    }

    private var semanticScoreText: String? {
        guard let semanticScore else { return nil }
        let percentage = max(0, min(Int((semanticScore * 100).rounded()), 100))
        return "\(percentage)%"
    }

    init(
        transcription: Transcription,
        isNewlyInserted: Bool,
        allTags: [TranscriptionTag],
        semanticScore: Float? = nil
    ) {
        self.transcription = transcription
        self.isNewlyInserted = isNewlyInserted
        self.allTags = allTags
        self.semanticScore = semanticScore
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if let tag = transcription.sourceTag {
                        Image(systemName: SourceTag.icon(for: tag))
                            .font(.caption2)
                            .foregroundStyle(SourceTag.color(for: tag))
                    }
                }

                Text(displayText)
                    .font(.body)
                    .lineLimit(2)
                    .lineSpacing(2)

                if !assignedTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(assignedTags.prefix(5)) { tag in
                            Image(systemName: tag.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: tag.colorHex) ?? .blue)
                                .frame(width: 22, height: 22)
                                .background((Color(hex: tag.colorHex) ?? .blue).opacity(0.15))
                                .clipShape(.circle)
                        }
                        if assignedTags.count > 5 {
                            Text("+\(assignedTags.count - 5)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 6) {
                if let semanticScoreText {
                    Text(semanticScoreText)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(.rect(cornerRadius: 6))
                }

                Text(transcription.getDurationFormatted(transcription.audioDuration))
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(.rect(cornerRadius: 6))

                Button("Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc") {
                    ClipboardManager.copyToClipboard(displayText)
                    HapticManager.success()
                    showCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        showCopied = false
                    }
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 13))
                .frame(width: 24, height: 24)
                .foregroundStyle(showCopied ? .green : .secondary)
                .buttonStyle(.borderless)
                .contentTransition(.symbolEffect(.replace))
            }
        }
        .scaleEffect(showGradient ? 1.1 : 1.0)
        .overlay(
            Group {
                if showGradient {
                    AnimatedMeshGradient2()
                        .scaleEffect(1.2)
                        .blendMode(colorScheme == .dark ? .color : .screen)
                }
            }
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showGradient)
        .task {
            if isNewlyInserted {
                showGradient = true
                try? await Task.sleep(for: .seconds(0.5))
                showGradient = false
            }
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    @Previewable @State var mockTranscriptions = Transcription.mockData

    List {
        if let firstTranscription = mockTranscriptions.first {
            TranscriptionRowView(transcription: firstTranscription, isNewlyInserted: true, allTags: [])
        }
    }
    .listStyle(.plain)
}
