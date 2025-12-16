//
//  DataController.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import Foundation
import SwiftData

@Observable
class DataController {
    var modelContext: ModelContext
    var path = [Transcription]()
    var searchText = ""

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
    }

    #if DEBUG
    /// Preview initializer with in-memory storage
    convenience init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transcription.self, configurations: config)
        self.init(modelContainer: container)
    }
    #endif

    func transcriptions(
        matching predicate: Predicate<Transcription> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Transcription>] = [SortDescriptor(\.timestamp, order: .reverse)],
        limit: Int? = nil
    ) throws -> [Transcription] {
        var transcriptionsDescriptor = FetchDescriptor<Transcription>(predicate: predicate, sortBy: sortBy)
        transcriptionsDescriptor.fetchLimit = limit
        return try modelContext.fetch(transcriptionsDescriptor)
    }

    func transcriptionEntities(
        matching predicate: Predicate<Transcription> = #Predicate { _ in true },
        sortBy: [SortDescriptor<Transcription>] = [SortDescriptor(\.timestamp, order: .reverse)],
        limit: Int? = nil
    ) throws -> [TranscriptionEntity] {
        try transcriptions(matching: predicate, sortBy: sortBy, limit: limit).map(\.entity)
    }

    func transcriptionCount(
        matching predicate: Predicate<Transcription> = #Predicate { _ in true }
    ) throws -> Int {
        let transcriptionsDescriptor = FetchDescriptor<Transcription>(predicate: predicate)
        return try modelContext.fetchCount(transcriptionsDescriptor)
    }

    @MainActor
    func select(entity: TranscriptionEntity) async throws {
        try await select(id: entity.id)
    }

    @MainActor
    func select(id: UUID) async throws {
        let results = try transcriptions(matching: #Predicate {
            $0.id == id
        })

        if let first = results.first {
            path = [first]
        }
    }
}
