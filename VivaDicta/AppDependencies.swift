//
//  AppDependencies.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Keychain
import SwiftUI

/// Composition root. Owns the app's injectable dependencies as protocol
/// instances so services and view models can take them in `init` instead
/// of reaching for `*.shared` singletons.
///
/// Production wiring uses the default `init()`. Tests and SwiftUI previews
/// supply mocks via the parameterized init.
struct AppDependencies: Sendable {

    let keychain: any KeychainServicing

    init(keychain: any KeychainServicing = KeychainServiceImpl()) {
        self.keychain = keychain
    }
}

// MARK: - SwiftUI Environment

/// Exposes `AppDependencies` to any view via `@Environment(\.dependencies)`.
/// The default value constructs a real `KeychainServiceImpl()` so SwiftUI
/// previews remain functional without explicit wiring. Tests and previews
/// that need a mock pass it through `.environment(\.dependencies, …)`.
private struct DependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies()
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}
