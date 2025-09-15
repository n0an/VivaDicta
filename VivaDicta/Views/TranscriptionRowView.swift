//
//  TranscriptionRowView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct TranscriptionRowView: View {
    let transcription: Transcription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                
                Text(transcription.getDurationFormatted(transcription.audioDuration))
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            Text(transcription.text)
                .font(.body)
                .lineLimit(2)
                .lineSpacing(2)
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    @Previewable @State var mockTranscriptions = [Transcription]()
    
    List {
        if let firstTranscription = mockTranscriptions.first {
            TranscriptionRowView(transcription: firstTranscription)
        }
    }
    .listStyle(.plain)
}