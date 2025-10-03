//
//  UserDefaultsStorage.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

/// A wrapper for UserDefaults that explicitly declares storage intent
/// This is the keyboard extension version - it only uses shared storage
enum UserDefaultsStorage {
    /// For data that is shared between app and extensions
    /// All keyboard extension data must be in the shared container
    static var shared: UserDefaults {
        UserDefaults(suiteName: AppGroupConfig.appGroupId)!
    }

    // Note: Keyboard extensions cannot use UserDefaults.standard
    // All data must be in the shared app group
}