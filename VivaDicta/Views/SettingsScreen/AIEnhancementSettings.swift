//
//  AIEnhancementSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct AIEnhancementSettings: View {
    var body: some View {
        Form {
            Section("Settings") {
                NavigationLink(destination: PromptsSettings()) {
                    Text("LLM Prompts")
                }
            }
        }
    }
}
