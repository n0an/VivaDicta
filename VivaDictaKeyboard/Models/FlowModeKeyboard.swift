//
//  FlowMode.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

// Simplified FlowMode for keyboard extension
// This matches the structure from the main app
struct FlowMode: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let aiEnhanceEnabled: Bool

    // Simplified version for keyboard extension
    // We only need basic info for display
    static let defaultMode = FlowMode(
        id: UUID(),
        name: "Default",
        aiEnhanceEnabled: false
    )
}
