// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// OAuth credential with access/refresh tokens and account info.
struct OAuthCredential: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let accountId: String?
    let accountEmail: String?
    /// Provider-specific project ID (e.g., Google Cloud project for Gemini).
    let projectId: String?

    init(accessToken: String, refreshToken: String, expiresAt: Date, accountId: String?, accountEmail: String?, projectId: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.accountId = accountId
        self.accountEmail = accountEmail
        self.projectId = projectId
    }

    /// Whether the token will expire within the next 5 minutes.
    var isExpiringSoon: Bool {
        Date().addingTimeInterval(300) >= expiresAt
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }
}
