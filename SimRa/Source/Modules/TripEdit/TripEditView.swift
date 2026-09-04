//
//  TripEditView.swift
//  SimRa
//
//  SwiftUI trip editor
//

import SwiftUI
import MapKit

// MARK: - Trip Point

/// SwiftUI representation of an incident attached to a trip location.
struct TripPoint: Identifiable {

    let id = UUID()
    let tripLocation: TripLocation
    let title: String

    var coordinate: CLLocationCoordinate2D {
        tripLocation.location.coordinate
    }

    var subtitle: String {
        DateFormatter.localizedString(
            from: tripLocation.location.timestamp,
            dateStyle: .short,
            timeStyle: .medium
        )
    }
}

// MARK: - View Model

@MainActor
final class TripEditViewModel: ObservableObject {

    let trip: Trip

    @Published private(set) var locations: [TripLocation] = []
    @Published var startIndex = 0
    @Published var endIndex = 0
    @Published private(set) var tripPoints: [TripPoint] = []
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published private(set) var changed = false

    /// Incident titles supplied by the SwiftUI app layer.
    private let incidentTitles: [String]

    init(
        trip: Trip,
        incidentTitles: [String]? = nil
    ) {
        self.trip = trip

        if let incidentTitles, !incidentTitles.isEmpty {
            self.incidentTitles = incidentTitles
        } else {
            self.incidentTitles =
                (AppDelegate.shared().constants["incidents"] as? [String]) ?? []
        }

        reload()
    }

    // MARK: - State

    var editingDisabled: Bool {
        trip.uploaded || trip.statisticsAdded
    }

    var hasLocations: Bool {
        !locations.isEmpty
    }

    var hasChangedRange: Bool {
        guard !locations.isEmpty else {
            return false
        }

        return startIndex != 0 ||
            endIndex != locations.count - 1
    }

    // MARK: - Reload

    func reload() {
        locations = trip.tripLocations.compactMap {
            $0 as? TripLocation
        }

        guard !locations.isEmpty else {
            startIndex = 0
            endIndex = 0
            tripPoints = []
            cameraPosition = .automatic
            return
        }

        startIndex = 0
        endIndex = locations.count - 1

        rebuildTripPoints()
        updateCamera()
    }

    // MARK: - Selection

    func updateStartIndex(_ value: Int) {
        guard !locations.isEmpty else {
            return
        }

        let maximum = max(
            endIndex - 1,
            0
        )

        let newValue = min(
            max(value, 0),
            maximum
        )

        guard newValue != startIndex else {
            return
        }

        startIndex = newValue
        changed = true
    }

    func updateEndIndex(_ value: Int) {
        guard !locations.isEmpty else {
            return
        }

        let minimum = min(
            startIndex + 1,
            locations.count - 1
        )

        let newValue = max(
            min(
                value,
                locations.count - 1
            ),
            minimum
        )

        guard newValue != endIndex else {
            return
        }

        endIndex = newValue
        changed = true
    }

    // MARK: - Apply Trim

    func applySelection() {
        guard !locations.isEmpty else {
            return
        }

        let lower = min(
            startIndex,
            endIndex
        )

        let upper = max(
            startIndex,
            endIndex
        )

        guard lower >= 0,
              upper < locations.count
        else {
            return
        }

        // Nothing to trim.
        guard lower > 0 ||
              upper < locations.count - 1
        else {
            return
        }

        let selectedLocations = Array(
            locations[lower...upper]
        )

        guard !selectedLocations.isEmpty else {
            return
        }

        updateCSVFiles(
            for: selectedLocations
        )

        let removedLocations = locations
            .enumerated()
            .filter { index, _ in
                index < lower ||
                index > upper
            }
            .map(\.element)

        for location in removedLocations {
            location.tripMotions.removeAllObjects()
            location.tripAnnotation = nil
        }

        trip.tripLocations.removeAllObjects()

        trip.tripLocations.addObjects(
            from: selectedLocations
        )

        trip.edited = true
        trip.save()

        locations = selectedLocations

        startIndex = 0
        endIndex = max(
            selectedLocations.count - 1,
            0
        )

        changed = false

        rebuildTripPoints()
        updateCamera()

        NotificationCenter.default.post(
            name: Notification.Name("tripEdited"),
            object: trip
        )
    }

    // MARK: - CSV

