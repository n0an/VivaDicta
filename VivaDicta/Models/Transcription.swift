//
//  Transcription.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import Foundation
import SwiftData
import CoreSpotlight

/// A SwiftData model representing a voice transcription with optional AI processing.
///
/// `Transcription` stores the result of transcribing audio, including both the raw
/// transcription and any AI-enhanced version. It also captures metadata about the
/// transcription process for analytics and display purposes.
///
/// ## Properties
///
/// - ``text``: The original transcribed text from speech-to-text
/// - ``enhancedText``: Optional AI-enhanced version of the transcription
/// - ``timestamp``: When the transcription was created
/// - ``audioDuration``: Length of the source audio in seconds
/// - ``audioFileName``: Name of the stored audio file (for playback)
///
/// ## Metadata
///
/// The model tracks which models and providers were used:
/// - Transcription: ``transcriptionModelName``, ``transcriptionProviderName``
/// - Enhancement: ``aiEnhancementModelName``, ``aiProviderName``, ``promptName``
/// - Performance: ``transcriptionDuration``, ``enhancementDuration``
///
/// ## Spotlight Integration
///
/// Use ``searchableAttributes(lastUsedDate:)`` to generate attributes for Spotlight indexing.
@Model
class Transcription {
    /// Unique identifier for the transcription.
    var id: UUID = UUID()

    /// The original transcribed text from speech-to-text.
    var text: String = ""

    /// AI-enhanced version of the transcription, if enhancement was applied.
    var enhancedText: String?

    /// Timestamp when the transcription was created.
    var timestamp: Date = Date()

    /// Duration of the source audio in seconds.
    var audioDuration: TimeInterval = 0

    /// Filename of the stored audio file for playback.
    var audioFileName: String?

    /// Display name of the transcription model used.
    var transcriptionModelName: String?

    /// Display name of the transcription provider (WhisperKit, Parakeet, etc.).
    var transcriptionProviderName: String?

    /// Display name of the AI model used for enhancement.
    var aiEnhancementModelName: String?

    /// Display name of the AI provider used for enhancement.
    var aiProviderName: String?

    /// Name of the prompt template used for enhancement.
    var promptName: String?

    /// Duration of the transcription process in seconds.
    var transcriptionDuration: TimeInterval?

    /// Duration of the AI processing process in seconds.
    var enhancementDuration: TimeInterval?

    /// System message used for AI processing request (synced from macOS).
    var aiRequestSystemMessage: String?

    /// User message used for AI processing request (synced from macOS).
    var aiRequestUserMessage: String?

    /// Name of the Power Mode active during transcription (synced from macOS).
    var powerModeName: String?

    /// Emoji of the Power Mode active during transcription (synced from macOS).
    var powerModeEmoji: String?

    /// Status of the transcription (pending/completed/failed, synced from macOS).
    var transcriptionStatus: String?

    /// AI-generated text variations (Summary, Action Points, Professional, etc.).
    @Relationship(deleteRule: .cascade)
    var variations: [TranscriptionVariation]? = []

