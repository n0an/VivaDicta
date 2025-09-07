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
    var timestamp: Date
    var enhancedText: String
    var audioFileName: String
    var audioDuration: TimeInterval
    var transcriptionModelName: String
    var enhancementModelName: String
    
    init(text: String,
         timestamp: Date,
         enhancedText: String,
         audioFileName: String,
         audioDuration: TimeInterval,
         transcriptionModelName: String,
         enhancementModelName: String) {
        self.text = text
        self.timestamp = timestamp
        self.enhancedText = enhancedText
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
        self.transcriptionModelName = transcriptionModelName
        self.enhancementModelName = enhancementModelName
    }
    
    var audioDurationFormatted: String {
        if audioDuration < 1 {
            return (audioDuration * 1000).formatted(.number.precision(.fractionLength(0))) + "ms"
        }
        if audioDuration < 60 {
            return audioDuration.formatted(.number.precision(.fractionLength(1))) + "s"
        }
        return Duration.seconds(round(audioDuration))
            .formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
}

extension Transcription {
    nonisolated(unsafe) static let mockData: [Transcription] =
    [
        Transcription(
            text: "hello world",
            timestamp: .now,
            enhancedText: "enhanced 1",
            audioFileName: "",
            audioDuration: 5,
            transcriptionModelName: "openai",
            enhancementModelName: ""),
        Transcription(
            text: "how are you",
            timestamp: .now,
            enhancedText: "enhanced 2",
            audioFileName: "",
            audioDuration: 42,
            transcriptionModelName: "whisper.cpp",
            enhancementModelName: ""),
        Transcription(
            text: "knock knock Neo",
            timestamp: .now.advanced(by: 1000),
            enhancedText: "enhanced 3",
            audioFileName: "",
            audioDuration: 77,
            transcriptionModelName: "elevellabs",
            enhancementModelName: "")
        
    ]
}
