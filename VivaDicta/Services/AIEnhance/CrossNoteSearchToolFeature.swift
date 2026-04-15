//
//  CrossNoteSearchToolFeature.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation

enum CrossNoteSearchToolFeature {
    static let isEnabledKey = UserDefaultsStorage.Keys.isImplicitCrossNoteSearchEnabled

    static var isEnabled: Bool {
        UserDefaultsStorage.appPrivate.bool(forKey: isEnabledKey)
    }
}
