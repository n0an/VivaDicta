//
//  VivaDictaAskRecordWidget.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2026.04.19
//

import WidgetKit
import SwiftUI

struct AskRecordWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AskRecordWidgetEntry {
        AskRecordWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AskRecordWidgetEntry) -> Void) {
        completion(AskRecordWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AskRecordWidgetEntry>) -> Void) {
        let entry = AskRecordWidgetEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct AskRecordWidgetEntry: TimelineEntry {
    let date: Date
}

struct VivaDictaAskRecordWidgetEntryView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    var entry: AskRecordWidgetProvider.Entry

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    private var askBackground: Color {
        if !isFullColor {
            .clear
        } else if colorScheme == .dark {
            Color(white: 0.18)
        } else {
            Color(white: 0.84)
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

    private var askForeground: Color {
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
            Link(destination: URL(string: "openAskFromWidget")!) {
                askButton
            }
            .frame(maxWidth: .infinity)

            Link(destination: URL(string: "startRecordFromWidget")!) {
                recordButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
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

    private var askButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(askForeground)
                .widgetAccentable()
            Text("Ask AI")
                .font(.headline)
                .foregroundStyle(askForeground)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(askBackground, in: .rect(cornerRadius: 18))
    }

    private var recordButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "record.circle.fill")
                .font(.title2)
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
                WidgetRecordPillBackground(cornerRadius: 18, colorScheme: colorScheme)
            } else {
                recordFallbackBackground
            }
        }
        .clipShape(.rect(cornerRadius: 18))
    }
}

struct VivaDictaAskRecordWidget: Widget {
    let kind: String = "VivaDictaAskRecordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AskRecordWidgetProvider()) { entry in
            VivaDictaAskRecordWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ask & Record")
        .description("Quickly open Ask AI or start a new recording.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    VivaDictaAskRecordWidget()
} timeline: {
    AskRecordWidgetEntry(date: .now)
}
