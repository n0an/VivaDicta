//
//  CancelRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents

struct CancelRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Recording"
    static let description = IntentDescription(
        "Cancels the current VivaDicta recording without saving a transcription."
    )

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppGroupCoordinator.shared.requestCancelRecording()
        }
        return .result()
    }
}
