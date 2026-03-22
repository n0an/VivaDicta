//
//  RecentNotesCache.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.22
//

import Foundation

/// A lightweight representation of a transcription for the keyboard extension.
///
/// Stored in shared UserDefaults so the keyboard can display recent notes
/// without needing SwiftData access.
struct RecentNote: Codable, Identifiable {
    let id: String
    let text: String
    let timestamp: Date
}

/// Manages a cache of recent transcriptions in shared UserDefaults
/// for the keyboard extension to read.
enum RecentNotesCache {
    static let key = "recentNotesCache"
    private static let maxNotes = 10

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)
    }

    /// Adds a note to the cache, keeping only the most recent entries.
    /// Called from the main app after saving a transcription.
    static func addNote(id: String, text: String, timestamp: Date) {
        var notes = loadNotes()

        // Remove existing entry with same ID (update case)
        notes.removeAll { $0.id == id }

        // Insert at the beginning (most recent first)
        notes.insert(RecentNote(id: id, text: text, timestamp: timestamp), at: 0)

        // Keep only the most recent
        if notes.count > maxNotes {
            notes = Array(notes.prefix(maxNotes))
        }

        saveNotes(notes)
    }

    /// Loads all cached recent notes.
    static func loadNotes() -> [RecentNote] {
        guard let data = sharedDefaults?.data(forKey: key),
              let notes = try? JSONDecoder().decode([RecentNote].self, from: data) else {
            return []
        }
        return notes
    }

    private static func saveNotes(_ notes: [RecentNote]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        sharedDefaults?.set(data, forKey: key)
    }
}
