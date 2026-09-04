//
//  AppDelegate.swift
//  SimRa
//
//  Swift entry-point delegate that bridges the legacy model layer.
//

import SwiftUI
import UIKit
import CoreLocation
import CoreMotion
import ActivityKit
import WidgetKit

@objcMembers
final class AppDelegate: NSObject, UIApplicationDelegate, CLLocationManagerDelegate {
    private enum WidgetStateKey {
        static let suiteName = "group.de.tu-berlin.mcc.simra"
        static let isRecording = "isRecording"
        static let startDate = "startDate"
        static let elapsedSeconds = "elapsedSeconds"
        static let distanceMeters = "distanceMeters"
        static let incidents = "incidents"
    }

    private static weak var sharedInstance: AppDelegate?

    let defaults: UserDefaults
    let lm: CLLocationManager
    let mm: CMMotionManager

    var constants: [String: Any] {
        let appLang = defaults.string(forKey: "appLanguage") ?? "auto"
        var bundle = Bundle.main
        if appLang != "auto",
           let path = Bundle.main.path(forResource: appLang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        }
        if let url = bundle.url(forResource: "constants", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any] {
            return dict
        }
        if let url = Bundle.main.url(forResource: "constants", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any] {
            return dict
        }
        return [:]
    }

    var trips: Trips!
    private(set) var activeTrip: Trip?
    private var recordingActivity:
        Activity<SimRaRecordingAttributes>?

    private var metricsTimer: Timer?

    private var lastWidgetReload:
        Date?
    private(set) var recoveryInProgress: Bool = false

    // Lazy loaded components
    private var _regions: Regions?
    private var _news: News?

    var regions: Regions {
        if let regions = _regions {
            return regions
        }
        let regions = Regions()
        _regions = regions
        return regions
    }

    var news: News {
        if let news = _news {
            return news
        }
        let news = News()
        _news = news
        return news
    }

    override init() {
        self.defaults = .standard
        self.lm = CLLocationManager()
        self.mm = CMMotionManager()
        super.init()
        Self.sharedInstance = self
        self.trips = Trips(appDelegate: self)
        registerRecordingObservers()
        restoreActiveRecording()
    }

    private func restoreActiveRecording() {
        let sharedDefaults = UserDefaults(
            suiteName: WidgetStateKey.suiteName
        )

        guard sharedDefaults?.bool(forKey: WidgetStateKey.isRecording) == true,
              let trip = Trip.loadIncompleteTrip(),
              let startDate = trip.recordingStartDate
        else {
            return
        }

        activeTrip = trip
        trip.resumeRecording(from: startDate)
        startRecordingActivity(for: trip, startDate: startDate)
        startMetricsTimer()
    }

    @objc(sharedDelegate)
    class func shared() -> AppDelegate {

        if let sharedInstance {
            return sharedInstance
        }

        guard
            let delegate =
                UIApplication.shared.delegate
                as? AppDelegate
        else {
            fatalError(
                "AppDelegate is not initialized."
            )
        }

        sharedInstance = delegate

        return delegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Utility.createSimraPrefs()
            Utility.createAppsPrefs()
            Utility.createProfilePrefs()
            Utility.createKeyPrefs()
            self?.trips.save()
        }

