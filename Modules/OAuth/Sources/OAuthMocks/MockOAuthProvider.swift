// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import OAuth
import TestUtilities

/// Hand-rolled mock for `OAuthProvider`. All scalar properties are tunable
/// via `init` parameters or by assignment. `postAuthSetup` uses the
/// `stubPostAuthSetupResponse` Result for happy-path / error simulation.
public final class MockOAuthProvider: OAuthProvider, @unchecked Sendable {

    public var providerName: String
    public var clientId: String
    public var authorizeURL: String
    public var tokenURL: String
    public var redirectURI: String
    public var scopes: String
    public var extraAuthParams: [String: String]
    public var keychainKey: String
    public var tokenRequestUsesJSON: Bool
    public var clientSecret: String?
    public var userinfoURL: String?

    public var stubExtractedAccountInfo: (id: String?, email: String?) = (nil, nil)
    public var stubPostAuthSetupResponse: Result<String?, Error>?

    public private(set) var extractAccountInfoCallCount = 0
    public private(set) var postAuthSetupCallCount = 0
    public private(set) var capturedClaims: [String: Any]?
    public private(set) var capturedAccessToken: String?

    public init(
        providerName: String = "MockProvider",
        clientId: String = "mock-client-id",
        authorizeURL: String = "https://example.com/authorize",
        tokenURL: String = "https://example.com/token",
        redirectURI: String = "https://example.com/callback",
        scopes: String = "scope1",
        extraAuthParams: [String: String] = [:],
        keychainKey: String = "mockOAuthCredential",
        tokenRequestUsesJSON: Bool = false,
        clientSecret: String? = nil,
        userinfoURL: String? = nil
    ) {
        self.providerName = providerName
        self.clientId = clientId
        self.authorizeURL = authorizeURL
        self.tokenURL = tokenURL
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.extraAuthParams = extraAuthParams
        self.keychainKey = keychainKey
        self.tokenRequestUsesJSON = tokenRequestUsesJSON
        self.clientSecret = clientSecret
        self.userinfoURL = userinfoURL
    }

    public func extractAccountInfo(from claims: [String: Any]) -> (id: String?, email: String?) {
        extractAccountInfoCallCount += 1
        capturedClaims = claims
        return stubExtractedAccountInfo
    }

    public func postAuthSetup(accessToken: String) async throws -> String? {
        postAuthSetupCallCount += 1
        capturedAccessToken = accessToken
        return try stubPostAuthSetupResponse.evaluate()
    }
}