    /// Creates a new transcription with the specified properties.
    ///
    /// - Parameters:
    ///   - text: The transcribed text.
    ///   - enhancedText: Optional AI-enhanced text.
    ///   - audioDuration: Duration of the source audio.
    ///   - audioFileName: Filename for the stored audio.
    ///   - transcriptionModelName: Name of the transcription model.
    ///   - transcriptionProviderName: Name of the transcription provider.
    ///   - aiEnhancementModelName: Name of the AI processing model.
    ///   - aiProviderName: Name of the AI provider.
    ///   - promptName: Name of the enhancement prompt.
    ///   - transcriptionDuration: Time taken to transcribe.
    ///   - enhancementDuration: Time taken to enhance.
    init(text: String,
         enhancedText: String? = nil,
         audioDuration: TimeInterval,
         audioFileName: String? = nil,
         transcriptionModelName: String? = nil,
         transcriptionProviderName: String? = nil,
         aiEnhancementModelName: String? = nil,
         aiProviderName: String? = nil,
         promptName: String? = nil,
         transcriptionDuration: TimeInterval? = nil,
         enhancementDuration: TimeInterval? = nil) {
        self.text = text
        self.enhancedText = enhancedText
        self.timestamp = Date()
        self.audioDuration = audioDuration
        self.audioFileName = audioFileName
        self.transcriptionModelName = transcriptionModelName
        self.transcriptionProviderName = transcriptionProviderName
        self.aiEnhancementModelName = aiEnhancementModelName
        self.aiProviderName = aiProviderName
        self.promptName = promptName
        self.transcriptionDuration = transcriptionDuration
        self.enhancementDuration = enhancementDuration
    }

    
    func getDurationFormatted(_ duration: Double) -> String {
        if duration < 1 {
            return (duration * 1000).formatted(.number.precision(.fractionLength(0))) + "ms"
        }
        if duration < 60 {
            return duration.formatted(.number.precision(.fractionLength(1))) + "s"
        }
        return Duration.seconds(round(duration))
            .formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
    
    func getFactor(audioDuration: Double, transcriptionDuration: Double) -> String {
        guard transcriptionDuration > 0 else { return "N/A" }
        return (audioDuration / transcriptionDuration).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Returns the audio file size in bytes, if available.
    ///
    /// - Returns: The file size in bytes, or `nil` if the file doesn't exist.
    nonisolated func getAudioFileSize() -> Int64? {
        guard let audioFileName = audioFileName else { return nil }

        // Construct path directly to avoid MainActor isolation of FileManager.appDirectory
        let audioURL = URL.documentsDirectory
            .appendingPathComponent("Audio")
            .appendingPathComponent(audioFileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else { return nil }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    /// Returns the audio file size formatted for display (KB, MB).
    ///
    /// - Returns: A human-readable file size string, or "N/A" if unavailable.
    nonisolated func getAudioFileSizeFormatted() -> String {
        guard let bytes = getAudioFileSize() else { return "N/A" }

        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return "\(kb.formatted(.number.precision(.fractionLength(0)))) KB"
        }

        let mb = kb / 1024.0
        return "\(mb.formatted(.number.precision(.fractionLength(1)))) MB"
    }
}

extension Transcription {
    var entity: TranscriptionEntity {

        .init(
            id: id,
            text: text,
            enhancedText: enhancedText,
            timestamp: timestamp,
            audioDuration: audioDuration,
            audioFileName: audioFileName,
            transcriptionModelName: transcriptionModelName,
            transcriptionProviderName: transcriptionProviderName,
            aiEnhancementModelName: aiEnhancementModelName,
            aiProviderName: aiProviderName,
            promptName: promptName,
            transcriptionDuration: transcriptionDuration,
            enhancementDuration: enhancementDuration
        )
    }
}

extension Transcription {
    nonisolated(unsafe) static let mockData: [Transcription] =
    [
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf. ",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),

        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8)
    ]
    
    nonisolated(unsafe) static let mockDataMany: [Transcription] =
    [
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
        
        Transcription(
            text: "hello world. heya how are you. asldjfsldafjasldfjsdf. Faldsjflasdjflsjadf. Flajsdflajsdflajsdfljasdflsaldfjlasdjflsadfjlasdjf. Flajlsdjfalsdjflajsdlfjasldfj. aFljalsdjflajsfdljasf",
            audioDuration: 5),
        
        Transcription(
            text: "heya how are you",
            enhancedText: "Hello. How are you?" ,
            audioDuration: 2,
            audioFileName: "",
            transcriptionModelName: "Tiny",
            transcriptionProviderName: "WhisperKit",
            aiEnhancementModelName: "claude-sonnet-4-0",
            aiProviderName: "Anthropic",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            transcriptionProviderName: "OpenAI",
            aiEnhancementModelName: "openai-gpt-5",
            aiProviderName: "OpenAI",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
    ]
}

extension Transcription {
    nonisolated func searchableAttributes(lastUsedDate: Date? = nil) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        
        let textToUse = enhancedText ?? text
        
        // Title: First 100 characters of the transcription or a date-based title
        let textPreview = String(textToUse.prefix(100))
        let dateString = timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())

        var title = ""
        
        if text.count > 100 {
            title = "\(textPreview)..."
        } else if !text.isEmpty {
            title = textPreview
        } else {
            title = "Recording - \(dateString)"
        }
        
        attributes.title = title
        attributes.displayName = title

        // Content: Full text for searching (original + enhanced + variations)
        var fullContent = text
        if let enhancedText = enhancedText, !enhancedText.isEmpty {
            fullContent += "\n\n" + enhancedText
        }
        if let variations {
            for variation in variations where !variation.text.isEmpty {
                fullContent += "\n\n" + variation.text
            }
        }
        attributes.contentDescription = fullContent

        // Keywords: Model names, prompt, and meaningful terms
        var keywords = [String]()

        if let promptName = promptName {
            keywords.append(promptName)
        }

        if let transcriptionModel = transcriptionModelName {
            keywords.append(transcriptionModel)
        }

        if let aiModel = aiEnhancementModelName {
            keywords.append(aiModel)
        }

        attributes.keywords = keywords

        // Duration and dates
        attributes.duration = NSNumber(value: audioDuration)
        attributes.contentCreationDate = timestamp
        attributes.contentModificationDate = timestamp

        // Additional metadata
        attributes.kind = "Voice Transcription"
        attributes.identifier = id.uuidString
        attributes.relatedUniqueIdentifier = id.uuidString

        // Audio metadata (if we have it)
        if audioDuration > 0 {
            let durationCategory: String
            switch audioDuration {
            case 0..<30:
                durationCategory = "Short recording"
            case 30..<120:
                durationCategory = "Medium recording"
            default:
                durationCategory = "Long recording"
            }
            attributes.comment = durationCategory
        }

        // Set lastUsedDate for Spotlight ranking (frequently accessed items rank higher)
        if let lastUsedDate {
            attributes.lastUsedDate = lastUsedDate
        }

        return attributes
    }

}

extension UTType {
    public static let transcription = UTType(exportedAs: "com.antonnovoselov.VivaDicta")
}
