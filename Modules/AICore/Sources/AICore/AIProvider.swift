//
//  AIProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import Foundation

public enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    public var id: Self { self }

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
    case gladia
    case speechmatics
    case cohere
    case cartesia
    case assemblyAI
    case zai
    case kimi
    case minimax
    case vercelAIGateway
    case opencodeZen
    case huggingFace
    case copilot
    case ollama
    case ollamaCloud
    case customOpenAI
    case localGemma
    case localMLX

    public var displayName: String {
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
        case .gladia:
            "Gladia"
        case .speechmatics:
            "Speechmatics"
        case .cohere:
            "Cohere"
        case .cartesia:
            "Cartesia"
        case .assemblyAI:
            "AssemblyAI"
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
        case .minimax:
            "MiniMax"
        case .vercelAIGateway:
            "Vercel AI Gateway"
        case .opencodeZen:
            "OpenCode Zen"
        case .huggingFace:
            "HuggingFace"
        case .copilot:
            "GitHub Copilot"
        case .ollama:
            "Ollama"
        case .ollamaCloud:
            "Ollama Cloud"
        case .customOpenAI:
            "Custom"
        case .localGemma:
            "Google Gemma"
        case .localMLX:
            "MLX"
        }
    }

    /// Returns the icon name for this provider (SF Symbol for Apple, asset name for others)
    public var iconName: String? {
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
        case .minimax:
            "minimax-color"
        case .openRouter:
            "openrouter"
        case .elevenLabs:
            "elevenlabs"
        case .deepgram:
            "deepgram"
        case .soniox:
            "soniox"
        case .gladia:
            "gladia"
        case .speechmatics:
            "speechmatics"
        case .cohere:
            "cohere-color"
        case .cartesia:
            "cartesia"
        case .assemblyAI:
            "assemblyai-color"
        case .vercelAIGateway:
            "vercel"
        case .opencodeZen:
            "opencode"
        case .huggingFace:
            "huggingface-color"
        case .copilot:
            "githubcopilot"
        case .ollama:
            "ollama"
        case .ollamaCloud:
            "ollama"
        case .customOpenAI:
            nil // Use SF Symbol "server.rack" directly in view
        case .localGemma:
            nil // Use SF Symbol "cpu" directly in view (on-device)
        case .localMLX:
            nil // Per-model assets used directly in the cards (on-device)
        }
    }

    /// Returns true if this provider uses an SF Symbol instead of an asset
    public var usesSFSymbol: Bool {
        self == .apple || self == .customOpenAI || self == .localGemma || self == .localMLX
    }

    /// Returns true when the selected model can stream text responses incrementally.
    public func supportsResponseStreaming(model: String) -> Bool {
        switch self {
        case .apple,
             .anthropic,
             .cerebras,
             .copilot,
             .groq,
             .gemini,
             .openAI,
             .openRouter,
             .grok,
             .mistral,
             .zai,
             .kimi,
             .minimax,
             .vercelAIGateway,
             .opencodeZen,
             .huggingFace,
             .ollama,
             .ollamaCloud,
             .customOpenAI,
             .localGemma,
             .localMLX:
            true
        default:
            false
        }
    }

    /// URL to obtain an API key for this provider.
    public var apiKeyURL: URL? {
        switch self {
        case .groq: URL(string: "https://console.groq.com/keys")
        case .openAI: URL(string: "https://platform.openai.com/api-keys")
        case .gemini: URL(string: "https://makersuite.google.com/app/apikey")
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        case .mistral: URL(string: "https://console.mistral.ai/api-keys")
        case .elevenLabs: URL(string: "https://elevenlabs.io/speech-synthesis")
        case .deepgram: URL(string: "https://console.deepgram.com/api-keys")
        case .soniox: URL(string: "https://console.soniox.com/")
        case .gladia: URL(string: "https://app.gladia.io/api-keys")
        case .speechmatics: URL(string: "https://portal.speechmatics.com/manage-access/")
        case .openRouter: URL(string: "https://openrouter.ai/keys")
        case .cerebras: URL(string: "https://cloud.cerebras.ai/")
        case .grok: URL(string: "https://console.x.ai/")
        case .vercelAIGateway: URL(string: "https://vercel.com/account/tokens")
        case .opencodeZen: URL(string: "https://opencode.ai/auth")
        case .huggingFace: URL(string: "https://huggingface.co/settings/tokens")
        case .zai: URL(string: "https://open.z.ai/")
        case .kimi: URL(string: "https://platform.moonshot.cn/console/api-keys")
        case .minimax: URL(string: "https://platform.minimax.io/user-center/basic-information/interface-key")
        case .cohere: URL(string: "https://dashboard.cohere.com/api-keys")
        case .cartesia: URL(string: "https://play.cartesia.ai/keys")
        case .assemblyAI: URL(string: "https://www.assemblyai.com/app/api-keys")
        case .ollamaCloud: URL(string: "https://ollama.com/settings/keys")
        default: nil
        }
    }

    /// Returns true if this provider requires an API key
    /// Note: customOpenAI doesn't require API key through the standard flow - it's handled separately
    public var requiresAPIKey: Bool {
        self != .apple && self != .ollama && self != .customOpenAI && self != .copilot && self != .localGemma && self != .localMLX
    }

    /// Cloud-based AI providers (require API key, network connection)
    /// Note: Ollama and customOpenAI are included here for UI purposes but don't require API key through standard flow
    public static let cloudProviders: [AIProvider] = [
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
        .minimax,
        .openRouter,
        .vercelAIGateway,
        .opencodeZen,
        .huggingFace,
        .ollama,
        .ollamaCloud,
        .customOpenAI]

    /// Cloud providers eligible to act as a reminder extractor.
    ///
    /// Excludes Ollama Cloud: reminder extraction relies on structured
    /// (`json_schema`) outputs, which Ollama Cloud does not support
    /// (https://docs.ollama.com/capabilities/structured-outputs). Local Ollama
    /// does support them, so it stays eligible.
    ///
    /// Also excludes OpenCode Zen: its free-tier models reject `json_schema`
    /// response formats ("This response_format type is unavailable now",
    /// verified 2026-06-19), so the structured reminder extraction would fail on
    /// the models most Zen users run.
    public static let reminderExtractorCloudProviders: [AIProvider] =
        cloudProviders.filter { $0 != .ollamaCloud && $0 != .opencodeZen }

    /// Local AI providers that run on-device or local network (no API key needed)
    public static let localProviders: [AIProvider] = [
        .apple,
        .localGemma,
        .localMLX,
        .ollama]

    /// All general-purpose AI providers including on-device and local
    public static let generalProviders: [AIProvider] = [
        .apple,
        .localGemma,
        .localMLX,
        .ollama,
        .ollamaCloud,
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
        .minimax,
        .openRouter,
        .vercelAIGateway,
        .opencodeZen,
        .huggingFace]

    public var baseURL: String {
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
        case .minimax:
            return "https://api.minimax.io/v1/chat/completions"
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .deepgram:
            return "https://api.deepgram.com/v1/listen"
        case .mistral:
            return "https://api.mistral.ai/v1/chat/completions"
        case .soniox:
            return "https://api.soniox.com/v1"
        case .gladia:
            return "https://api.gladia.io/v2"
        case .speechmatics:
            return "https://asr.api.speechmatics.com/v2"
        case .cohere:
            return "https://api.cohere.com/v2"
        case .cartesia:
            return "https://api.cartesia.ai"
        case .assemblyAI:
            return "https://api.assemblyai.com/v2"
        case .vercelAIGateway:
            return "https://ai-gateway.vercel.sh/v1/chat/completions"
        case .opencodeZen:
            return "https://opencode.ai/zen/v1/chat/completions"
        case .huggingFace:
            return "https://router.huggingface.co/v1/chat/completions"
        case .copilot:
            return "https://api.individual.githubcopilot.com/chat/completions"
        case .ollama:
            return "" // URL is configurable, stored in UserDefaults
        case .ollamaCloud:
            return "https://ollama.com/v1/chat/completions"
        case .customOpenAI:
            return "" // URL is configurable, stored in UserDefaults
        case .localGemma:
            return "" // On-device, no URL needed
        case .localMLX:
            return "" // On-device, no URL needed
        }
    }

    /// Default Ollama server URL
    public static let ollamaDefaultServerURL = "http://host:11434"

    public var defaultModel: String {
        switch self {
        case .apple:
            return "foundation-model"
        case .cerebras:
            return "llama3.1-8b"
        case .groq:
            return "openai/gpt-oss-120b"
        case .gemini:
            return "gemini-3.5-flash"
        case .anthropic:
            return "claude-sonnet-4-6"
        case .openAI:
            return "gpt-5.5"
        case .grok:
            return "grok-4.20-beta"
        case .zai:
            return "glm-5"
        case .kimi:
            return "kimi-k2.5"
        case .minimax:
            return "MiniMax-M3"
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
        case .gladia:
            return "solaria-1"
        case .speechmatics:
            return "speechmatics-batch-v2"
        case .cohere:
            return "cohere-transcribe-03-2026"
        case .cartesia:
            return "ink-whisper"
        case .assemblyAI:
            return "universal-3-pro"
        case .vercelAIGateway:
            // Note: Vercel AI Gateway uses "provider/model" format with dots for versions
            // (e.g., "claude-sonnet-4.6") unlike direct Anthropic API which uses hyphens
            // (e.g., "claude-sonnet-4-6"). Models are fetched dynamically, so this must
            // match Vercel's actual naming convention.
            return "anthropic/claude-sonnet-4.6"
        case .opencodeZen:
            // A free model so a brand-new key (no payment method) verifies and
            // works out of the box. See `opencodeZenFreeModels`.
            return "big-pickle"
        case .huggingFace:
            return "openai/gpt-oss-120b"
        case .copilot:
            return "gpt-4o"
        case .ollama:
            return "llama3.2"
        case .ollamaCloud:
            return "gpt-oss:120b"
        case .customOpenAI:
            return "" // Model is configurable, stored in UserDefaults
        case .localGemma:
            return "gemma-4-E2B"
        case .localMLX:
            return "qwen3.5-2b-mlx"
        }
    }

    // MARK: - Keychain

    /// Keychain account name for this provider's API key.
    /// Must match the macOS app's `APIKeyManager` key identifiers for iCloud Keychain sync.
    public var keychainKey: String {
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
        case .minimax: "minimaxAPIKey"
        case .elevenLabs: "elevenLabsAPIKey"
        case .deepgram: "deepgramAPIKey"
        case .mistral: "mistralAPIKey"
        case .soniox: "sonioxAPIKey"
        case .gladia: "gladiaAPIKey"
        case .speechmatics: "speechmaticsAPIKey"
        case .cohere: "cohereAPIKey"
        case .cartesia: "cartesiaAPIKey"
        case .assemblyAI: "assemblyaiAPIKey"
        case .vercelAIGateway: "vercelAIGatewayAPIKey"
        case .opencodeZen: "opencodeZenAPIKey"
        case .huggingFace: "huggingFaceAPIKey"
        case .customOpenAI: "customOpenAIAPIKey"
        case .ollamaCloud: "ollamaCloudAPIKey"
        case .apple, .ollama, .copilot, .localGemma, .localMLX: ""
        }
    }

    public var availableModels: [String] {
        switch self {
        case .apple:
            return ["foundation-model"]
        case .cerebras:
            return [
                "gpt-oss-120b",
                "zai-glm-4.7"
            ]
        case .groq:
            return [
                "llama-3.1-8b-instant",
                "llama-3.3-70b-versatile",
                "qwen/qwen3-32b",
                "openai/gpt-oss-120b",
                "openai/gpt-oss-20b"
            ]
        case .gemini:
            return [
                "gemini-3.1-pro-preview",
                "gemini-3.5-flash",
                "gemini-3-flash-preview",
                "gemini-3.1-flash-lite",
                "gemini-2.5-pro",
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite"
            ]
        case .anthropic:
            return [
                "claude-opus-4-8",
                "claude-opus-4-7",
                "claude-opus-4-6",
                "claude-sonnet-4-6",
                "claude-sonnet-4-5",
                "claude-haiku-4-5"
            ]
        case .openAI:
            return [
                "gpt-5.5",
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
                "grok-4.3",
                "grok-4.20-reasoning",
                "grok-4.20-non-reasoning",
                "grok-4.20-multi-agent",
                "grok-build-0.1"
            ]
        case .zai:
            return [
                "glm-5.1",
                "glm-5-turbo",
                "glm-5",
                "glm-4.7",
                "glm-4.6"
            ]
        case .kimi:
            return [
                "kimi-k2.6",
                "kimi-k2.5",
                "moonshot-v1-128k",
                "moonshot-v1-32k",
                "moonshot-v1-8k"
            ]
        case .minimax:
            return [
                "MiniMax-M3",
                "MiniMax-M2.7",
                "MiniMax-M2.7-highspeed",
                "MiniMax-M2.5",
                "MiniMax-M2.5-highspeed",
                "MiniMax-M2.1",
                "MiniMax-M2.1-highspeed",
                "MiniMax-M2"
            ]
        case .elevenLabs:
            return []
        case .deepgram:
            return []
        case .mistral:
            return [
                "mistral-large-latest",
                "mistral-medium-latest",
                "mistral-small-latest"
            ]
        case .soniox:
            return []
        case .gladia:
            return [] // Transcription-only provider, no chat models
        case .speechmatics:
            return [] // Transcription-only provider, no chat models
        case .cohere:
            return [] // Transcription-only provider, no chat models
        case .cartesia:
            return [] // Transcription-only provider, no chat models
        case .assemblyAI:
            return [] // Transcription-only provider, no chat models
        case .openRouter:
            return []
        case .vercelAIGateway:
            return []
        case .opencodeZen:
            // Curated OpenCode Zen catalog: the always-free models first, then
            // the pay-as-you-go models. Tier classification lives in
            // `opencodeZenFreeModels` / `opencodeZenPaidModels` below.
            return Self.opencodeZenFreeModels + Self.opencodeZenPaidModels
        case .huggingFace:
            return []
        case .copilot:
            return [] // Models are fetched dynamically from Copilot API
        case .ollama:
            return [] // Models are fetched dynamically from Ollama server
        case .ollamaCloud:
            // Curated fallback list of Ollama Cloud models. Refreshed at runtime
            // via `AIService.fetchOllamaCloudModels()` once an API key is added.
            return [
                "gpt-oss:120b",
                "gpt-oss:20b",
                "deepseek-v3.1:671b",
                "qwen3-coder:480b",
                "qwen3-vl:235b",
                "glm-4.6",
                "kimi-k2:1t",
                "minimax-m2"
            ]
        case .customOpenAI:
            return [] // Model is configured by user
        case .localGemma:
            return ["gemma-4-E2B", "gemma-4-E4B"]
        case .localMLX:
            return ["qwen3.5-2b-mlx", "qwen3.5-0.8b-mlx", "phi-4-mini-mlx", "llama-3.2-1b-mlx", "llama-3.2-3b-mlx", "ministral-3b-mlx", "falcon3-3b-mlx", "granite-3.3-2b-mlx"]
        }
    }
}

