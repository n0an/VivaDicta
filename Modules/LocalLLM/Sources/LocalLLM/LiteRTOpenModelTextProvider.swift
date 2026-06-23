//
//  LiteRTOpenModelTextProvider.swift
//  LocalLLM
//
//  Created by Anton Novoselov on 2026.06.23
//
//  `AITextProvider` backed by an on-device open LiteRT model (Llama / Ministral /
//  Falcon / DeepSeek). Thin: defers the lifecycle to the shared
//  `LiteRTOpenModelManager`. Output filtering is applied centrally by the caller.
//

import Foundation
import AICore

public struct LiteRTOpenModelTextProvider: AITextProvider {
    private let model: LiteRTOpenModel

    public init(model: String = LiteRTOpenModel.llama32_3B.rawValue) {
        self.model = LiteRTOpenModel(modelID: model)
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
        try await LiteRTOpenModelManager.shared.loadForGeneration(model: model)

        let prompt = systemMessage + "\n\n" + userMessage
        let stream = try await LiteRTOpenModelManager.shared.stream(prompt: prompt)

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
