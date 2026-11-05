//
//  WebhookDeliveryService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import os

/// Delivers finished transcriptions to webhooks through a persistent outbox.
///
/// Every send is written to disk first (index + body file), then uploaded by a
/// ``WebhookTransport`` - in production a background `URLSession`, so an
/// upload that starts as the app gets suspended still completes. Failed
/// attempts are retried per ``WebhookRetryPolicy``; retries are scheduled as
/// upload tasks with an `earliestBeginDate`, so they also run while the app is
/// not. Pending items are reconciled on launch and on foreground.
///
/// Nothing here throws to callers or blocks them: a failing webhook never
/// delays transcription, the Obsidian hand-off or folder export.
@MainActor
final class WebhookDeliveryService {
    static let shared = WebhookDeliveryService()

    /// What a manual send reports back to the UI.
    enum ManualSendResult: Equatable {
        case delivered(statusCode: Int)
        case failed(String)
        /// Not delivered yet; the outbox keeps retrying in the background.
        case queued(String?)
    }

    /// How long a manual send waits for the first attempt before reporting `.queued`.
    static let manualSendWaitTimeout: Duration = .seconds(30)

    private(set) var items: [WebhookOutboxItem] = []

    private let store: WebhookStore
    private let storage: WebhookOutboxStorage
    private let makeTransport: () -> any WebhookTransport
    private let now: () -> Date
    private let appVersion: String?
    private let logger = Logger(category: .webhooks)

    private var transport: (any WebhookTransport)?
    private var isLoaded = false
    private var backgroundCompletionHandlers: [() -> Void] = []
    private var manualWaiters: [UUID: CheckedContinuation<ManualSendResult, Never>] = [:]

    init(
        store: WebhookStore? = nil,
        storage: WebhookOutboxStorage = WebhookOutboxStorage(),
        makeTransport: @escaping () -> any WebhookTransport = { URLSessionWebhookTransport.makeBackground() },
        now: @escaping () -> Date = { Date() },
        appVersion: String? = WebhookPayloadBuilder.currentAppVersion
    ) {
        self.store = store ?? .shared
        self.storage = storage
        self.makeTransport = makeTransport
        self.now = now
        self.appVersion = appVersion
    }

    // MARK: - Lifecycle

    /// Recreates the background session (so it receives pending events) and
    /// resumes pending items. Safe to call repeatedly.
    func activate() {
        Task { await resume() }
    }

