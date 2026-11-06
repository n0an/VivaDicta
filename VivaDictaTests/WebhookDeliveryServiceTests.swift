//
//  WebhookDeliveryServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import Synchronization
import Testing
import KeychainMocks
import OAuth
@testable import VivaDicta

/// Intercepts webhook uploads made through a real `URLSession` and answers
/// from a queue of canned responses. Process-global, so the suite is serialized.
nonisolated final class WebhookURLProtocolStub: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case status(Int, headers: [String: String] = [:])
        case failure(URLError.Code)
        /// Answers with a redirect. If the session follows it, the stub
        /// captures the request to `to`.
        case redirect(Int, to: URL)
        /// Answers as if a redirect had already been followed: the response
        /// URL differs from the request's.
        case servedFrom(URL, status: Int)
    }

    struct Captured: Sendable {
        let url: URL?
        let headers: [String: String]
        let body: Data
    }

    private struct State {
        var replies: [Reply] = []
        var captured: [Captured] = []
    }

    private static let state = Mutex(State())

    static func reset(replies: [Reply]) {
        state.withLock { $0 = State(replies: replies) }
    }

    static var captured: [Captured] {
        state.withLock { $0.captured }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? Self.read(request.httpBodyStream)
        let reply = Self.state.withLock { state -> Reply in
            state.captured.append(Captured(url: request.url, headers: request.allHTTPHeaderFields ?? [:], body: body))
            return state.replies.isEmpty ? .status(200) : state.replies.removeFirst()
        }
        switch reply {
        case .status(let code, let headers):
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .redirect(let code, let target):
            let response = HTTPURLResponse(
                url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString]
            )!
            var newRequest = request
            newRequest.url = target
            client?.urlProtocol(self, wasRedirectedTo: newRequest, redirectResponse: response)
            // Reached when the redirect is refused: the 3xx is the final response.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .servedFrom(let url, let code):
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: [:])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

@MainActor
@Suite(.serialized, .tags(.networking))
final class WebhookDeliveryServiceTests {

    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private let clock = Clock()
    private let directory: URL
    private let defaults: UserDefaults
    private let keychain = MockKeychainService()
    private let backgroundTasks = FakeBackgroundTaskService()
    private let store: WebhookStore
    private let service: WebhookDeliveryService

    init() {
        directory = URL.temporaryDirectory.appending(path: "WebhookTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defaults = UserDefaults(suiteName: "WebhookDeliveryServiceTests-\(UUID().uuidString)")!
        store = WebhookStore(defaults: defaults, keychain: keychain)
        let clock = clock
        let backgroundTasks = backgroundTasks
        service = WebhookDeliveryService(
            store: store,
            storage: WebhookOutboxStorage(directory: directory),
            makeTransport: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [WebhookURLProtocolStub.self]
                return URLSessionWebhookTransport(configuration: configuration)
            },
            backgroundTasks: backgroundTasks,
            now: { clock.now },
            appVersion: "9.9.9"
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    private func addWebhook(token: String? = nil) throws -> WebhookDefinition {
        let webhook = WebhookDefinition(name: "Meetings", url: URL(string: "https://example.com/hooks/meetings")!)
        try store.save(webhook, token: token.map { .set($0) } ?? .keep)
        return try #require(store.webhook(id: webhook.id))
    }

    private func input(id: UUID = UUID(), enhanced: String? = "Polished") -> WebhookPayloadInput {
        WebhookPayloadInput(
            transcriptionID: id,
            text: "raw",
            enhancedText: enhanced,
            modeName: "Meeting",
            timestamp: clock.now,
            audioDuration: 60,
            language: "en",
            sourceTag: "shareExtension",
            transcriptionModelName: "Parakeet",
            aiModelName: "gpt-test"
        )
    }

    /// Waits for async transport completions to land on the main actor.
    private func waitUntil(_ condition: () -> Bool, timeout: Duration = .seconds(5)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - Tests

    @Test func delivers_withContractHeadersAndBody() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(200)])
        let webhook = try addWebhook(token: "secret-token")
        let note = input()

        service.enqueue(note, to: webhook)
        try await waitUntil { service.items.isEmpty }

        let request = try #require(WebhookURLProtocolStub.captured.first)
        #expect(WebhookURLProtocolStub.captured.count == 1)
        #expect(request.url == webhook.url)
        #expect(request.headers["Authorization"] == "Bearer secret-token")
        #expect(request.headers["Idempotency-Key"] == note.transcriptionID.uuidString)
        #expect(request.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(request.headers["User-Agent"] == "VivaDicta/9.9.9")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["id"] as? String == note.transcriptionID.uuidString)
        #expect(body["text"] as? String == "Polished")
        #expect(body["rawText"] as? String == "raw")
        #expect(store.statuses[webhook.id]?.outcome == .delivered)
        #expect(store.statuses[webhook.id]?.statusCode == 200)
    }

