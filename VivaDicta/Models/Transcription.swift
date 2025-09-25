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
        return (audioDuration / transcriptionDuration).formatted(.number.precision(.fractionLength(0...1)))
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
