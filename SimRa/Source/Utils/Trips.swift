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
final class Trips: NSObject, ObservableObject {
    
    static let shared = Trips()
    
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
        let trips = Trips.shared
        return trips.uploaded
    }
    
    @objc static var version: Int {
        let trips = Trips.shared
        return trips.version
    }
    
    @objc static var fileHash: String {
        let trips = Trips.shared
        return trips.fileHash
    }
    
    @objc static var filePasswd: String {
        let trips = Trips.shared
        return trips.filePasswd
    }
    
    @objc static var tripInfos: [Int: TripInfo] {
        let trips = Trips.shared
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
        var totalRides = UserDefaults.standard.integer(forKey: "totalRides")
        var totalDuration = UserDefaults.standard.integer(forKey: "totalDuration")
        var totalIncidents = UserDefaults.standard.integer(forKey: "totalIncidents")
        var totalLength = UserDefaults.standard.integer(forKey: "totalLength")
        var totalIdle = UserDefaults.standard.integer(forKey: "totalIdle")
        var numberOfScary = UserDefaults.standard.integer(forKey: "numberOfScary")
        
        totalRides += 1
        totalDuration += trip.duration
        totalIncidents += trip.numberOfScary
        totalLength += trip.length
        totalIdle += trip.idle
        
        UserDefaults.standard.set(totalRides, forKey: "totalRides")
        UserDefaults.standard.set(totalDuration, forKey: "totalDuration")
        UserDefaults.standard.set(totalIncidents, forKey: "totalIncidents")
        UserDefaults.standard.set(totalLength, forKey: "totalLength")
        UserDefaults.standard.set(totalIdle, forKey: "totalIdle")
        UserDefaults.standard.set(numberOfScary, forKey: "numberOfScary")
    }
}
