//
//  ReasoningConfig.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.08
//

import Foundation

struct ReasoningConfig {
    static let geminiReasoningModels: Set<String> = [
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite"
    ]

    static let openAIReasoningModels: Set<String> = [
        "gpt-5",
        "gpt-5-mini",
        "gpt-5-nano"
    ]

    static func getReasoningParameter(for modelName: String) -> String? {
        if geminiReasoningModels.contains(modelName) {
            return "low"
        } else if openAIReasoningModels.contains(modelName) {
            return "minimal"
        }
        return nil
    }
}
