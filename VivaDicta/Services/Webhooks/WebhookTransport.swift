//
//  WebhookTransport.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import Synchronization

/// Identifies one upload attempt of one outbox item. Stored in the task's
/// `taskDescription`, so a completion that arrives after the item was re-armed
/// can be matched to the attempt that produced it.
nonisolated struct WebhookTaskTag: Hashable, Sendable {
    let itemID: UUID
    let attempt: Int

    var taskDescription: String { "\(itemID.uuidString)#\(attempt)" }

    init(itemID: UUID, attempt: Int) {
        self.itemID = itemID
        self.attempt = attempt
    }

    init?(taskDescription: String?) {
        guard let parts = taskDescription?.split(separator: "#"), parts.count == 2,
              let itemID = UUID(uuidString: String(parts[0])),
              let attempt = Int(parts[1]) else { return nil }
        self.init(itemID: itemID, attempt: attempt)
    }
}

/// Outcome of one upload task, reported by a ``WebhookTransport``.
nonisolated struct WebhookTransportResult: Sendable, Equatable {
    let tag: WebhookTaskTag
    let statusCode: Int?
    let retryAfter: String?
    let errorCode: URLError.Code?
    let errorDescription: String?
    /// The response came from another URL than the one requested. The session
    /// refuses redirects, so this is a second line of defense.
    var redirected = false
}

/// Starts file-backed uploads and reports their completion through a handler,
/// so completions reach the service even when nothing awaits them (a manual
/// send that stopped waiting, or an automatic send).
nonisolated protocol WebhookTransport: AnyObject, Sendable {
    func setCompletionHandler(_ handler: @escaping @Sendable (WebhookTransportResult) -> Void)
    func start(tag: WebhookTaskTag, request: URLRequest, bodyFileURL: URL)
    /// Cancels every task of the item, whatever its attempt.
    func cancel(itemID: UUID)
    /// Cancels only the task of one attempt, leaving newer attempts of the item alone.
    func cancel(tag: WebhookTaskTag)
    /// Attempts that still have a running task.
    func activeTags() async -> Set<WebhookTaskTag>
}

/// `URLSession`-backed transport running in the app's process.
///
/// Deliberately not a background session: background sessions follow HTTP
/// redirects without asking their delegate, which would re-send the note to
/// whatever URL the server names (see ``WebhookRedirects``). This session
/// refuses every redirect. Uploads therefore run only while the app runs;
/// ``WebhookDeliveryService`` asks for background time while one is in flight.
nonisolated final class URLSessionWebhookTransport: WebhookTransport {
    private let session: URLSession
    private let delegate: Delegate

    init(configuration: URLSessionConfiguration) {
        delegate = Delegate()
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    static func makeDefault() -> URLSessionWebhookTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        // Fail fast when offline; the retry policy decides when to try again.
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = WebhookRequestBuilder.timeout
        configuration.timeoutIntervalForResource = 2 * WebhookRequestBuilder.timeout
        return URLSessionWebhookTransport(configuration: configuration)
    }

    func setCompletionHandler(_ handler: @escaping @Sendable (WebhookTransportResult) -> Void) {
        delegate.handler.withLock { $0 = handler }
    }

    func start(tag: WebhookTaskTag, request: URLRequest, bodyFileURL: URL) {
        let task = session.uploadTask(with: request, fromFile: bodyFileURL)
        task.taskDescription = tag.taskDescription
        task.resume()
    }

    func cancel(itemID: UUID) {
        session.getAllTasks { tasks in
            for task in tasks where WebhookTaskTag(taskDescription: task.taskDescription)?.itemID == itemID {
                task.cancel()
            }
        }
    }

    func cancel(tag: WebhookTaskTag) {
        let description = tag.taskDescription
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription == description {
                task.cancel()
            }
        }
    }

    func activeTags() async -> Set<WebhookTaskTag> {
        let tasks = await session.allTasks
        return Set(tasks.compactMap { task in
            guard task.state == .running || task.state == .suspended else { return nil }
            return WebhookTaskTag(taskDescription: task.taskDescription)
        })
    }

    private final class Delegate: NSObject, URLSessionDataDelegate, Sendable {
        let handler = Mutex<(@Sendable (WebhookTransportResult) -> Void)?>(nil)

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
            guard let tag = WebhookTaskTag(taskDescription: task.taskDescription) else { return }
            let response = task.response as? HTTPURLResponse
            let urlError = error as? URLError
            var redirected = false
            if let requested = task.originalRequest?.url, let answered = response?.url {
                redirected = !WebhookRedirects.isSameEndpoint(requested, answered)
            }
            let result = WebhookTransportResult(
                tag: tag,
                statusCode: error == nil ? response?.statusCode : nil,
                retryAfter: response?.value(forHTTPHeaderField: "Retry-After"),
                errorCode: urlError?.code ?? (error != nil ? .unknown : nil),
                errorDescription: error?.localizedDescription,
                redirected: redirected
            )
            handler.withLock { $0 }?(result)
        }

        /// Refuses every redirect, so the 3xx response is the result.
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
}
