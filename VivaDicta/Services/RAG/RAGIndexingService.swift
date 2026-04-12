//
//  RAGIndexingService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.11
//

import Foundation
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

/// Manages the vector index for RAG-based Smart Search.
///
/// Indexes transcription notes into a local vector database using LumoKit/VecturaKit.
/// Supports bulk indexing on first launch, incremental updates on note changes,
/// and semantic search for the Smart Search chat feature.
@MainActor
final class RAGIndexingService {
    static let shared = RAGIndexingService()

    private let logger = Logger(category: .ragIndexing)
    private let searchLogger = Logger(category: .ragSearch)

    // MARK: - UserDefaults Keys

    private let indexingCompletedKey = "ragIndexingCompleted_v1"
    private let chunkMappingKey = "ragChunkMapping_v1"
    private let transcriptionHashesKey = "ragTranscriptionHashes_v1"

    // MARK: - LumoKit Instance

    nonisolated(unsafe) private var lumoKit: LumoKit?
    private var isInitializing = false

    /// Whether the initial bulk indexing is currently running.
    private(set) var isIndexing = false

    /// Number of transcriptions that have been indexed.
    private(set) var indexedTranscriptionCount = 0

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
    }

    // MARK: - Initialization

    /// Lazily initializes LumoKit with VecturaKit configuration.
    private func ensureLumoKit() async throws {
        if lumoKit != nil {
            return
        }

        guard !isInitializing else {
            throw RAGError.initializationInProgress
        }

        isInitializing = true
        defer { isInitializing = false }

        logger.logInfo("Initializing LumoKit with VecturaKit...")

        let storageDir = RAGIndexingService.storageDirectoryURL
        try await initializeLumoKit(storageDirectory: storageDir)
        logger.logInfo("LumoKit initialized successfully")
    }

    // MARK: - Nonisolated LumoKit Wrappers
    //
    // LumoKit is not Sendable, so calling its async methods from @MainActor
    // would send a non-Sendable reference across an actor boundary. These
    // wrappers are `nonisolated` so no actor hop occurs and no sending check
    // applies. The `lumoKit` property is `nonisolated(unsafe)`; concurrent
    // access is fine because LumoKit internally serializes via VecturaKit.

    nonisolated private func initializeLumoKit(storageDirectory: URL) async throws {
        let searchOptions = VecturaConfig.SearchOptions(
            defaultNumResults: 5,
            minThreshold: 0.3
        )
        let config = try VecturaConfig(
            name: "vivedicta-rag",
            directoryURL: storageDirectory,
            searchOptions: searchOptions
        )
        let chunkingConfig = try ChunkingConfig(
            chunkSize: 500,
            overlapPercentage: 0.15,
            strategy: .semantic,
            contentType: .prose
        )
        let kit = try await LumoKit(config: config, chunkingConfig: chunkingConfig)
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
        guard !isIndexing else { return }
        isIndexing = true
        defer {
            isIndexing = false
            indexedTranscriptionCount = chunkMapping.count
        }

        do {
            try await ensureLumoKit()
            let descriptor = FetchDescriptor<Transcription>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let transcriptions = try modelContext.fetch(descriptor)

            if transcriptions.isEmpty {
                logger.logInfo("No transcriptions to index")
                UserDefaults.standard.set(true, forKey: indexingCompletedKey)
                return
            }

            let isFirstRun = !UserDefaults.standard.bool(forKey: indexingCompletedKey)
            var hashes = transcriptionHashes
            var mapping = chunkMapping
            var indexed = 0
            var skipped = 0

            for transcription in transcriptions {
                let content = indexableContent(for: transcription)
                guard !content.isEmpty else {
                    skipped += 1
                    continue
                }

                let contentHash = content.hashValue.description
                let idString = transcription.id.uuidString

                // Skip if content hasn't changed since last index
                if !isFirstRun, hashes[idString] == contentHash {
                    skipped += 1
                    continue
                }

                // Remove old chunks if re-indexing
                if let oldChunkIds = mapping[idString] {
                    let uuids = oldChunkIds.compactMap { UUID(uuidString: $0) }
                    if !uuids.isEmpty {
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
                    skipped += 1
                    continue
                }

                let chunkIds = try await _addDocuments(texts: chunks.map(\.text))
                mapping[idString] = chunkIds.map(\.uuidString)
                hashes[idString] = contentHash
                indexed += 1
            }

            // Clean up mappings for deleted transcriptions
            let currentIds = Set(transcriptions.map(\.id.uuidString))
            let orphanedIds = Set(mapping.keys).subtracting(currentIds)
            for orphanId in orphanedIds {
                if let chunkIds = mapping[orphanId] {
                    let uuids = chunkIds.compactMap { UUID(uuidString: $0) }
                    if !uuids.isEmpty {
                        try? await _deleteChunks(ids: uuids)
                    }
                }
                mapping.removeValue(forKey: orphanId)
                hashes.removeValue(forKey: orphanId)
            }

            chunkMapping = mapping
            transcriptionHashes = hashes
            UserDefaults.standard.set(true, forKey: indexingCompletedKey)

            let totalChunks = try await _documentCount()
            logger.logInfo("Indexing complete: \(indexed) indexed, \(skipped) skipped, \(orphanedIds.count) orphans removed, \(totalChunks) total chunks")
        } catch {
            logger.logError("Bulk indexing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Incremental Updates

    /// Indexes or re-indexes a single transcription after creation or edit.
    func indexTranscription(_ transcription: Transcription) async {
        do {
            try await ensureLumoKit()
            let content = indexableContent(for: transcription)
            let idString = transcription.id.uuidString

            guard !content.isEmpty else {
                logger.logWarning("Empty content for transcription \(idString), skipping")
                return
            }

            var mapping = chunkMapping
            var hashes = transcriptionHashes

            // Remove old chunks
            if let oldChunkIds = mapping[idString] {
                let uuids = oldChunkIds.compactMap { UUID(uuidString: $0) }
                if !uuids.isEmpty {
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

            let chunkIds = try await _addDocuments(texts: chunks.map(\.text))
            mapping[idString] = chunkIds.map(\.uuidString)
            hashes[idString] = content.hashValue.description

            chunkMapping = mapping
            transcriptionHashes = hashes
            indexedTranscriptionCount = mapping.count

            logger.logInfo("Indexed transcription \(idString): \(chunkIds.count) chunks")
        } catch {
            logger.logError("Failed to index transcription: \(error.localizedDescription)")
        }
    }

    /// Removes all chunks for a deleted transcription.
    func removeTranscription(id: UUID) async {
        do {
            try await ensureLumoKit()
            let idString = id.uuidString
            var mapping = chunkMapping
            var hashes = transcriptionHashes

            if let chunkIds = mapping[idString] {
                let uuids = chunkIds.compactMap { UUID(uuidString: $0) }
                if !uuids.isEmpty {
                    try await _deleteChunks(ids: uuids)
                }
                mapping.removeValue(forKey: idString)
                hashes.removeValue(forKey: idString)
                chunkMapping = mapping
                transcriptionHashes = hashes
                indexedTranscriptionCount = mapping.count
                logger.logInfo("Removed \(uuids.count) chunks for transcription \(idString)")
            }
        } catch {
            logger.logError("Failed to remove transcription chunks: \(error.localizedDescription)")
        }
    }

    /// Clears the entire vector store and re-indexes all notes.
    func reindexAll(modelContext: ModelContext) async {
        do {
            try await ensureLumoKit()
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

    // MARK: - Search

    /// Searches the vector index for chunks relevant to the query.
    ///
    /// Returns results mapped back to source transcription IDs, deduplicated
    /// by transcription (keeps highest-scoring chunk per note).
    func search(query: String, topK: Int = 5) async throws -> [RAGSearchResult] {
        try await ensureLumoKit()

        let results = try await _semanticSearch(
            query: query,
            numResults: topK * 2, // Over-fetch to allow deduplication
            threshold: 0.3
        )

        guard !results.isEmpty else {
            searchLogger.logInfo("No results for query: \(query.prefix(50))")
            return []
        }

        // Map chunk IDs back to transcription IDs
        let mapping = chunkMapping
        var transcriptionResults: [UUID: RAGSearchResult] = [:]

        for result in results {
            let chunkIdString = result.id.uuidString

            // Find which transcription owns this chunk
            guard let (transcriptionIdString, _) = mapping.first(where: { $0.value.contains(chunkIdString) }),
                  let transcriptionId = UUID(uuidString: transcriptionIdString) else {
                continue
            }

            // Keep highest-scoring chunk per transcription
            if let existing = transcriptionResults[transcriptionId], existing.relevanceScore >= result.score {
                continue
            }

            transcriptionResults[transcriptionId] = RAGSearchResult(
                transcriptionId: transcriptionId,
                chunkText: result.text,
                relevanceScore: result.score
            )
        }

        let sorted = transcriptionResults.values
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(topK)

        searchLogger.logInfo("Search '\(query.prefix(50))': \(sorted.count) transcriptions matched")
        return Array(sorted)
    }

    // MARK: - Helpers

    /// Returns the best available text content for indexing.
    /// Prefers `enhancedText` (AI-processed) over raw `text`.
    private func indexableContent(for transcription: Transcription) -> String {
        let text = transcription.enhancedText ?? transcription.text
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum RAGError: LocalizedError {
    case initializationInProgress
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .initializationInProgress: "RAG service is still initializing"
        case .notInitialized: "RAG service is not initialized"
        }
    }
}
