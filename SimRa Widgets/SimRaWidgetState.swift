//
//  SimRaWidgetState.swift
//  SimRa
//
//  Shared state between the SimRa app and Widget Extension.
//

import Foundation

enum SimRaWidgetState {

    // MARK: - App Group

    static let suiteName =
        "group.de.tu-berlin.mcc.simra"

    // MARK: - Keys

    private static let isRecordingKey =
        "isRecording"

    static let startDate =
        "startDate"

    static let elapsedSeconds =
        "elapsedSeconds"

    static let distanceMeters =
        "distanceMeters"

    static let incidents =
        "incidents"

    // MARK: - Shared Defaults

    static var defaults: UserDefaults? {
        UserDefaults(
            suiteName: suiteName
        )
    }

    // MARK: - Read

    static var isRecording: Bool {
        defaults?.bool(
            forKey: isRecordingKey
        ) ?? false
    }

    static var recordingStartDate: Date? {
        guard
            let timestamp = defaults?.object(
                forKey: startDate
            ) as? Double,
            timestamp > 0
        else {
            return nil
        }

        return Date(
            timeIntervalSince1970: timestamp
        )
    }

    static var elapsed: Int {
        max(
            defaults?.integer(
                forKey: elapsedSeconds
            ) ?? 0,
            0
        )
    }

    static var distance: Int {
        max(
            defaults?.integer(
                forKey: distanceMeters
            ) ?? 0,
            0
        )
    }

    static var incidentCount: Int {
        max(
            defaults?.integer(
                forKey: incidents
            ) ?? 0,
            0
        )
    }

    // MARK: - Write Recording State

    static func setRecording(
        _ recording: Bool,
        startDate: Date?
    ) {
        guard
            let defaults
        else {
            return
        }

        defaults.set(
            recording,
            forKey: self.isRecordingKey
        )

        if recording,
           let startDate
        {
            defaults.set(
                startDate.timeIntervalSince1970,
                forKey: self.startDate
            )
        } else {
            defaults.removeObject(
                forKey: self.startDate
            )
        }

        if !recording {
            defaults.set(
                0,
                forKey: elapsedSeconds
            )

            defaults.set(
                0,
                forKey: distanceMeters
            )

            defaults.set(
                0,
                forKey: incidents
            )
        }
    }

    // MARK: - Write Metrics

    static func setMetrics(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) {
        guard
            let defaults
        else {
            return
        }

        defaults.set(
            max(elapsedSeconds, 0),
            forKey: self.elapsedSeconds
        )

        defaults.set(
            max(distanceMeters, 0),
            forKey: self.distanceMeters
        )

        defaults.set(
            max(incidents, 0),
            forKey: self.incidents
        )
    }
}
