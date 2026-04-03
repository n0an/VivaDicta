//
//  VivaDictaWatchWidget.swift
//  VivaDictaWatchWidget
//
//  Created by Anton Novoselov on 2026.04.02
//

import WidgetKit
import SwiftUI

struct RecordEntry: TimelineEntry {
    let date: Date
}

struct RecordTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecordEntry {
        RecordEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecordEntry) -> Void) {
        completion(RecordEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecordEntry>) -> Void) {
        let entry = RecordEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct VivaDictaWatchWidgetEntryView: View {
    var entry: RecordEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    @ViewBuilder
    private var circularView: some View {
        if isFullColor {
            Image("WatchComplicationIcon")
                .resizable()
                .scaledToFit()
        } else {
            LockScreenIconCircularViewTinted()
        }
    }
    
    
    struct LockScreenIconCircularViewTinted: View {
        var body: some View {
            VStack {
                Image("VivaDictaIcon50")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .luminanceToAlpha()
            .background {
                LinearGradient(colors: [.white.opacity(0.4), .clear],
                                     startPoint: UnitPoint(x: 0.5, y: 1.5), endPoint: .top)
            }
            .widgetAccentable()
            .containerBackground(for: .widget) { }
        }
    }
    
    

    private var cornerView: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(.orange)
            .widgetLabel {
                Text("Record")
            }
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text("VivaDicta")
                    .font(.headline)
                Text("Tap to record")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        Label("VivaDicta", systemImage: "mic.fill")
    }
}

struct VivaDictaWatchWidget: Widget {
    let kind: String = "VivaDictaWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecordTimelineProvider()) { entry in
            VivaDictaWatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "vivadicta-watch://record"))
        }
        .configurationDisplayName("Quick Record")
        .description("VivaDicta Quick Record")
        .supportedFamilies([.accessoryCircular,
                            .accessoryCorner,
                            .accessoryRectangular,
                            .accessoryInline])
    }
}

#Preview(as: .accessoryCircular) {
    VivaDictaWatchWidget()
} timeline: {
    RecordEntry(date: .now)
}
