//
//  BackgroundTaskQueue.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.04
//

import Foundation

/// A work item representing audio that needs background transcription processing.
nonisolated struct BackgroundWorkItem: Codable, Sendable {
    let id: UUID
    let audioFileURL: URL
    let sourceTag: String
    let modeId: String?
    let recordingTimestamp: Date
    let createdAt: Date
    var retryCount: Int

    init(audioFileURL: URL, sourceTag: String, modeId: String?, recordingTimestamp: Date = Date()) {
        self.id = UUID()
        self.audioFileURL = audioFileURL
        self.sourceTag = sourceTag
        self.modeId = modeId
        self.recordingTimestamp = recordingTimestamp
        self.createdAt = Date()
        self.retryCount = 0
    }
}

/// Persistent queue for background transcription work items.
///
/// Stores items in UserDefaults so they survive app termination.
/// Thread-safe: all persistence goes through UserDefaults which is thread-safe.
/// This allows expiration handlers (called on arbitrary threads) to enqueue
/// items synchronously without a MainActor hop.
nonisolated final class BackgroundTaskQueue {
    private static let storageKey = "BackgroundTaskQueue.items"
    private static let maxRetryCount = 3
    private static let maxAgeInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private let defaults: UserDefaults

    var isEmpty: Bool { loadItems().isEmpty }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func enqueue(_ item: BackgroundWorkItem) {
        var items = loadItems()
        items.append(item)
        saveItems(items)
    }

    /// Returns all pending items after pruning aged-out and over-retried entries.
    func allPending() -> [BackgroundWorkItem] {
        var items = loadItems()
        let countBefore = items.count
        items.removeAll { item in
            item.retryCount >= Self.maxRetryCount ||
            Date().timeIntervalSince(item.createdAt) > Self.maxAgeInterval
        }
        if items.count != countBefore {
            saveItems(items)
        }
        return items
    }

    func markFailed(id: UUID) {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].retryCount += 1
            if items[index].retryCount >= Self.maxRetryCount {
                items.remove(at: index)
            }
        }
        saveItems(items)
    }

    func remove(id: UUID) {
        var items = loadItems()
        items.removeAll { $0.id == id }
        saveItems(items)
    }

    /// Removes all items matching the given audio filename.
    func removeByFileName(_ fileName: String) {
        var items = loadItems()
        items.removeAll { $0.audioFileURL.lastPathComponent == fileName }
        saveItems(items)
    }

    /// Checks if a file URL is already in the queue.
    func contains(audioFileURL: URL) -> Bool {
        loadItems().contains { $0.audioFileURL == audioFileURL }
    }

    /// Returns all queued audio filenames (for orphan recovery exclusion).
    func queuedFileNames() -> Set<String> {
        Set(loadItems().map { $0.audioFileURL.lastPathComponent })
    }

    // MARK: - Persistence

    private func loadItems() -> [BackgroundWorkItem] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        return (try? JSONDecoder().decode([BackgroundWorkItem].self, from: data)) ?? []
    }

    private func saveItems(_ items: [BackgroundWorkItem]) {
        let data = try? JSONEncoder().encode(items)
        defaults.set(data, forKey: Self.storageKey)
    }
}
