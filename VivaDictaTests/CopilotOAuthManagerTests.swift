//
//  CopilotOAuthManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing
import KeychainMocks
@testable import VivaDicta

/// Sut + mock pattern: sut is the real `CopilotOAuthManager`,
/// `MockKeychainService` is the injected dependency. Methods that drive
/// the GitHub device-code flow or live token exchange aren't covered.
@MainActor
struct CopilotOAuthManagerTests {

    /// Mirrors the private `keychainKey` constant in CopilotOAuthManager.
    /// Kept in sync manually; if the production constant changes these
    /// tests will fail loudly which is the desired signal.
    private static let copilotKeychainKey = "copilotOAuthCredential"

    let mockKeychain: MockKeychainService
    let sut: CopilotOAuthManager

    init() {
        let mock = MockKeychainService()
        self.mockKeychain = mock
        self.sut = CopilotOAuthManager(keychain: mock)
    }

    @Test func isSignedInFalseWhenKeychainEmpty() {
        #expect(!sut.isSignedIn)
    }

    @Test func isSignedInTrueWhenKeychainHasCredential() throws {
        let credential = CopilotCredential(
            githubAccessToken: "gh-token",
            copilotToken: "copilot-token",
            copilotTokenExpiresAt: Date().addingTimeInterval(3600),
            githubUsername: "octocat"
        )
        let data = try JSONEncoder().encode(credential)
        mockKeychain.save(data: data, forKey: Self.copilotKeychainKey, syncable: false)

        #expect(sut.isSignedIn)
    }

    @Test func accountInfoReturnsGithubUsername() throws {
        let credential = CopilotCredential(
            githubAccessToken: "gh-token",
            copilotToken: "copilot-token",
            copilotTokenExpiresAt: Date().addingTimeInterval(3600),
            githubUsername: "octocat"
        )
        let data = try JSONEncoder().encode(credential)
        mockKeychain.save(data: data, forKey: Self.copilotKeychainKey, syncable: false)

        #expect(sut.accountInfo == "octocat")
    }

    @Test func signOutRemovesCredentialFromKeychain() throws {
        let credential = CopilotCredential(
            githubAccessToken: "gh-token",
            copilotToken: "copilot-token",
            copilotTokenExpiresAt: Date().addingTimeInterval(3600),
            githubUsername: "octocat"
        )
        let data = try JSONEncoder().encode(credential)
        mockKeychain.save(data: data, forKey: Self.copilotKeychainKey, syncable: false)
        #expect(sut.isSignedIn)

        sut.signOut()

        #expect(mockKeychain.getData(forKey: Self.copilotKeychainKey, syncable: false) == nil,
                "After signOut the Copilot keychain entry must be cleared")
    }
}
