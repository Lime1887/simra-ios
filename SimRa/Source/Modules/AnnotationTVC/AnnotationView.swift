//
//  AnnotationView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct AnnotationView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss


    // MARK: - Model

    let tripAnnotation: TripAnnotation
    var trip: Trip? = nil


    // MARK: - State

    @State private var incidentId: Int = 0
    @State private var frightening: Bool = false

    // MARK: - Computed Properties

    private var isQuickRecorded: Bool {
        ["Siri", "Button", "Live Activity", "Widget / URL"].contains(tripAnnotation.source)
    }

    private var sourceColor: Color {
        switch tripAnnotation.source {
        case "Siri":
            return .blue
        case "Live Activity":
            return .purple
        case "Widget / URL":
            return .teal
        case "Button":
            return .green
        default:
            return .orange
        }
    }

    private var sourceIcon: String {
        switch tripAnnotation.source {
        case "Siri":
            return "mic.fill"
        case "Live Activity":
            return "iphone.gen3"
        case "Button":
            return "record.circle.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

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

    @FocusState private var commentFocused: Bool


    // MARK: - Incident Types

    private var incidentTypes: [String] {
        if let incidents = AppDelegate.shared().constants["incidents"] as? [String],
           !incidents.isEmpty {
            return incidents
        }

        return [
            NSLocalizedString("Nothing", comment: "Incident type"),
            NSLocalizedString("Close Passing", comment: "Incident type"),
            NSLocalizedString("Parking Car", comment: "Incident type"),
            NSLocalizedString("Almost Turning Accident", comment: "Incident type"),
            NSLocalizedString("Oncoming Traffic", comment: "Incident type"),
            NSLocalizedString("Tailgating", comment: "Incident type"),
            NSLocalizedString("Almost Dooring", comment: "Incident type"),
            NSLocalizedString("Sidestep (e.g. a dog)", comment: "Incident type"),
            NSLocalizedString("Other", comment: "Incident type")
        ]
    }


    // MARK: - Body

    var body: some View {
        Form {

            // MARK: Quick Reminder Notice

            if isQuickRecorded {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: sourceIcon)
                            .font(.title2)
                            .foregroundStyle(sourceColor)

                        VStack(alignment: .leading, spacing: 2) {
                               Text(tripAnnotation.source == "Siri" ?
                                   NSLocalizedString("Siri recording", comment: "Siri recording") :
                                   tripAnnotation.source == "Live Activity" ?
                                   NSLocalizedString("Live Activity recording", comment: "Live Activity recording") :
                                   tripAnnotation.source == "Button" ?
                                   NSLocalizedString("Button recording", comment: "Button recording") :
                                 NSLocalizedString("Quick recording", comment: "Quick recording"))
                                .font(.subheadline.weight(.semibold))
                                  .foregroundStyle(sourceColor)

                            Text(NSLocalizedString("Erfasst während der Fahrt. Bitte Typ und Beteiligte ergänzen.", comment: "Quick reminder explanation"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: Incident

            Section {
                Picker(NSLocalizedString("Incident type", comment: "Incident type"), selection: $incidentId) {
                    ForEach(incidentTypes.indices, id: \.self) { index in
                        Text(incidentTypes[index])
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)

                Toggle(NSLocalizedString("Scary / Danger", comment: "Scary situation"), isOn: $frightening)
            } header: {
                Text(NSLocalizedString("Incident", comment: "Incident"))
            } footer: {
                Text(NSLocalizedString("Specify what happened and if there was concrete danger.", comment: "Specify what happened and if there was concrete danger."))
            }


            // MARK: Road Users

            Section {
                Toggle(isOn: $car) {
                    Label(NSLocalizedString("Car", comment: "Road user"), systemImage: "car.fill")
                }
                Toggle(isOn: $taxi) {
                    Label(NSLocalizedString("Taxi", comment: "Road user"), systemImage: "car.fill")
                }
                Toggle(isOn: $delivery) {
                    Label(NSLocalizedString("Delivery vehicle / Van", comment: "Road user"), systemImage: "truck.box.fill")
                }
                Toggle(isOn: $bus) {
                    Label(NSLocalizedString("Bus", comment: "Road user"), systemImage: "bus.fill")
                }
                Toggle(isOn: $commercial) {
                    Label(NSLocalizedString("Truck", comment: "Road user"), systemImage: "truck.box.fill")
                }
                Toggle(isOn: $pedestrian) {
                    Label(NSLocalizedString("Pedestrian", comment: "Road user"), systemImage: "figure.walk")
                }
                Toggle(isOn: $bicycle) {
                    Label(NSLocalizedString("Bicycle", comment: "Road user"), systemImage: "bicycle")
                }
                Toggle(isOn: $motorcycle) {
                    Label(NSLocalizedString("Motorcycle", comment: "Road user"), systemImage: "motorcycle.fill")
                }
                Toggle(isOn: $escooter) {
                    Label(NSLocalizedString("E-Scooter", comment: "Road user"), systemImage: "scooter")
                }
                Toggle(isOn: $other) {
                    Label(NSLocalizedString("Other", comment: "Road user"), systemImage: "ellipsis.circle")
                }
            } header: {
                Text(NSLocalizedString("Involved parties", comment: "Involved parties"))
            } footer: {
                Text(NSLocalizedString("Select all road users involved in the incident.", comment: "Select all road users involved in the incident."))
            }


            // MARK: Comment

            Section {
                TextField(
                    NSLocalizedString("Comment", comment: "Comment"),
                    text: $comment,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .focused($commentFocused)
            } header: {
                Text(NSLocalizedString("Note", comment: "Note"))
            } footer: {
                Text(NSLocalizedString("Optional. Additional information about the incident.", comment: "Optional. Additional information about the incident."))
            }
        }

        // MARK: Navigation

        .navigationTitle(NSLocalizedString("Edit incident", comment: "Edit incident"))
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("Done", comment: "Done")) {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(NSLocalizedString("Done", comment: "Done")) {
                    commentFocused = false
                }
            }
        }

        .onAppear {
            loadValues()
        }
    }


    // MARK: - Load

    private func loadValues() {
        incidentId = Int(tripAnnotation.incidentId)
        frightening = tripAnnotation.frightening

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
    }


    // MARK: - Save

    private func saveAndDismiss() {
        tripAnnotation.incidentId = incidentId
        tripAnnotation.frightening = frightening

        tripAnnotation.car = car
        tripAnnotation.taxi = taxi
        tripAnnotation.delivery = delivery
        tripAnnotation.bus = bus
        tripAnnotation.commercial = commercial
        tripAnnotation.pedestrian = pedestrian
        tripAnnotation.bicycle = bicycle
        tripAnnotation.motorcycle = motorcycle
        tripAnnotation.escooter = escooter
        tripAnnotation.other = other

        tripAnnotation.comment = comment

        if let trip = trip {
            trip.edited = true
            trip.save()
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("annotationChanged"),
            object: tripAnnotation
        )

        dismiss()
    }
}
