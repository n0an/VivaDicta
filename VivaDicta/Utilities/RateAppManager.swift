//
//  RateAppManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.16
//

import Foundation
import StoreKit

/// Manager for handling app rating requests.
/// Requests are throttled based on launch count, days since install, and time since last request.
@MainActor
enum RateAppManager {

    // MARK: - Configuration

    /// Minimum number of app launches before requesting a rating.
    private static let minimumLaunchCount = 5

    /// Minimum number of days since first launch before requesting a rating.
    private static let minimumDaysSinceInstall = 3

    /// Minimum number of days between rating requests.
    private static let minimumDaysBetweenRequests = 90

    // MARK: - Private

    private static var defaults: UserDefaults {
        UserDefaultsStorage.appPrivate
    }

    /// The date when we last requested a rating from the user.
    private static var lastRatingRequestDate: Date? {
        get { defaults.object(forKey: UserDefaultsStorage.Keys.lastRatingRequestDate) as? Date }
        set { defaults.set(newValue, forKey: UserDefaultsStorage.Keys.lastRatingRequestDate) }
    }

    /// Number of days since the last rating request.
    private static var daysSinceLastRequest: Int? {
        guard let lastRequest = lastRatingRequestDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: lastRequest, to: Date())
        return components.day
    }

    // MARK: - Public

    /// Checks if conditions are met and requests an app rating if appropriate.
    /// Call this after successful user actions (transcription, enhancement, etc.).
    static func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }

        // Record the request date before showing
        lastRatingRequestDate = Date()

        // Request review using StoreKit
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    /// Returns true if all conditions are met for requesting a review.
    static func shouldRequestReview() -> Bool {
        // Check minimum launch count
        guard AppLaunchTracker.launchCount >= minimumLaunchCount else {
            return false
        }

        // Check minimum days since install
        guard AppLaunchTracker.daysSinceFirstLaunch >= minimumDaysSinceInstall else {
            return false
        }

        // Check if enough time has passed since last request
        if let daysSinceLast = daysSinceLastRequest {
            guard daysSinceLast >= minimumDaysBetweenRequests else {
                return false
            }
        }

        return true
    }
}
