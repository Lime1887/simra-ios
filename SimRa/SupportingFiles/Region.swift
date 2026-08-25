// Region.swift
class Region: NSObject {
    @Published var regionId: Int = 0
    @Published var regionsId: Int = 0
    @Published var lastSeenRegionsId: Int = 0
    @Published var loaded: Bool = false
    var name: String = ""
    var location: CLLocationCoordinate2D?
    
    override class func load() -> Region? {
        // Implementation
        return nil
    }
    
    override func seen() {
        lastSeenRegionsId = regionsId
    }
}
