//
//  Trip.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

@MainActor
final class Trip: NSObject, ObservableObject {
    
    @objc
    private(set) var identifier: Int
    @objc
    private(set) var uploaded = false
    @objc
    private(set) var edited = false
    @objc
    private(set) var AIVersion: Int = 0
    @objc
    private(set) var deferredSecs: Int = 0
    @objc
    private(set) var deferredMeters: Int = 0
    @objc
    private(set) var bikeTypeId: Int = 0
    @objc
    private(set) var positionId: Int = 0
    @objc
    private(set) var childseat: Bool = false
    @objc
    private(set) var trailer: Bool = false
    @objc
    private(set) var tripLocations: [TripLocation] = []
    @objc
    private(set) var tripAnnotation: TripAnnotation?
    
    private var tripInfo: TripInfo?
    
    init(identifier: Int) {
        self.identifier = identifier
    }
    
    init(fromDict dict: [String: Any]) {
        self.identifier = dict["identifier"] as? Int ?? 0
        self.uploaded = dict["uploaded"] as? Bool ?? false
        self.edited = dict["edited"] as? Bool ?? false
        self.AIVersion = dict["AIVersion"] as? Int ?? 0
        self.deferredSecs = dict["deferredSecs"] as? Int ?? 0
        self.deferredMeters = dict["deferredMeters"] as? Int ?? 0
        self.bikeTypeId = dict["bikeTypeId"] as? Int ?? 0
        self.positionId = dict["positionId"] as? Int ?? 0
        self.childseat = dict["childseat"] as? Bool ?? false
        self.trailer = dict["trailer"] as? Bool ?? false
    }
    
    @objc static func generate() -> Int {
        let existingTrips = Trips.shared.tripInfos
        return existingTrips.keys.max() ?? 0 + 1
    }
    
    @objc func save() {
        // Speichert die Trip Daten
        let tripInfo = TripInfo(identifier: identifier)
        tripInfo.version = AIVersion
        tripInfo.edited = edited
        tripInfo.uploaded = uploaded
        tripInfo.AIVersion = AIVersion
        tripInfo.deferredSecs = deferredSecs
        tripInfo.deferredMeters = deferredMeters
        tripInfo.bikeTypeId = bikeTypeId
        tripInfo.positionId = positionId
        tripInfo.childseat = childseat
        tripInfo.trailer = trailer
        
        tripInfo.annotationsCount = tripLocations.filter { $0.tripAnnotation != nil }.count
        tripInfo.validAnnotationsCount = tripLocations.filter { $0.tripAnnotation?.incidentId ?? 0 > 0 }.count
        
        // Speichere zu UserDefaults
        let dict: [String: Any] = [
            "identifier": identifier,
            "version": AIVersion,
            "edited": edited,
            "uploaded": uploaded,
            "AIVersion": AIVersion,
            "deferredSecs": deferredSecs,
            "deferredMeters": deferredMeters,
            "bikeTypeId": bikeTypeId,
            "positionId": positionId,
            "childseat": childseat,
            "trailer": trailer,
            "totalRides": UserDefaults.standard.integer(forKey: "totalRides"),
            "totalDuration": UserDefaults.standard.integer(forKey: "totalDuration"),
            "totalIncidents": UserDefaults.standard.integer(forKey: "totalIncidents"),
            "totalLength": UserDefaults.standard.integer(forKey: "totalLength"),
            "totalIdle": UserDefaults.standard.integer(forKey: "totalIdle"),
            "numberOfScary": UserDefaults.standard.integer(forKey: "numberOfScary"),
            "totalSlots": UserDefaults.standard.array(forKey: "totalSlots")
        ]
        
        Trips.shared.tripInfos[identifier] = tripInfo
    }
    
    @objc func load() {
        // Lädt Trip Daten aus UserDefaults
    }
}
