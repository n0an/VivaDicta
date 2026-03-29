//
//  AIProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    case apple
    case cerebras
    case groq
    case gemini
    case anthropic
    case openAI
    case openRouter
    case grok
    case elevenLabs
    case deepgram
    case mistral
    case soniox
    case cohere
    case zai
    case kimi
    case vercelAIGateway
    case huggingFace
    case copilot
    case ollama
    case customOpenAI

    var displayName: String {
        switch self {
        case .apple:
            "Apple"
        case .cerebras:
            "Cerebras"
        case .openAI:
            "OpenAI"
        case .groq:
            "Groq"
        case .elevenLabs:
            "ElevenLabs"
        case .deepgram:
            "Deepgram"
        case .mistral:
            "Mistral"
        case .gemini:
            "Gemini"
        case .soniox:
            "Soniox"
        case .cohere:
            "Cohere"
        case .anthropic:
            "Anthropic"
        case .openRouter:
            "OpenRouter"
        case .grok:
            "Grok (x.ai)"
        case .zai:
            "Z.AI"
        case .kimi:
            "Kimi (Moonshot)"
        case .vercelAIGateway:
            "Vercel AI Gateway"
        case .huggingFace:
            "HuggingFace"
        case .copilot:
            "GitHub Copilot"
        case .ollama:
            "Ollama"
        case .customOpenAI:
            "Custom"
        }
    }

    /// Returns the icon name for this provider (SF Symbol for Apple, asset name for others)
    var iconName: String? {
        switch self {
        case .apple:
            nil // Use SF Symbol "apple.logo" directly in view
        case .anthropic:
            "anthropic"
        case .openAI:
            "openai"
        case .gemini:
            "gemini"
        case .groq:
            "groq"
        case .mistral:
            "mistral"
        case .cerebras:
            "cerebras"
        case .grok:
            "grok"
        case .zai:
            "zai"
        case .kimi:
            "moonshot"
        case .openRouter:
            "openrouter"
        case .elevenLabs:
            "elevenlabs"
        case .deepgram:
            "deepgram"
        case .soniox:
            nil
        case .cohere:
            "cohere-color"
        case .vercelAIGateway:
            "vercel"
        case .huggingFace:
            "huggingface-color"
        case .copilot:
            "githubcopilot"
        case .ollama:
            "ollama"
        case .customOpenAI:
            nil // Use SF Symbol "server.rack" directly in view
        }
    }

    /// Returns true if this provider uses an SF Symbol instead of an asset
    var usesSFSymbol: Bool {
        self == .apple || self == .customOpenAI
    }

    /// URL to obtain an API key for this provider.
    var apiKeyURL: URL? {
        switch self {
        case .groq: URL(string: "https://console.groq.com/keys")
        case .openAI: URL(string: "https://platform.openai.com/api-keys")
        case .gemini: URL(string: "https://makersuite.google.com/app/apikey")
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        case .mistral: URL(string: "https://console.mistral.ai/api-keys")
        case .elevenLabs: URL(string: "https://elevenlabs.io/speech-synthesis")
        case .deepgram: URL(string: "https://console.deepgram.com/api-keys")
        case .soniox: URL(string: "https://console.soniox.com/")
        case .openRouter: URL(string: "https://openrouter.ai/keys")
        case .cerebras: URL(string: "https://cloud.cerebras.ai/")
        case .grok: URL(string: "https://console.x.ai/")
        case .vercelAIGateway: URL(string: "https://vercel.com/account/tokens")
        case .huggingFace: URL(string: "https://huggingface.co/settings/tokens")
        case .zai: URL(string: "https://open.z.ai/")
        case .kimi: URL(string: "https://platform.moonshot.cn/console/api-keys")
        case .cohere: URL(string: "https://dashboard.cohere.com/api-keys")
        default: nil
        }
    }

    /// Returns true if this provider requires an API key
    /// Note: customOpenAI doesn't require API key through the standard flow - it's handled separately
    var requiresAPIKey: Bool {
        self != .apple && self != .ollama && self != .customOpenAI && self != .copilot
    }

    /// Cloud-based AI providers (require API key, network connection)
    /// Note: Ollama and customOpenAI are included here for UI purposes but don't require API key through standard flow
    static let cloudProviders: [AIProvider] = [
        .anthropic,
        .openAI,
        .gemini,
        .copilot,
        .groq,
        .mistral,
        .cerebras,
        .grok,
        .zai,
        .kimi,
        .openRouter,
        .vercelAIGateway,
        .huggingFace,
        .ollama,
        .customOpenAI]

    /// Local AI providers that run on-device or local network (no API key needed)
    static let localProviders: [AIProvider] = [
        .apple,
        .ollama]

    /// All general-purpose AI providers including on-device and local
    static let generalProviders: [AIProvider] = [
        .apple,
        .ollama,
        .customOpenAI,
        .anthropic,
        .openAI,
        .gemini,
        .copilot,
        .groq,
        .mistral,
        .cerebras,
        .grok,
        .zai,
        .kimi,
        .openRouter,
        .vercelAIGateway,
        .huggingFace]
    
    var baseURL: String {
        switch self {
        case .apple:
            return "" // On-device, no URL needed
        case .cerebras:
            return "https://api.cerebras.ai/v1/chat/completions"
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .grok:
            return "https://api.x.ai/v1/chat/completions"
        case .zai:
            return "https://api.z.ai/api/paas/v4/chat/completions"
        case .kimi:
            return "https://api.moonshot.ai/v1/chat/completions"
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .deepgram:
            return "https://api.deepgram.com/v1/listen"
        case .mistral:
            return "https://api.mistral.ai/v1/chat/completions"
        case .soniox:
            return "https://api.soniox.com/v1"
        case .cohere:
            return "https://api.cohere.com/v2"
        case .vercelAIGateway:
            return "https://ai-gateway.vercel.sh/v1/chat/completions"
        case .huggingFace:
            return "https://router.huggingface.co/v1/chat/completions"
        case .copilot:
            return "https://api.individual.githubcopilot.com/chat/completions"
        case .ollama:
            return "" // URL is configurable, stored in UserDefaults
        case .customOpenAI:
            return "" // URL is configurable, stored in UserDefaults
        }
    }

    /// Default Ollama server URL
    static let ollamaDefaultServerURL = "http://host:11434"

    var defaultModel: String {
        switch self {
        case .apple:
            return "foundation-model"
        case .cerebras:
            return "gpt-oss-120b"
        case .groq:
            return "openai/gpt-oss-120b"
        case .gemini:
            return "gemini-3-flash-preview"
        case .anthropic:
            return "claude-sonnet-4-6"
        case .openAI:
            return "gpt-5.4"
        case .grok:
            return "grok-4.20-beta"
        case .zai:
            return "glm-5"
        case .kimi:
            return "kimi-k2.5"
        case .elevenLabs:
            return "scribe_v1"
        case .deepgram:
            return "whisper-1"
        case .mistral:
            return "mistral-large-latest"
        case .openRouter:
            return "openai/gpt-oss-120b"
        case .soniox:
            return "stt-async-v4"
        case .cohere:
            return "cohere-transcribe-03-2026"
        case .vercelAIGateway:
            // Note: Vercel AI Gateway uses "provider/model" format with dots for versions
            // (e.g., "claude-sonnet-4.5") unlike direct Anthropic API which uses hyphens
            // (e.g., "claude-sonnet-4-5"). Models are fetched dynamically, so this must
            // match Vercel's actual naming convention.
            return "anthropic/claude-sonnet-4.5"
        case .huggingFace:
            return "openai/gpt-oss-120b"
        case .copilot:
            return "gpt-4o"
        case .ollama:
            return "llama3.2"
        case .customOpenAI:
            return "" // Model is configurable, stored in UserDefaults
        }
    }

    // MARK: - Keychain

    /// Keychain account name for this provider's API key.
    /// Must match the macOS app's `APIKeyManager` key identifiers for iCloud Keychain sync.
    var keychainKey: String {
        switch self {
        case .cerebras: "cerebrasAPIKey"
        case .groq: "groqAPIKey"
        case .gemini: "geminiAPIKey"
        case .anthropic: "anthropicAPIKey"
        case .openAI: "openAIAPIKey"
        case .openRouter: "openRouterAPIKey"
        case .grok: "grokAPIKey"
        case .zai: "zaiAPIKey"
        case .kimi: "kimiAPIKey"
        case .elevenLabs: "elevenLabsAPIKey"
        case .deepgram: "deepgramAPIKey"
        case .mistral: "mistralAPIKey"
        case .soniox: "sonioxAPIKey"
        case .cohere: "cohereAPIKey"
        case .vercelAIGateway: "vercelAIGatewayAPIKey"
        case .huggingFace: "huggingFaceAPIKey"
        case .customOpenAI: "customOpenAIAPIKey"
        case .apple, .ollama, .copilot: ""
        }
    }

    var availableModels: [String] {
        switch self {
        case .apple:
            return ["foundation-model"]
        case .cerebras:
            return [
                "gpt-oss-120b",
                "llama3.1-8b",
                "qwen-3-235b-a22b-instruct-2507",
                "zai-glm-4.7"
            ]
        case .groq:
            return [
                "llama-3.1-8b-instant",
                "llama-3.3-70b-versatile",
                "moonshotai/kimi-k2-instruct-0905",
                "qwen/qwen3-32b",
                "meta-llama/llama-4-scout-17b-16e-instruct",
                "openai/gpt-oss-120b",
                "openai/gpt-oss-20b"
            ]
        case .gemini:
            return [
                "gemini-3.1-pro-preview",
                "gemini-3.1-flash-lite-preview",
                "gemini-3-pro-preview",
                "gemini-3-flash-preview",
                "gemini-2.5-pro",
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite",
                "gemini-flash-latest",
                "gemini-flash-lite-latest"
            ]
        case .anthropic:
            return [
                "claude-opus-4-6",
                "claude-sonnet-4-6",
                "claude-opus-4-5",
                "claude-sonnet-4-5",
                "claude-haiku-4-5"
            ]
        case .openAI:
            return [
                "gpt-5.4",
                "gpt-5.4-mini",
                "gpt-5.4-nano",
                "gpt-5.2",
                "gpt-5.1",
                "gpt-5-mini",
                "gpt-5-nano",
                "gpt-4.1",
                "gpt-4.1-mini",
                "gpt-4.1-nano",
                "gpt-4o",
                "gpt-4o-mini"
            ]
        case .grok:
            return [
                "grok-4.20-beta",
                "grok-4.20-multi-agent-beta",
                "grok-4-fast",
                "grok-4-1-fast",
                "grok-4",
                "grok-4-heavy",
                "grok-code-fast-1"
            ]
        case .zai:
            return [
                "glm-5",
                "glm-4.7",
                "glm-4.6"
            ]
        case .kimi:
            return [
                "kimi-k2.5",
                "kimi-k2",
                "moonshot-v1-128k",
                "moonshot-v1-32k",
                "moonshot-v1-8k"
            ]
        case .elevenLabs:
            return []
        case .deepgram:
            return []
        case .mistral:
            return [
                "mistral-large-latest",
                "mistral-medium-latest",
                "mistral-small-latest",
                "mistral-saba-latest"
            ]
        case .soniox:
            return []
        case .cohere:
            return [] // Transcription-only provider, no chat models
        case .openRouter:
            return []
        case .vercelAIGateway:
            return []
        case .huggingFace:
            return []
        case .copilot:
            return [] // Models are fetched dynamically from Copilot API
        case .ollama:
            return [] // Models are fetched dynamically from Ollama server
        case .customOpenAI:
            return [] // Model is configured by user
        }
    }
}
