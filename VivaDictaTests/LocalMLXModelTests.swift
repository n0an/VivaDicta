//
//  LocalMLXModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Pure logic on the on-device MLX model catalog: model-id parsing (with
//  fallback), repo mapping, the recommendation flag, and the thinking-toggle
//  flag. No filesystem or GPU.
//

import Foundation
import Testing
@testable import VivaDicta

struct LocalMLXModelTests {

    @Test("Model id maps to its model; unknown ids fall back to Qwen3.5 2B", arguments: [
        ("gemma-3n-e2b-mlx", LocalMLXModel.gemma3n_E2B),
        ("gemma-3n-e4b-mlx", .gemma3n_E4B),
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

    @Test func onlyQwen2BIsRecommended() {
        let recommended = LocalMLXModel.allCases.filter(\.isRecommendedForThisDevice)
        #expect(recommended == [.qwen35_2B])
    }

    @Test("Only the Qwen models expose the thinking toggle", arguments: [
        (LocalMLXModel.gemma3n_E2B, false),
        (.gemma3n_E4B, false),
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

    @Test func catalogIsTheTenCurrentSmallModels() {
        #expect(LocalMLXModel.allCases.count == 10)
    }
}
