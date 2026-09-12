//
//  StateLosingHostAppsTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.09.12
//

import Foundation
import Testing
@testable import VivaDicta

struct StateLosingHostAppsTests {
    private let sut = VivaDictaApp.StateLosingHostApps.self

    @Test func declinesReturnURLForAListedHost() {
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.MobileSMS", isSkipEnabled: true))
    }

    @Test func keepsReturnURLForAListedHostWhenTheSettingIsOff() {
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.MobileSMS", isSkipEnabled: false) == false)
    }

    @Test func keepsReturnURLForAHostThatReturnsCorrectly() {
        // Notes and Mail resume where the user was, so they must keep the
        // automatic teleport even with the setting on.
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.mobilenotes", isSkipEnabled: true) == false)
        #expect(sut.shouldDeclineReturnURL(hostId: "com.apple.mobilemail", isSkipEnabled: true) == false)
    }

    @Test func keepsReturnURLForAnUnknownHost() {
        #expect(sut.shouldDeclineReturnURL(hostId: "com.example.unknown", isSkipEnabled: true) == false)
    }

    @Test func everyEntryHasADisplayNameForTheSettingsList() {
        #expect(sut.displayNames.count == sut.entries.count)
        #expect(sut.displayNames.allSatisfy { !$0.isEmpty })
    }

    @Test func bundleIdsAreUnique() {
        #expect(sut.bundleIds.count == sut.entries.count)
    }
}

#if DEBUG
/// The debug return URL experiment that sits on top of the skip list.
///
/// The precedence *ordering* itself lives in two sequential branches inside
/// `VivaDictaApp.attemptReturnToHost(hostId:)` and is not reachable from a
/// test without restructuring the `App` type, so what is covered here is the
/// part that can actually go wrong silently: how a stored candidate resolves,
/// and whether every candidate in the table still resolves to what its label
/// promises.
struct ReturnURLExperimentTests {
    private let sut = VivaDictaApp.ReturnURLExperiment.self

    @Test func resolvesAnUnpickedCandidateToNoOverride() {
        #expect(sut.override(forRawValue: "") == .unset)
    }

    @Test func resolvesTheSkipCandidateToAManualReturn() {
        #expect(sut.override(forRawValue: "skip") == .skip)
    }

    @Test func resolvesACandidateURLToThatURL() {
        #expect(sut.override(forRawValue: "com-apple-mobilesafari-tab://")
                == .url(URL(string: "com-apple-mobilesafari-tab://")!))
    }

    @Test func treatsACandidateWithNoSchemeAsNoOverride() {
        // A typo in the table must degrade to shipping behavior, never to a
        // dead end the device log cannot explain. `URL(string:)` alone is not
        // the guard here - it accepts "not a url" and percent-encodes it.
        #expect(sut.override(forRawValue: "not a url") == .unset)
        #expect(sut.override(forRawValue: "mobilenotes") == .unset)
    }

    @Test func everyCandidateURLInTheTableStillParses() {
        for host in sut.hosts {
            for candidate in host.candidates {
                let expected: VivaDictaApp.ReturnURLExperiment.Override = switch candidate.id {
                case "": .unset
                case "skip": .skip
                default: .url(URL(string: candidate.id)!)
                }
                #expect(sut.override(forRawValue: candidate.id) == expected,
                        "\(host.displayName) candidate '\(candidate.label)' no longer resolves")
            }
        }
    }

    @Test func coversExactlyTheHostsOnTheSkipList() {
        // The experiment exists to find a better URL for the skipped apps, so
        // the two tables must not drift apart.
        #expect(Set(sut.hosts.map(\.bundleId)) == VivaDictaApp.StateLosingHostApps.bundleIds)
    }

    @Test func leavesHostsOutsideTheExperimentAlone() {
        #expect(sut.override(forHostId: "com.apple.mobilenotes") == .unset)
    }
}
#endif
