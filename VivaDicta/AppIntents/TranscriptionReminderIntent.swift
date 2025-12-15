//
//  TranscriptionReminderIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents

struct TranscriptionReminderIntent: AppIntent {
    @Dependency var dataController: DataController
    static let title: LocalizedStringResource = "Remind me of a Note"
    @Parameter var transcription: TranscriptionEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text: String
        if let enhancedText = transcription.enhancedText {
            text =  String(enhancedText.prefix(200))
        } else {
            text = String(transcription.text.prefix(200))
        }
        return .result(dialog: "\(text)")
    }
}
