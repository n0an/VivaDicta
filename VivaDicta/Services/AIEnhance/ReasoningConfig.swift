//
//  ReasoningConfig.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.08
//

import Foundation

struct ReasoningConfig {
    // 2.5-flash and 2.5-flash-lite support "none" to fully turn off thinking
    static let geminiNoneReasoningModels: Set<String> = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite"
    ]

    // These can't fully disable thinking — "minimal" is as low as they go
    static let geminiMinimalReasoningModels: Set<String> = [
        "gemini-2.5-pro",
        "gemini-3.1-pro-preview",
        "gemini-3-flash-preview",
        "gemini-3.1-flash-lite-preview"
    ]

    // 5.5, 5.4 and 5.2 models already default to "none", but we set it explicitly
    static let openAINoneReasoningModels: Set<String> = [
        "gpt-5.5",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.4-nano",
        "gpt-5.2"
    ]

    // Older 5-mini/nano default to "medium", so we bring them down to "minimal"
    static let openAIMinimalReasoningModels: Set<String> = [
        "gpt-5-mini",
        "gpt-5-nano"
    ]

    // gpt-oss-120b defaults to "medium" on Cerebras, "low" is the cheapest option
    static let cerebrasReasoningModels: Set<String> = [
        "gpt-oss-120b"
    ]

    // zai-glm-4.7 doesn't use reasoning_effort — needs "disable_reasoning" in the body instead
    static let cerebrasDisableReasoningModels: Set<String> = [
        "zai-glm-4.7"
    ]

    // Groq's gpt-oss models only support low/medium/high — no "none" option
    static let groqLowReasoningModels: Set<String> = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b"
    ]

    // qwen3-32b on Groq is a simple toggle: "none" = no thinking, "default" = thinking
    static let groqQwenReasoningModels: Set<String> = [
        "qwen/qwen3-32b"
    ]

    static func getReasoningParameter(for modelName: String) -> String? {
        if geminiNoneReasoningModels.contains(modelName) { return "none" }
        else if geminiMinimalReasoningModels.contains(modelName) { return "minimal" }
        else if openAINoneReasoningModels.contains(modelName) { return "none" }
        else if openAIMinimalReasoningModels.contains(modelName) { return "minimal" }
        else if cerebrasReasoningModels.contains(modelName) { return "low" }
        else if groqLowReasoningModels.contains(modelName) { return "low" }
        else if groqQwenReasoningModels.contains(modelName) { return "none" }
        return nil
    }

    // For models that need custom params instead of reasoning_effort
    static func getExtraBodyParameters(for modelName: String) -> [String: Any]? {
        if cerebrasDisableReasoningModels.contains(modelName) {
            return ["disable_reasoning": true]
        }
        return nil
    }
}
