//
//  MaintenanceCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.26
//

import Foundation
import SwiftData

/// One side of the maintenance contract: a service that the coordinator can
/// ask to do some cleanup work. The service itself decides whether to
/// actually do anything on a given call (typical adopters gate on a user
/// preference, but that is not part of the protocol). The current adopters
/// - `NoteCleanupService`, `AudioCleanupService`, `ChatCleanupService` -
/// stay independent; `MaintenanceCoordinator` just runs them in sequence.
@MainActor
protocol MaintenanceService {
    func performCleanupIfNeeded(modelContext: ModelContext) async
}

/// Orchestrates the app's periodic cleanup services as a single unit so that
/// callers (MainView's `.task`, app launch flows) don't need to know which
/// cleanup services exist or in what order to run them.
@MainActor
final class MaintenanceCoordinator {
    private let services: [any MaintenanceService]

    init(services: [any MaintenanceService]) {
        self.services = services
    }

    /// Runs every registered cleanup service, in registration order, on the
    /// given model context. Each service independently decides whether to
    /// actually do work.
    ///
    /// Order is stable but not load-bearing: services are independent and
    /// must not depend on each other's side effects. The sequential await is
    /// chosen for predictable resource use, not because of ordering needs.
    func performAllCleanupIfNeeded(modelContext: ModelContext) async {
        for service in services {
            await service.performCleanupIfNeeded(modelContext: modelContext)
        }
    }
}
