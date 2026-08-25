// Regions.swift
final class Regions: NSObject, ObservableObject {
    @Published var regionId: Int = 0
    @Published var regionsId: Int = 0
    @Published var lastSeenRegionsId: Int = 0
    @Published var loaded: Bool = false
    
    @Published var closestRegions: [Region] = []
    @Published var regionNames: [String] = []
    
    private let locationManager: CLLocationManager
    
    init() {
        self.locationManager = CLLocationManager()
        super.init()
        setupRegionData()
    }
    
    private func setupRegionData() {
        // Load regions from stored data
        // Implementation depends on your data source
    }
    
    @objc
    func regionSelected() -> Bool {
        return regionId > 0
    }
    
    @objc
    func regionTextsSorted() -> [String] {
        // Implementation for getting sorted region names
        return regionNames
    }
    
    func computeClosestRegions(_ location: CLLocation) {
        // Compute and sort regions by distance
        // Implementation: calculate distances to each region's location
        // and sort, keeping the closest ones
    }
    
    @objc
    func selectedIsOneOfThe3ClosestRegions() -> Bool {
        // Check if selected region is among the 3 closest
        return true // Placeholder
    }
    
    @objc
    var regionId: Int {
        return regionId
    }
    
    @objc
    func indexForRegionId(_ id: Int) -> Int {
        // Find index for region ID
        return 0 // Placeholder
    }
    
    @objc
    func selectIdSorted(_ id: Int) {
        regionId = id
        lastSeenRegionsId = id
        savedRegionId = id
    }
    
    @objc
    func selectPosition(_ position: Int) {
        // Select region by position
        if position >= 0 && position < regionNames.count {
            regionId = indexForRegionId(regionId)
        }
    }
    
    @objc
    func currentRegion() -> Region? {
        // Return current region at selected ID
        if regionId > 0 && regionId <= regionNames.count {
            let regionIndex = indexForRegionId(regionId) - 1
            if regionIndex >= 0 {
                return closestRegions[regionIndex]
            }
        }
        return nil
    }
    
    @objc
    func seen() {
        lastSeenRegionsId = regionId
    }
}

// MARK: - Private properties for ObjC compatibility
private var savedRegionId: Int = 0
