// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import UIKit
import OAuth

/// App-target adapter that bridges the OAuth module's `BackgroundTaskServicing`
/// protocol to the concrete `BackgroundTaskService` singleton.
struct BackgroundTaskServiceAdapter: BackgroundTaskServicing {
    func beginBackgroundTask(name: String, onExpiration: @escaping @Sendable () -> Void) -> UInt? {
        guard let identifier = BackgroundTaskService.shared?.beginBackgroundTask(name: name, onExpiration: onExpiration) else {
            return nil
        }
        guard identifier != .invalid else { return nil }
        return UInt(identifier.rawValue)
    }

    func endBackgroundTask(_ identifier: UInt) {
        BackgroundTaskService.shared?.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: Int(identifier)))
    }
}
