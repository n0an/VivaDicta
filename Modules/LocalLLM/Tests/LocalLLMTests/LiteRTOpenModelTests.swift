//
//  LiteRTOpenModelTests.swift
//  LocalLLMTests
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Pure logic on the on-device open LiteRT model catalog: model-id parsing (with
//  fallback) and repo/asset mapping. No filesystem or GPU.
//

import Foundation
import Testing
@testable import LocalLLM

struct LiteRTOpenModelTests {

    @Test("Model id maps to its model; unknown ids fall back to Llama 3.2 3B", arguments: [
        ("llama-3.2-3b", LiteRTOpenModel.llama32_3B),
        ("ministral-3b", .ministral3B),
        ("falcon3-3b", .falcon3_3B),
        ("totally-unknown", .llama32_3B),
        ("", .llama32_3B),
    ])
    func initFromModelID(id: String, expected: LiteRTOpenModel) {
        #expect(LiteRTOpenModel(modelID: id) == expected)
    }

    @Test func rawValueRoundTripsForModelStorage() {
        for model in LiteRTOpenModel.allCases {
            #expect(LiteRTOpenModel(rawValue: model.rawValue) == model)
        }
    }

    @Test func everyModelMapsToAnMlboydaisukeRepo() {
        for model in LiteRTOpenModel.allCases {
            #expect(model.huggingFaceRepo.hasPrefix("mlboydaisuke/"))
            #expect(model.huggingFaceRepo.hasSuffix("-LiteRT"))
        }
    }

    @Test func everyModelHasADisplayNameAndIcon() {
        for model in LiteRTOpenModel.allCases {
            #expect(!model.displayName.isEmpty)
            #expect(model.iconAsset != nil)
        }
    }

    @Test func catalogIsTheThreeOpenModels() {
        #expect(LiteRTOpenModel.allCases.count == 3)
    }
}
