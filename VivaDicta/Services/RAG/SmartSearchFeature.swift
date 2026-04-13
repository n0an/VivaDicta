//
//  SmartSearchFeature.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation

enum SmartSearchFeature {
    static let isEnabledKey = "smartSearchFeatureEnabled"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: isEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: isEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isEnabledKey)
        }
    }
}
