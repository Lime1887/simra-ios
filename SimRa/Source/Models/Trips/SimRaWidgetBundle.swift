import SwiftUI
import WidgetKit

@main
struct SimRaWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        if #available(iOS 16.2, *) {
            SimRaRecordingLiveActivity()
        }
    }
}
