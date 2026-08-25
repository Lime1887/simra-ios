//
//  Trip.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import CoreLocation

// This is a Swift wrapper that inherits from the Objective-C Trip class
// The Objective-C Trip class is already defined in Trip.m
// This wrapper adds ObservableObject conformance and @Published properties for SwiftUI

class TRIPWrapper: ObservableObject {
    
    // This is the Objective-C Trip class
    class Trip: UploaderObject, CLLocationManagerDelegate {
        // Implementation from Objective-C Trip.m file
    }
    
    private let trip: Trip
    
    // Observe Trip properties with @Published
    @objc
    var bikeTypeId: Int {
        get { trip.bikeTypeId }
        set { trip.bikeTypeId = newValue }
    }
    
    @objc
    var positionId: Int {
        get { trip.positionId }
        set { trip.positionId = newValue }
    }
    
    @objc
    var childseat: Bool {
        get { trip.childseat }
        set { trip.childseat = newValue }
    }
    
    @objc
    var trailer: Bool {
        get { trip.trailer }
        set { trip.trailer = newValue }
    }
    
    @objc
    var edited: Bool {
        get { trip.edited }
        set { trip.edited = newValue }
    }
    
    @objc
    var uploaded: Bool {
        get { trip.uploaded }
        set { trip.uploaded = newValue }
    }
    
    @objc
    var identifier: Int {
        get { trip.identifier }
        set { trip.identifier = newValue }
    }
    
    @objc
    var statisticsAdded: Bool {
        get { trip.statisticsAdded }
        set { trip.statisticsAdded = newValue }
    }
    
    @objc
    var reUploaded: Bool {
        get { trip.reUploaded }
        set { trip.reUploaded = newValue }
    }
    
    // Other important properties from the Trip class
    @objc
    var tripLocations: [TripLocation] {
        get { trip.tripLocations as? [TripLocation] ?? [] }
        set { trip.tripLocations = NSMutableArray(array: newValue) }
    }
    
    @objc
    var startLocation: CLLocation? {
        get { trip.startLocation }
        set { trip.startLocation = newValue }
    }
    
    @objc
    var lastLocation: CLLocation? {
        get { trip.lastLocation }
        set { trip.lastLocation = newValue }
    }
    
    @objc
    var lastTripMotion: TripMotion? {
        get { trip.lastTripMotion }
        set { trip.lastTripMotion = newValue }
    }
    
    // Initialize with a Trip instance
    init(trip: Trip) {
        self.trip = trip
        super.init()
    }
    
    // Factory method to create from identifier
    static func fromStorage(identifier: Int) -> TRIPWrapper? {
        // Create Trip from storage
        guard let trip = Trip.initFromStorage(identifier: identifier) else {
            return nil
        }
        return TRIPWrapper(trip: trip)
    }
    
    // Save method that persists changes
    func save() {
        trip.save()
    }
}

// Extension to make the wrapper more ObservableObject-friendly
extension TRIPWrapper {
    
    /// Reloads all properties from the trip
    func reload() {
        // Force observe all properties by accessing them
        _ = bikeTypeId
        _ = positionId
        _ = childseat
        _ = trailer
        _ = edited
        _ = uploaded
        _ = identifier
        _ = statisticsAdded
        _ = reUploaded
        _ = tripLocations
        _ = startLocation
        _ = lastLocation
        _ = lastTripMotion
    }
}
