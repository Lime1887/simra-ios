//
//  Trip.swift
//  SimRa
//
//  Swift port of the legacy Trip and Trips model layer.
//

import Foundation
import CoreLocation
import CoreMotion
import UIKit

@objcMembers
public class Trip: UploaderObject, CLLocationManagerDelegate {
    public private(set) var identifier: Int = 0
    public private(set) var startLocation: CLLocation?
    public private(set) var lastLocation: CLLocation?
    public private(set) var lastTripMotion: TripMotion?
    public var tripLocations: NSMutableArray = NSMutableArray()

    public private(set) var deferredSecs: Int = 0
    public private(set) var deferredMeters: Int = 0
    public var bikeTypeId: Int = 0
    public var positionId: Int = 0
    public var AIVersion: Int = 0
    public var childseat: Bool = false
    public var trailer: Bool = false
    public var statisticsAdded: Bool = false
    public var reUploaded: Bool = false

    private weak var appDelegate: AppDelegate?
    private var locationsFile: FileHandle?
    private var motionsFile: FileHandle?
    private var largestXMotion: TripLocation?
    private var secondLargestXMotion: TripLocation?
    private var largestYMotion: TripLocation?
    private var secondLargestYMotion: TripLocation?
    private var largestZMotion: TripLocation?
    private var secondLargestZMotion: TripLocation?
    private var timer: Timer?
    public private(set) var recordingStartDate: Date?
    private var accumulatedLength: Double = 0

