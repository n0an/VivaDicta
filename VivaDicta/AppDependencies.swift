//
//  AppDependencies.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Keychain

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
