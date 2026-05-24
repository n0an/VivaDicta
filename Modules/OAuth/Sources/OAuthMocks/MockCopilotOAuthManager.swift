// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import OAuth
import TestUtilities

/// Hand-rolled mock of ``CopilotOAuthManager`` for consumer tests. Stubs the
/// device-code flow + token refresh without polling GitHub.
///
/// ## Usage
///
/// ```swift
/// let copilot = MockCopilotOAuthManager()
/// copilot.isSignedIn = true
/// copilot.stubValidCopilotTokenResponse = .success("ghu_test-token")
/// let sut = AIService(..., copilotOAuthManager: copilot)
/// _ = try await sut.enhance(...)
/// #expect(copilot.validCopilotTokenCallCount == 1)
/// ```
@MainActor
public final class MockCopilotOAuthManager: CopilotOAuthManager {
    public init() {}

    // MARK: state

    public var isSignedIn: Bool = false
    public var accountInfo: String?

    // MARK: startDeviceCodeFlow

    public var stubStartDeviceCodeFlowResponse: Result<DeviceCodeResponse, Error>?
    public var didStartDeviceCodeFlow: (() -> Void)?
    public private(set) var startDeviceCodeFlowCallCount = 0

    // MARK: pollForToken

    public var stubPollForTokenResponse: Result<CopilotCredential, Error>?
    public var didPollForToken: (() -> Void)?
    public private(set) var pollForTokenCallCount = 0
    public private(set) var capturedPollDeviceCode: String?
    public private(set) var capturedPollInterval: Int?
    public private(set) var capturedPollExpiresIn: Int?

    // MARK: validCopilotToken

    public var stubValidCopilotTokenResponse: Result<String, Error>?
    public var didFetchValidCopilotToken: (() -> Void)?
    public private(set) var validCopilotTokenCallCount = 0

    // MARK: signOut

    public var didSignOut: (() -> Void)?
    public private(set) var signOutCallCount = 0

    // MARK: - CopilotOAuthManager conformance

    public func startDeviceCodeFlow() async throws -> DeviceCodeResponse {
        defer { didStartDeviceCodeFlow?() }
        startDeviceCodeFlowCallCount += 1
        return try stubStartDeviceCodeFlowResponse.evaluate()
    }

    public func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> CopilotCredential {
        defer { didPollForToken?() }
        pollForTokenCallCount += 1
        capturedPollDeviceCode = deviceCode
        capturedPollInterval = interval
        capturedPollExpiresIn = expiresIn
        return try stubPollForTokenResponse.evaluate()
    }

    public func validCopilotToken() async throws -> String {
        defer { didFetchValidCopilotToken?() }
        validCopilotTokenCallCount += 1
        return try stubValidCopilotTokenResponse.evaluate()
    }

    public func signOut() {
        defer { didSignOut?() }
        signOutCallCount += 1
        isSignedIn = false
    }
}
