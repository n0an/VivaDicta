//
//  TranscriptionsContentView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import os
import SwiftData
import SwiftUI

private enum TranscriptionSearchMode: String {
    case all
    case keyword
    case smart
}

private struct SemanticSearchMatch: Identifiable {
    let transcriptionId: UUID
    let relevanceScore: Float

    var id: UUID { transcriptionId }
}

struct TranscriptionsFloatingControls {
    let sheetTransitions: Namespace.ID
    let onShowChats: () -> Void
    let onStartRecording: () -> Void
}

struct TranscriptionsContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(SmartSearchFeature.isEnabledKey) private var isSmartSearchEnabled = true
    @Query(sort: \Transcription.timestamp, order: .reverse) private var allTranscriptions: [Transcription]
    @Query(sort: \TranscriptionTag.sortOrder) private var allTags: [TranscriptionTag]

    @Binding var searchText: String
    @Binding var isSelectionMode: Bool
    @Binding var selectedTranscriptionIDs: Set<UUID>
    @Binding var displayedTranscriptionIDs: Set<UUID>
    let savedFilter: SavedNotesFilter
    let floatingControls: TranscriptionsFloatingControls?

    @State private var filteredTranscriptions: [Transcription] = []
    @State private var smartSearchMatches: [SemanticSearchMatch] = []
    @State private var semanticScoresByID: [UUID: Float] = [:]
    @State private var searchTask: Task<Void, Never>?
    @State private var newlyInsertedIDs: Set<UUID> = []
    @State private var previousTranscriptionCount = 0
    @State private var showGoToTopButton = false
    @State private var selectedSourceTags: Set<String>
    @State private var selectedUserTagIds: Set<UUID>
    @State private var searchMode: TranscriptionSearchMode = .all

    private let topAnchorID = "topAnchor"
    private let logger = Logger(category: .transcriptionsContentView)

    @Environment(AppState.self) var appState

    init(
        searchText: Binding<String>,
        isSelectionMode: Binding<Bool>,
        selectedTranscriptionIDs: Binding<Set<UUID>>,
        displayedTranscriptionIDs: Binding<Set<UUID>>,
        savedFilter: SavedNotesFilter,
        floatingControls: TranscriptionsFloatingControls? = nil
    ) {
        self._searchText = searchText
        self._isSelectionMode = isSelectionMode
        self._selectedTranscriptionIDs = selectedTranscriptionIDs
        self._displayedTranscriptionIDs = displayedTranscriptionIDs
        self.savedFilter = savedFilter
        self._selectedSourceTags = State(initialValue: savedFilter.sourceTags)
        self._selectedUserTagIds = State(initialValue: savedFilter.userTagIds)
        self.floatingControls = floatingControls
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TranscriptionSearchControlsView(
                    hasTranscriptions: !allTranscriptions.isEmpty,
                    availableSourceTags: availableSourceTags,
                    allTags: allTags,
                    searchText: searchText,
                    selectedSourceTags: $selectedSourceTags,
                    selectedUserTagIds: $selectedUserTagIds,
                    searchMode: $searchMode
                )

                if allTranscriptions.isEmpty {
                    emptyAllStateView
                } else if showsCombinedResults {
                    if combinedResultsAreEmpty {
                        emptyFilteredStateView
                    } else {
                        CombinedSearchResultsView(
                            keywordTranscriptions: keywordDisplayedTranscriptions,
                            smartTranscriptions: smartDisplayedTranscriptions,
                            isSelectionMode: isSelectionMode,
                            selectedTranscriptionIDs: selectedTranscriptionIDs,
                            newlyInsertedIDs: newlyInsertedIDs,
                            allTags: allTags,
                            topAnchorID: topAnchorID,
                            colorScheme: colorScheme,
                            showGoToTopButton: $showGoToTopButton,
                            semanticScoreProvider: { transcriptionID in semanticScoresByID[transcriptionID] },
                            audioURLProvider: audioURL(for:),
                            onToggleSelection: toggleSelection(for:),
                            onDeleteKeyword: deleteKeywordTranscriptions(at:),
                            onDeleteSmart: deleteSmartTranscriptions(at:)
                        )
                    }
                } else if displayedTranscriptions.isEmpty {
                    emptyFilteredStateView
                } else {
                    TranscriptionsListView(
                        displayedTranscriptions: displayedTranscriptions,
                        isSelectionMode: isSelectionMode,
                        selectedTranscriptionIDs: selectedTranscriptionIDs,
                        newlyInsertedIDs: newlyInsertedIDs,
                        allTags: allTags,
                        topAnchorID: topAnchorID,
                        colorScheme: colorScheme,
                        showGoToTopButton: $showGoToTopButton,
                        semanticScoreProvider: currentSemanticScore(for:),
                        audioURLProvider: audioURL(for:),
                        onToggleSelection: toggleSelection(for:),
                        onDelete: deleteTranscription(at:)
                    )
                }
            }

            if let floatingControls, !isSelectionMode {
                MainFloatingActionButtonsView(
                    sheetTransitions: floatingControls.sheetTransitions,
                    onShowChats: floatingControls.onShowChats,
                    onStartRecording: floatingControls.onStartRecording
                )
            }
        }
        .onAppear {
            filteredTranscriptions = allTranscriptions
            smartSearchMatches = []
            semanticScoresByID = [:]
            previousTranscriptionCount = allTranscriptions.count
            syncDisplayedIDs()
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchMode = isSmartSearchEnabled ? .all : .keyword
            }
            performDebouncedSearch(with: newValue)
        }
        .onChange(of: allTranscriptions) { oldValue, newValue in
            let shouldResetTagFilter = NotesFilterResetPolicy.shouldResetToAllAfterDeletion(
                hasActiveFilter: hasActiveTagFilter,
                isSearching: !searchText.isEmpty,
                oldTranscriptionCount: oldValue.count,
                newTranscriptionCount: newValue.count,
                previousFilteredCount: filterTranscriptionsByActiveTags(oldValue).count,
                remainingFilteredCount: filterTranscriptionsByActiveTags(newValue).count
            )

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
                smartSearchMatches = []
                semanticScoresByID = [:]
            } else {
                performDebouncedSearch(with: searchText)
            }

            if shouldResetTagFilter {
                selectedSourceTags.removeAll()
                selectedUserTagIds.removeAll()
            }

            syncDisplayedIDs()
        }
        .onChange(of: filteredTranscriptions) {
            syncDisplayedIDs()
        }
        .onChange(of: selectedSourceTags) {
            syncDisplayedIDs()
        }
        .onChange(of: selectedUserTagIds) {
            syncDisplayedIDs()
        }
        .onChange(of: savedFilter) { _, newValue in
            selectedSourceTags = newValue.sourceTags
            selectedUserTagIds = newValue.userTagIds
        }
        .onChange(of: searchMode) {
            if !searchText.isEmpty {
                performDebouncedSearch(with: searchText)
            }
        }
        .onChange(of: isSmartSearchEnabled) { _, isEnabled in
            if !isEnabled {
                searchMode = .keyword
                smartSearchMatches = []
                semanticScoresByID = [:]
            }

            if !searchText.isEmpty {
                performDebouncedSearch(with: searchText)
            } else {
                syncDisplayedIDs()
            }
        }
    }

    private var hasActiveTagFilter: Bool {
        !selectedSourceTags.isEmpty || !selectedUserTagIds.isEmpty
    }

    private var showsCombinedResults: Bool {
        isSmartSearchEnabled && searchMode == .all && !searchText.isEmpty
    }

    private var combinedResultsAreEmpty: Bool {
        keywordDisplayedTranscriptions.isEmpty && smartDisplayedTranscriptions.isEmpty
    }

    private var availableSourceTags: [String] {
        var seen = Set<String>()
        return allTranscriptions.compactMap { $0.sourceTag }.filter { seen.insert($0).inserted }
    }

    private var keywordDisplayedTranscriptions: [Transcription] {
        let base = searchText.isEmpty ? allTranscriptions : filteredTranscriptions
        return filterTranscriptionsByActiveTags(base)
    }

    private var smartDisplayedTranscriptions: [Transcription] {
        smartSearchMatches.compactMap { match in
            guard let transcription = transcription(for: match.transcriptionId) else { return nil }
            return matchesActiveTags(for: transcription) ? transcription : nil
        }
    }

    private var displayedTranscriptions: [Transcription] {
        guard isSmartSearchEnabled else {
            return keywordDisplayedTranscriptions
        }

        return switch searchMode {
        case .smart:
            smartDisplayedTranscriptions
        case .all, .keyword:
            keywordDisplayedTranscriptions
        }
    }

    private func syncDisplayedIDs() {
        guard isSmartSearchEnabled else {
            displayedTranscriptionIDs = Set(keywordDisplayedTranscriptions.map(\.id))
            return
        }

        switch searchMode {
        case .all:
            displayedTranscriptionIDs = Set(keywordDisplayedTranscriptions.map(\.id))
                .union(smartDisplayedTranscriptions.map(\.id))
        case .keyword, .smart:
            displayedTranscriptionIDs = Set(displayedTranscriptions.map(\.id))
        }
    }

    private func transcription(for transcriptionID: UUID) -> Transcription? {
        allTranscriptions.first { $0.id == transcriptionID }
    }

    private func filterTranscriptionsByActiveTags(_ transcriptions: [Transcription]) -> [Transcription] {
        guard hasActiveTagFilter else { return transcriptions }
        return transcriptions.filter(matchesActiveTags(for:))
    }

    private func matchesActiveTags(for transcription: Transcription) -> Bool {
        let matchesSource = selectedSourceTags.isEmpty ||
            (transcription.sourceTag.map { selectedSourceTags.contains($0) } ?? false)

        let matchesUserTag = selectedUserTagIds.isEmpty ||
            (transcription.tagAssignments ?? []).contains { selectedUserTagIds.contains($0.tagId) }

        return matchesSource && matchesUserTag
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
                        smartSearchMatches = []
                        semanticScoresByID = [:]
                    }
                    return
                }

                let keywordResults = keywordSearchResults(for: searchTerm)
                guard isSmartSearchEnabled else {
                    await MainActor.run {
                        filteredTranscriptions = keywordResults
                        smartSearchMatches = []
                        semanticScoresByID = [:]
                    }
                    return
                }

                guard searchMode != .keyword else {
                    await MainActor.run {
                        filteredTranscriptions = keywordResults
                        smartSearchMatches = []
                        semanticScoresByID = [:]
                    }
                    return
                }

                guard shouldRunSemanticSearch(for: searchTerm) else {
                    await MainActor.run {
                        filteredTranscriptions = keywordResults
                        smartSearchMatches = []
                        semanticScoresByID = [:]
                    }
                    return
                }

                let smartMatches = await semanticSearchMatches(for: searchTerm)

                switch searchMode {
                case .all:
                    await MainActor.run {
                        filteredTranscriptions = keywordResults
                        smartSearchMatches = smartMatches
                        semanticScoresByID = Dictionary(
                            uniqueKeysWithValues: smartMatches.map { ($0.transcriptionId, $0.relevanceScore) }
                        )
                    }
                case .smart:
                    let orderedResults = smartMatches.compactMap { match in
                        allTranscriptions.first(where: { $0.id == match.transcriptionId })
                    }
                    await MainActor.run {
                        filteredTranscriptions = orderedResults
                        smartSearchMatches = smartMatches
                        semanticScoresByID = Dictionary(
                            uniqueKeysWithValues: smartMatches.map { ($0.transcriptionId, $0.relevanceScore) }
                        )
                    }
                case .keyword:
                    break
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

    private func currentSemanticScore(for transcriptionID: UUID) -> Float? {
        guard isSmartSearchEnabled, searchMode == .smart else { return nil }
        return semanticScoresByID[transcriptionID]
    }

    private func keywordSearchResults(for searchTerm: String) -> [Transcription] {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
        )
        descriptor.predicate = #Predicate<Transcription> { transcription in
            transcription.text.localizedStandardContains(searchTerm) ||
                (transcription.enhancedText?.localizedStandardContains(searchTerm) ?? false)
        }

        let transcriptionMatches = try? modelContext.fetch(descriptor)

        let variationDescriptor = FetchDescriptor<TranscriptionVariation>(
            predicate: #Predicate { $0.text.localizedStandardContains(searchTerm) }
        )
        let variationMatches = try? modelContext.fetch(variationDescriptor)

        let matchedTranscriptions = transcriptionMatches ?? []
        let matchedVariationIDs = Set((variationMatches ?? []).compactMap { $0.transcription?.id })
        let directMatchIDs = Set(matchedTranscriptions.map(\.id))
        let additionalIDs = matchedVariationIDs.subtracting(directMatchIDs)

        guard !additionalIDs.isEmpty else {
            return matchedTranscriptions
        }

        let additionalTranscriptions = allTranscriptions.filter { additionalIDs.contains($0.id) }
        return (matchedTranscriptions + additionalTranscriptions)
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func shouldRunSemanticSearch(for searchTerm: String) -> Bool {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }

        let tokens = trimmed
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        if tokens.contains(where: { $0.count >= 4 }) {
            return true
        }

        let combinedTokenLength = tokens.reduce(0) { $0 + $1.count }
        return tokens.count >= 2 && combinedTokenLength >= 6
    }

    private func semanticSearchMatches(for searchTerm: String) async -> [SemanticSearchMatch] {
        do {
            logger.logInfo(
                "Semantic notes search start query='\(searchTerm)' indexedNotes=\(RAGIndexingService.shared.indexedTranscriptionCount)"
            )
            let results = try await RAGIndexingService.shared.search(query: searchTerm, topK: 20)
            logger.logInfo(
                "Semantic notes search finished query='\(searchTerm)' matchedNotes=\(results.count)"
            )
            return results.map { result in
                SemanticSearchMatch(
                    transcriptionId: result.transcriptionId,
                    relevanceScore: result.relevanceScore
                )
            }
        } catch {
            logger.logError("Semantic search failed: \(error.localizedDescription)")
            return []
        }
    }

    private func deleteTranscription(at offsets: IndexSet) {
        deleteTranscriptions(in: displayedTranscriptions, at: offsets)
    }

    private func deleteKeywordTranscriptions(at offsets: IndexSet) {
        deleteTranscriptions(in: keywordDisplayedTranscriptions, at: offsets)
    }

    private func deleteSmartTranscriptions(at offsets: IndexSet) {
        deleteTranscriptions(in: smartDisplayedTranscriptions, at: offsets)
    }

    private func deleteTranscriptions(in transcriptions: [Transcription], at offsets: IndexSet) {
        HapticManager.heavyImpact()
        for index in offsets {
            let transcription = transcriptions[index]
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

            // Remove from RAG index
            Task { await RAGIndexingService.shared.removeTranscription(id: transcriptionID) }
        }

        do {
            try modelContext.save()
            RecentNotesCache.syncFromDatabase(modelContext: modelContext)
        } catch {
            logger.logError("Failed to save after deletion: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private var emptyFilteredStateView: some View {
        if !searchText.isEmpty {
            if isSmartSearchEnabled, searchMode == .smart {
                ContentUnavailableView(
                    "No Smart Matches",
                    systemImage: "sparkle.magnifyingglass",
                    description: Text("AI-powered semantic search could not find a close match. Try different wording or switch to Keyword.")
                )
            } else {
                ContentUnavailableView.search
            }
        } else {
            ContentUnavailableView(
                "No Matching Notes",
                systemImage: "tag",
                description: Text("No transcriptions match the selected filters.")
            )
        }
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

private struct TranscriptionSearchControlsView: View {
    let hasTranscriptions: Bool
    let availableSourceTags: [String]
    let allTags: [TranscriptionTag]
    let searchText: String
    @AppStorage(SmartSearchFeature.isEnabledKey) private var isSmartSearchEnabled = true
    @Binding var selectedSourceTags: Set<String>
    @Binding var selectedUserTagIds: Set<UUID>
    @Binding var searchMode: TranscriptionSearchMode

    var body: some View {
        if hasTranscriptions && (!availableSourceTags.isEmpty || !allTags.isEmpty) {
            TagFilterBar(
                sourceTags: availableSourceTags,
                userTags: allTags,
                selectedSourceTags: $selectedSourceTags,
                selectedUserTagIds: $selectedUserTagIds
            )
        }

        if isSmartSearchEnabled, !searchText.isEmpty {
            Picker("Search Mode", selection: $searchMode) {
                Text("All")
                    .tag(TranscriptionSearchMode.all)
                Label("Keyword", systemImage: "text.magnifyingglass")
                    .tag(TranscriptionSearchMode.keyword)
                Label("Smart", systemImage: "sparkle.magnifyingglass")
                    .tag(TranscriptionSearchMode.smart)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

private struct TranscriptionsListView: View {
    private static let floatingControlsInset: CGFloat = 120

    let displayedTranscriptions: [Transcription]
    let isSelectionMode: Bool
    let selectedTranscriptionIDs: Set<UUID>
    let newlyInsertedIDs: Set<UUID>
    let allTags: [TranscriptionTag]
    let topAnchorID: String
    let colorScheme: ColorScheme
    @Binding var showGoToTopButton: Bool
    let semanticScoreProvider: (UUID) -> Float?
    let audioURLProvider: (Transcription) -> URL?
    let onToggleSelection: (Transcription) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                EmptyView()
                    .id(topAnchorID)

                if isSelectionMode {
                    ForEach(displayedTranscriptions) { transcription in
                        SelectableTranscriptionRow(
                            transcription: transcription,
                            isSelected: selectedTranscriptionIDs.contains(transcription.id),
                            isNewlyInserted: newlyInsertedIDs.contains(transcription.id),
                            allTags: allTags,
                            semanticScore: semanticScoreProvider(transcription.id)
                        ) {
                            onToggleSelection(transcription)
                        }
                    }
                } else {
                    ForEach(displayedTranscriptions) { transcription in
                        TranscriptionNavigationRow(
                            transcription: transcription,
                            isNewlyInserted: newlyInsertedIDs.contains(transcription.id),
                            allTags: allTags,
                            semanticScore: semanticScoreProvider(transcription.id),
                            audioURL: audioURLProvider(transcription)
                        )
                    }
                    .onDelete(perform: onDelete)

                    if !displayedTranscriptions.isEmpty {
                        floatingControlsSpacer
                    }
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
            .overlay(alignment: .bottomLeading) {
                if showGoToTopButton {
                    ScrollToTopButton(backgroundColor: .indigo.opacity(colorScheme == .dark ? 0.4 : 0.7)) {
                        withAnimation {
                            proxy.scrollTo(topAnchorID, anchor: .top)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .scale(scale: 2)), removal: .opacity.combined(with: .scale(scale: 0.5))))
                }
            }
        }
    }

    private var floatingControlsSpacer: some View {
        Color.clear
            .frame(height: Self.floatingControlsInset)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct CombinedSearchResultsView: View {
    private static let floatingControlsInset: CGFloat = 120

    let keywordTranscriptions: [Transcription]
    let smartTranscriptions: [Transcription]
    let isSelectionMode: Bool
    let selectedTranscriptionIDs: Set<UUID>
    let newlyInsertedIDs: Set<UUID>
    let allTags: [TranscriptionTag]
    let topAnchorID: String
    let colorScheme: ColorScheme
    @Binding var showGoToTopButton: Bool
    let semanticScoreProvider: (UUID) -> Float?
    let audioURLProvider: (Transcription) -> URL?
    let onToggleSelection: (Transcription) -> Void
    let onDeleteKeyword: (IndexSet) -> Void
    let onDeleteSmart: (IndexSet) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                EmptyView()
                    .id(topAnchorID)

                if !keywordTranscriptions.isEmpty {
                    Section("Keyword Matches") {
                        rows(
                            transcriptions: keywordTranscriptions,
                            semanticScoreProvider: { _ in nil },
                            onDelete: onDeleteKeyword
                        )
                    }
                }

                if !smartTranscriptions.isEmpty {
                    Section("Smart Matches") {
                        rows(
                            transcriptions: smartTranscriptions,
                            semanticScoreProvider: semanticScoreProvider,
                            onDelete: onDeleteSmart
                        )
                    }
                }

                floatingControlsSpacer
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
            .overlay(alignment: .bottomLeading) {
                if showGoToTopButton {
                    ScrollToTopButton(backgroundColor: .indigo.opacity(colorScheme == .dark ? 0.4 : 0.7)) {
                        withAnimation {
                            proxy.scrollTo(topAnchorID, anchor: .top)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .scale(scale: 2)), removal: .opacity.combined(with: .scale(scale: 0.5))))
                }
            }
        }
    }

    private var floatingControlsSpacer: some View {
        Color.clear
            .frame(height: Self.floatingControlsInset)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func rows(
        transcriptions: [Transcription],
        semanticScoreProvider: @escaping (UUID) -> Float?,
        onDelete: @escaping (IndexSet) -> Void
    ) -> some View {
        if isSelectionMode {
            ForEach(transcriptions) { transcription in
                SelectableTranscriptionRow(
                    transcription: transcription,
                    isSelected: selectedTranscriptionIDs.contains(transcription.id),
                    isNewlyInserted: newlyInsertedIDs.contains(transcription.id),
                    allTags: allTags,
                    semanticScore: semanticScoreProvider(transcription.id)
                ) {
                    onToggleSelection(transcription)
                }
            }
        } else {
            ForEach(transcriptions) { transcription in
                TranscriptionNavigationRow(
                    transcription: transcription,
                    isNewlyInserted: newlyInsertedIDs.contains(transcription.id),
                    allTags: allTags,
                    semanticScore: semanticScoreProvider(transcription.id),
                    audioURL: audioURLProvider(transcription)
                )
            }
            .onDelete(perform: onDelete)
        }
    }
}

private struct SelectableTranscriptionRow: View {
    let transcription: Transcription
    let isSelected: Bool
    let isNewlyInserted: Bool
    let allTags: [TranscriptionTag]
    let semanticScore: Float?
    let onTap: () -> Void

    init(
        transcription: Transcription,
        isSelected: Bool,
        isNewlyInserted: Bool,
        allTags: [TranscriptionTag],
        semanticScore: Float? = nil,
        onTap: @escaping () -> Void
    ) {
        self.transcription = transcription
        self.isSelected = isSelected
        self.isNewlyInserted = isNewlyInserted
        self.allTags = allTags
        self.semanticScore = semanticScore
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .animation(.snappy(duration: 0.15), value: isSelected)

                TranscriptionRowView(
                    transcription: transcription,
                    isNewlyInserted: isNewlyInserted,
                    allTags: allTags,
                    semanticScore: semanticScore
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TranscriptionNavigationRow: View {
    let transcription: Transcription
    let isNewlyInserted: Bool
    let allTags: [TranscriptionTag]
    let semanticScore: Float?
    let audioURL: URL?

    var body: some View {
        NavigationLink {
            TranscriptionDetailView(transcription: transcription)
                .onAppear {
                    if semanticScore != nil {
                        RateAppManager.requestReviewIfAppropriate()
                    }
                }
        } label: {
            TranscriptionRowView(
                transcription: transcription,
                isNewlyInserted: isNewlyInserted,
                allTags: allTags,
                semanticScore: semanticScore
            )
        }
        .contextMenu {
            Section("Share") {
                if let latestVariation = transcription.variations?
                    .sorted(by: { $0.createdAt < $1.createdAt }).last {
                    let presetTitle = PresetCatalog.displayName(
                        for: latestVariation.presetId,
                        fallback: latestVariation.presetDisplayName
                    )

                    ShareLink(item: latestVariation.text) {
                        Label {
                            Text(presetTitle)
                        } icon: {
                            PresetIconView(icon: PresetCatalog.icon(for: latestVariation.presetId))
                        }
                    }
                }

                ShareLink(item: transcription.text) {
                    Label("Original Text", systemImage: "text.alignleft")
                }

                if let audioURL {
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
            selectedTranscriptionIDs: $selectedIDs,
            displayedTranscriptionIDs: .constant([]),
            savedFilter: SavedNotesFilter()
        )
    }
    .environment(AppState())
}
#endif
