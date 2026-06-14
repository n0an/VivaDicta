//
//  DeviceConditions.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.14
//

import Foundation

/// A point-in-time snapshot of device runtime conditions, attached to every
/// interactive analytics event.
///
/// Instruments only sees one device under one configuration; the user base runs
/// thousands of device / OS / thermal / power combinations. Tagging each event
/// with the thermal state, Low Power Mode flag, and app memory footprint turns
/// the analytics pipeline into a lightweight Xcode memory-and-thermal gauge
/// running across every user's device - so any event can later be sliced to find
/// "hot" screens, memory-heavy flows, or behaviour that only degrades in Low
/// Power Mode.
enum DeviceConditions {

    /// Snapshot of current conditions as snake_case analytics parameters.
    nonisolated static var parameters: [String: Any] {
        var params: [String: Any] = [
            "thermal_state": ProcessInfo.processInfo.thermalState.analyticsValue,
            "low_power_mode": ProcessInfo.processInfo.isLowPowerModeEnabled
        ]
        if let footprintMB = currentMemoryFootprintMB() {
            params["memory_mb"] = footprintMB
        }
        return params
    }

    /// The app's physical memory footprint in MB, read via `TASK_VM_INFO`.
    ///
    /// `phys_footprint` is the same figure Xcode's memory gauge reports and the
    /// value the system compares against the Jetsam limit, making it a more
    /// faithful "how close are we to being killed" signal than `resident_size`.
    /// Returns nil if the Mach call fails.
    nonisolated static func currentMemoryFootprintMB() -> Int? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Int(info.phys_footprint) / (1024 * 1024)
    }
}

extension ProcessInfo.ThermalState {
    /// Stable numeric encoding for analytics: `.nominal` = 0 ... `.critical` = 3.
    /// Kept stable so historical reporting doesn't break.
    nonisolated var analyticsValue: Int {
        switch self {
        case .nominal: 0
        case .fair: 1
        case .serious: 2
        case .critical: 3
        @unknown default: -1
        }
    }
}
