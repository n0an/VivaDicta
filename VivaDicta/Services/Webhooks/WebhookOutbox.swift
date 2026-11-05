//
//  WebhookOutbox.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation

/// One pending delivery of one transcription to one webhook.
nonisolated struct WebhookOutboxItem: Codable, Identifiable, Equatable, Sendable {
    /// Outbox item ID. Also the upload task's `taskDescription`.
    let id: UUID
    let webhookID: UUID
    /// Sent as the payload `id` and the `Idempotency-Key` header.
    let transcriptionID: UUID
    let createdAt: Date
    /// Attempts started so far.
    var attempts: Int
    /// When the next attempt may start.
    var nextAttemptAt: Date
    /// An upload task exists for the current attempt.
    var isInFlight: Bool
    var lastError: String?
}

/// File-backed persistence for the outbox: an index file plus one JSON body
/// file per item. Bodies are files so background `URLSession` upload tasks can
/// stream them (an hour-long meeting is 40-100 KB of text, never truncated).
nonisolated struct WebhookOutboxStorage: Sendable {
    let directory: URL

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Webhooks", directoryHint: .isDirectory)
    }

    init(directory: URL = WebhookOutboxStorage.defaultDirectory) {
        self.directory = directory
    }

    private var indexURL: URL { directory.appending(path: "outbox.json", directoryHint: .notDirectory) }
    private var bodiesDirectory: URL { directory.appending(path: "bodies", directoryHint: .isDirectory) }

    func bodyURL(for itemID: UUID) -> URL {
        bodiesDirectory.appending(path: "\(itemID.uuidString).json", directoryHint: .notDirectory)
    }

    func loadItems() -> [WebhookOutboxItem] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([WebhookOutboxItem].self, from: data)) ?? []
    }

    func saveItems(_ items: [WebhookOutboxItem]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: indexURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func writeBody(_ body: Data, for itemID: UUID) throws {
        try FileManager.default.createDirectory(at: bodiesDirectory, withIntermediateDirectories: true)
        try body.write(to: bodyURL(for: itemID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func removeBody(for itemID: UUID) {
        try? FileManager.default.removeItem(at: bodyURL(for: itemID))
    }

    func bodyExists(for itemID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: bodyURL(for: itemID).path(percentEncoded: false))
    }
}
