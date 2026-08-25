//
//  SimRaRecordingAttributes.swift
//  SimRa
//
//  Created by Emil Pauls
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import ActivityKit
import AppIntents

// MARK: - Activity State - Required by ActivityKit

struct SimRaRecordingAttributes: ActivityState {
    public let tripId: Int
    
    public let bikeTypeId: Int
    
    public struct ContentState: Codable {
        public let elapsedSeconds: Int
        public let distanceMeters: Int
        public let incidents: Int
    }
    
    public init(tripId: Int, bikeTypeId: Int, content: ContentState) {
        self.tripId = tripId
        self.bikeTypeId = bikeTypeId
        self.content = content
    }
}
