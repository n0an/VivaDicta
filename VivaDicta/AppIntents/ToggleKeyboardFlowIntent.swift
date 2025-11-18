//
//  ToggleKeyboardFlowIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import AppIntents

struct ToggleKeyboardFlowIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Keyboard Flow"
    static let description = IntentDescription("Toggle Keyboard Session in VivaDicta")

    static let openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let coordinator = AppGroupCoordinator.shared
            // TODO: implement here
            
        }
        return .result()
    }
}
