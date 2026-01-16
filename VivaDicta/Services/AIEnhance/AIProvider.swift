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
    case vercelAIGateway

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
        case .anthropic:
            "Anthropic"
        case .openRouter:
            "OpenRouter"
        case .grok:
            "Grok (x.ai)"
        case .vercelAIGateway:
            "Vercel AI Gateway"
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
        case .openRouter:
            "openrouter"
        case .elevenLabs:
            "elevenlabs"
        case .deepgram:
            "deepgram"
        case .soniox:
            nil
        case .vercelAIGateway:
            "vercel"
        }
    }

    /// Returns true if this provider uses an SF Symbol instead of an asset
    var usesSFSymbol: Bool {
        self == .apple
    }

    /// Returns true if this provider requires an API key
    var requiresAPIKey: Bool {
        self != .apple
    }

    /// Cloud-based AI providers (require API key, network connection)
    static let cloudProviders: [AIProvider] = [
        .anthropic,
        .openAI,
        .gemini,
        .groq,
        .mistral,
        .cerebras,
        .grok,
        .openRouter,
        .vercelAIGateway]

    /// All general-purpose AI providers including on-device
    static let generalProviders: [AIProvider] = [
        .apple,
        .anthropic,
        .openAI,
        .gemini,
        .groq,
        .mistral,
        .cerebras,
        .grok,
        .openRouter,
        .vercelAIGateway]
    
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
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .deepgram:
            return "https://api.deepgram.com/v1/listen"
        case .mistral:
            return "https://api.mistral.ai/v1/chat/completions"
        case .soniox:
            return "https://api.soniox.com/v1"
        case .vercelAIGateway:
            return "https://ai-gateway.vercel.sh/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .apple:
            return "foundation-model"
        case .cerebras:
            return "gpt-oss-120b"
        case .groq:
            return "openai/gpt-oss-120b"
        case .gemini:
            return "gemini-2.5-flash-lite"
        case .anthropic:
            return "claude-sonnet-4-5"
        case .openAI:
            return "gpt-5-mini"
        case .grok:
            return "grok-4"
        case .elevenLabs:
            return "scribe_v1"
        case .deepgram:
            return "whisper-1"
        case .mistral:
            return "mistral-large-latest"
        case .openRouter:
            return "openai/gpt-oss-120b"
        case .soniox:
            return "stt-async-v3"
        case .vercelAIGateway:
            return "anthropic/claude-sonnet-4-5"
        }
    }

    var availableModels: [String] {
        switch self {
        case .apple:
            return ["foundation-model"]
        case .cerebras:
            return [
                "llama-4-scout-17b-16e-instruct",
                "llama-3.3-70b",
                "gpt-oss-120b",
                "qwen-3-32b",
                "qwen-3-235b-a22b-instruct-2507"
            ]
        case .groq:
            return [
                "llama-3.1-8b-instant",
                "llama-3.3-70b-versatile",
                "moonshotai/kimi-k2-instruct-0905",
                "qwen/qwen3-32b",
                "meta-llama/llama-4-maverick-17b-128e-instruct",
                "openai/gpt-oss-120b",
                "openai/gpt-oss-20b"
            ]
        case .gemini:
            return [
                "gemini-3-flash-preview",
                "gemini-3-pro-preview",
                "gemini-2.5-pro",
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite",
                "gemini-flash-latest",
                "gemini-flash-lite-latest"
            ]
        case .anthropic:
            return [
                "claude-opus-4-5",
                "claude-sonnet-4-5",
                "claude-haiku-4-5"
            ]
        case .openAI:
            return [
                "gpt-5.2",
                "gpt-5.1",
                "gpt-5-mini",
                "gpt-5-nano",
                "gpt-4.1",
                "gpt-4.1-mini"
            ]
        case .grok:
            return [
                "grok-4",
                "grok-4-heavy",
                "grok-code-fast-1"
            ]
        case .elevenLabs:
            return ["scribe_v1", "scribe_v1_experimental"]
        case .deepgram:
            return ["whisper-1"]
        case .mistral:
            return [
                "mistral-large-latest",
                "mistral-medium-latest",
                "mistral-small-latest",
                "mistral-saba-latest"
            ]
        case .soniox:
            return ["stt-async-v3"]
        case .openRouter:
            return []
        case .vercelAIGateway:
            return []
        }
    }
}
