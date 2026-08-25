import SwiftUI

struct TripDetailView: View {
    @ObservedObject var trip: Trip
    
    // Lokale Statuswerte für die IdPicker-Auswahlen und Switche
    @State private var bikeTypeId: Int = 0
    @State private var positionId: Int = 0
    @State private var childSeat: Bool = false
    @State private var trailer: Bool = false
    
    @State private var hasChanges: Bool = false
    
    // Auslesen der Daten aus den App-Constants
    private var bikeTypes: [String] {
        (UIApplication.shared.delegate as? AppDelegate)?.constants?["bikeTypes"] as? [String] ?? []
    }
    
    private var positions: [String] {
        (UIApplication.shared.delegate as? AppDelegate)?.constants?["positions"] as? [String] ?? []
    }

    var body: some View {
        Form {
            Section(header: Text("Fahrrad-Details")) {
                Picker("Fahrradtyp", selection: $bikeTypeId) {
                    ForEach(0..<bikeTypes.count, id: \.self) { index in
                        Text(bikeTypes[index]).tag(index)
                    }
                }
                .onChange(of: bikeTypeId) { newValue in
                    trip.bikeTypeId = Int32(newValue)
                    hasChanges = true
                }

                Picker("Position", selection: $positionId) {
                    ForEach(0..<positions.count, id: \.self) { index in
                        Text(positions[index]).tag(index)
                    }
                }
                .onChange(of: positionId) { newValue in
                    trip.positionId = Int32(newValue)
                    hasChanges = true
                }
            }

            Section(header: Text("Ausstattung")) {
                Toggle("Kindersitz", isOn: $childSeat)
                    .onChange(of: childSeat) { newValue in
                        trip.childseat = newValue
                        hasChanges = true
                    }

                Toggle("Anhänger", isOn: $trailer)
                    .onChange(of: trailer) { newValue in
                        trip.trailer = newValue
                        hasChanges = true
                    }
            }

            Section {
                Button(action: saveAsDefault) {
                    Label("Als Standard speichern", systemImage: "star.fill")
                }
            }
        }
        .navigationTitle("Fahrt-Details")
        .onAppear(perform: loadCurrentValues)
        .onDisappear {
            if hasChanges {
                // Posten der Segue-/Notification-Information bei Verlassen der View
                NotificationCenter.default.post(name: NSNotification.Name("attributesChanged"), object: trip)
            }
        }
    }

    private func loadCurrentValues() {
        bikeTypeId = Int(trip.bikeTypeId)
        positionId = Int(trip.positionId)
        childSeat = trip.childseat
        trailer = trip.trailer
        hasChanges = false
    }

    private func saveAsDefault() {
        let defaults = UserDefaults.standard
        defaults.set(trip.bikeTypeId, forKey: "bikeTypeId")
        defaults.set(trip.positionId, forKey: "positionId")
        defaults.set(trip.childseat, forKey: "childSeat")
        defaults.set(trip.trailer, forKey: "trailer")
    }
}