//
//  BLEManager.swift
//  SimRa
//
//  Created by Hamza Khan on 15/07/2021[cite: 12, 13].
//  Copyright © 2021-2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin[cite: 12, 13]. All rights reserved.
//

import Foundation

@objcMembers
public class BLEManager: NSObject {
    
    public static let shared = BLEManager()
    
    // Objective-C compatibility wrapper for +[BLEManager sharedManager][cite: 12]
    @objc(sharedManager)
    public static func sharedManager() -> BLEManager {
        return shared
    }
    
    public var someProperty: String = "Default Property Value"[cite: 13]
    
    override private init() {
        super.init()
    }
}