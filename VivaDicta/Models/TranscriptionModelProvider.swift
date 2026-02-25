//
//  TranscriptionModelProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.06
//

import Foundation
//import FluidAudio

enum TranscriptionModelProvider: String, Sendable, Codable, CaseIterable, Identifiable {
    case parakeet
    case whisperKit
    case openAI
    case groq
    case elevenLabs
    case deepgram
    case mistral
    case gemini
    case soniox
    case customTranscription
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .parakeet:
            "Parakeet"
        case .whisperKit:
            "Whisper"
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
        case .customTranscription:
            "Custom"
        }
    }
    
    static let localProviders: [TranscriptionModelProvider] = [
        .whisperKit,
        .parakeet]
    
    static let cloudProviders: [TranscriptionModelProvider] = [
        .groq,
        .mistral,
        .gemini,
        .deepgram,
        .openAI,
        .elevenLabs,
        .soniox,
        .customTranscription]
    
    var cloudTranscriptionModelsNames: [String] {
        switch self {
        case .parakeet, .whisperKit:
            return []
            
        default:
            return TranscriptionModelProvider.allCloudModels.compactMap { $0.provider == self ? $0.name : nil }
        }
    }
    
    func getTranscriptionModelDisplayName(_ modelName: String) -> String {
        switch self {
        case .parakeet:
            guard let model = TranscriptionModelProvider.allParakeetModels.first(where: {$0.name == modelName}) else { return modelName }
            return model.displayName

        case .whisperKit:
            guard let model = TranscriptionModelProvider.allWhisperKitModels.first(where: {$0.name == modelName}) else { return modelName }
            return model.displayName

        case .customTranscription:
            // Custom transcription uses the display name "Custom"
            // The actual model name is shown in the configuration screen
            return "Custom"

        default:
            guard let model = TranscriptionModelProvider.allCloudModels.first(where: {$0.name == modelName}) else { return modelName }
            return model.displayName
        }
    }
    
    var defaultCloudTranscriptionModel: String? {
        switch self {
        case .groq: "whisper-large-v3-turbo"
        case .mistral: "voxtral-mini-latest"
        case .gemini: "gemini-3-flash-preview"
        case .deepgram: "nova-3"
        case .elevenLabs: "scribe_v2"
        case .openAI: "gpt-4o-mini-transcribe"
        case .soniox: "stt-async-v4"
        default: nil
        }
    }

    /// Discovers the first cloud transcription provider with a valid API key.
    /// Iterates providers in `cloudProviders` order, validates each key with a lightweight
    /// network call before returning. Returns nil if no valid key is found.
    static func discoverValidatedCloudProvider() async -> (provider: TranscriptionModelProvider, modelName: String)? {
        for provider in cloudProviders {
            guard let aiProvider = provider.mappedAIProvider,
                  let modelName = provider.defaultCloudTranscriptionModel,
                  let apiKey = aiProvider.apiKey else { continue }
            if await provider.validateTranscriptionAPIKey(apiKey) {
                return (provider, modelName)
            }
        }
        return nil
    }

    /// Validates a transcription API key with a lightweight GET request.
    private func validateTranscriptionAPIKey(_ key: String) async -> Bool {
        guard let (request, validStatusCode) = validationRequest(forKey: key) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == validStatusCode
        } catch {
            return false
        }
    }

    /// Builds a lightweight validation request for each transcription provider.
    private func validationRequest(forKey key: String) -> (URLRequest, Int)? {
        var request: URLRequest
        switch self {
        case .groq:
            request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .mistral:
            request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/models")!)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .gemini:
            request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(key)")!)
        case .deepgram:
            request = URLRequest(url: URL(string: "https://api.deepgram.com/v1/auth/token")!)
            request.addValue("Token \(key)", forHTTPHeaderField: "Authorization")
        case .openAI:
            request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .elevenLabs:
            request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/user")!)
            request.addValue(key, forHTTPHeaderField: "xi-api-key")
        case .soniox:
            request = URLRequest(url: URL(string: "https://api.soniox.com/v1/files")!)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        default:
            return nil
        }
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        return (request, 200)
    }

    public var mappedAIProvider: AIProvider? {
        switch self {
        case .openAI:
            return .openAI
        case .groq:
            return .groq
        case .elevenLabs:
            return .elevenLabs
        case .deepgram:
            return .deepgram
        case .mistral:
            return .mistral
        case .gemini:
            return .gemini
        case .soniox:
            return .soniox
        default:
            return nil
        }
    }
    
    @MainActor static let allModels: [any TranscriptionModel] = allParakeetModels + allWhisperKitModels + allCloudModels
    
    
    static var allCloudModels: [CloudModel] {
        [
            CloudModel(
                name: "whisper-large-v3-turbo",
                displayName: "Whisper Large Turbo",
                description: "Ultra-fast Whisper inference on Groq's LPU achieving 200x+ real-time speed. Free tier with generous daily limits",
                provider: .groq,
                recommended: true,
                speed: 1.0,
                accuracy: 0.92,
                cost: 0.05,  // $0.000667/min paid tier - Free tier available with 30K tokens/min, 14.4K requests/day (refreshes daily, basically free for personal use)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "voxtral-mini-latest",
                displayName: "Voxtral Mini V2",
                description: "State-of-the-art transcription with ~4% WER, speaker diarization, and 3-hour audio support. New signups get $500 free credits",
                provider: .mistral,
                recommended: true,
                speed: 0.95,
                accuracy: 0.97,
                cost: 0.45,  // $0.003/min - New signups get $500 free credits (~166,666 mins)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "gemini-3-pro-preview",
                displayName: "Gemini 3 Pro",
                description: "Google's latest multimodal model with enhanced transcription capabilities.",
                provider: .gemini,
                speed: 0.75,
                accuracy: 0.97,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-3-flash-preview",
                displayName: "Gemini 3 Flash",
                description: "Google's newest fast model combining intelligence with superior speed.",
                provider: .gemini,
                speed: 0.92,
                accuracy: 0.95,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            // Gemini Models
            CloudModel(
                name: "gemini-2.5-pro",
                displayName: "Gemini 2.5 Pro",
                description: "Google's advanced model with superior noise filtering and speaker diarization. Free tier available + $300 Google Cloud credits",
                provider: .gemini,
                speed: 0.7,
                accuracy: 0.96,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-2.5-flash",
                displayName: "Gemini 2.5 Flash",
                description: "Google's fastest model with 887 tokens/sec output and cost-effective batch processing. Free tier available + $300 Google Cloud credits",
                provider: .gemini,
                speed: 0.9,
                accuracy: 0.7,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "nova-3-multilingual",
                displayName: "Nova 3 Multi-language",
                description: "First AI model with real-time switching across 10+ languages. New signups get $200 free credits (~38,460 mins)",
                provider: .deepgram,
                speed: 0.95,
                accuracy: 0.95,
                cost: 0.75,  // $0.0052/min - New signups get $200 free credits (~38,460 mins)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "nova-3",
                displayName: "Nova 3",
                description: "Latest generation model with improved accuracy and speed for English transcription. New signups get $200 free credits (~46,511 mins)",
                provider: .deepgram,
                speed: 0.95,
                accuracy: 0.95,
                cost: 0.65,  // $0.0043/min - New signups get $200 free credits (~46,511 mins)
                supportManyLanguages: false,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false)
            ),
            
            CloudModel(
                name: "nova-3-medical",
                displayName: "Nova 3 Medical",
                description: "HIPAA-compliant clinical model with 3.44% WER and medical terminology expertise. New signups get $200 free credits (~25,974 mins)",
                provider: .deepgram,
                speed: 0.9,
                accuracy: 0.97,
                cost: 1.0,  // $0.0077/min - New signups get $200 free credits (~25,974 mins)
                supportManyLanguages: false,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false)
            ),
            
            CloudModel(
                name: "nova-2",
                displayName: "Nova 2",
                description: "Industry-leading low-latency model optimized for real-time streaming applications. New signups get $200 free credits (~46,511 mins)",
                provider: .deepgram,
                speed: 0.9,
                accuracy: 0.93,
                cost: 0.65,  // $0.0043/min - New signups get $200 free credits (~46,511 mins)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "scribe_v2",
                displayName: "Scribe v2",
                description: "Enhanced accuracy model supporting 92+ languages with improved accent handling. Free tier: ~150 mins/month",
                provider: .elevenLabs,
                speed: 0.75,
                accuracy: 1.0,
                cost: 0.95,  // $0.0067/min - Free tier: 10K chars/month (~2.5 hours STT, non-commercial use only)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "scribe_v1",
                displayName: "Scribe v1",
                description: "Industry-leading accuracy with excellent accent handling for batch transcription. Free tier: ~150 mins/month",
                provider: .elevenLabs,
                speed: 0.7,
                accuracy: 1.0,
                cost: 0.95,  // $0.0067/min - Free tier: 10K chars/month (~2.5 hours STT, non-commercial use only)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "gpt-4o-transcribe",
                displayName: "GPT-4o Transcribe",
                description: "OpenAI's latest model with reduced hallucinations and enhanced accuracy across all languages",
                provider: .openAI,
                speed: 0.7,
                accuracy: 0.95,
                cost: 0.9,  // $0.006/min
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gpt-4o-mini-transcribe",
                displayName: "GPT-4o Mini Transcribe",
                description: "Cost-effective OpenAI model for high-volume transcription with good accuracy",
                provider: .openAI,
                speed: 0.75,
                accuracy: 0.9,
                cost: 0.4,  // $0.003/min - half the price of GPT-4o
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "whisper-1",
                displayName: "Whisper",
                description: "OpenAI's legacy Whisper model with proven reliability for general transcription",
                provider: .openAI,
                speed: 0.7,
                accuracy: 0.93,
                cost: 0.9,  // $0.006/min
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            CloudModel(
                name: "stt-async-v4",
                displayName: "Soniox (stt-async-v4)",
                description: "Soniox asynchronous transcription model v4 with human-parity accuracy across 60+ languages.",
                provider: .soniox,
                speed: 0.8,
                accuracy: 0.97,
                cost: 0.25,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            )
        ]
    }
    
    static func getLanguageDictionary(supportManyLanguages: Bool) -> [String: String] {
        supportManyLanguages ? allLanguages : ["en": "English"]
    }
    
    static var allParakeetModels: [ParakeetModel] {
        [
            ParakeetModel(
                name: "parakeet-tdt-0.6b-v3",
                displayName: "Nvidia Parakeet V3",
                description: "NVIDIA's ultra-fast model supporting 25 most common languages with automatic language detection",
                recommended: true,
                size: "494 MB",
                speed: 0.95,
                accuracy: 0.8,
                ramUsage: 0.8,
                supportedLanguages: allLanguages
            ),
            ParakeetModel(
                name: "parakeet-tdt-0.6b-v2",
                displayName: "Nvidia Parakeet V2",
                description: "NVIDIA's blazing-fast English model with superior accuracy for real-time transcription",
                size: "474 MB",
                speed: 0.99,
                accuracy: 0.90,
                ramUsage: 0.8,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false)
            ),
        ]
    }
    
    static var allWhisperKitModels: [WhisperKitModel] {
        [
            WhisperKitModel(
                name: "whisperkit-tiny",
                displayName: "Whisper Tiny",
                description: "Smallest and fastest Whisper model, suitable for quick transcriptions",
                size: "76 MB",
                speed: 1.0,
                accuracy: 0.6,
                ramUsage: 0.3,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-tiny"
            ),
            WhisperKitModel(
                name: "whisperkit-tiny.en",
                displayName: "Whisper Tiny (English)",
                description: "English-optimized tiny model for fast English transcription",
                size: "76 MB",
                speed: 1.0,
                accuracy: 0.70,
                ramUsage: 0.3,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false),
                whisperKitModelName: "openai_whisper-tiny.en"
            ),
            
            WhisperKitModel(
                name: "whisperkit-base",
                displayName: "Whisper Base",
                description: "Balanced model offering good speed and accuracy, supports multiple languages",
                size: "140 MB",
                speed: 0.9,
                accuracy: 0.72,
                ramUsage: 0.5,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-base"
            ),
            WhisperKitModel(
                name: "whisperkit-base.en",
                displayName: "Whisper Base (English)",
                description: "Base model optimized for English, good balance between speed and accuracy",
                size: "140 MB",
                speed: 0.9,
                accuracy: 0.75,
                ramUsage: 0.5,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false),
                whisperKitModelName: "openai_whisper-base.en"
            ),
            
            WhisperKitModel(
                name: "whisperkit-large-v3-v20240930_626MB",
                displayName: "Whisper Large",
                description: "Highest accuracy model with comprehensive language support",
                size: "626 MB",
                speed: 0.50,
                accuracy: 1.0,
                ramUsage: 2.0,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-large-v3-v20240930_626MB"
            ),
            
            WhisperKitModel(
                name: "whisperkit-large-v3-v20240930_turbo_632MB",
                displayName: "Whisper Large Turbo",
                description: "Optimized large model with faster speed and excellent accuracy",
                recommended: true,
                size: "632 MB",
                speed: 0.85,
                accuracy: 0.95,
                ramUsage: 1.2,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-large-v3-v20240930_turbo_632MB"
            ),
        ]
    }
    
    enum AppLanguage: String, CaseIterable, Identifiable {
        case en, fr, jp, ko, zhHans = "zh-Hans", zhHant = "zh-Hant"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .en: return "English"
            case .fr: return "French"
            case .jp: return "Japanese"
            case .ko: return "Korean"
            case .zhHans: return "Simplified Chinese"
            case .zhHant: return "Traditional Chinese"
            }
        }
    }
    
    static let allLanguages = [
        "auto": "Auto-detect",
        "af": "Afrikaans",
        "ar": "Arabic",
        "hy": "Armenian",
        "az": "Azerbaijani",
        "be": "Belarusian",
        "bs": "Bosnian",
        "bg": "Bulgarian",
        "ca": "Catalan",
        "zh": "Chinese",
        "hr": "Croatian",
        "cs": "Czech",
        "da": "Danish",
        "nl": "Dutch",
        "en": "English",
        "et": "Estonian",
        "fi": "Finnish",
        "fr": "French",
        "gl": "Galician",
        "de": "German",
        "el": "Greek",
        "he": "Hebrew",
        "hi": "Hindi",
        "hu": "Hungarian",
        "is": "Icelandic",
        "id": "Indonesian",
        "it": "Italian",
        "ja": "Japanese",
        "kn": "Kannada",
        "kk": "Kazakh",
        "ko": "Korean",
        "lv": "Latvian",
        "lt": "Lithuanian",
        "mk": "Macedonian",
        "ms": "Malay",
        "mr": "Marathi",
        "mi": "Maori",
        "ne": "Nepali",
        "no": "Norwegian",
        "fa": "Persian",
        "pl": "Polish",
        "pt": "Portuguese",
        "ro": "Romanian",
        "ru": "Russian",
        "sr": "Serbian",
        "sk": "Slovak",
        "sl": "Slovenian",
        "es": "Spanish",
        "sw": "Swahili",
        "sv": "Swedish",
        "tl": "Tagalog",
        "ta": "Tamil",
        "th": "Thai",
        "tr": "Turkish",
        "uk": "Ukrainian",
        "ur": "Urdu",
        "vi": "Vietnamese",
    ]
    
    static let languageFlags: [String: String] = [
        "auto": "🌐",
        "af": "🇿🇦",
        "ar": "🇸🇦",
        "hy": "🇦🇲",
        "az": "🇦🇿",
        "be": "🇧🇾",
        "bs": "🇧🇦",
        "bg": "🇧🇬",
        "ca": "🇪🇸",
        "zh": "🇨🇳",
        "hr": "🇭🇷",
        "cs": "🇨🇿",
        "da": "🇩🇰",
        "nl": "🇳🇱",
        "en": "🇺🇸",
        "et": "🇪🇪",
        "fi": "🇫🇮",
        "fr": "🇫🇷",
        "gl": "🇪🇸",
        "de": "🇩🇪",
        "el": "🇬🇷",
        "he": "🇮🇱",
        "hi": "🇮🇳",
        "hu": "🇭🇺",
        "is": "🇮🇸",
        "id": "🇮🇩",
        "it": "🇮🇹",
        "ja": "🇯🇵",
        "kn": "🇮🇳",
        "kk": "🇰🇿",
        "ko": "🇰🇷",
        "lv": "🇱🇻",
        "lt": "🇱🇹",
        "mk": "🇲🇰",
        "ms": "🇲🇾",
        "mr": "🇮🇳",
        "mi": "🇳🇿",
        "ne": "🇳🇵",
        "no": "🇳🇴",
        "fa": "🇮🇷",
        "pl": "🇵🇱",
        "pt": "🇵🇹",
        "ro": "🇷🇴",
        "ru": "🇷🇺",
        "sr": "🇷🇸",
        "sk": "🇸🇰",
        "sl": "🇸🇮",
        "es": "🇪🇸",
        "sw": "🇹🇿",
        "sv": "🇸🇪",
        "tl": "🇵🇭",
        "ta": "🇮🇳",
        "th": "🇹🇭",
        "tr": "🇹🇷",
        "uk": "🇺🇦",
        "ur": "🇵🇰",
        "vi": "🇻🇳",
    ]
    
    static func languageWithFlag(_ code: String, name: String) -> String {
        let flag = languageFlags[code] ?? "🏳️"
        return "\(flag) \(name)"
    }
}
