//
//  SimRaRecordingWidget.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct SimRaRecordingEntry: TimelineEntry {

    let date: Date
    let isRecording: Bool
    let elapsedSeconds: Int
    let distanceMeters: Int
    let incidents: Int
    let totalRides: Int
    let totalDistanceMeters: Int
}

// MARK: - Timeline Provider

struct SimRaRecordingProvider: TimelineProvider {

    private enum StateKey {
        static let suiteName =
            "group.de.tu-berlin.mcc.simra"

        static let isRecording =
            "isRecording"

        static let elapsedSeconds =
            "elapsedSeconds"

        static let distanceMeters =
            "distanceMeters"

        static let incidents =
            "incidents"

        static let totalRides =
            "totalRides"

        static let totalDistanceMeters =
            "totalDistanceMeters"
    }

    // MARK: Placeholder

    func placeholder(
        in context: Context
    ) -> SimRaRecordingEntry {

        SimRaRecordingEntry(
            date: .now,
            isRecording: false,
            elapsedSeconds: 0,
            distanceMeters: 0,
            incidents: 0,
            totalRides: 0,
            totalDistanceMeters: 0
        )
    }

    // MARK: Snapshot

    func getSnapshot(
        in context: Context,
        completion: @escaping (
            SimRaRecordingEntry
        ) -> Void
    ) {

        completion(
            currentEntry()
        )
    }

    // MARK: Timeline

    func getTimeline(
        in context: Context,
        completion: @escaping (
            Timeline<SimRaRecordingEntry>
        ) -> Void
    ) {

        /*
         * The app explicitly requests a reload through
         * WidgetCenter when the recording state changes.
         *
         * Therefore the widget doesn't need an artificial
         * 5-second timeline.
         */
        completion(
            Timeline(
                entries: [
                    currentEntry()
                ],
                policy: .never
            )
        )
    }

    // MARK: Current Entry

    private func currentEntry()
        -> SimRaRecordingEntry
    {

        let defaults =
            UserDefaults(
                suiteName:
                    StateKey.suiteName
            ) ?? UserDefaults.standard

        return SimRaRecordingEntry(
            date: .now,

            isRecording:
                defaults.bool(
                    forKey:
                        StateKey.isRecording
                ),

            elapsedSeconds:
                max(
                    defaults.integer(
                        forKey:
                            StateKey.elapsedSeconds
                    ),
                    0
                ),

            distanceMeters:
                max(
                    defaults.integer(
                        forKey:
                            StateKey.distanceMeters
                    ),
                    0
                ),

            incidents:
                max(
                    defaults.integer(
                        forKey:
                            StateKey.incidents
                    ),
                    0
                ),

            totalRides:
                max(
                    defaults.integer(
                        forKey:
                            StateKey.totalRides
                    ),
                    0
                ),

            totalDistanceMeters:
                max(
                    defaults.integer(
                        forKey:
                            StateKey.totalDistanceMeters
                    ),
                    0
                )
        )
    }
}

// MARK: - Widget

@available(iOS 16.2, *)
public struct SimRaRecordingWidget: Widget {

    public static let kind =
        "SimRaRecordingWidget"

    public init() {}

    public var body:
        some WidgetConfiguration
    {

        StaticConfiguration(
            kind:
                Self.kind,
            provider:
                SimRaRecordingProvider()
        ) { entry in

            SimRaRecordingWidgetView(
                entry: entry
            )
        }
        .configurationDisplayName(
            "SimRa"
        )
        .description(
            "Start or continue a SimRa recording."
        )
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

// MARK: - Root Widget View

@available(iOS 16.2, *)
private struct SimRaRecordingWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    @Environment(\.widgetFamily)
    private var family

    var body: some View {

        if #available(iOS 17.0, *) {

            content
                .containerBackground(
                    for: .widget
                ) {
                    Color.clear
                }

        } else {

            content
        }
    }

