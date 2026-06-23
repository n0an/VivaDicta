import Testing
import Foundation
@testable import AICore

/// Characterization tests that lock the `AIProvider` catalog contract as it
/// moves into `AICore`. They assert the current behavior verbatim so the move
/// (and every later edit) is provably behavior-preserving.
struct AIProviderTests {

    // MARK: - Catalog integrity

    @Test func allCasesCountIsStable() {
        #expect(AIProvider.allCases.count == 29)
    }

    @Test func rawValuesRoundTripForCodableAndDefaultsCompatibility() {
        // Raw values are persisted (UserDefaults / SwiftData / Codable), so they
        // must survive the module move unchanged.
        for provider in AIProvider.allCases {
            #expect(AIProvider(rawValue: provider.rawValue) == provider)
        }
        #expect(AIProvider.anthropic.rawValue == "anthropic")
        #expect(AIProvider.openAI.rawValue == "openAI")
        #expect(AIProvider.customOpenAI.rawValue == "customOpenAI")
        #expect(AIProvider.ollamaCloud.rawValue == "ollamaCloud")
    }

    // MARK: - Keychain keys

    /// These strings must match the macOS app's `APIKeyManager` identifiers for
    /// iCloud Keychain sync. A new provider added without a mapping fails the
    /// completeness check below.
    @Test func keychainKeysMatchCrossPlatformContract() {
        let expected: [AIProvider: String] = [
            .apple: "",
            .cerebras: "cerebrasAPIKey",
            .groq: "groqAPIKey",
            .gemini: "geminiAPIKey",
            .anthropic: "anthropicAPIKey",
            .openAI: "openAIAPIKey",
            .openRouter: "openRouterAPIKey",
            .grok: "grokAPIKey",
            .elevenLabs: "elevenLabsAPIKey",
            .deepgram: "deepgramAPIKey",
            .mistral: "mistralAPIKey",
            .soniox: "sonioxAPIKey",
            .gladia: "gladiaAPIKey",
            .speechmatics: "speechmaticsAPIKey",
            .cohere: "cohereAPIKey",
            .cartesia: "cartesiaAPIKey",
            .assemblyAI: "assemblyaiAPIKey",
            .zai: "zaiAPIKey",
            .kimi: "kimiAPIKey",
            .minimax: "minimaxAPIKey",
            .vercelAIGateway: "vercelAIGatewayAPIKey",
            .opencodeZen: "opencodeZenAPIKey",
            .huggingFace: "huggingFaceAPIKey",
            .copilot: "",
            .ollama: "",
            .ollamaCloud: "ollamaCloudAPIKey",
            .customOpenAI: "customOpenAIAPIKey",
            .localGemma: "",
            .localQwen: "",
        ]
        #expect(Set(expected.keys) == Set(AIProvider.allCases), "every provider must have a keychain-key expectation")
        for (provider, key) in expected {
            #expect(provider.keychainKey == key, "keychainKey for \(provider)")
        }
    }

    // MARK: - Endpoints and default models

    @Test func baseURLsAreStable() {
        #expect(AIProvider.openAI.baseURL == "https://api.openai.com/v1/chat/completions")
        #expect(AIProvider.anthropic.baseURL == "https://api.anthropic.com/v1/messages")
        #expect(AIProvider.gemini.baseURL == "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        // On-device / locally-configured providers carry no compiled base URL.
        #expect(AIProvider.apple.baseURL == "")
        #expect(AIProvider.ollama.baseURL == "")
        #expect(AIProvider.customOpenAI.baseURL == "")
    }

    @Test func defaultModelsAreStable() {
        #expect(AIProvider.apple.defaultModel == "foundation-model")
        #expect(AIProvider.anthropic.defaultModel == "claude-sonnet-4-6")
        #expect(AIProvider.openAI.defaultModel == "gpt-5.5")
    }

    // MARK: - Capability flags

    @Test func requiresAPIKeyMatchesProviderKind() {
        #expect(AIProvider.openAI.requiresAPIKey)
        #expect(AIProvider.anthropic.requiresAPIKey)
        #expect(!AIProvider.apple.requiresAPIKey)
        #expect(!AIProvider.ollama.requiresAPIKey)
        #expect(!AIProvider.customOpenAI.requiresAPIKey)
        #expect(!AIProvider.copilot.requiresAPIKey)
    }

    @Test func responseStreamingSupport() {
        #expect(AIProvider.apple.supportsResponseStreaming(model: "foundation-model"))
        #expect(AIProvider.openAI.supportsResponseStreaming(model: "gpt-5.5"))
        #expect(AIProvider.anthropic.supportsResponseStreaming(model: "claude-sonnet-4-6"))
        // Speech-only providers do not stream chat responses.
        #expect(!AIProvider.deepgram.supportsResponseStreaming(model: "whisper-1"))
    }

    // MARK: - Curated provider groups

    @Test func localProvidersAreAppleGemmaQwenAndOllama() {
        #expect(AIProvider.localProviders == [.apple, .localGemma, .localQwen, .ollama])
    }

    @Test func cloudProvidersContainAnthropicButNotApple() {
        #expect(AIProvider.cloudProviders.contains(.anthropic))
        #expect(!AIProvider.cloudProviders.contains(.apple))
    }

    @Test func reminderExtractorExcludesOllamaCloudButKeepsLocalOllama() {
        #expect(!AIProvider.reminderExtractorCloudProviders.contains(.ollamaCloud))
        #expect(AIProvider.reminderExtractorCloudProviders.contains(.ollama))
    }

    @Test func reminderExtractorExcludesOpencodeZen() {
        // Zen's free-tier models reject json_schema response formats.
        #expect(!AIProvider.reminderExtractorCloudProviders.contains(.opencodeZen))
    }

    @Test func generalProvidersContainAppleAndOpenAI() {
        #expect(AIProvider.generalProviders.contains(.apple))
        #expect(AIProvider.generalProviders.contains(.openAI))
    }

    // MARK: - OpenCode Zen tiers

    @Test func opencodeZenTiersDoNotOverlapAndCoverAvailableModels() {
        let free = Set(AIProvider.opencodeZenFreeModels)
        let paid = Set(AIProvider.opencodeZenPaidModels)
        #expect(free.isDisjoint(with: paid), "a model cannot be both free and paid")
        #expect(Set(AIProvider.opencodeZen.availableModels) == free.union(paid))
    }

    @Test func opencodeZenFreeClassificationUsesAllowlist() {
        #expect(AIProvider.isOpencodeZenModelFree("big-pickle"))
        #expect(!AIProvider.isOpencodeZenModelFree("claude-opus-4-8"))
        // Unknown models are treated as paid (Zen's free set is a fixed promotion).
        #expect(!AIProvider.isOpencodeZenModelFree("some-future-model"))
        // The default model must be free so a brand-new key verifies and works.
        #expect(AIProvider.isOpencodeZenModelFree(AIProvider.opencodeZen.defaultModel))
    }
}
