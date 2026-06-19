//
//  AnalyticsService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.27
//

import Foundation
import Presets

/// Strongly-typed catalog of every analytics event the app reports.
///
/// Adding a new event:
/// 1. Add a case here with the parameters you want to attach.
/// 2. Map it in `name` and `parameters`.
/// 3. Track it via the injected `analytics` (or `DefaultAnalyticsService.live`):
///    `analytics.track(.yourEvent(...))`.
enum AnalyticsEvent {

    enum ChatType: String {
        case singleNote = "single_note"
        case multiNote = "multi_note"
        case allNotes = "all_notes"
        case smartSearch = "smart_search"
    }

    case onboardingCompleted
    case unrecognizedHostApp(bundleId: String)
    case keyboardSessionStarted(hostBundleId: String?)
    case modelDownloaded(name: String, type: String)

    case chatConversationStarted(
        chatType: ChatType,
        provider: String,
        model: String,
        noteCount: Int?
    )
    case chatMessageSent(
        chatType: ChatType,
        provider: String,
        model: String,
        turnCount: Int
    )

    case smartSearchQueryExecuted(queryLength: Int, topK: Int, resultCount: Int)
    case ragIndexingCompleted(
        indexedCount: Int,
        skippedCount: Int,
        totalChunks: Int,
        isFirstRun: Bool
    )

    case watchRecordingReceived(durationSeconds: Double?, hasModeId: Bool)

    case transcriptionCompleted(
        engine: String,
        isOnDevice: Bool,
        durationSeconds: Double,
        outputLength: Int
    )
    case variationGenerated(
        presetId: String,
        isBuiltInPreset: Bool,
        provider: String,
        model: String,
        durationSeconds: Double,
        outputLength: Int
    )

    // MARK: - Live Translation

    /// Fires when the Live Translation screen appears, regardless of whether
    /// a Soniox API key is configured. Captures discovery / globe-icon taps.
    case liveTranslationOpened

    /// Fires when a session successfully transitions to .running (after mic
    /// permission + WS connect). Counts real engagement, not intent.
    case liveTranslationStarted(
        sourceLanguage: String,
        targetLanguage: String,
        ttsEnabled: Bool,
        voice: String
    )

    /// Fires when the user stops a running session (or it ends naturally).
    /// Skipped when a session never reached .running.
    case liveTranslationStopped(
        durationSeconds: Double,
        originalTokenCount: Int,
        translatedTokenCount: Int,
        ttsEnabled: Bool
    )

    /// Fires when the user taps "Save as note" after a session.
    case liveTranslationSavedAsNote

    /// Fires when a session fails (missing key, mic denied, WS error, etc.).
    /// `reason` is a stable category identifier, not the localized message.
    case liveTranslationFailed(reason: String)

    // MARK: - Performance Monitoring (MetricKit, passive)

    /// Daily MetricKit launch-time report: bucket-weighted average time to first
    /// draw, with the number of launches the average is drawn from.
    case appLaunchMetric(averageMs: Double, sampleCount: Int)

    /// Daily MetricKit responsiveness report: bucket-weighted average hang time
    /// across the reporting window.
    case appHangMetric(averageMs: Double, sampleCount: Int)

    /// Daily MetricKit memory report: peak footprint and average suspended
    /// memory (both in MB).
    case appMemoryMetric(peakMB: Int, averageSuspendedMB: Int)

    /// A single MetricKit hang diagnostic - the app was unresponsive on the main
    /// thread for `hangSeconds`.
    case appHangDiagnostic(hangSeconds: Double)

    /// A single MetricKit CPU-exception diagnostic - the app burned an unusual
    /// amount of CPU over the sampling window.
    case appCPUExceptionDiagnostic(cpuSeconds: Double, sampledSeconds: Double)
}

extension AnalyticsEvent {

    /// The Firebase event name. Keep names stable - changing one breaks
    /// historical reporting in the Firebase console.
    nonisolated var name: String {
        switch self {
        case .onboardingCompleted: "onboarding_completed"
        case .unrecognizedHostApp: "unrecognized_host_app"
        case .keyboardSessionStarted: "keyboard_session_started"
        case .modelDownloaded: "model_downloaded"
        case .chatConversationStarted: "chat_conversation_started"
        case .chatMessageSent: "chat_message_sent"
        case .smartSearchQueryExecuted: "smart_search_query_executed"
        case .ragIndexingCompleted: "rag_indexing_completed"
        case .watchRecordingReceived: "watch_recording_received"
        case .transcriptionCompleted: "transcription_completed"
        case .variationGenerated: "variation_generated"
        case .liveTranslationOpened: "live_translation_opened"
        case .liveTranslationStarted: "live_translation_started"
        case .liveTranslationStopped: "live_translation_stopped"
        case .liveTranslationSavedAsNote: "live_translation_saved_as_note"
        case .liveTranslationFailed: "live_translation_failed"
        case .appLaunchMetric: "app_launch_metric"
        case .appHangMetric: "app_hang_metric"
        case .appMemoryMetric: "app_memory_metric"
        case .appHangDiagnostic: "app_hang_diagnostic"
        case .appCPUExceptionDiagnostic: "app_cpu_exception_diagnostic"
        }
    }

