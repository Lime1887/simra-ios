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

struct SimRa_WidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SimRa_WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimRa_WidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
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
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SimRa_WidgetsAttributes {
    fileprivate static var preview: SimRa_WidgetsAttributes {
        SimRa_WidgetsAttributes(name: "World")
    }
}

extension SimRa_WidgetsAttributes.ContentState {
    fileprivate static var smiley: SimRa_WidgetsAttributes.ContentState {
        SimRa_WidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SimRa_WidgetsAttributes.ContentState {
         SimRa_WidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SimRa_WidgetsAttributes.preview) {
   SimRa_WidgetsLiveActivity()
} contentStates: {
    SimRa_WidgetsAttributes.ContentState.smiley
    SimRa_WidgetsAttributes.ContentState.starEyes
}
