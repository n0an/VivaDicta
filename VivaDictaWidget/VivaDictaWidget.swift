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
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(entry.configuration.widgetColor.gradient)
                .font(.system(size: 80))
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(entry.configuration.widgetColor.gradient.opacity(0.9))
                .colorInvert()
                .saturation(0.2)
        }
        
    }
}

struct VivaDictaWidget: Widget {
    let kind: String = "VivaDictaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VivaDictaWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall])
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
}

#Preview(as: .systemSmall) {
    VivaDictaWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .def)
    SimpleEntry(date: .now, configuration: .red)
}
