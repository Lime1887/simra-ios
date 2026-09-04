//
//  SimRaRecordingWidget.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import WidgetKit
import CoreLocation

// MARK: - Configuration

private enum SimRaWidgetConfiguration {

    static let appGroupIdentifier =
        "group.de.tu-berlin.mcc.simra"

    static let recordingKey =
        "isRecording"

    static let startDateKey =
        "startDate"

    static let distanceKey =
        "distanceMeters"

    static let incidentsKey =
        "incidents"

    static let routeCoordinatesKey =
        "widgetRouteCoordinates"

    static let tripStatisticsKey =
        "widgetTripStatistics"

    static let startURL =
        URL(
            string: "simra://recording/start"
        )

    static let stopURL =
        URL(
            string: "simra://recording/stop"
        )
}

// MARK: - Timeline Entry

struct SimRaRecordingEntry: TimelineEntry {

    let date: Date

    let routeCoordinatesData: Data?

    let recording: Bool

    let distanceMeters: Double

    let recordingStartDate: Date?

    let incidentsCount: Int

    let weeklyKilometers: [Double]

    let weeklyRideCounts: [Int]

    init(
        date: Date = .now,
        routeCoordinatesData: Data? = nil,
        recording: Bool = false,
        distanceMeters: Double = 0,
        recordingStartDate: Date? = nil,
        incidentsCount: Int = 0,
        weeklyKilometers: [Double] = [
            0,
            0,
            0,
            0
        ],
        weeklyRideCounts: [Int] = [
            0,
            0,
            0,
            0
        ]
    ) {
        self.date = date
        self.routeCoordinatesData =
            routeCoordinatesData
        self.recording = recording
        self.distanceMeters =
            max(
                distanceMeters,
                0
            )
        self.recordingStartDate =
            recordingStartDate
        self.incidentsCount =
            max(
                incidentsCount,
                0
            )
        self.weeklyKilometers =
            weeklyKilometers
        self.weeklyRideCounts =
            weeklyRideCounts
    }
}

// MARK: - Coordinate

struct SimRaWidgetCoordinate: Codable, Equatable {

    let latitude: Double
    let longitude: Double

