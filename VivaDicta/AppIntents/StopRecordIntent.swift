//
//  StopRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents

struct StopRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription(
        "Stops the current VivaDicta recording and begins transcription."
    )

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppGroupCoordinator.shared.requestStopRecording()
        }
        return .result()
    }
}
