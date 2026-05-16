//
//  ToggleRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.13
//

import AppIntents
import SwiftUI
import AppGroup

struct ToggleRecordIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Recording"
    static let description = IntentDescription("Start or stop recording in VivaDicta")

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Recording")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        let coordinator = AppGroupCoordinator.shared
        let isCurrentlyRecording = coordinator.isRecording

        if isCurrentlyRecording {
            coordinator.requestStopRecording()
        } else {
            coordinator.requestStartRecordingFromControl()
        }
        return .result()
    }
}
