//
//  SimRaWidgetBundle 2.swift
//  SimRa
//
//  Created by Emil Pauls on 25.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.2, *)
struct SimRaLiveActivity: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(
            for: SimRaRecordingAttributes.self
        ) { context in

            // MARK: Lock Screen / Banner

            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 14) {

                    Image(systemName: "bicycle")
                        .font(.title2)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 5) {

                        Text("SimRa")
                            .font(.headline)

                        HStack(spacing: 14) {

                            Label {
                                Text(
                                    formatElapsed(
                                        context.state.elapsedSeconds
                                    )
                                )
                                .monospacedDigit()
                            } icon: {
                                Image(systemName: "timer")
                            }

                            Label {
                                Text(
                                    formatDistance(
                                        context.state.distanceMeters
                                    )
                                )
                                .monospacedDigit()
                            } icon: {
                                Image(systemName: "location")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                if #available(iOS 17.0, *) {
                    Button(intent: StopRecordingIntent()) {
                        Label("Stop recording", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)
                    .background(
                        .red.opacity(0.12),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(.red.opacity(0.34), lineWidth: 1)
                    )
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in

            DynamicIsland {

                // MARK: Expanded Leading

                DynamicIslandExpandedRegion(.leading) {

                    VStack(alignment: .leading, spacing: 4) {

                        Image(systemName: "bicycle")
                            .font(.title2)
                            .foregroundStyle(.tint)

                        Text("SimRa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Expanded Trailing

                DynamicIslandExpandedRegion(.trailing) {

                    VStack(alignment: .trailing, spacing: 4) {

                        Text(
                            formatElapsed(
                                context.state.elapsedSeconds
                            )
                        )
                        .font(.headline)
                        .monospacedDigit()

                        Text(
                            formatDistance(
                                context.state.distanceMeters
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }

                // MARK: Expanded Center

                DynamicIslandExpandedRegion(.center) {

                    VStack(spacing: 2) {

                        Text("Aufnahme")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(
                            formatElapsed(
                                context.state.elapsedSeconds
                            )
                        )
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    }
                }

                // MARK: Expanded Bottom

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {

                        HStack {

                            Label {
                                Text(
                                    formatDistance(
                                        context.state.distanceMeters
                                    )
                                )
                                .monospacedDigit()
                            } icon: {
                                Image(systemName: "location")
                            }

                            Spacer()

                            Label(
                                "SimRa",
                                systemImage: "bicycle"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if #available(iOS 17.0, *) {
                            Button(intent: StopRecordingIntent()) {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                .red.opacity(0.12),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(.red.opacity(0.34), lineWidth: 1)
                            )
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                        }
                    }
                }

            } compactLeading: {

                Image(systemName: "bicycle")

            } compactTrailing: {

                Text(
                    formatElapsed(
                        context.state.elapsedSeconds
                    )
                )
                .monospacedDigit()
                .font(.caption2)

            } minimal: {

                Image(systemName: "bicycle")
            }
        }
    }
}

// MARK: - Formatting

@available(iOS 16.2, *)
private func formatElapsed(_ seconds: Int) -> String {

    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainingSeconds = seconds % 60

    if hours > 0 {
        return String(
            format: "%d:%02d:%02d",
            hours,
            minutes,
            remainingSeconds
        )
    }

    return String(
        format: "%02d:%02d",
        minutes,
        remainingSeconds
    )
}

@available(iOS 16.2, *)
private func formatDistance(_ meters: Int) -> String {

    if meters < 1000 {
        return "\(meters) m"
    }

    let kilometers = Double(meters) / 1000.0

    if kilometers < 10 {
        return String(
            format: "%.1f km",
            kilometers
        )
    }

    return String(
        format: "%.0f km",
        kilometers
    )
}
