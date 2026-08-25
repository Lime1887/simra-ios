//
//  TripAnnotation.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

@MainActor
final class TripAnnotation: NSObject, ObservableObject {
    
    @objc
    private(set) var incidentId: Int = -5
    @objc
    private(set) var frightening: Bool = false
    @objc
    private(set) var car: Bool = false
    @objc
    private(set) var taxi: Bool = false
    @objc
    private(set) var delivery: Bool = false
    @objc
    private(set) var bus: Bool = false
    @objc
    private(set) var commercial: Bool = false
    @objc
    private(set) var pedestrian: Bool = false
    @objc
    private(set) var bicycle: Bool = false
    @objc
    private(set) var motorcycle: Bool = false
    @objc
    private(set) var escooter: Bool = false
    @objc
    private(set) var other: Bool = false
    @objc
    private(set) var comment: String = ""
    
    init() {
        self.incidentId = -5
    }
}
