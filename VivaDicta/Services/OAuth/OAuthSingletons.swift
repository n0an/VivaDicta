// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Keychain
import OAuth

/// App-target shared instances of the OAuth managers. The managers themselves
/// live in `Modules/OAuth` and are dependency-injected; this file is the
/// composition root for the convenience singletons used across the app.
extension DefaultOAuthManager {
    @MainActor public static let shared = DefaultOAuthManager(keychain: DefaultKeychainService())
}

extension DefaultCopilotOAuthManager {
    @MainActor public static let shared = DefaultCopilotOAuthManager(
        keychain: DefaultKeychainService(),
        backgroundTaskService: BackgroundTaskServiceAdapter()
    )
}
