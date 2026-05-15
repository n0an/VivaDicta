//
//  MockKeychainService.swift
//  KeychainMocks
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Keychain
import TestUtilities

/// Hybrid fake/mock for `KeychainServicing`.
///
/// Backed by an in-memory `[String: Data]` store so tests don't have to stub
/// every read/write to model state. Stub-style overrides (`stub*Result`) take
/// precedence when set, letting tests force specific failure modes. Per-method
/// `didFoo` callbacks fire via `defer` so test expectations are only signaled
/// after the side effect completes.
public final class MockKeychainService: KeychainServicing, @unchecked Sendable {

    public init() {}

    private var storage: [String: Data] = [:]

    // Call tracking
    public var saveStringCallCount = 0
    public var saveDataCallCount = 0
    public var getStringCallCount = 0
    public var getDataCallCount = 0
    public var deleteCallCount = 0

    // After-side-effect callbacks (Bev `defer { didFoo?() }` pattern)
    public var didSaveString: (() -> Void)?
    public var didSaveData: (() -> Void)?
    public var didGetString: (() -> Void)?
    public var didGetData: (() -> Void)?
    public var didDelete: (() -> Void)?

    // Optional overrides. When non-nil, replace the in-memory behavior.
    public var stubSaveStringResult: Bool?
    public var stubSaveDataResult: Bool?
    public var stubGetString: String??
    public var stubGetData: Data??
    public var stubDeleteResult: Bool?

    @discardableResult
    public func save(_ value: String, forKey key: String, syncable: Bool) -> Bool {
        defer { didSaveString?() }
        saveStringCallCount += 1
        if let override = stubSaveStringResult { return override }
        storage[key] = value.data(using: .utf8)
        return true
    }

    @discardableResult
    public func save(data: Data, forKey key: String, syncable: Bool) -> Bool {
        defer { didSaveData?() }
        saveDataCallCount += 1
        if let override = stubSaveDataResult { return override }
        storage[key] = data
        return true
    }

    public func getString(forKey key: String, syncable: Bool) -> String? {
        defer { didGetString?() }
        getStringCallCount += 1
        if let override = stubGetString { return override }
        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func getData(forKey key: String, syncable: Bool) -> Data? {
        defer { didGetData?() }
        getDataCallCount += 1
        if let override = stubGetData { return override }
        return storage[key]
    }

    @discardableResult
    public func delete(forKey key: String, syncable: Bool) -> Bool {
        defer { didDelete?() }
        deleteCallCount += 1
        if let override = stubDeleteResult { return override }
        storage.removeValue(forKey: key)
        return true
    }
}
