// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Network
import os

/// Minimal TCP server that listens on localhost for an OAuth redirect callback.
/// On iOS, it bridges the localhost redirect to a custom URL scheme so that
/// ASWebAuthenticationSession can intercept it.
final class OAuthCallbackServer: Sendable {
    private let logger = Logger(category: .oauthManager)
    let port: UInt16
    /// The custom URL scheme to redirect to after capturing the OAuth callback.
    let customSchemeRedirectBase: String

    init(port: UInt16 = 1455, customSchemeRedirectBase: String = "vivadicta://auth/callback") {
        self.port = port
        self.customSchemeRedirectBase = customSchemeRedirectBase
    }

    /// Starts the local server. When the OAuth provider redirects to localhost,
    /// this server responds with an HTTP 302 redirect to the custom URL scheme,
    /// forwarding the authorization code and state parameters.
    func start() async throws -> NWListener {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)

        listener.newConnectionHandler = { [logger, customSchemeRedirectBase] connection in
            connection.start(queue: .global(qos: .userInitiated))
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                guard let data, let requestString = String(data: data, encoding: .utf8) else {
                    connection.cancel()
                    return
                }

                logger.logInfo("OAuth callback server received request")

                // Extract the request path from the HTTP request line
                guard let firstLine = requestString.components(separatedBy: "\r\n").first,
                      let pathPart = firstLine.split(separator: " ").dropFirst().first,
                      let components = URLComponents(string: String(pathPart)) else {
                    Self.sendHTTPResponse(connection: connection, html: "<h1>Error</h1><p>Invalid request.</p>")
                    return
                }

                // Build the custom scheme redirect URL with the same query parameters
                let queryString = components.query ?? ""
                let redirectURL = queryString.isEmpty
                    ? customSchemeRedirectBase
                    : "\(customSchemeRedirectBase)?\(queryString)"

                // Respond with 302 redirect to the custom scheme
                let response = "HTTP/1.1 302 Found\r\nLocation: \(redirectURL)\r\nConnection: close\r\n\r\n"
                connection.send(content: response.data(using: .utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: listener)
                case .failed(let error):
                    continuation.resume(throwing: OAuthError.tokenExchangeFailed("Callback server failed: \(error.localizedDescription)"))
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }
    }

    // MARK: - Helpers

    private static func sendHTTPResponse(connection: NWConnection, html: String) {
        let fullHTML = "<!DOCTYPE html><html><head><title>OAuth</title></head><body style=\"font-family:-apple-system,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;\">\(html)</body></html>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n\(fullHTML)"
        connection.send(content: response.data(using: .utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
