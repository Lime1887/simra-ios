//
//  TripEditView.swift
//  SimRa
//
//  Created by Emil Pauls on 25.08.26.
//

import SwiftUI
import MapKit

// MARK: - Trip Point

@objcMembers
public final class TripPoint: NSObject, MKAnnotation {

    public var title: String?
    public var tripLocation: TripLocation

    public var subtitle: String? {
        let date = tripLocation.location.timestamp

        return DateFormatter.localizedString(
            from: date,
            dateStyle: .short,
            timeStyle: .medium
        )
    }

    public var coordinate: CLLocationCoordinate2D {
        tripLocation.location.coordinate
    }

    public init(tripLocation: TripLocation) {
        self.tripLocation = tripLocation
        super.init()
    }
}

// MARK: - Host Delegate

@objc
public protocol TripEditViewHostDelegate: AnyObject {

    func tripEditViewHostDidRequestDetails(
        _ host: TripEditViewHostController
    )

    func tripEditViewHost(
        _ host: TripEditViewHostController,
        didRequestAnnotationEdit tripPoint: TripPoint
    )
}

// MARK: - View Model

@MainActor
final class TripEditViewModel: ObservableObject {

    let trip: Trip

    @Published private(set) var locations: [TripLocation] = []

    @Published var startIndex: Int = 0
    @Published var endIndex: Int = 0

    @Published private(set) var tripPoints: [TripPoint] = []

    @Published var cameraPosition: MapCameraPosition = .automatic

    @Published private(set) var changed = false

    init(trip: Trip) {
        self.trip = trip
        reload()
    }

    // MARK: - Computed State

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

    var selectedPointCount: Int {
        guard !locations.isEmpty else {
            return 0
        }

        return max(
            endIndex - startIndex + 1,
            0
        )
    }

    // MARK: - Reload

