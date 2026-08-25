import SwiftUI

struct AnnotationView: View {
    @ObservedObject var tripAnnotation: TripAnnotation
    
    // Lokale Zustände für die UI-Steuerung
    @State private var incidentId: Int = 0
    @State private var frightening: Bool = false
    @State private var car: Bool = false
    @State private var taxi: Bool = false
    @State private var delivery: Bool = false
    @State private var bus: Bool = false
    @State private var commercial: Bool = false
    @State private var pedestrian: Bool = false
    @State private var bicycle: Bool = false
    @State private var motorcycle: Bool = false
    @State private var escooter: Bool = false
    @State private var other: Bool = false
    @State private var comment: String = ""
    
    @State private var hasChanged: Bool = false
    @FocusState private var isCommentFocused: Bool

    // Auslesen der Incident-Konstanten aus dem AppDelegate
    private var incidentTypes: [String] {
        if let ad = UIApplication.shared.delegate as? AppDelegate,
           let constants = ad.constants {
            return constants["incidents"] as? [String] ?? []
        }
        return []
    }

    var body: some View {
        Form {
            Section(header: Text("Vorfall-Art")) {
                Picker("Vorfall", selection: $incidentId) {
                    ForEach(0..<incidentTypes.count, id: \.self) { index in
                        Text(incidentTypes[index]).tag(index)
                    }
                }
                .onChange(of: incidentId) { newValue in
                    tripAnnotation.incidentId = Int32(newValue)
                    hasChanged = true
                }
                
                Toggle("Erschrecken / Gefährdung", isOn: $frightened)
                    .onChange(of: frightened) { newValue in
                        tripAnnotation.frightening = newValue
                        hasChanged = true
                    }
            }

            Section(header: Text("Beteiligte Verkehrsteilnehmer")) {
                Toggle("Auto", isOn: $car)
                    .onChange(of: car) { updateVehicle { tripAnnotation.car = car } }
                Toggle("Taxi", isOn: $taxi)
                    .onChange(of: taxi) { updateVehicle { tripAnnotation.taxi = taxi } }
                Toggle("Lieferwagen / Transporter", isOn: $delivery)
                    .onChange(of: delivery) { updateVehicle { tripAnnotation.delivery = delivery } }
                Toggle("Bus", isOn: $bus)
                    .onChange(of: bus) { updateVehicle { tripAnnotation.bus = bus } }
                Toggle("LKW", isOn: $commercial)
                    .onChange(of: commercial) { updateVehicle { tripAnnotation.commercial = commercial } }
                Toggle("Fußgänger", isOn: $pedestrian)
                    .onChange(of: pedestrian) { updateVehicle { tripAnnotation.pedestrian = pedestrian } }
                Toggle("Fahrrad", isOn: $bicycle)
                    .onChange(of: bicycle) { updateVehicle { tripAnnotation.bicycle = bicycle } }
                Toggle("Motorrad", isOn: $motorcycle)
                    .onChange(of: motorcycle) { updateVehicle { tripAnnotation.motorcycle = motorcycle } }
                Toggle("E-Scooter", isOn: $escooter)
                    .onChange(of:escooter) { updateVehicle { tripAnnotation.escooter = escooter } }
                Toggle("Andere", isOn: $other)
                    .onChange(of: other) { updateVehicle { tripAnnotation.other = other } }
            }

            Section(header: Text("Kommentar")) {
                TextEditor(text: $comment)
                    .frame(minHeight: 100)
                    .focused($isCommentFocused)
                    .onChange(of: comment) { newValue in
                        tripAnnotation.comment = newValue
                        hasChanged = true
                    }
                
                if isCommentFocused {
                    Button("Fertig") {
                        isCommentFocused = false
                        hasChanged = true
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .navigationTitle("Vorfall bearbeiten")
        .onAppear(perform: loadValues)
        .onDisappear {
            if hasChanged {
                NotificationCenter.default.post(name: NSNotification.Name("annotationChanged"), object: tripAnnotation)
            }
        }
    }

    private func loadValues() {
        incidentId = Int(tripAnnotation.incidentId)
        frightened = tripAnnotation.frightening
        car = tripAnnotation.car
        taxi = tripAnnotation.taxi
        delivery = tripAnnotation.delivery
        bus = tripAnnotation.bus
        commercial = tripAnnotation.commercial
        pedestrian = tripAnnotation.pedestrian
        bicycle = tripAnnotation.bicycle
        motorcycle = tripAnnotation.motorcycle
        escooter = tripAnnotation.escooter
        other = tripAnnotation.other
        comment = tripAnnotation.comment ?? ""
        hasChanged = false
    }

    private func updateVehicle(_ mutation: () -> Void) {
        mutation()
        hasChanged = true
    }
}