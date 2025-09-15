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
    @State private var filteredTranscriptions: [Transcription] = []
    
    var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    var body: some View {
        
        NavigationStack {
            VStack {
                if transcriptions.isEmpty {
                    emptyAllStateView
                }
                else if filteredTranscriptions.isEmpty {
                    emptyFilteredStateView
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
            .onAppear {
                updateFilteredTranscriptions()
            }
            .onChange(of: searchText) {
                updateFilteredTranscriptions()
            }
            .onChange(of: transcriptions) {
                updateFilteredTranscriptions()
            }

        }
    }
    
    private func updateFilteredTranscriptions() {
        filteredTranscriptions = transcriptions.filter { transcription in
            searchText.isEmpty ||
            transcription.text.localizedCaseInsensitiveContains(searchText) ||
            (transcription.enhancedText ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var emptyFilteredStateView: some View {
        ContentUnavailableView {
            Label("No Transcriptions found", systemImage: "doc.text.magnifyingglass")
        }
    }
    
    private var emptyAllStateView: some View {
        ContentUnavailableView {
            Label("No Transcriptions yet", systemImage: "waveform")
        } description: {
            Text("Tap Start Recording to capture your first transcription.")
        } actions: {
            Button("Start recording") {
                appState.selectedTab = .record
            }
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    @Previewable @State var appState = AppState()
    TranscriptionsView(appState: appState)
}
