//
//  VivaDictaIconWidget.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2026.01.24
//

import WidgetKit
import SwiftUI

struct IconWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> IconWidgetEntry {
        IconWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (IconWidgetEntry) -> Void) {
        completion(IconWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IconWidgetEntry>) -> Void) {
        let entry = IconWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct IconWidgetEntry: TimelineEntry {
    let date: Date
}

struct VivaDictaIconWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    var entry: IconWidgetProvider.Entry

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(white: 0.11)
            : Color(white: 0.95)
    }

    var body: some View {
        VStack(spacing: 0) {
            Image("VivaDictaIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
            Text("VivaDicta")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .offset(y: -5)
                .padding(.bottom, 4)
            Text("New recording")
                .foregroundStyle(.secondary)
        }
        
        .containerBackground(for: .widget) {
            backgroundColor
        }
        .widgetURL(URL(string: "startRecordFromWidget"))
    }
}

struct VivaDictaIconWidget: Widget {
    let kind: String = "VivaDictaIconWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IconWidgetProvider()) { entry in
            VivaDictaIconWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VivaDicta Icon")
        .description("Simple widget with app icon")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    VivaDictaIconWidget()
} timeline: {
    IconWidgetEntry(date: .now)
}
