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
    /// Which text the payload carries.
    var textContent: WebhookTextContent

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        isEnabled: Bool = true,
        hasBearerToken: Bool = false,
        textContent: WebhookTextContent = .default
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.hasBearerToken = hasBearerToken
        self.textContent = textContent
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        hasBearerToken = try container.decodeIfPresent(Bool.self, forKey: .hasBearerToken) ?? false
        // Webhooks saved before this option existed, and values from a newer
        // version this one does not know, fall back to today's behavior.
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
            .flatMap(WebhookTextContent.init(rawValue:)) ?? .default
    }

    /// Name shown in lists and menus, falling back to the host when the user left it empty.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return url.host() ?? "Webhook"
    }
}

/// Which text a webhook receives. The raw value is also the payload's
/// `textContent` field, so receivers know what `text` holds.
nonisolated enum WebhookTextContent: String, Codable, CaseIterable, Identifiable, Sendable {
    /// `text` is the original transcript. No `rawText`, no `aiModel`.
    case original
    /// `text` is the last AI-processed text (the transcript when no processing ran). No `rawText`.
    case processed
    /// `text` is the last AI-processed text, `rawText` the original transcript when it differs.
    case both

    static let `default`: WebhookTextContent = .both

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .original: "Original Only"
        case .processed: "Last Processed Only"
        case .both: "Both"
        }
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
