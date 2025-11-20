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
                    HStack(spacing: 20) {
                        Image(systemName: "microphone.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.leading, 24)
                        
                        Text("VivaDicta")
                            .foregroundColor(.primary)
                            .font(.system(size: 20, weight: .semibold))
                        
                        Spacer()
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
                    
                    Toggle(isOn: .constant(true)) {
                        Text("test")
                    }
                    .padding(.trailing, 12)
                    
//                    Toggle("", isOn: .constant(true))
//                        .padding(.trailing, 12)
                    
                    
                    //                    Image(systemName: "microphone.circle.fill")
                    //                        .font(.system(size: 30, weight: .semibold))
                    //                        .foregroundColor(.orange)
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