    var location:
        CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - Stored Statistic

private struct SimRaStoredTripStatistic:
    Codable {

    let date: Date
    let distanceMeters: Double
}

// MARK: - Timeline Provider

struct SimRaRecordingProvider:
    TimelineProvider {

    // MARK: Placeholder

    func placeholder(
        in context: Context
    ) -> SimRaRecordingEntry {

        SimRaRecordingEntry(
            recording: true,
            distanceMeters: 6_800,
            recordingStartDate:
                Date(
                    timeIntervalSinceNow:
                        -642
                ),
            incidentsCount: 2,
            weeklyKilometers: [
                7.4,
                15.8,
                11.2,
                21.6
            ],
            weeklyRideCounts: [
                2,
                4,
                3,
                5
            ]
        )
    }

    // MARK: Snapshot

    func getSnapshot(
        in context: Context,
        completion:
            @escaping (
                SimRaRecordingEntry
            ) -> Void
    ) {

        completion(
            currentEntry()
        )
    }

    // MARK: Timeline

    func getTimeline(
        in context: Context,
        completion:
            @escaping (
                Timeline<SimRaRecordingEntry>
            ) -> Void
    ) {

        let entry =
            currentEntry()

        let refreshInterval:
            TimeInterval

        if entry.recording {
            refreshInterval =
                60
        } else {
            refreshInterval =
                15 * 60
        }

        let nextRefresh =
            Date.now.addingTimeInterval(
                refreshInterval
            )

        completion(
            Timeline(
                entries: [
                    entry
                ],
                policy:
                    .after(
                        nextRefresh
                    )
            )
        )
    }

    // MARK: Current Entry

    private func currentEntry()
        -> SimRaRecordingEntry {

        guard
            let defaults =
                UserDefaults(
                    suiteName:
                        SimRaWidgetConfiguration
                            .appGroupIdentifier
                )
        else {
            return SimRaRecordingEntry()
        }

        let recording =
            defaults.bool(
                forKey:
                    SimRaWidgetConfiguration
                        .recordingKey
            )

        let startTimestamp =
            defaults.double(
                forKey:
                    SimRaWidgetConfiguration
                        .startDateKey
            )

        let startDate:
            Date?

        if startTimestamp > 0 {
            startDate =
                Date(
                    timeIntervalSince1970:
                        startTimestamp
                )
        } else {
            startDate = nil
        }

        let distance =
            max(
                defaults.double(
                    forKey:
                        SimRaWidgetConfiguration
                            .distanceKey
                ),
                0
            )

        let incidents =
            max(
                defaults.integer(
                    forKey:
                        SimRaWidgetConfiguration
                            .incidentsKey
                ),
                0
            )

        let routeData =
            defaults.data(
                forKey:
                    SimRaWidgetConfiguration
                        .routeCoordinatesKey
            )

        let statisticsData =
            defaults.data(
                forKey:
                    SimRaWidgetConfiguration
                        .tripStatisticsKey
            )

        let statistics =
            readStatistics(
                from:
                    statisticsData
            )

        let weekly =
            calculateWeeklyStatistics(
                statistics
            )

        return SimRaRecordingEntry(
            date: .now,
            routeCoordinatesData:
                routeData,
            recording:
                recording,
            distanceMeters:
                distance,
            recordingStartDate:
                recording
                    ? startDate
                    : nil,
            incidentsCount:
                incidents,
            weeklyKilometers:
                weekly.kilometers,
            weeklyRideCounts:
                weekly.rides
        )
    }

    // MARK: Coordinates

    private func decodeCoordinates(
        from data: Data?
    ) -> [
        CLLocationCoordinate2D
    ] {

        guard
            let data,
            let values =
                try? JSONDecoder().decode(
                    [
                        SimRaWidgetCoordinate
                    ].self,
                    from:
                        data
                )
        else {
            return []
        }

        return values
            .map(\.location)
            .filter {
                CLLocationCoordinate2DIsValid(
                    $0
                )
            }
    }

    // MARK: Statistics

    private func readStatistics(
        from data: Data?
    ) -> [
        SimRaStoredTripStatistic
    ] {

        guard
            let data,
            let values =
                try? JSONDecoder().decode(
                    [
                        SimRaStoredTripStatistic
                    ].self,
                    from:
                        data
                )
        else {
            return []
        }

        return values
    }

    private func calculateWeeklyStatistics(
        _ statistics:
            [SimRaStoredTripStatistic]
    ) -> (
        kilometers: [Double],
        rides: [Int]
    ) {

        let calendar =
            Calendar.current

        guard
            let currentWeek =
                calendar.dateInterval(
                    of: .weekOfYear,
                    for: .now
                )
        else {
            return (
                [
                    0,
                    0,
                    0,
                    0
                ],
                [
                    0,
                    0,
                    0,
                    0
                ]
            )
        }

        var kilometers =
            [
                0.0,
                0.0,
                0.0,
                0.0
            ]

        var rides =
            [
                0,
                0,
                0,
                0
            ]

        for statistic in statistics {

            guard
                let weekDifference =
                    calendar.dateComponents(
                        [.weekOfYear],
                        from:
                            currentWeek.start,
                        to:
                            statistic.date
                    ).weekOfYear
            else {
                continue
            }

            guard
                (-3...0).contains(
                    weekDifference
                )
            else {
                continue
            }

            let index =
                weekDifference + 3

            guard
                (0..<4).contains(
                    index
                )
            else {
                continue
            }

            kilometers[index] +=
                max(
                    statistic.distanceMeters,
                    0
                ) / 1_000

            rides[index] += 1
        }

        return (
            kilometers,
            rides
        )
    }
}

// MARK: - Widget

struct SimRaRecordingWidget:
    Widget {

    static let kind =
        "SimRaRecordingWidget"

    var body:
        some WidgetConfiguration {

        StaticConfiguration(
            kind:
                Self.kind,
            provider:
                SimRaRecordingProvider()
        ) { entry in

            SimRaRecordingWidgetView(
                entry:
                    entry
            )
        }
        .configurationDisplayName(
            "SimRa"
        )
        .description(
            "Aufnahme und Fahrtenstatistik."
        )
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Root View

private struct SimRaRecordingWidgetView: View {

    let entry: SimRaRecordingEntry

    @Environment(\.widgetFamily)
    private var family

    var body: some View {
        Group {
            if entry.recording {
                RecordingWidgetView(
                    entry: entry,
                    family: family
                )
            } else {
                StatisticsWidgetView(
                    entry: entry,
                    family: family
                )
            }
        }
        .containerBackground(
            for: .widget
        ) {
            if entry.recording {
                Color.black
            } else {
                Color(.systemBackground)
            }
        }
    }
}

// MARK: - Recording Widget

private struct RecordingWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    var body: some View {

        switch family {

        case .systemSmall:

            SmallRecordingView(
                entry:
                    entry
            )

        case .systemMedium:

            MediumRecordingView(
                entry:
                    entry
            )

        case .systemLarge:

            LargeRecordingView(
                entry:
                    entry,
                family:
                    family
            )

        case .systemExtraLarge:

            LargeRecordingView(
                entry:
                    entry,
                family:
                    family
            )

        @unknown default:

            MediumRecordingView(
                entry:
                    entry
            )
        }
    }
}

// MARK: - Small Recording

private struct SmallRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack(
            alignment:
                .bottom
        ) {

            RecordingRouteView(
                routeData:
                    entry.routeCoordinatesData
            )

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(
                        0.86
                    )
                ],
                startPoint:
                    .center,
                endPoint:
                    .bottom
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    0
            ) {

                SmallRecordingHeader()

                Spacer(
                    minLength:
                        6
                )

                HStack(
                    alignment:
                        .bottom,
                    spacing:
                        8
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            2
                    ) {

                        RecordingDuration(
                            startDate:
                                entry.recordingStartDate,
                            currentDate:
                                entry.date,
                            fontSize:
                                24
                        )

                        Text(
                            formatDistance(
                                entry.distanceMeters
                            )
                        )
                        .font(
                            .caption.weight(
                                .semibold
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(
                            .white
                        )
                        .lineLimit(
                            1
                        )
                    }

                    Spacer(
                        minLength:
                            0
                    )

                    StopButton(
                        size:
                            42
                    )
                }
            }
            .padding(
                11
            )
        }
        .clipped()
    }
}

