//
//  ReminderExtractionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation
import SwiftData
import os

enum ReminderExtractionError: LocalizedError {
    case unsupportedOS
    case noExtractorAvailable
    case providerUnavailable(String)
    case appleFoundationModelUnavailable
    case appleGuardrailViolation
    case appleRefusal
    case extractionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "This reminder extraction option is not available on the current OS version."
        case .noExtractorAvailable:
            return "No reminder extraction model is available for the current mode."
        case .providerUnavailable(let message):
            return message
        case .appleFoundationModelUnavailable:
            return "Apple Intelligence is not available on this device right now."
        case .appleGuardrailViolation:
            return "Apple Intelligence blocked this reminder extraction request due to safety guardrails."
        case .appleRefusal:
            return "Apple Intelligence declined to extract reminders from this note."
        case .extractionFailed(let message):
            return "Reminder extraction failed: \(message)"
        case .invalidResponse:
            return "The reminder extraction response could not be parsed."
        }
    }
}

private enum ReminderExtractionBackend {
    case apple
    case cloud(provider: AIProvider, model: String)
}

@MainActor
final class ReminderExtractionService {
    private let logger = Logger(category: .reminderExtraction)
    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    func canExtractReminders(using mode: VivaMode? = nil) -> Bool {
        resolvedBackend(for: mode ?? aiService.selectedMode) != nil
    }

    func extractAndPersist(
        for transcription: Transcription,
        modelContext: ModelContext,
        mode: VivaMode? = nil
    ) async throws -> [ExtractedReminderDraft] {
        let activeMode = mode ?? aiService.selectedMode
        guard let backend = resolvedBackend(for: activeMode) else {
            throw ReminderExtractionError.noExtractorAvailable
        }

        let now = Date()
        let timeZone = TimeZone.current
        let response: ReminderDraftsResponse

        switch backend {
        case .apple:
            guard #available(iOS 26, *) else {
                throw ReminderExtractionError.unsupportedOS
            }
            response = try await AppleFMReminderExtractionProvider().extract(
                noteText: transcription.text,
                now: now,
                timeZone: timeZone
            )
        case .cloud(let provider, let model):
            response = try await CloudReminderExtractionProvider(aiService: aiService).extract(
                noteText: transcription.text,
                provider: provider,
                model: model,
                now: now,
                timeZone: timeZone
            )
        }

        let persistedDrafts = persist(
            response.reminders,
            on: transcription,
            backend: backend,
            modelContext: modelContext
        )

        try modelContext.save()
        logger.logNotice("Reminder extraction - Persisted \(persistedDrafts.count) draft(s) for note \(transcription.id.uuidString)")
        return persistedDrafts
    }

    private func resolvedBackend(for mode: VivaMode) -> ReminderExtractionBackend? {
        let cloudProvider = CloudReminderExtractionProvider(aiService: aiService)

        if mode.reminderExtractorProvider != nil {
            return backend(
                for: mode.reminderExtractorProvider,
                model: mode.reminderExtractorModel,
                cloudProvider: cloudProvider
            )
        }

        if let backend = backend(
            for: mode.aiProvider,
            model: mode.aiModel,
            cloudProvider: cloudProvider
        ) {
            return backend
        }

        if AppleFoundationModelAvailability.isAvailable {
            return .apple
        }

        return nil
    }

    private func backend(
        for provider: AIProvider?,
        model: String?,
        cloudProvider: CloudReminderExtractionProvider
    ) -> ReminderExtractionBackend? {
        guard let provider else { return nil }

        if provider == .apple {
            return AppleFoundationModelAvailability.isAvailable ? .apple : nil
        }

        guard let model, !model.isEmpty else { return nil }

        if cloudProvider.canExtract(provider: provider, model: model) {
            return .cloud(provider: provider, model: model)
        }

        return nil
    }

    private func persist(
        _ drafts: [ReminderDraft],
        on transcription: Transcription,
        backend: ReminderExtractionBackend,
        modelContext: ModelContext
    ) -> [ExtractedReminderDraft] {
        let existingDrafts = transcription.sortedExtractedReminderDrafts
        let importedDrafts = existingDrafts.filter { $0.status == .imported }

        existingDrafts
            .filter { $0.status != .imported }
            .forEach { modelContext.delete($0) }

        let providerName: String?
        let modelName: String?
        switch backend {
        case .apple:
            providerName = AIProvider.apple.displayName
            modelName = AIProvider.apple.defaultModel
        case .cloud(let provider, let model):
            providerName = provider.displayName
            modelName = model
        }

        var seenKeys = Set<String>()
        var persistedDrafts: [ExtractedReminderDraft] = []

        for draft in drafts {
            let normalizedDraftTitle = normalizedTitle(for: draft.title)
            guard !normalizedDraftTitle.isEmpty else { continue }

            let dedupeKey = draftKey(title: normalizedDraftTitle, dueDateString: draft.optionalDueDateString)
            guard !seenKeys.contains(dedupeKey) else { continue }
            seenKeys.insert(dedupeKey)

            let alreadyImported = importedDrafts.contains {
                draftKey(
                    title: normalizedTitle(for: $0.title),
                    dueDateString: $0.optionalDueDateString
                ) == dedupeKey
            }

            guard !alreadyImported else { continue }

            let storedDraft = ExtractedReminderDraft()
            storedDraft.update(
                from: draft,
                providerName: providerName,
                modelName: modelName
            )
            storedDraft.transcription = transcription
            modelContext.insert(storedDraft)
            persistedDrafts.append(storedDraft)
        }

        return persistedDrafts
    }

    private func normalizedTitle(for title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func draftKey(title: String, dueDateString: String?) -> String {
        "\(title)|\(dueDateString ?? "")"
    }
}