    @Test func retryableFailure_isRetriedWithTheSameIdempotencyKey() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(503), .failure(.notConnectedToInternet), .status(204)])
        let webhook = try addWebhook()
        let note = input()

        service.enqueue(note, to: webhook)
        try await waitUntil { service.items.first?.isInFlight == false }
        #expect(store.statuses[webhook.id]?.outcome == .retrying)
        #expect(service.items.first?.nextAttemptAt == clock.now.addingTimeInterval(30))

        // Not due yet: nothing is sent.
        service.pump()
        #expect(WebhookURLProtocolStub.captured.count == 1)

        clock.now.addTimeInterval(30)
        service.pump()
        try await waitUntil { WebhookURLProtocolStub.captured.count == 2 && service.items.first?.isInFlight == false }
        #expect(service.items.first?.nextAttemptAt == clock.now.addingTimeInterval(120))

        clock.now.addTimeInterval(120)
        service.pump()
        try await waitUntil { service.items.isEmpty }

        let keys = WebhookURLProtocolStub.captured.map { $0.headers["Idempotency-Key"] }
        #expect(keys == Array(repeating: note.transcriptionID.uuidString, count: 3))
        #expect(store.statuses[webhook.id]?.outcome == .delivered)
    }

    @Test func nonRetryable4xx_stopsAndSurfacesTheFailure() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(401)])
        let webhook = try addWebhook()

        service.enqueue(input(), to: webhook)
        try await waitUntil { service.items.isEmpty }

        clock.now.addTimeInterval(3600)
        service.pump()
        #expect(WebhookURLProtocolStub.captured.count == 1)
        let status = try #require(store.statuses[webhook.id])
        #expect(status.outcome == .failed)
        #expect(status.statusCode == 401)
        #expect(status.message?.hasPrefix("HTTP 401") == true)
    }

    @Test func expiredItems_areDroppedAsFailed() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(500)])
        let webhook = try addWebhook()

        service.enqueue(input(), to: webhook)
        try await waitUntil { service.items.first?.isInFlight == false }

        clock.now.addTimeInterval(WebhookRetryPolicy.maxAge)
        service.pump()
        #expect(service.items.isEmpty)
        #expect(WebhookURLProtocolStub.captured.count == 1)
        #expect(store.statuses[webhook.id]?.outcome == .failed)
        #expect(store.statuses[webhook.id]?.message?.hasPrefix("Gave up after 24 hours") == true)
    }

    // MARK: Redirects

    private let redirectTarget = URL(string: "http://example.org/elsewhere")!

    @Test(arguments: [301, 302, 303, 307, 308])
    func redirect_isNotFollowed_andStopsDelivery(status: Int) async throws {
        WebhookURLProtocolStub.reset(replies: [.redirect(status, to: redirectTarget)])
        let webhook = try addWebhook(token: "secret-token")

        service.enqueue(input(), to: webhook)
        try await waitUntil { service.items.isEmpty }

        clock.now.addTimeInterval(3600)
        service.pump()
        // Only the configured URL was ever requested: no follow, no retry.
        #expect(WebhookURLProtocolStub.captured.map(\.url) == [webhook.url])
        let deliveryStatus = try #require(store.statuses[webhook.id])
        #expect(deliveryStatus.outcome == .failed)
        #expect(deliveryStatus.statusCode == status)
        #expect(deliveryStatus.message?.contains(WebhookRedirects.notFollowedMessage) == true)
    }

    @Test func responseFromAnotherURL_isNotCountedAsDelivered() async throws {
        // Second line of defense: a response from another URL is never a delivery.
        WebhookURLProtocolStub.reset(replies: [.servedFrom(redirectTarget, status: 200)])
        let webhook = try addWebhook()

        let result = await service.sendManually(input(), to: webhook)

        guard case .failed(let reason) = result else {
            Issue.record("Expected a failure, got \(result)")
            return
        }
        #expect(reason.hasPrefix("Redirected to another URL"))
        #expect(store.statuses[webhook.id]?.outcome == .failed)
        #expect(service.items.isEmpty)
        #expect(WebhookURLProtocolStub.captured.count == 1)
    }

    @Test(arguments: [307, 308])
    func sendTest_doesNotFollowRedirects(status: Int) async throws {
        WebhookURLProtocolStub.reset(replies: [.redirect(status, to: redirectTarget)])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebhookURLProtocolStub.self]
        let viewModel = WebhookEditViewModel(
            webhook: nil,
            store: store,
            session: WebhookRedirects.makeSession(configuration: configuration),
            appVersion: "9.9.9"
        )
        viewModel.urlString = "https://example.com/hooks/test"
        viewModel.tokenInput = "secret-token"

        await viewModel.sendTest()

        #expect(viewModel.testState == .failed("HTTP \(status). \(WebhookRedirects.notFollowedMessage)"))
        let captured = WebhookURLProtocolStub.captured
        #expect(captured.map(\.url) == [URL(string: "https://example.com/hooks/test")!])
        #expect(captured.first?.headers["Authorization"] == "Bearer secret-token")
    }

    @Test func delivery_usesTheWebhooksTextContent_andSendsRecordedAt() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(200)])
        var webhook = try addWebhook()
        webhook.textContent = .original
        try store.save(webhook, token: .keep)
        var note = input()
        note.recordedAt = clock.now.addingTimeInterval(-3 * 3600)

        service.enqueue(note, to: try #require(store.webhook(id: webhook.id)))
        try await waitUntil { service.items.isEmpty }

        let request = try #require(WebhookURLProtocolStub.captured.first)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["textContent"] as? String == "original")
        #expect(body["text"] as? String == "raw")
        #expect(body["rawText"] == nil)
        #expect(body["aiModel"] == nil)
        #expect(body["recordedAt"] as? String == WebhookPayloadBuilder.iso8601(clock.now.addingTimeInterval(-3 * 3600), timeZone: .current))
    }

    @Test(arguments: WebhookTextContent.allCases)
    func sendTest_honoursTheSelectedTextContent(option: WebhookTextContent) async throws {
        WebhookURLProtocolStub.reset(replies: [.status(200)])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WebhookURLProtocolStub.self]
        let viewModel = WebhookEditViewModel(
            webhook: nil,
            store: store,
            session: WebhookRedirects.makeSession(configuration: configuration),
            appVersion: "9.9.9"
        )
        viewModel.urlString = "https://example.com/hooks/test"
        viewModel.textContent = option

        await viewModel.sendTest()

        let request = try #require(WebhookURLProtocolStub.captured.first)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["textContent"] as? String == option.rawValue)
        #expect((body["rawText"] != nil) == (option == .both))
        #expect(body["recordedAt"] is String)
    }

    @Test func savingTheForm_storesTheTextContent() throws {
        let viewModel = WebhookEditViewModel(webhook: nil, store: store, appVersion: "9.9.9")
        viewModel.urlString = "https://example.com/hooks/test"
        #expect(viewModel.textContent == .both)

        viewModel.textContent = .processed
        #expect(viewModel.save())

        #expect(store.webhooks.first?.textContent == .processed)
        let reopened = WebhookEditViewModel(webhook: store.webhooks.first, store: store, appVersion: "9.9.9")
        #expect(reopened.textContent == .processed)
    }

    @Test func sendTest_productionSessionRefusesRedirects() {
        #expect(WebhookRedirects.testSession.delegate is WebhookRedirectRefuser)
    }

    @Test func manualResend_reusesTheTranscriptionID() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(200), .status(200)])
        let webhook = try addWebhook()
        let note = input()

        let first = await service.sendManually(note, to: webhook)
        let second = await service.sendManually(note, to: webhook)

        #expect(first == .delivered(statusCode: 200))
        #expect(second == .delivered(statusCode: 200))
        let ids = try WebhookURLProtocolStub.captured.map { captured in
            try #require(JSONSerialization.jsonObject(with: captured.body) as? [String: Any])["id"] as? String
        }
        #expect(ids == [note.transcriptionID.uuidString, note.transcriptionID.uuidString])
    }

    @Test func manualSend_reportsTheRejection() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(404)])
        let webhook = try addWebhook()

        let result = await service.sendManually(input(), to: webhook)
        guard case .failed(let reason) = result else {
            Issue.record("Expected a failure, got \(result)")
            return
        }
        #expect(reason.hasPrefix("HTTP 404"))
    }

    @Test func lockedKeychain_holdsTheItemInsteadOfSendingUnauthenticated() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(200)])
        let webhook = try addWebhook(token: "secret-token")
        keychain.stubGetString = .some(nil) // The Keychain answers "nothing" while locked.

        service.enqueue(input(), to: webhook)
        try await Task.sleep(for: .milliseconds(200))
        #expect(WebhookURLProtocolStub.captured.isEmpty)
        #expect(service.items.count == 1)

        keychain.stubGetString = nil
        service.pump()
        try await waitUntil { service.items.isEmpty }
        #expect(WebhookURLProtocolStub.captured.first?.headers["Authorization"] == "Bearer secret-token")
    }

    @Test func editingAWebhook_resendsPendingItemsToTheNewURLRightAway() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(503), .status(200)])
        var webhook = try addWebhook()

        service.enqueue(input(), to: webhook)
        try await waitUntil { service.items.first?.isInFlight == false }

        webhook.url = URL(string: "https://example.com/hooks/moved")!
        try store.save(webhook, token: .keep)
        service.rearmItems(forWebhook: webhook.id)
        try await waitUntil { service.items.isEmpty }

        #expect(WebhookURLProtocolStub.captured.map(\.url?.path) == ["/hooks/meetings", "/hooks/moved"])
    }

    @Test func deletingAWebhook_dropsItsPendingItems() async throws {
        WebhookURLProtocolStub.reset(replies: [.status(500)])
        let webhook = try addWebhook()
        store.onWebhookDeleted = { [service] id in service.discardItems(forWebhook: id) }

        service.enqueue(input(), to: webhook)
        try await waitUntil { service.items.first?.isInFlight == false }

        store.delete(id: webhook.id)
        #expect(service.items.isEmpty)
        #expect(store.statuses[webhook.id] == nil)
    }

    @Test func pendingItems_surviveARestart() async throws {
        WebhookURLProtocolStub.reset(replies: [.failure(.networkConnectionLost)])
        let webhook = try addWebhook()
        service.enqueue(input(), to: webhook)
        try await waitUntil { service.items.first?.isInFlight == false }

        // A fresh service over the same directory picks the item up again.
        WebhookURLProtocolStub.reset(replies: [.status(200)])
        let clock = clock
        clock.now.addTimeInterval(60)
        let restarted = WebhookDeliveryService(
            store: store,
            storage: WebhookOutboxStorage(directory: directory),
            makeTransport: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [WebhookURLProtocolStub.self]
                return URLSessionWebhookTransport(configuration: configuration)
            },
            backgroundTasks: backgroundTasks,
            now: { clock.now },
            appVersion: "9.9.9"
        )
        await restarted.resume()
        try await waitUntil { restarted.items.isEmpty }
        #expect(WebhookURLProtocolStub.captured.count == 1)
        #expect(store.statuses[webhook.id]?.outcome == .delivered)
    }
}