    func reload() {

        locations =
            (trip.tripLocations as? [TripLocation]) ?? []

        guard !locations.isEmpty else {
            startIndex = 0
            endIndex = 0
            tripPoints = []
            cameraPosition = .automatic
            return
        }

        let lastIndex = locations.count - 1

        if endIndex == 0 && startIndex == 0 {
            endIndex = lastIndex
        } else {
            startIndex = min(
                max(startIndex, 0),
                lastIndex
            )

            endIndex = min(
                max(endIndex, startIndex),
                lastIndex
            )
        }

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

    func resetSelection() {

        guard !locations.isEmpty else {
            return
        }

        startIndex = 0
        endIndex = locations.count - 1

        changed = true
    }

    // MARK: - Apply

    func applySelection() {

        guard !locations.isEmpty else {
            return
        }

        guard startIndex >= 0,
              endIndex >= 0,
              startIndex < locations.count,
              endIndex < locations.count else {
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

        let selectedLocations = Array(
            locations[lower...upper]
        )

        guard !selectedLocations.isEmpty else {
            return
        }

        trip.tripLocations.removeAllObjects()

        for location in selectedLocations {
            trip.tripLocations.add(location)
        }

        changed = true

        save()
        reload()
    }

    // MARK: - Save

    func save() {

        guard changed else {
            return
        }

        trip.edited = true
        trip.save()

        changed = false
    }

    // MARK: - Incident Annotations

    private func rebuildTripPoints() {

        tripPoints = []

        for location in locations {

            guard location.tripAnnotation != nil else {
                continue
            }

            guard let title = incidentTitle(
                for: location.tripAnnotation
            ) else {
                continue
            }

            let point = TripPoint(
                tripLocation: location
            )

            point.title = title
            point.tripLocation = location

            tripPoints.append(point)
        }
    }

    func deleteAnnotation(
        _ tripPoint: TripPoint
    ) {

        guard !editingDisabled else {
            return
        }

        tripPoint.tripLocation.tripAnnotation = nil

        tripPoints.removeAll {
            $0 === tripPoint
        }

        changed = true
    }

    func addAnnotation(
        at coordinate: CLLocationCoordinate2D
    ) {

        guard !editingDisabled else {
            return
        }

        guard !locations.isEmpty else {
            return
        }

        let target = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        var closest: TripLocation?

        var closestDistance =
            CLLocationDistance.greatestFiniteMagnitude

        for tripLocation in locations {

            let location = tripLocation.location

            let distance = location.distance(
                from: target
            )

            if distance < closestDistance {
                closestDistance = distance
                closest = tripLocation
            }
        }

        guard let closest else {
            return
        }

        guard closest.tripAnnotation == nil else {
            return
        }

        let annotation = TripAnnotation()

        closest.tripAnnotation = annotation

        guard let title = incidentTitle(
            for: annotation
        ) else {
            closest.tripAnnotation = nil
            return
        }

        let point = TripPoint(
            tripLocation: closest
        )

        point.title = title
        point.tripLocation = closest

        tripPoints.append(point)

        changed = true
    }

    private func incidentTitle(
        for annotation: TripAnnotation?
    ) -> String? {

        guard let annotation else {
            return nil
        }

        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
            return nil
        }

        guard let incidents =
            appDelegate.constants["incidents"] as? [String] else {
            return nil
        }

        let incidentID = Int(
            annotation.incidentId
        )

        guard incidentID >= 0,
              incidentID < incidents.count else {
            return nil
        }

        return incidents[incidentID]
    }

    // MARK: - Camera

    private func updateCamera() {

        let coordinates = locations.compactMap {
            $0.location.coordinate
        }

        guard !coordinates.isEmpty else {
            cameraPosition = .automatic
            return
        }

        var rect = MKMapRect.null

        for coordinate in coordinates {

            let point = MKMapPoint(coordinate)

            let pointRect = MKMapRect(
                x: point.x,
                y: point.y,
                width: 0,
                height: 0
            )

            if rect.isNull {
                rect = pointRect
            } else {
                rect = rect.union(pointRect)
            }
        }

        guard !rect.isNull else {
            return
        }

        let horizontalPadding =
            max(rect.size.width * 0.12, 100)

        let verticalPadding =
            max(rect.size.height * 0.22, 150)

        let paddedRect = rect.insetBy(
            dx: -horizontalPadding,
            dy: -verticalPadding
        )

        cameraPosition = .rect(paddedRect)
    }
}

// MARK: - Host Controller

@available(iOS 17.0, *)
@objcMembers
public final class TripEditViewHostController:
    UIViewController {

    private let trip: Trip

    private weak var delegate:
        TripEditViewHostDelegate?

    private var viewModel:
        TripEditViewModel

    private var hostingController:
        UIHostingController<TripEditView>!

    @objc
    public init(
        trip: Trip,
        delegate: TripEditViewHostDelegate
    ) {

        self.trip = trip
        self.delegate = delegate
        self.viewModel = TripEditViewModel(
            trip: trip
        )

        super.init(
            nibName: nil,
            bundle: nil
        )

        self.hostingController =
            UIHostingController(
                rootView: TripEditView(
                    viewModel: self.viewModel,
                    onShowDetails: {},
                    onEditAnnotation: { _ in }
                )
            )

        updateRootView()
        embedHostingController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    @objc
    public func reload() {

        viewModel = TripEditViewModel(
            trip: trip
        )

        updateRootView()
    }

    private func updateRootView() {

        hostingController.rootView =
            TripEditView(
                viewModel: viewModel,

                onShowDetails: { [weak self] in
                    guard let self else {
                        return
                    }

                    self.delegate?
                        .tripEditViewHostDidRequestDetails(
                            self
                        )
                },

                onEditAnnotation: { [weak self] tripPoint in
                    guard let self else {
                        return
                    }

                    self.delegate?
                        .tripEditViewHost(
                            self,
                            didRequestAnnotationEdit: tripPoint
                        )
                }
            )
    }

    private func embedHostingController() {

        view.backgroundColor = .clear

        addChild(hostingController)

        hostingController.view.translatesAutoresizingMaskIntoConstraints =
            false

        hostingController.view.backgroundColor =
            .clear

        view.addSubview(
            hostingController.view
        )

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            hostingController.view.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            hostingController.view.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            hostingController.view.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])

        hostingController.didMove(
            toParent: self
        )
    }
}

// MARK: - Main View

struct TripEditView: View {

    @ObservedObject var viewModel:
        TripEditViewModel

    let onShowDetails: () -> Void

    let onEditAnnotation:
        (TripPoint) -> Void

