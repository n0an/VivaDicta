// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Abstraction over a background-task scheduler so OAuth managers can keep
/// short async flows alive (e.g. device-code polling while the user authorizes
/// in Safari) without depending on the app target's `BackgroundTaskService`.
///
/// The app target provides an adapter that forwards to `UIApplication`.
public protocol BackgroundTaskService: Sendable {
    /// Begin a background task with the given name. `onExpiration` runs when
    /// the system is about to terminate the task. Returns an opaque identifier
    /// used to end the task, or `nil` if the task could not be started.
    @MainActor func beginBackgroundTask(name: String, onExpiration: @escaping @Sendable () -> Void) -> UInt?

    /// Ends a previously begun background task.
    @MainActor func endBackgroundTask(_ identifier: UInt)
}
