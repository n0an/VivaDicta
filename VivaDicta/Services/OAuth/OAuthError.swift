// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Errors that can occur during the OAuth flow.
enum OAuthError: LocalizedError {
    case timeout
    case stateMismatch
    case authorizationDenied(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case noCredential
    case invalidResponse

    var errorDescription: String? {
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
        }
    }
}
