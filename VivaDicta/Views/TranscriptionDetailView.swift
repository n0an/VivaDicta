//
//  TranscriptionDetailView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI

struct TranscriptionDetailView: View {
    
    var transcription: Transcription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let audioFileName = transcription.audioFileName {
                AudioPlayerView(audioFileName: audioFileName)
                    .padding(.bottom, 8)
            }
            
            HStack {
                Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                
                Text(transcription.getDurationFormatted(transcription.audioDuration))
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            Text(transcription.text)
                .font(.body)

            
            Divider()
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 10) {
                metadataRow(icon: "hourglass", label: "Audio Duration", value: transcription.getDurationFormatted(transcription.audioDuration))
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
                }
                if let duration = transcription.enhancementDuration {
                    metadataRow(icon: "clock.fill", label: "Enhancement Time", value: transcription.getDurationFormatted(duration))
                }
            }

            
            Spacer()
        }
        .padding()
    }
    
    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.medium))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TranscriptionDetailView(transcription: Transcription.mockData[2])
}
