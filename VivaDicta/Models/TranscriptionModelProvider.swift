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
        case .mistral:
            return .mistral
        case .gemini:
            return .gemini
        default:
            return nil
        }
    }
    
    @MainActor static let allModels: [any TranscriptionModel] = allParakeetModels + allWhisperKitModels + allCloudModels
    
    
    static var allCloudModels: [CloudModel] {
        [
            CloudModel(
                name: "openai-gpt-4o",
                displayName: "OpenAI GPT-4o Transcribe",
                description: "OpenAI's latest model with reduced hallucinations and enhanced multilingual accuracy",
                provider: .openAI,
                speed: 0.7,
                accuracy: 0.96,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "whisper-large-v3-turbo",
                displayName: "Whisper Large v3 Turbo (Groq)",
                description: "Ultra-fast Whisper inference on Groq's LPU achieving 200x+ real-time speed",
                provider: .groq,
                speed: 0.95,
                accuracy: 0.92,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "scribe_v1",
                displayName: "Scribe v1 (ElevenLabs)",
                description: "Industry-leading accuracy with excellent accent handling for batch transcription",
                provider: .elevenLabs,
                speed: 0.7,
                accuracy: 0.965,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "scribe_v2",
                displayName: "Scribe v2 (ElevenLabs)",
                description: "Enhanced accuracy model supporting 92+ languages with improved accent handling",
                provider: .elevenLabs,
                speed: 0.75,
                accuracy: 0.97,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "nova-2",
                displayName: "Nova (Deepgram)",
                description: "Industry-leading low-latency model optimized for real-time streaming applications",
                provider: .deepgram,
                speed: 0.9,
                accuracy: 0.93,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "nova-3-medical",
                displayName: "Nova-3 Medical (Deepgram)",
                description: "HIPAA-compliant clinical model with 3.44% WER and medical terminology expertise",
                provider: .deepgram,
                speed: 0.9,
                accuracy: 0.965,
                supportManyLanguages: false,
                supportedLanguages: getLanguageDictionary(supportManyLanguages: false)
            ),
            
            CloudModel(
                name: "voxtral-mini-latest",
                displayName: "Voxtral Mini (Mistral)",
                description: "Open-source 3B model outperforming Whisper v3 at $0.001/min with 30-min context",
                provider: .mistral,
                speed: 0.85,
                accuracy: 0.95,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            
            // Gemini Models
            CloudModel(
                name: "gemini-2.5-pro",
                displayName: "Gemini 2.5 Pro",
                description: "Google's advanced model with superior noise filtering and speaker diarization",
                provider: .gemini,
                speed: 0.7,
                accuracy: 0.96,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-2.5-flash",
                displayName: "Gemini 2.5 Flash",
                description: "Google's fastest model with 887 tokens/sec output and cost-effective batch processing",
                provider: .gemini,
                speed: 0.9,
                accuracy: 0.94,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "stt-async-v3",
                displayName: "Soniox Async v3",
                description: "Robust real-world audio handling for 60+ languages with 5-hour duration support",
                provider: .soniox,
                speed: 0.8,
                accuracy: 0.935,
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
                description: "NVIDIA's ultra-fast multilingual model supporting 25 languages with automatic language detection",
                size: "494 MB",
                speed: 0.99,
                accuracy: 0.88,
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
                speed: 0.95,
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
                speed: 0.95,
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
                speed: 0.85,
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
                speed: 0.85,
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
                speed: 0.60,
                accuracy: 0.98,
                ramUsage: 2.0,
                supportedLanguages: allLanguages,
                whisperKitModelName: "openai_whisper-large-v3-v20240930_626MB"
            ),
            
            WhisperKitModel(
                name: "whisperkit-large-v3-v20240930_turbo_632MB",
                displayName: "Whisper Large Turbo",
                description: "Optimized large model with faster speed and excellent accuracy",
                size: "632 MB",
                speed: 0.75,
                accuracy: 0.95,
                ramUsage: 1.2,
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