// MARK: - Ollama Cloud free / subscription tiers

public extension AIProvider {
    /// Ollama Cloud models usable with a free API key (no paid subscription).
    ///
    /// Verified against the live Ollama Cloud API on 2026-06-19: each model was
    /// sent a minimal chat request and returned HTTP 200. The split tracks
    /// roughly with model size/recency - open-weight community models are free
    /// while the newest flagship models require a subscription.
    /// See https://ollama.com/upgrade.
    static let ollamaCloudFreeModels: [String] = [
        "gpt-oss:20b",
        "gpt-oss:120b",
        "gemma3:4b",
        "gemma3:12b",
        "gemma3:27b",
        "gemma4:31b",
        "qwen3-coder-next",
        "qwen3-coder:480b",
        "nemotron-3-nano:30b",
        "nemotron-3-super",
        "nemotron-3-ultra",
        "ministral-3:3b",
        "ministral-3:8b",
        "ministral-3:14b",
        "devstral-small-2:24b",
        "devstral-2:123b",
        "minimax-m2.1",
        "minimax-m2.5",
        "minimax-m3",
        "glm-4.7",
        "rnj-1:8b"
    ]

    /// Ollama Cloud models that require a paid subscription. Selecting one
    /// without a plan returns HTTP 403 "this model requires a subscription,
    /// upgrade for access" (verified 2026-06-19). See https://ollama.com/upgrade.
    static let ollamaCloudSubscriptionModels: [String] = [
        "deepseek-v3.1:671b",
        "deepseek-v3.2",
        "deepseek-v4-flash",
        "deepseek-v4-pro",
        "kimi-k2.5",
        "kimi-k2.6",
        "kimi-k2.7-code",
        "glm-5",
        "glm-5.1",
        "glm-5.2",
        "qwen3.5:397b",
        "mistral-large-3:675b",
        "minimax-m2.7",
        "gemini-3-flash-preview"
    ]

