//
//  MaintenanceCoordinatorTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.26
//

import Foundation
import SwiftData
import Testing
@testable import VivaDicta

@MainActor
@Suite(.tags(.database))
struct MaintenanceCoordinatorTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    @Test func performAllCleanupIfNeeded_runsEachServiceOnce() async throws {
        let s1 = FakeMaintenanceService(label: "a")
        let s2 = FakeMaintenanceService(label: "b")
        let s3 = FakeMaintenanceService(label: "c")
        let sut = MaintenanceCoordinator(services: [s1, s2, s3])
        let context = try makeContext()

        await sut.performAllCleanupIfNeeded(modelContext: context)

        #expect(s1.callCount == 1)
        #expect(s2.callCount == 1)
        #expect(s3.callCount == 1)
    }

    @Test func performAllCleanupIfNeeded_runsServicesInRegistrationOrder() async throws {
        let order = OrderRecorder()
        let s1 = FakeMaintenanceService(label: "first", recorder: order)
        let s2 = FakeMaintenanceService(label: "second", recorder: order)
        let s3 = FakeMaintenanceService(label: "third", recorder: order)
        let sut = MaintenanceCoordinator(services: [s1, s2, s3])
        let context = try makeContext()

        await sut.performAllCleanupIfNeeded(modelContext: context)

        #expect(order.calls == ["first", "second", "third"])
    }

    @Test func performAllCleanupIfNeeded_passesModelContextToEachService() async throws {
        let s1 = FakeMaintenanceService(label: "a")
        let sut = MaintenanceCoordinator(services: [s1])
        let context = try makeContext()

        await sut.performAllCleanupIfNeeded(modelContext: context)

        #expect(s1.receivedContext === context)
    }

    @Test func performAllCleanupIfNeeded_withEmptyServiceList_isNoOp() async throws {
        let sut = MaintenanceCoordinator(services: [])
        let context = try makeContext()

        await sut.performAllCleanupIfNeeded(modelContext: context)
    }
}

@MainActor
final class FakeMaintenanceService: MaintenanceService {
    let label: String
    private(set) var callCount = 0
    private(set) var receivedContext: ModelContext?
    private weak var recorder: OrderRecorder?

    init(label: String, recorder: OrderRecorder? = nil) {
        self.label = label
        self.recorder = recorder
    }

    func performCleanupIfNeeded(modelContext: ModelContext) async {
        callCount += 1
        receivedContext = modelContext
        recorder?.calls.append(label)
    }
}

@MainActor
final class OrderRecorder {
    var calls: [String] = []
}