/// Scriptable transport for races the real `URLSession` cannot reproduce on demand.
nonisolated final class FakeWebhookTransport: WebhookTransport {
    struct State {
        var handler: (@Sendable (WebhookTransportResult) -> Void)?
        var started: [WebhookTaskTag] = []
        var cancelledTags: [WebhookTaskTag] = []
        var cancelledItems: [UUID] = []
        /// Runs inside `activeTags()` before it returns, to simulate events
        /// arriving while the caller awaits the task list.
        var duringActiveTags: (@Sendable () async -> Void)?
        var activeTagsResult: Set<WebhookTaskTag> = []
    }

    let state = Mutex(State())

    func setCompletionHandler(_ handler: @escaping @Sendable (WebhookTransportResult) -> Void) {
        state.withLock { $0.handler = handler }
    }

    func start(tag: WebhookTaskTag, request: URLRequest, bodyFileURL: URL) {
        state.withLock { $0.started.append(tag) }
    }

    func cancel(itemID: UUID) {
        state.withLock { $0.cancelledItems.append(itemID) }
    }

    func cancel(tag: WebhookTaskTag) {
        state.withLock { $0.cancelledTags.append(tag) }
    }

    func activeTags() async -> Set<WebhookTaskTag> {
        let (hook, result) = state.withLock { ($0.duringActiveTags, $0.activeTagsResult) }
        await hook?()
        return result
    }

    func complete(_ tag: WebhookTaskTag, statusCode: Int, retryAfter: String? = nil) {
        let handler = state.withLock { $0.handler }
        handler?(WebhookTransportResult(
            tag: tag, statusCode: statusCode, retryAfter: retryAfter, errorCode: nil, errorDescription: nil
        ))
    }
}

