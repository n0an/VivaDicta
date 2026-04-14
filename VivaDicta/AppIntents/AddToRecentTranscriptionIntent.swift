//
//  AddToRecentTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import SwiftData

struct AddToRecentTranscriptionIntent: AppIntent {
    @Dependency var dataController: DataController

    @Parameter var newText: String

    static let title: LocalizedStringResource = "Add to Recent Note"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recentTranscriptions = try dataController.transcriptions(limit: 1)

        if let recentTranscription = recentTranscriptions.first {
            recentTranscription.appendToOriginalText(newText)
            try? recentTranscription.modelContext?.save()
            return .result(dialog: "Done")
        } else {
            return .result(dialog: "You haven't recorded any notes yet.")
        }
    }
}
