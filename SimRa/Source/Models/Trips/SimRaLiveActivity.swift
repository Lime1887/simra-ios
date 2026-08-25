//
//  SimRaLiveActivity.swift
//  SimRa
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct SimRaLiveActivity: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(
            for: SimRaRecordingAttributes.self
        ) { context in

            HStack(spacing: 16) {

                Image(systemName: "bicycle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {

                    Text("SimRa")
                        .font(.headline.weight(.semibold))

                    HStack(spacing: 16) {

                        Text(
                            formatElapsed(
                                context.state.elapsedSeconds
                            )
                        )
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()

                        Text(
                            formatDistance(
                                context.state.distanceMeters
                            )
                        )
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    }
                }

                Spacer(minLength: 8)

                Link(destination: stopRecordingURL) {
                    Image(systemName: "stop.fill")
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(
                    .red.opacity(0.12),
                    in: Circle()
                )
            }
            .padding()
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in

            DynamicIsland {

                DynamicIslandExpandedRegion(.leading) {

                    VStack(alignment: .leading, spacing: 3) {

                        Image(systemName: "bicycle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.tint)

                        Text("SimRa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {

                    VStack(alignment: .trailing, spacing: 3) {

                        Text(
                            formatElapsed(
                                context.state.elapsedSeconds
                            )
                        )
                        .font(.title3.weight(.semibold))
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

                DynamicIslandExpandedRegion(.bottom) {

                    HStack(spacing: 12) {

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {

                            Text("Aufnahme")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                formatDistance(
                                    context.state.distanceMeters
                                )
                            )
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                        }

                        Spacer()

                        Link(destination: stopRecordingURL) {
                            Label(
                                "Stop",
                                systemImage: "stop.fill"
                            )
                            .font(
                                .subheadline.weight(.semibold)
                            )
                            .frame(minWidth: 74)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.red)
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
                .font(.caption2.weight(.semibold))
                .monospacedDigit()

            } minimal: {

                Image(systemName: "bicycle")
            }
        }
    }
}

@available(iOS 16.2, *)
private func formatElapsed(
    _ seconds: Int
) -> String {

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
private func formatDistance(
    _ meters: Int
) -> String {

    let kilometers = Double(meters) / 1000

    if kilometers < 1 {
        return String(
            format: "%.0f m",
            Double(meters)
        )
    }

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

private let stopRecordingURL = URL(string: "simra://recording/stop")!

#Preview(
    "SimRa Recording",
    as: .content,
    using: SimRaRecordingAttributes(
        tripId: 1,
        bikeTypeId: 1
    )
) {
    SimRaLiveActivity()
} contentStates: {

    SimRaRecordingAttributes.ContentState(
        elapsedSeconds: 120,
        distanceMeters: 340,
        incidents: 0
    )

    SimRaRecordingAttributes.ContentState(
        elapsedSeconds: 768,
        distanceMeters: 2700,
        incidents: 2
    )
}
