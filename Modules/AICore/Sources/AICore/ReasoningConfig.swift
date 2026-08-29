//
//  ReasoningConfig.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.08
//

import Foundation

public struct ReasoningConfig {
    // 2.5-flash and 2.5-flash-lite support "none" to fully turn off thinking
    static let geminiNoneReasoningModels: Set<String> = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite"
    ]

    // These can't fully disable thinking - "minimal" is as low as they go
    static let geminiMinimalReasoningModels: Set<String> = [
        "gemini-2.5-pro",
        "gemini-3.1-pro-preview",
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-3-flash-preview",
        "gemini-3.5-flash-lite",
        "gemini-3.1-flash-lite",
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

    /// xAI's reasoning models think hard by default, which costs seconds that
    /// dictation enhancement has no use for: measured 2026-08-26, grok-4.6 went
    /// 10.2s -> 5.2s and grok-4.5 6.6s -> 2.1s at "minimal", both scoring
    /// slightly *higher* on a cleanup eval. Neither accepts "none".
    ///
    /// grok-4.3 is deliberately absent: "none" takes it to 0.9s but it starts
    /// ignoring instructions, emitting the "ё" the prompt asks it to replace.
    /// grok-4.20-non-reasoning covers that speed slot without the tradeoff.
    static let grokMinimalReasoningModels: Set<String> = [
        "grok-4.6",
        "grok-4.5"
    ]

    /// Models that reject every temperature but 1.
    ///
    /// Moonshot's newer Kimi builds answer `invalid temperature: only 1 is
    /// allowed for this model` to anything else. Matched on the model id rather
    /// than the provider, since the same build is reachable directly, through
    /// OpenCode Go, and through gateways that prefix the vendor
    /// ("moonshotai/kimi-k3"). k2.6 and older accept the usual 0.3.
    static let fixedTemperatureModelIDs: [String] = [
        "kimi-k3",
        "kimi-k2.7"
    ]

    /// Whether a `temperature` field belongs in this model's request body.
    ///
    /// False for the GPT-5 reasoning family, which uses `reasoning_effort`, and
    /// for the models above, which accept only 1 - omitting it lets the server
    /// pick that default rather than us hard-coding a value per family.
    public static func sendsTemperature(for modelName: String) -> Bool {
        let id = modelName.lowercased()
        if id.hasPrefix("gpt-5") { return false }
        return !fixedTemperatureModelIDs.contains(where: id.contains)
    }

    /// Whether this model's output cap belongs in `max_completion_tokens`
    /// rather than `max_tokens`.
    ///
    /// The GPT-5 reasoning family rejects the older field outright:
    /// `Unsupported parameter: 'max_tokens' is not supported with this model.
    /// Use 'max_completion_tokens' instead.` Matched on the bare model id, so
    /// gateway-prefixed ids ("openai/gpt-5.6-terra" on OpenRouter or Vercel)
    /// are covered too.
    public static func usesMaxCompletionTokens(for modelName: String) -> Bool {
        bareModelID(modelName).hasPrefix("gpt-5")
    }

    /// Smallest output cap a reasoning model accepts. The cap covers reasoning
    /// tokens as well as visible output, and OpenAI rejects anything lower.
    public static let minimumReasoningOutputTokens = 16

    /// Strips a gateway's vendor prefix ("openai/gpt-5.6-terra" -> "gpt-5.6-terra")
    /// and lowercases, so model-family checks work whichever route serves the model.
    private static func bareModelID(_ modelName: String) -> String {
        let id = modelName.lowercased()
        guard let lastSlash = id.lastIndex(of: "/") else { return id }
        return String(id[id.index(after: lastSlash)...])
    }

    public static func getReasoningParameter(for modelName: String) -> String? {
        if geminiNoneReasoningModels.contains(modelName) { return "none" }
        else if geminiMinimalReasoningModels.contains(modelName) { return "minimal" }
        else if openAINoneReasoningModels.contains(modelName) { return "none" }
        else if openAIMinimalReasoningModels.contains(modelName) { return "minimal" }
        else if cerebrasReasoningModels.contains(modelName) { return "low" }
        else if groqLowReasoningModels.contains(modelName) { return "low" }
        else if groqQwenReasoningModels.contains(modelName) { return "none" }
        else if grokMinimalReasoningModels.contains(modelName) { return "minimal" }
        return nil
    }

    // For models that need custom params instead of reasoning_effort
    public static func getExtraBodyParameters(for modelName: String) -> [String: Any]? {
        if cerebrasDisableReasoningModels.contains(modelName) {
            return ["disable_reasoning": true]
        }
        return nil
    }
}
