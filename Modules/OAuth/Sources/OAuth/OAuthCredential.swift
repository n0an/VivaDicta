// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// OAuth credential with access/refresh tokens and account info.
public struct OAuthCredential: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let accountId: String?
    public let accountEmail: String?
    /// Provider-specific project ID (e.g., Google Cloud project for Gemini).
    public let projectId: String?

    public init(accessToken: String, refreshToken: String, expiresAt: Date, accountId: String?, accountEmail: String?, projectId: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.accountId = accountId
        self.accountEmail = accountEmail
        self.projectId = projectId
    }

    /// Whether the token will expire within the next 5 minutes.
    public var isExpiringSoon: Bool {
        Date().addingTimeInterval(300) >= expiresAt
    }

    public var isExpired: Bool {
        Date() >= expiresAt
    }
}
