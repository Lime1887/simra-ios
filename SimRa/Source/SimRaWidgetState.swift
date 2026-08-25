//
//  RecordingAppIntents.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - Shared Widget State

enum SimRaWidgetState {

    static let suiteName =
        "group.de.tu-berlin.mcc.simra"

    static let isRecording =
        "isRecording"

    static let startDate =
        "startDate"

    static let elapsedSeconds =
        "elapsedSeconds"

    static let distanceMeters =
        "distanceMeters"

    static let incidents =
        "incidents"

    static func defaults() ->
        UserDefaults?
    {
        UserDefaults(
            suiteName:
                suiteName
        )
    }
}

// MARK: - Start Recording Intent

struct StartSimRaRecordingIntent:
    AppIntent,
    Sendable
{

    static var title: LocalizedStringResource {
        "Start SimRa Recording"
    }

    static var description:
        IntentDescription?
    {
        IntentDescription(
            "Starts a new SimRa recording."
        )
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform()
        async throws
        -> some IntentResult
    {
        let success =
            AppDelegate
                .shared()
                .startRecordingRequested()

        guard success else {

            throw StartRecordingIntentError
                .failed
        }

        await MainActor.run {

            RecordingAppIntentSynchronizer
                .syncRecordingState()

        }

        return .result()
    }
}

// MARK: - Stop Recording Intent

struct StopSimRaRecordingIntent:
    AppIntent,
    Sendable
{

    static var title:
        LocalizedStringResource
    {
        "Stop SimRa Recording"
    }

    static var description:
        IntentDescription?
    {
        IntentDescription(
            "Stops the current SimRa recording."
        )
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform()
        async throws
        -> some IntentResult
    {
        let success =
            AppDelegate
                .shared()
                .stopRecordingRequested()

        guard success else {

            throw StopRecordingIntentError
                .failed
        }

        await MainActor.run {

            RecordingAppIntentSynchronizer
                .syncRecordingState()

        }

        return .result()
    }
}

// MARK: - Incident Intent

struct MarkSimRaIncidentIntent:
    AppIntent,
    Sendable
{

    static var title:
        LocalizedStringResource
    {
        "Mark SimRa Incident"
    }

    static var description:
        IntentDescription?
    {
        IntentDescription(
            "Marks an incident during the active SimRa recording."
        )
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform()
        async throws
        -> some IntentResult
    {
        let trip =
            AppDelegate
                .shared()
                .activeTrip

        guard
            let activeTrip = trip,
            let tripLocation =
                activeTrip.tripLocations.lastObject
                as? TripLocation
        else {

            throw MarkIncidentIntentError
                .failed
        }

        let annotation =
            TripAnnotation()

        annotation.incidentId = 0
        annotation.comment =
            "Marked from SimRa widget"

        tripLocation.tripAnnotation =
            annotation

        NotificationCenter.default.post(
            name:
                .incidentMarked,
            object:
                nil
        )

        return .result()
    }
}

// MARK: - Synchronizer

@MainActor
enum RecordingAppIntentSynchronizer {

    static func syncRecordingState() {

        let appDelegate =
            AppDelegate.shared()

        let activeTrip =
            appDelegate.activeTrip

        let isRecording =
            activeTrip != nil

        let startDate =
            activeTrip?.recordingStartDate

        guard let defaults =
            SimRaWidgetState.defaults()
        else {
            return
        }

        defaults.set(
            isRecording,
            forKey:
                SimRaWidgetState.isRecording
        )

        if
            isRecording,
            let startDate
        {

            defaults.set(
                startDate.timeIntervalSince1970,
                forKey:
                    SimRaWidgetState.startDate
            )

        } else {

            defaults.removeObject(
                forKey:
                    SimRaWidgetState.startDate
            )
        }

        let elapsedSeconds: Int

        if let startDate {

            elapsedSeconds =
                max(
                    0,
                    Int(
                        Date()
                            .timeIntervalSince(
                                startDate
                            )
                            .rounded()
                    )
                )

        } else {

            elapsedSeconds = 0
        }

        defaults.set(
            elapsedSeconds,
            forKey:
                SimRaWidgetState.elapsedSeconds
        )

        if !isRecording {

            defaults.set(
                0,
                forKey:
                    SimRaWidgetState.distanceMeters
            )

            defaults.set(
                0,
                forKey:
                    SimRaWidgetState.incidents
            )
        }

        WidgetCenter.shared.reloadTimelines(
            ofKind:
                "SimRaRecordingWidget"
        )
    }
}

// MARK: - Errors

enum StartRecordingIntentError:
    Error,
    LocalizedError
{
    case failed

    var errorDescription: String? {
        "SimRa could not start the recording."
    }
}

enum StopRecordingIntentError:
    Error,
    LocalizedError
{
    case failed

    var errorDescription: String? {
        "SimRa could not stop the recording."
    }
}

enum MarkIncidentIntentError:
    Error,
    LocalizedError
{
    case failed

    var errorDescription: String? {
        "No active SimRa recording was found."
    }
}