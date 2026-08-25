//
//  SimRa_WidgetsLiveActivity.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 25.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

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

struct SimRa_WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimRaRecordingAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.elapsedSeconds)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.distanceMeters)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.elapsedSeconds)")
            } minimal: {
                Text("\(context.state.elapsedSeconds)")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SimRaRecordingAttributes {
    fileprivate static var preview: SimRaRecordingAttributes {
        SimRaRecordingAttributes(tripId: 1, bikeTypeId: 1)
    }
}

extension SimRaRecordingAttributes.ContentState {
    fileprivate static var smiley: SimRaRecordingAttributes.ContentState {
        SimRaRecordingAttributes.ContentState(
            elapsedSeconds: 120,
            distanceMeters: 340,
            incidents: 0
        )
     }
     
     fileprivate static var starEyes: SimRaRecordingAttributes.ContentState {
         SimRaRecordingAttributes.ContentState(
             elapsedSeconds: 480,
             distanceMeters: 2700,
             incidents: 2
         )
     }
}

#Preview("Notification", as: .content, using: SimRaRecordingAttributes.preview) {
   SimRa_WidgetsLiveActivity()
} contentStates: {
    SimRaRecordingAttributes.ContentState.smiley
    SimRaRecordingAttributes.ContentState.starEyes
}