    private func updateCSVFiles(
        for selectedLocations: [TripLocation]
    ) {
        let documentsURL =
            Self.documentsDirectoryURL()

        let locationsURL =
            documentsURL.appendingPathComponent(
                "TripLocations-\(trip.identifier).csv"
            )

        let motionsURL =
            documentsURL.appendingPathComponent(
                "TripMotions-\(trip.identifier).csv"
            )

        var locationLines: [String] = []
        var motionLines: [String] = []

        for location in selectedLocations {

            let gyro =
                location.gyro ?? TripGyro()

            let locationLine =
                TripGyro().locationString(
                    from: location,
                    gyro: gyro,
                    closePassInfo:
                        location.closePassInfo
                )

            locationLines.append(
                locationLine
            )

            for case let motion
                    as TripMotion
                    in location.tripMotions {

                let motionLine =
                    TripMotion().motionString(
                        from: motion
                    )

                motionLines.append(
                    motionLine
                )
            }
        }

        if let data = locationLines
            .joined(separator: "\n")
            .data(using: .utf8) {

            try? data.write(
                to: locationsURL,
                options: .atomic
            )
        }

        if let data = motionLines
            .joined(separator: "\n")
            .data(using: .utf8) {

            try? data.write(
                to: motionsURL,
                options: .atomic
            )
        }
    }

    private static func documentsDirectoryURL() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    // MARK: - Persistence

    func saveTrimmed() {
        trip.edited = true
        trip.save()

        changed = false

        NotificationCenter.default.post(
            name: Notification.Name("tripEdited"),
            object: trip
        )
    }

    func persistAnnotations() {
        trip.save()
        changed = false
    }

    // MARK: - Incidents

    private func rebuildTripPoints() {
        tripPoints = locations.compactMap { location in

            guard let annotation =
                    location.tripAnnotation
            else {
                return nil
            }

            let title =
                incidentTitle(
                    for: annotation
                )
                ??
                NSLocalizedString(
                    "Danger",
                    comment: "Fallback incident title"
                )

            return TripPoint(
                tripLocation: location,
                title: title
            )
        }
    }

    @discardableResult
    func addAnnotation(
        at coordinate: CLLocationCoordinate2D
    ) -> TripPoint? {

        guard !editingDisabled,
              !locations.isEmpty
        else {
            return nil
        }

        let target = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        var closestLocation:
            TripLocation?

        var closestDistance =
            CLLocationDistance
                .greatestFiniteMagnitude

        for tripLocation in locations {

            let distance =
                tripLocation.location.distance(
                    from: target
                )

            if distance < closestDistance {
                closestDistance = distance
                closestLocation = tripLocation
            }
        }

        guard let closestLocation,
              closestLocation.tripAnnotation == nil
        else {
            return nil
        }

        let annotation =
            TripAnnotation()

        closestLocation.tripAnnotation =
            annotation

        let title =
            incidentTitle(
                for: annotation
            )
            ??
            NSLocalizedString(
                "Danger",
                comment: "Fallback incident title"
            )

        let point =
            TripPoint(
                tripLocation: closestLocation,
                title: title
            )

        tripPoints.append(point)

        trip.edited = true
        trip.save()

        NotificationCenter.default.post(
            name: Notification.Name("tripEdited"),
            object: trip
        )

        NotificationCenter.default.post(
            name: Notification.Name("annotationChanged"),
            object: trip
        )

        return point
    }

    func deleteAnnotation(
        _ tripPoint: TripPoint
    ) {
        guard !editingDisabled else {
            return
        }

        tripPoint
            .tripLocation
            .tripAnnotation = nil

        tripPoints.removeAll {
            $0.id == tripPoint.id
        }

        trip.edited = true
        trip.save()

        changed = false

        NotificationCenter.default.post(
            name: Notification.Name("tripEdited"),
            object: trip
        )

        NotificationCenter.default.post(
            name: Notification.Name("annotationChanged"),
            object: trip
        )
    }

    // MARK: - Incident Title

    private func incidentTitle(
        for annotation: TripAnnotation?
    ) -> String? {

        guard let annotation else {
            return nil
        }

        let incidentID =
            Int(annotation.incidentId)

        guard incidentID >= 0,
              incidentID < incidentTitles.count
        else {
            return nil
        }

        return incidentTitles[incidentID]
    }

    // MARK: - Camera