// MARK: - Medium Recording

private struct MediumRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack(
            alignment:
                .bottom
        ) {

            RecordingRouteView(
                routeData:
                    entry.routeCoordinatesData
            )

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(
                        0.88
                    )
                ],
                startPoint:
                    .center,
                endPoint:
                    .bottom
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    8
            ) {

                RecordingHeader()

                Spacer(
                    minLength:
                        0
                )

                HStack(
                    alignment:
                        .bottom,
                    spacing:
                        12
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            3
                    ) {

                        RecordingDuration(
                            startDate:
                                entry.recordingStartDate,
                            currentDate:
                                entry.date,
                            fontSize:
                                32
                        )

                        HStack(
                            spacing:
                                8
                        ) {

                            Text(
                                formatDistance(
                                    entry.distanceMeters
                                )
                            )
                            .font(
                                .subheadline.weight(
                                    .semibold
                                )
                            )
                            .monospacedDigit()

                            if entry.incidentsCount > 0 {

                                IncidentIndicator(
                                    count:
                                        entry.incidentsCount
                                )
                            }
                        }
                        .foregroundStyle(
                            .white
                        )
                    }

                    Spacer(
                        minLength:
                            0
                    )

                    StopButton(
                        size:
                            50
                    )
                }
            }
            .padding(
                14
            )
        }
        .clipped()
    }
}

// MARK: - Large Recording

private struct LargeRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    var body: some View {

        ZStack(
            alignment:
                .bottom
        ) {

            RecordingRouteView(
                routeData:
                    entry.routeCoordinatesData
            )

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(
                        0.90
                    )
                ],
                startPoint:
                    .top,
                endPoint:
                    .bottom
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                RecordingHeader()

                Spacer(
                    minLength:
                        0
                )

                Text(
                    "AKTIVE AUFNAHME"
                )
                .font(
                    .caption.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .white.opacity(
                        0.75
                    )
                )

                RecordingDuration(
                    startDate:
                        entry.recordingStartDate,
                    currentDate:
                        entry.date,
                    fontSize:
                        family ==
                        .systemExtraLarge
                        ? 48
                        : 41
                )

                HStack(
                    spacing:
                        8
                ) {

                    RecordingMetric(
                        title:
                            "Strecke",
                        value:
                            formatDistance(
                                entry.distanceMeters
                            ),
                        icon:
                            "bicycle"
                    )

                    if entry.incidentsCount > 0 {

                        RecordingMetric(
                            title:
                                "Meldungen",
                            value:
                                String(
                                    entry.incidentsCount
                                ),
                            icon:
                                "exclamationmark.triangle.fill"
                        )
                    }
                }

