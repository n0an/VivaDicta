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
//  Placement note: this currently lives in the app target alongside the spike
//  because that is where the swift-litert-lm package is linked. The production
//  home is the AIProviders module (constructed by AIKit's AIProviderRegistry,
//  like AppleFMTextProvider); extraction is a follow-up once the spike validates.
//

import Foundation
import AICore

struct LiteRTGemmaTextProvider: AITextProvider {
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
        try await LiteRTModelManager.shared.ensureLoaded()

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
