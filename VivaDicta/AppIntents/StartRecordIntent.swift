//
//  StartRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents

struct StartRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription(
        "Starts a new recording in VivaDicta. Use with Stop Recording to control the session from a shortcut."
    )

    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppGroupCoordinator.shared.requestStartRecordingFromControl()
        return .result()
    }
}
