import SwiftUI

struct ProfileView: View {
    @AppStorage("behaviour") var behaviour: Bool = false
    @AppStorage("behaviourValue") var behaviourValue: Double = 0.5
    @AppStorage("totalRides") var totalRides: Int = 0
    @AppStorage("totalLength") var totalLength: Double = 0.0

    var body: some View {
        Form {
            Section(header: Text("Fahrverhalten")) {
                Toggle("Fahrverhalten aufzeichnen", isOn: $behaviour)
                Slider(value: $behaviourValue, in: 0...1)
                    .disabled(!behaviour)
                    .opacity(behaviour ? 1.0 : 0.5)
            }
            
            Section(header: Text("Statistiken")) {
                HStack {
                    Text("Anzahl der Fahrten")
                    Spacer()
                    Text("\(totalRides)")
                }
                HStack {
                    Text("Gesamtdistanz")
                    Spacer()
                    Text(String(format: "%.1f km", totalLength / 1000.0))
                }
            }
        }
        .navigationTitle("Profil")
    }
}