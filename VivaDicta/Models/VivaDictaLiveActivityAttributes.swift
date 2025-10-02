//
//  VivaDictaLiveActivityAttributes.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.02
//

import Foundation
import ActivityKit

struct VivaDictaLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}
