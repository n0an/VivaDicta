// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
import Analytics
import AnalyticsMocks

/// Pins the `AnalyticsEvent` name, so the identifier used in logs and test
/// assertions stays stable.
struct AnalyticsEventTests {

    @Test func unrecognizedHostApp_mapsName() {
        let sut: AnalyticsEvent = .unrecognizedHostApp(bundleId: "com.example.host")

        #expect(sut.name == "unrecognized_host_app")
    }
}

/// `AnalyticsMocks` is exercised in-module so the recording double is verified
/// by the module that owns it, not only via the app's test target.
struct MockAnalyticsServiceTests {

    @Test func track_recordsEventsInOrder() {
        let sut = MockAnalyticsService()

        sut.track(.unrecognizedHostApp(bundleId: "com.example.first"))
        sut.track(.unrecognizedHostApp(bundleId: "com.example.second"))

        #expect(sut.trackedEvents == [
            .unrecognizedHostApp(bundleId: "com.example.first"),
            .unrecognizedHostApp(bundleId: "com.example.second"),
        ])
        #expect(sut.trackedEventNames == ["unrecognized_host_app", "unrecognized_host_app"])
    }
}
