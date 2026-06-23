//
//  CoreMLQwenTextProvider.swift
//  LocalLLM
//
//  Created by Anton Novoselov on 2026.06.23
//
//  `AITextProvider` backed by on-device Qwen3.5 via CoreML-LLM. Thin: defers the
//  model lifecycle to the shared `CoreMLQwenModelManager` and maps the system +
//  user messages into a single prompt. Output filtering is applied centrally by
//  the caller (TextEnhancer / AIService), so this returns the raw model text.
//

import Foundation
import AICore

public struct CoreMLQwenTextProvider: AITextProvider {
    private let variant: CoreMLQwenVariant

    /// - Parameter model: the mode's selected model id (e.g. "qwen3.5-2b" /
    ///   "qwen3.5-0.8b"); unknown ids fall back to 2B.
    public init(model: String = CoreMLQwenVariant.qwen2B.rawValue) {
        self.variant = CoreMLQwenVariant(modelID: model)
    }

    public func enhance(systemMessage: String, userMessage: String) async throws -> String {
        try await run(systemMessage: systemMessage, userMessage: userMessage, onPartialResponse: nil)
    }

    public func enhanceStreaming(
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
        // loadForGeneration never downloads - throws .notDownloaded if the model
        // isn't on disk rather than silently starting a multi-GB fetch.
        try await CoreMLQwenModelManager.shared.loadForGeneration(variant: variant)

        let prompt = systemMessage + "\n\n" + userMessage
        let stream = try await CoreMLQwenModelManager.shared.stream(prompt: prompt)

        var full = ""
        for await delta in stream {
            full += delta
            if let onPartialResponse {
                let snapshot = full
                await MainActor.run { onPartialResponse(snapshot) }
            }
        }
        return full.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
