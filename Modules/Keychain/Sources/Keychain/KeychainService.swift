//
//  KeychainService.swift
//  Keychain
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation

/// When a keychain item can be read.
public enum KeychainAccessibility: Sendable {
    /// The system default: readable only while the device is unlocked.
    case whenUnlocked
    /// Readable after the first unlock since boot, including while the device is
    /// locked again, and never synced or migrated to another device. Needed for
    /// secrets that background work (e.g. a background `URLSession` relaunch) reads.
    case afterFirstUnlockThisDeviceOnly
}

/// Secure storage abstraction. The `syncable` flag controls whether the item
/// participates in iCloud Keychain sync; the VivaDicta macOS app and iOS app
/// share API keys via this mechanism.
public protocol KeychainService: Sendable {

    @discardableResult
    func save(_ value: String, forKey key: String, syncable: Bool) -> Bool

    @discardableResult
    func save(data: Data, forKey key: String, syncable: Bool) -> Bool

    /// Saves a device-only item with an explicit accessibility class.
    @discardableResult
    func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) -> Bool

    func getString(forKey key: String, syncable: Bool) -> String?

    func getData(forKey key: String, syncable: Bool) -> Data?

    @discardableResult
    func delete(forKey key: String, syncable: Bool) -> Bool
}

// Default-syncable convenience overloads. Protocol methods cannot carry
// default parameter values, so these live in an extension to preserve the
// `keychain.save(value, forKey: key)` call shape used today.
public extension KeychainService {

    /// Fakes that do not model accessibility store the value as a plain device-only item.
    @discardableResult
    func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) -> Bool {
        save(value, forKey: key, syncable: false)
    }

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
