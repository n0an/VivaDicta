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
    case gemini
    
    var id: Self { self }
    
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

        default:
            guard let model = TranscriptionModelProvider.allCloudModels.first(where: {$0.name == modelName}) else { return modelName }
            return model.displayName
        }
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
        case .gemini:
            return .gemini
        case .parakeet, .whisperKit:
            return nil
        }
    }
    
    @MainActor static let allModels: [any TranscriptionModel] = allParakeetModels + allWhisperKitModels + allCloudModels
    
    
    static var allCloudModels: [CloudModel] {
        [
            CloudModel(
                name: "openai-gpt-4o",
                displayName: "OpenAI GPT-4o Transcribe",
                description: "OpenAI Speech-to-text model powered by GPT-4o",
                provider: .openAI,
                speed: 0.7,
                accuracy: 0.96,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "whisper-large-v3-turbo",
                displayName: "Whisper Large v3 Turbo (Groq)",
                description: "Whisper Large v3 Turbo model with Groq's lightning-speed inference",
                provider: .groq,
                speed: 0.65,
                accuracy: 0.96,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "scribe_v1",
                displayName: "Scribe v1 (ElevenLabs)",
                description: "ElevenLabs' Scribe model for fast and accurate transcription.",
                provider: .elevenLabs,
                speed: 0.7,
                accuracy: 0.98,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "nova-2",
                displayName: "Nova (Deepgram)",
                description: "Deepgram's Nova model for fast, accurate, and cost-effective transcription.",
                provider: .deepgram,
                speed: 0.9,
                accuracy: 0.95,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            // Gemini Models
            CloudModel(
                name: "gemini-2.5-pro",
                displayName: "Gemini 2.5 Pro",
                description: "Google's advanced multimodal model with high-quality transcription capabilities.",
                provider: .gemini,
                speed: 0.7,
                accuracy: 0.96,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-2.5-flash",
                displayName: "Gemini 2.5 Flash",
                description: "Google's optimized model for low-latency transcription with multimodal support.",
                provider: .gemini,
                speed: 0.9,
                accuracy: 0.94,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
        ]
    }
    
    static func getLanguageDictionary(supportManyLanguages: Bool) -> [String: String] {
        supportManyLanguages ? allLanguages : ["en": "English"]
    }
    
    static var allParakeetModels: [ParakeetModel] {
        [
            ParakeetModel(
                name: "parakeet-tdt-0.6b",
                displayName: "Parakeet",
                description: "NVIDIA's ASR model for lightning-fast transcription with multi-lingual support.",
                size: "630 MB",
                speed: 0.99,
                accuracy: 0.94,
                ramUsage: 0.8,
                supportedLanguages: allLanguages
            )
        ]
    }

    static var allWhisperKitModels: [WhisperKitModel] {
        [
            WhisperKitModel(
                name: "whisperkit-tiny",
                displayName: "WhisperKit Tiny",
                description: "Smallest and fastest WhisperKit model, suitable for quick transcriptions",
                size: "76 MB",
                speed: 0.95,
                accuracy: 0.65,
                ramUsage: 0.3,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-tiny"
            ),
            WhisperKitModel(
                name: "whisperkit-tiny.en",
                displayName: "WhisperKit Tiny (English)",
                description: "English-optimized tiny model for fast English transcription",
                size: "76 MB",
                speed: 0.95,
                accuracy: 0.70,
                ramUsage: 0.3,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false),
                whisperKitModelName: "openai_whisper-tiny.en"
            ),
            
            WhisperKitModel(
                name: "whisperkit-base",
                displayName: "WhisperKit Base",
                description: "Balanced model offering good speed and accuracy",
                size: "140 MB",
                speed: 0.85,
                accuracy: 0.75,
                ramUsage: 0.5,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-base"
            ),
            WhisperKitModel(
                name: "whisperkit-base.en",
                displayName: "WhisperKit Base (English)",
                description: "English-optimized base model with good balance",
                size: "140 MB",
                speed: 0.85,
                accuracy: 0.78,
                ramUsage: 0.5,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false),
                whisperKitModelName: "openai_whisper-base.en"
            ),
            
            WhisperKitModel(
                name: "whisperkit-small",
                displayName: "WhisperKit Small",
                description: "More accurate model with reasonable speed",
                size: "487 MB",
                speed: 0.70,
                accuracy: 0.85,
                ramUsage: 1.0,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-small"
            ),
            WhisperKitModel(
                name: "whisperkit-small.en",
                displayName: "WhisperKit Small (English)",
                description: "English-optimized small model with improved accuracy",
                size: "487 MB",
                speed: 0.70,
                accuracy: 0.88,
                ramUsage: 1.0,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false),
                whisperKitModelName: "openai_whisper-small.en"
            ),
            
            WhisperKitModel(
                name: "whisperkit-large-v3-v20240930_626MB",
                displayName: "WhisperKit Large v3 v20240930 626 MB",
                description: "Most accurate WhisperKit model with state-of-the-art performance",
                size: "626 MB",
                speed: 0.80,
                accuracy: 0.98,
                ramUsage: 3.0,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-large-v3-v20240930_626MB"
            ),
            
            WhisperKitModel(
                name: "whisperkit-large-v3-v20240930_turbo_632MB",
                displayName: "WhisperKit Large v3 Turbo v20240930 Optimized 632 MB",
                description: "Optimized for streaming with turbo inference, optimized size 632 MB",
                size: "632 MB",
                speed: 0.95,
                accuracy: 0.96,
                ramUsage: 2.0,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-large-v3-v20240930_turbo_632MB"
            ),
        ]
    }

    static let allLanguages = [
        "auto": "Auto-detect",
        "af": "Afrikaans",
        "am": "Amharic",
        "ar": "Arabic",
        "as": "Assamese",
        "az": "Azerbaijani",
        "ba": "Bashkir",
        "be": "Belarusian",
        "bg": "Bulgarian",
        "bn": "Bengali",
        "bo": "Tibetan",
        "br": "Breton",
        "bs": "Bosnian",
        "ca": "Catalan",
        "cs": "Czech",
        "cy": "Welsh",
        "da": "Danish",
        "de": "German",
        "el": "Greek",
        "en": "English",
        "es": "Spanish",
        "et": "Estonian",
        "eu": "Basque",
        "fa": "Persian",
        "fi": "Finnish",
        "fo": "Faroese",
        "fr": "French",
        "gl": "Galician",
        "gu": "Gujarati",
        "ha": "Hausa",
        "haw": "Hawaiian",
        "he": "Hebrew",
        "hi": "Hindi",
        "hr": "Croatian",
        "ht": "Haitian Creole",
        "hu": "Hungarian",
        "hy": "Armenian",
        "id": "Indonesian",
        "is": "Icelandic",
        "it": "Italian",
        "ja": "Japanese",
        "jw": "Javanese",
        "ka": "Georgian",
        "kk": "Kazakh",
        "km": "Khmer",
        "kn": "Kannada",
        "ko": "Korean",
        "la": "Latin",
        "lb": "Luxembourgish",
        "ln": "Lingala",
        "lo": "Lao",
        "lt": "Lithuanian",
        "lv": "Latvian",
        "mg": "Malagasy",
        "mi": "Maori",
        "mk": "Macedonian",
        "ml": "Malayalam",
        "mn": "Mongolian",
        "mr": "Marathi",
        "ms": "Malay",
        "mt": "Maltese",
        "my": "Myanmar",
        "ne": "Nepali",
        "nl": "Dutch",
        "nn": "Norwegian Nynorsk",
        "no": "Norwegian",
        "oc": "Occitan",
        "pa": "Punjabi",
        "pl": "Polish",
        "ps": "Pashto",
        "pt": "Portuguese",
        "ro": "Romanian",
        "ru": "Russian",
        "sa": "Sanskrit",
        "sd": "Sindhi",
        "si": "Sinhala",
        "sk": "Slovak",
        "sl": "Slovenian",
        "sn": "Shona",
        "so": "Somali",
        "sq": "Albanian",
        "sr": "Serbian",
        "su": "Sundanese",
        "sv": "Swedish",
        "sw": "Swahili",
        "ta": "Tamil",
        "te": "Telugu",
        "tg": "Tajik",
        "th": "Thai",
        "tk": "Turkmen",
        "tl": "Tagalog",
        "tr": "Turkish",
        "tt": "Tatar",
        "uk": "Ukrainian",
        "ur": "Urdu",
        "uz": "Uzbek",
        "vi": "Vietnamese",
        "yi": "Yiddish",
        "yo": "Yoruba",
        "yue": "Cantonese",
        "zh": "Chinese",
    ]
}
