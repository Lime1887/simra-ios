//
//  SimRa_WidgetsBundle.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 25.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct SimRa_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        SimRa_Widgets()
        SimRa_WidgetsControl()
        SimRa_WidgetsLiveActivity()
    }
}
