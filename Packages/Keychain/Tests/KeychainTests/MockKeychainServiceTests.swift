//
//  MockKeychainServiceTests.swift
//  KeychainTests
//
//  Created by Anton Novoselov on 2026.05.15
//

import Foundation
import Testing
import Keychain
import KeychainMocks

@Suite("MockKeychainService contract")
struct MockKeychainServiceTests {

    @Test func inMemoryRoundtripForStrings() {
        let mock = MockKeychainService()
        #expect(mock.save("hello", forKey: "k", syncable: true))
        #expect(mock.getString(forKey: "k", syncable: true) == "hello")
    }

    @Test func inMemoryRoundtripForData() {
        let mock = MockKeychainService()
        let bytes = Data([0x01, 0x02, 0x03])
        #expect(mock.save(data: bytes, forKey: "k", syncable: true))
        #expect(mock.getData(forKey: "k", syncable: true) == bytes)
    }

    @Test func stubOverrideForcesSaveFailure() {
        let mock = MockKeychainService()
        mock.stubSaveStringResult = false
        #expect(!mock.save("hello", forKey: "k", syncable: true))
        #expect(mock.getString(forKey: "k", syncable: true) == nil,
                "Failed save must not write to the backing store")
    }

    @Test func stubGetStringOverridesBackingStore() {
        let mock = MockKeychainService()
        mock.save("real-value", forKey: "k", syncable: true)
        mock.stubGetString = .some("forced-value")
        #expect(mock.getString(forKey: "k", syncable: true) == "forced-value")
    }

    @Test func stubGetStringSomeNoneReturnsNil() {
        let mock = MockKeychainService()
        mock.save("real-value", forKey: "k", syncable: true)
        mock.stubGetString = .some(nil)
        #expect(mock.getString(forKey: "k", syncable: true) == nil)
    }

    @Test func deleteRemovesFromBackingStore() {
        let mock = MockKeychainService()
        mock.save("temp", forKey: "k", syncable: true)
        #expect(mock.delete(forKey: "k", syncable: true))
        #expect(mock.getString(forKey: "k", syncable: true) == nil)
    }

    @Test func callCountsIncrement() {
        let mock = MockKeychainService()
        mock.save("a", forKey: "x", syncable: true)
        mock.save("b", forKey: "y", syncable: true)
        _ = mock.getString(forKey: "x", syncable: true)
        mock.delete(forKey: "y", syncable: true)
        #expect(mock.saveStringCallCount == 2)
        #expect(mock.getStringCallCount == 1)
        #expect(mock.deleteCallCount == 1)
    }

    @Test func didSaveStringFiresAfterMutation() {
        let mock = MockKeychainService()
        var observedValueAtCallback: String?
        mock.didSaveString = {
            observedValueAtCallback = mock.getString(forKey: "k", syncable: true)
        }
        mock.save("written", forKey: "k", syncable: true)
        #expect(observedValueAtCallback == "written",
                "didSaveString must run after the store has been mutated (defer pattern)")
    }
}
