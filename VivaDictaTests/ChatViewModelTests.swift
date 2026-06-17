//
//  ChatViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import SwiftData
import Testing
@testable import VivaDicta
import AICore

/// Proof-of-pattern: tests the real ``ChatViewModel`` against a
/// hand-rolled ``MockAIChatService`` injected through ``AIChatService``.
@MainActor
struct ChatViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: ChatConversation.self, ChatMessage.self, Transcription.self,
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
        let sut: ChatViewModel
        let mockAIService: MockAIChatService
        let container: ModelContainer
    }

    private func makeFixture(stubMode: VivaMode = .defaultMode) throws -> Fixture {
        let container = try makeContainer()
        let conversation = ChatConversation()
        let transcription = Transcription(text: "Test note", audioDuration: 5)
        container.mainContext.insert(conversation)
        container.mainContext.insert(transcription)

        let mockAIService = MockAIChatService()
        mockAIService.stubSelectedMode = stubMode

        let sut = ChatViewModel(
            conversation: conversation,
            transcription: transcription,
            aiService: mockAIService,
            modelContext: container.mainContext
        )
        return Fixture(sut: sut, mockAIService: mockAIService, container: container)
    }

    @Test func selectedProvider_reflectsMockSelectedMode() throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .openAI, model: "gpt-4")
        )
        #expect(fixture.sut.selectedProvider == .openAI)
    }

    @Test func selectedModel_returnsModelFromMockSelectedMode() throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .anthropic, model: "claude-sonnet-4-5")
        )
        #expect(fixture.sut.selectedModel == "claude-sonnet-4-5")
    }

    @Test func selectedModel_isNil_whenStubModelIsEmpty() throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .openAI, model: "")
        )
        #expect(fixture.sut.selectedModel == nil)
    }
}
