//
//  VivaDictaLiveActivity.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct VivaDictaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VivaDictaLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VivaDicta")
                                .foregroundColor(.primary)
                                .font(.system(size: 20, weight: .semibold))
                            Text("On")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 16, weight: .regular))
                        }
                        .padding(.leading, 24)
                        
                        Spacer()
                        
                        Button(intent: ToggleSessionIntent(isSessionActive: false)) {
                            Image(systemName: "power.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 24)
                    }
                    
                    Spacer()
                }
                .activityBackgroundTint(.clear)
                
            

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VivaDicta")
                            .foregroundColor(.primary)
                            .font(.system(size: 20, weight: .semibold))
                        Text("On")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16, weight: .regular))
                    }
                    .padding(.leading, 12)
                    
                    Spacer()
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Spacer()
                    
                    Button(intent: ToggleSessionIntent(isSessionActive: false)) {
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                    
                    Spacer()
                }
                
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Image(systemName: "microphone.circle.fill")
                    .foregroundColor(.orange)
            } minimal: {
                Image(systemName: "microphone.circle.fill")
                    .foregroundColor(.orange)
            }
            //            .keylineTint(Color.red)
        }
    }
}


#Preview("Notification", as: .content, using: VivaDictaLiveActivityAttributes.preview) {
   VivaDictaLiveActivity()
} contentStates: {
    VivaDictaLiveActivityAttributes.ContentState.smiley
    VivaDictaLiveActivityAttributes.ContentState.starEyes
}
