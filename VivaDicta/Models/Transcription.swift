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
    var audioFileURL: String
    var transcriptionModelName: String
    var enhancementModelName: String
    
    init(text: String,
         timestamp: Date,
         enhancedText: String,
         audioFileURL: String,
         transcriptionModelName: String,
         enhancementModelName: String) {
        self.text = text
        self.timestamp = timestamp
        self.enhancedText = enhancedText
        self.audioFileURL = audioFileURL
        self.transcriptionModelName = transcriptionModelName
        self.enhancementModelName = enhancementModelName
    }
}

extension Transcription {
    nonisolated(unsafe) static let mockData: [Transcription] =
    [
        Transcription(
            text: "hello world",
            timestamp: .now,
            enhancedText: "enhanced 1",
            audioFileURL: "",
            transcriptionModelName: "openai",
            enhancementModelName: ""),
        Transcription(
            text: "how are you",
            timestamp: .now,
            enhancedText: "enhanced 2",
            audioFileURL: "",
            transcriptionModelName: "whisper.cpp",
            enhancementModelName: ""),
        Transcription(
            text: "knock knock Neo",
            timestamp: .now,
            enhancedText: "enhanced 3",
            audioFileURL: "",
            transcriptionModelName: "elevellabs",
            enhancementModelName: "")
        
    ]
}
