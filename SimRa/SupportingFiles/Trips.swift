// Trips.swift
class Trips: UploaderObject {
    var tripInfos: [NSNumber: TripInfo] = [:]
    
    func newTrip() -> Trip {
        let trip = Trip()
        let tripInfo = trip.tripInfo
        tripInfos[trip.identifier] = tripInfo
        return trip
    }
    
    func deleteTripWithIdentifier(_ identifier: Int) {
        tripInfos.removeValue(forKey: NSNumber(value: identifier))
    }
    
    func updateTrip(_ trip: Trip) {
        let tripInfo = trip.tripInfo
        tripInfos[trip.identifier] = tripInfo
    }
}

class UploaderObject {
    // Placeholder class for UploaderObject
}
