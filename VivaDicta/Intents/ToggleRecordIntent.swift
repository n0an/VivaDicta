//
//  ToggleRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.13
//

import AppIntents
import SwiftUI

struct ToggleRecordIntent: AppIntent {

    static let title: LocalizedStringResource = "Toggle Recording"
    static let description = IntentDescription("Toggle recording in VivaDicta")

    static let openAppWhenRun: Bool = true

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = .foreground(.immediate)


    func perform() async throws -> some IntentResult {
        // Check current recording state and toggle accordingly
        await MainActor.run {
            let coordinator = AppGroupCoordinator.shared
            let isCurrentlyRecording = coordinator.isRecording

            if isCurrentlyRecording {
                // If recording, stop it
                coordinator.requestStopRecording()
            } else {
                // If not recording, start it from Control Center
                coordinator.requestStartRecordingFromControl()
            }
        }

        // The app will open due to openAppWhenRun = true
        // and will receive the appropriate notification

        return .result()
    }

}
