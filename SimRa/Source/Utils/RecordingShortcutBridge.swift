//
//  RecordingShortcutBridge.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import WidgetKit

@objcMembers
public final class RecordingShortcutBridge: NSObject {

    // MARK: - Shared State

    private enum SharedState {
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
    }

    // MARK: - Start Recording

    /// Starts a SimRa recording.
    ///
    /// Used by Siri Shortcuts and simra:// URLs.
    @discardableResult
    public static func startRecording() -> Bool {

        let result =
            AppDelegate.shared()
                .startRecordingRequested()

        guard result else {
            return false
        }

        /*
         * startRecordingRequested() may return before
         * AppDelegate.activeTrip is fully established.
         *
         * Wait for the actual recording state instead
         * of publishing a premature "recording" state.
         */
        waitForRecordingState(
            expectedRecording: true
        )

        return true
    }

    // MARK: - Stop Recording

    /// Stops the current SimRa recording.
    ///
    /// Used by Siri Shortcuts and simra:// URLs.
    @discardableResult
    public static func stopRecording() -> Bool {

        let result =
            AppDelegate.shared()
                .stopRecordingRequested()

        guard result else {
            return false
        }

        /*
         * Wait until activeTrip is really gone before
         * publishing the final "not recording" state.
         */
        waitForRecordingState(
            expectedRecording: false
        )

        return true
    }

    // MARK: - Wait For State

    private static func waitForRecordingState(
        expectedRecording: Bool
    ) {

        let maxAttempts = 30
        let interval: TimeInterval = 0.1

        checkRecordingState(
            expectedRecording:
                expectedRecording,
            attempt:
                0,
            maxAttempts:
                maxAttempts,
            interval:
                interval
        )
    }

    private static func checkRecordingState(
        expectedRecording: Bool,
        attempt: Int,
        maxAttempts: Int,
        interval: TimeInterval
    ) {

        let actualState =
            AppDelegate.shared().activeTrip != nil

        /*
         * State reached:
         * publish it immediately.
         */
        if actualState == expectedRecording {
            publishCurrentState()
            return
        }

        /*
         * Give AppDelegate a little more time.
         */
        guard attempt < maxAttempts else {
            /*
             * Even if AppDelegate did not reach the expected
             * state within the timeout, publish the ACTUAL
             * state rather than lying to the widget.
             */
            publishCurrentState()
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + interval
        ) {
            checkRecordingState(
                expectedRecording:
                    expectedRecording,
                attempt:
                    attempt + 1,
                maxAttempts:
                    maxAttempts,
                interval:
                    interval
            )
        }
    }

    // MARK: - Publish State

    private static func publishCurrentState() {

        let appDelegate =
            AppDelegate.shared()

        let activeTrip =
            appDelegate.activeTrip

        let isRecording =
            activeTrip != nil

        let startDate =
            activeTrip?.recordingStartDate

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

        let distanceMeters =
            max(
                activeTrip?.length() ?? 0,
                0
            )

        let incidents =
            max(
                activeTrip?.tripValidAnnotations() ?? 0,
                0
            )

        let defaults =
            UserDefaults(
                suiteName:
                    SharedState.suiteName
            ) ?? UserDefaults.standard

        defaults.set(
            isRecording,
            forKey:
                SharedState.isRecording
        )

        let regionSuffix = appDelegate.regions.regionId == 0 ? "" : "-\(appDelegate.regions.regionId)"
        let totalRides = appDelegate.defaults.integer(forKey: "totalRides\(regionSuffix)")
        let totalDistance = appDelegate.defaults.integer(forKey: "totalLength\(regionSuffix)")
        defaults.set(totalRides, forKey: "totalRides")
        defaults.set(totalDistance, forKey: "totalDistanceMeters")

        defaults.set(
            elapsedSeconds,
            forKey:
                SharedState.elapsedSeconds
        )

        defaults.set(
            distanceMeters,
            forKey:
                SharedState.distanceMeters
        )

        defaults.set(
            incidents,
            forKey:
                SharedState.incidents
        )

        /*
         * The widget must be told that its current timeline
         * is no longer valid.
         */
        WidgetCenter.shared.reloadTimelines(
            ofKind: "SimRaRecordingWidget"
        )
        WidgetCenter.shared.reloadAllTimelines()

        /*
         * Keep the existing app notification flow.
         */
        NotificationCenter.default.post(
            name:
                .recordingSessionDidChange,
            object:
                nil
        )
    }

    // MARK: - Incident

    /// Marks an incident during the active recording.
    @discardableResult
    public static func markIncident(
        _ incidentType: Int,
        source: String = "Siri / Widget"
    ) -> Bool {

        guard
            let activeTrip =
                AppDelegate.shared().activeTrip
        else {
            print("[RecordingShortcutBridge] No active trip found")
            return false
        }

        let targetLocation: TripLocation
        if let last = activeTrip.tripLocations.lastObject as? TripLocation {
            targetLocation = last
        } else if let loc = activeTrip.lastLocation {
            let newLoc = TripLocation()
            newLoc.location = loc
            activeTrip.tripLocations.add(newLoc)
            targetLocation = newLoc
        } else {
            print("[RecordingShortcutBridge] No location available for incident")
            return false
        }

        // Check if annotation already exists at this location
        if targetLocation.tripAnnotation != nil {
            print("[RecordingShortcutBridge] Annotation already exists at location")
            // Override anyway for quick recording
        }

        let annotation =
            TripAnnotation()

        annotation.incidentId =
            incidentType

        annotation.source = source

        let timeString =
            DateFormatter.localizedString(
                from: Date(),
                dateStyle: .none,
                timeStyle: .short
            )

        annotation.comment =
            "Schnell erfasst via \(source) (\(timeString)). Details später ausfüllen."

        targetLocation.tripAnnotation =
            annotation

        // Ensure trip is saved
        activeTrip.save()

        print("[RecordingShortcutBridge] Incident marked successfully: type=\(incidentType), source=\(source)")

        /*
         * Refresh the shared widget state because
         * the incident count has changed.
         */
        publishCurrentState()

        NotificationCenter.default.post(
            name:
                .incidentMarked,
            object:
                activeTrip
        )

        return true
    }
}

// MARK: - Notifications

public extension Notification.Name {

    static let startRecordingFromShortcut =
        Notification.Name(
            "startRecordingFromShortcutNotification"
        )

    static let stopRecordingFromShortcut =
        Notification.Name(
            "stopRecordingFromShortcutNotification"
        )

    static let incidentMarked =
        Notification.Name(
            "incidentMarkedNotification"
        )
}