    private func updateCamera() {
        let coordinates =
            locations.map {
                $0.location.coordinate
            }

        guard !coordinates.isEmpty else {
            cameraPosition = .automatic
            return
        }

        var rect =
            MKMapRect.null

        for coordinate in coordinates {

            let point =
                MKMapPoint(coordinate)

            let pointRect =
                MKMapRect(
                    x: point.x,
                    y: point.y,
                    width: 0,
                    height: 0
                )

            rect =
                rect.isNull
                ? pointRect
                : rect.union(pointRect)
        }

        guard !rect.isNull else {
            return
        }

        let horizontalPadding =
            max(
                rect.size.width * 0.12,
                100
            )

        let verticalPadding =
            max(
                rect.size.height * 0.18,
                150
            )

        cameraPosition =
            .rect(
                rect.insetBy(
                    dx: -horizontalPadding,
                    dy: -verticalPadding
                )
            )
    }
}

// MARK: - Main View

struct TripEditView: View {

    @ObservedObject
    var viewModel: TripEditViewModel

    @State
    private var editingTripPoint:
        TripPoint?

    @State
    private var showTripDetails =
        false

    var body: some View {

        NavigationStack {

            MapEditor(
                viewModel: viewModel,
                onEditAnnotation: {
                    editingTripPoint = $0
                }
            )
            .ignoresSafeArea()
            .safeAreaInset(
                edge: .bottom,
                spacing: 0
            ) {
                BottomEditor(
                    viewModel: viewModel
                )
                .padding(
                    .horizontal,
                    16
                )
                .padding(
                    .bottom,
                    8
                )
            }
            .navigationTitle(
                NSLocalizedString(
                    "Edit trip",
                    comment:
                        "Trip editor title"
                )
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                // MARK: Details

                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button {
                        showTripDetails = true
                    } label: {
                        Image(
                            systemName:
                                "info.circle"
                        )
                    }
                    .accessibilityLabel(
                        NSLocalizedString(
                            "Details",
                            comment:
                                "Trip details button"
                        )
                    )
                }

                // MARK: Trim

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {
                    Button {
                        viewModel.applySelection()
                    } label: {
                        Text(
                            NSLocalizedString(
                                "Trim",
                                comment:
                                    "Trim trip"
                            )
                        )
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        viewModel.editingDisabled ||
                        !viewModel.hasChangedRange
                    )
                }
            }
            .sheet(
                isPresented:
                    $showTripDetails
            ) {
                NavigationStack {
                    TripDetailView(
                        trip:
                            viewModel.trip
                    )
                }
                .presentationDetents([
                    .medium,
                    .large
                ])
                .presentationDragIndicator(
                    .visible
                )
            }
            .sheet(
                item:
                    $editingTripPoint
            ) { point in
                NavigationStack {
                    if let annotation =
                        point.tripLocation.tripAnnotation {

                        AnnotationView(
                            tripAnnotation:
                                annotation,
                            trip:
                                viewModel.trip
                        )
                    }
                }
            }
            .onDisappear {
                viewModel.persistAnnotations()
            }
        }
    }
}

// MARK: - Map

private struct MapEditor: View {

    @ObservedObject
    var viewModel:
        TripEditViewModel

    let onEditAnnotation:
        (TripPoint) -> Void

    @State
    private var lastPressLocation:
        CGPoint?

    var body: some View {

        MapReader { proxy in

            Map(
                position:
                    $viewModel.cameraPosition
            ) {
                completeTrack
                selectedTrack
                startAnnotation
                endAnnotation
                incidentAnnotations
            }
            .mapStyle(
                .standard(
                    elevation: .realistic
                )
            )
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .mapControlVisibility(
                .visible
            )
            .safeAreaPadding(
                .top,
                96
            )
            .safeAreaPadding(
                .bottom,
                96
            )
            .simultaneousGesture(
                DragGesture(
                    minimumDistance: 0
                )
                .onChanged { value in
                    lastPressLocation =
                        value.location
                }
            )
            .simultaneousGesture(
                LongPressGesture(
                    minimumDuration:
                        0.55
                )
                .onEnded { _ in

                    guard
                        let location =
                            lastPressLocation,
                        let coordinate =
                            proxy.convert(
                                location,
                                from: .local
                            ),
                        let point =
                            viewModel.addAnnotation(
                                at: coordinate
                            )
                    else {
                        return
                    }

                    onEditAnnotation(
                        point
                    )
                }
            )
        }
    }

    // MARK: - Complete Track

    @MapContentBuilder
    private var completeTrack:
        some MapContent {

        if viewModel.locations.count > 1 {

            MapPolyline(
                coordinates:
                    viewModel.locations.map {
                        $0.location.coordinate
                    }
            )
            .stroke(
                Color.primary.opacity(
                    0.23
                ),
                lineWidth: 3
            )
        }
    }

