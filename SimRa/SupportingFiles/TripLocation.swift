// TripLocation.swift
class TripLocation {
    var location: CLLocation?
    var tripMotions: [TripMotion] = []
    var tripAnnotation: TripAnnotation?
    
    var minOfMotionsX: Double = 0.0
    var minOfMotionsY: Double = 0.0
    var minOfMotionsZ: Double = 0.0
    var maxOfMotionsX: Double = 0.0
    var maxOfMotionsY: Double = 0.0
    var maxOfMotionsZ: Double = 0.0
    
    var largestXMotion: TripLocation?
    var secondLargestXMotion: TripLocation?
    var largestYMotion: TripLocation?
    var secondLargestYMotion: TripLocation?
    var largestZMotion: TripLocation?
    var secondLargestZMotion: TripLocation?
}
