//
//  HowToHelper.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct HowToHelper {

    static func showHowTo(
        openURL: OpenURLAction
    ) {
        let urls: [String: String] = [
            "de": "https://simra-backend.3s-rg.de:4998/SimRa_Anleitung_IOS.pdf",
            "en": "https://simra-backend.3s-rg.de:4998/SimRa_Instructions_IOS.pdf"
        ]

        let language = Bundle.preferredLocalizations(
            from: Array(urls.keys)
        ).first ?? "en"

        guard
            let urlString = urls[language],
            let url = URL(string: urlString)
        else {
            return
        }

        openURL(url)
    }
}
