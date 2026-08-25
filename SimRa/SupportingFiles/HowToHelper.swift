import UIKit

struct HowToHelper {
    static func showHowTo() {
        let dict = [
            "en": "https://simra-backend.3s-rg.de:4998/SimRa_Instructions_IOS.pdf",
            "de": "https://simra-backend.3s-rg.de:4998/SimRa_Anleitung_IOS.pdf"
        ]
        
        let preferredLanguage = Bundle.preferredLocalizations(from: Array(dict.keys)).first ?? "en"
        
        if let urlString = dict[preferredLanguage], let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}