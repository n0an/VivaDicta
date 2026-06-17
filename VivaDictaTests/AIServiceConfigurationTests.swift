//
//  AIServiceConfigurationTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
import Presets
@testable import VivaDicta
import AICore

struct AIServiceConfigurationTests {

    // MARK: - Test Helpers

    private let suiteName = "AIServiceConfigTests.\(UUID().uuidString)"

    private func makeService(withModes modes: [VivaMode]? = nil) -> AIService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        if let modes {
            let encoded = try! JSONEncoder().encode(modes)
            defaults.set(encoded, forKey: "VivaModes")
        }
        return AIService(userDefaults: defaults)
    }

    private func makeMode(
        name: String = "Test",
        aiProvider: AIProvider? = .ollama,
        aiModel: String = "llama3.2",
        aiEnhanceEnabled: Bool = true,
        presetId: String? = "regular"
    ) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: name,
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test-whisper",
            presetId: presetId,
            aiProvider: aiProvider,
            aiModel: aiModel,
            aiEnhanceEnabled: aiEnhanceEnabled
        )
    }

    private func makePresetManager() -> PresetManager {
        let defaults = UserDefaults(suiteName: "\(suiteName).presets")!
        defaults.removePersistentDomain(forName: "\(suiteName).presets")
        return PresetManager(userDefaults: defaults, storageKey: "testPresets")
    }

    // MARK: - isProperlyConfigured Tests

    @Test func isProperlyConfigured_aiDisabled_returnsFalse() {
        let mode = makeMode(aiEnhanceEnabled: false)
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()

        #expect(sut.isProperlyConfigured() == false)
    }

    @Test func isProperlyConfigured_noProvider_returnsFalse() {
        let mode = makeMode(aiProvider: nil)
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()

        #expect(sut.isProperlyConfigured() == false)
    }

    @Test func isProperlyConfigured_emptyModel_returnsFalse() {
        let mode = makeMode(aiModel: "")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()

        #expect(sut.isProperlyConfigured() == false)
    }

    @Test func isProperlyConfigured_noPreset_returnsFalse() {
        let mode = makeMode(presetId: nil)
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()

        #expect(sut.isProperlyConfigured() == false)
    }

    @Test func isProperlyConfigured_emptyPresetInstructions_returnsFalse() {
        let mode = makeMode(presetId: "empty_preset")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name

        let pm = makePresetManager()
        let emptyPreset = Preset(
            id: "empty_preset",
            name: "Empty",
            icon: "📝",
            presetDescription: "Empty preset",
            category: "Other",
            promptInstructions: "",
            useSystemTemplate: true,
            isBuiltIn: false
        )
        pm.addPreset(emptyPreset)
        sut.presetManager = pm

        #expect(sut.isProperlyConfigured() == false)
    }

    @Test func isProperlyConfigured_ollamaProvider_validConfig_returnsTrue() {
        // Ollama doesn't need API key — just needs model + preset
        let mode = makeMode(aiProvider: .ollama, aiModel: "llama3.2", presetId: "regular")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()

        #expect(sut.isProperlyConfigured() == true)
    }

    @Test func isProperlyConfigured_customOpenAI_noEndpoint_returnsFalse() {
        let mode = makeMode(aiProvider: .customOpenAI, aiModel: "gpt-4")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()
        // customOpenAIEndpointURL is "" by default

        #expect(sut.isProperlyConfigured() == false)
    }

    @Test func isProperlyConfigured_cloudProvider_noAPIKey_returnsFalse() {
        // Anthropic requires API key — no key in keychain → false
        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.presetManager = makePresetManager()

        #expect(sut.isProperlyConfigured() == false)
    }

    // MARK: - Streaming Capability Tests

    @Test func currentModeSupportsResponseStreaming_appleMode_returnsTrue() {
        let mode = makeMode(aiProvider: .apple, aiModel: "foundation-model")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name

        #expect(sut.currentModeSupportsResponseStreaming == true)
    }

    @Test func currentModeSupportsResponseStreaming_openAIAPIKeyMode_returnsTrue() {
        let mode = makeMode(aiProvider: .openAI, aiModel: "gpt-5-mini")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name

        #expect(sut.currentModeSupportsResponseStreaming == true)
    }

    @Test func currentModeSupportsResponseStreaming_openAIOAuth_returnsTrue() {
        let mode = makeMode(aiProvider: .openAI, aiModel: "gpt-5.4-mini")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.isOpenAISignedIn = true

        #expect(sut.currentModeSupportsResponseStreaming == true)
    }

    @Test func currentModeSupportsResponseStreaming_geminiOAuth_returnsTrue() {
        let mode = makeMode(aiProvider: .gemini, aiModel: "gemini-3-flash-preview")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.isGeminiSignedIn = true

        #expect(sut.currentModeSupportsResponseStreaming == true)
    }

    @Test func currentModeSupportsResponseStreaming_copilotOAuth_returnsTrue() {
        let mode = makeMode(aiProvider: .copilot, aiModel: "gpt-4o")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name
        sut.isCopilotSignedIn = true

        #expect(sut.currentModeSupportsResponseStreaming == true)
    }

    @Test func openAICompatibleStreamingDelta_extractsContentDelta() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#

        let delta = AIService.openAICompatibleStreamingDelta(from: line)

        #expect(delta == "Hello")
    }

    @Test func openAICompatibleStreamingDelta_ignoresDoneSentinel() {
        let line = "data: [DONE]"

        let delta = AIService.openAICompatibleStreamingDelta(from: line)

        #expect(delta == nil)
    }

    @Test func copilotStreamingDelta_extractsContentDelta() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#

        let delta = CopilotAPIClient.streamingDelta(from: line)

        #expect(delta == "Hello")
    }

    @Test func geminiStreamingText_extractsCandidateText() {
        let event: [String: Any] = [
            "response": [
                "candidates": [
                    [
                        "content": [
                            "parts": [
                                ["text": "Hello"],
                                ["text": " world"]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let text = GeminiAPIClient.streamingText(from: event)

        #expect(text == "Hello world")
    }

    @Test func currentModeSupportsResponseStreaming_anthropicReturnsTrue() {
        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6")
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name

        #expect(sut.currentModeSupportsResponseStreaming == true)
    }

    // MARK: - Apple FM Sampling Profiles

    @Test(arguments: [
        ("summary", AppleFoundationModelSamplingProfile.extractive),
        ("action_points", .extractive),
        ("key_points", .extractive),
        ("takeaways", .extractive),
        ("mind_map", .extractive),
        ("regular", .balanced),
        ("chat", .conversational),
        ("philosophical", .creative),
        ("custom_123", .balanced)
    ])
    func appleFMSamplingProfile_mapsPresetIDToProfile(
        presetID: String,
        expected: AppleFoundationModelSamplingProfile
    ) {
        #expect(AppleFoundationModelSamplingProfile.profile(for: presetID) == expected)
    }

    @Test func appleFMSamplingProfile_nilPresetFallsBackToBalanced() {
        #expect(AppleFoundationModelSamplingProfile.profile(for: nil) == .balanced)
    }

    // MARK: - Disable Modes by Provider Tests

    @Test func disableAIForModesUsingProvider_onlyAffectsMatchingModes() {
        let groqMode = makeMode(name: "Groq Mode", aiProvider: .groq, aiModel: "llama-3.3-70b-versatile")
        let ollamaMode = makeMode(name: "Ollama Mode", aiProvider: .ollama, aiModel: "llama3.2")
        let sut = makeService(withModes: [groqMode, ollamaMode])

        sut.disableAIEnhancementForModesUsingProvider(.groq)

        let updatedGroq = sut.modes.first { $0.name == "Groq Mode" }!
        let updatedOllama = sut.modes.first { $0.name == "Ollama Mode" }!

        #expect(updatedGroq.aiEnhanceEnabled == false)
        #expect(updatedOllama.aiEnhanceEnabled == true)
    }

    @Test func disableAIForModesUsingProvider_updatesSelectedMode() {
        let mode = makeMode(name: "Active", aiProvider: .groq)
        let sut = makeService(withModes: [mode])
        sut.selectedModeName = mode.name

        sut.disableAIEnhancementForModesUsingProvider(.groq)

        #expect(sut.selectedMode.aiEnhanceEnabled == false)
    }

    // MARK: - Disable Modes by Preset Tests

    @Test func disableAIForModesUsingPreset_onlyAffectsMatchingModes() {
        let summaryMode = makeMode(name: "Summary", presetId: "summary")
        let regularMode = makeMode(name: "Regular", presetId: "regular")
        let sut = makeService(withModes: [summaryMode, regularMode])

        sut.disableAIEnhancementForModesUsingPreset(presetId: "summary")

        let updatedSummary = sut.modes.first { $0.name == "Summary" }!
        let updatedRegular = sut.modes.first { $0.name == "Regular" }!

        #expect(updatedSummary.aiEnhanceEnabled == false)
        #expect(updatedSummary.presetId == nil)
        #expect(updatedRegular.aiEnhanceEnabled == true)
        #expect(updatedRegular.presetId == "regular")
    }

    // MARK: - Get Available Models Tests

    @Test func getAvailableModels_staticProvider_returnsProviderModels() {
        let sut = makeService()

        let anthropicModels = sut.getAvailableModels(for: .anthropic)

        #expect(anthropicModels.isEmpty == false)
        #expect(anthropicModels.contains("claude-sonnet-4-6"))
    }

    @Test func getAvailableModels_dynamicProvider_returnsStoredModels() {
        let sut = makeService()
        sut.openRouterModels = ["model-a", "model-b"]

        let models = sut.getAvailableModels(for: .openRouter)

        #expect(models == ["model-a", "model-b"])
    }

    @Test func getAvailableModels_customOpenAI_returnsConfiguredModel() {
        let sut = makeService()
        sut.customOpenAIModelName = "my-custom-model"

        let models = sut.getAvailableModels(for: .customOpenAI)

        #expect(models == ["my-custom-model"])
    }

    @Test func getAvailableModels_customOpenAI_emptyName_returnsEmpty() {
        let sut = makeService()
        sut.customOpenAIModelName = ""

        let models = sut.getAvailableModels(for: .customOpenAI)

        #expect(models.isEmpty)
    }
}
