// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import UIKit
import OAuth

/// App-target adapter that bridges the OAuth module's `BackgroundTaskService`
/// protocol to the concrete `BackgroundTaskManager` singleton.
struct BackgroundTaskServiceAdapter: BackgroundTaskService {
    func beginBackgroundTask(name: String, onExpiration: @escaping @Sendable () -> Void) -> UInt? {
        guard let identifier = BackgroundTaskManager.shared?.beginBackgroundTask(name: name, onExpiration: onExpiration) else {
            return nil
        }
        guard identifier != .invalid else { return nil }
        return UInt(identifier.rawValue)
    }

    func endBackgroundTask(_ identifier: UInt) {
        BackgroundTaskManager.shared?.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: Int(identifier)))
    }
}
