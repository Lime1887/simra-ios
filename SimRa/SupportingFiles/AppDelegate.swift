//
//  AppDelegate.swift
//  SimRa
//
//  SwiftUI entry-point delegate that bridges the legacy ObjC model layer.
//

import SwiftUI
import UIKit
import CoreLocation
import CoreMotion

@MainActor
@objcMembers
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static weak var sharedInstance: AppDelegate?

    let defaults: UserDefaults
    let lm: CLLocationManager
    let mm: CMMotionManager
    let trips: Trips
    let constants: [String: Any]
    let regions: Regions
    let news: News

    override init() {
        self.defaults = .standard
        self.lm = CLLocationManager()
        self.mm = CMMotionManager()
        self.trips = Trips()
        self.constants = [
            "bikeTypes": ["Sport", "Comfort", "City"],
            "positions": ["0", "1", "2"],
            "incidents": ["", "car", "taxi", "delivery", "bus", "commercial", "pedestrian", "bike", "motorcycle", "other"]
        ]
        self.regions = Regions()
        self.news = News()
        super.init()
        Self.sharedInstance = self
    }

    @objc(sharedDelegate)
    class func shared() -> AppDelegate {
        if let sharedInstance {
            return sharedInstance
        }
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            sharedInstance = delegate
            return delegate
        }
        let delegate = AppDelegate()
        sharedInstance = delegate
        return delegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Utility.createSimraPrefs()
        Utility.createAppsPrefs()
        Utility.createProfilePrefs()
        Utility.createKeyPrefs()

        print(defaults.dictionaryRepresentation())
        print("Path to user preference file: \(Utility.getDocumentDirectory() ?? "")")

        lm.requestWhenInUseAuthorization()
        trips.save()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        lm.requestWhenInUseAuthorization()
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard url.scheme == "simra" else { return false }

        if url.host == "recording" {
            if url.path == "/start" {
                return RecordingShortcutBridge.startRecording()
            }
            if url.path == "/stop" {
                return RecordingShortcutBridge.stopRecording()
            }
        }

        return false
    }

    @objc func openURL(_ dict: [String: String]) {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "de"
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

    @objc class func write(_ version: Int32) {
    }
}
