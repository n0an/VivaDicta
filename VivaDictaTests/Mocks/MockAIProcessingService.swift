// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AICore
import Presets
@testable import VivaDicta

/// Hand-rolled mock of ``AIProcessingService`` for `RecordViewModel` tests.
/// Stubs return values and counts invocations; no real `AIService` required.
@MainActor
final class MockAIProcessingService: AIProcessingService {

    // MARK: - Mode

    var modes: [VivaMode] = []
    var selectedMode: VivaMode = .defaultMode
    var selectedModeName: String = "Default"
    var stubGetMode: VivaMode?
    private(set) var reloadSelectedModeFromExtensionCallCount = 0

    func getMode(name: String) -> VivaMode { stubGetMode ?? selectedMode }
    func reloadSelectedModeFromExtension() { reloadSelectedModeFromExtensionCallCount += 1 }

    // MARK: - Configuration

    var stubIsProperlyConfigured = true
    func isProperlyConfigured(for modeOverride: VivaMode?, requirePreset: Bool) -> Bool {
        stubIsProperlyConfigured
    }

    // MARK: - Presets

    var presetManager: PresetManager?

    // MARK: - Clipboard

    private(set) var captureClipboardContextCallCount = 0
    private(set) var clearCapturedClipboardCallCount = 0
    func captureClipboardContext() { captureClipboardContextCallCount += 1 }
    func clearCapturedClipboard() { clearCapturedClipboardCallCount += 1 }

    // MARK: - Output

    var stubEnhanceResult: Result<(String, TimeInterval, String?), Error> = .success(("enhanced", 0, nil))
    private(set) var enhanceCallCount = 0
    func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        enhanceCallCount += 1
        return try stubEnhanceResult.get()
    }

    var stubGenerateVariationResult: Result<(String, TimeInterval), Error> = .success(("variation", 0))
    private(set) var generateVariationCallCount = 0
    private(set) var lastGenerateVariationText: String?
    private(set) var lastGenerateVariationPreset: Preset?
    func generateVariation(
        text: String,
        preset: Preset,
        modeOverride: VivaMode?,
        onPartialResult: (@MainActor (String) -> Void)?
    ) async throws -> (String, TimeInterval) {
        generateVariationCallCount += 1
        lastGenerateVariationText = text
        lastGenerateVariationPreset = preset
        return try stubGenerateVariationResult.get()
    }

    // MARK: - Last-message introspection

    var lastSystemMessageSent: String?
    var lastUserMessageSent: String?
}
