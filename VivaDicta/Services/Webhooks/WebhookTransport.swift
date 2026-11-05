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
/// (or in a later launch) can be matched to the attempt that produced it.
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
}

nonisolated enum WebhookTransportEvent: Sendable {
    case completed(WebhookTransportResult)
    /// A background session delivered all events queued while the app was not running.
    case finishedBackgroundEvents
}

/// Starts file-backed uploads and reports their completion.
///
/// Delegate-based rather than `async` on purpose: in production the uploads
/// run in a background `URLSession` and their completions can arrive in a
/// later launch of the app, when nothing is awaiting them.
nonisolated protocol WebhookTransport: AnyObject, Sendable {
    /// Whether ``start(tag:request:bodyFileURL:earliestBeginDate:)`` honors a
    /// future begin date. When `false` the caller must start the task when it is due.
    var supportsDeferredStart: Bool { get }

    func setEventHandler(_ handler: @escaping @Sendable (WebhookTransportEvent) -> Void)
    func start(tag: WebhookTaskTag, request: URLRequest, bodyFileURL: URL, earliestBeginDate: Date?)
    /// Cancels every task of the item, whatever its attempt.
    func cancel(itemID: UUID)
    /// Attempts that still have a running or scheduled task.
    func activeTags() async -> Set<WebhookTaskTag>
}

/// `URLSession`-backed transport. With a background configuration uploads
/// keep running while the app is suspended or terminated, and retries start
/// at their `earliestBeginDate` without the app being alive.
nonisolated final class URLSessionWebhookTransport: WebhookTransport {
    static let backgroundSessionIdentifier = "com.antonnovoselov.VivaDicta.webhooks"

    let supportsDeferredStart: Bool
    private let session: URLSession
    private let delegate: Delegate

    init(configuration: URLSessionConfiguration) {
        supportsDeferredStart = configuration.identifier != nil
        delegate = Delegate()
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    static func makeBackground() -> URLSessionWebhookTransport {
        let configuration = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForResource = WebhookRetryPolicy.maxAge
        return URLSessionWebhookTransport(configuration: configuration)
    }

    func setEventHandler(_ handler: @escaping @Sendable (WebhookTransportEvent) -> Void) {
        // Events can arrive as soon as the session exists (a relaunch for
        // background events), possibly before the handler is installed.
        let buffered = delegate.state.withLock { state in
            state.handler = handler
            defer { state.buffered.removeAll() }
            return state.buffered
        }
        buffered.forEach(handler)
    }

    func start(tag: WebhookTaskTag, request: URLRequest, bodyFileURL: URL, earliestBeginDate: Date?) {
        let task = session.uploadTask(with: request, fromFile: bodyFileURL)
        task.taskDescription = tag.taskDescription
        if supportsDeferredStart, let earliestBeginDate {
            task.earliestBeginDate = earliestBeginDate
        }
        task.resume()
    }

    func cancel(itemID: UUID) {
        session.getAllTasks { tasks in
            for task in tasks where WebhookTaskTag(taskDescription: task.taskDescription)?.itemID == itemID {
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
        struct State {
            var handler: (@Sendable (WebhookTransportEvent) -> Void)?
            var buffered: [WebhookTransportEvent] = []
        }

        let state = Mutex(State())

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
            guard let tag = WebhookTaskTag(taskDescription: task.taskDescription) else { return }
            let response = task.response as? HTTPURLResponse
            let urlError = error as? URLError
            let result = WebhookTransportResult(
                tag: tag,
                statusCode: error == nil ? response?.statusCode : nil,
                retryAfter: response?.value(forHTTPHeaderField: "Retry-After"),
                errorCode: urlError?.code ?? (error != nil ? .unknown : nil),
                errorDescription: error?.localizedDescription
            )
            deliver(.completed(result))
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            deliver(.finishedBackgroundEvents)
        }

        private func deliver(_ event: WebhookTransportEvent) {
            let handler = state.withLock { state -> (@Sendable (WebhookTransportEvent) -> Void)? in
                if state.handler == nil { state.buffered.append(event) }
                return state.handler
            }
            handler?(event)
        }
    }
}
