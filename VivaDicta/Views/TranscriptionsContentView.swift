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
    @Binding var isSelectionMode: Bool
    @Binding var selectedTranscriptionIDs: Set<UUID>

    @State private var filteredTranscriptions: [Transcription] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var newlyInsertedIDs: Set<UUID> = []
    @State private var previousTranscriptionCount = 0
    @State private var showGoToTopButton = false

    private let topAnchorID = "topAnchor"
    private let logger = Logger(category: .transcriptionsContentView)

    @Environment(AppState.self) var appState

    init(searchText: Binding<String>, isSelectionMode: Binding<Bool>, selectedTranscriptionIDs: Binding<Set<UUID>>) {
        self._searchText = searchText
        self._isSelectionMode = isSelectionMode
        self._selectedTranscriptionIDs = selectedTranscriptionIDs
    }

    var body: some View {
        VStack {
            if allTranscriptions.isEmpty {
                emptyAllStateView
            } else if filteredTranscriptions.isEmpty && !searchText.isEmpty {
                emptyFilteredStateView
            } else {
                ScrollViewReader { proxy in
                    List {
                        EmptyView()
                            .id(topAnchorID)

                        if isSelectionMode {
                            ForEach(displayedTranscriptions) { transcription in
                                SelectableTranscriptionRow(
                                    transcription: transcription,
                                    isSelected: selectedTranscriptionIDs.contains(transcription.id),
                                    isNewlyInserted: newlyInsertedIDs.contains(transcription.id)
                                ) {
                                    toggleSelection(for: transcription)
                                }
                            }
                        } else {
                            ForEach(displayedTranscriptions) { transcription in
                                NavigationLink {
                                    TranscriptionDetailView(transcription: transcription)
                                } label: {
                                    TranscriptionRowView(
                                        transcription: transcription,
                                        isNewlyInserted: newlyInsertedIDs.contains(transcription.id)
                                    )
                                }
                                .contextMenu {
                                    Section("Share") {
                                        if let enhancedText = transcription.enhancedText {
                                            ShareLink(item: enhancedText) {
                                                Label("Enhanced Text", systemImage: "sparkles")
                                            }
                                        }

                                        ShareLink(item: transcription.text) {
                                            Label("Original Text", systemImage: "text.alignleft")
                                        }

                                        if let audioURL = audioURL(for: transcription) {
                                            ShareLink(
                                                item: audioURL,
                                                preview: SharePreview(
                                                    "Recording \(transcription.timestamp.formatted(date: .abbreviated, time: .shortened))",
                                                    image: Image(systemName: "waveform")
                                                )
                                            ) {
                                                Label("Audio Recording", systemImage: "waveform")
                                            }
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deleteTranscription)
                        }
                    }
                    .listStyle(.plain)
                    .onScrollGeometryChange(for: Bool.self) { geo in
                        let topPadding: CGFloat = 300
                        return geo.contentOffset.y >= topPadding
                    } action: { _, isBeyondThreshold in
                        withAnimation {
                            showGoToTopButton = isBeyondThreshold
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if showGoToTopButton {
                            
                            ScrollToTopButton(backgroundColor: .indigo) {
                                withAnimation {
                                    proxy.scrollTo(topAnchorID, anchor: .top)
                                }
                            }
                            .padding(.bottom, 8)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .scale(scale: 2)), removal: .opacity.combined(with: .scale(scale: 0.5))))
                        }
                    }
                }
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

    private func audioURL(for transcription: Transcription) -> URL? {
        guard let audioFileName = transcription.audioFileName, !audioFileName.isEmpty else { return nil }
        let url = FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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

    private func toggleSelection(for transcription: Transcription) {
        HapticManager.lightImpact()
        if selectedTranscriptionIDs.contains(transcription.id) {
            selectedTranscriptionIDs.remove(transcription.id)
        } else {
            selectedTranscriptionIDs.insert(transcription.id)
        }
    }

    private func deleteTranscription(at offsets: IndexSet) {
        HapticManager.heavyImpact()
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
            Label("No Notes yet", systemImage: "waveform")
        } description: {
            Text("Tap the record button to capture your first note.")
        }
    }
}

// MARK: - Selectable Row for Selection Mode

private struct SelectableTranscriptionRow: View {
    let transcription: Transcription
    let isSelected: Bool
    let isNewlyInserted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .animation(.snappy(duration: 0.15), value: isSelected)

                TranscriptionRowView(
                    transcription: transcription,
                    isNewlyInserted: isNewlyInserted
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG || QA
#Preview(traits: .transcriptionsMockDataMany) {
    @Previewable @State var searchText = ""
    @Previewable @State var isSelectionMode = false
    @Previewable @State var selectedIDs: Set<UUID> = []
    NavigationStack {
        TranscriptionsContentView(
            searchText: $searchText,
            isSelectionMode: $isSelectionMode,
            selectedTranscriptionIDs: $selectedIDs
        )
    }
    .environment(AppState())
}
#endif
