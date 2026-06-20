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
        let conversation: MultiNoteConversation
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
        return Fixture(sut: sut, mockAIService: mockAIService, container: container, conversation: conversation)
    }

    /// A mode wired to a configured cloud provider, so `sendMessage` clears its
    /// guards (avoids the Apple FM branch).
    private func cloudMode() -> VivaMode {
        makeMode(provider: .openAI, model: "gpt-4")
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

    // MARK: - loadMessages

    @Test func loadMessages_populatesMessagesSortedByCreatedAt() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        let older = ChatMessage(role: "user", content: "first")
        older.createdAt = Date(timeIntervalSince1970: 100)
        let newer = ChatMessage(role: "assistant", content: "second")
        newer.createdAt = Date(timeIntervalSince1970: 200)
        fixture.conversation.messages = [newer, older]
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

    @Test func clearChat_removesAllMessages() throws {
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
    }

    // MARK: - sendMessage happy / error flows

    private enum TestError: Error { case boom }

    /// Spins the cooperative pool until the fire-and-forget streaming task
    /// settles. The mock has no real latency, so this converges immediately;
    /// the spin cap only guards against a hang.
    private func drainStreaming(_ sut: MultiNoteChatViewModel) async {
        var spins = 0
        while sut.isStreaming && spins < 5_000 {
            await Task.yield()
            spins += 1
        }
    }

    /// The fat path with no cross-note/web search armed: the VM streams a cloud
    /// reply through the injected `AIChatService` and persists both the user
    /// turn and the assistant turn.
    @Test func sendMessage_cloudHappyPath_streamsAndPersistsAssistant() async throws {
        // Skip the implicit cloud cross-note tool so the send stays hermetic
        // (it otherwise consults the global RAG feature flag + tool runtime).
        SmartSearchFeature.isEnabled = false
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.mockAIService.stubMakeChatStreamingRequestPartials = ["Here", "Here is", "Here is the answer."]
        fixture.mockAIService.stubMakeChatStreamingRequestResult = .success("Here is the answer.")
        fixture.sut.inputText = "summarize my notes"

        fixture.sut.sendMessage()
        await drainStreaming(fixture.sut)

        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.mockAIService.makeChatStreamingRequestCallCount == 1)
        #expect(fixture.sut.messages.count == 2)
        #expect(fixture.sut.messages.last?.role == "assistant")
        #expect(fixture.sut.messages.last?.content == "Here is the answer.")
        #expect(fixture.sut.messages.last?.isError == false)
        #expect(fixture.sut.errorMessage == nil)
    }

    /// A failing cloud request is caught: the user turn is kept and an error
    /// assistant message is appended rather than the flow crashing.
    @Test func sendMessage_whenCloudRequestFails_appendsErrorAssistantMessage() async throws {
        SmartSearchFeature.isEnabled = false
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.mockAIService.stubMakeChatStreamingRequestResult = .failure(TestError.boom)
        fixture.sut.inputText = "summarize my notes"

        fixture.sut.sendMessage()
        await drainStreaming(fixture.sut)

        #expect(fixture.mockAIService.makeChatStreamingRequestCallCount == 1)
        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.sut.messages.last?.isError == true)
    }
}
