//
//  AIEnhanceMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import Foundation


enum AIEnhanceModeType: Identifiable, CaseIterable {
    var id: Self { self }
    
    case email
    case chat
    case note
    case regular
    
    var name: String {
        switch self {
        case .email:
            "Email"
        case .chat:
            "Chat"
        case .note:
            "Note"
        case .regular:
            "Regular"
        }
    }
}

struct AIEnhanceMode {
    let prompt: String
    let type: AIEnhanceModeType
    
}
