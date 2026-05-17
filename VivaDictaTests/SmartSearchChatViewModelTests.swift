//
//  SmartSearchChatViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import SwiftData
import Testing
@testable import VivaDicta

/// Proof-of-pattern: tests the real ``SmartSearchChatViewModel`` against a
/// hand-rolled ``MockAIChatService`` injected through the ``AIChatService``
/// protocol. This is the first app-target test class following the Bev
/// dependency-injection-with-mocks pattern.
@MainActor
struct SmartSearchChatViewModelTests {

    // MARK: - Test Infrastructure

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SmartSearchConversation.self, ChatMessage.self,
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
        let sut: SmartSearchChatViewModel
        let mockAIService: MockAIChatService
        let container: ModelContainer
    }

    private func makeFixture(
        stubMode: VivaMode = VivaMode.defaultMode
    ) throws -> Fixture {
        let container = try makeContainer()
        let conversation = SmartSearchConversation()
        container.mainContext.insert(conversation)

        let mockAIService = MockAIChatService()
        mockAIService.stubSelectedMode = stubMode

        let sut = SmartSearchChatViewModel(
            conversation: conversation,
            aiService: mockAIService,
            modelContext: container.mainContext
        )
        return Fixture(sut: sut, mockAIService: mockAIService, container: container)
    }

    // MARK: - selectedProvider / selectedModel pass-through

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
