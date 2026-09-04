//
//  SimRaLiveActivity.swift
//  SimRa Widgets
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

            // MARK: - Lock Screen

            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in

            DynamicIsland {

                // MARK: - Expanded Leading

                DynamicIslandExpandedRegion(
                    .leading
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Image(
                            systemName: "bicycle"
                        )
                        .font(
                            .title3.weight(.semibold)
                        )
                        .foregroundStyle(.tint)

                        Text("SimRa")
                            .font(
                                .caption.weight(.semibold)
                            )
                    }
                }

                // MARK: - Expanded Trailing

                DynamicIslandExpandedRegion(
                    .trailing
                ) {
                    VStack(
                        alignment: .trailing,
                        spacing: 2
                    ) {
                        LiveTimer(
                            startDate:
                                context.attributes.startDate
                        )

                        Text(
                            formatDistance(
                                context.state.distanceMeters
                            )
                        )
                        .font(
                            .caption.weight(.medium)
                        )
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }

                // MARK: - Expanded Bottom

                DynamicIslandExpandedRegion(
                    .bottom
                ) {
                    HStack(
                        spacing: 10
                    ) {

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text("SimRa")
                                .font(
                                    .caption.weight(.medium)
                                )
                                .foregroundStyle(.secondary)

                            Text(
                                formatDistance(
                                    context.state.distanceMeters
                                )
                            )
                            .font(
                                .headline.weight(.semibold)
                            )
                            .monospacedDigit()
                        }

                        Spacer()

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
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(
                            .capsule
                        )
                        .tint(.orange)

                        Link(
                            destination:
                                stopRecordingURL
                        ) {
                            Label(
                                "Stop",
                                systemImage:
                                    "stop.fill"
                            )
                            .font(
                                .caption.weight(
                                    .semibold
                                )
                            )
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(
                            .capsule
                        )
                        .tint(.red)
                    }
                }

            } compactLeading: {

                Image(
                    systemName: "bicycle"
                )
                .foregroundStyle(.tint)

            } compactTrailing: {

                LiveTimer(
                    startDate:
                        context.attributes.startDate
                )
                .font(
                    .caption2.weight(
                        .semibold
                    )
                )
                .monospacedDigit()

            } minimal: {

                Image(
                    systemName: "bicycle"
                )
                .foregroundStyle(.tint)
            }
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct LockScreenLiveActivityView: View {

    let attributes:
        SimRaRecordingAttributes

    let state:
        SimRaRecordingAttributes.ContentState

    var body: some View {
        HStack(
            spacing: 12
        ) {

            Image(
                systemName: "bicycle"
            )
            .font(
                .title2.weight(
                    .semibold
                )
            )
            .foregroundStyle(.tint)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text("SimRa")
                    .font(
                        .headline.weight(
                            .semibold
                        )
                    )

                HStack(
                    spacing: 10
                ) {

                    LiveTimer(
                        startDate:
                            attributes.startDate
                    )

                    Text(
                        formatDistance(
                            state.distanceMeters
                        )
                    )
                    .monospacedDigit()
                }
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )

                if state.incidents > 0 {
                    Text("\(state.incidents) Gefahr(en) erfasst")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer(
                minLength: 4
            )

            Link(
                destination:
                    markIncidentURL
            ) {
                Image(
                    systemName: "exclamationmark.triangle.fill"
                )
                .font(
                    .body.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .frame(
                    width: 38,
                    height: 38
                )
                .background(
                    .orange,
                    in: Circle()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Gefahr erfassen"
            )

            Link(
                destination:
                    stopRecordingURL
            ) {
                Image(
                    systemName: "stop.fill"
                )
                .font(
                    .body.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .red
                )
                .frame(
                    width: 38,
                    height: 38
                )
                .background(
                    .red.opacity(
                        0.15
                    ),
                    in: Circle()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Stop recording"
            )
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            12
        )
        .activityBackgroundTint(
            .clear
        )
    }
}

// MARK: - Live Timer

@available(iOS 16.2, *)
private struct LiveTimer: View {

    let startDate: Date

    var body: some View {
        Text(
            timerInterval:
                startDate...Date.distantFuture,
            countsDown: false,
            showsHours: true
        )
        .monospacedDigit()
    }
}

// MARK: - Formatting

private func formatDistance(
    _ meters: Int
) -> String {

    let value = max(
        meters,
        0
    )

    let kilometers =
        Double(value) / 1000.0

    if kilometers < 1 {
        return String(
            format: "%.0f m",
            Double(value)
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

// MARK: - URLs

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