                HStack {

                    Spacer(
                        minLength:
                            0
                    )

                    StopButton(
                        size:
                            56
                    )
                }
            }
            .padding(
                family ==
                    .systemExtraLarge
                ? 20
                : 16
            )
        }
        .clipped()
    }
}

// MARK: - Real Route

private struct RecordingRouteView:
    View {

    let routeData:
        Data?

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                Color(
                    white:
                        0.06
                )

                if let coordinates =
                    decodedCoordinates,
                   coordinates.count >= 2 {

                    RouteDrawingView(
                        coordinates:
                            coordinates,
                        size:
                            geometry.size
                    )

                } else if decodedCoordinates?.count == 1 {

                    Circle()
                        .fill(
                            Color.blue
                        )
                        .frame(
                            width:
                                12,
                            height:
                                12
                        )

                } else {

                    Image(
                        systemName:
                            "bicycle"
                    )
                    .font(
                        .system(
                            size:
                                30,
                            weight:
                                .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(
                            0.20
                        )
                    )
                }
            }
            .frame(
                width:
                    geometry.size.width,
                height:
                    geometry.size.height
            )
        }
        .clipped()
        .allowsHitTesting(
            false
        )
    }

    private var decodedCoordinates:
        [CLLocationCoordinate2D]? {

        guard
            let routeData,
            let values =
                try? JSONDecoder().decode(
                    [
                        SimRaWidgetCoordinate
                    ].self,
                    from:
                        routeData
                )
        else {
            return nil
        }

        let coordinates =
            values
                .map(\.location)
                .filter {
                    CLLocationCoordinate2DIsValid(
                        $0
                    )
                }

        return coordinates.isEmpty
            ? nil
            : coordinates
    }
}

// MARK: - Route Drawing

private struct RouteDrawingView:
    View {

    let coordinates:
        [CLLocationCoordinate2D]

    let size:
        CGSize

    var body: some View {

        let layout =
            RouteLayout(
                coordinates:
                    coordinates,
                size:
                    size
            )

        ZStack {

            if layout.points.count >= 2 {

                Path { path in

                    guard
                        let first =
                            layout.points.first
                    else {
                        return
                    }

                    path.move(
                        to:
                            first
                    )

                    for point
                        in layout.points.dropFirst()
                    {
                        path.addLine(
                            to:
                                point
                        )
                    }
                }
                .stroke(
                    Color.blue,
                    style:
                        StrokeStyle(
                            lineWidth:
                                layout.lineWidth,
                            lineCap:
                                .round,
                            lineJoin:
                                .round
                        )
                )

                if let last =
                    layout.points.last {

                    Circle()
                        .fill(
                            Color.red
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    Color.white,
                                    lineWidth:
                                        2
                                )
                        }
                        .frame(
                            width:
                                12,
                            height:
                                12
                        )
                        .position(
                            last
                        )
                }
            }
        }
    }
}

// MARK: - Route Layout

private struct RouteLayout {

    let points:
        [CGPoint]

    let lineWidth:
        CGFloat

