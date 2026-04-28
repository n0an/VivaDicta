//
//  LiveTranslationModels.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import Foundation

enum LiveTranslationLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"
    case russian = "ru"
    case ukrainian = "uk"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case czech = "cs"
    case turkish = "tr"
    case arabic = "ar"
    case hebrew = "he"
    case hindi = "hi"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case indonesian = "id"
    case vietnamese = "vi"
    case thai = "th"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .russian: "Russian"
        case .ukrainian: "Ukrainian"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .dutch: "Dutch"
        case .polish: "Polish"
        case .czech: "Czech"
        case .turkish: "Turkish"
        case .arabic: "Arabic"
        case .hebrew: "Hebrew"
        case .hindi: "Hindi"
        case .chinese: "Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .indonesian: "Indonesian"
        case .vietnamese: "Vietnamese"
        case .thai: "Thai"
        }
    }
}

enum LiveTranslationStatus: Equatable, Sendable {
    case idle
    case starting
    case running
    case stopping
    case failed(String)
}

struct LiveTranslationToken: Sendable, Hashable {
    let id: UUID
    let text: String
    let isFinal: Bool
    let kind: Kind

    enum Kind: Sendable, Hashable {
        case original
        case translation
    }
}

struct LiveTranslationConfig: Sendable {
    var sourceLanguage: LiveTranslationLanguage
    var targetLanguage: LiveTranslationLanguage
    var ttsEnabled: Bool
    var ttsVoice: String

    static let `default` = LiveTranslationConfig(
        sourceLanguage: .spanish,
        targetLanguage: .russian,
        ttsEnabled: true,
        ttsVoice: "Adrian"
    )
}

enum LiveTranslationError: LocalizedError {
    case missingAPIKey
    case microphonePermissionDenied
    case audioSessionFailure(String)
    case webSocketFailure(String)
    case audioEngineFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Soniox API key is missing. Add it in Settings."
        case .microphonePermissionDenied:
            "Microphone access is required for live translation."
        case .audioSessionFailure(let message):
            "Audio session error: \(message)"
        case .webSocketFailure(let message):
            "Connection error: \(message)"
        case .audioEngineFailure(let message):
            "Audio error: \(message)"
        }
    }
}
