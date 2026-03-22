//
//  RecentNotesCacheSync.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.22
//

import Foundation
import SwiftData

extension RecentNotesCache {
    /// Syncs the cache with SwiftData, populating it with the most recent transcriptions.
    /// Called on app foreground to ensure the cache reflects existing data.
    @MainActor
    static func syncFromDatabase(modelContainer: ModelContainer) {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 10

        guard let transcriptions = try? context.fetch(descriptor) else { return }

        let notes = transcriptions.map { transcription in
            RecentNote(
                id: transcription.id.uuidString,
                text: transcription.enhancedText ?? transcription.text,
                timestamp: transcription.timestamp
            )
        }

        // Write directly to shared UserDefaults
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)?.set(data, forKey: "recentNotesCache")
    }
}
