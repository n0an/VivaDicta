// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Client-identification headers for the OpenCode gateway (`opencode.ai`),
/// which serves both `.opencodeZen` and `.opencodeGo`.
///
/// The gateway routes on these headers, not on the API key alone. A caller
/// that sends none is treated as anonymous and rate-limited hard, and
/// `x-opencode-session` is what gives a run of requests provider affinity so
/// the gateway can reuse a prompt cache across them. VivaDicta sent only
/// `Authorization`, which put every user in that anonymous bucket.
///
/// The values identify VivaDicta honestly. The official OpenCode CLI sends
/// `x-opencode-client: cli` under a matching `opencode/…` user agent; copying
/// those would claim to be a client this is not, so the client id and user
/// agent name this app instead. `x-opencode-project` is left off - VivaDicta
/// has no project to group requests by, and a synthetic id would only be
/// noise.
public enum OpenCodeHeaders {
    /// Stable for the lifetime of the process.
    ///
    /// VivaDicta has no conversation that outlives a launch - an enhancement
    /// is a single request - but every request in a launch shares the same
    /// system-prompt prefix, which is exactly what the gateway's cache is for.
    /// A fresh id per request would defeat it.
    private static let sessionID = UUID().uuidString

    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    private static var platformName: String {
        #if os(macOS)
        "macOS"
        #else
        "iOS"
        #endif
    }

    /// Headers for one request to `opencode.ai`. Empty for every other provider,
    /// so call sites can merge unconditionally.
    public static func headers(for provider: AIProvider) -> [String: String] {
        guard provider == .opencodeZen || provider == .opencodeGo else { return [:] }

        return [
            "x-opencode-client": "vivadicta",
            "x-opencode-session": sessionID,
            "x-opencode-request": UUID().uuidString,
            "User-Agent": "VivaDicta/\(appVersion) (\(platformName))"
        ]
    }
}
