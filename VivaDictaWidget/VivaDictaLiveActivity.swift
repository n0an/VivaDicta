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
                        
                        Text("VivaDicta")
                            .foregroundColor(.primary)
                            .font(.system(size: 20, weight: .semibold))
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
                        Text(context.state.state.statusText)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16, weight: .regular))
                    }
                    .padding(.leading, 12)
                    
                    Spacer()
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Spacer()
                    
                    // Note: symbolEffect() is not supported in Live Activities
                    Group {
                        if context.state.state == .idle {
                            Button(intent: ToggleSessionIntent(isSessionActive: false)) {
                                Image(systemName: context.state.state.iconName)
                                    .font(.system(size: 40))
                                    .foregroundColor(context.state.state.iconColor == "orange" ? .orange : .blue)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: context.state.state.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(context.state.state.iconColor == "orange" ? .orange : .blue)
                        }
                    }
                    .padding(.trailing, 12)
                    
                    Spacer()
                }
                
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Image(systemName: context.state.state.iconName)
                    .foregroundColor(context.state.state.iconColor == "orange" ? .orange : .blue)
            } minimal: {
                Image(systemName: context.state.state.iconName)
                    .foregroundColor(context.state.state.iconColor == "orange" ? .orange : .blue)
            }
        }
    }
}


#Preview("Notification", as: .content, using: VivaDictaLiveActivityAttributes.preview) {
   VivaDictaLiveActivity()
} contentStates: {
    VivaDictaLiveActivityAttributes.ContentState.idle
    VivaDictaLiveActivityAttributes.ContentState.recording
    VivaDictaLiveActivityAttributes.ContentState.transcribing
    VivaDictaLiveActivityAttributes.ContentState.enhancing
}
