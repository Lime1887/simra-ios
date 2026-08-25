//
//  MainViewModel.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import MapKit

@MainActor
final class MainViewModel: ObservableObject {
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var isRecording = false
    @Published var recordingStatusText: String? = nil
    @Published var navigateToTrips = false
    @Published var showOpenBikeSensorButton = false
    @Published var showOBSConfig = false

    // Alerts
    @Published var showHowToAlert = false
    @Published var showRegionAlert = false
    @Published var regionAlertMessage = ""

    @Published var recordingRouteOverlay: MKPolyline? = nil

    private let appDelegate = AppDelegate.shared()
    private var timer: Timer?
    private var recordingStartedAt: Date?
    private var lastKnownRecordingState = false
    private var recordingStateObserver: NSObjectProtocol?

    init() {
        checkInitialMessages()
        setupBluetooth()
        syncRecordingState()

        recordingStateObserver = NotificationCenter.default.addObserver(
            forName: .recordingSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncRecordingState()
        }
    }

    deinit {
        if let recordingStateObserver {
            NotificationCenter.default.removeObserver(recordingStateObserver)
        }
    }

    func toggleRecording() {
        if isRecording {
            _ = appDelegate.stopRecordingRequested()
        } else {
            _ = appDelegate.startRecordingRequested()
        }
        syncRecordingState()
    }

    private func syncRecordingState() {
        let currentlyRecording = appDelegate.activeTrip != nil
        recordingStartedAt = appDelegate.activeTrip?.recordingStartDate
        isRecording = currentlyRecording

        if currentlyRecording {
            if timer == nil {
                startTimer()
            }
        } else {
            stopTimer()
            if lastKnownRecordingState {
                navigateToTrips = true
            }
        }

        updateStatusText()
        updateRouteOverlay()
        lastKnownRecordingState = currentlyRecording
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusText()
            self?.updateRouteOverlay()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingStatusText = nil
    }

    private func updateStatusText() {
        guard let start = recordingStartedAt else {
            recordingStatusText = nil
            return
        }

        let elapsed = Date().timeIntervalSince(start)
        recordingStatusText = String(format: "%.0f s", elapsed)
    }

    private func updateRouteOverlay() {
        guard let trip = appDelegate.activeTrip,
              let locations = trip.tripLocations as? [TripLocation],
              locations.count > 1 else {
            recordingRouteOverlay = nil
            return
        }

        let coordinates = locations.map { $0.location.coordinate }
        recordingRouteOverlay = MKPolyline(
            coordinates: coordinates,
            count: coordinates.count
        )
    }

    private func setupBluetooth() {
        showOpenBikeSensorButton = UserDefaults.standard.bool(forKey: "openBikeSensor")
    }

    func openOBSConfig() {
        showOBSConfig = true
    }

    private func checkInitialMessages() {
        if !UserDefaults.standard.bool(forKey: "initialMessage") {
            showHowToAlert = true
        }
    }

    func confirmHowTo() {
        UserDefaults.standard.set(true, forKey: "initialMessage")
    }

    func skipHowTo() {
        UserDefaults.standard.set(true, forKey: "initialMessage")
    }

    func suppressRegionMessage() {
        UserDefaults.standard.set(true, forKey: "suppressRegionMessage")
    }

    func openRegionSettings() {
        // Placeholder for the region-selection flow; no native SwiftUI view exists yet.
    }
}