    /// Whether the given Ollama Cloud model name is usable on the free tier.
    ///
    /// Unknown / newly-added model names are treated as free (optimistic): the
    /// app surfaces the real "requires a subscription" error at request time, so
    /// a stale classification never blocks a genuinely-free model.
    static func isOllamaCloudModelFree(_ model: String) -> Bool {
        !ollamaCloudSubscriptionModels.contains(model)
    }
}

// MARK: - OpenCode Zen free / paid tiers

public extension AIProvider {
    /// OpenCode Zen models usable with the API key alone, at no cost (no payment
    /// method required).
    ///
    /// Verified against the live Zen API on 2026-06-19: each model returned
    /// HTTP 200 with `"cost": "0"` and no "No payment method" error. `big-pickle`
    /// is Zen's promoted anonymous free model (currently routes to
    /// deepseek-v4-flash). See https://opencode.ai/zen.
    ///
    /// Note: the catalog also lists `minimax-m3-free` and `qwen3.6-plus-free`,
    /// but their free promotion has ended - both now return "Free promotion has
    /// ended ... subscribe to OpenCode Go", so they are intentionally omitted.
    static let opencodeZenFreeModels: [String] = [
        "big-pickle",
        "deepseek-v4-flash-free",
        "nemotron-3-ultra-free",
        "mimo-v2.5-free",
        "north-mini-code-free"
    ]

