//
//  CancelRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents
import AppGroup

struct CancelRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Recording"
    static let description = IntentDescription(
        "Cancels the current VivaDicta recording without saving a transcription."
    )

    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppGroupCoordinator.shared.requestCancelRecording()
        return .result()
    }
}
