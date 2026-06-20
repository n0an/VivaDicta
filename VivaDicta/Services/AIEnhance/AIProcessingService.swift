// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AICore
import Presets

/// The mode-driven AI text-processing surface of ``AIService`` consumed by
/// ``RecordViewModel`` (mode selection, configuration check, clipboard context,
/// preset access, and producing output - both single `enhance` and multi
/// `generateVariation`).
///
/// Carved out so `RecordViewModel` can be unit-tested against a hand-rolled mock
/// without spinning up a real ``AIService``. Mirrors only the members that view
/// model actually touches. Named "Processing" (the app's domain term) rather
/// than "Enhance" - `enhance` is pre-AI-variations vocabulary; processing now
/// yields multiple variations.
@MainActor
protocol AIProcessingService: AnyObject {
    // Mode access
    var modes: [VivaMode] { get }
    var selectedMode: VivaMode { get set }
    var selectedModeName: String { get set }
    func getMode(name: String) -> VivaMode
    func reloadSelectedModeFromExtension()

    // Configuration
    func isProperlyConfigured(for modeOverride: VivaMode?, requirePreset: Bool) -> Bool

    // Presets
    var presetManager: PresetManager? { get }

    // Clipboard context
    func captureClipboardContext()
    func clearCapturedClipboard()

    // Output
    func enhance(_ text: String) async throws -> (String, TimeInterval, String?)
    func generateVariation(
        text: String,
        preset: Preset,
        modeOverride: VivaMode?,
        onPartialResult: (@MainActor (String) -> Void)?
    ) async throws -> (String, TimeInterval)

    // Last-message introspection
    var lastSystemMessageSent: String? { get }
    var lastUserMessageSent: String? { get }
}

/// Convenience overloads matching how callers invoke the default-argument
/// methods - default arguments are not visible through the protocol existential.
extension AIProcessingService {
    func isProperlyConfigured() -> Bool {
        isProperlyConfigured(for: nil, requirePreset: true)
    }

    func generateVariation(text: String, preset: Preset) async throws -> (String, TimeInterval) {
        try await generateVariation(text: text, preset: preset, modeOverride: nil, onPartialResult: nil)
    }
}

extension AIService: AIProcessingService {}
