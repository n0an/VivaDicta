//
//  VivaDictaLiveActivity.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VivaDictaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VivaDictaLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("VivaDicta")
                        .foregroundStyle(.black)
                    
                    Image(systemName: "microphone.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.indigo)
                    
                    Spacer()
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.yellow)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("VivaDicta")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "microphone.badge.plus.fill")
                        .foregroundStyle(.cyan)
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Image(systemName: "microphone.and.signal.meter")
                    .foregroundStyle(.purple)
            } minimal: {
                Image(systemName: "microphone.square.fill")
                    .foregroundStyle(.green)
            }
//            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}


#Preview("Notification", as: .content, using: VivaDictaLiveActivityAttributes.preview) {
   VivaDictaLiveActivity()
} contentStates: {
    VivaDictaLiveActivityAttributes.ContentState.smiley
    VivaDictaLiveActivityAttributes.ContentState.starEyes
}
