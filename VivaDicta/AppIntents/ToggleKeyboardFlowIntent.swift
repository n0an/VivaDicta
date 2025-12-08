//
//  ToggleKeyboardFlowIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import AppIntents
import os

struct ToggleKeyboardFlowIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Keyboard Flow"
    static let description = IntentDescription("Toggle Keyboard Session in VivaDicta")

    // Try to avoid opening the app - will test if this works
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let logger = Logger(category: .toggleKeyboardFlowIntent)

        await MainActor.run {
            let coordinator = AppGroupCoordinator.shared

            // Check current keyboard session state
            if coordinator.isKeyboardSessionActive {
                // Session is active - deactivate it
                logger.logInfo("🎙️ Keyboard flow active - deactivating session")
                coordinator.deactivateKeyboardSession()

            } else {
                // Session is not active - activate it
                logger.logInfo("🎙️ Keyboard flow inactive - activating session")

                // Activate keyboard session with default timeout (180 seconds)
                // This will send a Darwin notification that the main app will receive
                coordinator.activateKeyboardSession(timeoutSeconds: 180)
            }
        }

        return .result()
    }
}
