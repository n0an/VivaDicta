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
import AICore

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
            for: SmartSearchConversation.self, ChatMessage.self, Transcription.self,
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
        let searchService: MockNoteSearchService
        let container: ModelContainer
        let conversation: SmartSearchConversation
    }

    private func makeFixture(
        stubMode: VivaMode = VivaMode.defaultMode
    ) throws -> Fixture {
        let container = try makeContainer()
        let conversation = SmartSearchConversation()
        container.mainContext.insert(conversation)

        let mockAIService = MockAIChatService()
        mockAIService.stubSelectedMode = stubMode
        let searchService = MockNoteSearchService()

        let sut = SmartSearchChatViewModel(
            conversation: conversation,
            aiService: mockAIService,
            modelContext: container.mainContext,
            searchService: searchService
        )
        return Fixture(sut: sut, mockAIService: mockAIService, searchService: searchService, container: container, conversation: conversation)
    }

    /// A mode wired to a configured cloud provider, so `sendMessage` clears its
    /// guards (avoids the Apple FM branch).
    private func cloudMode() -> VivaMode {
        makeMode(provider: .openAI, model: "gpt-4")
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

    // MARK: - sendMessage guards (and the search seam)

    @Test func sendMessage_emptyInput_isNoOpAndDoesNotSearch() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.sut.inputText = ""

        fixture.sut.sendMessage()

        #expect(fixture.sut.messages.isEmpty)
        #expect(fixture.sut.errorMessage == nil)
        #expect(fixture.sut.isStreaming == false)
        // The injected NoteSearchService seam: the guard short-circuits before
        // any retrieval, so the search service is never asked.
        #expect(fixture.searchService.searchCallCount == 0)
    }

    @Test func sendMessage_noModelSelected_setsNoProviderError() throws {
        let fixture = try makeFixture(stubMode: makeMode(provider: .openAI, model: ""))
        fixture.sut.inputText = "hello"

        fixture.sut.sendMessage()

        #expect(fixture.sut.errorMessage == "No AI provider selected")
        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.searchService.searchCallCount == 0)
    }

    @Test func sendMessage_providerNotReady_setsNotConfiguredError() throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.mockAIService.stubIsChatProviderReady = false
        fixture.sut.inputText = "hello"

        fixture.sut.sendMessage()

        #expect(fixture.sut.errorMessage?.contains("not configured") == true)
        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.searchService.searchCallCount == 0)
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

    // MARK: - sendMessage happy / no-evidence / error flows

    private enum TestError: Error { case boom }

    /// Spins the cooperative pool until the fire-and-forget streaming task
    /// settles. The mock has no real latency, so this converges immediately;
    /// the spin cap only guards against a hang.
    private func drainStreaming(_ sut: SmartSearchChatViewModel) async {
        var spins = 0
        while sut.isStreaming && spins < 5_000 {
            await Task.yield()
            spins += 1
        }
    }

    private func ragHit(_ transcriptionId: UUID, _ chunk: String = "apples are a red fruit") -> RAGSearchResult {
        RAGSearchResult(transcriptionId: transcriptionId, chunkText: chunk, relevanceScore: 0.9)
    }

    /// The fat path: retrieval returns a hit, so the VM assembles an augmented
    /// prompt, streams a cloud reply through the injected `AIChatService`, and
    /// persists both the user turn and the assistant turn with its citations.
    @Test func sendMessage_cloudHappyPath_searchesStreamsAndPersistsAssistant() async throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        let note = Transcription(text: "Note about apples", audioDuration: 3)
        fixture.container.mainContext.insert(note)
        fixture.searchService.stubResult = .success([ragHit(note.id)])
        fixture.mockAIService.stubMakeChatStreamingRequestPartials = ["Apples", "Apples are", "Apples are a fruit."]
        fixture.mockAIService.stubMakeChatStreamingRequestResult = .success("Apples are a fruit.")
        fixture.sut.inputText = "tell me about apples"

        fixture.sut.sendMessage()
        await drainStreaming(fixture.sut)

        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.searchService.searchCallCount == 1)
        #expect(fixture.searchService.capturedQueries.first?.query == "tell me about apples")
        #expect(fixture.mockAIService.makeChatStreamingRequestCallCount == 1)
        // User turn + assistant reply are both persisted and shown.
        #expect(fixture.sut.messages.count == 2)
        #expect(fixture.sut.messages.last?.role == "assistant")
        #expect(fixture.sut.messages.last?.content == "Apples are a fruit.")
        #expect(fixture.sut.messages.last?.isError == false)
        // The retrieved note is cited on the assistant turn.
        #expect(fixture.sut.messages.last?.sourceTranscriptionIds == [note.id])
        #expect(fixture.sut.errorMessage == nil)
    }

    /// Retrieval returns nothing for a grounded query, so the VM short-circuits
    /// to a deterministic "no evidence" reply and never hits the cloud provider.
    @Test func sendMessage_noSearchResults_returnsDeterministicNoEvidenceWithoutCloudCall() async throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        fixture.searchService.stubResult = .success([]) // no note context
        fixture.sut.inputText = "anything about quarterly revenue"

        fixture.sut.sendMessage()
        await drainStreaming(fixture.sut)

        #expect(fixture.searchService.searchCallCount == 1)
        #expect(fixture.mockAIService.makeChatStreamingRequestCallCount == 0) // no cloud send
        #expect(fixture.sut.messages.last?.role == "assistant")
        #expect(fixture.sut.messages.last?.content.localizedStandardContains("could not find") == true)
        #expect(fixture.sut.messages.last?.isError == false)
        #expect(fixture.sut.errorMessage == nil)
    }

    /// A failing cloud request is caught: the user turn is kept and an error
    /// assistant message is appended rather than the flow crashing.
    @Test func sendMessage_whenCloudRequestFails_appendsErrorAssistantMessage() async throws {
        let fixture = try makeFixture(stubMode: cloudMode())
        let note = Transcription(text: "Note", audioDuration: 1)
        fixture.container.mainContext.insert(note)
        fixture.searchService.stubResult = .success([ragHit(note.id)])
        fixture.mockAIService.stubMakeChatStreamingRequestResult = .failure(TestError.boom)
        fixture.sut.inputText = "tell me about apples"

        fixture.sut.sendMessage()
        await drainStreaming(fixture.sut)

        #expect(fixture.mockAIService.makeChatStreamingRequestCallCount == 1)
        #expect(fixture.sut.isStreaming == false)
        #expect(fixture.sut.messages.last?.isError == true)
    }
}
