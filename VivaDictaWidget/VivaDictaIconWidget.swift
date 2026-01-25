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
        var entries: [IconWidgetEntry] = []
        let currentDate = Date()

        // Create entries every 15 minutes for the next 24 hours
        for quarterOffset in 0..<96 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: quarterOffset * 15, to: currentDate)!
            entries.append(IconWidgetEntry(date: entryDate))
        }

        let reloadDate = Calendar.current.date(byAdding: .hour, value: 24, to: currentDate)!
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
}

struct IconWidgetEntry: TimelineEntry {
    let date: Date

    /// Time parameter for mesh gradient animation, derived from date
    var t: Float {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = Float(components.hour ?? 0)
        let minutes = Float(components.minute ?? 0)
        return (hours * 60 + minutes) / 5.0
    }
}

struct VivaDictaIconWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    var entry: IconWidgetProvider.Entry

    private var t: Float { entry.t }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(white: 0.11)
            : Color(white: 0.95)
    }

    var body: some View {
        VStack(spacing: 0) {
            Image("VivaDictaIconFrameless")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .padding(.bottom, 8)
            Text("VivaDicta")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(meshGradient)
                .padding(.bottom, 12)
            Text("Record Note")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            backgroundColor
        }
        .widgetURL(URL(string: "startRecordFromWidget"))
    }

    private var meshGradient: MeshGradient {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t),
             sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t),
             sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t),
             sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
            [sinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t),
             sinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t),
             sinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t),
             sinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
        ], colors: [
            .blue, .purple, .indigo,
            .cyan, .pink, .blue,
            .purple, .indigo, .cyan
        ])
    }

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

struct VivaDictaIconWidget: Widget {
    let kind: String = "VivaDictaIconWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IconWidgetProvider()) { entry in
            VivaDictaIconWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VivaDicta")
        .description("Quickly create a new recording from your home screen")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    VivaDictaIconWidget()
} timeline: {
    IconWidgetEntry(date: Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: .now)!)
    IconWidgetEntry(date: Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: .now)!)
    IconWidgetEntry(date: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!)
    IconWidgetEntry(date: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now)!)
}
