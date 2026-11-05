//
//  WebhookEditViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import Foundation
import Observation
import os

/// Form state for adding or editing one webhook, including the "Send test" call.
@MainActor
@Observable
final class WebhookEditViewModel {
    enum TestState: Equatable {
        case idle
        case sending
        case finished(statusCode: Int, body: String)
        case failed(String)
    }

    var name: String
    var urlString: String
    var isEnabled: Bool
    /// New token typed by the user. Empty keeps the saved one (if any).
    var tokenInput: String = ""
    /// The user asked to remove the saved token.
    var removesSavedToken = false
    private(set) var testState: TestState = .idle
    private(set) var saveError: String?

    let original: WebhookDefinition?

    @ObservationIgnored private let store: WebhookStore
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let appVersion: String?
    @ObservationIgnored private let logger = Logger(category: .webhooks)

    /// Longest response body shown after a test send.
    static let maxPreviewLength = 500

    init(webhook: WebhookDefinition?,
         store: WebhookStore? = nil,
         session: URLSession = .shared,
         appVersion: String? = WebhookPayloadBuilder.currentAppVersion) {
        original = webhook
        name = webhook?.name ?? ""
        urlString = webhook?.url.absoluteString ?? ""
        isEnabled = webhook?.isEnabled ?? true
        self.store = store ?? .shared
        self.session = session
        self.appVersion = appVersion
    }

    var isEditing: Bool { original != nil }

    var hasSavedToken: Bool {
        (original?.hasBearerToken ?? false) && !removesSavedToken
    }

    var urlValidation: Result<URL, WebhookURLValidationError> {
        WebhookURLValidator.validate(urlString)
    }

    /// Validation message to show under the URL field, once the user typed something.
    var urlErrorMessage: String? {
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if case .failure(let error) = urlValidation { return error.message }
        return nil
    }

    var canSave: Bool {
        if case .success = urlValidation { return true }
        return false
    }

    var lastStatus: WebhookDeliveryStatus? {
        original.flatMap { store.statuses[$0.id] }
    }

    /// Saves the webhook. Returns `false` and sets ``saveError`` on failure.
    func save() -> Bool {
        guard case .success(let url) = urlValidation else { return false }
        let webhook = WebhookDefinition(
            id: original?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            isEnabled: isEnabled,
            hasBearerToken: original?.hasBearerToken ?? false
        )
        let change: WebhookStore.TokenChange
        let typedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typedToken.isEmpty {
            change = .set(typedToken)
        } else if removesSavedToken {
            change = .remove
        } else {
            change = .keep
        }
        do {
            try store.save(webhook, token: change)
            if original?.isEnabled == true && !isEnabled {
                WebhookDeliveryService.shared.discardItems(forWebhook: webhook.id)
            } else if let original, original.url != url || change != .keep {
                WebhookDeliveryService.shared.rearmItems(forWebhook: webhook.id)
            }
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    func delete() {
        guard let original else { return }
        store.delete(id: original.id)
    }

    /// POSTs a sample payload to the URL and token currently in the form
    /// (not the saved ones), so the user can test before saving.
    func sendTest() async {
        guard case .success(let url) = urlValidation else {
            testState = .failed(urlErrorMessage ?? "Enter a valid https URL.")
            return
        }
        testState = .sending

        let typedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let token: String?
        if !typedToken.isEmpty {
            token = typedToken
        } else if hasSavedToken, let original {
            token = store.token(for: original.id)
        } else {
            token = nil
        }

        let payload = WebhookPayloadBuilder.testPayload(appVersion: appVersion)
        do {
            let body = try WebhookPayloadBuilder.encode(payload)
            let request = WebhookRequestBuilder.request(
                url: url,
                bearerToken: token,
                idempotencyKey: payload.id,
                appVersion: appVersion
            )
            let (data, response) = try await session.upload(for: request, from: body)
            guard let http = response as? HTTPURLResponse else {
                testState = .failed("No HTTP response")
                return
            }
            testState = .finished(statusCode: http.statusCode, body: Self.preview(of: data))
            logger.logInfo("🪝 Test send finished with HTTP \(http.statusCode)")
        } catch {
            testState = .failed(error.localizedDescription)
            logger.logInfo("🪝 Test send failed: \(error.localizedDescription)")
        }
    }

    static func preview(of data: Data) -> String {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > maxPreviewLength else { return text }
        return String(text.prefix(maxPreviewLength)) + "…"
    }
}
