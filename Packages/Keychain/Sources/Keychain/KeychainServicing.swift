//
//  KeychainServicing.swift
//  Keychain
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation

/// Secure storage abstraction. The `syncable` flag controls whether the item
/// participates in iCloud Keychain sync; the VivaDicta macOS app and iOS app
/// share API keys via this mechanism.
public protocol KeychainServicing: Sendable {

    @discardableResult
    func save(_ value: String, forKey key: String, syncable: Bool) -> Bool

    @discardableResult
    func save(data: Data, forKey key: String, syncable: Bool) -> Bool

    func getString(forKey key: String, syncable: Bool) -> String?

    func getData(forKey key: String, syncable: Bool) -> Data?

    @discardableResult
    func delete(forKey key: String, syncable: Bool) -> Bool
}

// Default-syncable convenience overloads. Protocol methods cannot carry
// default parameter values, so these live in an extension to preserve the
// `KeychainService.shared.save(value, forKey: key)` call shape used today.
public extension KeychainServicing {

    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        save(value, forKey: key, syncable: true)
    }

    @discardableResult
    func save(data: Data, forKey key: String) -> Bool {
        save(data: data, forKey: key, syncable: true)
    }

    func getString(forKey key: String) -> String? {
        getString(forKey: key, syncable: true)
    }

    func getData(forKey key: String) -> Data? {
        getData(forKey: key, syncable: true)
    }

    @discardableResult
    func delete(forKey key: String) -> Bool {
        delete(forKey: key, syncable: true)
    }
}
