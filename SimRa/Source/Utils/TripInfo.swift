//
//  TripInfo.swift
//  SimRa
//
//  Created for SwiftUI Migration
//

import Foundation

@MainActor
final class TripInfo: NSObject, Codable {
    
    @objc
    private(set) var identifier: Int
    @objc
    private(set) var version: Int = 1
    @objc
    private(set) var edited: Bool = false
    @objc
    private(set) var uploaded: Bool = false
    @objc
    private(set) var fileHash: String?
    @objc
    private(set) var filePasswd: String?
    @objc
    private(set) var duration: TimeInterval = 0
    @objc
    private(set) var length: Double = 0
    @objc
    private(set) var statisticsAdded: Bool = false
    @objc
    private(set) var reUploaded: Bool = false
    @objc
    private(set) var annotationsCount: Int = 0
    @objc
    private(set) var validAnnotationsCount: Int = 0
    
    init(identifier: Int) {
        self.identifier = identifier
    }
}
