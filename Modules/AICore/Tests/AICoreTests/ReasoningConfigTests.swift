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
        // 3.7 and 3.8 Flash reject "minimal" with a validation error - "low" is their floor.
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.7-flash") == "low")
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.8-flash") == "low")
        #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.5-flash-lite") == "minimal")
        // OpenAI GPT-5 series
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5.5") == "none")
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5-mini") == "minimal")
        // GPT-6 offers no "none" or "minimal" level, so "low" is its floor.
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-6-astra") == "low")
        // Cerebras / Groq
        #expect(ReasoningConfig.getReasoningParameter(for: "gpt-oss-120b") == "low")
        #expect(ReasoningConfig.getReasoningParameter(for: "openai/gpt-oss-120b") == "low")
        #expect(ReasoningConfig.getReasoningParameter(for: "qwen/qwen3-32b") == "none")
        // Unknown model -> no override
        #expect(ReasoningConfig.getReasoningParameter(for: "some-unknown-model") == nil)
    }

    @Test func reasoningFamilyUsesMaxCompletionTokens() {
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "gpt-5.6-terra"))
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "gpt-5-mini"))
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "gpt-6-astra"))
        // Gateways prefix the vendor; the OpenAI backend behind them is the same.
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "openai/gpt-5.6-terra"))
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "openai/gpt-6-astra"))
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "GPT-5.5"))
        // Everything else keeps the classic field.
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "gpt-4-mini") == false)
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "openai/gpt-oss-120b") == false)
        #expect(ReasoningConfig.usesMaxCompletionTokens(for: "claude-sonnet-5") == false)
    }

    /// The reasoning family steers effort with `reasoning_effort`; sending
    /// `temperature` alongside it is rejected, so it has to be omitted for
    /// GPT-6 exactly as it already is for GPT-5.
    @Test func reasoningFamilyOmitsTemperature() {
        #expect(ReasoningConfig.sendsTemperature(for: "gpt-6-astra") == false)
        #expect(ReasoningConfig.sendsTemperature(for: "gpt-5.6-terra") == false)
        #expect(ReasoningConfig.sendsTemperature(for: "openai/gpt-6-astra") == false)
        // Kimi's newer builds accept only temperature 1, so we omit it there too.
        #expect(ReasoningConfig.sendsTemperature(for: "kimi-k3") == false)
        // Everything else still gets the usual 0.3.
        #expect(ReasoningConfig.sendsTemperature(for: "gpt-4o"))
        #expect(ReasoningConfig.sendsTemperature(for: "claude-fable-5-1"))
        #expect(ReasoningConfig.sendsTemperature(for: "gemini-3.8-flash"))
    }

    @Test func extraBodyParametersForDisableReasoningModels() {
        let zai = ReasoningConfig.getExtraBodyParameters(for: "zai-glm-4.7")
        #expect(zai?["disable_reasoning"] as? Bool == true)
        #expect(ReasoningConfig.getExtraBodyParameters(for: "gpt-5.5") == nil)
    }
}
