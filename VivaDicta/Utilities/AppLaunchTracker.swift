//
//  AppLaunchTracker.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.16
//

import Foundation

/// Utility for tracking app launch count and related launch-based features.
/// Use this for analytics, rate app prompts, feature gating by launch count, etc.
enum AppLaunchTracker {

    private static var defaults: UserDefaults {
        UserDefaultsStorage.appPrivate
    }

    /// The total number of times the app has been launched.
    static var launchCount: Int {
        defaults.integer(forKey: UserDefaultsStorage.Keys.appLaunchCount)
    }

    /// Call this once during app initialization to increment the launch count.
    static func recordLaunch() {
        let currentCount = launchCount
        defaults.set(currentCount + 1, forKey: UserDefaultsStorage.Keys.appLaunchCount)
    }

    /// Returns true if the current launch is within the first N launches (inclusive).
    /// - Parameter count: The number of launches to check against.
    /// - Returns: true if launchCount <= count
    static func isWithinFirstLaunches(_ count: Int) -> Bool {
        launchCount <= count
    }

    /// Returns true if this is the very first app launch.
    static var isFirstLaunch: Bool {
        launchCount == 1
    }
}
