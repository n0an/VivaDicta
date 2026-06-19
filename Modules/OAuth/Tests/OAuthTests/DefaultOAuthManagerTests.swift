// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
import Foundation
@testable import OAuth
import OAuthMocks
import KeychainMocks
import NetworkingMocks
import TestUtilities

/// Exercises the constructor-injected seams of `DefaultOAuthManager` - the
/// keychain credential store and the network-backed token-refresh path.
///
/// `signIn(provider:)` is intentionally NOT covered: it launches a real
/// `ASWebAuthenticationSession` browser auth flow, which cannot run under a
/// unit test.
@MainActor
struct DefaultOAuthManagerTests {

    private let keychain: MockKeychainService
    private let network: MockNetworkService
    private let provider: MockOAuthProvider
    private let sut: DefaultOAuthManager

    init() {
        self.keychain = MockKeychainService()
        self.network = MockNetworkService()
        self.provider = MockOAuthProvider(keychainKey: "test.oauth.credential")
        self.sut = DefaultOAuthManager(keychain: keychain, networkService: network)
        // The refresh path calls `provider.postAuthSetup` (via `try?`); stub it
        // benignly so its unset-stub guard does not record a spurious issue.
        self.provider.stubPostAuthSetupResponse = .success(nil)
    }

    // MARK: - isSignedIn

    @Test func isSignedInReturnsFalseWhenKeychainEmpty() {
        #expect(sut.isSignedIn(provider: provider) == false)
    }

    @Test func isSignedInReturnsTrueWhenCredentialStored() throws {
        try seedCredential(makeCredential())

        #expect(sut.isSignedIn(provider: provider))
    }

    // MARK: - accountEmail

    @Test func accountEmailReturnsNilWhenKeychainEmpty() {
        #expect(sut.accountEmail(for: provider) == nil)
    }

    @Test func accountEmailReturnsStoredEmail() throws {
        try seedCredential(makeCredential(accountEmail: "user@example.com"))

        #expect(sut.accountEmail(for: provider) == "user@example.com")
    }

    // MARK: - Credential persistence round-trip

    @Test func storedCredentialIsReadBackByIsSignedInAndAccountEmail() throws {
        try seedCredential(makeCredential(accountEmail: "round@trip.com"))

        #expect(sut.isSignedIn(provider: provider))
        #expect(sut.accountEmail(for: provider) == "round@trip.com")
    }

    // MARK: - signOut

    @Test func signOutRemovesCredentialAndCallsKeychainDelete() throws {
        try seedCredential(makeCredential())
        #expect(sut.isSignedIn(provider: provider))

        sut.signOut(provider: provider)

        #expect(sut.isSignedIn(provider: provider) == false)
        #expect(keychain.deleteCallCount >= 1)
        #expect(keychain.getData(forKey: provider.keychainKey, syncable: false) == nil)
    }

    // MARK: - validAccessToken

    @Test func validAccessTokenReturnsStoredTokenWhenStillValid() async throws {
        try seedCredential(
            makeCredential(
                accessToken: "valid-token",
                expiresAt: Date().addingTimeInterval(3600),
                accountId: "acct-77"
            )
        )

        let result = try await sut.validAccessToken(for: provider)

        #expect(result.token == "valid-token")
        #expect(result.accountId == "acct-77")
        // A still-valid token must not trigger a refresh network call.
        #expect(network.sendCallCount == 0)
    }

    @Test func validAccessTokenRefreshesExpiredCredentialViaNetwork() async throws {
        // Seed an expired credential. It keeps a non-empty refresh token so
        // `loadCredential` does not discard it as unrefreshable.
        try seedCredential(
            makeCredential(
                accessToken: "stale-token",
                refreshToken: "refresh-token",
                expiresAt: Date().addingTimeInterval(-60)
            )
        )

        // `tokenRequest` decodes access_token / refresh_token / expires_in
        // from the JSON body via JSONSerialization.
        let body = Data(
            #"{"access_token":"fresh-token","refresh_token":"new-refresh","expires_in":3600}"#.utf8
        )
        network.stubSendResponse = .success((body, makeHTTPResponse(200)))

        let result = try await sut.validAccessToken(for: provider)

        #expect(result.token == "fresh-token")
        #expect(network.sendCallCount == 1)
    }

    @Test func validAccessTokenPersistsRefreshedCredential() async throws {
        try seedCredential(
            makeCredential(
                accessToken: "stale-token",
                refreshToken: "refresh-token",
                expiresAt: Date().addingTimeInterval(-60)
            )
        )

        let body = Data(
            #"{"access_token":"fresh-token","refresh_token":"new-refresh","expires_in":3600}"#.utf8
        )
        network.stubSendResponse = .success((body, makeHTTPResponse(200)))

        _ = try await sut.validAccessToken(for: provider)

        // The refreshed credential is written back to the keychain and decodes
        // to the new access token.
        let persisted = try #require(keychain.getData(forKey: provider.keychainKey, syncable: false))
        let decoded = try JSONDecoder().decode(OAuthCredential.self, from: persisted)
        #expect(decoded.accessToken == "fresh-token")
    }

    @Test func validAccessTokenThrowsWhenNoCredential() async {
        await #expect(throws: OAuthError.self) {
            _ = try await sut.validAccessToken(for: provider)
        }
    }

    // MARK: - Helpers

    private func makeCredential(
        accessToken: String = "access",
        refreshToken: String = "refresh",
        expiresAt: Date = Date().addingTimeInterval(3600),
        accountId: String? = "acct-1",
        accountEmail: String? = "user@example.com",
        projectId: String? = nil
    ) -> OAuthCredential {
        OAuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            accountId: accountId,
            accountEmail: accountEmail,
            projectId: projectId
        )
    }

    /// Encodes the credential the same way `DefaultOAuthManager.saveCredential`
    /// does (JSONEncoder under `provider.keychainKey`) so `loadCredential` reads
    /// it back.
    private func seedCredential(_ credential: OAuthCredential) throws {
        let encoded = try JSONEncoder().encode(credential)
        keychain.save(data: encoded, forKey: provider.keychainKey, syncable: false)
    }

    private func makeHTTPResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/token")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