    init(
        coordinates:
            [CLLocationCoordinate2D],
        size:
            CGSize
    ) {

        guard
            !coordinates.isEmpty
        else {

            self.points = []
            self.lineWidth = 4
            return
        }

        let latitudes =
            coordinates.map(
                \.latitude
            )

        let longitudes =
            coordinates.map(
                \.longitude
            )

        guard
            let minimumLatitude =
                latitudes.min(),
            let maximumLatitude =
                latitudes.max(),
            let minimumLongitude =
                longitudes.min(),
            let maximumLongitude =
                longitudes.max()
        else {

            self.points = []
            self.lineWidth = 4
            return
        }

        let latitudeSpan =
            max(
                maximumLatitude -
                    minimumLatitude,
                0.00001
            )

        let centerLatitude =
            (
                minimumLatitude +
                maximumLatitude
            ) / 2

        let longitudeScale =
            max(
                cos(
                    centerLatitude *
                    Double.pi /
                    180
                ),
                0.1
            )

        let longitudeSpan =
            max(
                (
                    maximumLongitude -
                    minimumLongitude
                ) *
                longitudeScale,
                0.00001
            )

        let padding =
            min(
                max(
                    min(
                        size.width,
                        size.height
                    ) * 0.10,
                    18
                ),
                32
            )

        let drawingWidth =
            max(
                size.width -
                    padding * 2,
                1
            )

        let drawingHeight =
            max(
                size.height -
                    padding * 2,
                1
            )

        let scale =
            min(
                drawingWidth /
                    longitudeSpan,
                drawingHeight /
                    latitudeSpan
            )

        let usedWidth =
            longitudeSpan *
            scale

        let usedHeight =
            latitudeSpan *
            scale

        let originX =
            (
                size.width -
                usedWidth
            ) / 2

        let originY =
            (
                size.height -
                usedHeight
            ) / 2

        self.points =
            coordinates.map {
                coordinate in

                let normalizedLongitude =
                    (
                        (
                            coordinate.longitude -
                            minimumLongitude
                        ) *
                        longitudeScale
                    ) /
                    longitudeSpan

                let normalizedLatitude =
                    (
                        maximumLatitude -
                        coordinate.latitude
                    ) /
                    latitudeSpan

                return CGPoint(
                    x:
                        originX +
                        CGFloat(
                            normalizedLongitude
                        ) *
                        usedWidth,
                    y:
                        originY +
                        CGFloat(
                            normalizedLatitude
                        ) *
                        usedHeight
                )
            }

        let minimumDimension =
            min(
                size.width,
                size.height
            )

        self.lineWidth =
            min(
                max(
                    minimumDimension *
                        0.024,
                    3.5
                ),
                6
            )
    }
}

// MARK: - Recording Duration

private struct RecordingDuration:
    View {

    let startDate:
        Date?

    let currentDate:
        Date

    let fontSize:
        CGFloat

    var body: some View {

        Text(
            durationText
        )
        .font(
            .system(
                size:
                    fontSize,
                weight:
                    .bold,
                design:
                    .rounded
            )
        )
        .monospacedDigit()
        .foregroundStyle(
            Color.white
        )
        .lineLimit(
            1
        )
        .minimumScaleFactor(
            0.65
        )
        .contentTransition(
            .numericText()
        )
    }

    private var durationText:
        String {

        guard
            let startDate
        else {
            return "00:00"
        }

        let elapsed =
            max(
                currentDate.timeIntervalSince(
                    startDate
                ),
                0
            )

        let totalSeconds =
            Int(
                elapsed
            )

        let hours =
            totalSeconds / 3_600

        let minutes =
            (
                totalSeconds % 3_600
            ) / 60

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

        } else {

            return String(
                format:
                    "%02d:%02d",
                minutes,
                seconds
            )
        }
    }
}

// MARK: - Recording Header

private struct RecordingHeader:
    View {

    var body: some View {

        HStack(
            spacing:
                7
        ) {

            Image(
                systemName:
                    "bicycle"
            )
            .font(
                .system(
                    size:
                        14,
                    weight:
                        .bold
                )
            )

            Text(
                "SimRa"
            )
            .font(
                .headline.weight(
                    .bold
                )
            )

            Spacer(
                minLength:
                    8
            )

            Circle()
                .fill(
                    Color.red
                )
                .frame(
                    width:
                        7,
                    height:
                        7
                )

            Text(
                "Aufnahme"
            )
            .font(
                .caption2.weight(
                    .semibold
                )
            )
        }
        .foregroundStyle(
            Color.white
        )
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            7
        )
        .background(
            Color.black.opacity(
                0.30
            ),
            in:
                Capsule()
        )
    }
}

// MARK: - Small Header

private struct SmallRecordingHeader:
    View {

    var body: some View {

        HStack(
            spacing:
                6
        ) {

            Image(
                systemName:
                    "bicycle"
            )
            .font(
                .caption.weight(
                    .bold
                )
            )

            Text(
                "SimRa"
            )
            .font(
                .caption.weight(
                    .bold
                )
            )

            Spacer(
                minLength:
                    4
            )

            Circle()
                .fill(
                    Color.red
                )
                .frame(
                    width:
                        6,
                    height:
                        6
                )
        }
        .foregroundStyle(
            Color.white
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            6
        )
        .background(
            Color.black.opacity(
                0.30
            ),
            in:
                Capsule()
        )
    }
}

// MARK: - Stop Button

