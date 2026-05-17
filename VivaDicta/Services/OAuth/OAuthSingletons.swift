// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Keychain
import OAuth

/// App-target shared instances of the OAuth managers. The managers themselves
/// live in `Modules/OAuth` and are dependency-injected; this file is the
/// composition root for the convenience singletons used across the app.
extension OAuthManager {
    @MainActor public static let shared = OAuthManager(keychain: DefaultKeychainService())
}

extension CopilotOAuthManager {
    @MainActor public static let shared = CopilotOAuthManager(
        keychain: DefaultKeychainService(),
        backgroundTaskService: BackgroundTaskServiceAdapter()
    )
}
