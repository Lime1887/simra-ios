//
//  SimRa_Widgets.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 25.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }

    func timeline(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {
        Timeline(
            entries: [
                SimpleEntry(date: Date(), configuration: configuration)
            ],
            policy: .never
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct SimRa_WidgetsEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SimRa", systemImage: "bicycle")
                .font(.headline)

            HStack(spacing: 10) {
                recordingLink(
                    title: "Start",
                    systemImage: "play.fill",
                    tint: .green,
                    url: "simra://recording/start"
                )

                recordingLink(
                    title: "Stop",
                    systemImage: "stop.fill",
                    tint: .red,
                    url: "simra://recording/stop"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func recordingLink(
        title: String,
        systemImage: String,
        tint: Color,
        url: String
    ) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(tint)
                .background(
                    tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                }
        }
    }
}

struct SimRa_Widgets: Widget {
    let kind: String = "SimRa_Widgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            SimRa_WidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SimRa")
        .description("Start or stop a SimRa recording.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

extension ConfigurationAppIntent {
    fileprivate static var preview: ConfigurationAppIntent {
        ConfigurationAppIntent()
    }
}

#Preview(as: .systemSmall) {
    SimRa_Widgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .preview)
}
