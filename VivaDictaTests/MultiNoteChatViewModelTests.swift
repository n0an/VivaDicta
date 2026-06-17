//
//  MultiNoteChatViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import SwiftData
import Testing
@testable import VivaDicta
import AICore

/// Proof-of-pattern: tests the real ``MultiNoteChatViewModel`` against a
/// hand-rolled ``MockAIChatService`` injected through ``AIChatService``.
@MainActor
struct MultiNoteChatViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: MultiNoteConversation.self, ChatMessage.self,
            configurations: config
        )
    }

    private func makeMode(provider: AIProvider?, model: String) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "TestMode",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "whisper-large",
            aiProvider: provider,
            aiModel: model,
            aiEnhanceEnabled: true
        )
    }

    private struct Fixture {
        let sut: MultiNoteChatViewModel
        let mockAIService: MockAIChatService
        let container: ModelContainer
    }

    private func makeFixture(stubMode: VivaMode = .defaultMode) throws -> Fixture {
        let container = try makeContainer()
        let conversation = MultiNoteConversation()
        container.mainContext.insert(conversation)

        let mockAIService = MockAIChatService()
        mockAIService.stubSelectedMode = stubMode

        let sut = MultiNoteChatViewModel(
            conversation: conversation,
            aiService: mockAIService,
            modelContext: container.mainContext
        )
        return Fixture(sut: sut, mockAIService: mockAIService, container: container)
    }

    @Test func selectedProvider_reflectsMockSelectedMode() throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .gemini, model: "gemini-2.5-pro")
        )
        #expect(fixture.sut.selectedProvider == .gemini)
    }

    @Test func selectedModel_returnsModelFromMockSelectedMode() throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .openAI, model: "gpt-5")
        )
        #expect(fixture.sut.selectedModel == "gpt-5")
    }

    @Test func selectedModel_isNil_whenStubModelIsEmpty() throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .anthropic, model: "")
        )
        #expect(fixture.sut.selectedModel == nil)
    }
}
