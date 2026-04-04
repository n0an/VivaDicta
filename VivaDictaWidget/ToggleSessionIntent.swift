//
//  ToggleSessionIntent.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.11.20
//

import AppIntents
import ActivityKit
import SwiftUI

struct ToggleSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Session"
    static let description = IntentDescription("Toggle the keyboard session state")

    @Parameter(title: "Session Active")
    var isSessionActive: Bool
    
    static let isDiscoverable: Bool = false

    init() {
        self.isSessionActive = true
    }

    init(isSessionActive: Bool) {
        self.isSessionActive = isSessionActive
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // When toggling off, send termination notification via AppGroupCoordinator
        if !isSessionActive {
            // Send Darwin notification to terminate session
            // This will be handled by the main app without opening it
            AppGroupCoordinator.shared.requestTerminateSessionFromLiveActivity()

            // End all Live Activities immediately
            for activity in Activity<VivaDictaLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        return .result()
    }
}
