//
//  TranscriptionModelProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.06
//

import Foundation

enum TranscriptionModelProvider: String, Sendable, Codable, CaseIterable, Identifiable {
    case local
    case parakeet
    case openAI
    case groq
    case elevenLabs
    case deepgram
    case gemini
    
    var id: Self { self }
    
    var cloudTranscriptionModelsNames: [String] {
        switch self {
        case .local, .parakeet:
            return []
            
        default:
            return TranscriptionModelProvider.allCloudModels.compactMap { $0.provider == self ? $0.name : nil }
        }
    }
    
    func getTranscriptionModelDisplayName(_ modelName: String) -> String {
        switch self {
        case .local:
            guard let model = TranscriptionModelProvider.allLocalModels.first(where: {$0.name == modelName}) else { return modelName }
            return model.displayName
            
        case .parakeet:
            return modelName
            
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
        case .local, .parakeet:
            return nil
        }
    }
    
    static let allModels: [any TranscriptionModel] = allLocalModels + allCloudModels
    
    static var allLocalModels: [WhisperLocalModel] {
        [
            WhisperLocalModel(
                name: "tiny",
                displayName: "Tiny",
                description: "Tiny model, fastest, least accurate",
                provider: .local,
                size: "75 MB",
                speed: 0.95,
                accuracy: 0.6,
                ramUsage: 0.3,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: true),
            ),
            
            WhisperLocalModel(
                name: "tiny.en",
                displayName: "Tiny (English)",
                description: "Tiny model optimized for English, fastest, least accurate",
                provider: .local,
                size: "75 MB",
                speed: 0.95,
                accuracy: 0.65,
                ramUsage: 0.3,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false)
            ),
            WhisperLocalModel(
                name: "base",
                displayName: "Base",
                description: "Base model, good balance between speed and accuracy, supports multiple languages",
                provider: .local,
                size: "142 MB",
                speed: 0.85,
                accuracy: 0.72,
                ramUsage: 0.5,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: true)
            ),
            WhisperLocalModel(
                name: "base.en",
                displayName: "Base (English)",
                description: "Base model optimized for English, good balance between speed and accuracy",
                provider: .local,
                size: "142 MB",
                speed: 0.85,
                accuracy: 0.75,
                ramUsage: 0.5,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false)
            ),
            WhisperLocalModel(
                name: "large-v2",
                displayName: "Large v2",
                description: "Large model v2, slower than Medium but more accurate",
                provider: .local,
                size: "2.9 GB",
                speed: 0.3,
                accuracy: 0.96,
                ramUsage: 3.8,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: true)
            ),
            WhisperLocalModel(
                name: "large-v3",
                displayName: "Large v3",
                description: "Large model v3, very slow but most accurate",
                provider: .local,
                size: "2.9 GB",
                speed: 0.3,
                accuracy: 0.98,
                ramUsage: 3.9,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: true)
            ),
            WhisperLocalModel(
                name: "large-v3-turbo",
                displayName: "Large v3 Turbo",
                description: "Large model v3 Turbo, faster than v3 with similar accuracy",
                provider: .local,
                size: "1.5 GB",
                speed: 0.75,
                accuracy: 0.97,
                ramUsage: 1.8,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: true)
            ),
            WhisperLocalModel(
                name: "large-v3-turbo-q5_0",
                displayName: "Large v3 Turbo (Quantized)",
                description: "Quantized version of Large v3 Turbo, faster with slightly lower accuracy",
                provider: .local,
                size: "547 MB",
                speed: 0.75,
                accuracy: 0.95,
                ramUsage: 1.0,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: true)
            ),
        ]
    }
    
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
