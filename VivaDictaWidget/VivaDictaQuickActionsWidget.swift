//
//  VivaDictaQuickActionsWidget.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2026.04.19
//

import WidgetKit
import SwiftUI

struct QuickActionsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsWidgetEntry {
        QuickActionsWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsWidgetEntry) -> Void) {
        completion(QuickActionsWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsWidgetEntry>) -> Void) {
        let entry = QuickActionsWidgetEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickActionsWidgetEntry: TimelineEntry {
    let date: Date
}

struct VivaDictaQuickActionsWidgetEntryView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    var entry: QuickActionsWidgetProvider.Entry

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    private var lightPillBackground: Color {
        if !isFullColor {
            .clear
        } else if colorScheme == .dark {
            Color(white: 0.18)
        } else {
            Color(white: 0.92)
        }
    }

    private var recordForeground: Color {
        if !isFullColor {
            .white
        } else if colorScheme == .dark {
            .white
        } else {
            .black
        }
    }

    private var recordFallbackBackground: Color {
        if !isFullColor {
            .clear
        } else if colorScheme == .dark {
            Color(red: 0.32, green: 0.06, blue: 0.08)
        } else {
            .black
        }
    }

    private var lightPillForeground: Color {
        if !isFullColor {
            .white
        } else if colorScheme == .dark {
            .white
        } else {
            .black
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Link(destination: URL(string: "openSearchFromWidget")!) {
                searchPill
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Link(destination: URL(string: "startRecordFromWidget")!) {
                    recordPill
                }
                .frame(maxWidth: .infinity)

                Link(destination: URL(string: "openAskFromWidget")!) {
                    askPill
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {backgroundGradient}
    }
    
    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.12),
                    Color(red: 0.18, green: 0.12, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    .white,
                    Color(red: 0.88, green: 0.85, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var searchPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.headline)
                .foregroundStyle(lightPillForeground)
                .widgetAccentable()
            Text("Search notes")
                .font(.headline)
                .foregroundStyle(lightPillForeground)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lightPillBackground, in: .rect(cornerRadius: 22))
    }

    private var recordPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "record.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .widgetAccentable()
            Text("Record")
                .font(.headline)
                .foregroundStyle(recordForeground)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isFullColor {
                WidgetRecordPillBackground(cornerRadius: 22, colorScheme: colorScheme)
            } else {
                recordFallbackBackground
            }
        }
        .clipShape(.rect(cornerRadius: 22))
    }

    private var askPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.headline)
                .foregroundStyle(lightPillForeground)
                .widgetAccentable()
            Text("Ask AI")
                .font(.headline)
                .foregroundStyle(lightPillForeground)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lightPillBackground, in: .rect(cornerRadius: 22))
    }
}

struct VivaDictaQuickActionsWidget: Widget {
    let kind: String = "VivaDictaQuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsWidgetProvider()) { entry in
            VivaDictaQuickActionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Search notes, start a recording, or open Ask AI.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) {
    VivaDictaQuickActionsWidget()
} timeline: {
    QuickActionsWidgetEntry(date: .now)
}
