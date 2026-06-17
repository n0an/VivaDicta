import Foundation

/// A provider that turns a system message + user message into enhanced text,
/// with an optional streaming variant that reports partial results.
///
/// Conformers bind their per-provider configuration (API key, endpoint URL,
/// headers, model, OAuth token, sampling profile, ...) at construction, so this
/// protocol stays uniform across every backend. Consumers (the orchestrator /
/// registry) depend only on `AITextProvider` and never on a concrete provider.
public protocol AITextProvider: Sendable {
    /// Non-streaming enhancement. Returns the final enhanced text.
    func enhance(systemMessage: String, userMessage: String) async throws -> String

    /// Streaming enhancement. Calls `onPartialResponse` on the main actor as
    /// partial text arrives, and returns the final enhanced text.
    func enhanceStreaming(
        systemMessage: String,
        userMessage: String,
        onPartialResponse: @escaping @MainActor (String) -> Void
    ) async throws -> String
}