/// Records background-time requests instead of asking UIKit.
@MainActor
final class FakeBackgroundTaskService: BackgroundTaskService {
    private(set) var begun: [UInt] = []
    private(set) var ended: [UInt] = []
    private(set) var expirationHandlers: [UInt: @Sendable () -> Void] = [:]
    private var nextID: UInt = 1

    var active: Set<UInt> { Set(begun).subtracting(ended) }

    func beginBackgroundTask(name: String, onExpiration: @escaping @Sendable () -> Void) -> UInt? {
        defer { nextID += 1 }
        begun.append(nextID)
        expirationHandlers[nextID] = onExpiration
        return nextID
    }

    func endBackgroundTask(_ identifier: UInt) {
        ended.append(identifier)
    }
}

@MainActor
@Suite(.serialized)
final class WebhookDeliveryRaceTests {
    private let directory = URL.temporaryDirectory.appending(path: "WebhookRaceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let fake = FakeWebhookTransport()
    private let backgroundTasks = FakeBackgroundTaskService()
    private let store: WebhookStore
    private let service: WebhookDeliveryService

    /// Real time plus a skew the tests can advance.
    private nonisolated final class Clock: @unchecked Sendable {
        var skew: TimeInterval = 0
        var now: Date { Date().addingTimeInterval(skew) }
    }
    private let clock = Clock()

    init() {
        store = WebhookStore(
            defaults: UserDefaults(suiteName: "WebhookDeliveryRaceTests-\(UUID().uuidString)")!,
            keychain: MockKeychainService()
        )
        let fake = fake
        let clock = clock
        service = WebhookDeliveryService(
            store: store,
            storage: WebhookOutboxStorage(directory: directory),
            makeTransport: { fake },
            backgroundTasks: backgroundTasks,
            now: { clock.now },
            appVersion: "9.9.9"
        )
    }

    private func waitUntil(_ condition: () -> Bool, timeout: Duration = .seconds(5)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func enqueueOne() throws -> UUID {
        let webhook = WebhookDefinition(name: "Meetings", url: URL(string: "https://example.com/hooks/meetings")!)
        try store.save(webhook, token: .keep)
        let input = WebhookPayloadInput(
            transcriptionID: UUID(), text: "raw", enhancedText: nil, modeName: "Meeting",
            timestamp: Date(), audioDuration: 1, language: nil, sourceTag: "app",
            transcriptionModelName: nil, aiModelName: nil
        )
        let itemID = try #require(service.enqueue(input, to: webhook))
        return itemID
    }

    @Test func resume_doesNotRestartAnAttemptStartedWhileItAwaitedTheTaskList() async throws {
        let itemID = try enqueueOne()
        let first = WebhookTaskTag(itemID: itemID, attempt: 1)
        #expect(fake.state.withLock { $0.started } == [first])

        // While resume() awaits the task list, attempt 1 fails with a 503 and,
        // its backoff already over, the service starts attempt 2. The list
        // (taken earlier) contains neither.
        let fake = fake
        let clock = clock
        let service = service
        fake.state.withLock {
            $0.duringActiveTags = {
                fake.complete(first, statusCode: 503)
                try? await Task.sleep(for: .milliseconds(200))
                clock.skew += WebhookRetryPolicy.backoff(afterFailedAttempts: 1)
                await service.pump()
            }
        }

        await service.resume()

        let started = fake.state.withLock { $0.started }
        #expect(started == [first, WebhookTaskTag(itemID: itemID, attempt: 2)])
        #expect(service.items.first?.isInFlight == true)
    }

    @Test func inFlightUpload_holdsBackgroundTimeUntilItCompletes() async throws {
        let itemID = try enqueueOne()
        #expect(backgroundTasks.active.count == 1)

        fake.complete(WebhookTaskTag(itemID: itemID, attempt: 1), statusCode: 200)
        try await waitUntil { service.items.isEmpty }

        #expect(backgroundTasks.active.isEmpty)
        #expect(backgroundTasks.begun.count == 1)
        #expect(service.backgroundTaskID == nil)
    }

    @Test func expiredBackgroundTime_isReleased_andTheItemStaysPending() async throws {
        _ = try enqueueOne()
        let id = try #require(backgroundTasks.begun.first)

        backgroundTasks.expirationHandlers[id]?()
        try await waitUntil { service.backgroundTaskID == nil }

        #expect(backgroundTasks.active.isEmpty)
        #expect(service.items.first?.isInFlight == true)
    }

    @Test func dueRetry_startsOnItsOwn_whileTheAppRuns() async throws {
        let itemID = try enqueueOne()

        fake.complete(WebhookTaskTag(itemID: itemID, attempt: 1), statusCode: 503, retryAfter: "1")
        try await waitUntil { service.items.first?.isInFlight == false }
        #expect(fake.state.withLock { $0.started.count } == 1)
        // Nothing waits on an upload, so no background time is held.
        #expect(backgroundTasks.active.isEmpty)

        // No pump(), resume() or new send: the retry timer starts attempt 2.
        try await waitUntil { fake.state.withLock { $0.started.count } == 2 }
        #expect(fake.state.withLock { $0.started.last } == WebhookTaskTag(itemID: itemID, attempt: 2))
        #expect(backgroundTasks.active.count == 1)
    }

    @Test func rearm_cancelsOnlyTheOldAttempt() throws {
        let itemID = try enqueueOne()

        service.rearmItems(forWebhook: try #require(store.webhooks.first).id)

        let state = fake.state.withLock { $0 }
        #expect(state.cancelledTags == [WebhookTaskTag(itemID: itemID, attempt: 1)])
        #expect(state.cancelledItems.isEmpty)
        #expect(state.started.last == WebhookTaskTag(itemID: itemID, attempt: 2))
    }
}

@MainActor
struct WebhookStoreTests {

    @Test func token_isKeptInTheKeychainNotUserDefaults() throws {
        let suite = "WebhookStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let keychain = MockKeychainService()
        let store = WebhookStore(defaults: defaults, keychain: keychain)
        let webhook = WebhookDefinition(name: "Thoughts", url: URL(string: "https://example.com/hooks/thoughts")!)

        try store.save(webhook, token: .set("top-secret"))

        #expect(store.token(for: webhook.id) == "top-secret")
        #expect(store.webhook(id: webhook.id)?.hasBearerToken == true)
        let stored = try #require(defaults.data(forKey: "webhookDefinitions_v1"))
        #expect(String(decoding: stored, as: UTF8.self).contains("top-secret") == false)

        // Reloading from the same defaults keeps the definition.
        let reloaded = WebhookStore(defaults: defaults, keychain: keychain)
        #expect(reloaded.webhook(id: webhook.id)?.name == "Thoughts")

        store.delete(id: webhook.id)
        #expect(store.token(for: webhook.id) == nil)
        #expect(store.webhooks.isEmpty)
    }

    @Test func keepTokenChange_preservesTheSavedToken() throws {
        let defaults = try #require(UserDefaults(suiteName: "WebhookStoreTests-\(UUID().uuidString)"))
        let store = WebhookStore(defaults: defaults, keychain: MockKeychainService())
        var webhook = WebhookDefinition(name: "A", url: URL(string: "https://example.com/hooks/a")!)
        try store.save(webhook, token: .set("t"))

        webhook.name = "B"
        try store.save(webhook, token: .keep)
        #expect(store.webhook(id: webhook.id)?.hasBearerToken == true)
        #expect(store.token(for: webhook.id) == "t")

        try store.save(webhook, token: .remove)
        #expect(store.webhook(id: webhook.id)?.hasBearerToken == false)
        #expect(store.token(for: webhook.id) == nil)
    }
}
