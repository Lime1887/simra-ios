import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                Button(action: { openURL("https://www.digital-future.berlin/forschung/projekte/simra/") }) {
                    Label("Über uns", systemImage: "info.circle")
                }
                Button(action: { openURL("https://www.tu.berlin/3s/forschung/projekte/simra-datenschutzerklaerung") }) {
                    Label("Datenschutz", systemImage: "hand.raised")
                }
                Button(action: { print("HowTo Aktion") }) {
                    Label("Anleitung", systemImage: "questionmark.circle")
                }
                Button(action: { print("Feedback Aktion") }) {
                    Label("Feedback", systemImage: "envelope")
                }
                Button(action: { openURL("https://www.tu.berlin/footer/impressum") }) {
                    Label("Impressum", systemImage: "building.columns")
                }
            }
            
            Section {
                Button("App Version: SimRa") {
                    print("Diagnose Alert anzeigen")
                }
            }
        }
        .navigationTitle("Einstellungen")
    }
    
    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}