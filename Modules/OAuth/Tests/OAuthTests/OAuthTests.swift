// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
import Foundation
@testable import OAuth
import OAuthMocks
import KeychainMocks
import TestUtilities

@MainActor
struct OAuthManagerTests {

    @Test func signOutDeletesCredentialFromKeychain() throws {
        let keychain = MockKeychainService()
        let provider = MockOAuthProvider(keychainKey: "test.oauth.credential")
        let credential = OAuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            accountId: "acct-1",
            accountEmail: "user@example.com",
            projectId: nil
        )
        let encoded = try JSONEncoder().encode(credential)
        keychain.save(data: encoded, forKey: provider.keychainKey, syncable: false)

        let sut = DefaultOAuthManager(keychain: keychain)
        #expect(sut.isSignedIn(provider: provider))

        sut.signOut(provider: provider)

        #expect(!sut.isSignedIn(provider: provider))
        #expect(keychain.deleteCallCount >= 1)
        #expect(keychain.getData(forKey: provider.keychainKey, syncable: false) == nil)
    }

    @Test func isSignedInReturnsFalseWhenKeychainEmpty() {
        let keychain = MockKeychainService()
        let provider = MockOAuthProvider(keychainKey: "test.oauth.credential")
        let sut = DefaultOAuthManager(keychain: keychain)

        #expect(!sut.isSignedIn(provider: provider))
    }

    @Test func accountEmailReturnsStoredEmail() throws {
        let keychain = MockKeychainService()
        let provider = MockOAuthProvider(keychainKey: "test.oauth.credential")
        let credential = OAuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            accountId: "acct-1",
            accountEmail: "user@example.com",
            projectId: nil
        )
        let encoded = try JSONEncoder().encode(credential)
        keychain.save(data: encoded, forKey: provider.keychainKey, syncable: false)

        let sut = DefaultOAuthManager(keychain: keychain)
        #expect(sut.accountEmail(for: provider) == "user@example.com")
    }
}

@MainActor
struct CopilotOAuthManagerTests {

    @Test func signOutDeletesCredential() throws {
        let keychain = MockKeychainService()
        let credential = CopilotCredential(
            githubAccessToken: "gh-token",
            copilotToken: "cp-token",
            copilotTokenExpiresAt: Date().addingTimeInterval(1800),
            githubUsername: "octocat"
        )
        let encoded = try JSONEncoder().encode(credential)
        keychain.save(data: encoded, forKey: "copilotOAuthCredential", syncable: false)

        let bgTask = MockBackgroundTaskService()
        let sut = DefaultCopilotOAuthManager(keychain: keychain, backgroundTaskService: bgTask)
        #expect(sut.isSignedIn)
        #expect(sut.accountInfo == "octocat")

        sut.signOut()

        #expect(!sut.isSignedIn)
        #expect(keychain.deleteCallCount >= 1)
    }

    @Test func backgroundTaskServiceIsOptional() {
        let keychain = MockKeychainService()
        // Construction succeeds without a background task sut.
        let sut = DefaultCopilotOAuthManager(keychain: keychain, backgroundTaskService: nil)
        #expect(!sut.isSignedIn)
    }
}

struct MockOAuthProviderTests {

    @Test func postAuthSetupThrowsWhenStubMissing() async {
        // evaluate() records a Swift Testing Issue when the stub is nil -
        // that's the contract that surfaces forgotten stubs in real tests.
        // Acknowledge it via withKnownIssue while still asserting the throw.
        await withKnownIssue {
            let sut = MockOAuthProvider()
            await #expect(throws: StubNotSetError.self) {
                _ = try await sut.postAuthSetup(accessToken: "token")
            }
        }
    }

    @Test func postAuthSetupReturnsStubbedValue() async throws {
        let sut = MockOAuthProvider()
        sut.stubPostAuthSetupResponse = .success("project-id-42")
        let result = try await sut.postAuthSetup(accessToken: "token")
        #expect(result == "project-id-42")
        #expect(sut.postAuthSetupCallCount == 1)
        #expect(sut.capturedAccessToken == "token")
    }

    @Test func postAuthSetupPropagatesStubbedError() async {
        struct Boom: Error {}
        let sut = MockOAuthProvider()
        sut.stubPostAuthSetupResponse = .failure(Boom())
        await #expect(throws: Boom.self) {
            _ = try await sut.postAuthSetup(accessToken: "x")
        }
    }
}

@MainActor
struct MockBackgroundTaskServiceTests {

    @Test func beginReturnsIncrementingIdentifiers() {
        let sut = MockBackgroundTaskService()
        let id1 = sut.beginBackgroundTask(name: "first", onExpiration: {})
        let id2 = sut.beginBackgroundTask(name: "second", onExpiration: {})
        #expect(id1 == 1)
        #expect(id2 == 2)
        #expect(sut.beginCallCount == 2)
        #expect(sut.capturedNames == ["first", "second"])
    }

    @Test func stubBeginResultOverridesIdentifier() {
        let sut = MockBackgroundTaskService()
        sut.stubBeginResult = .some(nil)
        let id = sut.beginBackgroundTask(name: "name", onExpiration: {})
        #expect(id == nil)
    }

    @Test func endRecordsIdentifier() {
        let sut = MockBackgroundTaskService()
        _ = sut.beginBackgroundTask(name: "name", onExpiration: {})
        sut.endBackgroundTask(1)
        #expect(sut.endCallCount == 1)
        #expect(sut.endedIdentifiers == [1])
    }
}
