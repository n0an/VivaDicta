//
//  KeychainServiceImpl.swift
//  Keychain
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import os
import Security

/// Production keychain implementation. The default `service` value must match
/// the macOS VivaDicta app for iCloud Keychain sync to work; do not change it
/// without coordinating across both platforms.
public final class KeychainServiceImpl: KeychainServicing, Sendable {

    public static let defaultService = "com.antonnovoselov.VivaDicta"

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeychainService")
    private let service: String

    public init(service: String = KeychainServiceImpl.defaultService) {
        self.service = service
    }

    @discardableResult
    public func save(_ value: String, forKey key: String, syncable: Bool) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to convert value to data for key: \(key, privacy: .public)")
            return false
        }
        return save(data: data, forKey: key, syncable: syncable)
    }

    @discardableResult
    public func save(data: Data, forKey key: String, syncable: Bool) -> Bool {
        delete(forKey: key, syncable: syncable)

        var query = baseQuery(forKey: key, syncable: syncable)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            return true
        } else {
            logger.error("Failed to save keychain item for key: \(key, privacy: .public), status: \(status)")
            return false
        }
    }

    public func getString(forKey key: String, syncable: Bool) -> String? {
        guard let data = getData(forKey: key, syncable: syncable) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func getData(forKey key: String, syncable: Bool) -> Data? {
        var query = baseQuery(forKey: key, syncable: syncable)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    @discardableResult
    public func delete(forKey key: String, syncable: Bool) -> Bool {
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
