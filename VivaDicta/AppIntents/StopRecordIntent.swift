//
//  StopRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents
import AppGroup

struct StopRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription(
        "Stops the current VivaDicta recording and begins transcription."
    )

    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppGroupCoordinator.shared.requestStopRecording()
        return .result()
    }
}
