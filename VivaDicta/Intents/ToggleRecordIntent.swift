//
//  ToggleRecordIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.13
//

import AppIntents

struct ToggleRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Record"
    static let description = IntentDescription("Toggles Record in VivaDicta")
    
    static let openAppWhenRun: Bool = true
    
    
    func perform() async throws -> some IntentResult {
        
        
        
        
        return .result()
    }

}
