// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// GitHub Copilot OAuth manager seam used by consumers. The production
/// conformance is ``DefaultCopilotOAuthManager``; tests inject
/// `MockCopilotOAuthManager` from `OAuthMocks` to fake the device-code
/// flow without polling GitHub.
///
/// `@MainActor`-isolated to match the credential-storage and background-task
/// requirements of the device-code flow.
@MainActor
public protocol CopilotOAuthManager {
    /// Whether the user is signed in to Copilot.
    var isSignedIn: Bool { get }

    /// Display name shown in settings (GitHub username if known).
    var accountInfo: String? { get }

    /// Kicks off the GitHub device-code flow. Returns the user code +
    /// verification URL the caller surfaces in UI.
    func startDeviceCodeFlow() async throws -> DeviceCodeResponse

    /// Polls GitHub until the user authorizes the device code.
    /// `expiresIn` defaults to 900s, matching the GitHub-issued lifetime.
    func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> CopilotCredential

    /// Returns a valid Copilot token, refreshing from the stored GitHub
    /// access token if the Copilot token is expiring soon.
    func validCopilotToken() async throws -> String

    /// Signs out by removing the stored credential.
    func signOut()
}
