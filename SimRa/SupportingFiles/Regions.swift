// Regions.swift
final class Regions: NSObject, ObservableObject {
    @Published var regionId: Int = 0
    @Published var regionsId: Int = 0
    @Published var lastSeenRegionsId: Int = 0
    @Published var loaded: Bool = false
    var closestRegions: [Region] = []
    
    // Rest of the methods...
}
