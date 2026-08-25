import SwiftUI

struct TripSettingsView: View {
    @AppStorage("deferredSecs") var startSecs: Double = 0.0
    @AppStorage("deferredMeters") var startMeters: Double = 0.0
    @AppStorage("childSeat") var childSeat: Bool = false
    @AppStorage("trailer") var trailer: Bool = false
    @AppStorage("AI") var aiMode: Bool = false
    @AppStorage("openBikeSensor") var openBikeSensor: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Startverzögerung")) {
                VStack(alignment: .leading) {
                    Text("Sekunden: \(Int(startSecs))")
                    Slider(value: $startSecs, in: 0...60)
                }
                VStack(alignment: .leading) {
                    Text("Meter: \(Int(startMeters))")
                    Slider(value: $startMeters, in: 0...100)
                }
            }
            
            Section(header: Text("Fahrrad & Zubehör")) {
                Toggle("Kindersitz", isOn: $childSeat)
                Toggle("Anhänger", isOn: $trailer)
                Toggle("KI-Aufzeichnung", isOn: $aiMode)
            }
            
            Section(header: Text("Sensoren")) {
                Toggle("OpenBikeSensor", isOn: $openBikeSensor)
                if openBikeSensor {
                    Button("Sensor konfigurieren") {
                        print("OBS Config öffnen")
                    }
                }
            }
        }
        .navigationTitle("Fahrt-Einstellungen")
    }
}