    /// Called from `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
        backgroundCompletionHandlers.append(completionHandler)
        _ = ensureTransport()
    }

    /// Re-arms items whose upload task no longer exists, drops expired ones and
    /// starts everything that is due.
    func resume() async {
        loadIfNeeded()
        // Nothing pending: no need to spin up the background session. A relaunch
        // for background events creates it in `handleBackgroundEvents`.
        guard !items.isEmpty, let transport = ensureTransport() else { return }
        // Snapshot the attempts in flight *before* awaiting the task list. A
        // completion handled during the await can start a newer attempt that
        // the list predates; only attempts that are still unchanged afterwards
        // may be judged lost, or the same body would be uploaded twice.
        let inFlightSnapshot = Dictionary(
            uniqueKeysWithValues: items.filter(\.isInFlight).map { ($0.id, $0.attempts) }
        )
        if !inFlightSnapshot.isEmpty {
            let active = await transport.activeTags()
            for index in items.indices {
                let item = items[index]
                guard item.isInFlight,
                      inFlightSnapshot[item.id] == item.attempts,
                      !active.contains(WebhookTaskTag(itemID: item.id, attempt: item.attempts)) else { continue }
                logger.logInfo("🪝 Re-arming outbox item \(item.id.uuidString.prefix(8)) - its upload task is gone")
                items[index].isInFlight = false
            }
        }
        persist()
        pump()
    }

    // MARK: - Sending

    /// Queues the transcription for the mode's webhook, if the mode has an enabled one.
    func enqueueIfEnabled(transcription: Transcription, mode: VivaMode, languageOverride: String? = nil) {
        guard let webhookID = mode.webhookID else { return }
        guard let webhook = store.webhook(id: webhookID), webhook.isEnabled else {
            logger.logInfo("🪝 Mode '\(mode.name)' points at a missing or disabled webhook - skipping")
            return
        }
        let input = WebhookPayloadBuilder.input(
            for: transcription,
            modeName: mode.name,
            language: languageOverride ?? mode.transcriptionLanguage
        )
        enqueue(input, to: webhook)
    }

    /// Sends on the user's request and waits briefly for the first attempt.
    /// A re-send reuses the transcription ID, so receivers can deduplicate.
    func sendManually(_ input: WebhookPayloadInput, to webhook: WebhookDefinition) async -> ManualSendResult {
        guard let itemID = enqueue(input, to: webhook, startImmediately: false) else {
            return .failed("Could not prepare the request.")
        }
        return await withCheckedContinuation { continuation in
            manualWaiters[itemID] = continuation
            pump()
            Task { [weak self] in
                try? await Task.sleep(for: Self.manualSendWaitTimeout)
                self?.resolveWaiter(for: itemID, with: .queued(nil))
            }
        }
    }

    /// Writes the payload to the outbox and starts delivery. Returns the item ID.
    @discardableResult
    func enqueue(_ input: WebhookPayloadInput, to webhook: WebhookDefinition, startImmediately: Bool = true) -> UUID? {
        loadIfNeeded()
        let payload = WebhookPayloadBuilder.payload(for: input, appVersion: appVersion)
        let body: Data
        do {
            body = try WebhookPayloadBuilder.encode(payload)
        } catch {
            logger.logError("🪝 Failed to encode payload: \(error.localizedDescription)")
            return nil
        }

        // A newer send of the same note to the same webhook supersedes a pending one.
        for stale in items where stale.webhookID == webhook.id && stale.transcriptionID == input.transcriptionID {
            discard(stale)
        }

        let createdAt = now()
        let item = WebhookOutboxItem(
            id: UUID(),
            webhookID: webhook.id,
            transcriptionID: input.transcriptionID,
            createdAt: createdAt,
            attempts: 0,
            nextAttemptAt: createdAt,
            isInFlight: false,
            lastError: nil
        )
        do {
            try storage.writeBody(body, for: item.id)
        } catch {
            logger.logError("🪝 Failed to write outbox body: \(error.localizedDescription)")
            return nil
        }
        items.append(item)
        persist()
        logger.logInfo("🪝 Queued note \(input.transcriptionID.uuidString.prefix(8)) for '\(webhook.displayName)' (\(body.count) bytes)")
        if startImmediately {
            pump()
        }
        return item.id
    }

    /// Restarts pending items of a webhook whose URL or token just changed, so a
    /// retry that was already scheduled does not go out with the old values.
    func rearmItems(forWebhook webhookID: UUID) {
        loadIfNeeded()
        let currentDate = now()
        for index in items.indices where items[index].webhookID == webhookID {
            if items[index].isInFlight {
                // Cancel exactly the old attempt: cancellation is asynchronous,
                // and the pump below starts a newer attempt of the same item.
                transport?.cancel(tag: WebhookTaskTag(itemID: items[index].id, attempt: items[index].attempts))
                items[index].isInFlight = false
            }
            items[index].nextAttemptAt = currentDate
        }
        persist()
        pump()
    }

    /// Drops every pending item for a webhook (it was deleted or disabled).
    func discardItems(forWebhook webhookID: UUID) {
        loadIfNeeded()
        for item in items where item.webhookID == webhookID {
            discard(item)
        }
        persist()
    }

    // MARK: - Delivery

    /// Starts an upload for every pending item that may go out now.
    func pump() {
        loadIfNeeded()
        guard let transport = ensureTransport() else { return }
        let currentDate = now()

        for item in items where !item.isInFlight {
            guard let webhook = store.webhook(id: item.webhookID), webhook.isEnabled else {
                logger.logInfo("🪝 Dropping outbox item for a missing or disabled webhook")
                discard(item)
                continue
            }
            if WebhookRetryPolicy.isExpired(createdAt: item.createdAt, now: currentDate) {
                giveUp(item, reason: Self.expiredReason(lastError: item.lastError), statusCode: nil)
                continue
            }
            guard storage.bodyExists(for: item.id) else {
                logger.logError("🪝 Outbox body missing - dropping item")
                discard(item)
                continue
            }
            if !transport.supportsDeferredStart && item.nextAttemptAt > currentDate {
                continue
            }

            var token: String?
            if webhook.hasBearerToken {
                guard let storedToken = store.token(for: webhook.id) else {
                    // Most likely the Keychain is locked. Never send without the token; try on the next resume.
                    logger.logInfo("🪝 Token for '\(webhook.displayName)' unavailable - waiting")
                    continue
                }
                token = storedToken
            }

            let request = WebhookRequestBuilder.request(
                url: webhook.url,
                bearerToken: token,
                idempotencyKey: item.transcriptionID.uuidString,
                appVersion: appVersion
            )
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { continue }
            let beginDate = item.nextAttemptAt > currentDate ? item.nextAttemptAt : nil
            items[index].isInFlight = true
            items[index].attempts += 1
            transport.start(
                tag: WebhookTaskTag(itemID: item.id, attempt: items[index].attempts),
                request: request,
                bodyFileURL: storage.bodyURL(for: item.id),
                earliestBeginDate: beginDate
            )
            logger.logInfo("🪝 Attempt \(items[index].attempts) to '\(webhook.displayName)'\(beginDate.map { " at \($0.formatted(.iso8601))" } ?? "")")
        }
        persist()
    }

    func handle(_ event: WebhookTransportEvent) {
        switch event {
        case .finishedBackgroundEvents:
            let handlers = backgroundCompletionHandlers
            backgroundCompletionHandlers.removeAll()
            handlers.forEach { $0() }
        case .completed(let result):
            handle(result)
        }
    }

    private func handle(_ result: WebhookTransportResult) {
        loadIfNeeded()
        // Unknown, not in flight, or an older attempt: the item was discarded,
        // superseded or re-armed, and this completion is stale.
        guard let index = items.firstIndex(where: { $0.id == result.tag.itemID }),
              items[index].isInFlight,
              items[index].attempts == result.tag.attempt else { return }
        var item = items[index]
        item.isInFlight = false
        let currentDate = now()

        let decision = WebhookRetryPolicy.decide(
            statusCode: result.statusCode,
            retryAfter: result.retryAfter,
            errorCode: result.errorCode,
            errorDescription: result.errorDescription,
            failedAttempts: item.attempts,
            now: currentDate
        )

        switch decision {
        case .delivered(let statusCode):
            remove(item)
            store.recordStatus(
                WebhookDeliveryStatus(outcome: .delivered, date: currentDate, statusCode: statusCode, message: nil),
                for: item.webhookID
            )
            logger.logInfo("🪝 Delivered note \(item.transcriptionID.uuidString.prefix(8)) (HTTP \(statusCode))")
            resolveWaiter(for: item.id, with: .delivered(statusCode: statusCode))

        case .retry(let delay, let reason):
            let nextAttempt = currentDate.addingTimeInterval(delay)
            if nextAttempt.timeIntervalSince(item.createdAt) >= WebhookRetryPolicy.maxAge {
                giveUp(item, reason: Self.expiredReason(lastError: reason), statusCode: result.statusCode)
            } else {
                item.nextAttemptAt = nextAttempt
                item.lastError = reason
                items[index] = item
                store.recordStatus(
                    WebhookDeliveryStatus(outcome: .retrying, date: currentDate, statusCode: result.statusCode, message: reason),
                    for: item.webhookID
                )
                logger.logInfo("🪝 Attempt \(item.attempts) failed (\(reason)) - retrying in \(Int(delay))s")
                resolveWaiter(for: item.id, with: .queued(reason))
            }

        case .giveUp(let reason):
            giveUp(item, reason: reason, statusCode: result.statusCode)
        }

        persist()
        pump()
    }

    // MARK: - Helpers

    private func giveUp(_ item: WebhookOutboxItem, reason: String, statusCode: Int?) {
        remove(item)
        store.recordStatus(
            WebhookDeliveryStatus(outcome: .failed, date: now(), statusCode: statusCode, message: reason),
            for: item.webhookID
        )
        logger.logError("🪝 Gave up on note \(item.transcriptionID.uuidString.prefix(8)): \(reason)")
        resolveWaiter(for: item.id, with: .failed(reason))
    }

    private func discard(_ item: WebhookOutboxItem) {
        if item.isInFlight {
            transport?.cancel(itemID: item.id)
        }
        remove(item)
        resolveWaiter(for: item.id, with: .queued(nil))
    }

    private func remove(_ item: WebhookOutboxItem) {
        items.removeAll { $0.id == item.id }
        storage.removeBody(for: item.id)
    }

    private func resolveWaiter(for itemID: UUID, with result: ManualSendResult) {
        guard let continuation = manualWaiters.removeValue(forKey: itemID) else { return }
        continuation.resume(returning: result)
    }

    private static func expiredReason(lastError: String?) -> String {
        let hours = Int(WebhookRetryPolicy.maxAge / 3600)
        guard let lastError else { return "Gave up after \(hours) hours" }
        return "Gave up after \(hours) hours: \(lastError)"
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        items = storage.loadItems()
    }

    private func ensureTransport() -> (any WebhookTransport)? {
        if let transport { return transport }
        let created = makeTransport()
        created.setEventHandler { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        transport = created
        return created
    }

    private func persist() {
        do {
            try storage.saveItems(items)
        } catch {
            logger.logError("🪝 Failed to persist outbox: \(error.localizedDescription)")
        }
    }
}
