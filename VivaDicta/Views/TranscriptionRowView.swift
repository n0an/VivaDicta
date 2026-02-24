//
//  TranscriptionRowView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct TranscriptionRowView: View {
    let transcription: Transcription
    let isNewlyInserted: Bool

    @Environment(\.colorScheme) var colorScheme
    @State private var showGradient = false
    @State private var showCopied = false

    private var displayText: String {
        transcription.enhancedText ?? transcription.text
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(displayText)
                    .font(.body)
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            Spacer()

            VStack(spacing: 6) {
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
                    Task { @MainActor in
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
        .onAppear {
            if isNewlyInserted {
                showGradient = true
                
                // Remove completely after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showGradient = false
                }
            }
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    @Previewable @State var mockTranscriptions = Transcription.mockData

    List {
        if let firstTranscription = mockTranscriptions.first {
            TranscriptionRowView(transcription: firstTranscription, isNewlyInserted: true)
        }
    }
    .listStyle(.plain)
}
