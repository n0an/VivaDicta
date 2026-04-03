//
//  VivaDictaWidget.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

// TODO: NOT USED AT THE MOMENT. CAN DELETE, OR USE - DECIDE LATER

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()

        // Create entries for the next 24 hours, one per hour
        for hourOffset in 0..<24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        // Reload timeline after 24 hours
        let reloadDate = Calendar.current.date(byAdding: .hour, value: 24, to: currentDate)!
        return Timeline(entries: entries, policy: .after(reloadDate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent

    /// Time parameter for mesh gradient animation, derived from date
    var t: Float {
        // Use hours and minutes to create a slowly changing value
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = Float(components.hour ?? 0)
        let minutes = Float(components.minute ?? 0)
        return (hours * 60 + minutes) / 10.0 // Completes a cycle roughly every 10 hours
    }
}

struct VivaDictaWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    
    var entry: Provider.Entry

    var body: some View {
        
        switch family {
        case .systemSmall:
            WidgetViewSmall(entry: entry)
                .widgetURL(URL(string: "startRecordFromWidget"))
        case .accessoryCircular:
            LockScreenCircularView()
                .widgetURL(URL(string: "startRecordFromWidget"))
        case .accessoryRectangular:
            LockScreenRectangularView()
                .widgetURL(URL(string: "startRecordFromWidget"))
        case .accessoryInline:
            Label("Record Note", systemImage: "microphone.circle.fill")
                .widgetURL(URL(string: "startRecordFromWidget"))
        case .systemMedium, .systemLarge, .systemExtraLarge:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

private struct WidgetViewSmall: View {
    var entry: SimpleEntry

    private var t: Float { entry.t }

    private var meshColors: [Color] {
        entry.configuration.widgetColor.meshGradientColors
    }

    private var meshPoints: [SIMD2<Float>] {
        [
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
        ]
    }

    var body: some View {
        VStack {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(entry.configuration.widgetColor == .gradient1 ? .orange : .white.opacity(0.9))
                .font(.system(size: 88))
                .shadow(color: .black.opacity(entry.configuration.widgetColor == .gradient1 ? 0.7 : 0.5), radius: entry.configuration.widgetColor == .gradient2 ? 4 : 6, x: 0, y: 4)
        }
        .containerBackground(for: .widget) {
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints,
                colors: meshColors
            )
        }
    }

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

struct VivaDictaWidget: Widget {
    let kind: String = "VivaDictaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VivaDictaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VivaDicta")
        .description("Record Note in VivaDicta")
        .supportedFamilies([.systemSmall,
                            .accessoryRectangular,
                            .accessoryCircular,
                            .accessoryInline])
    }
}

extension ConfigurationAppIntent {
    fileprivate static var gradient1: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.widgetColorString = WidgetColor.gradient1.rawValue
        return intent
    }
    
    fileprivate static var gradient2: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.widgetColorString = WidgetColor.gradient2.rawValue
        return intent
    }
    
    fileprivate static var red: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.widgetColorString = WidgetColor.red.rawValue
        return intent
    }
    
    fileprivate static var blue: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.widgetColorString = WidgetColor.blue.rawValue
        return intent
    }
    
    fileprivate static var green: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.widgetColorString = WidgetColor.green.rawValue
        return intent
    }
}

#Preview("gradient1", as: .systemSmall) {
    VivaDictaWidget()
} timeline: {
    SimpleEntry(date: Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 3, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!, configuration: .gradient1)
}

#Preview("gradient2", as: .systemSmall) {
    VivaDictaWidget()
} timeline: {
    SimpleEntry(date: Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 3, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
    SimpleEntry(date: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!, configuration: .gradient2)
}
