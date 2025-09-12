//
//  AIEnhanceMode.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI


//enum AIEnhanceModeType: Identifiable, CaseIterable {
//    var id: Self { self }
//    
//    case email
//    case chat
//    case note
//    case regular
//    
//    var name: String {
//        switch self {
//        case .email:
//            "Email"
//        case .chat:
//            "Chat"
//        case .note:
//            "Note"
//        case .regular:
//            "Regular"
//        }
//    }
//}

struct AIEnhanceMode: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let prompt: String
    let aiProvider: String
    let aiModel: String
    
    let aiEnhanceEnabled: Bool
    
    static let predefinedModes: [AIEnhanceMode] = [
        AIEnhanceMode(
            name: "Email",
            prompt: "",
            aiProvider: "",
            aiModel: "",
            aiEnhanceEnabled: false
        ),
        AIEnhanceMode(
            name: "Chat",
            prompt: "",
            aiProvider: "",
            aiModel: "",
            aiEnhanceEnabled: false
        ),
        AIEnhanceMode(
            name: "Note",
            prompt: "",
            aiProvider: "",
            aiModel: "",
            aiEnhanceEnabled: false
        ),
        AIEnhanceMode(
            name: "Regular",
            prompt: "",
            aiProvider: "",
            aiModel: "",
            aiEnhanceEnabled: false
        ),
    ]
}
