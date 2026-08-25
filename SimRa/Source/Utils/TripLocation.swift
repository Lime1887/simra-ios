//
//  TripLocation.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

@MainActor
final class TripLocation: NSObject, ObservableObject {
    
    @objc
    private(set) var location = CLLocation(latitude: 0, longitude: 0, timestamp: Date())
    @objc
    private(set) var tripMotions: [TripMotion] = []
    @objc
    private(set) var tripAnnotation: TripAnnotation?
    
    init() {
        self.location = CLLocation(latitude: 0, longitude: 0, timestamp: Date())
    }
}
