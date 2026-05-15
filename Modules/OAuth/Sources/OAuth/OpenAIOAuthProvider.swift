// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// OpenAI OAuth provider configuration.
/// Uses the same client ID as the Codex CLI for OAuth PKCE flow.
public struct OpenAIOAuthProvider: OAuthProvider {
    public let providerName = "OpenAI"
    public let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    public let authorizeURL = "https://auth.openai.com/oauth/authorize"
    public let tokenURL = "https://auth.openai.com/oauth/token"
    public let redirectURI = "http://localhost:1455/auth/callback"
    public let scopes = "openid profile email offline_access"
    public let keychainKey = "chatGPTOAuthCredential"

    public let extraAuthParams: [String: String] = [
        "codex_cli_simplified_flow": "true",
        "id_token_add_organizations": "true"
    ]

    public init() {}

    /// OpenAI backend API endpoint for AI completions.
    public static let completionsEndpoint = "https://chatgpt.com/backend-api/codex/responses"

    /// OpenAI backend API endpoint for listing available models.
    public static let modelsEndpoint = "https://chatgpt.com/backend-api/codex/models"

    public func extractAccountInfo(from claims: [String: Any]) -> (id: String?, email: String?) {
        // Account ID: try multiple known claim paths
        let accountId: String? = {
            if let id = claims["chatgpt_account_id"] as? String {
                return id
            }
            if let auth = claims["https://api.openai.com/auth"] as? [String: Any],
               let id = auth["chatgpt_account_id"] as? String {
                return id
            }
            if let orgs = claims["organizations"] as? [[String: Any]],
               let first = orgs.first,
               let id = first["id"] as? String {
                return id
            }
            return nil
        }()

        // Email: try multiple known claim paths
        let email: String? = {
            if let email = claims["email"] as? String {
                return email
            }
            if let profile = claims["https://api.openai.com/profile"] as? [String: Any],
               let email = profile["email"] as? String {
                return email
            }
            return nil
        }()

        return (accountId, email)
    }

    /// Decodes JWT payload without signature verification (trusted issuer).
    public static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }

        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }
}
