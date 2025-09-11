//
//  TranscriptionsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import SwiftUI
import SwiftData

struct TranscriptionsView: View {
    @Query(sort: \Transcription.timestamp, order: .reverse) private var transcriptions: [Transcription]
    
    @State var selectedTranscription: Transcription?
    
    var body: some View {
        
        NavigationStack {
            List {
                ForEach(transcriptions) { transcription in
                    
                    NavigationLink(destination: TranscriptionDetailView(transcription: transcription)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Text(transcription.audioDurationFormatted)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                            
                            Text(transcription.text)
                                .font(.body)                                .lineLimit(2)
                                .lineSpacing(2)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Transcriptions")
        }
    }
    
}

#Preview(traits: .transcriptionsMockData) {
    TranscriptionsView()
}