    /// Whether ``DeviceConditions`` (thermal state, Low Power Mode, memory) are
    /// merged into this event. True for interactive events, where the live
    /// device state is meaningful. False for the MetricKit-sourced events, whose
    /// payloads are aggregated over the past day - the device state at delivery
    /// time is unrelated to when the metrics were recorded.
    nonisolated var attachesDeviceConditions: Bool {
        switch self {
        case .appLaunchMetric, .appHangMetric, .appMemoryMetric,
             .appHangDiagnostic, .appCPUExceptionDiagnostic:
            false
        default:
            true
        }
    }

    /// Parameters attached to the event. Keep keys snake_case and consistent
    /// across events (`provider`, `model`, `chat_type`, ...). Do not include
    /// raw user content - only counts, lengths, enum values, and IDs.
    nonisolated var parameters: [String: Any]? {
        switch self {
        case .onboardingCompleted:
            return nil

        case .unrecognizedHostApp(let bundleId):
            return ["bundle_id": bundleId]

        case .keyboardSessionStarted(let hostBundleId):
            return ["host_bundle_id": hostBundleId ?? "unknown"]

        case .modelDownloaded(let name, let type):
            return ["model_name": name, "model_type": type]

        case .chatConversationStarted(let chatType, let provider, let model, let noteCount):
            var params: [String: Any] = [
                "chat_type": chatType.rawValue,
                "provider": provider,
                "model": model
            ]
            if let noteCount { params["note_count"] = noteCount }
            return params

        case .chatMessageSent(let chatType, let provider, let model, let turnCount):
            return [
                "chat_type": chatType.rawValue,
                "provider": provider,
                "model": model,
                "turn_count": turnCount
            ]

        case .smartSearchQueryExecuted(let queryLength, let topK, let resultCount):
            return [
                "query_length": queryLength,
                "top_k": topK,
                "result_count": resultCount
            ]

        case .ragIndexingCompleted(let indexedCount, let skippedCount, let totalChunks, let isFirstRun):
            return [
                "indexed_count": indexedCount,
                "skipped_count": skippedCount,
                "total_chunks": totalChunks,
                "is_first_run": isFirstRun
            ]

        case .watchRecordingReceived(let durationSeconds, let hasModeId):
            var params: [String: Any] = ["has_mode_id": hasModeId]
            if let durationSeconds {
                params["duration_seconds"] = durationSeconds
            }
            return params

        case .transcriptionCompleted(let engine, let isOnDevice, let durationSeconds, let outputLength):
            return [
                "engine": engine,
                "is_on_device": isOnDevice,
                "duration_seconds": durationSeconds,
                "output_length": outputLength
            ]

        case .variationGenerated(let presetId, let isBuiltInPreset, let provider, let model, let durationSeconds, let outputLength):
            return [
                "preset_id": presetId,
                "is_built_in_preset": isBuiltInPreset,
                "provider": provider,
                "model": model,
                "duration_seconds": durationSeconds,
                "output_length": outputLength
            ]

        case .liveTranslationOpened:
            return nil

        case .liveTranslationStarted(let sourceLanguage, let targetLanguage, let ttsEnabled, let voice):
            return [
                "source_language": sourceLanguage,
                "target_language": targetLanguage,
                "tts_enabled": ttsEnabled,
                "voice": voice
            ]

        case .liveTranslationStopped(let durationSeconds, let originalTokenCount, let translatedTokenCount, let ttsEnabled):
            return [
                "duration_seconds": durationSeconds,
                "original_token_count": originalTokenCount,
                "translated_token_count": translatedTokenCount,
                "tts_enabled": ttsEnabled
            ]

        case .liveTranslationSavedAsNote:
            return nil

        case .liveTranslationFailed(let reason):
            return ["reason": reason]

        case .appLaunchMetric(let averageMs, let sampleCount):
            return ["average_ms": averageMs, "sample_count": sampleCount]

        case .appHangMetric(let averageMs, let sampleCount):
            return ["average_ms": averageMs, "sample_count": sampleCount]

        case .appMemoryMetric(let peakMB, let averageSuspendedMB):
            return ["peak_mb": peakMB, "average_suspended_mb": averageSuspendedMB]

        case .appHangDiagnostic(let hangSeconds):
            return ["hang_seconds": hangSeconds]

        case .appCPUExceptionDiagnostic(let cpuSeconds, let sampledSeconds):
            return ["cpu_seconds": cpuSeconds, "sampled_seconds": sampledSeconds]
        }
    }
}

/// Reports analytics events through one typed chokepoint, so call sites can't
/// typo event names or drift in parameter keys. `track` is safe to call from any
/// context.
///
/// Production wires `DefaultAnalyticsService` (Firebase); tests wire
/// `MockAnalyticsService` to assert which events fired.
protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}
