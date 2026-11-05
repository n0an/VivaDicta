//
//  WebhookDefinition.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation

/// A user-configured webhook that receives finished transcriptions as JSON.
///
/// Stored in app-private UserDefaults by ``WebhookStore``. The optional bearer
/// token is never part of this value: it lives in the Keychain, and
/// ``hasBearerToken`` only records that one was saved, so a send attempted
/// while the Keychain is locked waits instead of going out unauthenticated.
nonisolated struct WebhookDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var url: URL
    var isEnabled: Bool
    var hasBearerToken: Bool

    init(id: UUID = UUID(), name: String, url: URL, isEnabled: Bool = true, hasBearerToken: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.hasBearerToken = hasBearerToken
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        hasBearerToken = try container.decodeIfPresent(Bool.self, forKey: .hasBearerToken) ?? false
    }

    /// Name shown in lists and menus, falling back to the host when the user left it empty.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return url.host() ?? "Webhook"
    }
}

/// Why a webhook URL was rejected.
nonisolated enum WebhookURLValidationError: Error, Equatable, Sendable {
    case empty
    case malformed
    case notHTTPS

    var message: String {
        switch self {
        case .empty: "Enter the webhook URL."
        case .malformed: "This is not a valid URL."
        case .notHTTPS: "The URL must start with https://."
        }
    }
}

/// Validates user-entered webhook URLs. Only `https` is accepted: the payload
/// carries the full transcript and possibly a bearer token.
nonisolated enum WebhookURLValidator {
    static func validate(_ input: String) -> Result<URL, WebhookURLValidationError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            return .failure(.malformed)
        }
        guard scheme == "https" else { return .failure(.notHTTPS) }
        guard let host = components.host, !host.isEmpty, !host.contains(" "),
              let url = components.url else {
            return .failure(.malformed)
        }
        return .success(url)
    }
}

/// The last delivery result for one webhook, shown in Settings → Integrations.
nonisolated struct WebhookDeliveryStatus: Codable, Hashable, Sendable {
    enum Outcome: String, Codable, Sendable {
        case delivered
        /// The last attempt failed with a retryable error; another one is scheduled.
        case retrying
        /// Delivery stopped for good (non-retryable response or too old).
        case failed
    }

    var outcome: Outcome
    var date: Date
    var statusCode: Int?
    var message: String?
}
