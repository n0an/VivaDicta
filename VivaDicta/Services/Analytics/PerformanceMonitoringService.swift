//
//  PerformanceMonitoringService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.14
//

import Foundation
import Analytics
import MetricKit
import os

/// Subscribes to MetricKit so the app receives passive, aggregated production
/// performance reports from the entire user base - data Instruments cannot
/// provide because it only profiles one connected device at a time.
///
/// MetricKit delivers `MXMetricPayload`s roughly once per day (launch time,
/// hang time, memory) and `MXDiagnosticPayload`s when incidents occur (long
/// hangs, CPU exceptions). Reports only arrive on real devices in real usage,
/// never the simulator - use Xcode's *Debug ▸ Simulate MetricKit Payloads* to
/// exercise the callbacks locally.
///
/// `MXMetricManager` does not retain its subscribers, so this service is a
/// process-lifetime singleton. It holds no mutable state, hence `@unchecked
/// Sendable`.
final class PerformanceMonitoringService: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    static let shared = PerformanceMonitoringService()

    private let logger = Logger(category: .analytics)

    /// Guards against double registration, which would make MetricKit deliver
    /// every payload twice and double all reported counts. Only ever touched
    /// from `start()`, which is called on the main thread at launch.
    private var isStarted = false

    private override init() { super.init() }

    /// Registers as a MetricKit subscriber. Idempotent; call once at launch.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
        logger.logInfo("📈 MetricKit subscriber registered")
    }

    // MARK: - MXMetricManagerSubscriber

    // `nonisolated` is load-bearing: with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
    // these would be implicitly `@MainActor`, and the `@objc` thunk for an
    // `@MainActor` method runs a runtime executor precondition on entry. MetricKit
    // calls subscribers synchronously on its own background queue, so on iOS 26
    // (trapping variant) that precondition crashes before the body runs. The bodies
    // only read the payload and call the `nonisolated` `DefaultAnalyticsService.live.track`,
    // so running off the main actor is safe. The helpers below are `nonisolated` for
    // the same reason (they're reached only from here).

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            reportLaunchTime(payload)
            reportHangTime(payload)
            reportMemory(payload)
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for hang in payload.hangDiagnostics ?? [] {
                let seconds = hang.hangDuration.converted(to: .seconds).value
                DefaultAnalyticsService.live.track(.appHangDiagnostic(hangSeconds: seconds))
            }
            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                DefaultAnalyticsService.live.track(.appCPUExceptionDiagnostic(
                    cpuSeconds: cpu.totalCPUTime.converted(to: .seconds).value,
                    sampledSeconds: cpu.totalSampledTime.converted(to: .seconds).value
                ))
            }
        }
    }

    // MARK: - Metric extraction

    nonisolated private func reportLaunchTime(_ payload: MXMetricPayload) {
        guard let launch = payload.applicationLaunchMetrics,
              let stats = weightedAverageMs(launch.histogrammedTimeToFirstDraw) else { return }
        DefaultAnalyticsService.live.track(.appLaunchMetric(averageMs: stats.averageMs, sampleCount: stats.count))
    }

    nonisolated private func reportHangTime(_ payload: MXMetricPayload) {
        guard let responsiveness = payload.applicationResponsivenessMetrics,
              let stats = weightedAverageMs(responsiveness.histogrammedApplicationHangTime) else { return }
        DefaultAnalyticsService.live.track(.appHangMetric(averageMs: stats.averageMs, sampleCount: stats.count))
    }

    nonisolated private func reportMemory(_ payload: MXMetricPayload) {
        guard let memory = payload.memoryMetrics else { return }
        // Report MiB (bytes / 1024²), not Measurement's decimal `.megabytes`
        // (1e6 bytes), so these line up with DeviceConditions.currentMemoryFootprintMB
        // and the Jetsam limit, both of which are MiB-based.
        let peakMB = Int(memory.peakMemoryUsage.converted(to: .bytes).value) / (1024 * 1024)
        let suspendedMB = Int(memory.averageSuspendedMemory.averageMeasurement.converted(to: .bytes).value) / (1024 * 1024)
        DefaultAnalyticsService.live.track(.appMemoryMetric(peakMB: peakMB, averageSuspendedMB: suspendedMB))
    }

    /// Collapses a duration histogram into a single bucket-weighted average (in
    /// milliseconds) plus the total sample count. MetricKit reports distributions
    /// rather than scalars, so we approximate each bucket by its midpoint.
    nonisolated private func weightedAverageMs(_ histogram: MXHistogram<UnitDuration>) -> (averageMs: Double, count: Int)? {
        let enumerator = histogram.bucketEnumerator
        var totalCount = 0
        var weightedSum = 0.0
        while let bucket = enumerator.nextObject() as? MXHistogramBucket<UnitDuration> {
            let start = bucket.bucketStart.converted(to: .milliseconds).value
            let end = bucket.bucketEnd.converted(to: .milliseconds).value
            let midpoint = (start + end) / 2
            weightedSum += midpoint * Double(bucket.bucketCount)
            totalCount += bucket.bucketCount
        }
        guard totalCount > 0 else { return nil }
        return (weightedSum / Double(totalCount), totalCount)
    }
}
