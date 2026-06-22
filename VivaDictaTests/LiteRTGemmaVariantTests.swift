//
//  LiteRTGemmaVariantTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.06.22
//
//  Pure logic on the on-device Gemma variant: model-id parsing (with fallback)
//  and the device-RAM recommendation threshold. No filesystem or GPU.
//

import Foundation
import Testing
@testable import VivaDicta

struct LiteRTGemmaVariantTests {

    // MARK: - init(modelID:)

    @Test func initFromModelID_knownE2B() {
        #expect(LiteRTGemmaVariant(modelID: "gemma-4-E2B") == .e2b)
    }

    @Test func initFromModelID_knownE4B() {
        #expect(LiteRTGemmaVariant(modelID: "gemma-4-E4B") == .e4b)
    }

    @Test func initFromModelID_unknownFallsBackToE2B() {
        #expect(LiteRTGemmaVariant(modelID: "totally-unknown") == .e2b)
        #expect(LiteRTGemmaVariant(modelID: "") == .e2b)
    }

    // MARK: - recommendedVariant(forPhysicalMemoryBytes:)
    // Boundary triangulation around the 11 GB gate (just-under / on / just-over).

    private static let gb: UInt64 = 1_073_741_824

    @Test func recommended_eightGBDevice_isE2B() {
        #expect(LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: 8 * Self.gb) == .e2b)
    }

    @Test func recommended_sixGBDevice_isE2B() {
        #expect(LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: 6 * Self.gb) == .e2b)
    }

    @Test func recommended_justUnderElevenGB_isE2B() {
        let justUnder = UInt64(10.9 * Double(Self.gb))
        #expect(LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: justUnder) == .e2b)
    }

    @Test func recommended_exactlyElevenGB_isE4B() {
        #expect(LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: 11 * Self.gb) == .e4b)
    }

    @Test func recommended_twelveGBDevice_isE4B() {
        #expect(LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: 12 * Self.gb) == .e4b)
    }

    @Test func recommended_exactlyOneVariantPerDevice() {
        // The badge logic assumes exactly one variant is recommended on any device.
        for bytes in [6 * Self.gb, 8 * Self.gb, 11 * Self.gb, 12 * Self.gb, 16 * Self.gb] {
            let recommended = LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: bytes)
            let matches = LiteRTGemmaVariant.allCases.filter { $0 == recommended }
            #expect(matches.count == 1)
        }
    }
}
