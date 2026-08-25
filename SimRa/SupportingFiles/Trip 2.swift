// Trip.swift
class TripInfo: NSObject {
    @Published var identifier: Int = 0
    @Published var version: Int = 0
    @Published var edited: Bool = false
    @Published var uploaded: Bool = false
    @Published var statisticsAdded: Bool = false
    @Published var reUploaded: Bool = false
    
    @Published var start: Date = Date()
    @Published var end: Date = Date()
    @Published var duration: TimeInterval = 0
    
    @Published var length: Int = 0
    
    @Published var annotationsCount: Int = 0
    @Published var validAnnotationsCount: Int = 0
    
    @Published var fileHash: String = ""
    @Published var filePasswd: String = ""
}