    // MARK: - Selected Track

    @MapContentBuilder
    private var selectedTrack:
        some MapContent {

        if viewModel.locations.count > 1 {

            let start =
                min(
                    viewModel.startIndex,
                    viewModel.locations.count - 1
                )

            let end =
                min(
                    viewModel.endIndex,
                    viewModel.locations.count - 1
                )

            if start <= end {

                let selected =
                    Array(
                        viewModel.locations[
                            start...end
                        ]
                    )

                if selected.count > 1 {

                    MapPolyline(
                        coordinates:
                            selected.map {
                                $0.location.coordinate
                            }
                    )
                    .stroke(
                        .tint,
                        lineWidth: 5
                    )
                }
            }
        }
    }

    // MARK: - Start

    @MapContentBuilder
    private var startAnnotation:
        some MapContent {

        if let coordinate =
            coordinate(
                at:
                    viewModel.startIndex
            ) {

            Annotation(
                "",
                coordinate:
                    coordinate
            ) {
                EndpointMarker(
                    systemImage:
                        "play.fill",
                    tint:
                        .green
                )
            }
        }
    }

    // MARK: - End

    @MapContentBuilder
    private var endAnnotation:
        some MapContent {

        if let coordinate =
            coordinate(
                at:
                    viewModel.endIndex
            ) {

            Annotation(
                "",
                coordinate:
                    coordinate
            ) {
                EndpointMarker(
                    systemImage:
                        "flag.checkered",
                    tint:
                        .red
                )
            }
        }
    }

    // MARK: - Incidents

