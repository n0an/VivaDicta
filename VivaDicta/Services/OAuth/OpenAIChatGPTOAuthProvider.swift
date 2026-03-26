// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// OpenAI ChatGPT OAuth provider configuration.
/// Uses the same client ID as the Codex CLI for OAuth PKCE flow.
struct OpenAIChatGPTOAuthProvider: OAuthProvider {
    let providerName = "ChatGPT"
    let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    let authorizeURL = "https://auth.openai.com/oauth/authorize"
    let tokenURL = "https://auth.openai.com/oauth/token"
    let redirectURI = "http://localhost:1455/auth/callback"
    let scopes = "openid profile email offline_access"
    let keychainKey = "chatGPTOAuthCredential"

    let extraAuthParams: [String: String] = [
        "codex_cli_simplified_flow": "true",
        "id_token_add_organizations": "true"
    ]

    /// ChatGPT backend API endpoint for AI completions.
    static let completionsEndpoint = "https://chatgpt.com/backend-api/codex/responses"

    /// ChatGPT backend API endpoint for listing available models.
    static let modelsEndpoint = "https://chatgpt.com/backend-api/codex/models"

    func extractAccountInfo(from claims: [String: Any]) -> (id: String?, email: String?) {
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
    static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
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
