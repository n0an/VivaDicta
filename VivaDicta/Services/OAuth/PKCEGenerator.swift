// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import CryptoKit

/// Generates PKCE (Proof Key for Code Exchange) parameters for OAuth flows.
struct PKCEGenerator: Sendable {
    let verifier: String
    let challenge: String

    /// Generates a new PKCE verifier/challenge pair.
    static func generate() -> PKCEGenerator {
        let verifierData = randomBytes(count: 32)
        let verifier = base64URLEncode(verifierData)
        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = base64URLEncode(challengeData)
        return PKCEGenerator(verifier: verifier, challenge: challenge)
    }

    /// Generates a random state string for CSRF protection.
    static func generateState() -> String {
        base64URLEncode(randomBytes(count: 32))
    }

    // MARK: - Helpers

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}
