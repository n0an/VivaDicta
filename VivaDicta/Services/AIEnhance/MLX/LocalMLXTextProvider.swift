//
//  LocalMLXTextProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.24
//
//  `AITextProvider` backed by on-device MLX (GPU). Thin: defers the model
//  lifecycle to the shared `LocalMLXModelManager` and streams chunks. Output
//  filtering is applied centrally by the caller (AIService), so this returns
//  the raw model text.
//

import Foundation
import AICore

struct LocalMLXTextProvider: AITextProvider {
    private let model: LocalMLXModel

    /// - Parameter model: the mode's selected model id (e.g. "qwen3.5-2b-mlx");
    ///   unknown ids fall back to the recommended model.
    init(model: String) {
        self.model = LocalMLXModel(modelID: model)
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
        let stream = try await LocalMLXModelManager.shared.stream(
            model: model,
            systemMessage: systemMessage,
            userMessage: userMessage
        )

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
