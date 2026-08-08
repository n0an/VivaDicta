// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// xAI (Grok) OAuth provider configuration.
///
/// Signs the user in with their **SuperGrok or X Premium subscription** instead
/// of a metered `console.x.ai` API key. The resulting access token is a plain
/// bearer for `https://api.x.ai/v1`, so the normal OpenAI-compatible transport
/// is reused unchanged - the token simply takes the API key's place.
///
/// Uses xAI's public Grok CLI OAuth client (no client secret). The endpoints
/// below are published at `https://auth.x.ai/.well-known/openid-configuration`.
///
/// Sign-in runs the **device-code** grant rather than the browser redirect:
/// xAI validates `redirect_uri` against the values registered for this client,
/// so the redirect flow would need a loopback listener on one specific port.
/// Device code needs no callback at all. `authorizeURL` / `redirectURI` are
/// still populated with the registered pair so the redirect flow stays
/// available, but nothing in the app drives it today.
public struct GrokOAuthProvider: OAuthProvider {
    public let providerName = "Grok"
    public let clientId = "b1a00492-073a-47ea-816f-4c329264a828"
    public let authorizeURL = "https://auth.x.ai/oauth2/authorize"
    public let tokenURL = "https://auth.x.ai/oauth2/token"
    public let deviceCodeURL: String? = "https://auth.x.ai/oauth2/device/code"
    public let redirectURI = "http://127.0.0.1:56121/callback"

    /// `api:access` is what grants the subscription token access to
    /// `api.x.ai`. Without it the token is scoped to Grok Build only, which
    /// speaks a different host and wire format.
    public let scopes = "openid profile email offline_access grok-cli:access api:access"

    public let keychainKey = "grokOAuthCredential"

    /// Unused - the redirect flow is not driven by the app. See the type note.
    public let extraAuthParams: [String: String] = [:]

    public let deviceAuthExtraParams: [String: String] = ["referrer": "vivadicta"]

    public init() {}

    public func extractAccountInfo(from claims: [String: Any]) -> (id: String?, email: String?) {
        // Team principals carry the useful id in `principal_id`; personal
        // accounts use the standard `sub`.
        let id: String? = {
            if claims["principal_type"] as? String == "Team",
               let principalId = claims["principal_id"] as? String {
                return principalId
            }
            return claims["sub"] as? String
        }()

        let email: String? = {
            if let email = claims["email"] as? String, email.contains("@") {
                return email
            }
            return claims["preferred_username"] as? String
        }()

        return (id, email)
    }
}
