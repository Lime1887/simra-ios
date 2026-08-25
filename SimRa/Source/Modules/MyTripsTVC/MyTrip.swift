//
//  TripItem.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - My Trips View

struct MyTripsView: View {

    // MARK: - State

    @State private var trips: [Trip] = []
    @State private var selectedTripIDs = Set<Int>()

    @StateObject private var uploadCoordinator =
        TripBatchUploadCoordinator()

    @Environment(\.editMode)
    private var editMode

    // MARK: - Derived State

    private var pendingTrips: [Trip] {
        trips.filter { !$0.uploaded }
    }

    private var uploadedTrips: [Trip] {
        trips.filter { $0.uploaded }
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    private var allPendingTripsSelected: Bool {
        let pendingIDs = Set(
            pendingTrips.map(\.identifier)
        )

        guard !pendingIDs.isEmpty else {
            return false
        }

        return pendingIDs.allSatisfy {
            selectedTripIDs.contains($0)
        }
    }

    private var hasSelection: Bool {
        !selectedTripIDs.isEmpty
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selectedTripIDs) {

            // MARK: Not Uploaded

            if !pendingTrips.isEmpty {
                Section {
                    ForEach(
                        pendingTrips,
                        id: \.identifier
                    ) { trip in
                        tripRow(for: trip)
                    }
                } header: {
                    sectionHeader(
                        NSLocalizedString(
                            "Not Uploaded",
                            comment: "Not Uploaded"
                        )
                    )
                }
            }

            // MARK: Uploaded

            if !uploadedTrips.isEmpty {
                Section {
                    ForEach(
                        uploadedTrips,
                        id: \.identifier
                    ) { trip in
                        tripRow(for: trip)
                    }
                } header: {
                    sectionHeader(
                        NSLocalizedString(
                            "Uploaded",
                            comment: "Uploaded"
                        )
                    )
                }
            }

            // MARK: Empty

            if trips.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString(
                        "No trips",
                        comment: "No trips"
                    ),
                    systemImage: "bicycle",
                    description: Text(
                        NSLocalizedString(
                            "Once trips are recorded, they will appear here.",
                            comment: "Empty trips description"
                        )
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(
            NSLocalizedString(
                "My Trips",
                comment: "My Trips"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .safeAreaInset(
            edge: .bottom,
            spacing: 0
        ) {
            if uploadCoordinator.isUploading {
                uploadProgressView
            }
        }
        .alert(
            uploadCoordinator.alertTitle,
            isPresented:
                $uploadCoordinator.showAlert
        ) {
            Button(
                NSLocalizedString(
                    "OK",
                    comment: "OK"
                ),
                role: .cancel
            ) {
                reloadTrips()
            }
        } message: {
            Text(
                uploadCoordinator.alertMessage
            )
        }
        .onAppear {
            reloadTrips()
        }
        .onChange(of: isEditing) { _, editing in
            if !editing {
                selectedTripIDs.removeAll()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .tripEdited
            )
        ) { _ in
            reloadTrips()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .tripAttributesChanged
            )
        ) { _ in
            reloadTrips()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .tripAnnotationChanged
            )
        ) { _ in
            reloadTrips()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        if isEditing {
            ToolbarItem(
                placement: .topBarLeading
            ) {
                Button {
                    toggleSelectAllPending()
                } label: {
                    Text(
                        allPendingTripsSelected
                        ? NSLocalizedString(
                            "None",
                            comment: "Deselect all"
                        )
                        : NSLocalizedString(
                            "All",
                            comment: "Select all"
                        )
                    )
                }
                .disabled(
                    pendingTrips.isEmpty
                )
            }
        }

        ToolbarItem(
            placement: .topBarTrailing
        ) {
            EditButton()
        }

        if isEditing {
            ToolbarItemGroup(
                placement: .bottomBar
            ) {

                Button {
                    uploadSelectedTrips()
                } label: {
                    if uploadCoordinator.isUploading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(
                            NSLocalizedString(
                                "Upload",
                                comment: "Upload"
                            ),
                            systemImage:
                                "icloud.and.arrow.up"
                        )
                    }
                }
                .disabled(
                    selectedPendingTripCount == 0 ||
                    uploadCoordinator.isUploading
                )

                Spacer()

                Button(
                    role: .destructive
                ) {
                    deleteSelectedTrips()
                } label: {
                    Label(
                        NSLocalizedString(
                            "Delete",
                            comment: "Delete"
                        ),
                        systemImage: "trash"
                    )
                }
                .disabled(
                    !hasSelection ||
                    uploadCoordinator.isUploading
                )
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(
        _ title: String
    ) -> some View {
        Text(title)
            .font(
                .subheadline.weight(.semibold)
            )
    }

    // MARK: - Upload Progress

    @ViewBuilder
    private var uploadProgressView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {

                ProgressView()
                    .controlSize(.small)

                Text(
                    NSLocalizedString(
                        "Uploading trips...",
                        comment: "Uploading trips"
                    )
                )
                .font(
                    .subheadline.weight(
                        .medium
                    )
                )

                Spacer()

                Text(
                    "\(uploadCoordinator.completedCount) / \(uploadCoordinator.totalCount)"
                )
                .font(
                    .subheadline.monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ProgressView(
                value:
                    uploadCoordinator.progress
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
    }

    // MARK: - Selection

    private var selectedPendingTripCount: Int {
        selectedTripIDs.reduce(
            into: 0
        ) { count, identifier in
            if pendingTrips.contains(
                where: {
                    $0.identifier == identifier
                }
            ) {
                count += 1
            }
        }
    }

    private func selectedTrips() -> [Trip] {
        trips.filter {
            selectedTripIDs.contains(
                $0.identifier
            )
        }
    }

    private func selectedPendingTrips() -> [Trip] {
        selectedTrips().filter {
            !$0.uploaded
        }
    }

    private func toggleSelectAllPending() {
        let pendingIDs = Set(
            pendingTrips.map(\.identifier)
        )

        guard !pendingIDs.isEmpty else {
            return
        }

        if allPendingTripsSelected {
            selectedTripIDs.subtract(
                pendingIDs
            )
        } else {
            selectedTripIDs.formUnion(
                pendingIDs
            )
        }
    }

    // MARK: - Trip Row

    private func tripRow(
        for trip: Trip
    ) -> some View {
        NavigationLink {
            TripEditView(
                viewModel:
                    TripEditViewModel(
                        trip: trip
                    )
            )
        } label: {
            CompactTripRow(
                title:
                    tripTitle(
                        for: trip
                    ),
                summary:
                    summaryText(
                        for: trip
                    ),
                isEdited:
                    trip.edited
            )
        }
        .swipeActions(
            edge: .leading,
            allowsFullSwipe: false
        ) {
            if !trip.uploaded {
                Button {
                    uploadCoordinator.upload(
                        trips: [trip]
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "Upload",
                            comment: "Upload"
                        ),
                        systemImage:
                            "icloud.and.arrow.up"
                    )
                }
                .tint(.accentColor)
                .disabled(
                    uploadCoordinator.isUploading
                )
            }
        }
        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: true
        ) {
            Button(
                role: .destructive
            ) {
                deleteTrip(
                    trip.identifier
                )
            } label: {
                Label(
                    NSLocalizedString(
                        "Delete",
                        comment: "Delete"
                    ),
                    systemImage: "trash"
                )
            }
            .disabled(
                uploadCoordinator.isUploading
            )
        }
    }

    // MARK: - Upload

    private func uploadSelectedTrips() {
        let selected =
            selectedPendingTrips()

        guard !selected.isEmpty else {
            return
        }

        uploadCoordinator.upload(
            trips: selected
        )
    }

    // MARK: - Delete

    private func deleteTrip(
        _ identifier: Int
    ) {
        guard !uploadCoordinator.isUploading else {
            return
        }

        AppDelegate
            .shared()
            .trips
            .deleteTrip(
                withIdentifier:
                    identifier
            )

        selectedTripIDs.remove(
            identifier
        )

        reloadTrips()
    }

    private func deleteSelectedTrips() {
        guard !uploadCoordinator.isUploading else {
            return
        }

        let identifiers =
            selectedTrips()
                .map(\.identifier)

        guard !identifiers.isEmpty else {
            return
        }

        for identifier in identifiers {
            AppDelegate
                .shared()
                .trips
                .deleteTrip(
                    withIdentifier:
                        identifier
                )
        }

        selectedTripIDs.removeAll()
        reloadTrips()
    }

    // MARK: - Trip Date

    private func tripDate(
        for trip: Trip
    ) -> Date? {
        guard
            let firstLocation =
                trip.tripLocations.firstObject
                as? TripLocation
        else {
            return nil
        }

        return firstLocation.location.timestamp
    }

    // MARK: - Trip Title

    private func tripTitle(
        for trip: Trip
    ) -> String {

        guard let date =
                tripDate(for: trip)
        else {
            return NSLocalizedString(
                "Trip",
                comment: "Trip"
            )
        }

        let time =
            date.formatted(
                .dateTime
                    .hour()
                    .minute()
            )

        let calendar =
            Calendar.current

        if calendar.isDateInToday(date) {
            return String(
                format: "%@ · %@",
                NSLocalizedString(
                    "Today",
                    comment: "Today"
                ),
                time
            )
        }

        if calendar.isDateInYesterday(date) {
            return String(
                format: "%@ · %@",
                NSLocalizedString(
                    "Yesterday",
                    comment: "Yesterday"
                ),
                time
            )
        }

        if calendar.dateInterval(
            of: .weekOfYear,
            for: Date()
        )?.contains(date) == true {

            let weekday =
                date.formatted(
                    .dateTime
                        .weekday(.wide)
                )

            return "\(weekday) · \(time)"
        }

        return date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
                .hour()
                .minute()
        )
    }

    // MARK: - Summary

    private func summaryText(
        for trip: Trip
    ) -> String {

        let distance =
            formattedDistance(
                trip.length()
            )

        guard let durationObject =
                trip.duration()
        else {
            return "\(distance) · –"
        }

        let duration =
            formatDuration(
                durationObject.duration
            )

        guard let speed =
                averageSpeedText(
                    distanceInMeters:
                        trip.length(),
                    duration:
                        durationObject.duration
                )
        else {
            return "\(distance) · \(duration)"
        }

        return "\(distance) · \(duration) · \(speed)"
    }

    // MARK: - Distance

    private func formattedDistance(
        _ meters: Int
    ) -> String {

        let value =
            max(meters, 0)

        if value >= 1000 {
            return Measurement(
                value:
                    Double(value) / 1000,
                unit:
                    UnitLength.kilometers
            )
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .road
                )
            )
        }

        return Measurement(
            value:
                Double(value),
            unit:
                UnitLength.meters
        )
        .formatted(
            .measurement(
                width: .abbreviated,
                usage: .road
            )
        )
    }

    // MARK: - Average Speed

    private func averageSpeedText(
        distanceInMeters:
            Int,
        duration:
            TimeInterval
    ) -> String? {

        guard distanceInMeters > 0,
              duration > 0
        else {
            return nil
        }

        let kilometers =
            Double(distanceInMeters) /
            1000

        let hours =
            duration / 3600

        guard hours > 0 else {
            return nil
        }

        let speed =
            kilometers / hours

        return Measurement(
            value: speed,
            unit:
                UnitSpeed.kilometersPerHour
        )
        .formatted(
            .measurement(
                width: .abbreviated
            )
        )
    }

    // MARK: - Duration

    private func formatDuration(
        _ value: TimeInterval
    ) -> String {

        let totalSeconds =
            max(
                Int(value.rounded()),
                0
            )

        let hours =
            totalSeconds / 3600

        let minutes =
            (totalSeconds % 3600) / 60

        let seconds =
            totalSeconds % 60

        if hours > 0 {
            return String(
                format:
                    "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format:
                "%02d:%02d",
            minutes,
            seconds
        )
    }

    // MARK: - Reload

    private func reloadTrips() {
        // Load trips in background for better performance
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedTrips =
                Trip
                    .allStoredIdentifiers()
                    .sorted {
                        $0.compare($1) ==
                            .orderedAscending
                    }
                    .compactMap {
                        Trip(
                            fromStorage:
                                $0.intValue
                        )
                    }

            DispatchQueue.main.async {
                self.trips =
                    loadedTrips.sorted {
                        let lhsDate =
                            self.tripDate(
                                for: $0
                            ) ?? .distantPast

                        let rhsDate =
                            self.tripDate(
                                for: $1
                            ) ?? .distantPast

                        return lhsDate > rhsDate
                    }

                let validIdentifiers =
                    Set(
                        self.trips.map(\.identifier)
                    )

                self.selectedTripIDs.formIntersection(
                    validIdentifiers
                )
            }
        }
    }
}

// MARK: - Compact Trip Row

private struct CompactTripRow: View {

    let title: String
    let summary: String
    let isEdited: Bool

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {

            Image(
                systemName: "bicycle"
            )
            .font(
                .system(
                    size: 16,
                    weight: .medium
                )
            )
            .foregroundStyle(.tint)
            .frame(
                width: 34,
                height: 34
            )
            .background(
                Color.secondary.opacity(0.10),
                in: Circle()
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(title)
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(1)

                HStack(
                    spacing: 4
                ) {

                    Text(summary)

                    Text("·")
                        .foregroundStyle(
                            .tertiary
                        )

                    Text(
                        isEdited
                        ? NSLocalizedString(
                            "Edited",
                            comment: "Edited"
                        )
                        : NSLocalizedString(
                            "Not edited",
                            comment: "Not edited"
                        )
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
                .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Notification Names

private extension Notification.Name {

    static let tripEdited =
        Notification.Name(
            "tripEdited"
        )

    static let tripAttributesChanged =
        Notification.Name(
            "attributesChanged"
        )

    static let tripAnnotationChanged =
        Notification.Name(
            "annotationChanged"
        )
}

// MARK: - Batch Upload Coordinator

@MainActor
final class TripBatchUploadCoordinator:
    NSObject,
    ObservableObject
{

    // MARK: - Published State

    @Published var showAlert = false

    @Published var alertTitle =
        "SimRa"

    @Published var alertMessage =
        ""

    @Published private(set) var isUploading =
        false

    @Published private(set) var completedCount =
        0

    @Published private(set) var totalCount =
        0

    @Published private(set) var progress =
        0.0

    // MARK: - Private State

    private var queue: [Trip] = []
    private var currentIndex = 0

    private var successCount = 0
    private var failureCount = 0

    private var finished = false
    private var processingCurrentTrip = false

    // MARK: - Upload

    func upload(
        trips: [Trip]
    ) {
        guard !isUploading else {
            return
        }

        queue =
            trips
                .filter { !$0.uploaded }
                .sorted {
                    $0.identifier <
                        $1.identifier
                }

        currentIndex = 0
        successCount = 0
        failureCount = 0
        finished = false
        processingCurrentTrip = false

        completedCount = 0
        totalCount = queue.count
        progress = 0

        alertTitle = "SimRa"
        alertMessage = ""

        guard !queue.isEmpty else {
            alertMessage =
                NSLocalizedString(
                    "No unuploaded trips selected.",
                    comment:
                        "No unuploaded trips selected"
                )

            showAlert = true
            return
        }

        isUploading = true

        uploadNextTrip()
    }

    // MARK: - Error Callback

    @objc
    func uploadTripError(
        _ error: NSError
    ) {
        guard processingCurrentTrip else {
            return
        }

        processingCurrentTrip = false
        failureCount += 1

        registerCompletedTrip()
        uploadNextTrip()
    }

    // MARK: - Completion Callback

    @objc
    func uploadTripCompleted(
        _ dict: NSDictionary
    ) {
        guard processingCurrentTrip else {
            return
        }

        processingCurrentTrip = false

        if let response =
            dict["response"]
            as? HTTPURLResponse,
            (200...299).contains(
                response.statusCode
            ) {

            successCount += 1

        } else {
            failureCount += 1
        }

        registerCompletedTrip()
        uploadNextTrip()
    }

    // MARK: - Progress

    private func registerCompletedTrip() {
        completedCount =
            min(
                completedCount + 1,
                totalCount
            )

        progress =
            totalCount > 0
            ? Double(completedCount) /
                Double(totalCount)
            : 0
    }

    // MARK: - Upload Next Trip

    private func uploadNextTrip() {
        guard currentIndex < queue.count else {
            finishBatch()
            return
        }

        guard !processingCurrentTrip else {
            return
        }

        let trip =
            queue[currentIndex]

        currentIndex += 1
        processingCurrentTrip = true

        trip.uploadFile(
            "ride",
            withController: self,
            error:
                #selector(
                    uploadTripError(_:)
                ),
            completion:
                #selector(
                    uploadTripCompleted(_:)
                )
        )
    }

    // MARK: - Finish

    private func finishBatch() {
        guard !finished else {
            return
        }

        finished = true
        processingCurrentTrip = false
        isUploading = false

        completedCount = totalCount
        progress =
            totalCount > 0
            ? 1.0
            : 0.0

        alertTitle = "SimRa"

        if failureCount == 0 {

            if successCount == 1 {
                alertMessage =
                    NSLocalizedString(
                        "Trip uploaded successfully.",
                        comment:
                            "Trip upload success"
                    )
            } else {
                alertMessage =
                    String(
                        format:
                            NSLocalizedString(
                                "%d trips uploaded successfully.",
                                comment:
                                    "Trips upload success"
                            ),
                        successCount
                    )
            }

        } else {

            alertMessage =
                String(
                    format:
                        NSLocalizedString(
                            "%d succeeded, %d failed.",
                            comment:
                                "Partial upload failure"
                        ),
                    successCount,
                    failureCount
                )
        }

        showAlert = true

        queue.removeAll(
            keepingCapacity: false
        )

        currentIndex = 0
    }
}
