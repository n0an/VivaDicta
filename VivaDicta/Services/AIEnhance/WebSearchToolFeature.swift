//
//  WebSearchToolFeature.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation

enum WebSearchToolFeature {
    static let isEnabledKey = UserDefaultsStorage.Keys.isImplicitWebSearchEnabled

    static var isEnabled: Bool {
        UserDefaultsStorage.appPrivate.bool(forKey: isEnabledKey)
    }
}
