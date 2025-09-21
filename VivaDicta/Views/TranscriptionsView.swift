//
//  TranscriptionsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import SwiftUI
import SwiftData

struct TranscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.timestamp, order: .reverse) private var allTranscriptions: [Transcription]
    
    @State var selectedTranscription: Transcription?
    @State var searchText: String = ""
    @State private var filteredTranscriptions: [Transcription] = []
    @State private var searchTask: Task<Void, Never>?
    
    var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if allTranscriptions.isEmpty {
                    emptyAllStateView
                }
                else if filteredTranscriptions.isEmpty && !searchText.isEmpty {
                    emptyFilteredStateView
                } else {
                    List {
                        ForEach(displayedTranscriptions) { transcription in
                            NavigationLink(destination: TranscriptionDetailView(transcription: transcription)) {
                                TranscriptionRowView(transcription: transcription)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transcriptions")
            .searchable(text: $searchText, placement: .navigationBarDrawer)
            .onAppear {
                filteredTranscriptions = allTranscriptions
            }
            .onChange(of: searchText) { _, newValue in
                performDebouncedSearch(with: newValue)
            }
            .onChange(of: allTranscriptions) { _, _ in
                if searchText.isEmpty {
                    filteredTranscriptions = allTranscriptions
                } else {
                    performDebouncedSearch(with: searchText)
                }
            }
        }
    }
    
    private var displayedTranscriptions: [Transcription] {
        searchText.isEmpty ? allTranscriptions : filteredTranscriptions
    }
    
    private func performDebouncedSearch(with searchTerm: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        // Create new debounced search task
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(200))
                
                guard !searchTerm.isEmpty else {
                    await MainActor.run {
                        filteredTranscriptions = allTranscriptions
                    }
                    return
                }
                
                var descriptor = FetchDescriptor<Transcription>(
                    sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
                )
                descriptor.predicate = #Predicate<Transcription> { transcription in
                    transcription.text.localizedStandardContains(searchTerm) ||
                    (transcription.enhancedText?.localizedStandardContains(searchTerm) ?? false)
                }
                
                let results = try modelContext.fetch(descriptor)
                
                await MainActor.run {
                    filteredTranscriptions = results
                }
            } catch {
                print("Search was cancelled or failed: \(error)")
            }
        }
    }
    
    private var emptyFilteredStateView: some View {
        ContentUnavailableView.search(text: searchText)
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
