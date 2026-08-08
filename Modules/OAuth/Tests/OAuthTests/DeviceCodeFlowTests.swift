// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
import Foundation
@testable import OAuth
import OAuthMocks
import KeychainMocks
import NetworkingMocks
import TestUtilities

/// Covers `DefaultOAuthManager`'s RFC 8628 device-code flow - the sign-in path
/// used by xAI Grok, and the only sign-in path that is testable without a
/// browser session.
///
/// Poll tests use `interval: 1` because the manager waits one interval before
/// its first poll (a 0/absent interval is floored to 1s), so each poll round
/// costs a real second of wall clock.
@MainActor
struct DeviceCodeFlowTests {

    private let keychain: MockKeychainService
    private let network: MockNetworkService
    private let provider: MockOAuthProvider
    private let sut: DefaultOAuthManager

    init() {
        self.keychain = MockKeychainService()
        self.network = MockNetworkService()
        self.provider = MockOAuthProvider(
            keychainKey: "test.device.credential",
            deviceCodeURL: "https://auth.example.com/oauth2/device/code"
        )
        self.sut = DefaultOAuthManager(keychain: keychain, networkService: network)
        self.provider.stubPostAuthSetupResponse = .success(nil)
    }

    // MARK: - startDeviceCodeFlow

    @Test func throwsWhenProviderDoesNotSupportDeviceCode() async {
        provider.deviceCodeURL = nil

        await #expect(throws: OAuthError.self) {
            _ = try await sut.startDeviceCodeFlow(provider: provider)
        }
    }

    @Test func parsesCompleteDeviceCodeResponse() async throws {
        network.stubSendResponse = .success((deviceCodeBody(), httpResponse(200)))

        let result = try await sut.startDeviceCodeFlow(provider: provider)

        #expect(result.deviceCode == "device-abc")
        #expect(result.userCode == "WXYZ-1234")
        #expect(result.verificationUri == "https://auth.example.com/device")
        #expect(result.verificationUriComplete == "https://auth.example.com/device?code=WXYZ-1234")
        #expect(result.interval == 3)
        #expect(result.expiresIn == 600)
    }

    @Test func browserURIPrefersThePreFilledVerificationURI() async throws {
        network.stubSendResponse = .success((deviceCodeBody(), httpResponse(200)))

        let result = try await sut.startDeviceCodeFlow(provider: provider)

        #expect(result.browserURI == "https://auth.example.com/device?code=WXYZ-1234")
    }

    /// RFC 8628 permits `interval: 0` and allows omitting it entirely. Neither
    /// is an error, and neither may become a zero-delay poll loop.
    @Test(arguments: ["\"interval\":0,", "\"interval\":-4,", ""])
    func fallsBackToFiveSecondIntervalWhenServerIntervalIsUnusable(_ intervalField: String) async throws {
        let body = Data("""
        {"device_code":"device-abc","user_code":"WXYZ-1234",\
        "verification_uri":"https://auth.example.com/device",\(intervalField)"expires_in":600}
        """.utf8)
        network.stubSendResponse = .success((body, httpResponse(200)))

        let result = try await sut.startDeviceCodeFlow(provider: provider)

        #expect(result.interval == 5)
    }

    @Test func fallsBackToDefaultExpiryWhenServerOmitsIt() async throws {
        let body = Data("""
        {"device_code":"device-abc","user_code":"WXYZ-1234",\
        "verification_uri":"https://auth.example.com/device","interval":3}
        """.utf8)
        network.stubSendResponse = .success((body, httpResponse(200)))

        let result = try await sut.startDeviceCodeFlow(provider: provider)

        #expect(result.expiresIn == 900)
    }

    /// The verification URI is handed to the system opener, so a non-https
    /// scheme must never survive parsing - it would let a spoofed response
    /// launch an arbitrary handler.
    @Test(arguments: [
        "javascript:alert(1)",
        "vivadicta://auth/callback",
        "http://auth.example.com/device",
        "not a url at all"
    ])
    func rejectsNonHTTPSVerificationURI(_ hostileURI: String) async {
        let body = Data("""
        {"device_code":"device-abc","user_code":"WXYZ-1234",\
        "verification_uri":"\(hostileURI)","interval":3,"expires_in":600}
        """.utf8)
        network.stubSendResponse = .success((body, httpResponse(200)))

        await #expect(throws: OAuthError.self) {
            _ = try await sut.startDeviceCodeFlow(provider: provider)
        }
    }

    /// A hostile *optional* pre-filled URI is dropped rather than failing the
    /// whole sign-in: the plain https URI still works, so the user is not
    /// blocked, and the bad value never reaches the opener.
    @Test func dropsNonHTTPSPreFilledURIButKeepsTheFlowUsable() async throws {
        let body = Data("""
        {"device_code":"device-abc","user_code":"WXYZ-1234",\
        "verification_uri":"https://auth.example.com/device",\
        "verification_uri_complete":"javascript:alert(1)",\
        "interval":3,"expires_in":600}
        """.utf8)
        network.stubSendResponse = .success((body, httpResponse(200)))

        let result = try await sut.startDeviceCodeFlow(provider: provider)

        #expect(result.verificationUriComplete == nil)
        #expect(result.browserURI == "https://auth.example.com/device")
    }

    @Test(arguments: [
        #"{"user_code":"WXYZ","verification_uri":"https://a.example.com","expires_in":600}"#,
        #"{"device_code":"d","verification_uri":"https://a.example.com","expires_in":600}"#,
        #"{"device_code":"d","user_code":"WXYZ","expires_in":600}"#,
        #"{"device_code":"","user_code":"WXYZ","verification_uri":"https://a.example.com"}"#
    ])
    func throwsWhenRequiredFieldsAreMissingOrEmpty(_ json: String) async {
        network.stubSendResponse = .success((Data(json.utf8), httpResponse(200)))

        await #expect(throws: OAuthError.self) {
            _ = try await sut.startDeviceCodeFlow(provider: provider)
        }
    }

    @Test func surfacesServerErrorDetailOnNonSuccessStatus() async {
        let body = Data(#"{"error":"invalid_client","error_description":"unknown client"}"#.utf8)
        network.stubSendResponse = .success((body, httpResponse(400)))

        await #expect(throws: OAuthError.self) {
            _ = try await sut.startDeviceCodeFlow(provider: provider)
        }
    }

    // MARK: - pollForDeviceCodeToken

    @Test func pendingThenAuthorizedReturnsCredential() async throws {
        network.stubSendResponses = [
            .success((Data(#"{"error":"authorization_pending"}"#.utf8), httpResponse(400))),
            .success((tokenBody(), httpResponse(200)))
        ]

        let credential = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())

        #expect(credential.accessToken == "granted-token")
        #expect(credential.refreshToken == "granted-refresh")
        #expect(network.sendCallCount == 2)
    }

    @Test func authorizedCredentialIsPersistedAndMarksProviderSignedIn() async throws {
        network.stubSendResponses = [.success((tokenBody(), httpResponse(200)))]

        _ = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())

        #expect(sut.isSignedIn(provider: provider))
        let persisted = try #require(keychain.getData(forKey: provider.keychainKey, syncable: false))
        let decoded = try JSONDecoder().decode(OAuthCredential.self, from: persisted)
        #expect(decoded.accessToken == "granted-token")
    }

    /// `slow_down` is a throttle signal, not a failure: the poll must back off
    /// and keep going.
    @Test func slowDownBacksOffAndKeepsPolling() async throws {
        network.stubSendResponses = [
            .success((Data(#"{"error":"slow_down","interval":1}"#.utf8), httpResponse(400))),
            .success((tokenBody(), httpResponse(200)))
        ]

        let credential = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())

        #expect(credential.accessToken == "granted-token")
        #expect(network.sendCallCount == 2)
    }

    @Test(arguments: ["access_denied", "authorization_denied"])
    func deniedAuthorizationThrows(_ error: String) async {
        network.stubSendResponses = [
            .success((Data("{\"error\":\"\(error)\"}".utf8), httpResponse(400)))
        ]

        await #expect(throws: OAuthError.self) {
            _ = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())
        }
        #expect(sut.isSignedIn(provider: provider) == false)
    }

    @Test func expiredDeviceCodeThrows() async {
        network.stubSendResponses = [
            .success((Data(#"{"error":"expired_token"}"#.utf8), httpResponse(400)))
        ]

        await #expect(throws: OAuthError.self) {
            _ = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())
        }
    }

    /// An unrecognized `error` code is a real failure, not something to keep
    /// polling through until the code expires.
    @Test func unknownErrorCodeFailsFast() async {
        network.stubSendResponses = [
            .success((Data(#"{"error":"invalid_grant"}"#.utf8), httpResponse(400)))
        ]

        await #expect(throws: OAuthError.self) {
            _ = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())
        }
        #expect(network.sendCallCount == 1)
    }

    @Test func givesUpOnceTheDeviceCodeWindowHasPassed() async {
        network.stubSendResponse = .success((Data(#"{"error":"authorization_pending"}"#.utf8), httpResponse(400)))

        await #expect(throws: OAuthError.self) {
            _ = try await sut.pollForDeviceCodeToken(
                provider: provider,
                deviceCode: makeDeviceCode(expiresIn: 0)
            )
        }
    }

    @Test func assumesOneHourLifetimeWhenTokenResponseOmitsExpiry() async throws {
        let body = Data(#"{"access_token":"granted-token","refresh_token":"granted-refresh"}"#.utf8)
        network.stubSendResponses = [.success((body, httpResponse(200)))]

        let credential = try await sut.pollForDeviceCodeToken(provider: provider, deviceCode: makeDeviceCode())

        // 3600s default, allowing slack for the poll's own wall-clock delay.
        let lifetime = credential.expiresAt.timeIntervalSinceNow
        #expect(lifetime > 3500 && lifetime <= 3600)
    }

    // MARK: - Helpers

    private func makeDeviceCode(expiresIn: Int = 600) -> DeviceCodeResponse {
        DeviceCodeResponse(
            deviceCode: "device-abc",
            userCode: "WXYZ-1234",
            verificationUri: "https://auth.example.com/device",
            interval: 1,
            expiresIn: expiresIn
        )
    }

    private func deviceCodeBody() -> Data {
        Data("""
        {"device_code":"device-abc","user_code":"WXYZ-1234",\
        "verification_uri":"https://auth.example.com/device",\
        "verification_uri_complete":"https://auth.example.com/device?code=WXYZ-1234",\
        "interval":3,"expires_in":600}
        """.utf8)
    }

    private func tokenBody() -> Data {
        Data(#"{"access_token":"granted-token","refresh_token":"granted-refresh","expires_in":3600}"#.utf8)
    }

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://auth.example.com/oauth2/token")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