    /// OpenCode Zen models that bill pay-as-you-go and require a workspace with a
    /// payment method. Selecting one without billing set up returns
    /// "No payment method. Add a payment method here ..." (verified 2026-06-19).
    /// Token pricing passes through the provider's list price with zero markup.
    static let opencodeZenPaidModels: [String] = [
        "claude-fable-5",
        "claude-opus-4-8",
        "claude-opus-4-7",
        "claude-sonnet-4-6",
        "claude-sonnet-4-5",
        "claude-haiku-4-5",
        "gpt-5.5",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.1",
        "gpt-5-nano",
        "gemini-3.1-pro",
        "gemini-3.5-flash",
        "gemini-3-flash",
        "deepseek-v4-pro",
        "deepseek-v4-flash",
        "glm-5.1",
        "glm-5",
        "kimi-k2.6",
        "kimi-k2.5",
        "minimax-m2.7",
        "minimax-m2.5",
        "qwen3.6-plus",
        "qwen3.5-plus",
        "grok-build-0.1"
    ]

    /// Whether the given OpenCode Zen model is usable for free with the API key.
    ///
    /// Uses an explicit allowlist (unlike Ollama Cloud's deny-list): Zen's free
    /// set is a small, fixed promotion while the paid catalog is large and
    /// growing, so anything not explicitly free is treated as pay-as-you-go.
    static func isOpencodeZenModelFree(_ model: String) -> Bool {
        opencodeZenFreeModels.contains(model)
    }
}
