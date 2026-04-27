//
//  RAGIndexingService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import CryptoKit
import Foundation
import Observation
import SwiftData
import os
@preconcurrency import LumoKit
@preconcurrency import VecturaKit

/// Result of a RAG semantic search, mapping chunks back to source transcriptions.
struct RAGSearchResult: Sendable {
    let transcriptionId: UUID
    let chunkText: String
    let relevanceScore: Float
}

private struct RankedChunkCandidate {
    let transcriptionId: UUID
    let chunkText: String
    let semanticScore: Float
}

/// Manages the vector index for RAG-based Smart Search.
///
/// Indexes transcription notes into a local vector database using LumoKit/VecturaKit.
/// Supports bulk indexing on first launch, incremental updates on note changes,
/// and semantic search for the Smart Search chat feature.
@Observable
@MainActor
final class RAGIndexingService {
    static let shared = RAGIndexingService()
    private static let previewCharacterLimit = 180
    private static let maxLoggedChunksPerNote = 3
    nonisolated(unsafe) private static let semanticSearchThreshold: Float = 0.25
    private static let diagnosticThresholds: [Float] = [0.2, 0.0]
    nonisolated(unsafe) private static let indexVersion = "v14_potion_base_32m"
    nonisolated(unsafe) private static let vectorStoreName = "vivadicta-rag-\(indexVersion)"

    @ObservationIgnored
    private let logger = Logger(category: .ragIndexing)
    @ObservationIgnored
    private let searchLogger = Logger(category: .ragSearch)

    // MARK: - UserDefaults Keys

    private let indexingCompletedKey = "ragIndexingCompleted_\(RAGIndexingService.indexVersion)"
    private let chunkMappingKey = "ragChunkMapping_\(RAGIndexingService.indexVersion)"
    private let transcriptionHashesKey = "ragTranscriptionHashes_\(RAGIndexingService.indexVersion)"

    // MARK: - LumoKit Instance

    @ObservationIgnored
    nonisolated(unsafe) private var lumoKit: LumoKit?
    @ObservationIgnored
    private var initializationTask: Task<Void, Error>?

    /// Whether the initial bulk indexing is currently running.
    private(set) var isIndexing = false

    /// Number of transcriptions that have been indexed.
    private(set) var indexedTranscriptionCount = 0

    @ObservationIgnored
    private var latestMutationTokenByTranscriptionID: [String: Int] = [:]
    @ObservationIgnored
    private var nextMutationToken = 0

    // MARK: - Chunk Mapping

