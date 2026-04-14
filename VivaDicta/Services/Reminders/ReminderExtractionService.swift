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

        logger.logInfo(
            "Reminder extraction - Start noteId=\(transcription.id.uuidString) backend=\(backendDescription(backend)) text='\(preview(transcription.text))'"
        )

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

        logDrafts(
            response.reminders,
            prefix: "Reminder extraction - Raw model output noteId=\(transcription.id.uuidString)"
        )

        let persistedDrafts = persist(
            response.reminders,
            on: transcription,
            backend: backend,
            modelContext: modelContext,
            now: now,
            timeZone: timeZone
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
        modelContext: ModelContext,
        now: Date,
        timeZone: TimeZone
    ) -> [ExtractedReminderDraft] {
        let existingDrafts = reminderDrafts(for: transcription, modelContext: modelContext)
        let importedDrafts = existingDrafts.filter { $0.status == .imported }
        logger.logInfo(
            "Reminder extraction - Existing drafts before replace noteId=\(transcription.id.uuidString) count=\(existingDrafts.count) imported=\(importedDrafts.count)"
        )
        logStoredDrafts(
            existingDrafts,
            prefix: "Reminder extraction - Existing draft snapshot noteId=\(transcription.id.uuidString)"
        )

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

        let sanitizedDrafts = sanitizeDrafts(drafts, now: now, timeZone: timeZone)
        logDrafts(
            sanitizedDrafts,
            prefix: "Reminder extraction - Sanitized drafts noteId=\(transcription.id.uuidString)"
        )
        var seenKeys = Set<String>()
        var persistedDrafts: [ExtractedReminderDraft] = []

        for draft in sanitizedDrafts {
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
            logger.logInfo(
                "Reminder extraction - Persisting draft noteId=\(transcription.id.uuidString) draftId=\(storedDraft.id.uuidString) title='\(storedDraft.title)' due='\(storedDraft.optionalDueDateString ?? "nil")' raw='\(storedDraft.rawDueDatePhrase ?? "nil")'"
            )
        }

        return persistedDrafts
    }

    private func reminderDrafts(
        for transcription: Transcription,
        modelContext: ModelContext
    ) -> [ExtractedReminderDraft] {
        let descriptor = FetchDescriptor<ExtractedReminderDraft>(
            sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]
        )
        let allDrafts = (try? modelContext.fetch(descriptor)) ?? []
        logger.logDebug(
            "Reminder extraction - Fetch all drafts total=\(allDrafts.count) targetNoteId=\(transcription.id.uuidString)"
        )
        logStoredDrafts(
            allDrafts,
            prefix: "Reminder extraction - All stored drafts before note filter"
        )
        let filteredDrafts = allDrafts.filter { $0.transcription?.id == transcription.id }
        logStoredDrafts(
            filteredDrafts,
            prefix: "Reminder extraction - Filtered stored drafts targetNoteId=\(transcription.id.uuidString)"
        )
        return filteredDrafts
    }

    private func sanitizeDrafts(
        _ drafts: [ReminderDraft],
        now: Date,
        timeZone: TimeZone
    ) -> [ReminderDraft] {
        var mergedDrafts: [ReminderDraft] = []

        for draft in drafts {
            let normalizedCandidate = normalizedDraft(draft, now: now, timeZone: timeZone)
            guard shouldKeepDraft(normalizedCandidate) else { continue }

            let normalizedCandidateTitle = normalizedTitle(for: normalizedCandidate.title)
            guard !normalizedCandidateTitle.isEmpty else { continue }

            if let existingIndex = mergedDrafts.firstIndex(where: {
                normalizedTitle(for: $0.title) == normalizedCandidateTitle
            }) {
                let existingDraft = mergedDrafts[existingIndex]
                let shouldMerge = existingDraft.optionalDueDateString == normalizedCandidate.optionalDueDateString
                    || existingDraft.optionalDueDateString == nil
                    || normalizedCandidate.optionalDueDateString == nil
                    || normalizedTitle(for: existingDraft.rawDueDatePhrase ?? "") == normalizedTitle(for: normalizedCandidate.rawDueDatePhrase ?? "")

                if shouldMerge {
                    mergedDrafts[existingIndex] = mergedDraft(existingDraft, with: normalizedCandidate)
                    continue
                }
            }

            mergedDrafts.append(normalizedCandidate)
        }

        return mergedDrafts
    }

    private func shouldKeepDraft(_ draft: ReminderDraft) -> Bool {
        let normalizedDraftTitle = normalizedTitle(for: draft.title)
        guard !normalizedDraftTitle.isEmpty else { return false }

        let normalizedDuePhrase = normalizedTitle(for: draft.rawDueDatePhrase ?? "")
        if !normalizedDuePhrase.isEmpty && normalizedDraftTitle == normalizedDuePhrase {
            return false
        }

        return likelyTimingOnlyTitle(draft.title) == false
    }

    private func normalizedDraft(
        _ draft: ReminderDraft,
        now: Date,
        timeZone: TimeZone
    ) -> ReminderDraft {
        let recoveredTitleData = ReminderDueDateParser.splitEmbeddedDuePhrase(
            from: draft.title,
            now: now,
            timeZone: timeZone
        )

        return ReminderDraft(
            title: recoveredTitleData.cleanTitle,
            optionalDueDateString: normalizedOptionalString(draft.optionalDueDateString) ?? recoveredTitleData.dueDateString,
            rawDueDatePhrase: normalizedOptionalString(draft.rawDueDatePhrase) ?? recoveredTitleData.rawDueDatePhrase,
            notes: normalizedOptionalString(draft.notes),
            priority: draft.priority
        )
    }

    private func mergedDraft(_ lhs: ReminderDraft, with rhs: ReminderDraft) -> ReminderDraft {
        let preferred = draftScore(lhs) >= draftScore(rhs) ? lhs : rhs
        let secondary = preferred.title == lhs.title
            && preferred.optionalDueDateString == lhs.optionalDueDateString
            && preferred.rawDueDatePhrase == lhs.rawDueDatePhrase
            && preferred.notes == lhs.notes
            && preferred.priority == lhs.priority ? rhs : lhs

        return ReminderDraft(
            title: preferred.title,
            optionalDueDateString: preferred.optionalDueDateString ?? secondary.optionalDueDateString,
            rawDueDatePhrase: preferred.rawDueDatePhrase ?? secondary.rawDueDatePhrase,
            notes: preferred.notes ?? secondary.notes,
            priority: mergedPriority(preferred.priority, secondary.priority)
        )
    }

    private func draftScore(_ draft: ReminderDraft) -> Int {
        var score = 0
        if normalizedOptionalString(draft.optionalDueDateString) != nil { score += 4 }
        if normalizedOptionalString(draft.rawDueDatePhrase) != nil { score += 2 }
        if normalizedOptionalString(draft.notes) != nil { score += 2 }
        if draft.priority != .none { score += 1 }
        score += draft.title.count / 20
        return score
    }

    private func normalizedTitle(for title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func likelyTimingOnlyTitle(_ title: String) -> Bool {
        let normalized = normalizedTitle(for: title)
        guard !normalized.isEmpty else { return false }

        let dateWords = [
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "today", "tomorrow", "tonight", "morning", "afternoon", "evening", "noon"
        ]

        let containsDateWord = dateWords.contains { normalized.contains($0) }
        let containsTimeMarker = normalized.contains("am") || normalized.contains("pm") || normalized.contains(":")

        guard containsDateWord else { return false }
        return containsTimeMarker || normalized.split(separator: " ").count <= 3
    }

    private func draftKey(title: String, dueDateString: String?) -> String {
        "\(title)|\(dueDateString ?? "")"
    }

    private func mergedPriority(_ lhs: ReminderDraftPriority, _ rhs: ReminderDraftPriority) -> ReminderDraftPriority {
        func rank(_ priority: ReminderDraftPriority) -> Int {
            switch priority {
            case .high:
                3
            case .medium:
                2
            case .low:
                1
            case .none:
                0
            }
        }

        return rank(lhs) >= rank(rhs) ? lhs : rhs
    }

    private func backendDescription(_ backend: ReminderExtractionBackend) -> String {
        switch backend {
        case .apple:
            "apple"
        case .cloud(let provider, let model):
            "\(provider.rawValue)/\(model)"
        }
    }

    private func logDrafts(_ drafts: [ReminderDraft], prefix: String) {
        if drafts.isEmpty {
            logger.logDebug("\(prefix) count=0")
            return
        }

        for (index, draft) in drafts.enumerated() {
            logger.logDebug(
                "\(prefix) [\(index)] title='\(draft.title)' due='\(draft.optionalDueDateString ?? "nil")' raw='\(draft.rawDueDatePhrase ?? "nil")' notes='\(draft.notes ?? "nil")' priority=\(draft.priority.rawValue)"
            )
        }
    }

    private func logStoredDrafts(_ drafts: [ExtractedReminderDraft], prefix: String) {
        if drafts.isEmpty {
            logger.logDebug("\(prefix) count=0")
            return
        }

        for (index, draft) in drafts.enumerated() {
            logger.logDebug(
                "\(prefix) [\(index)] draftId=\(draft.id.uuidString) noteId=\(draft.transcription?.id.uuidString ?? "nil") status=\(draft.status.rawValue) title='\(draft.title)' due='\(draft.optionalDueDateString ?? "nil")' raw='\(draft.rawDueDatePhrase ?? "nil")'"
            )
        }
    }

    private func preview(_ text: String, limit: Int = 120) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing("\n", with: " ")
        if normalized.count <= limit {
            return normalized
        }
        return String(normalized.prefix(limit)) + "..."
    }
}
