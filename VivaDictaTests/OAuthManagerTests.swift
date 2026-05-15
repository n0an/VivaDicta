//
//  OAuthManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing
import KeychainMocks
@testable import VivaDicta

/// Sut + mock pattern: sut is the real `OAuthManager`, `MockKeychainService`
/// is the injected dependency. Only the keychain-touching paths are tested
/// here; methods that drive `ASWebAuthenticationSession` or perform live
/// token exchange aren't covered.
@MainActor
struct OAuthManagerTests {

    let mockKeychain: MockKeychainService
    let sut: OAuthManager
    let provider = OpenAIOAuthProvider()

    init() {
        let mock = MockKeychainService()
        self.mockKeychain = mock
        self.sut = OAuthManager(keychain: mock)
    }

    @Test func isSignedInFalseWhenKeychainEmpty() {
        #expect(!sut.isSignedIn(provider: provider))
    }

    @Test func isSignedInTrueWhenKeychainHasValidCredential() throws {
        let credential = OAuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            accountId: "id-123",
            accountEmail: "user@example.com"
        )
        let data = try JSONEncoder().encode(credential)
        mockKeychain.save(data: data, forKey: provider.keychainKey, syncable: false)

        #expect(sut.isSignedIn(provider: provider))
    }

    @Test func accountEmailReturnsCredentialEmail() throws {
        let credential = OAuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            accountId: "id-123",
            accountEmail: "user@example.com"
        )
        let data = try JSONEncoder().encode(credential)
        mockKeychain.save(data: data, forKey: provider.keychainKey, syncable: false)

        #expect(sut.accountEmail(for: provider) == "user@example.com")
    }

    @Test func signOutRemovesCredentialFromKeychain() throws {
        let credential = OAuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            accountId: nil,
            accountEmail: nil
        )
        let data = try JSONEncoder().encode(credential)
        mockKeychain.save(data: data, forKey: provider.keychainKey, syncable: false)
        #expect(sut.isSignedIn(provider: provider))

        sut.signOut(provider: provider)

        #expect(mockKeychain.getData(forKey: provider.keychainKey, syncable: false) == nil,
                "After signOut the keychain entry for this provider must be cleared")
    }

    @Test func expiredCredentialWithNoRefreshTokenIsAutoDeleted() throws {
        let expired = OAuthCredential(
            accessToken: "access",
            refreshToken: "",
            expiresAt: Date().addingTimeInterval(-60),
            accountId: nil,
            accountEmail: nil
        )
        let data = try JSONEncoder().encode(expired)
        mockKeychain.save(data: data, forKey: provider.keychainKey, syncable: false)

        #expect(!sut.isSignedIn(provider: provider),
                "Expired credential with empty refresh token must not count as signed in")
        #expect(mockKeychain.getData(forKey: provider.keychainKey, syncable: false) == nil,
                "loadCredential() must delete unrecoverable expired credentials")
    }
}
