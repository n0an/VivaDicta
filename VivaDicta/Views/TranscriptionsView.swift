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
    
    @State var searchText: String = ""
    
    var filteredTranscriptions: [Transcription] {
        transcriptions.filter { transcription in
            searchText.isEmpty ||
            transcription.text.localizedCaseInsensitiveContains(searchText) ||
            (transcription.enhancedText ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        
        NavigationStack {
            VStack {
                if filteredTranscriptions.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredTranscriptions) { transcription in
                            
                            NavigationLink(destination: TranscriptionDetailView(transcription: transcription)) {
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
                    }
                    .listStyle(.plain)
                    
                }
            }
            .navigationTitle("Transcriptions")
            .searchable(text: $searchText, placement: .navigationBarDrawer)

        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Transcriptions")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
}

#Preview(traits: .transcriptionsMockData) {
    TranscriptionsView()
}
