// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// The CLI backends an enhancement request can be routed through when a local
/// CLI server (a Mac running the Claude / Codex / Gemini CLIs) is configured.
public enum CLIServerProvider: String, Sendable {
    case anthropic
    case codex
    case gemini
}

/// A boundary over the optional "CLI server" enhancement backend.
///
/// The enhancement orchestration can route a request through a user-configured
/// local CLI server instead of (or as a fallback before) a hosted API. That
/// server is an app-level concern (UserDefaults-backed config + auth), so this
/// protocol lets the orchestration depend on the capability rather than the
/// concrete client - the app supplies a `Default`-prefixed adapter, tests a
/// `Mock`. Mirrors how `KeychainService` / `OAuthManager` are injected.
///
/// `isCliActive(for:)` already folds in the master "CLI server enabled" toggle,
/// so a caller only needs `isCliActive(for:) && serverURL` to decide to attempt
/// a CLI call, and `isCliActive(for:)` alone to decide whether the CLI is an
/// available fallback.
///
/// `@MainActor` because the app's CLI client reads main-actor-isolated config;
/// this matches `AIProviderRegistry`, which is also `@MainActor`.
@MainActor
public protocol CLIServerEnhancer {
    /// `true` when the CLI server is enabled *and* the given backend is active
    /// (available + enabled) on it.
    func isCliActive(for provider: CLIServerProvider) -> Bool

    /// The configured CLI server URL, or `nil`/empty when unset.
    var serverURL: String? { get }

    /// Sends an enhancement request to the CLI server. Returns the raw result
    /// (the caller applies its own trimming/filtering).
    func enhance(text: String, systemPrompt: String, model: String, provider: CLIServerProvider) async throws -> String
}
