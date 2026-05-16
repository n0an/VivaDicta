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
        let sut = MockKeychainService()
        #expect(sut.save("hello", forKey: "k", syncable: true))
        #expect(sut.getString(forKey: "k", syncable: true) == "hello")
    }

    @Test func inMemoryRoundtripForData() {
        let sut = MockKeychainService()
        let bytes = Data([0x01, 0x02, 0x03])
        #expect(sut.save(data: bytes, forKey: "k", syncable: true))
        #expect(sut.getData(forKey: "k", syncable: true) == bytes)
    }

    @Test func stubOverrideForcesSaveFailure() {
        let sut = MockKeychainService()
        sut.stubSaveStringResult = false
        #expect(!sut.save("hello", forKey: "k", syncable: true))
        #expect(sut.getString(forKey: "k", syncable: true) == nil)
    }

    @Test func deleteRemovesFromBackingStore() {
        let sut = MockKeychainService()
        sut.save("temp", forKey: "k", syncable: true)
        #expect(sut.delete(forKey: "k", syncable: true))
        #expect(sut.getString(forKey: "k", syncable: true) == nil)
    }

    @Test func callCountsIncrement() {
        let sut = MockKeychainService()
        sut.save("a", forKey: "x", syncable: true)
        sut.save("b", forKey: "y", syncable: true)
        _ = sut.getString(forKey: "x", syncable: true)
        sut.delete(forKey: "y", syncable: true)
        #expect(sut.saveStringCallCount == 2)
        #expect(sut.getStringCallCount == 1)
        #expect(sut.deleteCallCount == 1)
    }

    @Test func didSaveStringFiresAfterMutation() {
        let sut = MockKeychainService()
        var observed: String?
        sut.didSaveString = {
            observed = sut.getString(forKey: "k", syncable: true)
        }
        sut.save("written", forKey: "k", syncable: true)
        #expect(observed == "written")
    }
}
