//
//  LocalMLXModelTests.swift
//  LocalLLMTests
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Pure logic on the on-device MLX model catalog: model-id parsing (with
//  fallback), repo mapping, the recommendation flag, and the thinking-toggle
//  flag. No filesystem or GPU.
//

import Foundation
import Testing
@testable import LocalLLM

struct LocalMLXModelTests {

    @Test("Model id maps to its model; unknown ids fall back to Qwen3.5 2B", arguments: [
        ("qwen3.5-4b-mlx", LocalMLXModel.qwen35_4B),
        ("qwen3.5-2b-mlx", .qwen35_2B),
        ("qwen3.5-0.8b-mlx", .qwen35_08B),
        ("phi-4-mini-mlx", .phi4Mini),
        ("llama-3.2-1b-mlx", .llama32_1B),
        ("llama-3.2-3b-mlx", .llama32_3B),
        ("ministral-3b-mlx", .ministral3B),
        ("falcon3-3b-mlx", .falcon3_3B),
        ("granite-3.3-2b-mlx", .granite33_2B),
        ("totally-unknown", .qwen35_2B),
        ("", .qwen35_2B),
        ("llama-3.2-3b", .qwen35_2B), // the old LiteRT id is not an MLX id -> fallback
    ])
    func initFromModelID(id: String, expected: LocalMLXModel) {
        #expect(LocalMLXModel(modelID: id) == expected)
    }

    @Test func everyModelMapsToAnMlxCommunityRepo() {
        for model in LocalMLXModel.allCases {
            #expect(model.mlxRepo.hasPrefix("mlx-community/"))
        }
    }

    @Test func rawValueRoundTripsForModelStorage() {
        for model in LocalMLXModel.allCases {
            #expect(LocalMLXModel(rawValue: model.rawValue) == model)
        }
    }

    // Device RAM picks the recommended Qwen. Boundary triangulation around the
    // 7 GB and 11 GB gates (just-under / on / just-over).
    @Test("Device RAM selects the recommended Qwen", arguments: [
        (6.0, LocalMLXModel.qwen35_08B),
        (6.99, .qwen35_08B),   // just under the 7 GB gate
        (7.0, .qwen35_2B),     // exactly on the 7 GB gate
        (8.0, .qwen35_2B),
        (10.99, .qwen35_2B),   // just under the 11 GB gate
        (11.0, .qwen35_4B),    // exactly on the 11 GB gate
        (12.0, .qwen35_4B),
    ])
    func recommendedQwenForRAM(ramGB: Double, expected: LocalMLXModel) {
        let bytes = UInt64(ramGB * 1_073_741_824)
        #expect(LocalMLXModel.recommendedQwen(forPhysicalMemoryBytes: bytes) == expected)
    }

    @Test("Only the Qwen models expose the thinking toggle", arguments: [
        (LocalMLXModel.qwen35_4B, true),
        (.qwen35_2B, true),
        (.qwen35_08B, true),
        (.phi4Mini, false),
        (.llama32_1B, false),
        (.llama32_3B, false),
        (.ministral3B, false),
        (.falcon3_3B, false),
        (.granite33_2B, false),
    ])
    func supportsThinkingToggle(model: LocalMLXModel, expected: Bool) {
        #expect(model.supportsThinkingToggle == expected)
    }

    @Test func catalogIsTheNineCurrentSmallModels() {
        #expect(LocalMLXModel.allCases.count == 9)
    }
}