    var body: some View {

        ZStack(alignment: .bottom) {

            TripMap(
                viewModel: viewModel,
                onEditAnnotation: onEditAnnotation
            )
            .ignoresSafeArea()

            BottomEditor(
                viewModel: viewModel
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .toolbar {

            // MARK: Centered Navigation Title

            ToolbarItem(
                placement: .principal
            ) {

                Text(
                    NSLocalizedString(
                        "Edit trip",
                        comment: ""
                    )
                )
                .font(.headline)
            }

            // MARK: Details

            ToolbarItem(
                placement: .topBarLeading
            ) {

                Button(
                    action: onShowDetails
                ) {

                    Image(
                        systemName: "info.circle"
                    )
                }
                .accessibilityLabel(
                    NSLocalizedString(
                        "Details",
                        comment: ""
                    )
                )
            }

            // MARK: Done

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Button {

                    viewModel.applySelection()

                } label: {

                    Text(
                        NSLocalizedString(
                            "Done",
                            comment: ""
                        )
                    )
                    .fontWeight(.semibold)
                }
                .disabled(
                    viewModel.editingDisabled ||
                    !viewModel.hasChangedRange
                )
            }
        }
    }
}

// MARK: - Map

private struct TripMap: View {

    @ObservedObject var viewModel:
        TripEditViewModel

    let onEditAnnotation:
        (TripPoint) -> Void

    var body: some View {

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
    }

    @MapContentBuilder
    private var completeTrack:
        some MapContent {

        if viewModel.locations.count > 1 {

            MapPolyline(
                coordinates:
                    viewModel.locations.compactMap {
                        $0.location.coordinate
                    }
            )
            .stroke(
                Color.red.opacity(0.42),
                lineWidth: 3
            )
        }
    }

    @MapContentBuilder
    private var selectedTrack:
        some MapContent {

        if viewModel.locations.count > 1 {

            let start = min(
                viewModel.startIndex,
                viewModel.locations.count - 1
            )

            let end = min(
                viewModel.endIndex,
                viewModel.locations.count - 1
            )

            if start <= end {

                let selected = Array(
                    viewModel.locations[start...end]
                )

                if selected.count > 1 {

                    MapPolyline(
                        coordinates:
                            selected.compactMap {
                                $0.location.coordinate
                            }
                    )
                    .stroke(
                        Color.accentColor,
                        lineWidth: 5
                    )
                }
            }
        }
    }

    // MARK: Start Annotation

    @MapContentBuilder
    private var startAnnotation:
        some MapContent {

        if let coordinate =
            coordinate(at: viewModel.startIndex) {

            Annotation(
                NSLocalizedString(
                    "Start",
                    comment: ""
                ),
                coordinate: coordinate
            ) {

                ZStack {

                    Circle()
                        .fill(.white)
                        .frame(
                            width: 36,
                            height: 36
                        )

                    Circle()
                        .fill(.green)
                        .frame(
                            width: 26,
                            height: 26
                        )

                    Image(
                        systemName: "arrow.down"
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                }
                .shadow(
                    color:
                        .black.opacity(0.22),
                    radius: 5,
                    y: 2
                )
            }
        }
    }

    // MARK: End Annotation

    @MapContentBuilder
    private var endAnnotation:
        some MapContent {

        if let coordinate =
            coordinate(at: viewModel.endIndex) {

            Annotation(
                NSLocalizedString(
                    "Finish",
                    comment: ""
                ),
                coordinate: coordinate
            ) {

                ZStack {

                    Circle()
                        .fill(.white)
                        .frame(
                            width: 36,
                            height: 36
                        )

                    Circle()
                        .fill(.red)
                        .frame(
                            width: 26,
                            height: 26
                        )

                    Image(
                        systemName: "flag.fill"
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                }
                .shadow(
                    color:
                        .black.opacity(0.22),
                    radius: 5,
                    y: 2
                )
            }
        }
    }

    // MARK: Incident Annotations

    @MapContentBuilder
    private var incidentAnnotations:
        some MapContent {

        ForEach(
            Array(
                viewModel.tripPoints.enumerated()
            ),
            id: \.offset
        ) { _, point in

            let coordinate =
                point.tripLocation.location.coordinate

            Annotation(
                point.title ?? "",
                coordinate: coordinate
            ) {

                Button {

                    onEditAnnotation(point)

                } label: {

                    Image(
                        systemName:
                            "exclamationmark"
                    )
                    .font(
                        .system(
                            size: 14,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(
                        width: 30,
                        height: 30
                    )
                    .background(
                        incidentColor(point),
                        in: Circle()
                    )
                    .shadow(
                        color:
                            .black.opacity(0.2),
                        radius: 4,
                        y: 2
                    )
                }
            }
        }
    }

    private func coordinate(
        at index: Int
    ) -> CLLocationCoordinate2D? {

        guard index >= 0,
              index < viewModel.locations.count else {
            return nil
        }

        return viewModel.locations[index]
            .location
            .coordinate
    }

    private func incidentColor(
        _ point: TripPoint
    ) -> Color {

        guard let annotation =
            point.tripLocation.tripAnnotation else {
            return .blue
        }

        let incidentID =
            Int(annotation.incidentId)

        return incidentID == 0
            ? .orange
            : .blue
    }
}

// MARK: - Bottom Editor

private struct BottomEditor: View {

    @ObservedObject var viewModel:
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
            onStartChanged: {
                viewModel.updateStartIndex($0)
            },
            onEndChanged: {
                viewModel.updateEndIndex($0)
            }
        )
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .modifier(
            BottomEditorGlassModifier()
        )
    }
}

// MARK: - Bottom Editor Glass

private struct BottomEditorGlassModifier:
    ViewModifier {

    func body(
        content: Content
    ) -> some View {

        if #available(iOS 26.0, *) {

            content
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )

        } else {

            content
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                    .stroke(
                        Color.primary.opacity(0.08),
                        lineWidth: 0.7
                    )
                }
        }
    }
}

