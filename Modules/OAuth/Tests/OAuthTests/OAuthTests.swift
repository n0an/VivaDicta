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

        let manager = OAuthManager(keychain: keychain)
        #expect(manager.isSignedIn(provider: provider))

        manager.signOut(provider: provider)

        #expect(!manager.isSignedIn(provider: provider))
        #expect(keychain.deleteCallCount >= 1)
        #expect(keychain.getData(forKey: provider.keychainKey, syncable: false) == nil)
    }

    @Test func isSignedInReturnsFalseWhenKeychainEmpty() {
        let keychain = MockKeychainService()
        let provider = MockOAuthProvider(keychainKey: "test.oauth.credential")
        let manager = OAuthManager(keychain: keychain)

        #expect(!manager.isSignedIn(provider: provider))
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

        let manager = OAuthManager(keychain: keychain)
        #expect(manager.accountEmail(for: provider) == "user@example.com")
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
        let manager = CopilotOAuthManager(keychain: keychain, backgroundTaskService: bgTask)
        #expect(manager.isSignedIn)
        #expect(manager.accountInfo == "octocat")

        manager.signOut()

        #expect(!manager.isSignedIn)
        #expect(keychain.deleteCallCount >= 1)
    }

    @Test func backgroundTaskServiceIsOptional() {
        let keychain = MockKeychainService()
        // Construction succeeds without a background task service.
        let manager = CopilotOAuthManager(keychain: keychain, backgroundTaskService: nil)
        #expect(!manager.isSignedIn)
    }
}

struct MockOAuthProviderTests {

    @Test func postAuthSetupThrowsWhenStubMissing() async {
        // evaluate() records a Swift Testing Issue when the stub is nil -
        // that's the contract that surfaces forgotten stubs in real tests.
        // Acknowledge it via withKnownIssue while still asserting the throw.
        await withKnownIssue {
            let provider = MockOAuthProvider()
            await #expect(throws: StubNotSetError.self) {
                _ = try await provider.postAuthSetup(accessToken: "token")
            }
        }
    }

    @Test func postAuthSetupReturnsStubbedValue() async throws {
        let provider = MockOAuthProvider()
        provider.stubPostAuthSetupResponse = .success("project-id-42")
        let result = try await provider.postAuthSetup(accessToken: "token")
        #expect(result == "project-id-42")
        #expect(provider.postAuthSetupCallCount == 1)
        #expect(provider.capturedAccessToken == "token")
    }

    @Test func postAuthSetupPropagatesStubbedError() async {
        struct Boom: Error {}
        let provider = MockOAuthProvider()
        provider.stubPostAuthSetupResponse = .failure(Boom())
        await #expect(throws: Boom.self) {
            _ = try await provider.postAuthSetup(accessToken: "x")
        }
    }
}

@MainActor
struct MockBackgroundTaskServiceTests {

    @Test func beginReturnsIncrementingIdentifiers() {
        let service = MockBackgroundTaskService()
        let id1 = service.beginBackgroundTask(name: "first", onExpiration: {})
        let id2 = service.beginBackgroundTask(name: "second", onExpiration: {})
        #expect(id1 == 1)
        #expect(id2 == 2)
        #expect(service.beginCallCount == 2)
        #expect(service.capturedNames == ["first", "second"])
    }

    @Test func stubBeginResultOverridesIdentifier() {
        let service = MockBackgroundTaskService()
        service.stubBeginResult = .some(nil)
        let id = service.beginBackgroundTask(name: "name", onExpiration: {})
        #expect(id == nil)
    }

    @Test func endRecordsIdentifier() {
        let service = MockBackgroundTaskService()
        _ = service.beginBackgroundTask(name: "name", onExpiration: {})
        service.endBackgroundTask(1)
        #expect(service.endCallCount == 1)
        #expect(service.endedIdentifiers == [1])
    }
}
