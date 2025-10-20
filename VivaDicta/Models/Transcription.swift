//
//  Transcription.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import Foundation
import SwiftData

@Model
class Transcription {
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

        // Construct audio directory path directly to avoid MainActor isolation issues
        let documentsDirectory = URL.documentsDirectory
        let audioDirectory = documentsDirectory.appendingPathComponent("Audio")
        let audioURL = audioDirectory.appendingPathComponent(audioFileName)

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
            return String(format: "%.0f KB", kb)
        }

        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
}

extension Transcription {
    nonisolated(unsafe) static let mockData: [Transcription] =
    [
        
        Transcription(
            text: "hello world",
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
}
