//
//  SimRaRecordingActivityManager.swift
//  SimRa
//
//  Created by Emil Pauls on 31.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


//
//  SimRaRecordingActivityManager.swift
//  SimRa
//
//  ActivityKit integration for SimRa recordings.
//

import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
final class SimRaRecordingActivityManager {

    static let shared =
        SimRaRecordingActivityManager()

    private init() {}

    // MARK: - Start

    @discardableResult
    func start(
        tripId: Int,
        bikeTypeId: Int,
        startDate: Date = .now
    ) -> Bool {

        guard ActivityAuthorizationInfo()
            .areActivitiesEnabled
        else {
            return false
        }

        // Prevent duplicate SimRa activities.
        guard Activity<SimRaRecordingAttributes>
            .activities
            .isEmpty
        else {
            return false
        }

        let attributes =
            SimRaRecordingAttributes(
                tripId: tripId,
                bikeTypeId: bikeTypeId,
                startDate: startDate
            )

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds: 0,
                distanceMeters: 0,
                incidents: 0
            )

        let content =
            ActivityContent(
                state: state,
                staleDate:
                    startDate.addingTimeInterval(
                        60 * 60 * 8
                    )
            )

        do {
            _ = try Activity<
                SimRaRecordingAttributes
            >.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )

            return true

        } catch {
            return false
        }
    }

    // MARK: - Update

    func update(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) async {

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds:
                    elapsedSeconds,
                distanceMeters:
                    distanceMeters,
                incidents:
                    incidents
            )

        let content =
            ActivityContent(
                state: state,
                staleDate:
                    Date.now.addingTimeInterval(
                        60 * 10
                    )
            )

        for activity in Activity<
            SimRaRecordingAttributes
        >.activities {

            await activity.update(
                content
            )
        }
    }

    // MARK: - Stop

    func stop(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) async {

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds:
                    elapsedSeconds,
                distanceMeters:
                    distanceMeters,
                incidents:
                    incidents
            )

        let content =
            ActivityContent(
                state: state,
                staleDate: nil
            )

        for activity in Activity<
            SimRaRecordingAttributes
        >.activities {

            await activity.end(
                content,
                dismissalPolicy:
                    .immediate
            )
        }
    }
}