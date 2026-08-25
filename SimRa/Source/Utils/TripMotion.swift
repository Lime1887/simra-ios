//
//  TripMotion.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

@MainActor
final class TripMotion: NSObject, ObservableObject {
    
    @objc
    private(set) var timestamp: TimeInterval = 0
    @objc
    private(set) var x: Double = 0
    @objc
    private(set) var y: Double = 0
    @objc
    private(set) var z: Double = 0
    @objc
    private(set) var xl: Double = 0
    @objc
    private(set) var yl: Double = 0
    @objc
    private(set) var zl: Double = 0
    @objc
    private(set) var xr: Double = 0
    @objc
    private(set) var yr: Double = 0
    @objc
    private(set) var zr: Double = 0
    @objc
    private(set) var cr: Double = 0
    
    init() {
        self.timestamp = 0
    }
}