    @ViewBuilder
    private var content:
        some View
    {

        switch family {

        case .systemSmall:
            SmallWidgetView(
                entry: entry
            )

        case .systemMedium:
            MediumWidgetView(
                entry: entry
            )

        default:
            SmallWidgetView(
                entry: entry
            )
        }
    }
}

// MARK: - Small Widget

@available(iOS 16.2, *)
private struct SmallWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    private var accent:
        Color
    {
        entry.isRecording
            ? .red
            : .green
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            // MARK: Header

            HStack(
                spacing: 7
            ) {

                Image(
                    systemName:
                        "bicycle"
                )
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    accent
                )

                Text("SimRa")
                    .font(
                        .headline.weight(
                            .semibold
                        )
                    )

                Spacer()
            }

            Spacer(
                minLength: 8
            )

            // MARK: Content

            if entry.isRecording {

                recordingContent

            } else {

                readyContent
            }
        }
        .padding(16)
    }

    // MARK: Recording Content

    private var recordingContent:
        some View
    {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Text(
                NSLocalizedString(
                    "Recording",
                    comment:
                        "Recording state"
                )
            )
            .font(
                .caption.weight(
                    .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                formatTime(
                    entry.elapsedSeconds
                )
            )
            .font(
                .system(
                    size: 30,
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()

            Text(
                formatDistance(
                    entry.distanceMeters
                )
            )
            .font(
                .subheadline.weight(
                    .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

            if entry.incidents > 0 {

                Text(
                    "\(entry.incidents) " +
                    NSLocalizedString(
                        "incidents",
                        comment:
                            "Incident count"
                    )
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .orange
                )
            }

            Spacer(
                minLength: 7
            )

            HStack(spacing: 8) {
                Link(
                    destination:
                        markIncidentURL
                ) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(
                            .subheadline.weight(
                                .semibold
                            )
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(height: 32)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .buttonBorderShape(
                    .capsule
                )
                .tint(.orange)
                .accessibilityLabel("Gefahr erfassen")

                Link(
                    destination:
                        stopRecordingURL
                ) {
                    Image(systemName: "stop.fill")
                        .font(
                            .subheadline.weight(
                                .semibold
                            )
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(height: 32)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .buttonBorderShape(
                    .capsule
                )
                .tint(.red)
                .accessibilityLabel("Stop recording")
            }
        }
    }

    // MARK: Ready Content

    private var readyContent:
        some View
    {

        VStack(
            alignment: .leading,
            spacing: 9
        ) {

            Text(
                NSLocalizedString(
                    "Ready",
                    comment:
                        "Ready to record"
                )
            )
            .font(
                .title3.weight(
                    .semibold
                )
            )

            Text(
                NSLocalizedString(
                    "Start a new ride",
                    comment:
                        "Start a new ride"
                )
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )

            Spacer(
                minLength: 4
            )

            Link(
                destination:
                    startRecordingURL
            ) {

                Label(
                    NSLocalizedString(
                        "Start",
                        comment:
                            "Start recording"
                    ),
                    systemImage:
                        "record.circle"
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .buttonBorderShape(
                .capsule
            )
            .tint(.green)
        }
    }
}

// MARK: - Medium Widget

@available(iOS 16.2, *)
private struct MediumWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    private var accent:
        Color
    {
        entry.isRecording
            ? .red
            : .green
    }

    var body: some View {

        HStack(
            spacing: 20
        ) {

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                // MARK: Header

                HStack(
                    spacing: 7
                ) {

                    Image(
                        systemName:
                            "bicycle"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        accent
                    )

                    Text("SimRa")
                        .font(
                            .headline.weight(
                                .semibold
                            )
                        )
                }

                Spacer(
                    minLength: 8
                )

                if entry.isRecording {

                    recordingContent

                } else {

                    readyContent
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )

            Divider()

            // MARK: Statistics

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                if entry.isRecording {

                    Text(
                        NSLocalizedString(
                            "Distance",
                            comment:
                                "Distance"
                        )
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        formatDistance(
                            entry.distanceMeters
                        )
                    )
                    .font(
                        .title2.weight(
                            .semibold
                        )
                    )
                    .monospacedDigit()

                    Text(
                        formatTime(
                            entry.elapsedSeconds
                        )
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .monospacedDigit()

                    if entry.incidents > 0 {

                        Text(
                            "\(entry.incidents) " +
                            NSLocalizedString(
                                "incidents",
                                comment:
                                    "Incident count"
                            )
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .orange
                        )
                    }

                } else {

                    Text(
                        NSLocalizedString(
                            "Gesamt",
                            comment:
                                "Total distance"
                        )
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        formatDistance(
                            entry.totalDistanceMeters
                        )
                    )
                    .font(
                        .title2.weight(
                            .semibold
                        )
                    )
                    .monospacedDigit()

                    Text(
                        entry.totalRides == 1
                            ? "1 Fahrt"
                            : "\(entry.totalRides) Fahrten"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .frame(
                minWidth: 82,
                alignment:
                    .leading
            )
        }
        .padding(18)
    }

    // MARK: Recording Content

    private var recordingContent:
        some View
    {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            Text(
                NSLocalizedString(
                    "Recording",
                    comment:
                        "Recording state"
                )
            )
            .font(
                .subheadline.weight(
                    .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                formatTime(
                    entry.elapsedSeconds
                )
            )
            .font(
                .system(
                    size: 28,
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()

            Text(
                formatDistance(
                    entry.distanceMeters
                )
            )
            .font(
                .subheadline.weight(
                    .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

            Spacer(
                minLength: 9
            )

            HStack(spacing: 8) {
                Link(
                    destination:
                        markIncidentURL
                ) {
                    Label(
                        "Gefahr",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .caption.weight(
                            .semibold
                        )
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .buttonBorderShape(
                    .capsule
                )
                .tint(.orange)

                Link(
                    destination:
                        stopRecordingURL
                ) {
                    Label(
                        NSLocalizedString(
                            "Stop",
                            comment:
                                "Stop recording"
                        ),
                        systemImage:
                            "stop.fill"
                    )
                    .font(
                        .caption.weight(
                            .semibold
                        )
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .buttonBorderShape(
                    .capsule
                )
                .tint(.red)
            }
        }
    }

    // MARK: Ready Content

    private var readyContent:
        some View
    {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Text(
                NSLocalizedString(
                    "Ready for your next ride",
                    comment:
                        "Ready for next ride"
                )
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )

            Spacer(
                minLength: 8
            )

            Link(
                destination:
                    startRecordingURL
            ) {

                Label(
                    NSLocalizedString(
                        "Start recording",
                        comment:
                            "Start recording"
                    ),
                    systemImage:
                        "record.circle"
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .buttonBorderShape(
                .capsule
            )
            .tint(.green)
        }
    }
}

// MARK: - Formatting

private func formatTime(
    _ seconds: Int
) -> String {

    let safeSeconds =
        max(
            0,
            seconds
        )

    let hours =
        safeSeconds / 3600

    let minutes =
        (safeSeconds % 3600) / 60

    let remainingSeconds =
        safeSeconds % 60

    if hours > 0 {

        return String(
            format:
                "%d:%02d:%02d",
            hours,
            minutes,
            remainingSeconds
        )
    }

    return String(
        format:
            "%02d:%02d",
        minutes,
        remainingSeconds
    )
}

private func formatDistance(
    _ meters: Int
) -> String {

    let safeMeters =
        max(
            0,
            meters
        )

    if safeMeters >= 1000 {

        return String(
            format:
                "%.1f km",
            Double(safeMeters) /
                1000.0
        )
    }

    return "\(safeMeters) m"
}

// MARK: - URLs

private let startRecordingURL =
    URL(
        string:
            "simra://recording/start"
    )!

private let stopRecordingURL =
    URL(
        string:
            "simra://recording/stop"
    )!

private let markIncidentURL =
    URL(
        string:
            "simra://incident/mark?type=0"
    )!
