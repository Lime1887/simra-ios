//
//  API.swift
//  SimRa
//
//  Created by Christoph Krey on 26.04.22.
//  Copyright © 2022-2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation

@objcMembers
public class API: NSObject {
    
    private static let scheme = "https:"
    private static let host = "simra-backend.3s-rg.de:8082"
    private static let version = 13
    
    public static var APIPrefix: String {
        let prefix = "\(scheme)//\(host)/\(version)"
        print("APIprefix: \(prefix)")
        return prefix
    }
    
    public static var APIShortPrefix: String {
        let prefix = "\(scheme)//\(host)"
        print("APIprefix: \(prefix)")
        return prefix
    }
}