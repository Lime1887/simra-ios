//
//  SimRaLiveActivity.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity

@available(iOS 16.2, *)
struct SimRaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimRaRecordingAttributes.self) { context in
            // MARK: Lock Screen
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Image(systemName: "bicycle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)

                            Text("SimRa")
                                .font(.headline.weight(.semibold))
                        }

                        Text(NSLocalizedString("Aufnahme läuft", comment: "Live Activity recording status"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(
                            timerInterval: context.attributes.startDate...Date.distantFuture,
                            pauseTime: Date.distantFuture,
                            countsDown: false,
                            showsHours: true
                        )
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                        Text(formatDistance(context.state.distanceMeters))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }

                // MARK: Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        liveActivityIncidentButton
                        Spacer(minLength: 0)
                        stopLink
                    }
                }
            } compactLeading: {
                Image(systemName: "bicycle")
                    .font(.system(size: 10, weight: .semibold))
            } compactTrailing: {
                Text(
                    timerInterval: context.attributes.startDate...Date.distantFuture,
                    pauseTime: Date.distantFuture,
                    countsDown: false,
                    showsHours: false
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .allowsTightening(true)
                .frame(width: 40)
                .lineLimit(1)
            } minimal: {
                Image(systemName: "bicycle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Expanded Incident Button

    @ViewBuilder
    private var liveActivityIncidentButton: some View {
        if #available(iOS 17.0, *) {
            Button(intent: MarkLiveActivityIncidentIntent()) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(Color.orange.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(NSLocalizedString("Report danger", comment: "Report danger button")))
        } else {
            Link(destination: markIncidentURL) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(Color.orange.opacity(0.14), in: Circle())
            }
            .accessibilityLabel(Text(NSLocalizedString("Report danger", comment: "Report danger button")))
        }
    }

    // MARK: - Stop

    private var stopLink: some View {
        Link(destination: stopRecordingURL) {
            Label(
                NSLocalizedString("Stop", comment: "Stop recording"),
                systemImage: "stop.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(minHeight: 42)
            .background(Color.red, in: Capsule())
        }
        .accessibilityLabel(Text(NSLocalizedString("Stop recording", comment: "Stop recording")))
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
private struct LockScreenLiveActivityView: View {
    let attributes: SimRaRecordingAttributes
    let state: SimRaRecordingAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            metrics
            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bicycle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.red)

            Text("SimRa")
                .font(.headline.weight(.semibold))

            Text(NSLocalizedString("Aufnahme", comment: "Recording"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
        }
    }

    // MARK: Metrics

    private var metrics: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(
                timerInterval: attributes.startDate...Date.distantFuture,
                pauseTime: Date.distantFuture,
                countsDown: false,
                showsHours: true
            )
            .font(.system(size: 31, weight: .bold, design: .rounded))
            .monospacedDigit()

            Text("·")
                .foregroundStyle(.tertiary)

            Text(formatDistance(state.distanceMeters))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if state.incidents > 0 {
                Label("\(state.incidents)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(Text("\(state.incidents)"))
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 10) {
            if #available(iOS 17.0, *) {
                Button(intent: MarkLiveActivityIncidentIntent()) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.orange.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: markIncidentURL) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.orange.opacity(0.13), in: Capsule())
                }
            }

            Link(destination: stopRecordingURL) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.red.opacity(0.13), in: Capsule())
            }
        }
    }
}

// MARK: - Incident Intent

@available(iOS 17.0, *)
private struct MarkLiveActivityIncidentIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Danger"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.de.tu-berlin.mcc.simra")

        let pending = defaults?.integer(forKey: "pendingLiveActivityIncidents") ?? 0
        defaults?.set(pending + 1, forKey: "pendingLiveActivityIncidents")

        for activity in Activity<SimRaRecordingAttributes>.activities {
            let currentState = activity.content.state
            let updatedState = SimRaRecordingAttributes.ContentState(
                elapsedSeconds: currentState.elapsedSeconds,
                distanceMeters: currentState.distanceMeters,
                incidents: currentState.incidents + 1
            )

            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil
                )
            )
        }

        return .result()
    }
}

// MARK: - Formatting

private func formatDistance(_ meters: Int) -> String {
    let safe = max(meters, 0)
    let kilometers = Double(safe) / 1000.0

    if kilometers < 1 {
        return String(format: "%.0f m", Double(safe))
    }

    if kilometers < 10 {
        return String(format: "%.1f km", kilometers)
    }

    return String(format: "%.0f km", kilometers)
}

// MARK: - URLs

private let stopRecordingURL = URL(string: "simra://recording/stop")!
private let markIncidentURL = URL(string: "simra://incident/mark?type=0")!
