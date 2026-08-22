import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@available(iOS 16.2, *)
public struct SimRaRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsedSeconds: Int
        public var distanceMeters: Int
        public var incidents: Int
        
        public init(elapsedSeconds: Int, distanceMeters: Int, incidents: Int) {
            self.elapsedSeconds = elapsedSeconds
            self.distanceMeters = distanceMeters
            self.incidents = incidents
        }
    }
    
    public var tripId: Int
    public var bikeTypeId: Int
    
    public init(tripId: Int, bikeTypeId: Int) {
        self.tripId = tripId
        self.bikeTypeId = bikeTypeId
    }
}

@objcMembers
public final class LiveActivityManager: NSObject {
    
    public static let shared = LiveActivityManager()
    
    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private var currentActivity: Activity<SimRaRecordingAttributes>?
    #else
    private var currentActivity: Any? = nil
    #endif
    
    private override init() {
        super.init()
    }
    
    @objc
    public func startActivity(tripId: Int, bikeTypeId: Int) {
        if #available(iOS 16.2, *) {
            let attributes = SimRaRecordingAttributes(tripId: tripId, bikeTypeId: bikeTypeId)
            let initialContentState = SimRaRecordingAttributes.ContentState(elapsedSeconds: 0, distanceMeters: 0, incidents: 0)
            
            Task {
                do {
                    let activity = try await Activity<SimRaRecordingAttributes>.request(
                        attributes: attributes,
                        contentState: initialContentState,
                        pushType: nil)
                    self.currentActivity = activity
                } catch {
                    // silently ignore or handle error as needed
                }
            }
        }
    }
    
    @objc
    public func update(elapsedSeconds: Int, distanceMeters: Int, incidents: Int) {
        if #available(iOS 16.2, *) {
            Task {
                guard let activity = currentActivity else { return }
                let updatedContentState = SimRaRecordingAttributes.ContentState(
                    elapsedSeconds: elapsedSeconds,
                    distanceMeters: distanceMeters,
                    incidents: incidents)
                await activity.update(using: updatedContentState)
            }
        }
    }
    
    @objc
    public func endActivity() {
        if #available(iOS 16.2, *) {
            Task {
                if let activity = currentActivity {
                    await activity.end(dismissalPolicy: .immediate)
                    self.currentActivity = nil
                }
            }
        }
    }
}
