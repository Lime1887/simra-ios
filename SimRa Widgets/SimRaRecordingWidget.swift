import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
public struct SimRaRecordingWidget: Widget {
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SimRaRecordingWidget", provider: Provider()) { entry in
            SimRaRecordingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SimRa Recording")
        .description("Shows your current SimRa recording.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview(
    "Small",
    as: .systemSmall
) {
    SimRaRecordingWidget()
} timeline: {
    SimRaRecordingEntry(date: .now)
}

@available(iOS 17.0, *)
#Preview(
    "Medium",
    as: .systemMedium
) {
    SimRaRecordingWidget()
} timeline: {
    SimRaRecordingEntry(date: .now)
}
#endif
