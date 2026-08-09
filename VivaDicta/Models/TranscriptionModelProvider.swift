//
//  TranscriptionModelProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.06
//

import Foundation
import AICore

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
    case gladia
    case speechmatics
    case cohere
    case cartesia
    case xai
    case assemblyAI
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
        case .gladia:
            "Gladia"
        case .speechmatics:
            "Speechmatics"
        case .cohere:
            "Cohere"
        case .cartesia:
            "Cartesia"
        case .xai:
            "xAI"
        case .assemblyAI:
            "AssemblyAI"
        case .customTranscription:
            "Custom"
        }
    }
    
    static let localProviders: [TranscriptionModelProvider] = [
        .whisperKit,
        .parakeet]

    /// Soniox's current realtime model. Declared here rather than on
    /// `SonioxRealtimeSTTClient` because this file is also compiled into the
    /// app extensions, which don't link the app-only realtime client.
    ///
    /// Soniox retired `stt-rt-v4` on 2026-06-30; it still resolves as an alias
    /// to v5, but name the current model explicitly rather than depend on that
    /// aliasing surviving.
    /// `nonisolated` so the realtime client - an actor - can read it without
    /// hopping to MainActor just to look up a string constant.
    nonisolated static let sonioxRealtimeModel = "stt-rt-v5"

    /// Soniox's current async/batch model, used by the upload-and-poll path.
    nonisolated static let sonioxAsyncModel = "stt-async-v5"

    /// Models that transcribe over a live socket while the user speaks, rather
    /// than uploading the finished file. These need the engine-backed capture
    /// path - `AVAudioRecorder` hands out no buffers to stream.
    static func isStreamingModel(_ modelName: String) -> Bool {
        modelName == sonioxRealtimeModel
    }

    /// The model to send to a batch/upload endpoint for a given selection.
    /// Realtime slugs are rejected by Soniox's async `/v1/transcriptions` API,
    /// so a realtime selection maps to its async counterpart whenever the
    /// upload path runs - the keyboard flow, and the fallback after a dropped
    /// socket. Everything else passes through untouched.
    static func asyncEquivalent(of modelName: String) -> String {
        isStreamingModel(modelName) ? sonioxAsyncModel : modelName
    }
    
    static let cloudProviders: [TranscriptionModelProvider] = [
        .groq,
        .soniox,
        .gladia,
        .speechmatics,
        .assemblyAI,
        .mistral,
        .deepgram,
        .cohere,
        .xai,
        .cartesia,
        .elevenLabs,
        .gemini,
        .openAI,
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
            let normalized = TranscriptionModelProvider.normalizedCloudModelName(modelName)
            guard let model = TranscriptionModelProvider.allCloudModels.first(where: {$0.name == normalized}) else { return modelName }
            return model.displayName
        }
    }
    
    /// Cloud model slugs that providers renamed or retired. Saved mode
    /// selections may still carry the old name; normalize before any
    /// catalog lookup so those modes keep transcribing.
    static let renamedCloudModels: [String: String] = [
        "stt-async-v4": "stt-async-v5",  // Soniox retired v4 on 2026-06-30
        "scribe_v1": "scribe_v2",  // ElevenLabs removed Scribe v1 on 2026-07-09
        "universal-3-pro": "universal-3-5-pro"  // AssemblyAI dropped it from the speech_models enum
    ]

    static func normalizedCloudModelName(_ name: String) -> String {
        renamedCloudModels[name] ?? name
    }

    var defaultCloudTranscriptionModel: String? {
        switch self {
        case .groq: "whisper-large-v3-turbo"
        case .mistral: "voxtral-mini-latest"
        case .gemini: "gemini-3.6-flash"
        case .deepgram: "nova-3"
        case .elevenLabs: "scribe_v2"
        case .openAI: "gpt-transcribe"
        case .soniox: "stt-async-v5"
        case .gladia: "solaria-1"
        case .speechmatics: "speechmatics-batch-v2"
        case .cohere: "cohere-transcribe-03-2026"
        case .cartesia: "ink-whisper"
        case .xai: "grok-stt"
        case .assemblyAI: "universal-3-5-pro"
        default: nil
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
        case .soniox:
            return .soniox
        case .gladia:
            return .gladia
        case .speechmatics:
            return .speechmatics
        case .cohere:
            return .cohere
        case .cartesia:
            return .cartesia
        case .xai:
            return .grok
        case .assemblyAI:
            return .assemblyAI
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
                accuracy: 0.9,
                cost: 0.05,  // $0.000667/min paid tier - Free tier available with 30K tokens/min, 14.4K requests/day (refreshes daily, basically free for personal use)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),

            CloudModel(
                name: "whisper-large-v3",
                displayName: "Whisper Large V3",
                description: "Full-size Whisper on Groq's LPU - higher accuracy than Turbo and still 189x real-time speed. Free tier with generous daily limits",
                provider: .groq,
                speed: 0.95,
                accuracy: 0.93,
                cost: 0.15,  // $0.111/hr (~$0.00185/min) - same free tier as Turbo
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),

            CloudModel(
                name: "stt-async-v5",
                displayName: "Soniox (stt-async-v5)",
                description: "Soniox transcription model v5 with human-parity accuracy across 60+ languages, reengineered speaker separation and better handling of numbers, dates and emails. Powers Live Translation - super-fast real-time speech-to-speech translation, ideal for lectures and workshops.",
                provider: .soniox,
                recommended: true,
                speed: 0.95,
                accuracy: 0.98,
                cost: 0.25,
                supportManyLanguages: true,
                supportedLanguages: sonioxLanguages
            ),

            CloudModel(
                name: sonioxRealtimeModel,
                displayName: "Soniox Realtime (stt-rt-v5)",
                description: "Streams audio to Soniox while you speak instead of uploading after you stop, so the transcript is essentially ready the moment you finish. Same 60+ language coverage as the async model. Falls back to the standard upload path if the connection drops.",
                provider: .soniox,
                speed: 1.0,
                accuracy: 0.97,
                cost: 0.25,
                supportManyLanguages: true,
                supportedLanguages: sonioxLanguages
            ),

            CloudModel(
                name: "solaria-1",
                displayName: "Gladia Solaria",
                description: "Gladia's Solaria model with 100+ languages, built-in inline translation and speaker diarization in a single API call. New accounts get free credits.",
                provider: .gladia,
                recommended: true,
                speed: 0.85,
                accuracy: 0.96,
                cost: 0.6,
                supportManyLanguages: true,
                supportedLanguages: gladiaLanguages
            ),

            CloudModel(
                name: "solaria-3",
                displayName: "Gladia Solaria-3",
                description: "Gladia's most accurate model for real-world business audio in English, French, German, Spanish and Italian. Async only, one language per recording - pick Solaria for other languages or auto-detect.",
                provider: .gladia,
                speed: 0.85,
                accuracy: 0.97,
                cost: 0.6,
                supportManyLanguages: true,
                supportedLanguages: gladiaSolaria3Languages
            ),

            CloudModel(
                name: "speechmatics-batch-v2",
                displayName: "Speechmatics Enhanced",
                description: "Speechmatics batch transcription with industry-leading accuracy on European languages, speaker diarization and built-in translation across 50+ languages.",
                provider: .speechmatics,
                recommended: true,
                speed: 0.7,
                accuracy: 0.97,
                cost: 0.7,
                supportManyLanguages: true,
                supportedLanguages: speechmaticsLanguages
            ),

            CloudModel(
                name: "melia-1",
                displayName: "Speechmatics Melia-1",
                description: "Speechmatics' multilingual model with automatic code-switching across 56+ languages - no language selection needed. Their lowest-priced tier, in production preview for batch transcription.",
                provider: .speechmatics,
                speed: 0.75,
                accuracy: 0.96,
                cost: 0.3,
                supportManyLanguages: true,
                supportedLanguages: speechmaticsLanguages
            ),

            CloudModel(
                name: "speechmatics-standard",
                displayName: "Speechmatics Standard",
                description: "Speechmatics' fastest and cheapest tier - lower accuracy than Enhanced, but the quickest turnaround across the same 50+ languages.",
                provider: .speechmatics,
                speed: 0.9,
                accuracy: 0.92,
                cost: 0.35,
                supportManyLanguages: true,
                supportedLanguages: speechmaticsLanguages
            ),

            CloudModel(
                name: "voxtral-mini-latest",
                displayName: "Voxtral Mini V2",
                description: "State-of-the-art transcription with ~4% WER, speaker diarization, and 3-hour audio support. New signups get $500 free credits",
                provider: .mistral,
                recommended: true,
                speed: 0.95,
                accuracy: 0.95,
                cost: 0.45,  // $0.003/min - New signups get $500 free credits (~166,666 mins)
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),

            CloudModel(
                name: "nova-3-multilingual",
                displayName: "Nova 3 Multi-language",
                description: "First AI model with real-time switching across 10+ languages. New signups get $200 free credits (~38,460 mins)",
                provider: .deepgram,
                recommended: true,
                speed: 0.95,
                accuracy: 0.97,
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
                accuracy: 0.97,
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
                name: "cohere-transcribe-03-2026",
                displayName: "Cohere Transcribe",
                description: "Best-in-class accuracy (5.4 WER) across 14 languages. Free trial tier with rate limits, no credit card required",
                provider: .cohere,
                speed: 0.85,
                accuracy: 0.98,
                cost: 0.1,
                supportManyLanguages: true,
                supportedLanguages: cohereLanguages
            ),

            CloudModel(
                name: "cohere-transcribe-arabic-07-2026",
                displayName: "Cohere Transcribe Arabic",
                description: "Cohere's Arabic-specialist model, built for dialect variation and Arabic-English code-switching. Arabic and English only - pick Cohere Transcribe for other languages. Free trial tier with rate limits.",
                provider: .cohere,
                speed: 0.85,
                accuracy: 0.97,
                cost: 0.1,
                supportManyLanguages: true,
                supportedLanguages: cohereArabicLanguages
            ),

            CloudModel(
                name: "universal-3-5-pro",
                displayName: "AssemblyAI Universal-3.5 Pro",
                description: "AssemblyAI's latest and most accurate Universal model with native code switching, improved speaker diarization and automatic language detection. Unsupported languages fall back to Universal-2 automatically. New accounts get $50 in free credits, no credit card required.",
                provider: .assemblyAI,
                recommended: true,
                speed: 0.9,
                accuracy: 0.99,
                cost: 0.5,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),

            CloudModel(
                name: "universal-2",
                displayName: "AssemblyAI Universal-2",
                description: "AssemblyAI's fast, cost-effective Universal model with strong accuracy across major languages, automatic language detection and speaker diarization. New accounts get $50 in free credits, no credit card required.",
                provider: .assemblyAI,
                speed: 0.9,
                accuracy: 0.95,
                cost: 0.4,
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),

            CloudModel(
                name: "grok-stt",
                displayName: "xAI Speech-to-Text",
                description: "xAI's hosted speech-to-text endpoint with natural formatting and multilingual support. Uses the same xAI API key as Grok chat. No auto-detect - pick a language.",
                provider: .xai,
                recommended: true,
                speed: 0.9,
                accuracy: 0.95,
                cost: 0.5,
                supportManyLanguages: true,
                supportedLanguages: xaiLanguages
            ),

            CloudModel(
                name: "ink-whisper",
                displayName: "Cartesia Ink Whisper",
                description: "Cartesia's batch Speech-to-Text with arbitrary-length audio support, word-level timestamps, and 100+ languages. Free credits on signup.",
                provider: .cartesia,
                speed: 0.9,
                accuracy: 0.95,
                cost: 0.4,  // Placeholder - Cartesia bills per credit, not per minute
                supportManyLanguages: true,
                supportedLanguages: cartesiaLanguages
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

            // Gemini Models
            CloudModel(
                name: "gemini-3.6-flash",
                displayName: "Gemini 3.6 Flash",
                description: "Google's latest fast multimodal model, successor to 3.5 Flash with better quality at lower cost.",
                provider: .gemini,
                speed: 0.93,
                accuracy: 0.93,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-3.5-flash",
                displayName: "Gemini 3.5 Flash",
                description: "Google's previous-generation fast multimodal model, superseded by Gemini 3.6 Flash.",
                provider: .gemini,
                speed: 0.92,
                accuracy: 0.92,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-3.5-flash-lite",
                displayName: "Gemini 3.5 Flash Lite",
                description: "Google's fastest 3.5-class model (350 tokens/sec) with significantly better quality than 3.1 Flash Lite.",
                provider: .gemini,
                speed: 0.97,
                accuracy: 0.88,
                cost: 0.2,  // Slightly above 3.1 Flash Lite tier - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-3.1-pro-preview",
                displayName: "Gemini 3.1 Pro (Preview)",
                description: "Google's most capable Gemini model with advanced multimodal understanding.",
                provider: .gemini,
                speed: 0.7,
                accuracy: 0.94,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-3.1-flash-lite",
                displayName: "Gemini 3.1 Flash Lite",
                description: "Google's fastest and cheapest model, designed for high-volume transcription.",
                provider: .gemini,
                speed: 0.95,
                accuracy: 0.85,
                cost: 0.15,  // Cheapest Gemini tier - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-3-flash-preview",
                displayName: "Gemini 3 Flash (Preview)",
                description: "Earlier preview of Gemini 3 Flash combining intelligence with superior speed.",
                provider: .gemini,
                speed: 0.92,
                accuracy: 0.9,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            // Gemini 2.5 family is scheduled for shutdown on 2026-10-16 per Google's deprecation page.
            // Kept for backward compatibility; plan migration of user selections before October.
            CloudModel(
                name: "gemini-2.5-pro",
                displayName: "Gemini 2.5 Pro",
                description: "Google's advanced 2.5-generation model with superior noise filtering and speaker diarization. Scheduled for shutdown 2026-10-16.",
                provider: .gemini,
                speed: 0.7,
                accuracy: 0.92,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),
            CloudModel(
                name: "gemini-2.5-flash",
                displayName: "Gemini 2.5 Flash",
                description: "Google's fast 2.5-generation model with cost-effective batch processing. Scheduled for shutdown 2026-10-16.",
                provider: .gemini,
                speed: 0.9,
                accuracy: 0.7,
                cost: 0.3,  // $0.002/min - Free tier (15 RPM) + $300 Google Cloud credits for 90 days
                supportManyLanguages: true,
                supportedLanguages: allLanguages
            ),

            CloudModel(
                name: "gpt-transcribe",
                displayName: "GPT Transcribe",
                description: "OpenAI's recommended transcription model - roughly half Whisper's word error rate at a lower price per minute, with stronger handling of accents and noisy audio. No word-level timestamps.",
                provider: .openAI,
                recommended: true,
                speed: 0.8,
                accuracy: 0.97,
                cost: 0.6,  // $0.0045/min - between GPT-4o Mini ($0.003) and GPT-4o ($0.006)
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
                name: "gpt-4o-transcribe-diarize",
                displayName: "GPT-4o Transcribe Diarize",
                description: "OpenAI's speaker-aware transcription model - returns speaker-labeled transcripts for conversations and meetings. Language is always auto-detected.",
                provider: .openAI,
                speed: 0.7,
                accuracy: 0.95,
                cost: 0.9,  // ~$0.006/min, same tier as gpt-4o-transcribe
                supportManyLanguages: true,
                supportedLanguages: ["auto": "Auto-detect"]
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

        ]
    }
    
    static func getLanguageDictionary(supportManyLanguages: Bool) -> [String: String] {
        supportManyLanguages ? allLanguages : ["en": "English"]
    }

    /// Cohere supports 14 languages. No auto-detect - language must be specified.
    static let cohereLanguages: [String: String] = {
        let codes = ["en", "fr", "de", "it", "es", "pt", "el", "nl", "pl", "zh", "ja", "ko", "vi", "ar"]
        return allLanguages.filter { codes.contains($0.key) }
    }()

    /// Cohere Transcribe Arabic is trained on Arabic and English only, including
    /// code-switching between the two.
    static let cohereArabicLanguages: [String: String] = {
        let codes = ["ar", "en"]
        return allLanguages.filter { codes.contains($0.key) }
    }()

    /// Cartesia ink-whisper supports 104 languages via Whisper. No auto-detect -
    /// the API defaults to "en" if omitted, so the service falls back to "en" when
    /// the user has selected "auto".
    static let cartesiaLanguages: [String: String] = {
        let codes: Set<String> = [
            "en", "zh", "de", "es", "ru", "ko", "fr", "ja", "pt", "tr",
            "pl", "ca", "nl", "ar", "sv", "it", "id", "hi", "fi", "vi",
            "he", "uk", "el", "ms", "cs", "ro", "da", "hu", "ta", "no",
            "th", "ur", "hr", "bg", "lt", "la", "mi", "ml", "cy", "sk",
            "te", "fa", "lv", "bn", "sr", "az", "sl", "kn", "et", "mk",
            "br", "eu", "is", "hy", "ne", "mn", "bs", "kk", "sq", "sw",
            "gl", "mr", "pa", "si", "km", "sn", "yo", "so", "af", "oc",
            "ka", "be", "tg", "sd", "gu", "am", "yi", "lo", "uz", "fo",
            "ht", "ps", "tk", "nn", "mt", "sa", "lb", "my", "bo", "tl",
            "mg", "as", "tt", "haw", "ln", "ha", "ba", "jw", "su", "yue",
        ]
        return allLanguages.filter { codes.contains($0.key) }
    }()

    /// Gladia supports the full Whisper-style language set plus a handful of extras.
    /// Translation targets are the same set; auto-detect is also supported.
    static let gladiaLanguages: [String: String] = allLanguages

    /// Gladia Solaria-3 supports 5 European languages, exactly one per
    /// request. No auto-detect - language must be specified.
    static let gladiaSolaria3Languages: [String: String] = {
        let codes: Set<String> = ["en", "fr", "de", "es", "it"]
        return allLanguages.filter { codes.contains($0.key) }
    }()

    /// Speechmatics batch supports ~50 languages plus auto-detect.
    /// Note: Speechmatics uses `cmn` for Mandarin where we use `zh`; the service
    /// rewrites the code at request time so users still see "Chinese" in the picker.
    static let speechmaticsLanguages: [String: String] = {
        let codes: Set<String> = [
            "auto",
            "ar", "ba", "eu", "be", "bn", "bg", "yue", "ca", "zh", "hr",
            "cs", "da", "nl", "en", "et", "fi", "fr", "gl", "de", "el",
            "he", "hi", "hu", "id", "it", "ja", "ko", "lv", "lt", "ms",
            "mt", "mr", "mn", "no", "fa", "pl", "pt", "ro", "ru", "sk",
            "sl", "es", "sw", "sv", "ta", "th", "tr", "uk", "ur", "vi",
            "cy",
        ]
        return allLanguages.filter { codes.contains($0.key) }
    }()

    /// xAI Speech-to-Text documents exactly 24 supported language codes and
    /// rejects everything else with a 400 when `format=true`. The list is
    /// enumerated here (not derived from `allLanguages`) so a future Whisper
    /// addition can't silently leak an unsupported code into the picker. Note
    /// that xAI uses `fil` for Filipino, not Whisper's `tl`. No auto-detect:
    /// the API requires a concrete language when ITN formatting is on.
    static let xaiLanguages: [String: String] = [
        "ar": "Arabic",
        "cs": "Czech",
        "da": "Danish",
        "nl": "Dutch",
        "en": "English",
        "fil": "Filipino",
        "fr": "French",
        "de": "German",
        "hi": "Hindi",
        "id": "Indonesian",
        "it": "Italian",
        "ja": "Japanese",
        "ko": "Korean",
        "mk": "Macedonian",
        "ms": "Malay",
        "fa": "Persian",
        "pl": "Polish",
        "pt": "Portuguese",
        "ro": "Romanian",
        "ru": "Russian",
        "es": "Spanish",
        "sv": "Swedish",
        "th": "Thai",
        "tr": "Turkish",
        "vi": "Vietnamese",
    ]

    /// Soniox stt-async-v5 supports 60 languages plus auto-detect.
    /// Translation targets are the same set.
    static let sonioxLanguages: [String: String] = {
        let codes: Set<String> = [
            "auto",
            "af", "sq", "ar", "az", "eu", "be", "bn", "bs", "bg", "ca",
            "zh", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "gl",
            "de", "el", "gu", "he", "hi", "hu", "id", "it", "ja", "kn",
            "kk", "ko", "lv", "lt", "mk", "ms", "ml", "mr", "no", "fa",
            "pl", "pt", "pa", "ro", "ru", "sr", "sk", "sl", "es", "sw",
            "sv", "tl", "ta", "te", "th", "tr", "uk", "ur", "vi", "cy",
        ]
        return allLanguages.filter { codes.contains($0.key) }
    }()
    
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
    
    /// All languages supported by OpenAI Whisper (99 codes), plus "auto".
    /// Individual cloud providers may filter this down via per-model `supportedLanguages`.
    static let allLanguages = [
        "auto": "Auto-detect",
        "af": "Afrikaans",
        "sq": "Albanian",
        "am": "Amharic",
        "ar": "Arabic",
        "hy": "Armenian",
        "as": "Assamese",
        "az": "Azerbaijani",
        "ba": "Bashkir",
        "eu": "Basque",
        "be": "Belarusian",
        "bn": "Bengali",
        "bs": "Bosnian",
        "br": "Breton",
        "bg": "Bulgarian",
        "my": "Burmese",
        "yue": "Cantonese",
        "ca": "Catalan",
        "zh": "Chinese",
        "hr": "Croatian",
        "cs": "Czech",
        "da": "Danish",
        "nl": "Dutch",
        "en": "English",
        "et": "Estonian",
        "fo": "Faroese",
        "fi": "Finnish",
        "fr": "French",
        "gl": "Galician",
        "ka": "Georgian",
        "de": "German",
        "el": "Greek",
        "gu": "Gujarati",
        "ht": "Haitian Creole",
        "ha": "Hausa",
        "haw": "Hawaiian",
        "he": "Hebrew",
        "hi": "Hindi",
        "hu": "Hungarian",
        "is": "Icelandic",
        "id": "Indonesian",
        "it": "Italian",
        "ja": "Japanese",
        "jw": "Javanese",
        "kn": "Kannada",
        "kk": "Kazakh",
        "km": "Khmer",
        "ko": "Korean",
        "lo": "Lao",
        "la": "Latin",
        "lv": "Latvian",
        "ln": "Lingala",
        "lt": "Lithuanian",
        "lb": "Luxembourgish",
        "mk": "Macedonian",
        "mg": "Malagasy",
        "ms": "Malay",
        "ml": "Malayalam",
        "mt": "Maltese",
        "mi": "Maori",
        "mr": "Marathi",
        "mn": "Mongolian",
        "ne": "Nepali",
        "no": "Norwegian",
        "nn": "Nynorsk",
        "oc": "Occitan",
        "ps": "Pashto",
        "fa": "Persian",
        "pl": "Polish",
        "pt": "Portuguese",
        "pa": "Punjabi",
        "ro": "Romanian",
        "ru": "Russian",
        "sa": "Sanskrit",
        "sr": "Serbian",
        "sn": "Shona",
        "sd": "Sindhi",
        "si": "Sinhala",
        "sk": "Slovak",
        "sl": "Slovenian",
        "so": "Somali",
        "es": "Spanish",
        "su": "Sundanese",
        "sw": "Swahili",
        "sv": "Swedish",
        "tl": "Tagalog",
        "tg": "Tajik",
        "ta": "Tamil",
        "tt": "Tatar",
        "te": "Telugu",
        "th": "Thai",
        "bo": "Tibetan",
        "tr": "Turkish",
        "tk": "Turkmen",
        "uk": "Ukrainian",
        "ur": "Urdu",
        "uz": "Uzbek",
        "vi": "Vietnamese",
        "cy": "Welsh",
        "yi": "Yiddish",
        "yo": "Yoruba",
    ]
    
    static let languageFlags: [String: String] = [
        "auto": "🌐",
        "af": "🇿🇦",
        "sq": "🇦🇱",
        "am": "🇪🇹",
        "ar": "🇸🇦",
        "hy": "🇦🇲",
        "as": "🇮🇳",
        "az": "🇦🇿",
        "ba": "🇷🇺",
        "eu": "🇪🇸",
        "be": "🇧🇾",
        "bn": "🇧🇩",
        "bs": "🇧🇦",
        "br": "🇫🇷",
        "bg": "🇧🇬",
        "my": "🇲🇲",
        "yue": "🇭🇰",
        "ca": "🇪🇸",
        "zh": "🇨🇳",
        "hr": "🇭🇷",
        "cs": "🇨🇿",
        "da": "🇩🇰",
        "nl": "🇳🇱",
        "en": "🇺🇸",
        "et": "🇪🇪",
        "fo": "🇫🇴",
        "fi": "🇫🇮",
        "fil": "🇵🇭",
        "fr": "🇫🇷",
        "gl": "🇪🇸",
        "ka": "🇬🇪",
        "de": "🇩🇪",
        "el": "🇬🇷",
        "gu": "🇮🇳",
        "ht": "🇭🇹",
        "ha": "🇳🇬",
        "haw": "🇺🇸",
        "he": "🇮🇱",
        "hi": "🇮🇳",
        "hu": "🇭🇺",
        "is": "🇮🇸",
        "id": "🇮🇩",
        "it": "🇮🇹",
        "ja": "🇯🇵",
        "jw": "🇮🇩",
        "kn": "🇮🇳",
        "kk": "🇰🇿",
        "km": "🇰🇭",
        "ko": "🇰🇷",
        "lo": "🇱🇦",
        "la": "🇻🇦",
        "lv": "🇱🇻",
        "ln": "🇨🇩",
        "lt": "🇱🇹",
        "lb": "🇱🇺",
        "mk": "🇲🇰",
        "mg": "🇲🇬",
        "ms": "🇲🇾",
        "ml": "🇮🇳",
        "mt": "🇲🇹",
        "mi": "🇳🇿",
        "mr": "🇮🇳",
        "mn": "🇲🇳",
        "ne": "🇳🇵",
        "no": "🇳🇴",
        "nn": "🇳🇴",
        "oc": "🇫🇷",
        "ps": "🇦🇫",
        "fa": "🇮🇷",
        "pl": "🇵🇱",
        "pt": "🇵🇹",
        "pa": "🇮🇳",
        "ro": "🇷🇴",
        "ru": "🇷🇺",
        "sa": "🇮🇳",
        "sr": "🇷🇸",
        "sn": "🇿🇼",
        "sd": "🇵🇰",
        "si": "🇱🇰",
        "sk": "🇸🇰",
        "sl": "🇸🇮",
        "so": "🇸🇴",
        "es": "🇪🇸",
        "su": "🇮🇩",
        "sw": "🇹🇿",
        "sv": "🇸🇪",
        "tl": "🇵🇭",
        "tg": "🇹🇯",
        "ta": "🇮🇳",
        "tt": "🇷🇺",
        "te": "🇮🇳",
        "th": "🇹🇭",
        "bo": "🇨🇳",
        "tr": "🇹🇷",
        "tk": "🇹🇲",
        "uk": "🇺🇦",
        "ur": "🇵🇰",
        "uz": "🇺🇿",
        "vi": "🇻🇳",
        "cy": "🏴󠁧󠁢󠁷󠁬󠁳󠁿",
        "yi": "🇮🇱",
        "yo": "🇳🇬",
    ]
    
    static func languageWithFlag(_ code: String, name: String) -> String {
        let flag = languageFlags[code] ?? "🏳️"
        return "\(flag) \(name)"
    }
}
