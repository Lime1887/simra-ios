import Foundation
import CoreLocation

@objcMembers
public class Region: NSObject {
    public var position: Int = 0
    public var identifier: String = ""
    public var englishDescription: String?
    public var germanDescription: String?
    public var lat: NSNumber?
    public var lon: NSNumber?

    override public init() {
        super.init()
    }

    override public var localizedDescription: String {
        let strLoc = Bundle.preferredLocalizations(from: ["en", "de"]).first ?? "en"
        return (strLoc == "de" ? germanDescription : englishDescription) ?? identifier
    }

    public func location() -> CLLocation? {
        guard let latNum = lat, let lonNum = lon, (latNum.doubleValue != 0.0 || lonNum.doubleValue != 0.0) else {
            return nil
        }
        return CLLocation(latitude: latNum.doubleValue, longitude: lonNum.doubleValue)
    }

    public func distanceFrom(_ location: CLLocation?) -> CLLocationDistance {
        guard let myLocation = self.location(), let targetLocation = location else {
            return 400000000
        }
        return myLocation.distance(from: targetLocation)
    }
}