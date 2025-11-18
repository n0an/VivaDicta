//
//  TranscriptionDetailView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI
import CoreSpotlight

struct TranscriptionDetailView: View {

    var transcription: Transcription
    var appState: AppState

    var body: some View {
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
            
            // Original text section
            VStack(alignment: .leading, spacing: 8) {
                Text(transcription.text)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .lineSpacing(2)
                
                HStack {
                    Text("Original")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    AnimatedCopyButton(textToCopy: transcription.text)
                }
            }
            
            if let enhancedText = transcription.enhancedText {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(enhancedText)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .lineSpacing(2)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                            Text("Enhanced")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                        AnimatedCopyButton(textToCopy: enhancedText)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
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

            
            Spacer()
        }
        .padding()
        .onAppear {
            let activity = appState.userActivity(for: transcription)
            activity.becomeCurrent()
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
