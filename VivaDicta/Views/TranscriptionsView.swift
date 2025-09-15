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
    @State private var debouncedSearchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    
    var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    var body: some View {
        NavigationStack {
            TranscriptionsList(searchText: debouncedSearchText, appState: appState)
                .navigationTitle("Transcriptions")
                .searchable(text: $searchText, placement: .navigationBarDrawer)
                .onChange(of: searchText) { _, newValue in
                    // Cancel previous search task
                    searchTask?.cancel()
                    
                    // Create new debounced search task
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        
                        // Only update if task wasn't cancelled
                        if !Task.isCancelled {
                            await MainActor.run {
                                debouncedSearchText = newValue
                            }
                        }
                    }
                }
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
