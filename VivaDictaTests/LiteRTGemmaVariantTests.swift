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

    @Test("Model id maps to its variant; unknown ids fall back to E2B", arguments: [
        ("gemma-4-E2B", LiteRTGemmaVariant.e2b),
        ("gemma-4-E4B", .e4b),
        ("totally-unknown", .e2b),
        ("", .e2b),
    ])
    func initFromModelID(id: String, expected: LiteRTGemmaVariant) {
        #expect(LiteRTGemmaVariant(modelID: id) == expected)
    }

    // MARK: - recommendedVariant(forPhysicalMemoryBytes:)
    // Boundary triangulation around the 11 GB gate (just-under / on / just-over).

    @Test("Device RAM selects the recommended variant", arguments: [
        (6.0, LiteRTGemmaVariant.e2b),
        (8.0, .e2b),
        (10.99, .e2b),  // just under the 11 GB gate
        (11.0, .e4b),    // exactly on the gate
        (12.0, .e4b),
    ])
    func recommendedVariantForRAM(ramGB: Double, expected: LiteRTGemmaVariant) {
        let bytes = UInt64(ramGB * 1_073_741_824)
        #expect(LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: bytes) == expected)
    }
}
