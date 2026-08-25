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
    private var recordingStartDate: Date?

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

        guard let documentDirectory = documentsDirectoryURL() else { return nil }
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

        if tripAnnotations == 0, let location = tripLocations.firstObject as? TripLocation {
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
        let locationsURL = documentDirectoryURL?.appendingPathComponent("TripLocations-\(identifier).csv")
        let motionsURL = documentDirectoryURL?.appendingPathComponent("TripMotions-\(identifier).csv")

        let locationsHandle = locationsURL.flatMap { FileHandle(forReadingAtPath: $0.path) }
        let motionsHandle = motionsURL.flatMap { FileHandle(forReadingAtPath: $0.path) }

        if let locationsHandle, let motionsHandle {
            var locationsString = Self.readline(locationsHandle)
            var motionsString = Self.readline(motionsHandle)

            while locationsString != nil || motionsString != nil {
                if let locationLine = locationsString, let motionLine = motionsString {
                    let locationArray = locationLine.components(separatedBy: ",")
                    let motionArray = motionLine.components(separatedBy: ",")
                    let locationTime = Double(locationArray[safe: 5] ?? "0") ?? 0
                    let motionTime = Double(motionArray[safe: 5] ?? "0") ?? 0
                    if locationTime <= motionTime {
                        if let data = locationLine.data(using: .utf8) { fh.write(data) }
                        locationsString = Self.readline(locationsHandle)
                    } else {
                        if let data = motionLine.data(using: .utf8) { fh.write(data) }
                        motionsString = Self.readline(motionsHandle)
                    }
                } else if let locationLine = locationsString {
                    if let data = locationLine.data(using: .utf8) { fh.write(data) }
                    locationsString = Self.readline(locationsHandle)
                } else if let motionLine = motionsString {
                    if let data = motionLine.data(using: .utf8) { fh.write(data) }
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
                        guard let firstTime = locationLines.keys.sorted().first else { break }
                        if firstTime.doubleValue < motionTime.doubleValue {
                            if let data = (locationLines[firstTime] ?? "").data(using: .utf8) {
                                fh.write(data)
                            }
                            locationLines.removeValue(forKey: firstTime)
                        } else {
                            break
                        }
                    }

                    if let data = csvLine.data(using: .utf8) {
                        fh.write(data)
                    }
                }
            }
        }

        try? fh.close()
        return fileURL
    }

    public override func save() {
        guard let appDelegate else { return }
        appDelegate.trips.updateTrip(self)

        let fileManager = FileManager.default
        let documentDirectoryURL = Self.documentsDirectoryURL()
        let tripURL = documentDirectoryURL.appendingPathComponent("Trip-\(identifier).json")
        let tripInfoURL = documentDirectoryURL.appendingPathComponent("TripInfo-\(identifier).json")

        let tripSuccess = (asJSONData() as NSData?)?.write(to: tripURL, options: .atomic, error: nil) ?? false
        let tripInfoSuccess = (tripInfo().asJSONData() as NSData?)?.write(to: tripInfoURL, options: .atomic, error: nil) ?? false

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
        info.annotationsCount = tripAnnotations
        info.validAnnotationsCount = tripValidAnnotations
        return info
    }

    public override func uploadFile(_ name: String, withController controller: NSObject, error errorSelector: Selector, completion completionSelector: Selector) {
        var saveNecessary = false

        for case let location as TripLocation in tripLocations {
            if let annotation = location.tripAnnotation, annotation.incidentId == 0 {
                location.tripAnnotation = nil
                saveNecessary = true
            }
        }

        if tripAnnotations == 0, let location = tripLocations.firstObject as? TripLocation {
            let annotation = TripAnnotation()
            annotation.incidentId = -5
            location.tripAnnotation = annotation
            saveNecessary = true
        }

        if saveNecessary {
            save()
        }

        if !statisticsAdded {
            appDelegate?.trips.addTripToStatistics(self)
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
        var total: CLLocationDistance = 0
        var lastTripLocation: TripLocation?
        for case let tripLocation as TripLocation in tripLocations {
            if let lastTripLocation {
                total += tripLocation.location.distance(from: lastTripLocation.location)
            }
            lastTripLocation = tripLocation
        }
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
        saveRecordingCheckpoint()

        let fileManager = FileManager.default
        let documentDirectoryURL = Self.documentsDirectoryURL()
        let locationsURL = documentDirectoryURL.appendingPathComponent("TripLocations-\(identifier).csv")
        let motionsURL = documentDirectoryURL.appendingPathComponent("TripMotions-\(identifier).csv")

        fileManager.createFile(atPath: locationsURL.path, contents: Data(), attributes: nil)
        fileManager.createFile(atPath: motionsURL.path, contents: Data(), attributes: nil)
        locationsFile = FileHandle(forWritingAtPath: locationsURL.path)
        motionsFile = FileHandle(forWritingAtPath: motionsURL.path)
        recordingStartDate = Date()

        if appDelegate.mm.isGyroAvailable {
            appDelegate.mm.startGyroUpdates()
        }

        appDelegate.lm.delegate = self

        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            appDelegate.lm.requestWhenInUseAuthorization()
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            appDelegate.lm.allowsBackgroundLocationUpdates = true
            appDelegate.lm.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            appDelegate.lm.activityType = .fitness
            appDelegate.lm.startUpdatingLocation()
        }

        if appDelegate.mm.isAccelerometerAvailable {
            let accelerometerSamples = 30
            let accelerometerSteps = 5
            var xa = Array(repeating: 0.0, count: accelerometerSamples)
            var ya = Array(repeating: 0.0, count: accelerometerSamples)
            var za = Array(repeating: 0.0, count: accelerometerSamples)
            var xla = Array(repeating: 0.0, count: accelerometerSamples)
            var yla = Array(repeating: 0.0, count: accelerometerSamples)
            var zla = Array(repeating: 0.0, count: accelerometerSamples)
            var xra = Array(repeating: 0.0, count: accelerometerSamples)
            var yra = Array(repeating: 0.0, count: accelerometerSamples)
            var zra = Array(repeating: 0.0, count: accelerometerSamples)
            var cra = Array(repeating: 0.0, count: accelerometerSamples)
            var aIndex = 0
            var aFill = 0

            appDelegate.mm.accelerometerUpdateInterval = 1.0 / 50.0
            appDelegate.mm.startAccelerometerUpdates()
            if appDelegate.mm.isDeviceMotionAvailable {
                appDelegate.mm.deviceMotionUpdateInterval = 1.0 / 50.0
                appDelegate.mm.startDeviceMotionUpdates()
            }

            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 50.0, repeats: true) { [weak self, weak appDelegate] _ in
                guard let self, let appDelegate else { return }
                let accelerometerData = appDelegate.mm.accelerometerData
                let deviceMotion = appDelegate.mm.deviceMotion

                if let accelerometerData {
                    xa[aIndex] = accelerometerData.acceleration.x
                    ya[aIndex] = accelerometerData.acceleration.y
                    za[aIndex] = accelerometerData.acceleration.z
                    if let deviceMotion {
                        xla[aIndex] = deviceMotion.userAcceleration.x
                        yla[aIndex] = deviceMotion.userAcceleration.y
                        zla[aIndex] = deviceMotion.userAcceleration.z
                        xra[aIndex] = deviceMotion.attitude.quaternion.x
                        yra[aIndex] = deviceMotion.attitude.quaternion.y
                        zra[aIndex] = deviceMotion.attitude.quaternion.z
                        cra[aIndex] = deviceMotion.attitude.quaternion.w
                    } else {
                        xla[aIndex] = 0.0
                        yla[aIndex] = 0.0
                        zla[aIndex] = 0.0
                        xra[aIndex] = 0.0
                        yra[aIndex] = 0.0
                        zra[aIndex] = 0.0
                        cra[aIndex] = 0.0
                    }

                    aIndex = (aIndex + 1) % accelerometerSamples
                    aFill += 1

                    if aFill >= accelerometerSamples {
                        var x = 0.0
                        var y = 0.0
                        var z = 0.0
                        var xl = 0.0
                        var yl = 0.0
                        var zl = 0.0
                        var xr = 0.0
                        var yr = 0.0
                        var zr = 0.0
                        var cr = 0.0
                        for i in 0..<accelerometerSamples {
                            x += xa[i]
                            y += ya[i]
                            z += za[i]
                            xl += xla[i]
                            yl += yla[i]
                            zl += zla[i]
                            xr += xla[i]
                            yr += yla[i]
                            zr += zla[i]
                            cr += zla[i]
                        }
                        x /= Double(accelerometerSamples)
                        y /= Double(accelerometerSamples)
                        z /= Double(accelerometerSamples)
                        xl /= Double(accelerometerSamples)
                        yl /= Double(accelerometerSamples)
                        zl /= Double(accelerometerSamples)
                        xr /= Double(accelerometerSamples)
                        yr /= Double(accelerometerSamples)
                        zr /= Double(accelerometerSamples)
                        cr /= Double(accelerometerSamples)

                        self.addAcceleration(x: x, y: y, z: z, xl: xl, yl: yl, zl: zl, xr: xr, yr: yr, zr: zr, cr: cr)
                        aFill = accelerometerSamples - accelerometerSteps
                    }
                }
            }
        }
    }

    public func stopRecording() {
        let appDelegate = AppDelegate.shared()
        timer?.invalidate()
        timer = nil

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
        if startLocation == nil {
            startLocation = location
        }

        let previousTripLocation = tripLocations.lastObject as? TripLocation
        let appDelegate = AppDelegate.shared()
        let deferredSecs = appDelegate.defaults.integer(forKey: "deferredSecs")
        let deferredMeters = appDelegate.defaults.integer(forKey: "deferredMeters")
        let now = Date().timeIntervalSince1970

        if ((deferredSecs == 0 || now - (startLocation?.timestamp.timeIntervalSince1970 ?? now) > Double(deferredSecs)) &&
            (deferredMeters == 0 || location.distance(from: startLocation ?? location) > Double(deferredMeters))) {
            let newLocation = TripLocation()
            newLocation.location = location
            let gyro = TripGyro()
            gyro.x = gyroData?.rotationRate.x ?? 0
            gyro.y = gyroData?.rotationRate.y ?? 0
            gyro.z = gyroData?.rotationRate.z ?? 0
            tripLocations.add(newLocation)
            let csvString = locationString(from: newLocation, gyro: gyro, closePassInfo: nil)
            if let data = csvString.data(using: .utf8) {
                locationsFile?.write(data)
                try? locationsFile?.synchronize()
            }
            newLocation.gyro = gyro

            if let previousTripLocation {
                let lastX = previousTripLocation.maxOfMotionsX - previousTripLocation.minOfMotionsX
                if let largestXMotion {
                    let largestX = largestXMotion.maxOfMotionsX - largestXMotion.minOfMotionsX
                    if lastX > largestX {
                        secondLargestXMotion = largestXMotion
                        largestXMotion = previousTripLocation
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
                        secondLargestYMotion = largestYMotion
                        largestYMotion = previousTripLocation
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
                        secondLargestZMotion = largestZMotion
                        largestZMotion = previousTripLocation
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
            try? motionsFile?.synchronize()
        }

        lastTripLocation.minOfMotionsX = min(lastTripLocation.minOfMotionsX, tripMotion.x)
        lastTripLocation.minOfMotionsY = min(lastTripLocation.minOfMotionsY, tripMotion.y)
        lastTripLocation.minOfMotionsZ = min(lastTripLocation.minOfMotionsZ, tripMotion.z)
        lastTripLocation.maxOfMotionsX = max(lastTripLocation.maxOfMotionsX, tripMotion.x)
        lastTripLocation.maxOfMotionsY = max(lastTripLocation.maxOfMotionsY, tripMotion.y)
        lastTripLocation.maxOfMotionsZ = max(lastTripLocation.maxOfMotionsZ, tripMotion.z)
    }

    public func durationStartDate() -> Date? {
        (duration() as DateInterval?)?.start
    }

    public func durationEndDate() -> Date? {
        (duration() as DateInterval?)?.end
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
            "trailer": trailer
        ]
    }

    public static func allStoredIdentifiers() -> [NSNumber] {
        var identifiers: [Int] = []
        let defaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys.sorted()

        for key in defaultsKeys where key.hasPrefix("Trip-") {
            let id = Int(key.dropFirst("Trip-".count)) ?? 0
            if id > 0 {
                print("[Trip] move from NSUserDefaults to Files \(id)")
                if let trip = Trip(fromStorage: id) {
                    trip.save()
                }
            }
        }

        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: documentDirectory.path) {
            for content in contents where content.hasPrefix("Trip-") {
                let id = Int(content.dropFirst("Trip-".count).dropLast(".json".count)) ?? 0
                if id > 0 && !identifiers.contains(id) {
                    identifiers.append(id)
                }
            }
        }

        return identifiers.map { NSNumber(value: $0) }
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

        var locationEntries: [(timestamp: Double, location: TripLocation)] = []
        for line in locationsString.components(separatedBy: .newlines) where !line.isEmpty {
            guard let location = tripLocation(fromCSVLine: line) else { continue }
            let fields = line.components(separatedBy: ",")
            let timestamp = Double(fields[safe: 5] ?? "0") ?? 0
            locationEntries.append((timestamp: timestamp, location: location))
        }

        var motionEntries: [(timestamp: Double, motion: TripMotion)] = []
        for line in motionsString.components(separatedBy: .newlines) where !line.isEmpty {
            guard let motion = tripMotion(fromCSVLine: line) else { continue }
            let fields = line.components(separatedBy: ",")
            let timestamp = Double(fields[safe: 5] ?? "0") ?? 0
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

    private static func tripLocation(fromDictionary dict: [String: Any]) -> TripLocation? {
        guard let timestamp = (dict["timestamp"] as? NSNumber)?.doubleValue,
              let lat = (dict["lat"] as? NSNumber)?.doubleValue,
              let lon = (dict["lon"] as? NSNumber)?.doubleValue else {
            return nil
        }

        let speed = (dict["speed"] as? NSNumber)?.doubleValue ?? 0
        let horizontalAccuracy = (dict["horizontalAccuracy"] as? NSNumber)?.doubleValue ?? 0
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: -1,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: speed,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )

        let tripLocation = TripLocation(location: location)

        if let a = dict["a"] as? NSNumber,
           let b = dict["b"] as? NSNumber,
           let c = dict["c"] as? NSNumber {
            let gyro = TripGyro()
            gyro.x = a.doubleValue
            gyro.y = b.doubleValue
            gyro.z = c.doubleValue
            tripLocation.gyro = gyro
        }

        if let leftSensorValue = dict["leftSensorVal"] as? NSNumber,
           let rightSensorValue = dict["rightSensorVal"] as? NSNumber {
            let closePass = ClosePassInfo()
            closePass.leftSensorValue = leftSensorValue
            closePass.rightSensorValue = rightSensorValue
            tripLocation.closePassInfo = closePass
        }

        tripLocation.tripMotions = NSMutableArray()
        if let tripMotionsArray = dict["tripMotions"] as? [[String: Any]] {
            for tripMotionDict in tripMotionsArray {
                let tripMotion = TripMotion()
                tripMotion.x = (tripMotionDict["x"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.y = (tripMotionDict["y"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.z = (tripMotionDict["z"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.xl = (tripMotionDict["xl"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.yl = (tripMotionDict["yl"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.zl = (tripMotionDict["zl"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.xr = (tripMotionDict["xr"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.yr = (tripMotionDict["yr"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.zr = (tripMotionDict["zr"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.cr = (tripMotionDict["cr"] as? NSNumber)?.doubleValue ?? 0
                tripMotion.timestamp = (tripMotionDict["timestamp"] as? NSNumber)?.doubleValue ?? 0
                tripLocation.tripMotions.add(tripMotion)
            }
        }

        if let tripAnnotationDict = dict["tripAnnotation"] as? [String: Any] {
            let tripAnnotation = TripAnnotation()
            tripAnnotation.incidentId = (tripAnnotationDict["incidentId"] as? NSNumber)?.intValue ?? 0
            tripAnnotation.frightening = (tripAnnotationDict["frightening"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.car = (tripAnnotationDict["car"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.bus = (tripAnnotationDict["bus"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.taxi = (tripAnnotationDict["taxi"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.commercial = (tripAnnotationDict["commercial"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.delivery = (tripAnnotationDict["delivery"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.bicycle = (tripAnnotationDict["bicycle"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.motorcycle = (tripAnnotationDict["motorcycle"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.pedestrian = (tripAnnotationDict["pedestrian"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.other = (tripAnnotationDict["other"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.escooter = (tripAnnotationDict["escooter"] as? NSNumber)?.boolValue ?? false
            tripAnnotation.comment = tripAnnotationDict["comment"] as? String
            tripLocation.tripAnnotation = tripAnnotation
        }

        return tripLocation
    }

    private static func tripLocation(fromCSVLine line: String) -> TripLocation? {
        let fields = line.components(separatedBy: ",")
        guard fields.count >= 6,
              let lat = Double(fields[0]),
              let lon = Double(fields[1]),
              let timestampMs = Double(fields[5]) else {
            return nil
        }

        let accuracy = (fields.count > 6 && !fields[6].isEmpty) ? (Double(fields[6]) ?? -1) : -1
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: -1,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: Date(timeIntervalSince1970: timestampMs / 1000.0)
        )

        let tripLocation = TripLocation(location: location)

        if fields.count > 9 {
            let hasGyro = !fields[7].isEmpty || !fields[8].isEmpty || !fields[9].isEmpty
            if hasGyro {
                let gyro = TripGyro()
                gyro.x = Double(fields[7]) ?? 0
                gyro.y = Double(fields[8]) ?? 0
                gyro.z = Double(fields[9]) ?? 0
                tripLocation.gyro = gyro
            }
        }

        var hasClosePass = fields.count > 14 && Int(fields[14]) == 1
        if !hasClosePass && fields.count > 13 {
            hasClosePass = !fields[10].isEmpty || !fields[11].isEmpty || !fields[12].isEmpty || !fields[13].isEmpty
        }

        if hasClosePass {
            let closePassInfo = ClosePassInfo()
            closePassInfo.location = location
            if fields.count > 10, !fields[10].isEmpty { closePassInfo.leftSensor1Value = NSNumber(value: Double(fields[10]) ?? 0) }
            if fields.count > 11, !fields[11].isEmpty { closePassInfo.leftSensor2Value = NSNumber(value: Double(fields[11]) ?? 0) }
            if fields.count > 12, !fields[12].isEmpty { closePassInfo.rightSensor1Value = NSNumber(value: Double(fields[12]) ?? 0) }
            if fields.count > 13, !fields[13].isEmpty { closePassInfo.rightSensor2Value = NSNumber(value: Double(fields[13]) ?? 0) }
            tripLocation.closePassInfo = closePassInfo

            let tripAnnotation = TripAnnotation()
            tripAnnotation.incidentId = 1
            tripLocation.tripAnnotation = tripAnnotation
        }

        return tripLocation
    }

    private static func tripMotion(fromCSVLine line: String) -> TripMotion? {
        let fields = line.components(separatedBy: ",")
        guard fields.count >= 22 else { return nil }

        let tripMotion = TripMotion()
        tripMotion.x = Double(fields[2]) ?? 0
        tripMotion.y = Double(fields[3]) ?? 0
        tripMotion.z = Double(fields[4]) ?? 0
        tripMotion.timestamp = (Double(fields[5]) ?? 0) / 1000.0
        tripMotion.xl = Double(fields[15]) ?? 0
        tripMotion.yl = Double(fields[16]) ?? 0
        tripMotion.zl = Double(fields[17]) ?? 0
        tripMotion.xr = Double(fields[18]) ?? 0
        tripMotion.yr = Double(fields[19]) ?? 0
        tripMotion.zr = Double(fields[20]) ?? 0
        tripMotion.cr = Double(fields[21]) ?? 0
        return tripMotion
    }

    private func locationString(from tripLocation: TripLocation, gyro: TripGyro?, closePassInfo: ClosePassInfo?) -> String {
        let lat = tripLocation.location.coordinate.latitude
        let lon = tripLocation.location.coordinate.longitude
        let horizontalAccuracy = tripLocation.location.horizontalAccuracy

        var csvString = String(format: "%f,%f,", lat, lon)
        csvString += String(format: "%f,%f,%f,%.0f,", 0.0, 0.0, 0.0, round(tripLocation.location.timestamp.timeIntervalSince1970) * 1000.0)

        if horizontalAccuracy == -1.0 {
            csvString += ","
        } else {
            csvString += String(format: "%f,", horizontalAccuracy)
        }

        if let gyro {
            csvString += String(format: "%f,%f,%f,", gyro.x, gyro.y, gyro.z)
        } else {
            csvString += ",,,"
        }

        var isClosePassEvent = "0"
        var leftSensorVal1 = ""
        var leftSensorVal2 = ""
        var rightSensorVal1 = ""
        var rightSensorVal2 = ""

        if let closePassInfo {
            isClosePassEvent = "1"
            leftSensorVal1 = closePassInfo.leftSensor1Value?.stringValue ?? ""
            leftSensorVal2 = closePassInfo.leftSensor2Value?.stringValue ?? ""
            rightSensorVal1 = closePassInfo.rightSensor1Value?.stringValue ?? ""
            rightSensorVal2 = closePassInfo.rightSensor2Value?.stringValue ?? ""
        }

        csvString += "\(leftSensorVal1),\(leftSensorVal2),\(rightSensorVal1),\(rightSensorVal2),\(isClosePassEvent),"
        csvString += ",,,,,,"
        csvString += "\n"
        return csvString
    }

    private func motionString(from tripMotion: TripMotion) -> String {
        var csvString = ",,"
        csvString += String(format: "%f,%f,%f,%.0f,", tripMotion.x * 9.81, tripMotion.y * 9.81, tripMotion.z * 9.81, tripMotion.timestamp * 1000.0)
        csvString += ","
        csvString += ",,,"
        csvString += ",,,,,"
        csvString += String(format: "%f,%f,%f,%f,%f,%f,%f", tripMotion.xl * 9.81, tripMotion.yl * 9.81, tripMotion.zl * 9.81, tripMotion.xr, tripMotion.yr, tripMotion.zr, tripMotion.cr)
        csvString += "\n"
        return csvString
    }

    private static func readline(_ handle: FileHandle) -> String? {
        var line: String?
        while true {
            let data = handle.readData(ofLength: 1)
            if data.isEmpty { break }
            if line == nil { line = "" }
            guard let character = String(data: data, encoding: .utf8) else { continue }
            line?.append(character)
            if character == "\n" { break }
        }
        return line
    }
}

@objcMembers
public class Trips: UploaderObject {
    private unowned let appDelegate: AppDelegate
    public private(set) var tripInfos: [NSNumber: TripInfo] = [:]

    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        self.appDelegate.trips = self

        self.version = appDelegate.defaults.integer(forKey: "version")
        self.uploaded = appDelegate.defaults.bool(forKey: "uploaded")
        self.fileHash = appDelegate.defaults.string(forKey: "fileHash")
        self.filePasswd = appDelegate.defaults.string(forKey: "filePasswd")

        Trip.recoverIncompleteTrips()

        let allTripInfos = TripInfo.allStoredIdentifiers().sorted { $0.compare($1) == .orderedAscending }
        for identifierNumber in allTripInfos {
            let identifier = identifierNumber.intValue
            if let tripInfo = TripInfo(fromStorage: identifier) {
                tripInfos[NSNumber(value: tripInfo.identifier)] = tripInfo
            }
        }

        let allTrips = Trip.allStoredIdentifiers().sorted { $0.compare($1) == .orderedAscending }
        for identifierNumber in allTrips {
            let identifier = identifierNumber.intValue
            let key = NSNumber(value: identifier)
            if let tripInfo = tripInfos[key], tripInfo.annotationsCount != 0 {
                continue
            }
            if let trip = Trip(fromStorage: identifier) {
                let tripInfo = trip.tripInfo()
                tripInfos[NSNumber(value: trip.identifier)] = tripInfo
                trip.save()
            }
        }

        if !appDelegate.defaults.bool(forKey: "copyStatisticsOnce") {
            Utility.saveBool(key: "copyStatisticsOnce", value: true)
            if appDelegate.regions.regionSelected {
                save()
                let totalRides = appDelegate.defaults.integer(forKey: "totalRides")
                let totalDuration = appDelegate.defaults.integer(forKey: "totalDuration")
                let totalIncidents = appDelegate.defaults.integer(forKey: "totalIncidents")
                let totalLength = appDelegate.defaults.integer(forKey: "totalLength")
                let totalIdle = appDelegate.defaults.integer(forKey: "totalIdle")
                let numberOfScary = appDelegate.defaults.integer(forKey: "numberOfScary")
                var totalSlots = (appDelegate.defaults.array(forKey: "totalSlots") as? [Int]) ?? Array(repeating: 0, count: 24)
                if totalSlots.count < 24 {
                    totalSlots = Array(repeating: 0, count: 24)
                }

                Utility.saveInt(key: withRegionId("totalRides", regionId: appDelegate.regions.regionId), value: totalRides)
                Utility.saveInt(key: withRegionId("totalDuration", regionId: appDelegate.regions.regionId), value: totalDuration)
                Utility.saveInt(key: withRegionId("totalIncidents", regionId: appDelegate.regions.regionId), value: totalIncidents)
                Utility.saveInt(key: withRegionId("totalLength", regionId: appDelegate.regions.regionId), value: totalLength)
                Utility.saveInt(key: withRegionId("totalIdle", regionId: appDelegate.regions.regionId), value: totalIdle)
                Utility.saveInt(key: withRegionId("numberOfScary", regionId: appDelegate.regions.regionId), value: numberOfScary)
                Utility.saveArray(key: withRegionId("totalSlots", regionId: appDelegate.regions.regionId), value: totalSlots as NSArray)
            }
        }
    }

    public convenience override init() {
        self.init(appDelegate: AppDelegate.shared())
    }

    public func newTrip() -> Trip {
        let trip = Trip()
        tripInfos[NSNumber(value: trip.identifier)] = trip.tripInfo()
        return trip
    }

    public func deleteTripWithIdentifier(_ identifier: Int) {
        tripInfos.removeValue(forKey: NSNumber(value: identifier))
        Trip.deleteFromStorage(identifier)
    }

    public func updateTrip(_ trip: Trip) {
        tripInfos[NSNumber(value: trip.identifier)] = trip.tripInfo()
    }

    public func addTripToStatistics(_ trip: Trip) {
        addTripToStatistics(trip, regionId: 0)
        if appDelegate.regions.regionSelected {
            addTripToStatistics(trip, regionId: appDelegate.regions.regionId)
        }
    }

    private func addTripToStatistics(_ trip: Trip, regionId: Int) {
        let totalRides = appDelegate.defaults.integer(forKey: withRegionId("totalRides", regionId: regionId)) + 1
        let totalDuration = appDelegate.defaults.integer(forKey: withRegionId("totalDuration", regionId: regionId)) + Int((trip.duration()?.duration ?? 0) * 1000.0)
        let totalIncidents = appDelegate.defaults.integer(forKey: withRegionId("totalIncidents", regionId: regionId)) + trip.tripValidAnnotations()
        let totalLength = appDelegate.defaults.integer(forKey: withRegionId("totalLength", regionId: regionId)) + trip.length()
        let totalIdle = appDelegate.defaults.integer(forKey: withRegionId("totalIdle", regionId: regionId)) + Int(Double(trip.idle()) * 1000.0)
        let numberOfScary = appDelegate.defaults.integer(forKey: withRegionId("numberOfScary", regionId: regionId)) + trip.numberOfScary()
        var totalSlots = (appDelegate.defaults.array(forKey: withRegionId("totalSlots", regionId: regionId)) as? [Int]) ?? Array(repeating: 0, count: 24)
        if totalSlots.count < 24 {
            totalSlots = Array(repeating: 0, count: 24)
        }

        if let start = trip.duration()?.startDate, let end = trip.duration()?.endDate {
            let calendar = Calendar(identifier: .gregorian)
            let startHour = calendar.component(.hour, from: start)
            let endHour = calendar.component(.hour, from: end)
            totalSlots[startHour] += 1
            totalSlots[endHour] += 1
        }

        Utility.saveInt(key: withRegionId("totalRides", regionId: regionId), value: totalRides)
        Utility.saveInt(key: withRegionId("totalDuration", regionId: regionId), value: totalDuration)
        Utility.saveInt(key: withRegionId("totalIncidents", regionId: regionId), value: totalIncidents)
        Utility.saveInt(key: withRegionId("totalLength", regionId: regionId), value: totalLength)
        Utility.saveInt(key: withRegionId("totalIdle", regionId: regionId), value: totalIdle)
        Utility.saveInt(key: withRegionId("numberOfScary", regionId: regionId), value: numberOfScary)
        Utility.saveArray(key: withRegionId("totalSlots", regionId: regionId), value: totalSlots as NSArray)
        Utility.writeProfile()
    }

    public override func csvFile() -> URL? {
        let fileManager = FileManager.default
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent("trips.csv")
        try? fileManager.removeItem(at: fileURL)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard let fh = FileHandle(forWritingAtPath: fileURL.path) else { return nil }

        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let major = bundleVersion.components(separatedBy: ".").first ?? bundleVersion
        var csvString = "i\(major)#\(version)\n"
        csvString += "birth,gender,region,experience,numberOfRides,duration,numberOfIncidents,length,idle,behaviour,numberOfScary"
        for i in 0..<24 {
            csvString += ",\(i)"
        }
        csvString += "\n"
        if let data = csvString.data(using: .utf8) {
            fh.write(data)
        }

        let defaults = appDelegate.defaults
        let regionId = appDelegate.regions.regionSelected ? appDelegate.regions.regionId : 0
        csvString = String(format: "%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%@,%ld",
                           defaults.integer(forKey: "ageId"),
                           defaults.integer(forKey: "sexId"),
                           regionId,
                           defaults.integer(forKey: "experienceId"),
                           defaults.integer(forKey: withRegionId("totalRides", regionId: regionId)),
                           defaults.integer(forKey: withRegionId("totalDuration", regionId: regionId)),
                           defaults.integer(forKey: withRegionId("totalIncidents", regionId: regionId)),
                           defaults.integer(forKey: withRegionId("totalLength", regionId: regionId)),
                           defaults.integer(forKey: withRegionId("totalIdle", regionId: regionId)),
                           defaults.bool(forKey: "behaviour") ? String(defaults.integer(forKey: "behaviourValue")) : "",
                           defaults.integer(forKey: withRegionId("numberOfScary", regionId: regionId)))

        let totalSlots = defaults.array(forKey: withRegionId("totalSlots", regionId: regionId)) as? [Int] ?? Array(repeating: 0, count: 24)
        for i in 0..<24 {
            csvString += ",\(totalSlots[safe: i] ?? 0)"
        }
        csvString += "\n"
        if let data = csvString.data(using: .utf8) {
            fh.write(data)
        }
        try? fh.close()
        return fileURL
    }

    public override func save() {
        let regionId = appDelegate.regions.regionSelected ? appDelegate.regions.regionId : 0
        Utility.saveInt(key: withRegionId("version", regionId: regionId), value: version)
        Utility.saveBool(key: withRegionId("uploaded", regionId: regionId), value: uploaded)
        if let fileHash {
            Utility.saveString(key: withRegionId("fileHash", regionId: regionId), value: fileHash)
        }
        if let filePasswd {
            Utility.saveString(key: withRegionId("filePasswd", regionId: regionId), value: filePasswd)
        }
        if appDelegate.regions.regionSelected {
            Utility.writeRegionBasedProfile(regionId: appDelegate.regions.regionId)
        }
    }

    public override func uploadFile(_ name: String, withController controller: NSObject, error errorSelector: Selector, completion completionSelector: Selector) {
        let regionId = appDelegate.regions.regionSelected ? appDelegate.regions.regionId : 0
        version = appDelegate.defaults.integer(forKey: withRegionId("version", regionId: regionId))
        uploaded = appDelegate.defaults.bool(forKey: withRegionId("uploaded", regionId: regionId))
        fileHash = appDelegate.defaults.string(forKey: withRegionId("fileHash", regionId: regionId))
        filePasswd = appDelegate.defaults.string(forKey: withRegionId("filePasswd", regionId: regionId))
        super.uploadFile(name, withController: controller, error: errorSelector, completion: completionSelector)
    }

    private func withRegionId(_ key: String, regionId: Int) -> String {
        regionId == 0 ? key : "\(key)-\(regionId)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
