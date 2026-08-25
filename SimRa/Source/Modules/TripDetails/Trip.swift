//
//  Trip.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - Swift Wrapper for Objective-C Trip Class
// This class wraps the Objective-C Trip class to make it ObservableObject for SwiftUI
// It should be in a Swift-specific module that can access the Objective-C classes

@objc
public final class TRIPWrapper: NSObject, ObservableObject {
    
    // MARK: - Internal Objective-C Trip Instance
    private var _objcTrip: Trip?
    
    // MARK: - Published Properties (Swift API for SwiftUI)
    // These map directly to the properties in the Objective-C Trip class
    
    @Published public var bikeTypeId: Int = 0
    @Published public var positionId: Int = 0
    @Published public var childseat: Bool = false
    @Published public var trailer: Bool = false
    @Published public var edited: Bool = false
    @Published public var uploaded: Bool = false
    @Published public var statisticsAdded: Bool = false
    @Published public var reUploaded: Bool = false
    @Published public var identifier: Int = 0
    
    @Published public var tripLocations: [TripLocation] = []
    
    // Additional properties that may be accessed elsewhere
    @Published public var startLocation: CLLocation?
    @Published public var lastLocation: CLLocation?
    @Published public var lastTripMotion: TripMotion?
    
    // MARK: - Initialization
    
    public convenience init() {
        self.initFromStorage(identifier: 0)
    }
    
    public convenience init(identifier: Int = 0) {
        self.initFromStorage(identifier: identifier)
    }
    
    public convenience init(trip: Trip) {
        self._objcTrip = trip
        // Map properties from ObjC Trip
        bikeTypeId = trip.bikeTypeId
        positionId = trip.positionId
        childseat = trip.childseat
        trailer = trip.trailer
        edited = trip.edited
        uploaded = trip.uploaded
        identifier = trip.identifier
        statisticsAdded = trip.statisticsAdded
        reUploaded = trip.reUploaded
        tripLocations = trip.tripLocations as? [TripLocation] ?? []
        startLocation = trip.startLocation
        lastLocation = trip.lastLocation
        lastTripMotion = trip.lastTripMotion
    }
    
    // MARK: - Static Factory Methods
    
    public static func fromStorage(identifier: Int) -> TRIPWrapper? {
        guard let objCTrip = Trip.initFromStorage(identifier: identifier) else {
            return nil
        }
        let wrapper = TRIPWrapper()
        wrapper._objcTrip = objCTrip
        wrapper.syncFromObjCTrip()
        return wrapper
    }
    
    // MARK: - Sync from Internal ObjC Trip
    
    private func syncFromObjCTrip() {
        guard let objCTrip = _objcTrip else { return }
        
        bikeTypeId = objCTrip.bikeTypeId
        positionId = objCTrip.positionId
        childseat = objCTrip.childseat
        trailer = objCTrip.trailer
        edited = objCTrip.edited
        uploaded = objCTrip.uploaded
        identifier = objCTrip.identifier
        statisticsAdded = objCTrip.statisticsAdded
        reUploaded = objCTrip.reUploaded
        tripLocations = objCTrip.tripLocations as? [TripLocation] ?? []
        startLocation = objCTrip.startLocation
        lastLocation = objCTrip.lastLocation
        lastTripMotion = objCTrip.lastTripMotion
    }
    
    // MARK: - Action Methods (forwarded to ObjC Trip)
    
    @objc
    public func save() {
        _objcTrip?.save()
    }
    
    @objc
    public func startRecording() {
        _objcTrip?.startRecording()
    }
    
    @objc
    public func stopRecording() {
        _objcTrip?.stopRecording()
    }
    
    @objc
    public func successfullyReUploaded() {
        _objcTrip?.successfullyReUploaded()
    }
    
    @objc
    public var tripInfo: TripInfo {
        return _objcTrip?.tripInfo ?? TripInfo()
    }
    
    @objc
    public var length: Int {
        return _objcTrip?.length ?? 0
    }
    
    @objc
    public var idle: Int {
        return _objcTrip?.idle ?? 0
    }
    
    @objc
    public var numberOfScary: Int {
        return _objcTrip?.numberOfScary ?? 0
    }
    
    @objc
    public var tripAnnotations: Int {
        return _objcTrip?.tripAnnotations ?? 0
    }
    
    @objc
    public var tripValidAnnotations: Int {
        return _objcTrip?.tripValidAnnotations ?? 0
    }
    
    @objc
    public var duration: NSDateInterval? {
        get {
            return _objcTrip?.duration
        }
    }
    
    @objc
    public var csvFile: NSURL? {
        return _objcTrip?.csvFile
    }
    
    @objc
    public var gpxFile: NSURL? {
        get {
            return _objcTrip?.gpxFile
        }
        set {
            _objcTrip?.gpxFile = newValue
        }
    }
    
    @objc
    public var geoJSONFile: NSURL? {
        get {
            return _objcTrip?.geoJSONFile
        }
        set {
            _objcTrip?.geoJSONFile = newValue
        }
    }
    
    @objc
    public var kmlFile: NSURL? {
        get {
            return _objcTrip?.kmlFile
        }
        set {
            _objcTrip?.kmlFile = newValue
        }
    }
}