private struct StopButton:
    View {

    let size:
        CGFloat

    var body: some View {

        if let url =
            SimRaWidgetConfiguration
                .stopURL {

            Link(
                destination:
                    url
            ) {

                buttonContent
            }
            .buttonStyle(
                .plain
            )

        } else {

            buttonContent
        }
    }

    private var buttonContent:
        some View {

        ZStack {

            Circle()
                .fill(
                    .ultraThinMaterial
                )

            Circle()
                .stroke(
                    Color.white.opacity(
                        0.42
                    ),
                    lineWidth:
                        1
                )

            Image(
                systemName:
                    "stop.fill"
            )
            .font(
                .system(
                    size:
                        size * 0.29,
                    weight:
                        .bold
                )
            )
            .foregroundStyle(
                Color.red
            )
        }
        .frame(
            width:
                size,
            height:
                size
        )
        .accessibilityLabel(
            "Aufnahme stoppen"
        )
    }
}

// MARK: - Recording Metric

private struct RecordingMetric:
    View {

    let title:
        String

    let value:
        String

    let icon:
        String

    var body: some View {

        HStack(
            spacing:
                7
        ) {

            Image(
                systemName:
                    icon
            )
            .font(
                .caption.weight(
                    .semibold
                )
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    0
            ) {

                Text(
                    title
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    Color.white.opacity(
                        0.65
                    )
                )

                Text(
                    value
                )
                .font(
                    .subheadline.weight(
                        .bold
                    )
                )
                .monospacedDigit()
            }
        }
        .foregroundStyle(
            Color.white
        )
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            7
        )
        .background(
            Color.black.opacity(
                0.26
            ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        11,
                    style:
                        .continuous
                )
        )
    }
}

// MARK: - Incident Indicator

private struct IncidentIndicator:
    View {

    let count:
        Int

    var body: some View {

        HStack(
            spacing:
                4
        ) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )

            Text(
                String(
                    count
                )
            )
        }
        .font(
            .caption.weight(
                .semibold
            )
        )
        .foregroundStyle(
            Color.orange
        )
    }
}

// MARK: - Statistics Widget

private struct StatisticsWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    var body: some View {

        switch family {

        case .systemSmall:

            SmallStatisticsView(
                entry:
                    entry
            )

        case .systemMedium:

            MediumStatisticsView(
                entry:
                    entry
            )

        case .systemLarge,
             .systemExtraLarge:

            LargeStatisticsView(
                entry:
                    entry,
                family:
                    family
            )

        @unknown default:

            MediumStatisticsView(
                entry:
                    entry
            )
        }
    }
}

// MARK: - Small Statistics

private struct SmallStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {

            StatisticsHeader(
                compact:
                    true
            )

            Spacer(
                minLength:
                    8
            )

            HStack(
                alignment:
                    .firstTextBaseline,
                spacing:
                    4
            ) {

                Text(
                    String(
                        format:
                            "%.1f",
                        totalKilometers
                    )
                )
                .font(
                    .system(
                        size:
                            30,
                        weight:
                            .bold,
                        design:
                            .rounded
                    )
                )
                .monospacedDigit()
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.70
                )

                Text(
                    "km"
                )
                .font(
                    .caption.weight(
                        .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                "in 4 Wochen"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )

            Spacer(
                minLength:
                    7
            )

            MiniWeeklyBars(
                values:
                    entry.weeklyKilometers
            )

            Spacer(
                minLength:
                    7
            )

            StartRecordingButton(
                compact:
                    true
            )
        }
        .padding(
            12
        )
    }

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }
}

// MARK: - Medium Statistics

