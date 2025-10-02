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



extension VivaDictaLiveActivityAttributes {
    fileprivate static var preview: VivaDictaLiveActivityAttributes {
        VivaDictaLiveActivityAttributes(name: "World")
    }
}

extension VivaDictaLiveActivityAttributes.ContentState {
    fileprivate static var smiley: VivaDictaLiveActivityAttributes.ContentState {
        VivaDictaLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VivaDictaLiveActivityAttributes.ContentState {
         VivaDictaLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}
