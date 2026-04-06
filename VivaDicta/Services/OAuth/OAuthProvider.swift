// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Protocol for OAuth provider configurations.
protocol OAuthProvider: Sendable {
    /// Human-readable provider name (e.g., "OpenAI").
    var providerName: String { get }

    /// OAuth client ID.
    var clientId: String { get }

    /// Authorization endpoint URL.
    var authorizeURL: String { get }

    /// Token exchange/refresh endpoint URL.
    var tokenURL: String { get }

    /// Redirect URI for the OAuth callback.
    var redirectURI: String { get }

    /// OAuth scopes (space-separated).
    var scopes: String { get }

    /// Additional query parameters for the authorization request.
    var extraAuthParams: [String: String] { get }

    /// Keychain key used to store the credential.
    var keychainKey: String { get }

    /// Whether the token endpoint expects JSON (`true`) or form-urlencoded (`false`).
    var tokenRequestUsesJSON: Bool { get }

    /// OAuth client secret (required by some providers like Google, optional for public clients).
    var clientSecret: String? { get }

    /// Extract account info (id, email) from the JWT access token claims.
    func extractAccountInfo(from claims: [String: Any]) -> (id: String?, email: String?)

    /// Optional userinfo endpoint for providers whose access tokens aren't JWTs (e.g. Google).
    var userinfoURL: String? { get }

    /// Optional post-auth setup (e.g., project discovery). Called after token exchange.
    /// Returns a project ID if applicable.
    func postAuthSetup(accessToken: String) async throws -> String?
}

extension OAuthProvider {
    /// Default: form-urlencoded (standard OAuth2).
    var tokenRequestUsesJSON: Bool { false }

    /// Default: no client secret (public PKCE client).
    var clientSecret: String? { nil }

    /// Default: no userinfo endpoint (use JWT claims).
    var userinfoURL: String? { nil }

    /// Default: no post-auth setup needed.
    func postAuthSetup(accessToken: String) async throws -> String? { nil }
}
