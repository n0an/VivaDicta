//
//  ChatViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.17
//

import Foundation
import Analytics
import AnalyticsMocks
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
        let analytics: MockAnalyticsService
        let conversation: ChatConversation
    }

    private func makeFixture(stubMode: VivaMode = .defaultMode, analytics: MockAnalyticsService = MockAnalyticsService()) throws -> Fixture {
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
            modelContext: container.mainContext,
            analytics: analytics
        )
        return Fixture(sut: sut, mockAIService: mockAIService, container: container, analytics: analytics, conversation: conversation)
    }

    /// A mode wired to a configured cloud provider, so `sendMessage` clears its
    /// guards and reaches the send path (avoids the Apple FM branch).
    private func cloudMode() -> VivaMode {
        makeMode(provider: .openAI, model: "gpt-4")
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

    /// The capability the Analytics seam unlocks: assert which events fired by
    /// injecting a recording `MockAnalyticsService` (impossible with the old
    /// static facade). `sendMessage` logs conversation-started + message-sent
    /// synchronously, before the streaming task runs.
    @Test func sendMessage_tracksConversationStartedAndMessageSent() async throws {
        let fixture = try makeFixture(
            stubMode: makeMode(provider: .openAI, model: "gpt-4")
        )
        fixture.sut.inputText = "hello there"

        fixture.sut.sendMessage()

        // Events fire synchronously, before the streaming task starts.
        #expect(fixture.analytics.trackedEventNames.contains("chat_conversation_started"))
        #expect(fixture.analytics.trackedEventNames.contains("chat_message_sent"))

        // Drain the background streaming task so it finishes while the in-memory
        // container is still alive (otherwise it touches a reset ModelContext).
        fixture.sut.cancelStreaming()
        var spins = 0
        while fixture.sut.isStreaming && spins < 1000 {
            await Task.yield()
            spins += 1
        }
        #expect(!fixture.sut.isStreaming)   // drained for real, not just hit the spin cap
    }

    // MARK: - loadMessages

    @Test func loadMessages_populatesMessagesSortedByCreatedAt() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        let older = ChatMessage(role: "user", content: "first")
        older.createdAt = Date(timeIntervalSince1970: 100)
        let newer = ChatMessage(role: "assistant", content: "second")
        newer.createdAt = Date(timeIntervalSince1970: 200)
        fixture.conversation.messages = [newer, older] // inserted out of order
        fixture.container.mainContext.insert(older)
        fixture.container.mainContext.insert(newer)

        fixture.sut.loadMessages()

        #expect(fixture.sut.messages.map(\.content) == ["first", "second"])
    }

    // MARK: - sendMessage guards

    @Test func sendMessage_emptyInput_isNoOp() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.sut.inputText = ""

        fixture.sut.sendMessage()

        #expect(fixture.sut.messages.isEmpty)
        #expect(fixture.sut.errorMessage == nil)
        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.analytics.trackedEventNames.contains("chat_message_sent") == false)
    }

    @Test func sendMessage_whitespaceOnlyInput_isNoOp() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.sut.inputText = "   \n\t  "

        fixture.sut.sendMessage()

        #expect(fixture.sut.messages.isEmpty)
        #expect(fixture.sut.errorMessage == nil)
        #expect(fixture.sut.isStreaming == false)
    }

    @Test func sendMessage_noModelSelected_setsNoProviderError() throws {
        let fixture = try makeFixture(stubMode: makeMode(provider: .openAI, model: ""))
        fixture.sut.inputText = "hello"

        fixture.sut.sendMessage()

        #expect(fixture.sut.errorMessage == "No AI provider selected")
        #expect(fixture.sut.isStreaming == false)
    }

    @Test func sendMessage_providerNotReady_setsNotConfiguredError() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.mockAIService.stubIsChatProviderReady = false
        fixture.sut.inputText = "hello"

        fixture.sut.sendMessage()

        #expect(fixture.sut.errorMessage?.contains("not configured") == true)
        #expect(fixture.sut.isStreaming == false)
    }

    // MARK: - clearChat

    @Test func clearChat_removesAllMessagesAndDisarmsSearch() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        let m1 = ChatMessage(role: "user", content: "one")
        m1.createdAt = Date(timeIntervalSince1970: 1)
        let m2 = ChatMessage(role: "assistant", content: "two")
        m2.createdAt = Date(timeIntervalSince1970: 2)
        fixture.conversation.messages = [m1, m2]
        fixture.container.mainContext.insert(m1)
        fixture.container.mainContext.insert(m2)
        fixture.sut.loadMessages()
        #expect(fixture.sut.messages.count == 2)

        fixture.sut.clearChat()

        #expect(fixture.sut.messages.isEmpty)
        #expect(fixture.sut.isCrossNoteSearchArmed == false)
        #expect(fixture.sut.isWebSearchArmed == false)
    }
}