private struct MediumStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            StatisticsHeader(
                compact:
                    false
            )

            HStack(
                alignment:
                    .bottom,
                spacing:
                    16
            ) {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {

                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing:
                            4
                    ) {

                        Text(
                            String(
                                format:
                                    "%.1f",
                                totalKilometers
                            )
                        )
                        .font(
                            .system(
                                size:
                                    36,
                                weight:
                                    .bold,
                                design:
                                    .rounded
                            )
                        )
                        .monospacedDigit()
                        .lineLimit(
                            1
                        )

                        Text(
                            "km"
                        )
                        .font(
                            .subheadline.weight(
                                .medium
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Text(
                        String(
                            format:
                                "%d Fahrten",
                            totalRides
                        )
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer(
                    minLength:
                        0
                )

                MiniWeeklyBars(
                    values:
                        entry.weeklyKilometers
                )
                .frame(
                    width:
                        145
                )
            }

            Spacer(
                minLength:
                    0
            )

            StartRecordingButton(
                compact:
                    false
            )
        }
        .padding(
            14
        )
    }

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    private var totalRides:
        Int {

        entry.weeklyRideCounts.reduce(
            0,
            +
        )
    }
}

// MARK: - Large Statistics

private struct LargeStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    var body: some View {

        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            StatisticsHeader(
                compact:
                    false
            )

            HStack(
                spacing:
                    family ==
                    .systemExtraLarge
                    ? 18
                    : 12
            ) {

                StatisticBlock(
                    title:
                        "Kilometer",
                    value:
                        String(
                            format:
                                "%.1f",
                            totalKilometers
                        ),
                    unit:
                        "km",
                    icon:
                        "bicycle"
                )

                StatisticBlock(
                    title:
                        "Fahrten",
                    value:
                        String(
                            totalRides
                        ),
                    unit:
                        nil,
                    icon:
                        "arrow.triangle.2.circlepath"
                )
            }

            WeeklyBars(
                values:
                    entry.weeklyKilometers,
                compact:
                    family ==
                    .systemLarge
            )

            Spacer(
                minLength:
                    0
            )

            StartRecordingButton(
                compact:
                    false
            )
        }
        .padding(
            family ==
                .systemExtraLarge
            ? 20
            : 16
        )
    }

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    private var totalRides:
        Int {

        entry.weeklyRideCounts.reduce(
            0,
            +
        )
    }
}

// MARK: - Statistics Header

