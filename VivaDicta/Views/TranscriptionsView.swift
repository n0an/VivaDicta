//
//  TranscriptionsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import SwiftUI
import SwiftData

struct TranscriptionsView: View {
    @State var selectedTranscription: Transcription?
    @State var searchText: String = ""
    
    var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    var body: some View {
        NavigationStack {
            TranscriptionsList(searchText: searchText, appState: appState)
                .navigationTitle("Transcriptions")
                .searchable(text: $searchText, placement: .navigationBarDrawer)
        }
    }
}

private struct TranscriptionsList: View {
    let searchText: String
    let appState: AppState
    
    @Query private var transcriptions: [Transcription]
    @Query(sort: \Transcription.timestamp, order: .reverse) private var allTranscriptions: [Transcription]
    
    init(searchText: String, appState: AppState) {
        self.searchText = searchText
        self.appState = appState
        
        _transcriptions = Query(filter: #Predicate<Transcription> { transcription in
            if searchText.isEmpty {
                true
            } else {
                transcription.text.localizedStandardContains(searchText) ||
                (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
            }
        }, sort: \Transcription.timestamp, order: .reverse)
    }
    
    var body: some View {
        VStack {
            if allTranscriptions.isEmpty {
                emptyAllStateView
            }
            else if transcriptions.isEmpty {
                emptyFilteredStateView
            } else {
                List {
                    ForEach(transcriptions) { transcription in
                        NavigationLink(destination: TranscriptionDetailView(transcription: transcription)) {
                            TranscriptionRowView(transcription: transcription)
                        }
                    }
                }
                .listStyle(.plain)
            }
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
