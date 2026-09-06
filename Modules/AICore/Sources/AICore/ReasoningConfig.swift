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

    // "low" is the floor for these: they reject "minimal" outright with a
    // validation error, so the usual minimal-effort default would 400 every
    // enhancement call.
    static let geminiLowReasoningModels: Set<String> = [
        "gemini-3.8-flash",
        "gemini-3.7-flash"
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

    /// "low" is the floor for these: unlike the GPT-5 generation they offer no
    /// "none" or "minimal" level (gpt-6-astra takes low/medium/high/xhigh/max),
    /// so asking for one would 400 every enhancement call. Left at the floor
    /// because cleaning up dictation gains nothing from a longer reasoning pass.
    static let openAILowReasoningModels: Set<String> = [
        "gpt-6-astra"
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

    /// Whether the model belongs to OpenAI's reasoning family, which steers
    /// effort with `reasoning_effort` rather than `temperature` and renamed its
    /// output cap. Covers the GPT-5 generation and GPT-6 (`gpt-6-astra`).
    ///
    /// Matched on the bare model id so gateway-prefixed ids
    /// ("openai/gpt-5.6-terra" on OpenRouter or Vercel) are covered too.
    private static func isOpenAIReasoningFamily(_ modelName: String) -> Bool {
        let id = bareModelID(modelName)
        return id.hasPrefix("gpt-5") || id.hasPrefix("gpt-6")
    }

    /// Whether a `temperature` field belongs in this model's request body.
    ///
    /// False for OpenAI's reasoning family, which uses `reasoning_effort`, and
    /// for the models above, which accept only 1 - omitting it lets the server
    /// pick that default rather than us hard-coding a value per family.
    public static func sendsTemperature(for modelName: String) -> Bool {
        if isOpenAIReasoningFamily(modelName) { return false }
        let id = modelName.lowercased()
        return !fixedTemperatureModelIDs.contains(where: id.contains)
    }

    /// Whether this model's output cap belongs in `max_completion_tokens`
    /// rather than `max_tokens`.
    ///
    /// OpenAI's reasoning family rejects the older field outright:
    /// `Unsupported parameter: 'max_tokens' is not supported with this model.
    /// Use 'max_completion_tokens' instead.`
    public static func usesMaxCompletionTokens(for modelName: String) -> Bool {
        isOpenAIReasoningFamily(modelName)
    }

    /// Floor for an output cap sent to a reasoning model.
    ///
    /// The cap covers reasoning tokens as well as visible output, and a model
    /// that spends the whole budget thinking answers 400 `Could not finish the
    /// message because max_tokens or model output limit was reached` - which a
    /// key check would misread as a bad key. Measured against gpt-5.6-terra on
    /// 2026-08-29: a 1-token cap fails outright, and reasoning spend on the
    /// same prompt varied between 0 and 6 tokens run to run, so the floor buys
    /// headroom rather than sitting just above the observed spend. Still small
    /// enough to cap a runaway probe on a heavy model.
    public static let minimumReasoningOutputTokens = 256

    /// Strips a gateway's vendor prefix ("openai/gpt-5.6-terra" -> "gpt-5.6-terra")
    /// and lowercases, so model-family checks work whichever route serves the model.
    private static func bareModelID(_ modelName: String) -> String {
        let id = modelName.lowercased()
        guard let lastSlash = id.lastIndex(of: "/") else { return id }
        return String(id[id.index(after: lastSlash)...])
    }

    public static func getReasoningParameter(for modelName: String) -> String? {
        if geminiNoneReasoningModels.contains(modelName) { return "none" }
        else if geminiLowReasoningModels.contains(modelName) { return "low" }
        else if geminiMinimalReasoningModels.contains(modelName) { return "minimal" }
        else if openAINoneReasoningModels.contains(modelName) { return "none" }
        else if openAIMinimalReasoningModels.contains(modelName) { return "minimal" }
        else if openAILowReasoningModels.contains(modelName) { return "low" }
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
