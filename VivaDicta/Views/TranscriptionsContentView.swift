//
//  TranscriptionsContentView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import os
import SwiftData
import SwiftUI

struct TranscriptionsContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.timestamp, order: .reverse) private var allTranscriptions: [Transcription]

    @Binding var searchText: String
    @State private var filteredTranscriptions: [Transcription] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var navigationPath = NavigationPath()
    @State private var newlyInsertedIDs: Set<UUID> = []
    @State private var previousTranscriptionCount = 0

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "TranscriptionsContentView")

    var appState: AppState

    init(appState: AppState, searchText: Binding<String>) {
        self.appState = appState
        self._searchText = searchText
    }

    var body: some View {
        VStack {
            if allTranscriptions.isEmpty {
                emptyAllStateView
            } else if filteredTranscriptions.isEmpty && !searchText.isEmpty {
                emptyFilteredStateView
            } else {
                List {
                    ForEach(displayedTranscriptions) { transcription in
                        NavigationLink(destination: TranscriptionDetailView(transcription: transcription, appState: appState)) {
                            TranscriptionRowView(
                                transcription: transcription,
                                isNewlyInserted: newlyInsertedIDs.contains(transcription.id)
                            )
                        }
                    }
                    .onDelete(perform: deleteTranscription)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            filteredTranscriptions = allTranscriptions
            previousTranscriptionCount = allTranscriptions.count
        }
        .onChange(of: searchText) { _, newValue in
            performDebouncedSearch(with: newValue)
        }
        .onChange(of: allTranscriptions) { oldValue, newValue in
            // Detect newly inserted transcriptions
            if newValue.count > previousTranscriptionCount {
                // Find the newly added transcription(s)
                // Since the query is sorted by timestamp in reverse, new ones appear at the beginning
                let newTranscriptions = newValue.prefix(newValue.count - previousTranscriptionCount)
                for transcription in newTranscriptions {
                    newlyInsertedIDs.insert(transcription.id)

                    // Remove from the set after animation completes (1 second)
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await MainActor.run {
                            _ = newlyInsertedIDs.remove(transcription.id)
                        }
                    }
                }
            }
            previousTranscriptionCount = newValue.count

            // Update filtered results
            if searchText.isEmpty {
                filteredTranscriptions = allTranscriptions
            } else {
                performDebouncedSearch(with: searchText)
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
                logger.logError("Search was cancelled or failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteTranscription(at offsets: IndexSet) {
        for index in offsets {
            let transcription = displayedTranscriptions[index]
            let transcriptionID = transcription.id

            if let audioFileName = transcription.audioFileName {
                let audioURL = FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
                try? FileManager.default.removeItem(at: audioURL)
            }

            modelContext.delete(transcription)

            // Remove from Spotlight index
            Task {
                await appState.removeTranscriptionFromSpotlight(transcriptionID)
            }
        }

        do {
            try modelContext.save()
        } catch {
            logger.logError("Failed to save after deletion: \(error.localizedDescription)")
        }
    }

    private var emptyFilteredStateView: some View {
        ContentUnavailableView.search
    }

    private var emptyAllStateView: some View {
        ContentUnavailableView {
            Label("No Transcriptions yet", systemImage: "waveform")
        } description: {
            Text("Tap the record button to capture your first transcription.")
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    @Previewable @State var appState = AppState()
    @Previewable @State var searchText = ""
    NavigationStack {
        TranscriptionsContentView(appState: appState, searchText: $searchText)
    }
}
