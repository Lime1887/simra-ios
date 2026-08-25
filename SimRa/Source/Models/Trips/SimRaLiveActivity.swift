import Foundation
import ActivityKit

#if canImport(ActivityKit)

@available(iOS 16.2, *)
struct SimRaRecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let elapsedSeconds: Int
        let distanceMeters: Int
        let incidents: Int
    }

    let tripId: Int
    let bikeTypeId: Int
}

// MARK: - Live Activity Manager

@objcMembers
public final class LiveActivityManager: NSObject {

    public static let shared = LiveActivityManager()

    @available(iOS 16.2, *)
    private var currentActivity: Activity<SimRaRecordingAttributes>?

    private override init() {
        super.init()
    }

    // MARK: Start

    @objc(startActivityWithTripId:bikeTypeId:)
    public func startActivity(
        tripId: Int,
        bikeTypeId: Int
    ) {
        guard #available(iOS 16.2, *) else {
            return
        }

        let attributes = SimRaRecordingAttributes(
            tripId: tripId,
            bikeTypeId: bikeTypeId
        )

        let initialContentState =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds: 0,
                distanceMeters: 0,
                incidents: 0
            )
        let initialContent = ActivityContent(
            state: initialContentState,
            staleDate: nil
        )

        Task {
            do {
                let activity =
                    try Activity<SimRaRecordingAttributes>.request(
                        attributes: attributes,
                        content: initialContent,
                        pushType: nil
                    )

                self.currentActivity = activity

            } catch {
                // Die eigentliche SimRa-Aufnahme läuft unabhängig
                // von der Live Activity weiter.
            }
        }
    }

    // MARK: Update

    @objc(updateWithElapsedSeconds:distanceMeters:incidents:)
    public func update(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) {
        guard #available(iOS 16.2, *) else {
            return
        }

        Task {
            guard let activity = self.currentActivity else {
                return
            }

            let updatedContentState =
                SimRaRecordingAttributes.ContentState(
                    elapsedSeconds: elapsedSeconds,
                    distanceMeters: distanceMeters,
                    incidents: incidents
                )
            let updatedContent = ActivityContent(
                state: updatedContentState,
                staleDate: nil
            )

            await activity.update(updatedContent)
        }
    }

    // MARK: End

    @objc(endActivity)
    public func endActivity() {
        guard #available(iOS 16.2, *) else {
            return
        }

        Task {
            guard let activity = self.currentActivity else {
                return
            }

            let finalContent = ActivityContent(
                state: activity.content.state,
                staleDate: nil
            )

            await activity.end(
                finalContent,
                dismissalPolicy: .immediate
            )

            self.currentActivity = nil
        }
    }
}

#endif
