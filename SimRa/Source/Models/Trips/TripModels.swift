//
//  TripModels.swift
//  SimRa
//
//  Swift equivalents of the legacy Trip model support types.
//

import Foundation
import CoreLocation

@objcMembers
public final class TripAnnotation: NSObject {
    public var comment: String?
    public var frightening: Bool = false
    public var car: Bool = false
    public var taxi: Bool = false
    public var delivery: Bool = false
    public var bus: Bool = false
    public var commercial: Bool = false
    public var pedestrian: Bool = false
    public var bicycle: Bool = false
    public var motorcycle: Bool = false
    public var other: Bool = false
    public var escooter: Bool = false
    public var incidentId: Int = 0

    public override init() {
        super.init()
    }
}

@objcMembers
public final class TripMotion: NSObject {
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0
    public var xl: Double = 0
    public var yl: Double = 0
    public var zl: Double = 0
    public var xr: Double = 0
    public var yr: Double = 0
    public var zr: Double = 0
    public var cr: Double = 0
    public var timestamp: TimeInterval = 0

    public override init() {
        super.init()
    }
}

@objcMembers
public final class TripGyro: NSObject {
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0

    public override init() {
        super.init()
    }
}

@objcMembers
public final class TripLocation: NSObject {
    public var location: CLLocation
    public var gyro: TripGyro?
    public var tripMotions: NSMutableArray
    public var tripAnnotation: TripAnnotation?
    public var closePassInfo: ClosePassInfo?

    var minOfMotionsX: Double = 0
    var minOfMotionsY: Double = 0
    var minOfMotionsZ: Double = 0
    var maxOfMotionsX: Double = 0
    var maxOfMotionsY: Double = 0
    var maxOfMotionsZ: Double = 0

    public override init() {
        self.location = CLLocation(latitude: 0, longitude: 0, timestamp: Date())
        self.tripMotions = NSMutableArray()
        super.init()
    }

    public init(location: CLLocation) {
        self.location = location
        self.tripMotions = NSMutableArray()
        super.init()
    }
}

@objcMembers
public final class TripInfo: NSObject {
    public var identifier: Int = 0
    public var version: Int = 0
    public var edited: Bool = false
    public var uploaded: Bool = false
    public var statisticsAdded: Bool = false
    public var reUploaded: Bool = false
    public var annotationsCount: Int = 0
    public var validAnnotationsCount: Int = 0
    public var fileHash: String?
    public var filePasswd: String?
    public var duration: NSDateInterval = NSDateInterval(start: Date(), end: Date())
    public var length: Int = 0

    public override init() {
        super.init()
    }

    public init(identifier: Int) {
        self.identifier = identifier
        super.init()
    }

    private convenience init?(dictionary: [String: Any]) {
        self.init()

        guard let identifier = dictionary["identifier"] as? NSNumber else { return nil }
        self.identifier = identifier.intValue
        self.version = (dictionary["version"] as? NSNumber)?.intValue ?? 0
        self.edited = (dictionary["edited"] as? NSNumber)?.boolValue ?? false
        self.uploaded = (dictionary["uploaded"] as? NSNumber)?.boolValue ?? false
        self.statisticsAdded = (dictionary["statisticsAdded"] as? NSNumber)?.boolValue ?? false
        self.reUploaded = (dictionary["reUploaded"] as? NSNumber)?.boolValue ?? false
        self.annotationsCount = (dictionary["annotationsCount"] as? NSNumber)?.intValue ?? 0
        self.validAnnotationsCount = (dictionary["validAnnotationsCount"] as? NSNumber)?.intValue ?? 0
        self.fileHash = dictionary["fileHash"] as? String
        self.filePasswd = dictionary["filePasswd"] as? String

        let start = (dictionary["start"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970
        let end = (dictionary["end"] as? NSNumber)?.doubleValue ?? start
        self.duration = NSDateInterval(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end)
        )
        self.length = (dictionary["length"] as? NSNumber)?.intValue ?? 0
    }

    public convenience init?(fromStorage identifier: Int) {
        let key = "TripInfo-\(identifier)"
        let defaults = UserDefaults.standard

        if let dict = defaults.dictionary(forKey: key) {
            self.init(dictionary: dict)
            return
        }

        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let tripInfoURL = documentDirectory?.appendingPathComponent("TripInfo-\(identifier).json")
        guard
            let tripInfoURL,
            let jsonData = try? Data(contentsOf: tripInfoURL),
            let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        else {
            return nil
        }

        self.init(dictionary: dict)
    }

    public static func allStoredIdentifiers() -> [NSNumber] {
        var identifiers: [Int] = []
        let defaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys.sorted()

        for key in defaultsKeys where key.hasPrefix("TripInfo-") {
            let id = Int(key.dropFirst("TripInfo-".count)) ?? 0
            if id > 0 {
                identifiers.append(id)
            }
        }

        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: documentDirectory.path) {
            for content in contents where content.hasPrefix("TripInfo-") {
                let id = Int(content.dropFirst("TripInfo-".count).dropLast(".json".count)) ?? 0
                if id > 0 && !identifiers.contains(id) {
                    identifiers.append(id)
                }
            }
        }

        return identifiers.map { NSNumber(value: $0) }
    }

    public func asDictionary() -> [String: Any] {
        var tripInfoDict: [String: Any] = [
            "identifier": identifier,
            "version": version,
            "edited": edited,
            "uploaded": uploaded,
            "statisticsAdded": statisticsAdded,
            "reUploaded": reUploaded,
            "annotationsCount": annotationsCount,
            "validAnnotationsCount": validAnnotationsCount,
            "start": duration.startDate.timeIntervalSince1970,
            "end": duration.endDate.timeIntervalSince1970,
            "length": length
        ]

        if let fileHash {
            tripInfoDict["fileHash"] = fileHash
        }
        if let filePasswd {
            tripInfoDict["filePasswd"] = filePasswd
        }

        return tripInfoDict
    }

    public func asJSONData() -> Data? {
        try? JSONSerialization.data(withJSONObject: asDictionary(), options: [])
    }
}
