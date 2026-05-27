//
//  ReminderExtractionServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.27
//

import Foundation
import Testing
@testable import VivaDicta

/// `ReminderExtractionService.extractAndPersist` makes real cloud/Apple FM
/// calls and is out of scope for unit tests. `canExtractReminders` is the
/// public surface that gatekeeps the auto-extraction flow, and that's what
/// these tests pin down. Apple Foundation Model availability depends on
/// `SystemLanguageModel.default.availability` on the simulator, so tests
/// that would otherwise fall through to the Apple branch are excluded.
@MainActor
struct ReminderExtractionServiceTests {

    private let suiteName = "ReminderExtractionServiceTests.\(UUID().uuidString)"

    private func makeAIService() -> AIService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AIService(userDefaults: defaults)
    }

    private func makeMode(
        reminderExtractorProvider: AIProvider? = nil,
        reminderExtractorModel: String? = nil,
        aiProvider: AIProvider? = nil,
        aiModel: String = ""
    ) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "Test",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test-whisper",
            presetId: "regular",
            aiProvider: aiProvider,
            aiModel: aiModel,
            reminderExtractorProvider: reminderExtractorProvider,
            reminderExtractorModel: reminderExtractorModel,
            aiEnhanceEnabled: true
        )
    }

    // MARK: - Explicit reminder extractor provider

    @Test func canExtractReminders_returnsFalse_whenReminderExtractorRequiresKey_butNoneConnected() {
        let aiService = makeAIService()
        let sut = ReminderExtractionService(aiService: aiService)
        let mode = makeMode(reminderExtractorProvider: .openAI, reminderExtractorModel: "gpt-5")

        #expect(sut.canExtractReminders(using: mode) == false)
    }

    @Test func canExtractReminders_returnsTrue_whenReminderExtractorIsOllamaWithModel() {
        let aiService = makeAIService()
        let sut = ReminderExtractionService(aiService: aiService)
        let mode = makeMode(reminderExtractorProvider: .ollama, reminderExtractorModel: "llama3.2")

        #expect(sut.canExtractReminders(using: mode))
    }

    @Test func canExtractReminders_returnsFalse_whenReminderExtractorHasNoModel() {
        let aiService = makeAIService()
        let sut = ReminderExtractionService(aiService: aiService)
        let mode = makeMode(reminderExtractorProvider: .openAI, reminderExtractorModel: nil)

        #expect(sut.canExtractReminders(using: mode) == false)
    }

    @Test func canExtractReminders_returnsFalse_whenReminderExtractorIsCopilot() {
        // Copilot is hardcoded as unsupported for reminder extraction.
        let aiService = makeAIService()
        let sut = ReminderExtractionService(aiService: aiService)
        let mode = makeMode(reminderExtractorProvider: .copilot, reminderExtractorModel: "gpt-4o")

        #expect(sut.canExtractReminders(using: mode) == false)
    }

    // MARK: - Fallback to mode.aiProvider when no explicit reminder extractor

    @Test func canExtractReminders_fallsBackToModeAIProvider_whenNoExplicitReminderExtractor() {
        let aiService = makeAIService()
        let sut = ReminderExtractionService(aiService: aiService)
        let mode = makeMode(
            reminderExtractorProvider: nil,
            reminderExtractorModel: nil,
            aiProvider: .ollama,
            aiModel: "llama3.2"
        )

        #expect(sut.canExtractReminders(using: mode))
    }
}
