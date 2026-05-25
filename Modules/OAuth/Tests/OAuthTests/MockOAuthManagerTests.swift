// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import OAuth
import OAuthMocks
import Testing
import TestUtilities

/// Locks in the lifecycle parity between `MockOAuthManager` /
/// `MockCopilotOAuthManager` and their `Default<Name>` production
/// counterparts: successful sign-in / token-poll updates signed-in state;
/// sign-out clears it. Regression catch for the divergence both PR #281
/// reviewers flagged.
@MainActor
@Suite("Mock OAuth manager lifecycle parity")
struct MockOAuthManagerLifecycleTests {

    @Test func successfulSignInMarksProviderSignedIn() async throws {
        let sut = MockOAuthManager()
        let provider = MockOAuthProvider(keychainKey: "test-provider")
        let credential = OAuthCredential(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            accountId: "id-1",
            accountEmail: "a@example.com",
            projectId: nil
        )
        sut.stubSignInResponse = .success(credential)

        _ = try await sut.signIn(provider: provider)

        #expect(sut.isSignedIn(provider: provider))
        #expect(sut.accountEmail(for: provider) == "a@example.com")
    }

    @Test func signOutClearsSignedInStateAndEmail() async throws {
        let sut = MockOAuthManager()
        let provider = MockOAuthProvider(keychainKey: "test-provider")
        sut.signedInProviders.insert(provider.keychainKey)
        sut.accountEmails[provider.keychainKey] = "a@example.com"

        sut.signOut(provider: provider)

        #expect(sut.isSignedIn(provider: provider) == false)
        #expect(sut.accountEmail(for: provider) == nil)
    }

    @Test func copilotPollForTokenFlipsSignedInAndAccountInfo() async throws {
        let sut = MockCopilotOAuthManager()
        let credential = CopilotCredential(
            githubAccessToken: "gh-token",
            copilotToken: "copilot-token",
            copilotTokenExpiresAt: Date().addingTimeInterval(3600),
            githubUsername: "octocat"
        )
        sut.stubPollForTokenResponse = .success(credential)

        _ = try await sut.pollForToken(deviceCode: "dc", interval: 5, expiresIn: 900)

        #expect(sut.isSignedIn)
        #expect(sut.accountInfo == "octocat")
    }

    @Test func copilotSignOutClearsAccountInfo() async throws {
        let sut = MockCopilotOAuthManager()
        sut.isSignedIn = true
        sut.accountInfo = "octocat"

        sut.signOut()

        #expect(sut.isSignedIn == false)
        #expect(sut.accountInfo == nil)
    }
}
