//
//  SimRaRecordingAttributes.swift
//  SimRa
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct SimRaRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let elapsedSeconds: Int
        let distanceMeters: Int
        let incidents: Int
    }

    let tripId: Int
    let bikeTypeId: Int
}
