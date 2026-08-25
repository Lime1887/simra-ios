import ActivityKit

@available(iOS 16.2, *)
public struct SimRaRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsedSeconds: Int
        public var distanceMeters: Int
        public var incidents: Int

        public init(
            elapsedSeconds: Int,
            distanceMeters: Int,
            incidents: Int
        ) {
            self.elapsedSeconds = elapsedSeconds
            self.distanceMeters = distanceMeters
            self.incidents = incidents
        }
    }

    public var tripId: Int
    public var bikeTypeId: Int

    public init(
        tripId: Int,
        bikeTypeId: Int
    ) {
        self.tripId = tripId
        self.bikeTypeId = bikeTypeId
    }
}