    @MapContentBuilder
    private var incidentAnnotations:
        some MapContent {

        ForEach(
            viewModel.tripPoints
        ) { point in

            Annotation(
                point.title,
                coordinate:
                    point.coordinate
            ) {
                Button {
                    onEditAnnotation(
                        point
                    )
                } label: {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .caption.weight(
                            .bold
                        )
                    )
                    .foregroundStyle(
                        .white
                    )
                    .frame(
                        width: 30,
                        height: 30
                    )
                    .background(
                        incidentColor(
                            for: point
                        ),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                .white.opacity(
                                    0.9
                                ),
                                lineWidth: 1.5
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    point.title
                )
                .accessibilityHint(
                    NSLocalizedString(
                        "Edit incident",
                        comment:
                            "Incident annotation hint"
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    private func coordinate(
        at index: Int
    ) -> CLLocationCoordinate2D? {

        guard
            index >= 0,
            index < viewModel.locations.count
        else {
            return nil
        }

        return viewModel.locations[index]
            .location
            .coordinate
    }

    private func incidentColor(
        for point: TripPoint
    ) -> Color {

        guard let annotation =
                point.tripLocation
                    .tripAnnotation
        else {
            return .blue
        }

        // Different colors for different sources
        if annotation.source == "Siri" {
            return annotation.frightening ? .purple : .blue
        } else if annotation.source != "Manual" {
            return annotation.frightening ? .indigo : .cyan
        }

        return annotation.frightening
            ? .red
            : .orange
    }
}

// MARK: - Endpoint Marker

private struct EndpointMarker:
    View {

    let systemImage: String
    let tint: Color

    var body: some View {
        Image(
            systemName:
                systemImage
        )
        .font(
            .caption.weight(.bold)
        )
        .foregroundStyle(
            .white
        )
        .frame(
            width: 30,
            height: 30
        )
        .background(
            tint,
            in: Circle()
        )
        .overlay {
            Circle()
                .stroke(
                    .white.opacity(
                        0.9
                    ),
                    lineWidth: 1.5
                )
        }
    }
}

// MARK: - Bottom Editor

private struct BottomEditor:
    View {

    @ObservedObject
    var viewModel:
        TripEditViewModel

    var body: some View {

        RangeSlider(
            startIndex:
                $viewModel.startIndex,
            endIndex:
                $viewModel.endIndex,
            count:
                viewModel.locations.count,
            disabled:
                viewModel.editingDisabled,
            onStartChanged:
                viewModel.updateStartIndex,
            onEndChanged:
                viewModel.updateEndIndex
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            10
        )
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(
                    0.08
                ),
                lineWidth: 0.5
            )
        }
    }
}

// MARK: - Range Slider

private struct RangeSlider:
    View {

    @Binding
    var startIndex: Int

    @Binding
    var endIndex: Int

    let count: Int
    let disabled: Bool

    let onStartChanged:
        (Int) -> Void

    let onEndChanged:
        (Int) -> Void

    @State
    private var activeHandle:
        Handle?

    private enum Handle {
        case start
        case end
    }

    var body: some View {

        GeometryReader { geometry in

            let inset: CGFloat = 18

            let width =
                max(
                    geometry.size.width -
                        inset * 2,
                    1
                )

            let maximum =
                max(
                    count - 1,
                    1
                )

            let centerY =
                geometry.size.height / 2

            let startX =
                position(
                    index:
                        startIndex,
                    maximum:
                        maximum,
                    width:
                        width,
                    inset:
                        inset
                )

            let endX =
                position(
                    index:
                        endIndex,
                    maximum:
                        maximum,
                    width:
                        width,
                    inset:
                        inset
                )

            ZStack {

                Capsule()
                    .fill(
                        Color.primary.opacity(
                            0.12
                        )
                    )
                    .frame(
                        height: 5
                    )
                    .position(
                        x:
                            geometry.size.width / 2,
                        y:
                            centerY
                    )

                Capsule()
                    .fill(.tint)
                    .frame(
                        width:
                            max(
                                endX - startX,
                                6
                            ),
                        height: 5
                    )
                    .position(
                        x:
                            (startX + endX) / 2,
                        y:
                            centerY
                    )

                sliderHandle(
                    type: .start,
                    x: startX,
                    y: centerY
                )
                .gesture(
                    dragGesture(
                        handle: .start,
                        width: width,
                        inset: inset,
                        maximum: maximum
                    )
                )

                sliderHandle(
                    type: .end,
                    x: endX,
                    y: centerY
                )
                .gesture(
                    dragGesture(
                        handle: .end,
                        width: width,
                        inset: inset,
                        maximum: maximum
                    )
                )
            }
        }
        .frame(
            height: 38
        )
        .opacity(
            disabled ? 0.45 : 1
        )
        .accessibilityElement(
            children: .contain
        )
    }

    // MARK: - Handle

    private func sliderHandle(
        type: Handle,
        x: CGFloat,
        y: CGFloat
    ) -> some View {

        let isStart =
            type == .start

        let tint: Color =
            isStart
            ? .green
            : .red

        return Circle()
            .fill(.background)
            .frame(
                width: 28,
                height: 28
            )
            .overlay {
                Circle()
                    .stroke(
                        tint,
                        lineWidth:
                            activeHandle == type
                            ? 2
                            : 1.25
                    )
            }
            .overlay {
                Image(
                    systemName:
                        isStart
                        ? "play.fill"
                        : "flag.checkered"
                )
                .font(
                    .caption2.weight(
                        .bold
                    )
                )
                .foregroundStyle(
                    tint
                )
            }
            .scaleEffect(
                activeHandle == type
                ? 1.08
                : 1
            )
            .animation(
                .easeOut(
                    duration: 0.12
                ),
                value:
                    activeHandle == type
            )
            .position(
                x: x,
                y: y
            )
    }

    // MARK: - Gesture

    private func dragGesture(
        handle: Handle,
        width: CGFloat,
        inset: CGFloat,
        maximum: Int
    ) -> some Gesture {

        DragGesture(
            minimumDistance: 0
        )
        .onChanged { value in

            guard !disabled else {
                return
            }

            activeHandle = handle

            let normalized =
                min(
                    max(
                        (
                            value.location.x -
                            inset
                        ) / width,
                        0
                    ),
                    1
                )

            let index =
                Int(
                    (
                        normalized *
                        CGFloat(
                            maximum
                        )
                    )
                    .rounded()
                )

            switch handle {

            case .start:

                let newValue =
                    min(
                        max(
                            index,
                            0
                        ),
                        max(
                            endIndex - 1,
                            0
                        )
                    )

                if newValue != startIndex {
                    startIndex = newValue
                    onStartChanged(
                        newValue
                    )
                }

            case .end:

                let newValue =
                    max(
                        min(
                            index,
                            maximum
                        ),
                        min(
                            startIndex + 1,
                            maximum
                        )
                    )

                if newValue != endIndex {
                    endIndex = newValue
                    onEndChanged(
                        newValue
                    )
                }
            }
        }
        .onEnded { _ in
            activeHandle = nil
        }
    }

    // MARK: - Position

    private func position(
        index: Int,
        maximum: Int,
        width: CGFloat,
        inset: CGFloat
    ) -> CGFloat {

        guard maximum > 0 else {
            return inset
        }

        return inset +
            (
                CGFloat(index) /
                CGFloat(maximum)
            ) *
            width
    }
}
