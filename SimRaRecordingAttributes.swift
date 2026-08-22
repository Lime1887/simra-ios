#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.2, *)
public struct SimRaRecordingAttributes: ActivityAttributes {
    public typealias ContentState = ContentState

    public struct ContentState: Codable, Hashable {
        // Define properties relevant to the content state here
    }

    // Define any additional properties or methods needed for the attributes here
}
#endif