        lm.requestWhenInUseAuthorization()
        startTripRecovery()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        lm.requestWhenInUseAuthorization()
        processPendingLiveActivityIncidents()
    }

    private func processPendingLiveActivityIncidents() {
        let key = "pendingLiveActivityIncidents"
        let pending = defaultsForWidget.integer(forKey: key)

        guard pending > 0,
              activeTrip != nil
        else {
            return
        }

        defaultsForWidget.set(0, forKey: key)

        for _ in 0..<pending {
            _ = RecordingShortcutBridge.markIncident(
                0,
                source: "Live Activity"
            )
        }
    }

    private var defaultsForWidget: UserDefaults {
        UserDefaults(
            suiteName: WidgetStateKey.suiteName
        ) ?? .standard
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard url.scheme == "simra" else { return false }

        if url.host == "recording" {
            if url.path == "/start" {
                return startRecordingRequested()
            }
            if url.path == "/stop" {
                return stopRecordingRequested()
            }
        }

        if url.host == "incident" {
            if url.path == "/mark" || url.path == "/report" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let typeStr = components?.queryItems?.first(where: { $0.name == "type" })?.value ?? "0"
                let incidentType = Int(typeStr) ?? 0
                return RecordingShortcutBridge.markIncident(incidentType, source: "Live Activity")
            }
        }

        return false
    }

    @objc func openURL(_ dict: [String: String]) {
        let appLang = defaults.string(forKey: "appLanguage") ?? "auto"
        let languageCode: String
        if appLang == "auto" {
            languageCode = Locale.current.language.languageCode?.identifier ?? "de"
        } else {
            languageCode = appLang
        }
        let urlString = dict[languageCode] ?? dict["de"] ?? dict["en"]
        guard let urlString, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @objc func showHowTo() {
        openURL([
            "en": "https://simra-backend.3s-rg.de:4998/SimRa_Instructions_IOS.pdf",
            "de": "https://simra-backend.3s-rg.de:4998/SimRa_Anleitung_IOS.pdf"
        ])
    }

    @objc
    func startRecordingRequested() -> Bool {

        guard activeTrip == nil else {
            return false
        }

        let trip = trips.newTrip()

        activeTrip = trip

        trip.startRecording()

        let startDate =
            trip.recordingStartDate ?? Date()

        startRecordingActivity(
            for: trip,
            startDate: startDate
        )

        updateWidgetState(
            isRecording: true,
            startDate: startDate
        )

        startMetricsTimer()

        notifyRecordingStateChanged()

        return true
    }

    @objc
    func stopRecordingRequested() -> Bool {

        guard
            let trip = activeTrip
        else {
            return false
        }

        let elapsedSeconds: Int

        if let startDate =
            trip.recordingStartDate
        {
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
                trip.length(),
                0
            )

        let incidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        activeTrip = nil

        trip.stopRecording()

        stopRecordingActivity(
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents
        )

        updateWidgetState(
            isRecording: false,
            startDate: nil,
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            incidents: incidents
        )

        stopMetricsTimer()

        notifyRecordingStateChanged()

        return true
    }

    @objc class func write(_ version: Int32) {
    }

    private func startTripRecovery() {
        guard !recoveryInProgress else { return }
        recoveryInProgress = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            Trip.recoverIncompleteTrips()
            DispatchQueue.main.async {
                self?.recoveryInProgress = false
            }
        }
    }
    
    private func startMetricsTimer() {

        metricsTimer?.invalidate()

        updateRecordingMetrics()

        metricsTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    5.0,
                repeats:
                    true
            ) { [weak self] _ in

                guard let self else {
                    return
                }

                self.updateRecordingMetrics()
            }
    }

    private func stopMetricsTimer() {

        metricsTimer?.invalidate()
        metricsTimer = nil
        lastWidgetReload = nil
    }

    private func updateRecordingMetrics() {

        guard
            let trip = activeTrip,
            let startDate =
                trip.recordingStartDate
        else {
            return
        }

        let elapsedSeconds =
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

        let distanceMeters =
            max(
                trip.length(),
                0
            )

        let incidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        SimRaWidgetState.setMetrics(
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents
        )

        updateRecordingActivity(
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents
        )

        // Regular widget needs only occasional
        // timeline refreshes for distance/incidents.
        if let lastWidgetReload {

            if Date()
                .timeIntervalSince(
                    lastWidgetReload
                ) >= 30 {

                WidgetCenter.shared
                    .reloadAllTimelines()

                self.lastWidgetReload =
                    Date()
            }

        } else {

            WidgetCenter.shared
                .reloadAllTimelines()

            lastWidgetReload =
                Date()
        }
    }

    private func registerRecordingObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartRecordingShortcut(_:)),
            name: .startRecordingFromShortcut,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopRecordingShortcut(_:)),
            name: .stopRecordingFromShortcut,
            object: nil
        )
    }

    @objc private func handleStartRecordingShortcut(_ notification: Notification) {
        _ = startRecordingRequested()
    }

    @objc private func handleStopRecordingShortcut(_ notification: Notification) {
        _ = stopRecordingRequested()
    }

    private func notifyRecordingStateChanged() {
        NotificationCenter.default.post(
            name: .recordingSessionDidChange,
            object: self
        )
    }

    private func updateWidgetState(
        isRecording: Bool,
        startDate: Date?,
        elapsedSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        incidents: Int? = nil
    ) {

        guard
            let defaults =
                UserDefaults(
                    suiteName:
                        WidgetStateKey.suiteName
                )
        else {
            assertionFailure(
                "SimRa App Group is unavailable."
            )
            return
        }

        defaults.set(
            isRecording,
            forKey:
                WidgetStateKey.isRecording
        )

        if let startDate,
           isRecording
        {
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

        if !isRecording {

            defaults.set(
                elapsedSeconds ?? 0,
                forKey:
                    WidgetStateKey.elapsedSeconds
            )

            defaults.set(
                distanceMeters ?? 0,
                forKey:
                    WidgetStateKey.distanceMeters
            )

            defaults.set(
                incidents ?? 0,
                forKey:
                    WidgetStateKey.incidents
            )
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "SimRaRecordingWidget")
    }

    private func startRecordingActivity(
        for trip: Trip,
        startDate: Date
    ) {

        guard
            #available(iOS 16.2, *)
        else {
            return
        }

        guard
            ActivityAuthorizationInfo()
                .areActivitiesEnabled
        else {
            return
        }

        if let existing =
            Activity<
                SimRaRecordingAttributes
            >.activities.first {

            recordingActivity =
                existing

            return
        }

        let attributes =
            SimRaRecordingAttributes(
                tripId:
                    trip.identifier,
                bikeTypeId:
                    trip.bikeTypeId,
                startDate:
                    startDate
            )

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds: 0,
                distanceMeters: 0,
                incidents: 0
            )

        let content =
            ActivityContent(
                state:
                    state,
                staleDate:
                    startDate.addingTimeInterval(
                        12 * 60 * 60
                    )
            )

        do {

            recordingActivity =
                try Activity.request(
                    attributes:
                        attributes,
                    content:
                        content,
                    pushType:
                        nil
                )

        } catch {

            recordingActivity =
                nil

            print(
                "[SimRa] Could not start Live Activity: \(error)"
            )
        }
    }

    private func stopRecordingActivity(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) {

        guard
            #available(iOS 16.2, *)
        else {
            return
        }

        let activity =
            recordingActivity
            ?? Activity<
                SimRaRecordingAttributes
            >.activities.first

        guard
            let activity
        else {
            return
        }

        let content =
            ActivityContent(
                state:
                    SimRaRecordingAttributes.ContentState(
                        elapsedSeconds:
                            max(
                                elapsedSeconds,
                                0
                            ),
                        distanceMeters:
                            max(
                                distanceMeters,
                                0
                            ),
                        incidents:
                            max(
                                incidents,
                                0
                            )
                    ),
                staleDate:
                    nil
            )

        Task {

            await activity.end(
                content,
                dismissalPolicy:
                    .immediate
            )
        }

        recordingActivity =
            nil
    }

    private func updateRecordingActivity(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) {

        guard
            #available(iOS 16.2, *)
        else {
            return
        }

        let activity =
            recordingActivity
            ?? Activity<
                SimRaRecordingAttributes
            >.activities.first

        guard
            let activity
        else {
            return
        }

        recordingActivity =
            activity

        let content =
            ActivityContent(
                state:
                    SimRaRecordingAttributes.ContentState(
                        elapsedSeconds:
                            max(
                                elapsedSeconds,
                                0
                            ),
                        distanceMeters:
                            max(
                                distanceMeters,
                                0
                            ),
                        incidents:
                            max(
                                incidents,
                                0
                            )
                    ),
                staleDate:
                    Date().addingTimeInterval(
                        60
                    )
            )

        Task {

            await activity.update(
                content
            )
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        activeTrip?.locationManager(manager, didUpdateLocations: locations)
    }
}

public extension Notification.Name {
    static let recordingSessionDidChange = Notification.Name("recordingSessionDidChangeNotification")
}
