//
//  MaintenanceCoordinator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.26
//

import Foundation
import SwiftData

/// One side of the maintenance contract: a service that does some cleanup
/// work iff its own user-settings gate is on. Implementations stay
/// independent (`NoteCleanupService`, `AudioCleanupService`, `ChatCleanupService`);
/// `MaintenanceCoordinator` just runs them in order.
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
    /// actually do work based on its own user-settings gate.
    func performAllCleanupIfNeeded(modelContext: ModelContext) async {
        for service in services {
            await service.performCleanupIfNeeded(modelContext: modelContext)
        }
    }
}
