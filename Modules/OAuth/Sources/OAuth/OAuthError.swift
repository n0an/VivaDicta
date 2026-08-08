// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Errors that can occur during the OAuth flow.
public enum OAuthError: LocalizedError {
    case timeout
    case stateMismatch
    case authorizationDenied(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case noCredential
    case invalidResponse
    /// The provider does not advertise a device authorization endpoint.
    case deviceCodeUnsupported(String)
    /// The device-authorization request failed or returned an unusable payload.
    case deviceCodeFailed(String)
    /// The user did not authorize the device code before it expired.
    case deviceCodeExpired

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Sign-in timed out. Please try again."
        case .stateMismatch:
            return "Invalid response from server. Please try again."
        case .authorizationDenied(let reason):
            return "Authorization denied: \(reason)"
        case .tokenExchangeFailed(let reason):
            return "Failed to exchange token: \(reason)"
        case .tokenRefreshFailed(let reason):
            return "Failed to refresh token: \(reason)"
        case .noCredential:
            return "Not signed in."
        case .invalidResponse:
            return "Invalid response from server."
        case .deviceCodeUnsupported(let providerName):
            return "\(providerName) does not support device-code sign-in."
        case .deviceCodeFailed(let reason):
            return "Failed to start sign-in: \(reason)"
        case .deviceCodeExpired:
            return "The sign-in code expired before it was authorized. Please try again."
        }
    }
}
