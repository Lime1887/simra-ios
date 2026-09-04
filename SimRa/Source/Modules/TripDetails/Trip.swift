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
    
    // FIX: Swift convenience initializer MUST delegate to self.init, not super.init
    public convenience init() {
        self.init()
        self._objcTrip = Trip()
        self.syncFromObjCTrip()
    }
    
    // FIX: Use correct argument label 'identifier' to match ObjC initializer
    public convenience init(identifier: Int) {
        self.init(identifier: identifier)
        let objCTrip = Trip(identifier: identifier)
        if objCTrip != nil {
            self._objcTrip = objCTrip
            self.syncFromObjCTrip()
        }
    }
    
    public convenience init(trip: Trip) {
        self.init()
        self._objcTrip = trip
        self.syncFromObjCTrip()
    }
    
    // MARK: - Static Factory Methods
    
    // FIX: Match ObjC method signature - use identifier: label
    public static func fromStorage(identifier: Int) -> TRIPWrapper? {
        // ObjC initializer: - (instancetype)initFromStorage:(NSInteger)identifier
        let objCTrip = Trip(identifier: identifier)
        if objCTrip != nil {
            let wrapper = TRIPWrapper(trip: objCTrip!)
            return wrapper
        }
        return nil
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
    
    // FIX: tripInfo is a method in ObjC, not a property - keep as computed property
    @objc
    public var tripInfo: TripInfo {
        get {
            if _objcTrip == nil {
                return TripInfo()
            }
            return _objcTrip!.tripInfo
        }
        set {
            // This property is read-only in the Objective-C Trip class
            // The setter does nothing
        }
    }
    
    // FIX: Add 'override' keyword for computed properties
    @objc
    public override var length: Int {
        get {
            if _objcTrip == nil {
                return 0
            }
            return _objcTrip!.length
        }
        set {
            // This property is read-only in the Objective-C Trip class
            // The setter does nothing
        }
    }
    
    @objc
    public override var idle: Int {
        get {
            if _objcTrip == nil {
                return 0
            }
            return _objcTrip!.idle
        }
        set {
            // This property is read-only in the Objective-C Trip class
            // The setter does nothing
        }
    }
    
    @objc
    public override var numberOfScary: Int {
        get {
            if _objcTrip == nil {
                return 0
            }
            return _objcTrip!.numberOfScary
        }
        set {
            // This property is read-only in the Objective-C Trip class
            // The setter does nothing
        }
    }
    
    @objc
    public override var tripAnnotations: Int {
        get {
            if _objcTrip == nil {
                return 0
            }
            return _objcTrip!.tripAnnotations
        }
        set {
            // This property is read-only in the Objective-C Trip class
            // The setter does nothing
        }
    }
    
    @objc
    public override var tripValidAnnotations: Int {
        get {
            if _objcTrip == nil {
                return 0
            }
            return _objcTrip!.tripValidAnnotations
        }
        set {
            // This property is read-only in the Objective-C Trip class
            // The setter does nothing
        }
    }
    
    @objc
    public func duration() -> NSDateInterval? {
        return _objcTrip?.duration
    }
    
    @objc
    public func gpxFile() -> NSURL? {
        return _objcTrip?.gpxFile
    }
    
    @objc
    public func geoJSONFile() -> NSURL? {
        return _objcTrip?.geoJSONFile
    }
    
    @objc
    public func kmlFile() -> NSURL? {
        return _objcTrip?.kmlFile
    }
}

// MARK: - Access to ObjC Trip class (for bridging)
// Required to access Trip methods that don't exist in the wrapper

// MARK: - Helper Extensions for Swift-ObjC Interop

// MARK: - Trip Extension (for Swift syntax access)
extension Trip {
    @objc 
    public static func initWithIdentifier(identifier: Int) -> Trip? {
        let trip = self.init(identifier: identifier)
        return trip
    }
}
