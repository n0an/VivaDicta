// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Keychain
import OAuth

/// App-target shared instances of the OAuth managers. The managers themselves
/// live in `Modules/OAuth` and are dependency-injected; this file is the
/// composition root for the convenience singletons used across the app.
extension DefaultOAuthManager {
    /// `backgroundTaskService` keeps device-code polling alive while the user is
    /// away in Safari approving the code (the app is backgrounded for that
    /// stretch). Unused by the redirect flow, which never leaves the app.
    @MainActor public static let shared = DefaultOAuthManager(
        keychain: DefaultKeychainService(),
        backgroundTaskService: BackgroundTaskServiceAdapter()
    )
}

extension DefaultCopilotOAuthManager {
    @MainActor public static let shared = DefaultCopilotOAuthManager(
        keychain: DefaultKeychainService(),
        backgroundTaskService: BackgroundTaskServiceAdapter()
    )
}
