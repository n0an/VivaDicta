//
//  WebhookStore.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import Observation
import AppGroup
import Keychain
import os

/// Owns the webhook definitions, their bearer tokens and the last delivery
/// result per webhook.
///
/// Definitions and statuses live in app-private UserDefaults: modes (which
/// reference webhooks by ID) are device-local too, and the extensions never
/// send. Tokens live in the Keychain as device-only items, never in
/// UserDefaults, logs or analytics.
@MainActor
@Observable
final class WebhookStore {
    static let shared = WebhookStore()

    /// How a save treats the bearer token.
    enum TokenChange: Equatable {
        case keep
        case set(String)
        case remove
    }

    enum StoreError: LocalizedError {
        case keychainWriteFailed

        var errorDescription: String? {
            switch self {
            case .keychainWriteFailed: "Could not save the token to the Keychain."
            }
        }
    }

    private(set) var webhooks: [WebhookDefinition] = []
    private(set) var statuses: [UUID: WebhookDeliveryStatus] = [:]

    /// Called after a webhook is deleted, so modes and the outbox can drop it.
    @ObservationIgnored var onWebhookDeleted: ((UUID) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: any KeychainService
    @ObservationIgnored private let logger = Logger(category: .webhooks)

    init(defaults: UserDefaults = UserDefaultsStorage.appPrivate,
         keychain: any KeychainService = DefaultKeychainService()) {
        self.defaults = defaults
        self.keychain = keychain
        load()
    }

    var enabledWebhooks: [WebhookDefinition] {
        webhooks.filter(\.isEnabled)
    }

    func webhook(id: UUID) -> WebhookDefinition? {
        webhooks.first { $0.id == id }
    }

    /// Inserts or updates a webhook and applies the token change.
    func save(_ webhook: WebhookDefinition, token change: TokenChange) throws {
        var webhook = webhook
        switch change {
        case .keep:
            webhook.hasBearerToken = self.webhook(id: webhook.id)?.hasBearerToken ?? false
        case .set(let token):
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                keychain.delete(forKey: Self.tokenKey(for: webhook.id), syncable: false)
                webhook.hasBearerToken = false
            } else {
                guard keychain.save(trimmed, forKey: Self.tokenKey(for: webhook.id), syncable: false) else {
                    throw StoreError.keychainWriteFailed
                }
                webhook.hasBearerToken = true
            }
        case .remove:
            keychain.delete(forKey: Self.tokenKey(for: webhook.id), syncable: false)
            webhook.hasBearerToken = false
        }

        if let index = webhooks.firstIndex(where: { $0.id == webhook.id }) {
            webhooks[index] = webhook
        } else {
            webhooks.append(webhook)
        }
        persistWebhooks()
        logger.logInfo("🪝 Saved webhook '\(webhook.displayName)' (enabled: \(webhook.isEnabled), token: \(webhook.hasBearerToken))")
    }

    func delete(id: UUID) {
        guard let index = webhooks.firstIndex(where: { $0.id == id }) else { return }
        let removed = webhooks.remove(at: index)
        keychain.delete(forKey: Self.tokenKey(for: id), syncable: false)
        statuses[id] = nil
        persistWebhooks()
        persistStatuses()
        logger.logInfo("🪝 Deleted webhook '\(removed.displayName)'")
        onWebhookDeleted?(id)
    }

    /// The bearer token, or `nil` when none is set or the Keychain is unavailable (device locked).
    func token(for webhookID: UUID) -> String? {
        keychain.getString(forKey: Self.tokenKey(for: webhookID), syncable: false)
    }

    func recordStatus(_ status: WebhookDeliveryStatus, for webhookID: UUID) {
        guard webhook(id: webhookID) != nil else { return }
        statuses[webhookID] = status
        persistStatuses()
    }

    static func tokenKey(for webhookID: UUID) -> String {
        "webhook.bearerToken.\(webhookID.uuidString)"
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: UserDefaultsStorage.Keys.webhookDefinitions) {
            do {
                webhooks = try JSONDecoder().decode([WebhookDefinition].self, from: data)
            } catch {
                logger.logError("🪝 Failed to decode webhooks: \(error.localizedDescription)")
            }
        }
        if let data = defaults.data(forKey: UserDefaultsStorage.Keys.webhookDeliveryStatuses),
           let decoded = try? JSONDecoder().decode([String: WebhookDeliveryStatus].self, from: data) {
            statuses = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                UUID(uuidString: key).map { ($0, value) }
            })
        }
    }

    private func persistWebhooks() {
        guard let data = try? JSONEncoder().encode(webhooks) else {
            logger.logError("🪝 Failed to encode webhooks")
            return
        }
        defaults.set(data, forKey: UserDefaultsStorage.Keys.webhookDefinitions)
    }

    private func persistStatuses() {
        let keyed = Dictionary(uniqueKeysWithValues: statuses.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(keyed) else { return }
        defaults.set(data, forKey: UserDefaultsStorage.Keys.webhookDeliveryStatuses)
    }
}
