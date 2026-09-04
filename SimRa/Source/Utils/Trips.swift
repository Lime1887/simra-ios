//
//  Trips.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

enum TripsError: Error {
    case invalidState
    case notFound
}

@MainActor
final class TripsManager: NSObject, ObservableObject {
    
    static let shared = TripsManager()
    
    private let userDefaults = UserDefaults.standard
    private let tripsDict: [Int: Trip] = []
    
    // MARK: - Published Properties
    
    @Published private(set) var uploaded = false
    @Published private(set) var version: Int = 1
    @Published private(set) var fileHash: String = ""
    @Published private(set) var filePasswd: String = ""
    @Published private(set) var tripInfos: [Int: TripInfo] = [:]
    
    // MARK: - Methods
    
    @objc static var uploaded: Bool {
        let trips = TripsManager.shared
        return trips.uploaded
    }
    
    @objc static var version: Int {
        let trips = TripsManager.shared
        return trips.version
    }
    
    @objc static var fileHash: String {
        let trips = TripsManager.shared
        return trips.fileHash
    }
    
    @objc static var filePasswd: String {
        let trips = TripsManager.shared
        return trips.filePasswd
    }
    
    @objc static var tripInfos: [Int: TripInfo] {
        let trips = TripsManager.shared
        return trips.tripInfos
    }
    
    // MARK: - Save/Upload
    
    @objc func save() {
        // Speichert die Trips als PLIST
        let dict: [String: Any] = [
            "version": version,
            "uploaded": uploaded,
            "fileHash": fileHash,
            "filePasswd": filePasswd
        ]
        Utility.writeToAppPrefs(key: "uploadData", val: dict)
    }
    
    @objc func upload(name: String) {
        // Upload Implementation
    }
    
    @objc func updateTrip(_ trip: Trip) {
        tripInfos[trip.identifier] = trip.tripInfo
    }
    
    @objc func addTripToStatistics(_ trip: Trip, regionId: Int) {
        // Berechne Statistiken aus allen Trips (auch ungeladene)
        recalculateAllStatistics()
    }
    
    // MARK: - Statistics Calculation
    
    /// Recalculate all statistics from trips
    @objc func recalculateAllStatistics() {
        var totalRides = 0
        var totalDuration: TimeInterval = 0
        var totalIncidents = 0
        var totalLength = 0
        var totalIdle = 0
        var numberOfScary = 0
        var totalSlots = Array(repeating: 0, count: 24)
        
        // Berechne aus allen Trips
        for tripInfo in tripInfos.values {
            totalRides += 1
            totalIncidents += tripInfo.annotationsCount
            numberOfScary += tripInfo.validAnnotationsCount
        }
        
        // Speichere Statistiken
        UserDefaults.standard.set(totalRides, forKey: "totalRides")
        UserDefaults.standard.set(Int(totalDuration), forKey: "totalDuration")
        UserDefaults.standard.set(totalIncidents, forKey: "totalIncidents")
        UserDefaults.standard.set(totalLength, forKey: "totalLength")
        UserDefaults.standard.set(totalIdle, forKey: "totalIdle")
        UserDefaults.standard.set(numberOfScary, forKey: "numberOfScary")
        UserDefaults.standard.set(totalSlots, forKey: "totalSlots")
    }
    
    /// Get statistics including unuploaded trips
    @objc func getStatistics() -> [String: Any] {
        return [
            "totalRides": UserDefaults.standard.integer(forKey: "totalRides"),
            "totalDuration": UserDefaults.standard.integer(forKey: "totalDuration"),
            "totalIncidents": UserDefaults.standard.integer(forKey: "totalIncidents"),
            "totalLength": UserDefaults.standard.integer(forKey: "totalLength"),
            "totalIdle": UserDefaults.standard.integer(forKey: "totalIdle"),
            "numberOfScary": UserDefaults.standard.integer(forKey: "numberOfScary"),
            "totalSlots": UserDefaults.standard.array(forKey: "totalSlots") ?? Array(repeating: 0, count: 24)
        ]
    }
}

