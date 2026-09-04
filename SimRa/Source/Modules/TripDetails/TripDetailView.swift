//
//  TripDetailView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct TripDetailView: View {

    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss

    // MARK: - Model

    let trip: Trip

    // MARK: - State

    @State private var bikeTypeId: Int = 0
    @State private var positionId: Int = 0
    @State private var childSeat = false
    @State private var trailer = false
    @State private var hasChanges = false

    // MARK: - Constants

    private var constants: [String: Any] {
        AppDelegate.shared().constants
    }

    private var bikeTypes: [String] {
        constants["bikeTypes"] as? [String] ?? []
    }

    private var positions: [String] {
        constants["positions"] as? [String] ?? []
    }

    // MARK: - Body

    var body: some View {

        Form {

            // MARK: - Bicycle

            Section {

                Picker(
                    NSLocalizedString("Bicycle type", comment: "Bicycle type"),
                    selection: $bikeTypeId
                ) {

                    if bikeTypes.isEmpty {

                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)

                    } else {

                        ForEach(bikeTypes.indices, id: \.self) { index in

                            Text(bikeTypes[index])
                                .tag(index)
                        }
                    }
                }

                Picker(
                    NSLocalizedString("Position", comment: "Position"),
                    selection: $positionId
                ) {

                    if positions.isEmpty {

                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)

                    } else {

                        ForEach(positions.indices, id: \.self) { index in

                            Text(positions[index])
                                .tag(index)
                        }
                    }
                }

            } header: {

                Label(
                    NSLocalizedString("Bicycle", comment: "Bicycle"),
                    systemImage: "bicycle"
                )
            }

            // MARK: - Equipment

            Section {

                Toggle(
                    isOn: $childSeat
                ) {

                    Label(
                        NSLocalizedString("Child seat", comment: "Child seat"),
                        systemImage: "figure.child"
                    )
                }

                Toggle(
                    isOn: $trailer
                ) {

                    Label(
                        NSLocalizedString("Trailer", comment: "Trailer"),
                        systemImage: "cart"
                    )
                }

            } header: {

                Label(
                    NSLocalizedString("Equipment", comment: "Equipment"),
                    systemImage: "bicycle.circle"
                )
            }

            // MARK: - Defaults

            Section {

                Button {

                    saveAsDefault()

                } label: {

                    Label(
                        NSLocalizedString("Use as default", comment: "Use as default"),
                        systemImage: "star"
                    )
                }

            } footer: {

                Text(
                    NSLocalizedString("These bicycle and equipment settings will be applied to future trips.", comment: "These bicycle and equipment settings will be applied to future trips.")
                )
            }

            // MARK: - Unsaved Changes

            if hasChanges {

                Section {

                    Label(
                        NSLocalizedString("Unsaved Changes", comment: "Unsaved Changes"),
                        systemImage: "pencil"
                    )
                    .foregroundStyle(.secondary)

                } footer: {

                    Text(
                        NSLocalizedString("Tap 'Done' to save changes.", comment: "Tap 'Done' to save changes.")
                    )
                }
            }
        }

        // MARK: - Navigation

        .navigationTitle(
            NSLocalizedString("Trip Details", comment: "Trip Details")
        )
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItem(
                placement: .confirmationAction
            ) {

                Button(
                    NSLocalizedString("Done", comment: "Done")
                ) {

                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .disabled(!hasChanges)
            }
        }

        // MARK: - Change Tracking

        .onChange(of: bikeTypeId) { _, _ in
            markChanged()
        }

        .onChange(of: positionId) { _, _ in
            markChanged()
        }

        .onChange(of: childSeat) { _, _ in
            markChanged()
        }

        .onChange(of: trailer) { _, _ in
            markChanged()
        }

        // MARK: - Load

        .onAppear {
            loadCurrentValues()
        }
    }

    // MARK: - Change

    private func markChanged() {

        // During initial loading SwiftUI also fires
        // some onChange events. Compare against the
        // actual Trip values before declaring a change.

        hasChanges =
            bikeTypeId != Int(trip.bikeTypeId)
            || positionId != Int(trip.positionId)
            || childSeat != trip.childseat
            || trailer != trip.trailer
    }

    // MARK: - Load

    private func loadCurrentValues() {

        bikeTypeId = Int(trip.bikeTypeId)
        positionId = Int(trip.positionId)
        childSeat = trip.childseat
        trailer = trip.trailer
        hasChanges = false
    }

    // MARK: - Save

    private func saveAndDismiss() {

        guard hasChanges else {
            dismiss()
            return
        }

        trip.bikeTypeId = bikeTypeId
        trip.positionId = positionId
        trip.childseat = childSeat
        trip.trailer = trailer

        // Editing trip metadata is an actual trip edit.
        trip.edited = true
        trip.save()
        hasChanges = false

        NotificationCenter.default.post(
            name: NSNotification.Name("attributesChanged"),
            object: trip
        )

        NotificationCenter.default.post(
            name: NSNotification.Name("tripEdited"),
            object: trip
        )

        dismiss()
    }

    // MARK: - Defaults

    private func saveAsDefault() {

        UserDefaults.standard.set(
            bikeTypeId,
            forKey: "bikeTypeId"
        )

        UserDefaults.standard.set(
            positionId,
            forKey: "positionId"
        )

        UserDefaults.standard.set(
            childSeat,
            forKey: "childSeat"
        )

        UserDefaults.standard.set(
            trailer,
            forKey: "trailer"
        )
    }
}