private struct StatisticsHeader:
    View {

    let compact:
        Bool

    var body: some View {

        HStack(
            spacing:
                7
        ) {

            Image(
                systemName:
                    "bicycle"
            )
            .font(
                .system(
                    size:
                        compact
                        ? 12
                        : 14,
                    weight:
                        .semibold
                )
            )

            Text(
                "SimRa"
            )
            .font(
                compact
                ? .caption.weight(
                    .bold
                )
                : .headline.weight(
                    .semibold
                )
            )

            Spacer(
                minLength:
                    4
            )

            if !compact {

                Text(
                    "4 Wochen"
                )
                .font(
                    .caption2.weight(
                        .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }
}

// MARK: - Statistic Block

private struct StatisticBlock:
    View {

    let title:
        String

    let value:
        String

    let unit:
        String?

    let icon:
        String

    var body: some View {

        HStack(
            spacing:
                9
        ) {

            Image(
                systemName:
                    icon
            )
            .font(
                .title3.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .green
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    1
            ) {

                Text(
                    title
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

                HStack(
                    alignment:
                        .firstTextBaseline,
                    spacing:
                        3
                ) {

                    Text(
                        value
                    )
                    .font(
                        .system(
                            size:
                                28,
                            weight:
                                .bold,
                            design:
                                .rounded
                        )
                    )
                    .monospacedDigit()

                    if let unit {

                        Text(
                            unit
                        )
                        .font(
                            .caption.weight(
                                .medium
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Weekly Bars

private struct WeeklyBars:
    View {

    let values:
        [Double]

    let compact:
        Bool

    var body: some View {

        GeometryReader { geometry in

            let safeValues =
                normalizedValues

            let maximum =
                max(
                    safeValues.max() ?? 0,
                    1
                )

            HStack(
                alignment:
                    .bottom,
                spacing:
                    compact
                    ? 8
                    : 12
            ) {

                ForEach(
                    safeValues.indices,
                    id:
                        \.self
                ) { index in

                    VStack(
                        spacing:
                            5
                    ) {

                        Spacer(
                            minLength:
                                0
                        )

                        RoundedRectangle(
                            cornerRadius:
                                5,
                            style:
                                .continuous
                        )
                        .fill(
                            Color.green.opacity(
                                index ==
                                safeValues.count - 1
                                ? 0.95
                                : 0.42
                            )
                        )
                        .frame(
                            height:
                                max(
                                    6,
                                    geometry.size.height *
                                    0.68 *
                                    CGFloat(
                                        safeValues[index] /
                                        maximum
                                    )
                                )
                        )

                        Text(
                            weekLabel(
                                index
                            )
                        )
                        .font(
                            .system(
                                size:
                                    compact
                                    ? 8
                                    : 9,
                                weight:
                                    .medium
                            )
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
            }
        }
        .frame(
            height:
                compact
                ? 72
                : 92
        )
    }

    private var normalizedValues:
        [Double] {

        let suffix =
            Array(
                values.suffix(4)
            )

        let missing =
            max(
                0,
                4 - suffix.count
            )

        return Array(
            repeating:
                0,
            count:
                missing
        ) + suffix
    }

    private func weekLabel(
        _ index:
            Int
    ) -> String {

        let calendar =
            Calendar.current

        guard
            let currentWeek =
                calendar.dateInterval(
                    of: .weekOfYear,
                    for: .now
                ),
            let date =
                calendar.date(
                    byAdding:
                        .weekOfYear,
                    value:
                        index - 3,
                    to:
                        currentWeek.start
                )
        else {
            return "-"
        }

        let week =
            calendar.component(
                .weekOfYear,
                from:
                    date
            )

        return String(
            format:
                "KW %d",
            week
        )
    }
}

// MARK: - Mini Weekly Bars

private struct MiniWeeklyBars:
    View {

    let values:
        [Double]

    var body: some View {

        GeometryReader { geometry in

            let safeValues =
                normalizedValues

            let maximum =
                max(
                    safeValues.max() ?? 0,
                    1
                )

            HStack(
                alignment:
                    .bottom,
                spacing:
                    6
            ) {

                ForEach(
                    safeValues.indices,
                    id:
                        \.self
                ) { index in

                    RoundedRectangle(
                        cornerRadius:
                            3,
                        style:
                            .continuous
                    )
                    .fill(
                        Color.green.opacity(
                            index == 3
                            ? 0.95
                            : 0.40
                        )
                    )
                    .frame(
                        height:
                            max(
                                4,
                                geometry.size.height *
                                CGFloat(
                                    safeValues[index] /
                                    maximum
                                )
                            )
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .bottom
                    )
                }
            }
        }
        .frame(
            height:
                42
        )
    }

    private var normalizedValues:
        [Double] {

        let suffix =
            Array(
                values.suffix(4)
            )

        let missing =
            max(
                0,
                4 - suffix.count
            )

        return Array(
            repeating:
                0,
            count:
                missing
        ) + suffix
    }
}

// MARK: - Start Recording Button

private struct StartRecordingButton:
    View {

    let compact:
        Bool

    var body: some View {

        if let url =
            SimRaWidgetConfiguration
                .startURL {

            Link(
                destination:
                    url
            ) {

                content
            }
            .buttonStyle(
                .plain
            )

        } else {

            content
        }
    }

    private var content:
        some View {

        HStack(
            spacing:
                7
        ) {

            Image(
                systemName:
                    "record.circle.fill"
            )
            .font(
                .system(
                    size:
                        compact
                        ? 13
                        : 14,
                    weight:
                        .bold
                )
            )

            Text(
                "Aufnahme starten"
            )
            .font(
                compact
                ? .caption.weight(
                    .semibold
                )
                : .subheadline.weight(
                    .semibold
                )
            )
            .lineLimit(
                1
            )
            .minimumScaleFactor(
                0.8
            )
        }
        .foregroundStyle(
            .green
        )
        .frame(
            maxWidth:
                .infinity
        )
        .frame(
            minHeight:
                compact
                ? 30
                : 34
        )
        .background(
            Color.green.opacity(
                0.11
            ),
            in:
                Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    Color.green.opacity(
                        0.18
                    ),
                    lineWidth:
                        1
                )
        }
    }
}

// MARK: - Widget Background

private extension View {

    @ViewBuilder
    func simRaWidgetBackground()
        -> some View {

        if #available(
            iOS 17.0,
            *
        ) {

            self.containerBackground(
                for:
                    .widget
            ) {
                Color.clear
            }

        } else {

            self.background(
                Color.clear
            )
        }
    }
}

// MARK: - Distance Formatting

private func formatDistance(
    _ meters:
        Double
) -> String {

    let safeMeters =
        max(
            meters,
            0
        )

    if safeMeters < 1_000 {

        return String(
            format:
                "%.0f m",
            safeMeters
        )
    }

    let kilometers =
        safeMeters / 1_000

    if kilometers < 10 {

        return String(
            format:
                "%.1f km",
            kilometers
        )
    }

    return String(
        format:
            "%.0f km",
            kilometers
    )
}
