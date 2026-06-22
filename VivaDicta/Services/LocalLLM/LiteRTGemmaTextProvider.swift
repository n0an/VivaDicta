//
//  LiteRTGemmaTextProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  `AITextProvider` backed by on-device Gemma via LiteRT-LM. Thin: defers the
//  model lifecycle to the shared `LiteRTModelManager` and maps the system +
//  user messages into a single prompt. Output filtering is applied centrally by
//  the caller (TextEnhancer / AIService), so this returns the raw model text.
//
//  Placement note: this lives in the app target because that is where the
//  swift-litert-lm package is linked. The eventual home is a LocalLLM module
//  (constructed via AIKit's AIProviderRegistry, like AppleFMTextProvider), which
//  also firewalls the heavy native runtime - see the local-LLM extraction plan.
//

import Foundation
import AICore

struct LiteRTGemmaTextProvider: AITextProvider {
    private let variant: LiteRTGemmaVariant

    /// - Parameter model: the mode's selected model id (e.g. "gemma-4-E2B" /
    ///   "gemma-4-E4B"); unknown ids fall back to E2B.
    init(model: String = LiteRTGemmaVariant.e2b.rawValue) {
        self.variant = LiteRTGemmaVariant(modelID: model)
    }

    func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await run(systemMessage: systemMessage, userMessage: userMessage, onPartialResponse: nil)
    }

    func enhanceStreaming(
        systemMessage: String,
        userMessage: String,
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        try await run(systemMessage: systemMessage, userMessage: userMessage, onPartialResponse: onPartialResponse)
    }

    private func run(
        systemMessage: String,
        userMessage: String,
        onPartialResponse: (@MainActor (String) -> Void)?
    ) async throws -> String {
        try await LiteRTModelManager.shared.ensureLoaded(variant: variant)

        let prompt = systemMessage + "\n\n" + userMessage
        let stream = try await LiteRTModelManager.shared.stream(prompt: prompt)

        var full = ""
        for try await delta in stream {
            full += delta
            if let onPartialResponse {
                let snapshot = full
                await MainActor.run { onPartialResponse(snapshot) }
            }
        }
        return full.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
