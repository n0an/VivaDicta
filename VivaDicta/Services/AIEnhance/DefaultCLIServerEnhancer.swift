//
//  DefaultCLIServerEnhancer.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.17
//

import Foundation
import AIKit

/// Production `CLIServerEnhancer` backed by ``VivAgentsClient``.
///
/// Adapts the app's all-static CLI-server client to the `AIKit` boundary so the
/// enhancement orchestration depends on the protocol rather than the global.
/// Stateless, so `Sendable` is trivial; every call forwards to `VivAgentsClient`.
struct DefaultCLIServerEnhancer: CLIServerEnhancer {
    func isCliActive(for provider: CLIServerProvider) -> Bool {
        guard VivAgentsClient.isEnabled else { return false }
        switch provider {
        case .anthropic: return VivAgentsClient.isAnthropicCliActive
        case .codex: return VivAgentsClient.isCodexCliActive
        case .gemini: return VivAgentsClient.isGeminiCliActive
        }
    }

    var serverURL: String? { VivAgentsClient.serverURL }

    func enhance(text: String, systemPrompt: String, model: String, provider: CLIServerProvider) async throws -> String {
        try await VivAgentsClient.enhance(text: text, systemPrompt: systemPrompt, model: model, provider: provider.rawValue)
    }
}
