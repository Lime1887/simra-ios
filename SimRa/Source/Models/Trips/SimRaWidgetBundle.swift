import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct SimRaWidgetBundle: WidgetBundle {

    @WidgetBundleBuilder
    var body: some Widget {

        SimRaLiveActivity()
    }
}