    /// Maps transcription UUID string -> array of chunk UUID strings.
    /// Stored in UserDefaults for persistence across launches.
    private var chunkMapping: [String: [String]] {
        get {
            UserDefaults.standard.dictionary(forKey: chunkMappingKey) as? [String: [String]] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: chunkMappingKey)
        }
    }

    /// Maps transcription UUID string -> hash of indexed content.
    /// Used to detect when a note has been edited and needs re-indexing.
    private var transcriptionHashes: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: transcriptionHashesKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: transcriptionHashesKey)
        }
    }

    private init() {
        indexedTranscriptionCount = chunkMapping.count
        logger.logInfo(
            "RAG service restored featureEnabled=\(SmartSearchFeature.isEnabled) indexingCompleted=\(UserDefaults.standard.bool(forKey: indexingCompletedKey)) mappedNotes=\(chunkMapping.count) storage=\(Self.storageDirectoryURL.path)"
        )
    }

    // MARK: - Initialization

    /// Lazily initializes LumoKit with VecturaKit configuration.
    private func ensureLumoKit() async throws {
        if lumoKit != nil {
            return
        }

        if let initializationTask {
            return try await initializationTask.value
        }

        let storageDir = RAGIndexingService.storageDirectoryURL
        let task = Task { [storageDir, logger] in
            logger.logInfo("Initializing LumoKit with SwiftEmbedder potion-base-32M...")
            try await initializeLumoKit(storageDirectory: storageDir)
            logger.logInfo("LumoKit initialized successfully")
        }
        initializationTask = task

        do {
            try await task.value
        } catch {
            initializationTask = nil
            throw error
        }

        initializationTask = nil
    }

    // MARK: - Nonisolated LumoKit Wrappers
    //
    // LumoKit is not Sendable, so calling its async methods from @MainActor
    // would send a non-Sendable reference across an actor boundary. These
    // wrappers are `nonisolated` so no actor hop occurs and no sending check
    // applies. The `lumoKit` property is `nonisolated(unsafe)`; concurrent
    // access is fine because LumoKit internally serializes via VecturaKit.

    nonisolated private func initializeLumoKit(storageDirectory: URL) async throws {
        let logger = Logger(category: .ragIndexing)
        let searchOptions = VecturaConfig.SearchOptions(
            defaultNumResults: 5,
            minThreshold: Self.semanticSearchThreshold
        )
        let config = try VecturaConfig(
            name: Self.vectorStoreName,
            directoryURL: storageDirectory,
            searchOptions: searchOptions
        )
        let chunkingConfig = try ChunkingConfig(
            chunkSize: 500,
            overlapPercentage: 0.15,
            strategy: .semantic,
            contentType: .prose
        )
        logger.logInfo(
            """
            RAG init config:
            db=\(config.name)
            storage=\(storageDirectory.path)
            results=\(searchOptions.defaultNumResults)
            threshold=\(Double(searchOptions.minThreshold ?? 0).formatted(.number.precision(.fractionLength(2))))
            chunkSize=\(chunkingConfig.chunkSize)
            overlap=\(Double(chunkingConfig.overlapPercentage).formatted(.percent.precision(.fractionLength(0))))
            strategy=\(String(describing: chunkingConfig.strategy))
            """
        )
        logger.logInfo("RAG init embedder=SwiftEmbedder model=minishlab/potion-base-32M")
        let kit = try await LumoKit(
            config: config,
            chunkingConfig: chunkingConfig,
            modelSource: .id("minishlab/potion-base-32M")
        )
        lumoKit = kit
    }

    nonisolated private func _addDocuments(texts: [String]) async throws -> [UUID] {
        guard let kit = lumoKit else { throw RAGError.notInitialized }
        return try await kit.addDocuments(texts: texts)
    }

    nonisolated private func _deleteChunks(ids: [UUID]) async throws {
        guard let kit = lumoKit else { throw RAGError.notInitialized }
        try await kit.deleteChunks(ids: ids)
    }

    nonisolated private func _semanticSearch(query: String, numResults: Int, threshold: Float) async throws -> [VecturaSearchResult] {
        guard let kit = lumoKit else { throw RAGError.notInitialized }
        return try await kit.semanticSearch(query: query, numResults: numResults, threshold: threshold)
    }

    nonisolated private func _documentCount() async throws -> Int {
        guard let kit = lumoKit else { throw RAGError.notInitialized }
        return try await kit.documentCount()
    }

    nonisolated private func _resetDB() async throws {
        guard let kit = lumoKit else { throw RAGError.notInitialized }
        try await kit.resetDB()
    }

    nonisolated private func _chunkText(_ text: String, config: ChunkingConfig) throws -> [Chunk] {
        guard let kit = lumoKit else { throw RAGError.notInitialized }
        return try kit.chunkText(text, config: config)
    }

    /// The local storage directory for vector data (not synced via CloudKit).
    private static var storageDirectoryURL: URL {
        let documentsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return documentsURL.appending(path: "RAGIndex")
    }

    // MARK: - Bulk Indexing

    /// Indexes all transcriptions on first launch, or incrementally updates changed notes.
    func indexAllIfNeeded(modelContext: ModelContext) async {
        guard SmartSearchFeature.isEnabled else {
            logger.logInfo("RAG indexing skipped because Smart Search is disabled")
            indexedTranscriptionCount = chunkMapping.count
            return
        }

        guard !isIndexing else {
            logger.logDebug("RAG bulk indexing request ignored because indexing is already in progress")
            return
        }
        isIndexing = true
        defer {
            isIndexing = false
            indexedTranscriptionCount = chunkMapping.count
        }

        do {
            try await ensureLumoKit()
            await logIndexSnapshot(reason: "bulk-index-start", using: logger)
            let descriptor = FetchDescriptor<Transcription>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let transcriptions = try modelContext.fetch(descriptor)
            logger.logInfo(
                "RAG bulk indexing started: transcriptions=\(transcriptions.count) indexedMappings=\(chunkMapping.count)"
            )

            if transcriptions.isEmpty {
                logger.logInfo("No transcriptions to index")
                UserDefaults.standard.set(true, forKey: indexingCompletedKey)
                return
            }

            let isFirstRun = !UserDefaults.standard.bool(forKey: indexingCompletedKey)
            var indexed = 0
            var skipped = 0

            for transcription in transcriptions {
                let idString = transcription.id.uuidString
                let content = indexableContent(for: transcription)
                let noteTitle = Self.noteTitle(from: content, fallback: idString)
                let mutationToken = beginMutation(for: idString)

                guard !content.isEmpty else {
                    logger.logInfo("RAG removing indexed data for empty note id=\(idString) title='\(noteTitle)'")
                    if let oldChunkIds = chunkMapping[idString] {
                        let uuids = oldChunkIds.compactMap { UUID(uuidString: $0) }
                        if !uuids.isEmpty {
                            try? await _deleteChunks(ids: uuids)
                        }
                    }
                    guard isCurrentMutation(mutationToken, for: idString) else {
                        skipped += 1
                        continue
                    }
                    removeIndexedMetadata(for: idString)
                    skipped += 1
                    continue
                }

                let contentHash = stableHash(content)

                // Skip if content hasn't changed since last index
                if !isFirstRun, transcriptionHashes[idString] == contentHash {
                    logger.logDebug(
                        "RAG unchanged note id=\(idString) title='\(noteTitle)' hash=\(contentHash.prefix(12))"
                    )
                    skipped += 1
                    continue
                }

                logger.logInfo(
                    "RAG indexing note id=\(idString) title='\(noteTitle)' chars=\(content.count) hash=\(contentHash.prefix(12))"
                )

                // Remove old chunks if re-indexing
                if let oldChunkIds = chunkMapping[idString] {
                    let uuids = oldChunkIds.compactMap { UUID(uuidString: $0) }
                    if !uuids.isEmpty {
                        logger.logInfo("RAG removing \(uuids.count) existing chunks for note id=\(idString)")
                        try await _deleteChunks(ids: uuids)
                    }
                }

                // Chunk and index
                let chunks = try _chunkText(content, config: ChunkingConfig(
                    chunkSize: 500,
                    overlapPercentage: 0.15,
                    strategy: .semantic,
                    contentType: .prose
                ))
                guard !chunks.isEmpty else {
                    logger.logWarning("RAG produced 0 chunks for note id=\(idString) title='\(noteTitle)'")
                    skipped += 1
                    continue
                }

                logger.logInfo("RAG note id=\(idString) title='\(noteTitle)' chunked into \(chunks.count) chunks")
                for chunk in chunks.prefix(Self.maxLoggedChunksPerNote) {
                    logger.logDebug(
                        "RAG chunk note=\(idString) index=\(chunk.metadata.index) chars=\(chunk.text.count) preview='\(Self.preview(chunk.text))'"
                    )
                }

                let chunkIds = try await _addDocuments(texts: chunks.map(\.text))
                guard isCurrentMutation(mutationToken, for: idString) else {
                    logger.logInfo("RAG discarded stale bulk indexing result for note id=\(idString) title='\(noteTitle)'")
                    try? await _deleteChunks(ids: chunkIds)
                    skipped += 1
                    continue
                }

                updateIndexedMetadata(for: idString, chunkIDs: chunkIds, contentHash: contentHash)
                indexed += 1
                logger.logInfo(
                    "RAG stored \(chunkIds.count) chunks for note id=\(idString) firstChunkIDs=\(Self.joinedIDs(from: chunkIds))"
                )
            }

            // Clean up mappings for deleted transcriptions
            let currentIds = Set(transcriptions.map(\.id.uuidString))
            let orphanedIds = Set(chunkMapping.keys).subtracting(currentIds)
            for orphanId in orphanedIds {
                let mutationToken = beginMutation(for: orphanId)
                if let chunkIds = chunkMapping[orphanId] {
                    let uuids = chunkIds.compactMap { UUID(uuidString: $0) }
                    if !uuids.isEmpty {
                        try? await _deleteChunks(ids: uuids)
                    }
                }
                guard isCurrentMutation(mutationToken, for: orphanId) else {
                    continue
                }
                removeIndexedMetadata(for: orphanId)
            }

            UserDefaults.standard.set(true, forKey: indexingCompletedKey)

            let totalChunks = try await _documentCount()
            logger.logInfo("Indexing complete: \(indexed) indexed, \(skipped) skipped, \(orphanedIds.count) orphans removed, \(totalChunks) total chunks")
            await logIndexSnapshot(reason: "bulk-index-complete", using: logger)
            AnalyticsService.track(.ragIndexingCompleted(
                indexedCount: indexed,
                skippedCount: skipped,
                totalChunks: totalChunks,
                isFirstRun: isFirstRun
            ))
        } catch {
            logger.logError("Bulk indexing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Incremental Updates

    /// Indexes or re-indexes a single transcription after creation or edit.
    func indexTranscription(_ transcription: Transcription) async {
        guard SmartSearchFeature.isEnabled else {
            logger.logInfo("RAG single-note indexing skipped because Smart Search is disabled")
            return
        }

        do {
            try await ensureLumoKit()
            let content = indexableContent(for: transcription)
            let idString = transcription.id.uuidString
            let noteTitle = Self.noteTitle(from: content, fallback: idString)
            let mutationToken = beginMutation(for: idString)

            guard !content.isEmpty else {
                logger.logInfo("RAG removing indexed data for empty transcription \(idString)")
                if let oldChunkIds = chunkMapping[idString] {
                    let uuids = oldChunkIds.compactMap { UUID(uuidString: $0) }
                    if !uuids.isEmpty {
                        try await _deleteChunks(ids: uuids)
                    }
                }
                guard isCurrentMutation(mutationToken, for: idString) else {
                    return
                }
                removeIndexedMetadata(for: idString)
                return
            }

            // Remove old chunks
            if let oldChunkIds = chunkMapping[idString] {
                let uuids = oldChunkIds.compactMap { UUID(uuidString: $0) }
                if !uuids.isEmpty {
                    logger.logInfo("RAG reindex removing \(uuids.count) chunks for note id=\(idString) title='\(noteTitle)'")
                    try await _deleteChunks(ids: uuids)
                }
            }

            // Chunk and index
            let chunks = try _chunkText(content, config: ChunkingConfig(
                chunkSize: 500,
                overlapPercentage: 0.15,
                strategy: .semantic,
                contentType: .prose
            ))
            guard !chunks.isEmpty else { return }

            logger.logInfo("RAG single-note chunking id=\(idString) title='\(noteTitle)' chunks=\(chunks.count)")
            for chunk in chunks.prefix(Self.maxLoggedChunksPerNote) {
                logger.logDebug(
                    "RAG single-note chunk note=\(idString) index=\(chunk.metadata.index) chars=\(chunk.text.count) preview='\(Self.preview(chunk.text))'"
                )
            }

            let chunkIds = try await _addDocuments(texts: chunks.map(\.text))
            guard isCurrentMutation(mutationToken, for: idString) else {
                logger.logInfo("RAG discarded stale single-note indexing result for note id=\(idString) title='\(noteTitle)'")
                try? await _deleteChunks(ids: chunkIds)
                return
            }

            updateIndexedMetadata(for: idString, chunkIDs: chunkIds, contentHash: stableHash(content))
            indexedTranscriptionCount = chunkMapping.count

            logger.logInfo("Indexed transcription \(idString): \(chunkIds.count) chunks")
        } catch {
            logger.logError("Failed to index transcription: \(error.localizedDescription)")
        }
    }

    /// Removes all chunks for a deleted transcription.
    func removeTranscription(id: UUID) async {
        guard SmartSearchFeature.isEnabled else {
            var mapping = chunkMapping
            var hashes = transcriptionHashes
            mapping.removeValue(forKey: id.uuidString)
            hashes.removeValue(forKey: id.uuidString)
            chunkMapping = mapping
            transcriptionHashes = hashes
            indexedTranscriptionCount = mapping.count
            return
        }

        do {
            try await ensureLumoKit()
            let idString = id.uuidString
            let mutationToken = beginMutation(for: idString)

            if let chunkIds = chunkMapping[idString] {
                let uuids = chunkIds.compactMap { UUID(uuidString: $0) }
                if !uuids.isEmpty {
                    try await _deleteChunks(ids: uuids)
                }
                guard isCurrentMutation(mutationToken, for: idString) else {
                    return
                }
                removeIndexedMetadata(for: idString)
                indexedTranscriptionCount = chunkMapping.count
                logger.logInfo("Removed \(uuids.count) chunks for transcription \(idString)")
            }
        } catch {
            logger.logError("Failed to remove transcription chunks: \(error.localizedDescription)")
        }
    }

    /// Clears the entire vector store and re-indexes all notes.
    func reindexAll(modelContext: ModelContext) async {
        guard SmartSearchFeature.isEnabled else {
            await clearAll()
            return
        }

        do {
            try await ensureLumoKit()
            await logIndexSnapshot(reason: "reindex-request", using: logger)
            try await _resetDB()

            chunkMapping = [:]
            transcriptionHashes = [:]
            UserDefaults.standard.set(false, forKey: indexingCompletedKey)

            logger.logInfo("Cleared vector store, starting full re-index")
            await indexAllIfNeeded(modelContext: modelContext)
        } catch {
            logger.logError("Failed to reset and re-index: \(error.localizedDescription)")
        }
    }

    /// Clears the entire vector store and all local indexing metadata.
    func clearAll() async {
        do {
            try await ensureLumoKit()
            await logIndexSnapshot(reason: "clear-all-before-reset", using: logger)
            try await _resetDB()
        } catch {
            logger.logWarning("RAG reset skipped during clearAll: \(error.localizedDescription)")
        }

        chunkMapping = [:]
        transcriptionHashes = [:]
        UserDefaults.standard.set(false, forKey: indexingCompletedKey)
        indexedTranscriptionCount = 0
        logger.logInfo("Cleared Smart Search vector store and metadata")
    }

    // MARK: - Search

    /// Searches the vector index for chunks relevant to the query.
    ///
    /// Returns results mapped back to source transcription IDs, deduplicated
    /// by transcription (keeps highest-scoring chunk per note).
    func search(query: String, topK: Int = 5) async throws -> [RAGSearchResult] {
        guard SmartSearchFeature.isEnabled else {
            searchLogger.logInfo("RAG search skipped because Smart Search is disabled")
            return []
        }

        try await ensureLumoKit()
        let threshold = Self.semanticSearchThreshold
        let requestedResults = topK * 2
        let queryPreview = Self.preview(query, limit: 80)
        let mapping = chunkMapping
        let indexingCompleted = UserDefaults.standard.bool(forKey: indexingCompletedKey)

        searchLogger.logInfo(
            "RAG search start query='\(queryPreview)' topK=\(topK) requested=\(requestedResults) threshold=\(Double(threshold).formatted(.number.precision(.fractionLength(2)))) mappedNotes=\(mapping.count) indexedNotes=\(indexedTranscriptionCount) indexingCompleted=\(indexingCompleted)"
        )
        if mapping.isEmpty {
            searchLogger.logWarning("RAG search is running with 0 mapped notes - search will likely return no results")
            await logIndexSnapshot(reason: "search-start-empty-index", using: searchLogger)
        }

        let results = try await _semanticSearch(
            query: query,
            numResults: requestedResults, // Over-fetch to allow deduplication
            threshold: threshold
        )

        guard !results.isEmpty else {
            searchLogger.logInfo("No results for query: \(query.prefix(50))")
            await logIndexSnapshot(reason: "search-empty-results", using: searchLogger)
            await logDiagnosticSearchSweep(
                query: query,
                requestedResults: requestedResults,
                baseThreshold: threshold,
                mapping: mapping
            )
            AnalyticsService.track(.smartSearchQueryExecuted(
                queryLength: query.count,
                topK: topK,
                resultCount: 0
            ))
            return []
        }

        searchLogger.logInfo("RAG raw search returned \(results.count) chunk hits for query='\(queryPreview)'")

        // Map chunk IDs back to transcription IDs and keep the strongest chunk per note.
        var transcriptionResults: [UUID: RankedChunkCandidate] = [:]

        for (index, result) in results.enumerated() {
            let chunkIdString = result.id.uuidString

            // Find which transcription owns this chunk
            guard let transcriptionId = mapping
                .first(where: { $0.value.contains(chunkIdString) })
                .flatMap({ UUID(uuidString: $0.key) }) else {
                searchLogger.logWarning("RAG raw[\(index + 1)] chunkId=\(chunkIdString) could not be mapped to a transcription")
                continue
            }

            let candidate = RankedChunkCandidate(
                transcriptionId: transcriptionId,
                chunkText: result.text,
                semanticScore: result.score
            )

            if let existing = transcriptionResults[transcriptionId], existing.semanticScore >= candidate.semanticScore {
                continue
            }

            transcriptionResults[transcriptionId] = candidate
        }

        let finalResults = Array(
            transcriptionResults.values
            .sorted { $0.semanticScore > $1.semanticScore }
            .prefix(topK)
            .map {
                RAGSearchResult(
                    transcriptionId: $0.transcriptionId,
                    chunkText: $0.chunkText,
                    relevanceScore: $0.semanticScore
                )
            }
        )

        if finalResults.isEmpty {
            searchLogger.logWarning("RAG semantic search returned chunk hits but none could be mapped back to transcriptions")
            await logIndexSnapshot(reason: "search-unmapped-raw-hits", using: searchLogger)
        }
        searchLogger.logInfo("Search '\(query.prefix(50))': \(finalResults.count) transcriptions matched")
        AnalyticsService.track(.smartSearchQueryExecuted(
            queryLength: query.count,
            topK: topK,
            resultCount: finalResults.count
        ))
        return finalResults
    }

    // MARK: - Helpers

    /// Returns the original transcription text for indexing.
    ///
    /// Smart Search intentionally indexes the raw note content instead of
    /// `enhancedText` so retrieval is not biased toward shortened summaries
    /// or stylistic rewrites.
    private func indexableContent(for transcription: Transcription) -> String {
        transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Deterministic SHA-256 hash used for change detection. Unlike `String.hashValue`,
    /// this is stable across launches and devices.
    private func stableHash(_ content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return Data(digest).base64EncodedString()
    }

    nonisolated private static func preview(_ text: String, limit: Int = 180) -> String {
        let flattened = text
            .replacing("\n", with: " ")
            .replacing("\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard flattened.count > limit else { return flattened }
        return String(flattened.prefix(limit)) + "..."
    }

    nonisolated private static func noteTitle(from text: String, fallback: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = firstLine.map { String($0.prefix(60)) } ?? fallback
        return title.isEmpty ? fallback : title
    }

    nonisolated private static func joinedIDs(from ids: [UUID], maxCount: Int = 3) -> String {
        ids.prefix(maxCount).map(\.uuidString).joined(separator: ", ")
    }

    private func beginMutation(for idString: String) -> Int {
        nextMutationToken += 1
        let token = nextMutationToken
        latestMutationTokenByTranscriptionID[idString] = token
        return token
    }

    private func isCurrentMutation(_ token: Int, for idString: String) -> Bool {
        latestMutationTokenByTranscriptionID[idString] == token
    }

    private func updateIndexedMetadata(for idString: String, chunkIDs: [UUID], contentHash: String) {
        var mapping = chunkMapping
        var hashes = transcriptionHashes
        mapping[idString] = chunkIDs.map(\.uuidString)
        hashes[idString] = contentHash
        chunkMapping = mapping
        transcriptionHashes = hashes
        indexedTranscriptionCount = mapping.count
    }

    private func removeIndexedMetadata(for idString: String) {
        var mapping = chunkMapping
        var hashes = transcriptionHashes
        mapping.removeValue(forKey: idString)
        hashes.removeValue(forKey: idString)
        chunkMapping = mapping
        transcriptionHashes = hashes
        indexedTranscriptionCount = mapping.count
    }

    private func logDiagnosticSearchSweep(
        query: String,
        requestedResults: Int,
        baseThreshold: Float,
        mapping: [String: [String]]
    ) async {
        for diagnosticThreshold in Self.diagnosticThresholds where diagnosticThreshold < baseThreshold {
            do {
                let diagnosticResults = try await _semanticSearch(
                    query: query,
                    numResults: requestedResults,
                    threshold: diagnosticThreshold
                )
                let mappedCount = diagnosticResults.reduce(into: 0) { count, result in
                    let chunkIdString = result.id.uuidString
                    if mapping.first(where: { $0.value.contains(chunkIdString) }) != nil {
                        count += 1
                    }
                }

                searchLogger.logInfo(
                    "RAG diagnostic threshold=\(Double(diagnosticThreshold).formatted(.number.precision(.fractionLength(2)))) rawHits=\(diagnosticResults.count) mappedRawHits=\(mappedCount)"
                )
            } catch {
                searchLogger.logWarning(
                    "RAG diagnostic threshold=\(Double(diagnosticThreshold).formatted(.number.precision(.fractionLength(2)))) failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private func logIndexSnapshot(reason: String, using logger: Logger) async {
        let storedChunksText: String
        if let storedChunks = try? await _documentCount() {
            storedChunksText = String(storedChunks)
        } else {
            storedChunksText = "unavailable"
        }

        logger.logInfo(
            "RAG snapshot reason=\(reason) featureEnabled=\(SmartSearchFeature.isEnabled) indexingCompleted=\(UserDefaults.standard.bool(forKey: indexingCompletedKey)) mappedNotes=\(chunkMapping.count) indexedNotes=\(indexedTranscriptionCount) storedChunks=\(storedChunksText) storage=\(Self.storageDirectoryURL.path)"
        )
    }
}

// MARK: - Errors

enum RAGError: LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized: "RAG service is not initialized"
        }
    }
}
