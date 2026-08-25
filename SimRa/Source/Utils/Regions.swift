//
//  Regions.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

@MainActor
final class Regions: NSObject, ObservableObject {
    
    static let shared = Regions()
    
    private init() {
        self.regionId = UserDefaults.standard.integer(forKey: "regionId")
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var regionId: Int = 0
    @Published private(set) var regionName: String = "Unknown"
    @Published private(set) var regionSelected: Bool = false
    
    // MARK: - Methods
    
    @objc static var regionId: Int {
        let regions = shared
        return regions.regionId
    }
    
    @objc static var regionSelected: Bool {
        let regions = shared
        return regions.regionSelected
    }
    
    @objc static func selectRegion(_ regionId: Int) {
        if regionId > 0 {
            UserDefaults.standard.set(regionId, forKey: "regionId")
        }
    }
}
