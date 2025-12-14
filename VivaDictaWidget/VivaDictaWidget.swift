//
//  VivaDictaWidget.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

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
        let entry = SimpleEntry(date: .now, configuration: configuration)
        
        return Timeline(entries: [entry], policy: .never)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
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
            Label("Start record", systemImage: "microphone.circle.fill")
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

    private var meshColors: [Color] {
        let base = entry.configuration.widgetColor
        return base.meshGradientColors
    }

    var body: some View {
        VStack {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(1).gradient)
                .font(.system(size: 88))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .containerBackground(for: .widget) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: meshColors
            )
        }
    }
}

private struct LockScreenCircularView: View {
    var body: some View {
        
        VStack {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange.gradient)
                .font(.system(size: 40))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            ContainerRelativeShape()
                .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                     startPoint: .bottom, endPoint: .top))
        }
        .containerBackground(for: .widget) { }
    }
}

private struct LockScreenRectangularView: View {
    var body: some View {
        
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "mic.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange.gradient)
                    .font(.system(size: 40))
                
                Text("VivaDicta")
            }
        }
        
        .containerBackground(for: .widget) { }
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
    fileprivate static var def: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.widgetColorString = WidgetColor.def.rawValue
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

#Preview(as: .accessoryCircular) {
    VivaDictaWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .def)
    SimpleEntry(date: .now, configuration: .red)
    SimpleEntry(date: .now, configuration: .blue)
    SimpleEntry(date: .now, configuration: .green)
}
