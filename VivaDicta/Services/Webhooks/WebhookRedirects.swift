//
//  WebhookRedirects.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.06
//

import Foundation

/// Webhook requests never follow HTTP redirects: the note and the token go
/// only to the exact https URL the user entered. Following a 307/308 would
/// re-send the note to another host, or over plain http, since the app
/// allows arbitrary loads and ATS would not stop it.
///
/// Default and ephemeral sessions ask their delegate before following, so
/// ``WebhookRedirectRefuser`` turns the 3xx response itself into the result.
/// Background sessions follow redirects without asking, which is why webhook
/// requests never use one. ``isSameEndpoint(_:_:)`` is a second check on
/// every completion.
nonisolated enum WebhookRedirects {
    static let notFollowedMessage = "Redirects are not followed. Enter the final URL instead."

    /// Session for "Send test": ephemeral, no cache or cookies, refuses redirects.
    static let testSession = makeSession(configuration: .ephemeral)

    static func makeSession(configuration: URLSessionConfiguration) -> URLSession {
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: WebhookRedirectRefuser(), delegateQueue: nil)
    }

    /// Whether a response for `finalURL` still came from the endpoint the
    /// request was sent to (`original`). Scheme and host compare
    /// case-insensitively, a missing port matches the scheme's default, and
    /// an empty path matches "/".
    static func isSameEndpoint(_ original: URL, _ finalURL: URL) -> Bool {
        guard let lhs = URLComponents(url: original, resolvingAgainstBaseURL: true),
              let rhs = URLComponents(url: finalURL, resolvingAgainstBaseURL: true) else {
            return original == finalURL
        }
        func port(_ components: URLComponents) -> Int? {
            components.port ?? (components.scheme?.lowercased() == "https" ? 443 : components.scheme?.lowercased() == "http" ? 80 : nil)
        }
        func path(_ components: URLComponents) -> String {
            components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        }
        return lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && port(lhs) == port(rhs)
            && path(lhs) == path(rhs)
            && lhs.percentEncodedQuery == rhs.percentEncodedQuery
    }
}

/// Refuses every HTTP redirect, so the 3xx response is returned as the result.
/// Only consulted by default and ephemeral sessions.
nonisolated final class WebhookRedirectRefuser: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
