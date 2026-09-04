//
//  MainViewModel.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import MapKit
import WidgetKit

// MARK: - Recording Incident

struct RecordingIncident: Identifiable {

    let id: String
    let coordinate: CLLocationCoordinate2D
    let source: String

    var isQuickRecorded: Bool {
        source != "Manual"
    }
}

// MARK: - Main View Model

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - Widget State

    private enum WidgetStateKey {

        static let suiteName =
            "group.de.tu-berlin.mcc.simra"

        static let recording =
            "isRecording"

        static let startDate =
            "startDate"

        static let elapsedSeconds =
            "elapsedSeconds"

        static let distanceMeters =
            "distanceMeters"

        static let incidents =
            "incidents"

        static let routeCoordinates =
            "widgetRouteCoordinates"

        static let tripStatistics =
            "widgetTripStatistics"
    }

    private struct WidgetCoordinate: Codable {

        let latitude: Double
        let longitude: Double
    }

    private struct WidgetTripStatistic: Codable {

        let date: Date
        let distanceMeters: Double
    }

    // MARK: - Map

    @Published var cameraPosition:
        MapCameraPosition = .userLocation(
            fallback: .automatic
        )

    // MARK: - Recording

    @Published private(set)
    var isRecording = false

    @Published private(set)
    var recordingTransitionInProgress = false

    @Published
    var recordingStatusText: String?

    @Published
    var recordingRouteOverlay: MKPolyline?

    @Published private(set)
    var recordingIncidents:
        [RecordingIncident] = []

    // MARK: - Navigation

    @Published
    var navigateToTrips = false

    // MARK: - Bike Sensor

    @Published
    var showOpenBikeSensorButton = false

    @Published
    var showOBSConfig = false

    // MARK: - Hazard Map

    @Published
    var showHazardMap = false

    // MARK: - Alerts

    @Published
    var showHowToAlert = false

    @Published
    var showRegionAlert = false

    @Published
    var regionAlertMessage = ""

    // MARK: - Dependencies

    private let appDelegate =
        AppDelegate.shared()

    // MARK: - Recording Runtime

    private var timer: Timer?

    private var recordingStartedAt: Date?

    private var lastKnownRecordingState = false

    private var pendingRecordingTarget: Bool?

    // MARK: - Notifications

    private var recordingStateObserver:
        NSObjectProtocol?

    private var incidentObserver:
        NSObjectProtocol?

    // MARK: - Route Cache

    private var lastOverlayPointCount = 0

    private var lastRouteUpdateDate:
        Date?

    // MARK: - Metrics Cache

    private var cachedDistanceMeters = 0

    private var cachedIncidents = 0

    private var lastMetricsPointCount = 0

    private var lastMetricsUpdate:
        Date?

    private var isComputingMetrics = false

    // MARK: - Widget Cache

    private var lastWidgetRoutePointCount = -1

    private var lastWidgetTimelineReload:
        Date?

    private var lastWidgetSyncDate:
        Date?

    private var widgetStatisticsRefreshScheduled =
        false

    // MARK: - Init

    init() {

        checkInitialMessages()
        setupBluetooth()
        setupObservers()

        // Wichtig:
        // Beim App-Start NICHT die komplette
        // historische Widget-Statistik neu berechnen.
        syncRecordingState(
            refreshHistoricalStatistics: false
        )
    }

    deinit {

        if let observer =
            recordingStateObserver {

            NotificationCenter.default
                .removeObserver(
                    observer
                )
        }

        if let observer =
            incidentObserver {

            NotificationCenter.default
                .removeObserver(
                    observer
                )
        }

        timer?.invalidate()
    }

    // MARK: - Notification Setup

    private func setupObservers() {

        recordingStateObserver =
            NotificationCenter.default.addObserver(
                forName:
                    .recordingSessionDidChange,
                object:
                    nil,
                queue:
                    .main
            ) { [weak self] _ in

                Task { @MainActor in
                    self?.syncRecordingState()
                }
            }

        incidentObserver =
            NotificationCenter.default.addObserver(
                forName:
                    .incidentMarked,
                object:
                    nil,
                queue:
                    .main
            ) { [weak self] _ in

                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    self.updateRouteOverlay(
                        force: true
                    )

                    self.synchronizeWidgetState(
                        reload: true
                    )
                }
            }
    }

    // MARK: - Recording

    func toggleRecording() {

        guard
            !recordingTransitionInProgress
        else {
            return
        }

        let targetState =
            !isRecording

        recordingTransitionInProgress =
            true

        pendingRecordingTarget =
            targetState

        if targetState {

            // Nur den eigentlichen Request absetzen.
            // Keine nachgelagerte Berechnung hier.
            _ =
                appDelegate
                .startRecordingRequested()

        } else {

            // Nur den eigentlichen Request absetzen.
            _ =
                appDelegate
                .stopRecordingRequested()
        }

        // Der tatsächliche Zustand wird über
        // recordingSessionDidChange synchronisiert.
    }

    // MARK: - Incident

    func markIncident() {

        guard isRecording else {
            return
        }

        _ =
            RecordingShortcutBridge
            .markIncident(
                0,
                source: "Button"
            )

        // Keine teure Arbeit im Button-Call.
        // Die Notification sorgt für die Aktualisierung.
    }

    // MARK: - Recording State

    private func syncRecordingState(
        refreshHistoricalStatistics:
            Bool = false
    ) {

        let activeTrip =
            appDelegate.activeTrip

        let currentlyRecording =
            activeTrip != nil

        let previousState =
            lastKnownRecordingState

        let stateChanged =
            currentlyRecording != previousState

        isRecording =
            currentlyRecording

        recordingStartedAt =
            activeTrip?.recordingStartDate

        if currentlyRecording {

            // Während der Aufnahme darf die Hazard Map
            // nicht offen bleiben.
            if showHazardMap {
                showHazardMap = false
            }

            if timer == nil {
                startTimer()
            }

            updateStatusText()

            updateRouteOverlay(
                force:
                    stateChanged
            )

            synchronizeWidgetState(
                reload:
                    stateChanged
            )

        } else {

            // Aufnahme beendet.
            stopTimer()

            recordingStatusText = nil
            recordingStartedAt = nil

            recordingRouteOverlay = nil
            recordingIncidents = []

            lastOverlayPointCount = 0
            lastRouteUpdateDate = nil

            lastMetricsPointCount = 0
            lastMetricsUpdate = nil
            isComputingMetrics = false

            lastWidgetRoutePointCount = -1
            lastWidgetSyncDate = nil

            /*
             WICHTIG:

             Die historischen Widget-Statistiken werden
             nicht synchron im Start/Stop-Pfad berechnet.

             Stattdessen werden sie nach dem State-Update
             geplant. Die View kann dadurch zuerst reagieren.
             */
            synchronizeWidgetState(
                reload: true
            )

            if refreshHistoricalStatistics {
                scheduleHistoricalWidgetStatisticsRefresh()
            }
        }

        // Transition erst beenden, wenn der tatsächlich
        // beobachtete Zustand dem angeforderten Zustand entspricht.
        if let pendingTarget =
            pendingRecordingTarget {

            if pendingTarget ==
                currentlyRecording {

                recordingTransitionInProgress =
                    false

                pendingRecordingTarget =
                    nil
            }
        }

        if previousState &&
            !currentlyRecording {

            navigateToTrips = true

            scheduleHistoricalWidgetStatisticsRefresh()
        }

        lastKnownRecordingState =
            currentlyRecording
    }

    // MARK: - Timer

    private func startTimer() {

        timer?.invalidate()

        let timer =
            Timer(
                timeInterval:
                    1.0,
                repeats:
                    true
            ) { [weak self] _ in

                Task { @MainActor in
                    self?.recordingTimerTick()
                }
            }

        self.timer = timer

        RunLoop.main.add(
            timer,
            forMode:
                .common
        )
    }

    private func recordingTimerTick() {

        guard isRecording else {
            return
        }

        // Jede Sekunde nur die sichtbare Zeit aktualisieren.
        updateStatusText()

        let now = Date()

        // Route höchstens ca. alle 2 Sekunden
        // neu aufbauen.
        if shouldUpdateRoute(
            at: now
        ) {
            updateRouteOverlay()
        }

        // Distanz höchstens alle 5 Sekunden
        // neu berechnen.
        if shouldUpdateMetrics(
            at: now
        ) {
            refreshRecordingMetrics()
        }

        // Widget nur selten aktualisieren.
        if shouldSyncWidget(
            at: now
        ) {
            synchronizeWidgetState(
                reload: false
            )
        }
    }

    private func stopTimer() {

        timer?.invalidate()
        timer = nil

        recordingStatusText = nil

        lastOverlayPointCount = 0
        lastRouteUpdateDate = nil

        lastMetricsPointCount = 0
        lastMetricsUpdate = nil

        isComputingMetrics = false

        cachedDistanceMeters = 0
        cachedIncidents = 0
    }

    // MARK: - Status

    private func updateStatusText() {

        guard
            let start =
                recordingStartedAt
        else {

            recordingStatusText = nil
            return
        }

        let elapsed =
            max(
                0,
                Int(
                    Date()
                        .timeIntervalSince(
                            start
                        )
                        .rounded()
                )
            )

        recordingStatusText =
            String(
                format:
                    "%@ · %@",
                formatElapsedTime(
                    elapsed
                ),
                formatDistance(
                    cachedDistanceMeters
                )
            )
    }

    // MARK: - Metrics Scheduling

    private func shouldUpdateMetrics(
        at date: Date
    ) -> Bool {

        guard
            let last =
                lastMetricsUpdate
        else {
            return true
        }

        return date.timeIntervalSince(
            last
        ) >= 5
    }

    private func shouldUpdateRoute(
        at date: Date
    ) -> Bool {

        guard
            let last =
                lastRouteUpdateDate
        else {
            return true
        }

        return date.timeIntervalSince(
            last
        ) >= 2
    }

    private func shouldSyncWidget(
        at date: Date
    ) -> Bool {

        guard
            let last =
                lastWidgetSyncDate
        else {
            return true
        }

        return date.timeIntervalSince(
            last
        ) >= 15
    }

    // MARK: - Recording Metrics

    private func refreshRecordingMetrics() {

        guard
            let trip =
                appDelegate.activeTrip
        else {
            return
        }

        let pointCount =
            trip.tripLocations.count

        guard
            !isComputingMetrics
        else {
            return
        }

        guard
            pointCount != lastMetricsPointCount ||
            shouldUpdateMetrics(
                at: .now
            )
        else {
            return
        }

        isComputingMetrics = true

        // Diese Berechnungen werden bewusst
        // nicht jede Sekunde ausgeführt.
        let distance =
            max(
                trip.length(),
                0
            )

        let incidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        cachedDistanceMeters =
            distance

        cachedIncidents =
            incidents

        lastMetricsPointCount =
            pointCount

        lastMetricsUpdate =
            .now

        isComputingMetrics = false

        updateStatusText()

        // Widget bekommt den neuesten
        // zwischengespeicherten Stand.
        synchronizeWidgetState(
            reload: false
        )
    }

    // MARK: - Route Overlay

    private func updateRouteOverlay(
        force: Bool = false
    ) {

        guard
            let trip =
                appDelegate.activeTrip
        else {

            recordingRouteOverlay = nil
            recordingIncidents = []

            lastOverlayPointCount = 0
            lastRouteUpdateDate = nil

            return
        }

        guard
            let locations =
                (trip.tripLocations as NSArray)
                    as? [TripLocation]
        else {

            recordingRouteOverlay = nil
            recordingIncidents = []

            lastOverlayPointCount = 0
            lastRouteUpdateDate = nil

            return
        }

        let pointCount =
            locations.count

        if !force &&
            pointCount ==
                lastOverlayPointCount {

            lastRouteUpdateDate =
                .now

            return
        }

        let coordinates =
            locations.map {
                $0.location.coordinate
            }

        if coordinates.count >= 2 {

            recordingRouteOverlay =
                MKPolyline(
                    coordinates:
                        coordinates,
                    count:
                        coordinates.count
                )

        } else {

            recordingRouteOverlay = nil
        }

        recordingIncidents =
            locations.compactMap {
                location in

                guard
                    let annotation =
                        location.tripAnnotation
                else {
                    return nil
                }

                let coordinate =
                    location
                        .location
                        .coordinate

                let timestamp =
                    location
                        .location
                        .timestamp
                        .timeIntervalSince1970

                let identifier =
                    String(
                        format:
                            "%.6f:%.6f:%.3f",
                        coordinate.latitude,
                        coordinate.longitude,
                        timestamp
                    )

                return RecordingIncident(
                    id:
                        identifier,
                    coordinate:
                        coordinate,
                    source:
                        annotation.source
                )
            }

        lastOverlayPointCount =
            pointCount

        lastRouteUpdateDate =
            .now
    }

    // MARK: - Widget Synchronization

    private func synchronizeWidgetState(
        reload: Bool
    ) {

        guard
            let defaults =
                UserDefaults(
                    suiteName:
                        WidgetStateKey.suiteName
                )
        else {
            return
        }

        let activeTrip =
            appDelegate.activeTrip

        let recording =
            activeTrip != nil

        let startDate =
            activeTrip?.recordingStartDate

        defaults.set(
            recording,
            forKey:
                WidgetStateKey.recording
        )

        if recording,
           let startDate {

            defaults.set(
                startDate.timeIntervalSince1970,
                forKey:
                    WidgetStateKey.startDate
            )

        } else {

            defaults.removeObject(
                forKey:
                    WidgetStateKey.startDate
            )
        }

        if recording {

            defaults.set(
                currentElapsedSeconds(),
                forKey:
                    WidgetStateKey.elapsedSeconds
            )

            defaults.set(
                Double(
                    max(
                        cachedDistanceMeters,
                        0
                    )
                ),
                forKey:
                    WidgetStateKey.distanceMeters
            )

            defaults.set(
                max(
                    cachedIncidents,
                    0
                ),
                forKey:
                    WidgetStateKey.incidents
            )

        } else {

            defaults.set(
                0,
                forKey:
                    WidgetStateKey.elapsedSeconds
            )

            defaults.set(
                0,
                forKey:
                    WidgetStateKey.distanceMeters
            )

            defaults.set(
                0,
                forKey:
                    WidgetStateKey.incidents
            )
        }

        var routeChanged =
            false

        if recording,
           let activeTrip {

            let locations =
                (activeTrip.tripLocations as NSArray)
                    .compactMap {
                        $0 as? TripLocation
                    }

            let pointCount =
                locations.count

            if pointCount !=
                lastWidgetRoutePointCount {

                let coordinates =
                    locations.map {
                        location in

                        let coordinate =
                            location
                                .location
                                .coordinate

                        return WidgetCoordinate(
                            latitude:
                                coordinate.latitude,
                            longitude:
                                coordinate.longitude
                        )
                    }

                if let data =
                    try? JSONEncoder()
                        .encode(
                            coordinates
                        ) {

                    defaults.set(
                        data,
                        forKey:
                            WidgetStateKey
                                .routeCoordinates
                    )
                }

                lastWidgetRoutePointCount =
                    pointCount

                routeChanged = true
            }

        } else {

            defaults.removeObject(
                forKey:
                    WidgetStateKey
                        .routeCoordinates
            )

            lastWidgetRoutePointCount =
                -1

            routeChanged = true
        }

        lastWidgetSyncDate =
            .now

        // Kein synchronize():
        // UserDefaults schreibt automatisch.
        let shouldReload =
            reload ||
            (
                routeChanged &&
                shouldReloadWidgetTimeline()
            )

        guard shouldReload else {
            return
        }

        WidgetCenter.shared
            .reloadTimelines(
                ofKind:
                    "SimRaRecordingWidget"
            )

        lastWidgetTimelineReload =
            .now

        /*
         Historische Statistik bewusst NICHT hier
         synchron berechnen.

         Das ist genau der Code, der früher den
         Start/Stop-Button blockieren konnte.
         */
    }

    // MARK: - Historical Widget Statistics

    private func scheduleHistoricalWidgetStatisticsRefresh() {

        guard
            !widgetStatisticsRefreshScheduled
        else {
            return
        }

        widgetStatisticsRefreshScheduled =
            true

        Task { @MainActor [weak self] in

            // Erst UI-State und Navigation rendern lassen.
            await Task.yield()

            guard
                let self,
                !Task.isCancelled
            else {
                return
            }

            self.writeWidgetTripStatistics()

            self.widgetStatisticsRefreshScheduled =
                false

            self.reloadWidgetTimeline()
        }
    }

    private func writeWidgetTripStatistics() {

        guard
            let defaults =
                UserDefaults(
                    suiteName:
                        WidgetStateKey.suiteName
                )
        else {
            return
        }

        let cutoff =
            Date.now.addingTimeInterval(
                -35 * 24 * 60 * 60
            )

        let activeIdentifier =
            appDelegate
                .activeTrip?
                .identifier

        var statistics:
            [WidgetTripStatistic] = []

        let identifiers =
            Trip.allStoredIdentifiers()

        statistics.reserveCapacity(
            identifiers.count
        )

        for identifier in identifiers {

            let tripIdentifier =
                identifier.intValue

            if tripIdentifier ==
                activeIdentifier {
                continue
            }

            guard
                let trip =
                    Trip(
                        fromStorage:
                            tripIdentifier
                    )
            else {
                continue
            }

            guard
                let firstLocation =
                    trip.tripLocations
                        .firstObject
                        as? TripLocation
            else {
                continue
            }

            let date =
                firstLocation
                    .location
                    .timestamp

            guard
                date >= cutoff,
                date <= .now,
                trip.tripLocations.count > 1
            else {
                continue
            }

            let distance =
                max(
                    trip.length(),
                    0
                )

            guard
                distance > 0
            else {
                continue
            }

            statistics.append(
                WidgetTripStatistic(
                    date:
                        date,
                    distanceMeters:
                        Double(
                            distance
                        )
                )
            )
        }

        statistics.sort {
            $0.date <
                $1.date
        }

        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        statistics
                    )
        else {
            return
        }

        defaults.set(
            data,
            forKey:
                WidgetStateKey
                    .tripStatistics
        )
    }

    private func reloadWidgetTimeline() {

        WidgetCenter.shared
            .reloadTimelines(
                ofKind:
                    "SimRaRecordingWidget"
            )

        lastWidgetTimelineReload =
            .now
    }

    // MARK: - Widget Helpers

    private func shouldReloadWidgetTimeline()
        -> Bool {

        guard
            let last =
                lastWidgetTimelineReload
        else {
            return true
        }

        return Date()
            .timeIntervalSince(
                last
            ) >= 15
    }

    private func currentElapsedSeconds()
        -> Int {

        guard
            let start =
                recordingStartedAt
        else {
            return 0
        }

        return max(
            0,
            Int(
                Date()
                    .timeIntervalSince(
                        start
                    )
                    .rounded()
            )
        )
    }

    // MARK: - Formatting

    private func formatElapsedTime(
        _ seconds: Int
    ) -> String {

        let safe =
            max(
                seconds,
                0
            )

        let hours =
            safe / 3_600

        let minutes =
            (
                safe %
                3_600
            ) / 60

        let remaining =
            safe % 60

        if hours > 0 {

            return String(
                format:
                    "%d:%02d:%02d",
                hours,
                minutes,
                remaining
            )
        }

        return String(
            format:
                "%02d:%02d",
            minutes,
            remaining
        )
    }

    private func formatDistance(
        _ meters: Int
    ) -> String {

        let safe =
            max(
                meters,
                0
            )

        if safe >= 1_000 {

            return String(
                format:
                    "%.1f km",
                Double(safe) /
                    1_000.0
            )
        }

        return String(
            format:
                "%d m",
            safe
        )
    }

    // MARK: - Bluetooth

    private func setupBluetooth() {

        showOpenBikeSensorButton =
            UserDefaults.standard.bool(
                forKey:
                    "openBikeSensor"
            )
    }

    func openOBSConfig() {

        showOBSConfig =
            true
    }

    // MARK: - Hazard Map

    func toggleHazardMap() {

        guard
            !isRecording
        else {
            return
        }

        showHazardMap.toggle()
    }

    func closeHazardMap() {

        showHazardMap =
            false
    }

    // MARK: - Initial Messages

    private func checkInitialMessages() {

        if !UserDefaults.standard.bool(
            forKey:
                "initialMessage"
        ) {

            showHowToAlert =
                true
        }
    }

    func confirmHowTo() {

        UserDefaults.standard.set(
            true,
            forKey:
                "initialMessage"
        )
    }

    func skipHowTo() {

        UserDefaults.standard.set(
            true,
            forKey:
                "initialMessage"
        )
    }

    func suppressRegionMessage() {

        UserDefaults.standard.set(
            true,
            forKey:
                "suppressRegionMessage"
        )
    }

    func openRegionSettings() {
        // Existing region-selection flow.
    }
}
