//
//  ToggleRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.13
//

import AppIntents
import SwiftUI

struct ToggleRecordIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Recording"
    static let description = IntentDescription("Start or stop recording in VivaDicta")

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Recording")
    var value: Bool

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let coordinator = AppGroupCoordinator.shared

            if value {
                coordinator.requestStartRecordingFromControl()
            } else {
                coordinator.requestStopRecording()
            }
        }
        return .result()
    }
}
