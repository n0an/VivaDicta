// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AICore
import Networking
import NetworkingMocks
import Testing
@testable import VivaDicta

/// Smoke tests confirming `AIService` plumbs the injected `NetworkService`
/// through to the underlying HTTP calls. Full per-provider coverage lives in
/// each provider's own test suite; this file just locks in the wiring so a
/// future refactor that drops the injection is caught immediately.
@Suite(.tags(.networking))
@MainActor
struct AIServiceNetworkingTests {

    private let suiteName = "AIServiceNetworkingTests.\(UUID().uuidString)"

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func storesInjectedNetworkService() {
        let networkService = MockNetworkService()
        let sut = AIService(userDefaults: makeDefaults(), networkService: networkService)

        #expect(sut.networkService is MockNetworkService)
    }

    @Test func defaultNetworkServiceIsDefaultNetworkServiceWhenNotInjected() {
        let sut = AIService(userDefaults: makeDefaults())

        #expect(sut.networkService is DefaultNetworkService)
    }

    // MARK: - Dynamic catalog: fetched list wins, static list is the fallback

    @Test func getAvailableModelsPrefersFetchedOpencodeZenCatalogOverStatic() {
        // Mock network with no stub: any catalog fetch fails gracefully, so the
        // list stays empty until we set it explicitly below.
        let sut = AIService(userDefaults: makeDefaults(), networkService: MockNetworkService())

        // Before a fetch: the curated static list.
        #expect(sut.getAvailableModels(for: .opencodeZen) == AIProvider.opencodeZen.availableModels)

        // After a fetch: the live catalog wins.
        sut.opencodeZenModels = ["big-pickle", "claude-opus-4-8"]
        #expect(sut.getAvailableModels(for: .opencodeZen) == ["big-pickle", "claude-opus-4-8"])
    }

    @Test func getAvailableModelsPrefersFetchedOpencodeGoCatalogOverStatic() {
        let sut = AIService(userDefaults: makeDefaults(), networkService: MockNetworkService())

        #expect(sut.getAvailableModels(for: .opencodeGo) == AIProvider.opencodeGo.availableModels)

        sut.opencodeGoModels = ["qwen3.7-max", "deepseek-v4-flash"]
        #expect(sut.getAvailableModels(for: .opencodeGo) == ["qwen3.7-max", "deepseek-v4-flash"])
    }
}
