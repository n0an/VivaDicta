// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
import Analytics
import AnalyticsMocks

/// Pins the `AnalyticsEvent` -> Firebase name/parameter mapping. These names are
/// a stable contract (changing one breaks historical reporting), so the module
/// owns the tests that guard them.
struct AnalyticsEventTests {

    @Test func transcriptionCompleted_mapsNameParametersAndAttachesDeviceConditions() {
        let sut: AnalyticsEvent = .transcriptionCompleted(
            engine: "whisperKit", isOnDevice: true, durationSeconds: 1.5, outputLength: 42
        )

        #expect(sut.name == "transcription_completed")
        #expect(sut.parameters?["engine"] as? String == "whisperKit")
        #expect(sut.parameters?["is_on_device"] as? Bool == true)
        #expect(sut.parameters?["output_length"] as? Int == 42)
        #expect(sut.attachesDeviceConditions == true)   // interactive event
    }

    @Test func chatConversationStarted_omitsNoteCountWhenNil() {
        let withCount: AnalyticsEvent = .chatConversationStarted(chatType: .multiNote, provider: "openai", model: "gpt", noteCount: 3)
        let withoutCount: AnalyticsEvent = .chatConversationStarted(chatType: .singleNote, provider: "openai", model: "gpt", noteCount: nil)

        #expect(withCount.parameters?["chat_type"] as? String == "multi_note")
        #expect(withCount.parameters?["note_count"] as? Int == 3)
        #expect(withoutCount.parameters?["note_count"] == nil)
    }

    @Test func metricKitEvents_doNotAttachDeviceConditions() {
        // MetricKit payloads are aggregated over the past day, so live device
        // state at delivery time is unrelated.
        #expect(AnalyticsEvent.appLaunchMetric(averageMs: 100, sampleCount: 3).attachesDeviceConditions == false)
        #expect(AnalyticsEvent.appLaunchMetric(averageMs: 100, sampleCount: 3).name == "app_launch_metric")
    }

    @Test func eventWithoutParameters_returnsNil() {
        #expect(AnalyticsEvent.onboardingCompleted.parameters == nil)
        #expect(AnalyticsEvent.onboardingCompleted.name == "onboarding_completed")
    }
}

/// `AnalyticsMocks` is exercised in-module so the recording double is verified
/// by the module that owns it, not only via the app's test target.
struct MockAnalyticsServiceTests {

    @Test func track_recordsEventsInOrder() {
        let sut = MockAnalyticsService()

        sut.track(.onboardingCompleted)
        sut.track(.liveTranslationOpened)

        #expect(sut.trackedEvents.count == 2)
        #expect(sut.trackedEventNames == ["onboarding_completed", "live_translation_opened"])
    }
}
