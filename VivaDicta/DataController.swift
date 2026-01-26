//
//  DataController.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import Foundation
import SwiftData

/// Data access layer for SwiftData operations on transcriptions.
///
/// `DataController` provides a convenient interface for querying and managing
/// ``Transcription`` records in the SwiftData store.
///
/// ## Overview
///
/// The controller provides:
/// - Flexible transcription queries with predicates and sorting
/// - Single transcription lookup by ID
/// - Count queries for statistics
/// - Conversion to ``TranscriptionEntity`` for Spotlight indexing
///
/// ## Usage
///
/// ```swift
/// let controller = DataController(modelContainer: container)
///
/// // Fetch recent transcriptions
/// let recent = try controller.transcriptions(limit: 10)
///
/// // Fetch by ID
/// if let transcription = try controller.transcription(byId: someUUID) {
///     // Use transcription
/// }
///
/// // Count all transcriptions
/// let count = try controller.transcriptionCount()
/// ```
@Observable
class DataController {
    /// The SwiftData context for database operations.
    var modelContext: ModelContext

    /// Creates a DataController with the specified model container.
    ///
    /// - Parameter modelContainer: The SwiftData container to use.
    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
    }

    #if DEBUG
    /// Preview initializer with in-memory storage.
    convenience init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transcription.self, configurations: config)
        self.init(modelContainer: container)
    }
    #endif

    /// Fetches transcriptions matching the specified criteria.
    ///
    /// - Parameters:
    ///   - predicate: Filter predicate (defaults to all transcriptions).
    ///   - sortBy: Sort descriptors (defaults to newest first).
    ///   - limit: Maximum number of results (defaults to unlimited).
    /// - Returns: Array of matching transcriptions.
    /// - Throws: Any SwiftData fetch error.
    func transcriptions(
        matching predicate: Predicate<Transcription> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Transcription>] = [SortDescriptor(\.timestamp, order: .reverse)],
        limit: Int? = nil
    ) throws -> [Transcription] {
        var transcriptionsDescriptor = FetchDescriptor<Transcription>(predicate: predicate, sortBy: sortBy)
        transcriptionsDescriptor.fetchLimit = limit
        return try modelContext.fetch(transcriptionsDescriptor)
    }

    /// Fetches a single transcription by its ID.
    ///
    /// - Parameter id: The UUID of the transcription to find.
    /// - Returns: The transcription if found, or `nil`.
    /// - Throws: Any SwiftData fetch error.
    func transcription(byId id: UUID) throws -> Transcription? {
        try transcriptions(matching: #Predicate { $0.id == id }, limit: 1).first
    }

    /// Fetches transcriptions as entities for Spotlight indexing.
    ///
    /// - Parameters:
    ///   - predicate: Filter predicate (defaults to all transcriptions).
    ///   - sortBy: Sort descriptors (defaults to newest first).
    ///   - limit: Maximum number of results (defaults to unlimited).
    /// - Returns: Array of ``TranscriptionEntity`` instances.
    /// - Throws: Any SwiftData fetch error.
    func transcriptionEntities(
        matching predicate: Predicate<Transcription> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Transcription>] = [SortDescriptor(\.timestamp, order: .reverse)],
        limit: Int? = nil
    ) throws -> [TranscriptionEntity] {
        try transcriptions(matching: predicate, sortBy: sortBy, limit: limit).map(\.entity)
    }

    /// Returns the count of transcriptions matching the predicate.
    ///
    /// - Parameter predicate: Filter predicate (defaults to all transcriptions).
    /// - Returns: The number of matching transcriptions.
    /// - Throws: Any SwiftData fetch error.
    func transcriptionCount(
        matching predicate: Predicate<Transcription> = #Predicate { _ in true }
    ) throws -> Int {
        let transcriptionsDescriptor = FetchDescriptor<Transcription>(predicate: predicate)
        return try modelContext.fetchCount(transcriptionsDescriptor)
    }
}
