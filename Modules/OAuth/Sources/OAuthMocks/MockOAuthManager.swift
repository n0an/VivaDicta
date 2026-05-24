// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import OAuth
import TestUtilities

/// Hand-rolled mock of ``OAuthManager`` for consumer tests. Each test creates
/// its own instance and stubs the per-call responses. Stubs are keyed by the
/// `OAuthProvider`'s `keychainKey` so a single mock can serve different
/// providers in the same test (e.g. Gemini-OAuth + OpenAI-OAuth paths).
///
/// ## Usage
///
/// ```swift
/// let oauth = MockOAuthManager()
/// oauth.signedInProviders.insert(GeminiOAuthProvider().keychainKey)
/// oauth.stubValidAccessTokenResponse = .success(
///     (token: "test-token", accountId: "acc-1", projectId: "proj-1")
/// )
/// let sut = AIService(..., oauthManager: oauth)
/// _ = try await sut.enhance(...)
/// #expect(oauth.validAccessTokenCallCount == 1)
/// ```
@MainActor
public final class MockOAuthManager: OAuthManager {
    public init() {}

    // MARK: isSignedIn / accountEmail

    /// Set of `provider.keychainKey` values considered signed-in. Falls back
    /// to `false` for keys not in the set.
    public var signedInProviders: Set<String> = []

    /// Per-provider account email lookup (keyed by `provider.keychainKey`).
    public var accountEmails: [String: String] = [:]

    // MARK: signIn

    public var stubSignInResponse: Result<OAuthCredential, Error>?
    public var didSignIn: (() -> Void)?
    public private(set) var signInCallCount = 0
    public private(set) var capturedSignInProviderKey: String?

    // MARK: signOut

    public var didSignOut: (() -> Void)?
    public private(set) var signOutCallCount = 0
    public private(set) var capturedSignOutProviderKey: String?

    // MARK: validAccessToken

    public var stubValidAccessTokenResponse: Result<(token: String, accountId: String?, projectId: String?), Error>?
    public var didFetchValidAccessToken: (() -> Void)?
    public private(set) var validAccessTokenCallCount = 0
    public private(set) var capturedValidAccessTokenProviderKey: String?

    // MARK: - OAuthManager conformance

    public func isSignedIn(provider: some OAuthProvider) -> Bool {
        signedInProviders.contains(provider.keychainKey)
    }

    public func accountEmail(for provider: some OAuthProvider) -> String? {
        accountEmails[provider.keychainKey]
    }

    public func signIn(provider: some OAuthProvider) async throws -> OAuthCredential {
        defer { didSignIn?() }
        signInCallCount += 1
        capturedSignInProviderKey = provider.keychainKey
        return try stubSignInResponse.evaluate()
    }

    public func signOut(provider: some OAuthProvider) {
        defer { didSignOut?() }
        signOutCallCount += 1
        capturedSignOutProviderKey = provider.keychainKey
        signedInProviders.remove(provider.keychainKey)
    }

    public func validAccessToken(for provider: some OAuthProvider) async throws -> (token: String, accountId: String?, projectId: String?) {
        defer { didFetchValidAccessToken?() }
        validAccessTokenCallCount += 1
        capturedValidAccessTokenProviderKey = provider.keychainKey
        return try stubValidAccessTokenResponse.evaluate()
    }
}
