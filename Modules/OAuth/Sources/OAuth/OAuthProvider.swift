// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Protocol for OAuth provider configurations.
public protocol OAuthProvider: Sendable {
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

    /// Device authorization endpoint (RFC 8628). Non-nil enables device-code
    /// sign-in via ``OAuthManager/startDeviceCodeFlow(provider:)``; providers
    /// that only support the browser redirect flow leave this `nil`.
    var deviceCodeURL: String? { get }

    /// Extra form fields sent with the device-authorization request (e.g. a
    /// client `referrer` tag some issuers expect).
    var deviceAuthExtraParams: [String: String] { get }

    /// Optional post-auth setup (e.g., project discovery). Called after token exchange.
    /// Returns a project ID if applicable.
    func postAuthSetup(accessToken: String) async throws -> String?
}

extension OAuthProvider {
    /// Default: form-urlencoded (standard OAuth2).
    public var tokenRequestUsesJSON: Bool { false }

    /// Default: no client secret (public PKCE client).
    public var clientSecret: String? { nil }

    /// Default: no userinfo endpoint (use JWT claims).
    public var userinfoURL: String? { nil }

    /// Default: browser redirect flow only, no device-code support.
    public var deviceCodeURL: String? { nil }

    /// Default: no extra device-authorization fields.
    public var deviceAuthExtraParams: [String: String] { [:] }

    /// Default: no post-auth setup needed.
    public func postAuthSetup(accessToken: String) async throws -> String? { nil }
}
