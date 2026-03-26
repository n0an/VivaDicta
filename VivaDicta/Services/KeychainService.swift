//
//  KeychainService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.19
//

import Foundation
import Security
import os

/// Securely stores and retrieves API keys using Keychain with iCloud sync.
/// Uses the same `kSecAttrService` as the macOS app so items sync via iCloud Keychain.
final class KeychainService: Sendable {
    static let shared = KeychainService()

    private let logger = Logger(category: .keychainService)

    /// Must match macOS KeychainService for iCloud Keychain sync
    private let service = "com.antonnovoselov.VivaDicta"

    private init() {}

    @discardableResult
    func save(_ value: String, forKey key: String, syncable: Bool = true) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.logError("Failed to convert value to data for key: \(key)")
            return false
        }
        return save(data: data, forKey: key, syncable: syncable)
    }

    @discardableResult
    func save(data: Data, forKey key: String, syncable: Bool = true) -> Bool {
        delete(forKey: key, syncable: syncable)

        var query = baseQuery(forKey: key, syncable: syncable)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            return true
        } else {
            logger.logError("Failed to save keychain item for key: \(key), status: \(status)")
            return false
        }
    }

    func getString(forKey key: String, syncable: Bool = true) -> String? {
        guard let data = getData(forKey: key, syncable: syncable) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getData(forKey key: String, syncable: Bool = true) -> Data? {
        var query = baseQuery(forKey: key, syncable: syncable)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    @discardableResult
    func delete(forKey key: String, syncable: Bool = true) -> Bool {
        let query = baseQuery(forKey: key, syncable: syncable)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(forKey key: String, syncable: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
        if syncable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        return query
    }
}

// MARK: - AIProvider convenience

extension AIProvider {
    /// Reads this provider's API key from the Keychain.
    var apiKey: String? {
        let key = keychainKey
        guard !key.isEmpty else { return nil }
        return KeychainService.shared.getString(forKey: key)
    }
}
