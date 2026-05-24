// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// OAuth manager seam used by consumers (AIService, etc.). The production
/// conformance is ``DefaultOAuthManager``; tests inject `MockOAuthManager`
/// from `OAuthMocks` to fake the OAuth lifecycle without running real PKCE
/// flows or hitting the keychain.
///
/// `@MainActor`-isolated because credential storage and any platform
/// authentication UI invocation must happen on the main thread.
@MainActor
public protocol OAuthManager {
    /// Whether the user is signed in for a given provider.
    func isSignedIn(provider: some OAuthProvider) -> Bool

    /// Returns the account email for a given provider, if signed in.
    func accountEmail(for provider: some OAuthProvider) -> String?

    /// Triggers the platform-appropriate PKCE sign-in flow and stores the
    /// resulting credential.
    func signIn(provider: some OAuthProvider) async throws -> OAuthCredential

    /// Signs out by removing the stored credential.
    func signOut(provider: some OAuthProvider)

    /// Returns a valid access token, refreshing if needed.
    func validAccessToken(for provider: some OAuthProvider) async throws -> (token: String, accountId: String?, projectId: String?)
}
