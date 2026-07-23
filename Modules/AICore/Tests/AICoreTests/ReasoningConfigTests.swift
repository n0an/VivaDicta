import Testing
import Foundation
@testable import AICore

/// Characterization tests locking the model -> reasoning-parameter mappings as
/// ReasoningConfig moves into AICore.
struct ReasoningConfigTests {

    @Test func reasoningParameterMappings() {
        // Gemini
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-flash") == "none")
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-pro") == "minimal")
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.6-flash") == "minimal")
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.5-flash-lite") == "minimal")
        // OpenAI GPT-5 series
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5.5") == "none")
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5-mini") == "minimal")
        // Cerebras / Groq
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-oss-120b") == "low")
        #expect(ReasoningConfig.getReasoningParameter(for: "openai/gpt-oss-120b") == "low")
        #expect(ReasoningConfig.getReasoningParameter(for: "qwen/qwen3-32b") == "none")
        // Unknown model -> no override
        #expect(ReasoningConfig.getReasoningParameter(for: "some-unknown-model") == nil)
    }

    @Test func extraBodyParametersForDisableReasoningModels() {
        let zai = ReasoningConfig.getExtraBodyParameters(for: "zai-glm-4.7")
        #expect(zai?["disable_reasoning"] as? Bool == true)
        #expect(ReasoningConfig.getExtraBodyParameters(for: "gpt-5.5") == nil)
    }
}
