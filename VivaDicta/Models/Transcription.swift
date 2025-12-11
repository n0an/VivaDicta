//
//  Transcription.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import Foundation
import SwiftData
import CoreSpotlight

@Model
class Transcription {
    var id: UUID = UUID()
    var text: String
    var enhancedText: String?
    var timestamp: Date
    var audioDuration: TimeInterval
    var audioFileName: String?
    var transcriptionModelName: String?
    var aiEnhancementModelName: String?
    var promptName: String?
    var transcriptionDuration: TimeInterval?
    var enhancementDuration: TimeInterval?

    // TODO: Add tags/keywords property for LLM-generated tags
    // var tags: [String]? = nil  // LLM-generated keywords/tags for better Spotlight search
    
    init(text: String,
         enhancedText: String? = nil,
         audioDuration: TimeInterval,
         audioFileName: String? = nil,
         transcriptionModelName: String? = nil,
         aiEnhancementModelName: String? = nil,
         promptName: String? = nil,
         transcriptionDuration: TimeInterval? = nil,
         enhancementDuration: TimeInterval? = nil) {
        self.text = text
        self.enhancedText = enhancedText
        self.timestamp = Date()
        self.audioDuration = audioDuration
        self.audioFileName = audioFileName
        self.transcriptionModelName = transcriptionModelName
        self.aiEnhancementModelName = aiEnhancementModelName
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

    /// Get the audio file size in bytes
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

    /// Format file size in human-readable format (KB, MB)
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
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
            aiEnhancementModelName: "claude-sonnet-4-0",
            promptName: "Chat",
            transcriptionDuration: 0.2,
            enhancementDuration: 0.8),
        
        Transcription(
            text: "knock knock Neo",
            enhancedText: "Knock-knock Neo!" ,
            audioDuration: 77,
            audioFileName: "",
            transcriptionModelName: "Large V3 Turbo",
            aiEnhancementModelName: "openai-gpt-5",
            promptName: "Note",
            transcriptionDuration: 1.2,
            enhancementDuration: 2.8),
    ]
}

extension Transcription {
    nonisolated func searchableAttributes(lastUsedDate: Date? = nil) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)

        // Title: First 100 characters of the transcription or a date-based title
        let textPreview = String(text.prefix(100))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: timestamp)

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

        // Content: Full text for searching (original + enhanced)
        var fullContent = text
        if let enhancedText = enhancedText, !enhancedText.isEmpty {
            fullContent += "\n\n" + enhancedText
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

        // TODO: Add LLM-generated tags to keywords when available
        // if let tags = tags {
        //     keywords.append(contentsOf: tags)
        // }

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
