//
//  ToggleRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.13
//

import AppIntents
import SwiftUI

struct ToggleRecordIntent: AppIntent {
    
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription("Start recording in VivaDicta")

    static let openAppWhenRun: Bool = true


    func perform() async throws -> some IntentResult {
        // Use Darwin notification to communicate with the main app
        // This is consistent with how keyboard extension communicates
        Task { @MainActor in
            AppGroupCoordinator.shared.requestStartRecordingFromControl()
        }

        // The app will open due to openAppWhenRun = true
        // and will receive the notification to start recording

        return .result()
    }

}