// MARK: - Range Slider

private struct RangeSlider: View {

    @Binding var startIndex: Int
    @Binding var endIndex: Int

    let count: Int
    let disabled: Bool

    let onStartChanged:
        (Int) -> Void

    let onEndChanged:
        (Int) -> Void

    @State private var activeHandle:
        Handle?

    private enum Handle {
        case start
        case end
    }

    var body: some View {

        GeometryReader { geometry in

            let inset: CGFloat = 18

            let width = max(
                geometry.size.width -
                inset * 2,
                1
            )

            let maximum = max(
                count - 1,
                1
            )

            let startX = position(
                index: startIndex,
                maximum: maximum,
                width: width,
                inset: inset
            )

            let endX = position(
                index: endIndex,
                maximum: maximum,
                width: width,
                inset: inset
            )

            ZStack {

                // Track

                Capsule()
                    .fill(
                        Color.primary.opacity(0.12)
                    )
                    .frame(height: 6)
                    .padding(
                        .horizontal,
                        inset
                    )

                // Selected range

                Capsule()
                    .fill(
                        Color.accentColor
                    )
                    .frame(
                        width:
                            max(
                                endX - startX,
                                6
                            ),
                        height: 6
                    )
                    .position(
                        x:
                            (startX + endX) / 2,
                        y:
                            geometry.size.height / 2
                    )

                // Start handle

                handle(
                    type: .start,
                    x: startX
                )
                .gesture(
                    dragGesture(
                        handle: .start,
                        width: width,
                        inset: inset,
                        maximum: maximum
                    )
                )

                // End handle

                handle(
                    type: .end,
                    x: endX
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
        .frame(height: 44)
        .opacity(
            disabled ? 0.45 : 1
        )
    }

    // MARK: Handle

    private func handle(
        type: Handle,
        x: CGFloat
    ) -> some View {

        Group {

            if #available(iOS 26.0, *) {

                ZStack {

                    Circle()
                        .fill(
                            Color.accentColor
                                .opacity(0.9)
                        )
                        .frame(
                            width: 30,
                            height: 30
                        )

                    Capsule()
                        .fill(.white)
                        .frame(
                            width: 3,
                            height: 12
                        )
                }
                .glassEffect(
                    .regular.interactive(),
                    in: Circle()
                )

            } else {

                ZStack {

                    Circle()
                        .fill(.background)
                        .frame(
                            width: 32,
                            height: 32
                        )
                        .shadow(
                            color:
                                .black.opacity(0.18),
                            radius: 5,
                            y: 2
                        )

                    Circle()
                        .stroke(
                            Color.accentColor,
                            lineWidth:
                                activeHandle == type
                                ? 2
                                : 1
                        )
                        .frame(
                            width: 32,
                            height: 32
                        )

                    Capsule()
                        .fill(
                            Color.accentColor
                        )
                        .frame(
                            width: 3,
                            height: 12
                        )
                }
            }
        }
        .scaleEffect(
            activeHandle == type
            ? 1.08
            : 1
        )
        .position(
            x: x,
            y: 22
        )
        .animation(
            .easeOut(duration: 0.12),
            value: activeHandle
        )
    }

    // MARK: Drag Gesture

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

            let normalized = min(
                max(
                    (
                        value.location.x -
                        inset
                    ) / width,
                    0
                ),
                1
            )

            let index = Int(
                (
                    normalized *
                    CGFloat(maximum)
                )
                .rounded()
            )

            switch handle {

            case .start:

                let newValue = min(
                    max(index, 0),
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

                let newValue = max(
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

    // MARK: Position

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
            ) * width
    }
}