    private lazy var motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "de.tu-berlin.mcc.simra.motionQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    private final class AccelerometerBuffer {
        var xa = [Double](repeating: 0.0, count: 30)
        var ya = [Double](repeating: 0.0, count: 30)
        var za = [Double](repeating: 0.0, count: 30)
        var xla = [Double](repeating: 0.0, count: 30)
        var yla = [Double](repeating: 0.0, count: 30)
        var zla = [Double](repeating: 0.0, count: 30)
        var xra = [Double](repeating: 0.0, count: 30)
        var yra = [Double](repeating: 0.0, count: 30)
        var zra = [Double](repeating: 0.0, count: 30)
        var cra = [Double](repeating: 0.0, count: 30)
        var aIndex = 0
        var aFill = 0
    }

    private var accelerometerBuffer: AccelerometerBuffer?

    public override init() {
        let defaults = UserDefaults.standard
        let nextIdentifier = defaults.integer(forKey: "lastTripId") + 1
        Utility.saveInt(key: "lastTripId", value: nextIdentifier)
        self.identifier = nextIdentifier
        super.init()
    }

    public init(identifier: Int) {
        self.identifier = identifier
        super.init()
        self.tripLocations = NSMutableArray()
    }

    public convenience init?(fromStorage identifier: Int) {
        if let trip = Trip.loadFromStorage(identifier: identifier) {
            self.init(identifier: identifier)
            self.apply(dictionary: trip)
        } else {
            return nil
        }
    }

    private static func loadFromStorage(identifier: Int) -> [String: Any]? {
        let defaults = UserDefaults.standard
        let key = "Trip-\(identifier)"
        if let dict = defaults.dictionary(forKey: key) {
            return dict
        }

        let documentDirectory = Self.documentsDirectoryURL()
        let tripURL = documentDirectory.appendingPathComponent("Trip-\(identifier).json")
        guard let jsonData = try? Data(contentsOf: tripURL),
              let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        return dict
    }

    private func apply(dictionary: [String: Any]) {
        identifier = (dictionary["identifier"] as? NSNumber)?.intValue ?? identifier
        version = (dictionary["version"] as? NSNumber)?.intValue ?? version
        edited = (dictionary["edited"] as? NSNumber)?.boolValue ?? false
        uploaded = (dictionary["uploaded"] as? NSNumber)?.boolValue ?? false
        fileHash = dictionary["fileHash"] as? String
        filePasswd = dictionary["filePasswd"] as? String
        deferredSecs = (dictionary["deferredSecs"] as? NSNumber)?.intValue ?? 0
        deferredMeters = (dictionary["deferredMeters"] as? NSNumber)?.intValue ?? 0
        bikeTypeId = (dictionary["bikeTypeId"] as? NSNumber)?.intValue ?? 0
        positionId = (dictionary["positionId"] as? NSNumber)?.intValue ?? 0
        AIVersion = (dictionary["AIVersion"] as? NSNumber)?.intValue ?? 0
        childseat = (dictionary["childseat"] as? NSNumber)?.boolValue ?? false
        trailer = (dictionary["trailer"] as? NSNumber)?.boolValue ?? false
        statisticsAdded = (dictionary["statisticsAdded"] as? NSNumber)?.boolValue ?? false
        reUploaded = (dictionary["reUploaded"] as? NSNumber)?.boolValue ?? false

        tripLocations = NSMutableArray()

        if let locations = dictionary["tripLocations"] as? [[String: Any]] {
            for tripLocationDict in locations {
                guard let tripLocation = Self.tripLocation(fromDictionary: tripLocationDict) else {
                    continue
                }
                tripLocations.add(tripLocation)
            }
        }

        if let first = tripLocations.firstObject as? TripLocation {
            startLocation = first.location
        }
        if let last = tripLocations.lastObject as? TripLocation {
            lastLocation = last.location
            if let motion = last.tripMotions.lastObject as? TripMotion {
                lastTripMotion = motion
            }
        }

        if tripAnnotations() == 0, let location = tripLocations.firstObject as? TripLocation {
            let annotation = TripAnnotation()
            annotation.incidentId = -5
            location.tripAnnotation = annotation
        }
    }

    public override func csvFile() -> URL? {
        csvFile(withHeader: true)
    }

    public func csvFile(withHeader: Bool) -> URL? {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent("trip.csv")
        try? fileManager.removeItem(at: fileURL)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard let fh = FileHandle(forWritingAtPath: fileURL.path) else { return nil }

        if withHeader {
            let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            let major = bundleVersion.components(separatedBy: ".").first ?? bundleVersion
            var csvString = "i\(major)#\(version)#\(AIVersion)\n"
            csvString += "key,lat,lon,ts,bike,childCheckBox,trailerCheckBox,pLoc,incident,i1,i2,i3,i4,i5,i6,i7,i8,i9,scary,desc,i10\n"
            if let data = csvString.data(using: .utf8) {
                fh.write(data)
            }

            var key = 0
            for case let tripLocation as TripLocation in tripLocations {
                guard let annotation = tripLocation.tripAnnotation else { continue }
                var comment = annotation.comment
                if let currentComment = comment {
                    let escaped = currentComment
                        .replacingOccurrences(of: "\"", with: "\\\"")
                        .replacingOccurrences(of: "\n", with: "\\n")
                    comment = escaped
                }

                let csvLine = String(
                    format: "%ld,%f,%f,%.0f,%ld,%d,%d,%ld,%ld,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%@,%d\n",
                    key,
                    tripLocation.location.coordinate.latitude,
                    tripLocation.location.coordinate.longitude,
                    round(tripLocation.location.timestamp.timeIntervalSince1970) * 1000.0,
                    bikeTypeId,
                    childseat,
                    trailer,
                    positionId,
                    annotation.incidentId,
                    annotation.bus,
                    annotation.bicycle,
                    annotation.pedestrian,
                    annotation.delivery,
                    annotation.commercial,
                    annotation.motorcycle,
                    annotation.car,
                    annotation.taxi,
                    annotation.other,
                    annotation.frightening,
                    comment.map { "\"\($0)\"" } ?? "",
                    annotation.escooter
                )
                if let data = csvLine.data(using: .utf8) {
                    fh.write(data)
                }
                key += 1
            }

            if let data = "\n===================\n".data(using: .utf8) {
                fh.write(data)
            }
        }

        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        var header = "i\(bundleVersion)#\(version)\n"
        header += "lat,lon,X,Y,Z,timeStamp,acc,a,b,c,obsDistanceLeft1,obsDistanceLeft2,obsDistanceRight1,obsDistanceRight2,obsClosePassEvent,XL,YL,ZL,RX,RY,RZ,RC\n"
        if let data = header.data(using: .utf8) {
            fh.write(data)
        }

        let documentDirectoryURL = Self.documentsDirectoryURL()
        let locationsURL = documentDirectoryURL.appendingPathComponent("TripLocations-\(identifier).csv")
        let motionsURL = documentDirectoryURL.appendingPathComponent("TripMotions-\(identifier).csv")

        let locationsHandle = FileHandle(forReadingAtPath: locationsURL.path)
        let motionsHandle = FileHandle(forReadingAtPath: motionsURL.path)

        if let locationsHandle, let motionsHandle {
            var locationsString = Self.readline(locationsHandle)
            var motionsString = Self.readline(motionsHandle)

            while locationsString != nil || motionsString != nil {
                if let locationLine = locationsString, let motionLine = motionsString {
                    let locationArray = locationLine.components(separatedBy: ",")
                    let motionArray = motionLine.components(separatedBy: ",")
                    let locationTime = Double(locationArray[5] ?? "0") ?? 0
                    let motionTime = Double(motionArray[5] ?? "0") ?? 0
                    if locationTime <= motionTime {
                        if let data = locationLine.data(using: String.Encoding.utf8) { fh.write(data) }
                        locationsString = Self.readline(locationsHandle)
                    } else {
                        if let data = motionLine.data(using: String.Encoding.utf8) { fh.write(data) }
                        motionsString = Self.readline(motionsHandle)
                    }
                } else if let locationLine = locationsString {
                    if let data = locationLine.data(using: String.Encoding.utf8) { fh.write(data) }
                    locationsString = Self.readline(locationsHandle)
                } else if let motionLine = motionsString {
                    if let data = motionLine.data(using: String.Encoding.utf8) { fh.write(data) }
                    motionsString = Self.readline(motionsHandle)
                }
            }

            try? locationsHandle.close()
            try? motionsHandle.close()
        } else {
            var locationLines: [NSNumber: String] = [:]
            for case let tripLocation as TripLocation in tripLocations {
                let csvLine = locationString(from: tripLocation, gyro: tripLocation.gyro, closePassInfo: tripLocation.closePassInfo)
                let locationTime = NSNumber(value: round(tripLocation.location.timestamp.timeIntervalSince1970) * 1000.0)
                locationLines[locationTime] = csvLine
            }

            for case let tripLocation as TripLocation in tripLocations {
                for case let tripMotion as TripMotion in tripLocation.tripMotions {
                    let csvLine = motionString(from: tripMotion)
                    let motionTime = NSNumber(value: tripMotion.timestamp * 1000.0)

                    while !locationLines.isEmpty {
                        guard let firstTime = locationLines.keys.sorted(by: { $0.compare($1) == .orderedAscending }).first else { break }
                        if firstTime.doubleValue < motionTime.doubleValue {
                            if let data = (locationLines[firstTime] ?? "").data(using: String.Encoding.utf8) {
                                fh.write(data)
                            }
                            locationLines.removeValue(forKey: firstTime)
                        } else {
                            break
                        }
                    }

                    if let data = csvLine.data(using: String.Encoding.utf8) {
                        fh.write(data)
                    }
                }
            }
        }

        try? fh.close()
        return fileURL
    }

    public override func save() {
        if let appDelegate = self.appDelegate ?? (UIApplication.shared.delegate as? AppDelegate) {
            appDelegate.trips.updateTrip(self)
        }

        let documentDirectoryURL = Self.documentsDirectoryURL()
        let tripURL = documentDirectoryURL.appendingPathComponent("Trip-\(identifier).json")
        let tripInfoURL = documentDirectoryURL.appendingPathComponent("TripInfo-\(identifier).json")

        let tripSuccess: Bool
        if let tripData = asJSONData() {
            tripSuccess = (try? tripData.write(to: tripURL, options: .atomic)) != nil
        } else {
            tripSuccess = false
        }

        let tripInfoSuccess: Bool
        if let tripInfoData = tripInfo().asJSONData() {
            tripInfoSuccess = (try? tripInfoData.write(to: tripInfoURL, options: .atomic)) != nil
        } else {
            tripInfoSuccess = false
        }

        print("[Trip] save tripSuccess=\(tripSuccess) tripInfoSuccess=\(tripInfoSuccess)")

        removeRecordingCheckpoint()
        if edited {
            removeLegacyCSVFiles()
        }
        Utility.remove(key: "Trip-\(identifier)")
        Utility.remove(key: "TripInfo-\(identifier)")
    }

    public func tripInfo() -> TripInfo {
        let info = TripInfo(identifier: identifier)
        info.version = version
        info.edited = edited
        info.uploaded = uploaded
        info.fileHash = fileHash
        info.filePasswd = filePasswd
        info.duration = duration() ?? NSDateInterval(start: Date(), end: Date())
        info.length = length()
        info.statisticsAdded = statisticsAdded
        info.reUploaded = reUploaded
        info.annotationsCount = tripAnnotations()
        info.validAnnotationsCount = tripValidAnnotations()
        return info
    }

    public func asDictionary() -> [String: Any] {
        var tripDict: [String: Any] = [
            "identifier": identifier,
            "version": version,
            "edited": edited,
            "uploaded": uploaded,
            "deferredSecs": deferredSecs,
            "deferredMeters": deferredMeters,
            "bikeTypeId": bikeTypeId,
            "positionId": positionId,
            "AIVersion": AIVersion,
            "childseat": childseat,
            "trailer": trailer,
            "statisticsAdded": statisticsAdded,
            "reUploaded": reUploaded
        ]

        if let fileHash {
            tripDict["fileHash"] = fileHash
        }
        if let filePasswd {
            tripDict["filePasswd"] = filePasswd
        }

        let tripLocationsArray = NSMutableArray()
        for case let tripLocation as TripLocation in tripLocations {
            tripLocationsArray.add(convertTripLocationToDictionary(tripLocation))
        }
        tripDict["tripLocations"] = tripLocationsArray

        return tripDict
    }

    public func asJSONData() -> Data? {
        try? JSONSerialization.data(withJSONObject: asDictionary(), options: [])
    }

    public override func uploadFile(_ name: String, withController controller: NSObject, error errorSelector: Selector, completion completionSelector: Selector) {
        var saveNecessary = false

        for case let location as TripLocation in tripLocations {
            if let annotation = location.tripAnnotation, annotation.incidentId == 0 {
                location.tripAnnotation = nil
                saveNecessary = true
            }
        }

        if tripAnnotations() == 0, let location = tripLocations.firstObject as? TripLocation {
            let annotation = TripAnnotation()
            annotation.incidentId = -5
            location.tripAnnotation = annotation
            saveNecessary = true
        }

        if saveNecessary {
            save()
        }

        let currentAppDelegate = appDelegate ?? (UIApplication.shared.delegate as? AppDelegate)
        if !statisticsAdded {
            currentAppDelegate?.trips.addTripToStatistics(self)
            statisticsAdded = true
            save()
        }

        super.uploadFile(name, withController: controller, error: errorSelector, completion: completionSelector)
    }

    public func successfullyReUploaded() {
        reUploaded = true
    }

    public func tripAnnotations() -> Int {
        var count = 0
        for case let tripLocation as TripLocation in tripLocations where tripLocation.tripAnnotation != nil {
            count += 1
        }
        return count
    }

    public func tripValidAnnotations() -> Int {
        var count = 0
        for case let tripLocation as TripLocation in tripLocations {
            if let annotation = tripLocation.tripAnnotation, annotation.incidentId != 0 {
                count += 1
            }
        }
        return count
    }

    public func numberOfScary() -> Int {
        var count = 0
        for case let tripLocation as TripLocation in tripLocations {
            if let annotation = tripLocation.tripAnnotation, annotation.frightening {
                count += 1
            }
        }
        return count
    }

    public func duration() -> NSDateInterval? {
        guard let first = tripLocations.firstObject as? TripLocation,
              let last = tripLocations.lastObject as? TripLocation else {
            return nil
        }
        return NSDateInterval(start: first.location.timestamp, end: last.location.timestamp)
    }

    public func length() -> Int {
        if accumulatedLength > 0 {
            return Int(accumulatedLength)
        }
        var total: CLLocationDistance = 0
        var lastTripLocation: TripLocation?
        for case let tripLocation as TripLocation in tripLocations {
            if let lastTripLocation {
                total += tripLocation.location.distance(from: lastTripLocation.location)
            }
            lastTripLocation = tripLocation
        }
        accumulatedLength = total
        return Int(total)
    }

    public func idle() -> Int {
        var total: TimeInterval = 0
        var lastTripLocation: TripLocation?
        for case let tripLocation as TripLocation in tripLocations {
            if let lastTripLocation, tripLocation.location.speed < 3.0 / 3.6 {
                total += tripLocation.location.timestamp.timeIntervalSince1970 - lastTripLocation.location.timestamp.timeIntervalSince1970
            }
            lastTripLocation = tripLocation
        }
        return Int(total)
    }

    public func gpxFile() -> URL? {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent("trip.gpx")
        try? fileManager.removeItem(at: fileURL)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard let fh = FileHandle(forWritingAtPath: fileURL.path) else { return nil }

        if let data = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n".data(using: .utf8) { fh.write(data) }
        if let data = "<gpx version=\"1.1\" creator=\"SimRa iOS\"><trk><trkseg>\n".data(using: .utf8) { fh.write(data) }

        for case let tripLocation as TripLocation in tripLocations {
            let csvString = String(format: "<trkpt lat=\"%f\" lon=\"%f\"></trkpt>\n", tripLocation.location.coordinate.latitude, tripLocation.location.coordinate.longitude)
            if let data = csvString.data(using: .utf8) { fh.write(data) }
        }

        if let data = "</trkseg></trk></gpx>\n".data(using: .utf8) { fh.write(data) }
        try? fh.close()
        return fileURL
    }

    public func geoJSONFile() -> URL? {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent("trip.geojson")
        try? fileManager.removeItem(at: fileURL)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard let fh = FileHandle(forWritingAtPath: fileURL.path) else { return nil }

        var separator = false
        if let data = "{\"type\":\"LineString\",\"coordinates\":[\n".data(using: .utf8) { fh.write(data) }

        for case let tripLocation as TripLocation in tripLocations {
            let csvString = String(format: "%@[%f,%f]\n", separator ? "," : "", tripLocation.location.coordinate.longitude, tripLocation.location.coordinate.latitude)
            separator = true
            if let data = csvString.data(using: .utf8) { fh.write(data) }
        }

        if let data = "]}\n".data(using: .utf8) { fh.write(data) }
        try? fh.close()
        return fileURL
    }

    public func kmlFile() -> URL? {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent("trip.kml")
        try? fileManager.removeItem(at: fileURL)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard let fh = FileHandle(forWritingAtPath: fileURL.path) else { return nil }

        if let data = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n".data(using: .utf8) { fh.write(data) }
        if let data = "<kml xmlns=\"http://www.opengis.net/kml/2.2\"><Document><Placemark id=\"Simra\"><LineString id=\"Simra\"><coordinates>\n".data(using: .utf8) { fh.write(data) }

        for case let tripLocation as TripLocation in tripLocations {
            let csvString = String(format: "%f,%f\n", tripLocation.location.coordinate.longitude, tripLocation.location.coordinate.latitude)
            if let data = csvString.data(using: .utf8) { fh.write(data) }
        }

        if let data = "</coordinates></LineString></Placemark></Document></kml>\n".data(using: .utf8) { fh.write(data) }
        try? fh.close()
        return fileURL
    }

    public func startRecording() {
        let appDelegate = AppDelegate.shared()
        self.appDelegate = appDelegate
        deferredSecs = appDelegate.defaults.integer(forKey: "deferredSecs")
        deferredMeters = appDelegate.defaults.integer(forKey: "deferredMeters")
        bikeTypeId = appDelegate.defaults.integer(forKey: "bikeTypeId")
        positionId = appDelegate.defaults.integer(forKey: "positionId")
        childseat = appDelegate.defaults.bool(forKey: "childSeat")
        trailer = appDelegate.defaults.bool(forKey: "trailer")

        let fileManager = FileManager.default
        let documentDirectoryURL = Self.documentsDirectoryURL()
        let locationsURL = documentDirectoryURL.appendingPathComponent("TripLocations-\(identifier).csv")
        let motionsURL = documentDirectoryURL.appendingPathComponent("TripMotions-\(identifier).csv")

        fileManager.createFile(atPath: locationsURL.path, contents: Data(), attributes: nil)
        fileManager.createFile(atPath: motionsURL.path, contents: Data(), attributes: nil)
        locationsFile = FileHandle(forWritingAtPath: locationsURL.path)
        motionsFile = FileHandle(forWritingAtPath: motionsURL.path)
        recordingStartDate = Date()
        saveRecordingCheckpoint()

        if appDelegate.mm.isGyroAvailable {
            appDelegate.mm.startGyroUpdates()
        }

        appDelegate.lm.delegate = self
        let status = CLLocationManager().authorizationStatus
        if status == .notDetermined {
            appDelegate.lm.requestWhenInUseAuthorization()
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            appDelegate.lm.allowsBackgroundLocationUpdates = true
            appDelegate.lm.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            appDelegate.lm.activityType = .fitness
            appDelegate.lm.startUpdatingLocation()
        } else {
            print("[Trip] Location authorization not granted: \(status.rawValue)")
        }

        if appDelegate.mm.isDeviceMotionAvailable {
            let accelerometerSamples = 30
            let accelerometerSteps = 5
            let buffer = AccelerometerBuffer()
            self.accelerometerBuffer = buffer

            appDelegate.mm.deviceMotionUpdateInterval = 1.0 / 50.0
            appDelegate.mm.startDeviceMotionUpdates(to: motionQueue) { [weak self, weak appDelegate] deviceMotion, _ in
                guard let self, let appDelegate, let buffer = self.accelerometerBuffer, let deviceMotion else { return }
                let accel = appDelegate.mm.accelerometerData?.acceleration

                buffer.xa[buffer.aIndex] = accel?.x ?? (deviceMotion.userAcceleration.x + deviceMotion.gravity.x)
                buffer.ya[buffer.aIndex] = accel?.y ?? (deviceMotion.userAcceleration.y + deviceMotion.gravity.y)
                buffer.za[buffer.aIndex] = accel?.z ?? (deviceMotion.userAcceleration.z + deviceMotion.gravity.z)
                buffer.xla[buffer.aIndex] = deviceMotion.userAcceleration.x
                buffer.yla[buffer.aIndex] = deviceMotion.userAcceleration.y
                buffer.zla[buffer.aIndex] = deviceMotion.userAcceleration.z
                buffer.xra[buffer.aIndex] = deviceMotion.attitude.quaternion.x
                buffer.yra[buffer.aIndex] = deviceMotion.attitude.quaternion.y
                buffer.zra[buffer.aIndex] = deviceMotion.attitude.quaternion.z
                buffer.cra[buffer.aIndex] = deviceMotion.attitude.quaternion.w

                buffer.aIndex = (buffer.aIndex + 1) % accelerometerSamples
                buffer.aFill += 1

                if buffer.aFill >= accelerometerSamples {
                    var x = 0.0, y = 0.0, z = 0.0
                    var xl = 0.0, yl = 0.0, zl = 0.0
                    var xr = 0.0, yr = 0.0, zr = 0.0, cr = 0.0
                    for i in 0..<accelerometerSamples {
                        x += buffer.xa[i]; y += buffer.ya[i]; z += buffer.za[i]
                        xl += buffer.xla[i]; yl += buffer.yla[i]; zl += buffer.zla[i]
                        xr += buffer.xra[i]; yr += buffer.yra[i]; zr += buffer.zra[i]
                        cr += buffer.cra[i]
                    }
                    let count = Double(accelerometerSamples)
                    x /= count; y /= count; z /= count
                    xl /= count; yl /= count; zl /= count
                    xr /= count; yr /= count; zr /= count; cr /= count

                    self.addAcceleration(x: x, y: y, z: z, xl: xl, yl: yl, zl: zl, xr: xr, yr: yr, zr: zr, cr: cr)
                    buffer.aFill = accelerometerSamples - accelerometerSteps
                }
            }
        } else if appDelegate.mm.isAccelerometerAvailable {
            let accelerometerSamples = 30
            let accelerometerSteps = 5
            let buffer = AccelerometerBuffer()
            self.accelerometerBuffer = buffer

            appDelegate.mm.accelerometerUpdateInterval = 1.0 / 50.0
            appDelegate.mm.startAccelerometerUpdates(to: motionQueue) { [weak self] accelerometerData, _ in
                guard let self, let buffer = self.accelerometerBuffer, let accelerometerData else { return }
                buffer.xa[buffer.aIndex] = accelerometerData.acceleration.x
                buffer.ya[buffer.aIndex] = accelerometerData.acceleration.y
                buffer.za[buffer.aIndex] = accelerometerData.acceleration.z

                buffer.aIndex = (buffer.aIndex + 1) % accelerometerSamples
                buffer.aFill += 1

                if buffer.aFill >= accelerometerSamples {
                    var x = 0.0, y = 0.0, z = 0.0
                    for i in 0..<accelerometerSamples {
                        x += buffer.xa[i]; y += buffer.ya[i]; z += buffer.za[i]
                    }
                    let count = Double(accelerometerSamples)
                    x /= count; y /= count; z /= count
                    self.addAcceleration(x: x, y: y, z: z, xl: 0, yl: 0, zl: 0, xr: 0, yr: 0, zr: 0, cr: 0)
                    buffer.aFill = accelerometerSamples - accelerometerSteps
                }
            }
        }
    }

    public func stopRecording() {
        let appDelegate = self.appDelegate ?? AppDelegate.shared()
        timer?.invalidate()
        timer = nil
        motionQueue.cancelAllOperations()
        self.accelerometerBuffer = nil

        if appDelegate.mm.isGyroActive {
            appDelegate.mm.stopGyroUpdates()
        }
        if appDelegate.mm.isAccelerometerActive {
            appDelegate.mm.stopAccelerometerUpdates()
        }
        if appDelegate.mm.isDeviceMotionActive {
            appDelegate.mm.stopDeviceMotionUpdates()
        }
        appDelegate.lm.stopUpdatingLocation()
        appDelegate.lm.delegate = nil

        try? locationsFile?.synchronize()
        try? motionsFile?.synchronize()
        try? locationsFile?.close()
        try? motionsFile?.close()
        locationsFile = nil
        motionsFile = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            if appDelegate.defaults.bool(forKey: "AI") {
                self.AIIncidentDetection()
            } else {
                self.offlineIncidentDectection()
            }
            self.save()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let gyroData = AppDelegate.shared().mm.gyroData
        for location in locations {
            addLocation(location, withGyroData: gyroData)
        }
    }

    public func storeClosePassValueForTripWithLeftSensorVal(_ leftSensorVal: NSNumber,
                                                            rightSensorVal: NSNumber,
                                                            leftSensor1Val: NSNumber,
                                                            leftSensor2Val: NSNumber,
                                                            rightSensor1Val: NSNumber,
                                                            rightSensor2Val: NSNumber) {
        let closePassInfo = ClosePassInfo()
        let isValidLeftSensor = checkIncidentMinimumDistance(leftSensorVal)
        let isValidRightSensor = checkIncidentMinimumDistance(rightSensorVal)
        if isValidLeftSensor {
            closePassInfo.leftSensorValue = leftSensorVal
        }
        if isValidRightSensor {
            closePassInfo.rightSensorValue = rightSensorVal
        }
        if checkIncidentMinimumDistance(leftSensor1Val) {
            closePassInfo.leftSensor1Value = leftSensor1Val
        }
        if checkIncidentMinimumDistance(leftSensor2Val) {
            closePassInfo.leftSensor2Value = leftSensor2Val
        }
        if checkIncidentMinimumDistance(rightSensor1Val) {
            closePassInfo.rightSensor1Value = rightSensor1Val
        }
        if checkIncidentMinimumDistance(rightSensor2Val) {
            closePassInfo.rightSensor2Value = rightSensor2Val
        }

        if isValidLeftSensor || isValidRightSensor, let tripLocation = tripLocations.lastObject as? TripLocation {
            closePassInfo.location = tripLocation.location
            let csvString = locationString(from: tripLocation, gyro: tripLocation.gyro, closePassInfo: closePassInfo)
            if let data = csvString.data(using: .utf8) {
                locationsFile?.write(data)
                try? locationsFile?.synchronize()
            }

            let annotation = TripAnnotation()
            annotation.incidentId = 1
            annotation.comment = "Open Bike Sensor Close Pass incident reading\n Left Sensor: \(leftSensorVal)\n Right Sensor: \(rightSensorVal)\n"
            tripLocation.tripAnnotation = annotation
        }
    }

    public func checkIncidentMinimumDistance(_ sensorValue: NSNumber) -> Bool {
        sensorValue.intValue < 150
    }

    public func offlineIncidentDectection() {
        if let largestXMotion, largestXMotion.tripAnnotation == nil {
            largestXMotion.tripAnnotation = TripAnnotation()
        }
        if let secondLargestXMotion, secondLargestXMotion.tripAnnotation == nil {
            secondLargestXMotion.tripAnnotation = TripAnnotation()
        }
        if let largestYMotion, largestYMotion.tripAnnotation == nil {
            largestYMotion.tripAnnotation = TripAnnotation()
        }
        if let secondLargestYMotion, secondLargestYMotion.tripAnnotation == nil {
            secondLargestYMotion.tripAnnotation = TripAnnotation()
        }
        if let largestZMotion, largestZMotion.tripAnnotation == nil {
            largestZMotion.tripAnnotation = TripAnnotation()
        }
        if let secondLargestZMotion, secondLargestZMotion.tripAnnotation == nil {
            secondLargestZMotion.tripAnnotation = TripAnnotation()
        }
    }

    public func AIIncidentDetection() {
        offlineIncidentDectection()
    }

    public func addLocation(_ location: CLLocation, withGyroData gyroData: CMGyroData?) {
        print("[Trip] addLocation - lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude), speed: \(location.speed)")
        
        if startLocation == nil {
            startLocation = location
            print("[Trip] Set startLocation")
        }

        let previousTripLocation = tripLocations.lastObject as? TripLocation
        let currentAppDelegate = appDelegate ?? AppDelegate.shared()
        let deferredSecs = currentAppDelegate.defaults.integer(forKey: "deferredSecs")
        let deferredMeters = currentAppDelegate.defaults.integer(forKey: "deferredMeters")

        guard let startLocation = startLocation else {
            print("[Trip] startLocation is nil, cannot process location")
            return
        }

        let referenceDate = recordingStartDate ?? startLocation.timestamp
        let timeSinceStart = location.timestamp.timeIntervalSince(referenceDate)
        let distanceFromStart = location.distance(from: startLocation)

        print("[Trip] Deferred check - secs: \(deferredSecs), meters: \(deferredMeters), timeSinceStart: \(timeSinceStart), distanceFromStart: \(distanceFromStart)")

        // Match logic: check against startLocation, not previousLocation
        if ((deferredSecs == 0 || timeSinceStart > Double(deferredSecs)) &&
            (deferredMeters == 0 || distanceFromStart > Double(deferredMeters))) {
            let newLocation = TripLocation()
            newLocation.location = location
            let gyro = TripGyro()
            gyro.x = gyroData?.rotationRate.x ?? 0
            gyro.y = gyroData?.rotationRate.y ?? 0
            gyro.z = gyroData?.rotationRate.z ?? 0
            if let prevLoc = (tripLocations.lastObject as? TripLocation)?.location {
                accumulatedLength += location.distance(from: prevLoc)
            }
            tripLocations.add(newLocation)
            lastLocation = location
            
            let csvString = locationString(from: newLocation, gyro: gyro, closePassInfo: nil)
            if let data = csvString.data(using: .utf8) {
                locationsFile?.write(data)
            }
            newLocation.gyro = gyro

            if let previousTripLocation {
                let lastX = previousTripLocation.maxOfMotionsX - previousTripLocation.minOfMotionsX
                if let largestXMotion {
                    let largestX = largestXMotion.maxOfMotionsX - largestXMotion.minOfMotionsX
                    if lastX > largestX {
                        self.secondLargestXMotion = largestXMotion
                        self.largestXMotion = previousTripLocation
                    } else if let secondLargestXMotion {
                        let secondLargestX = secondLargestXMotion.maxOfMotionsX - secondLargestXMotion.minOfMotionsX
                        if lastX > secondLargestX {
                            self.secondLargestXMotion = previousTripLocation
                        }
                    }
                } else {
                    largestXMotion = previousTripLocation
                }

                let lastY = previousTripLocation.maxOfMotionsY - previousTripLocation.minOfMotionsY
                if let largestYMotion {
                    let largestY = largestYMotion.maxOfMotionsY - largestYMotion.minOfMotionsY
                    if lastY > largestY {
                        self.secondLargestYMotion = largestYMotion
                        self.largestYMotion = previousTripLocation
                    } else if let secondLargestYMotion {
                        let secondLargestY = secondLargestYMotion.maxOfMotionsY - secondLargestYMotion.minOfMotionsY
                        if lastY > secondLargestY {
                            self.secondLargestYMotion = previousTripLocation
                        }
                    }
                } else {
                    largestYMotion = previousTripLocation
                }

                let lastZ = previousTripLocation.maxOfMotionsZ - previousTripLocation.minOfMotionsZ
                if let largestZMotion {
                    let largestZ = largestZMotion.maxOfMotionsZ - largestZMotion.minOfMotionsZ
                    if lastZ > largestZ {
                        self.secondLargestZMotion = largestZMotion
                        self.largestZMotion = previousTripLocation
                    } else if let secondLargestZMotion {
                        let secondLargestZ = secondLargestZMotion.maxOfMotionsZ - secondLargestZMotion.minOfMotionsZ
                        if lastZ > secondLargestZ {
                            self.secondLargestZMotion = previousTripLocation
                        }
                    }
                } else {
                    largestZMotion = previousTripLocation
                }
            }
        }
    }

    public func addAcceleration(x: Double,
                                y: Double,
                                z: Double,
                                xl: Double,
                                yl: Double,
                                zl: Double,
                                xr: Double,
                                yr: Double,
                                zr: Double,
                                cr: Double) {
        guard let lastTripLocation = tripLocations.lastObject as? TripLocation else { return }
        let tripMotion = TripMotion()
        tripMotion.x = x
        tripMotion.y = y
        tripMotion.z = z
        tripMotion.xl = xl
        tripMotion.yl = yl
        tripMotion.zl = zl
        tripMotion.xr = xr
        tripMotion.yr = yr
        tripMotion.zr = zr
        tripMotion.cr = cr
        tripMotion.timestamp = Date().timeIntervalSince1970
        lastTripMotion = tripMotion
        let csvString = motionString(from: tripMotion)
        if let data = csvString.data(using: .utf8) {
            motionsFile?.write(data)
        }

        lastTripLocation.minOfMotionsX = min(lastTripLocation.minOfMotionsX, tripMotion.x)
        lastTripLocation.minOfMotionsY = min(lastTripLocation.minOfMotionsY, tripMotion.y)
        lastTripLocation.minOfMotionsZ = min(lastTripLocation.minOfMotionsZ, tripMotion.z)
        lastTripLocation.maxOfMotionsX = max(lastTripLocation.maxOfMotionsX, tripMotion.x)
        lastTripLocation.maxOfMotionsY = max(lastTripLocation.maxOfMotionsY, tripMotion.y)
        lastTripLocation.maxOfMotionsZ = max(lastTripLocation.maxOfMotionsZ, tripMotion.z)
    }

    public func durationStartDate() -> Date? {
        guard let nsInterval = duration() else { return nil }
        return nsInterval.startDate
    }

    public func durationEndDate() -> Date? {
        guard let nsInterval = duration() else { return nil }
        return nsInterval.endDate
    }

    private func removeRecordingCheckpoint() {
        let checkpointURL = Self.checkpointURL(forIdentifier: identifier)
        try? FileManager.default.removeItem(at: checkpointURL)
    }

    private func saveRecordingCheckpoint() {
        let checkpointURL = Self.checkpointURL(forIdentifier: identifier)
        let checkpoint = recordingCheckpointDictionary()
        if let jsonData = try? JSONSerialization.data(withJSONObject: checkpoint, options: []) {
            try? jsonData.write(to: checkpointURL, options: .atomic)
        }
    }

    public static func loadIncompleteTrip() -> Trip? {
        guard let identifier = recoverableIdentifiers().first else {
            return nil
        }

        return tripFromCheckpoint(
            at: checkpointURL(forIdentifier: identifier.intValue)
        )
    }

    public func resumeRecording(from startDate: Date) {
        self.recordingStartDate = startDate
        self.appDelegate = AppDelegate.shared()

        let documentDirectoryURL = Self.documentsDirectoryURL()
        let locationsURL = documentDirectoryURL.appendingPathComponent("TripLocations-\(identifier).csv")
        let motionsURL = documentDirectoryURL.appendingPathComponent("TripMotions-\(identifier).csv")

        locationsFile = FileHandle(forWritingAtPath: locationsURL.path)
        motionsFile = FileHandle(forWritingAtPath: motionsURL.path)
        try? locationsFile?.seekToEnd()
        try? motionsFile?.seekToEnd()
        saveRecordingCheckpoint()
    }

    private func removeLegacyCSVFiles() {
        let fileManager = FileManager.default
        let documentDirectoryURL = Self.documentsDirectoryURL()
        let locationsURL = documentDirectoryURL.appendingPathComponent("TripLocations-\(identifier).csv")
        let motionsURL = documentDirectoryURL.appendingPathComponent("TripMotions-\(identifier).csv")
        try? fileManager.removeItem(at: locationsURL)
        try? fileManager.removeItem(at: motionsURL)
    }

    private func recordingCheckpointDictionary() -> [String: Any] {
        [
            "identifier": identifier,
            "version": version,
            "AIVersion": AIVersion,
            "deferredSecs": deferredSecs,
            "deferredMeters": deferredMeters,
            "bikeTypeId": bikeTypeId,
            "positionId": positionId,
            "childseat": childseat,
            "trailer": trailer,
            "recordingStartDate": recordingStartDate?.timeIntervalSince1970 ?? 0
        ]
    }

    public static func allStoredIdentifiers() -> [NSNumber] {
        var identifiers: [Int] = []

        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: documentDirectory.path) {
            for content in contents where content.hasPrefix("Trip-") && content.hasSuffix(".json") {
                let idString = content.dropFirst("Trip-".count).dropLast(".json".count)
                if let id = Int(idString), id > 0 && !identifiers.contains(id) {
                    identifiers.append(id)
                }
            }
        }

        let defaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in defaultsKeys where key.hasPrefix("Trip-") {
            let idString = key.dropFirst("Trip-".count)
            if let id = Int(idString), id > 0 && !identifiers.contains(id) {
                identifiers.append(id)
            }
        }

        return identifiers.sorted().map { NSNumber(value: $0) }
    }

    public static func recoverIncompleteTrips() {
        let fileManager = FileManager.default
        let identifiers = recoverableIdentifiers()

        for identifierNumber in identifiers {
            let identifier = identifierNumber.intValue
            let tripURL = tripURL(forIdentifier: identifier)
            let tripInfoURL = tripInfoURL(forIdentifier: identifier)
            let checkpointURL = checkpointURL(forIdentifier: identifier)
            let locationsURL = locationsURL(forIdentifier: identifier)
            let motionsURL = motionsURL(forIdentifier: identifier)

            if fileManager.fileExists(atPath: tripURL.path) || fileManager.fileExists(atPath: tripInfoURL.path) {
                try? fileManager.removeItem(at: checkpointURL)
                continue
            }

            if let trip = tripFromCheckpoint(at: checkpointURL) {
                print("[Trip] recovering unfinished trip \(identifier)")
                trip.save()
            } else {
                print("[Trip] removing stale checkpoint for trip \(identifier)")
                try? fileManager.removeItem(at: checkpointURL)
                try? fileManager.removeItem(at: locationsURL)
                try? fileManager.removeItem(at: motionsURL)
            }
        }
    }

    public static func deleteFromStorage(_ identifier: Int) {
        Utility.remove(key: "Trip-\(identifier)")
        Utility.remove(key: "TripInfo-\(identifier)")

        let fileManager = FileManager.default
        let documentDirectoryURL = documentsDirectoryURL()
        let tripURL = documentDirectoryURL.appendingPathComponent("Trip-\(identifier).json")
        let tripInfoURL = documentDirectoryURL.appendingPathComponent("TripInfo-\(identifier).json")
        let tripLocationsURL = documentDirectoryURL.appendingPathComponent("TripLocations-\(identifier).csv")
        let tripMotionsURL = documentDirectoryURL.appendingPathComponent("TripMotions-\(identifier).csv")
        let tripCheckpointURL = documentDirectoryURL.appendingPathComponent("TripCheckpoint-\(identifier).json")

        let tripSuccess = (try? fileManager.removeItem(at: tripURL)) == nil ? false : true
        let tripInfoSuccess = (try? fileManager.removeItem(at: tripInfoURL)) == nil ? false : true
        let tripLocationsSuccess = (try? fileManager.removeItem(at: tripLocationsURL)) == nil ? false : true
        let tripMotionsSuccess = (try? fileManager.removeItem(at: tripMotionsURL)) == nil ? false : true
        let tripCheckpointSuccess = (try? fileManager.removeItem(at: tripCheckpointURL)) == nil ? false : true

        print("[Trip] deleteFromStorage trip=\(tripSuccess) tripInfo=\(tripInfoSuccess) tripLocations=\(tripLocationsSuccess) tripMotions=\(tripMotionsSuccess) tripCheckpoint=\(tripCheckpointSuccess)")
    }

    public static func documentsDirectoryURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }

    public static func tripURL(forIdentifier identifier: Int) -> URL {
        documentsDirectoryURL().appendingPathComponent("Trip-\(identifier).json")
    }

    public static func tripInfoURL(forIdentifier identifier: Int) -> URL {
        documentsDirectoryURL().appendingPathComponent("TripInfo-\(identifier).json")
    }

    public static func locationsURL(forIdentifier identifier: Int) -> URL {
        documentsDirectoryURL().appendingPathComponent("TripLocations-\(identifier).csv")
    }

    public static func motionsURL(forIdentifier identifier: Int) -> URL {
        documentsDirectoryURL().appendingPathComponent("TripMotions-\(identifier).csv")
    }

    public static func checkpointURL(forIdentifier identifier: Int) -> URL {
        documentsDirectoryURL().appendingPathComponent("TripCheckpoint-\(identifier).json")
    }

    private static func recoverableIdentifiers() -> [NSNumber] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: documentsDirectoryURL().path) else {
            return []
        }

        var identifiers: [NSNumber] = []
        for content in contents where content.hasPrefix("TripCheckpoint-") && content.hasSuffix(".json") {
            let identifierString = content
                .replacingOccurrences(of: "TripCheckpoint-", with: "")
                .replacingOccurrences(of: ".json", with: "")
            let identifier = Int(identifierString) ?? 0
            if identifier > 0 {
                identifiers.append(NSNumber(value: identifier))
            }
        }
        return identifiers
    }

    private static func tripFromCheckpoint(at checkpointURL: URL) -> Trip? {
        guard let checkpointData = try? Data(contentsOf: checkpointURL),
              let checkpoint = try? JSONSerialization.jsonObject(with: checkpointData, options: []) as? [String: Any],
              let identifier = (checkpoint["identifier"] as? NSNumber)?.intValue,
              identifier > 0 else {
            return nil
        }

        let locationsURL = locationsURL(forIdentifier: identifier)
        let motionsURL = motionsURL(forIdentifier: identifier)
        guard let locationsString = try? String(contentsOf: locationsURL, encoding: .utf8), !locationsString.isEmpty else {
            return nil
        }
        let motionsString = (try? String(contentsOf: motionsURL, encoding: .utf8)) ?? ""

        let trip = Trip(identifier: identifier)
        trip.version = (checkpoint["version"] as? NSNumber)?.intValue ?? 0
        trip.AIVersion = (checkpoint["AIVersion"] as? NSNumber)?.intValue ?? 0
        trip.deferredSecs = (checkpoint["deferredSecs"] as? NSNumber)?.intValue ?? 0
        trip.deferredMeters = (checkpoint["deferredMeters"] as? NSNumber)?.intValue ?? 0
        trip.bikeTypeId = (checkpoint["bikeTypeId"] as? NSNumber)?.intValue ?? 0
        trip.positionId = (checkpoint["positionId"] as? NSNumber)?.intValue ?? 0
        trip.childseat = (checkpoint["childseat"] as? NSNumber)?.boolValue ?? false
        trip.trailer = (checkpoint["trailer"] as? NSNumber)?.boolValue ?? false
        if let timestamp = checkpoint["recordingStartDate"] as? NSNumber,
           timestamp.doubleValue > 0 {
            trip.recordingStartDate = Date(
                timeIntervalSince1970: timestamp.doubleValue
            )
        }

        var locationEntries: [(timestamp: Double, location: TripLocation)] = []
        for line in locationsString.components(separatedBy: .newlines) where !line.isEmpty {
            guard let location = tripLocation(fromCSVLine: line) else { continue }
            let fields = line.components(separatedBy: ",")
            let timestamp = Double(fields[5] ?? "0") ?? 0
            locationEntries.append((timestamp: timestamp, location: location))
        }

        var motionEntries: [(timestamp: Double, motion: TripMotion)] = []
        for line in motionsString.components(separatedBy: .newlines) where !line.isEmpty {
            guard let motion = tripMotion(fromCSVLine: line) else { continue }
            let fields = line.components(separatedBy: ",")
            let timestamp = Double(fields[5] ?? "0") ?? 0
            motionEntries.append((timestamp: timestamp, motion: motion))
        }

        var locationIndex = 0
        var motionIndex = 0
        var currentLocation: TripLocation?

        while locationIndex < locationEntries.count || motionIndex < motionEntries.count {
            var shouldTakeLocation = false
            if locationIndex < locationEntries.count {
                if motionIndex >= motionEntries.count {
                    shouldTakeLocation = true
                } else {
                    shouldTakeLocation = locationEntries[locationIndex].timestamp <= motionEntries[motionIndex].timestamp
                }
            }

            if shouldTakeLocation {
                let tripLocation = locationEntries[locationIndex].location
                if trip.startLocation == nil {
                    trip.startLocation = tripLocation.location
                }
                trip.lastLocation = tripLocation.location
                currentLocation = tripLocation
                trip.tripLocations.add(tripLocation)
                locationIndex += 1
            } else {
                let tripMotion = motionEntries[motionIndex].motion
                if let currentLocation {
                    currentLocation.tripMotions.add(tripMotion)
                    currentLocation.minOfMotionsX = min(currentLocation.minOfMotionsX, tripMotion.x)
                    currentLocation.minOfMotionsY = min(currentLocation.minOfMotionsY, tripMotion.y)
                    currentLocation.minOfMotionsZ = min(currentLocation.minOfMotionsZ, tripMotion.z)
                    currentLocation.maxOfMotionsX = max(currentLocation.maxOfMotionsX, tripMotion.x)
                    currentLocation.maxOfMotionsY = max(currentLocation.maxOfMotionsY, tripMotion.y)
                    currentLocation.maxOfMotionsZ = max(currentLocation.maxOfMotionsZ, tripMotion.z)
                }
                motionIndex += 1
            }
        }

        if trip.tripLocations.count == 0 {
            return nil
        }

        return trip
    }

    private static func readline(_ fh: FileHandle) -> String? {
        var line = ""
        while true {
            let data = fh.readData(ofLength: 1)
            if data.isEmpty {
                return line.isEmpty ? nil : line
            }
            guard let char = String(data: data, encoding: .utf8) else { continue }
            if char == "\n" {
                return line
            }
            line += char
        }
    }

    private func locationString(from tripLocation: TripLocation, gyro: TripGyro?, closePassInfo: ClosePassInfo?) -> String {
        String(
            format: "%f,%f,%f,%f,%f,%.0f,%f,%f,%f,%f,%ld,%ld,%ld,%ld,%d,%f,%f,%f,%f,%f,%f,%f\n",
            tripLocation.location.coordinate.latitude,
            tripLocation.location.coordinate.longitude,
            0.0,
            0.0,
            0.0,
            round(tripLocation.location.timestamp.timeIntervalSince1970) * 1000.0,
            tripLocation.location.horizontalAccuracy,
            gyro?.x ?? 0.0,
            gyro?.y ?? 0.0,
            gyro?.z ?? 0.0,
            closePassInfo?.leftSensor1Value?.intValue ?? -1,
            closePassInfo?.leftSensor2Value?.intValue ?? -1,
            closePassInfo?.rightSensor1Value?.intValue ?? -1,
            closePassInfo?.rightSensor2Value?.intValue ?? -1,
            closePassInfo != nil ? 1 : 0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0
        )
    }

    private func motionString(from tripMotion: TripMotion) -> String {
        String(
            format: ",,%f,%f,%f,%.0f,,,,,,,,,,%f,%f,%f,%f,%f,%f,%f\n",
            tripMotion.x,
            tripMotion.y,
            tripMotion.z,
            round(tripMotion.timestamp * 1000.0),
            tripMotion.xl,
            tripMotion.yl,
            tripMotion.zl,
            tripMotion.xr,
            tripMotion.yr,
            tripMotion.zr,
            tripMotion.cr
        )
    }

    private func convertTripLocationToDictionary(_ tripLocation: TripLocation) -> [String: Any] {
        var dict: [String: Any] = [
            "lat": tripLocation.location.coordinate.latitude,
            "lon": tripLocation.location.coordinate.longitude,
            "alt": tripLocation.location.altitude,
            "horizontalAccuracy": tripLocation.location.horizontalAccuracy,
            "verticalAccuracy": tripLocation.location.verticalAccuracy,
            "speed": tripLocation.location.speed,
            "course": tripLocation.location.course,
            "timestamp": tripLocation.location.timestamp.timeIntervalSince1970,
            "minOfMotionsX": tripLocation.minOfMotionsX,
            "maxOfMotionsX": tripLocation.maxOfMotionsX,
            "minOfMotionsY": tripLocation.minOfMotionsY,
            "maxOfMotionsY": tripLocation.maxOfMotionsY,
            "minOfMotionsZ": tripLocation.minOfMotionsZ,
            "maxOfMotionsZ": tripLocation.maxOfMotionsZ
        ]

        if let gyro = tripLocation.gyro {
            dict["gyro"] = [
                "x": gyro.x,
                "y": gyro.y,
                "z": gyro.z
            ]
        }

        if let closePassInfo = tripLocation.closePassInfo {
            dict["closePassInfo"] = [
                "leftSensorValue": closePassInfo.leftSensorValue?.intValue ?? -1,
                "rightSensorValue": closePassInfo.rightSensorValue?.intValue ?? -1,
                "leftSensor1Value": closePassInfo.leftSensor1Value?.intValue ?? -1,
                "leftSensor2Value": closePassInfo.leftSensor2Value?.intValue ?? -1,
                "rightSensor1Value": closePassInfo.rightSensor1Value?.intValue ?? -1,
                "rightSensor2Value": closePassInfo.rightSensor2Value?.intValue ?? -1
            ]
        }

        if let annotation = tripLocation.tripAnnotation {
            dict["tripAnnotation"] = [
                "incidentId": annotation.incidentId,
                "bus": annotation.bus,
                "bicycle": annotation.bicycle,
                "pedestrian": annotation.pedestrian,
                "delivery": annotation.delivery,
                "commercial": annotation.commercial,
                "motorcycle": annotation.motorcycle,
                "car": annotation.car,
                "taxi": annotation.taxi,
                "other": annotation.other,
                "escooter": annotation.escooter,
                "frightening": annotation.frightening,
                "source": annotation.source,
                "comment": annotation.comment ?? ""
            ]
        }

        let motionsArray = NSMutableArray()
        for case let motion as TripMotion in tripLocation.tripMotions {
            motionsArray.add([
                "x": motion.x,
                "y": motion.y,
                "z": motion.z,
                "xl": motion.xl,
                "yl": motion.yl,
                "zl": motion.zl,
                "xr": motion.xr,
                "yr": motion.yr,
                "zr": motion.zr,
                "cr": motion.cr,
                "timestamp": motion.timestamp
            ])
        }
        dict["tripMotions"] = motionsArray

        return dict
    }

    private static func tripLocation(fromDictionary dict: [String: Any]) -> TripLocation? {
        guard let lat = dict["lat"] as? Double,
              let lon = dict["lon"] as? Double else {
            return nil
        }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: dict["alt"] as? Double ?? 0.0,
            horizontalAccuracy: dict["horizontalAccuracy"] as? Double ?? 0.0,
            verticalAccuracy: dict["verticalAccuracy"] as? Double ?? 0.0,
            course: dict["course"] as? Double ?? 0.0,
            speed: dict["speed"] as? Double ?? 0.0,
            timestamp: Date(timeIntervalSince1970: dict["timestamp"] as? Double ?? Date().timeIntervalSince1970)
        )

        let tripLocation = TripLocation()
        tripLocation.location = location
        tripLocation.minOfMotionsX = dict["minOfMotionsX"] as? Double ?? 0.0
        tripLocation.maxOfMotionsX = dict["maxOfMotionsX"] as? Double ?? 0.0
        tripLocation.minOfMotionsY = dict["minOfMotionsY"] as? Double ?? 0.0
        tripLocation.maxOfMotionsY = dict["maxOfMotionsY"] as? Double ?? 0.0
        tripLocation.minOfMotionsZ = dict["minOfMotionsZ"] as? Double ?? 0.0
        tripLocation.maxOfMotionsZ = dict["maxOfMotionsZ"] as? Double ?? 0.0

        if let gyroDict = dict["gyro"] as? [String: Any] {
            let gyro = TripGyro()
            gyro.x = gyroDict["x"] as? Double ?? 0.0
            gyro.y = gyroDict["y"] as? Double ?? 0.0
            gyro.z = gyroDict["z"] as? Double ?? 0.0
            tripLocation.gyro = gyro
        }

        if let closePassDict = dict["closePassInfo"] as? [String: Any] {
            let closePass = ClosePassInfo()
            closePass.leftSensorValue = NSNumber(value: closePassDict["leftSensorValue"] as? Int ?? -1)
            closePass.rightSensorValue = NSNumber(value: closePassDict["rightSensorValue"] as? Int ?? -1)
            closePass.leftSensor1Value = NSNumber(value: closePassDict["leftSensor1Value"] as? Int ?? -1)
            closePass.leftSensor2Value = NSNumber(value: closePassDict["leftSensor2Value"] as? Int ?? -1)
            closePass.rightSensor1Value = NSNumber(value: closePassDict["rightSensor1Value"] as? Int ?? -1)
            closePass.rightSensor2Value = NSNumber(value: closePassDict["rightSensor2Value"] as? Int ?? -1)
            tripLocation.closePassInfo = closePass
        }

        if let annotationDict = dict["tripAnnotation"] as? [String: Any] {
            let annotation = TripAnnotation()
            annotation.incidentId = annotationDict["incidentId"] as? Int ?? 0
            annotation.bus = annotationDict["bus"] as? Bool ?? false
            annotation.bicycle = annotationDict["bicycle"] as? Bool ?? false
            annotation.pedestrian = annotationDict["pedestrian"] as? Bool ?? false
            annotation.delivery = annotationDict["delivery"] as? Bool ?? false
            annotation.commercial = annotationDict["commercial"] as? Bool ?? false
            annotation.motorcycle = annotationDict["motorcycle"] as? Bool ?? false
            annotation.car = annotationDict["car"] as? Bool ?? false
            annotation.taxi = annotationDict["taxi"] as? Bool ?? false
            annotation.other = annotationDict["other"] as? Bool ?? false
            annotation.escooter = annotationDict["escooter"] as? Bool ?? false
            annotation.frightening = annotationDict["frightening"] as? Bool ?? false
            annotation.source = annotationDict["source"] as? String ?? "Manual"
            annotation.comment = annotationDict["comment"] as? String
            tripLocation.tripAnnotation = annotation
        }

        if let motions = dict["tripMotions"] as? [[String: Any]] {
            for motionDict in motions {
                let motion = TripMotion()
                motion.x = motionDict["x"] as? Double ?? 0.0
                motion.y = motionDict["y"] as? Double ?? 0.0
                motion.z = motionDict["z"] as? Double ?? 0.0
                motion.xl = motionDict["xl"] as? Double ?? 0.0
                motion.yl = motionDict["yl"] as? Double ?? 0.0
                motion.zl = motionDict["zl"] as? Double ?? 0.0
                motion.xr = motionDict["xr"] as? Double ?? 0.0
                motion.yr = motionDict["yr"] as? Double ?? 0.0
                motion.zr = motionDict["zr"] as? Double ?? 0.0
                motion.cr = motionDict["cr"] as? Double ?? 0.0
                motion.timestamp = motionDict["timestamp"] as? Double ?? Date().timeIntervalSince1970
                tripLocation.tripMotions.add(motion)
            }
        }

        return tripLocation
    }

    private static func tripLocation(fromCSVLine line: String) -> TripLocation? {
        let fields = line.components(separatedBy: ",")
        guard fields.count >= 7,
              let lat = Double(fields[0]),
              let lon = Double(fields[1]),
              let timestampMs = Double(fields[5]),
              let horizontalAccuracy = Double(fields[6]) else {
            return nil
        }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: 0.0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 0.0,
            course: 0.0,
            speed: 0.0,
            timestamp: Date(timeIntervalSince1970: timestampMs / 1000.0)
        )

        let tripLocation = TripLocation()
        tripLocation.location = location

        if fields.count >= 10 {
            let gyro = TripGyro()
            gyro.x = Double(fields[7]) ?? 0.0
            gyro.y = Double(fields[8]) ?? 0.0
            gyro.z = Double(fields[9]) ?? 0.0
            tripLocation.gyro = gyro
        }

        return tripLocation
    }

    private static func tripMotion(fromCSVLine line: String) -> TripMotion? {
        let fields = line.components(separatedBy: ",")
        guard fields.count >= 6,
              let x = Double(fields[2]),
              let y = Double(fields[3]),
              let z = Double(fields[4]),
              let timestampMs = Double(fields[5]) else {
            return nil
        }

        let motion = TripMotion()
        motion.x = x
        motion.y = y
        motion.z = z
        motion.timestamp = timestampMs / 1000.0

        if fields.count >= 22 {
            motion.xl = Double(fields[15]) ?? 0.0
            motion.yl = Double(fields[16]) ?? 0.0
            motion.zl = Double(fields[17]) ?? 0.0
            motion.xr = Double(fields[18]) ?? 0.0
            motion.yr = Double(fields[19]) ?? 0.0
            motion.zr = Double(fields[20]) ?? 0.0
            motion.cr = Double(fields[21]) ?? 0.0
        }

        return motion
    }
}
