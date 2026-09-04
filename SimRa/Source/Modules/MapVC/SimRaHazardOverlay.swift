//
//  SimRaHazardOverlay.swift
//  SimRa
//
//  Real SimRa hazard-map data.
//
//  Street geometry:
//  /assets/maplibre/street-map.json
//
//  Safety colors:
//  /api/safety-metrics/region-map
//
//  The current SimRa frontend defines the street grid as:
//      highway: string
//      osm_id: number
//      way: string
//
//  `way` is a serialized GeoJSON LineString.
//

import Foundation
import MapKit
import UIKit

// MARK: - Public Overlay

struct SimRaHazardOverlay: Identifiable {

    let id: Int
    let polyline: MKPolyline
    let color: UIColor
}

// MARK: - Internal Street

private struct SimRaStreet {

    let id: Int

    let coordinates:
        [CLLocationCoordinate2D]

    let boundingBox:
        MKMapRect
}

// MARK: - Errors

enum SimRaHazardServiceError:
    LocalizedError
{

    case invalidResponse
    case httpStatus(Int)
    case invalidStreetMap
    case noStreetData
    case noHazardData

    var errorDescription: String? {

        switch self {

        case .invalidResponse:

            return
                "SimRa returned an invalid response."

        case .httpStatus(let status):

            return
                "SimRa returned HTTP \(status)."

        case .invalidStreetMap:

            return
                "The SimRa street map could not be decoded."

        case .noStreetData:

            return
                "No SimRa street data is available."

        case .noHazardData:

            return
                "No SimRa hazard data is available."
        }
    }
}

// MARK: - Service

final class SimRaHazardService {

    static let shared =
        SimRaHazardService()

    private let session:
        URLSession

    private let baseURL =
        URL(
            string:
                "https://simra.3s-rg.de"
        )!

    private let lock =
        NSLock()

    private var streetCache:
        [SimRaStreet]?

    private var colorCache:
        [Int: UIColor]?

    private init() {

        let configuration =
            URLSessionConfiguration.default

        configuration
            .timeoutIntervalForRequest = 30

        configuration
            .timeoutIntervalForResource = 60

        configuration
            .waitsForConnectivity = true

        session =
            URLSession(
                configuration:
                    configuration
            )
    }

    // MARK: - Public Data Loading

    func loadData() async throws {

        _ = try await loadStreets()

        _ = try await loadHazardColors()

        guard hasStreetData else {

            throw
                SimRaHazardServiceError
                    .noStreetData
        }

        guard hasHazardData else {

            throw
                SimRaHazardServiceError
                    .noHazardData
        }
    }

    // MARK: - Public Overlay Generation

    func overlays(
        for region:
            MKCoordinateRegion,
        maximumCount:
            Int = 500,
        paddingFactor:
            Double = 0.20
    )
        -> [SimRaHazardOverlay]
    {

        let streets:
            [SimRaStreet]

        let colors:
            [Int: UIColor]

        lock.lock()

        guard
            let cachedStreets =
                streetCache,
            let cachedColors =
                colorCache
        else {

            lock.unlock()

            return []
        }

        streets =
            cachedStreets

        colors =
            cachedColors

        lock.unlock()

        let visibleRect =
            makeVisibleMapRect(
                from:
                    region,
                paddingFactor:
                    paddingFactor
            )

        var candidates:
            [(street:
                SimRaStreet,
              color:
                UIColor)] = []

        candidates.reserveCapacity(
            min(
                streets.count,
                maximumCount * 2
            )
        )

        for street in streets {

            guard
                street.boundingBox
                    .intersects(
                        visibleRect
                    ),
                let color =
                    colors[
                        street.id
                    ]
            else {
                continue
            }

            candidates.append(
                (
                    street:
                        street,
                    color:
                        color
                )
            )
        }

        // Protect MapKit from extremely dense views.
        if
            candidates.count
                > maximumCount
        {

            candidates =
                Array(
                    candidates.prefix(
                        maximumCount
                    )
                )
        }

        return candidates.compactMap {

            candidate
                in

            guard
                candidate
                    .street
                    .coordinates
                    .count >= 2
            else {
                return nil
            }

            let polyline =
                MKPolyline(
                    coordinates:
                        candidate
                            .street
                            .coordinates,
                    count:
                        candidate
                            .street
                            .coordinates
                            .count
                )

            return
                SimRaHazardOverlay(
                    id:
                        candidate
                            .street
                            .id,
                    polyline:
                        polyline,
                    color:
                        candidate
                            .color
                )
        }
    }

    // MARK: - Cache

    func clearCache() {

        lock.lock()

        streetCache = nil
        colorCache = nil

        lock.unlock()
    }

    private var hasStreetData: Bool {

        lock.lock()

        defer {
            lock.unlock()
        }

        return
            !(streetCache?.isEmpty ?? true)
    }

    private var hasHazardData: Bool {

        lock.lock()

        defer {
            lock.unlock()
        }

        return
            !(colorCache?.isEmpty ?? true)
    }

    // MARK: - Streets

    private func loadStreets()
        async throws
        -> [SimRaStreet]
    {

        lock.lock()

        if
            let cached =
                streetCache
        {

            lock.unlock()

            return cached
        }

        lock.unlock()

        let url =
            baseURL
                .appendingPathComponent(
                    "assets/maplibre/street-map.json"
                )

        let (
            data,
            response
        ) =
            try await
                session.data(
                    from:
                        url
                )

        try validate(
            response:
                response
        )

        let entries:
            [StreetGridEntry]

        do {

            entries =
                try JSONDecoder()
                    .decode(
                        [
                            StreetGridEntry
                        ].self,
                        from:
                            data
                    )

        } catch {

            print(
                "SimRa street-map decode error:",
                error
            )

            throw
                SimRaHazardServiceError
                    .invalidStreetMap
        }

        var result:
            [SimRaStreet] = []

        result.reserveCapacity(
            entries.count
        )

        for entry in entries {

            guard
                let coordinates =
                    decodeWay(
                        entry.way
                    ),
                coordinates.count >= 2,
                let boundingBox =
                    makeBoundingBox(
                        coordinates
                    )
            else {
                continue
            }

            result.append(
                SimRaStreet(
                    id:
                        entry.osmId,
                    coordinates:
                        coordinates,
                    boundingBox:
                        boundingBox
                )
            )
        }

        guard !result.isEmpty else {

            throw
                SimRaHazardServiceError
                    .invalidStreetMap
        }

        lock.lock()

        streetCache =
            result

        lock.unlock()

        print(
            "SimRa: loaded \(result.count) street geometries."
        )

        return result
    }

    // MARK: - Hazard Colors

    private func loadHazardColors()
        async throws
        -> [Int: UIColor]
    {

        lock.lock()

        if
            let cached =
                colorCache
        {

            lock.unlock()

            return cached
        }

        lock.unlock()

        let url =
            baseURL
                .appendingPathComponent(
                    "api/safety-metrics/region-map"
                )

        let (
            data,
            response
        ) =
            try await
                session.data(
                    from:
                        url
                )

        try validate(
            response:
                response
        )

        let object =
            try JSONSerialization
                .jsonObject(
                    with:
                        data,
                    options:
                        []
                )

        guard
            let dictionary =
                object
                    as? [String: Any]
        else {

            print(
                "SimRa: region-map response was not a JSON object."
            )

            throw
                SimRaHazardServiceError
                    .invalidResponse
        }

        var result:
            [Int: UIColor] = [:]

        result.reserveCapacity(
            dictionary.count
        )

        for (
            key,
            value
        ) in dictionary {

            guard
                let streetID =
                    Int(key)
            else {
                continue
            }

            guard
                let colorString =
                    value as? String
            else {
                continue
            }

            guard
                let color =
                    UIColor(
                        simRaColor:
                            colorString
                    )
            else {
                continue
            }

            result[
                streetID
            ] =
                color
        }

        guard !result.isEmpty else {

            throw
                SimRaHazardServiceError
                    .noHazardData
        }

        lock.lock()

        colorCache =
            result

        lock.unlock()

        print(
            "SimRa: loaded \(result.count) hazard colors."
        )

        return result
    }

    // MARK: - Geometry Decoder

    private func decodeWay(
        _ way:
            String
    )
        -> [CLLocationCoordinate2D]?
    {

        guard
            let data =
                way.data(
                    using:
                        .utf8
                )
        else {
            return nil
        }

        // Primary/current format:
        // serialized GeoJSON LineString.
        if
            let geometry =
                try? JSONDecoder()
                    .decode(
                        GeoJSONLineString
                            .self,
                        from:
                            data
                    )
        {

            guard
                geometry.type
                    .lowercased()
                    ==
                    "linestring"
            else {
                return nil
            }

            return
                sanitize(
                    geometry.coordinates
                )
        }

        // Compatibility with historical WKT data.
        return
            decodeWKT(
                way
            )
    }

    private func sanitize(
        _ raw:
            [[Double]]
    )
        -> [CLLocationCoordinate2D]
    {

        var result:
            [CLLocationCoordinate2D] = []

        result.reserveCapacity(
            raw.count
        )

        for position in raw {

            guard
                position.count >= 2
            else {
                continue
            }

            let longitude =
                position[0]

            let latitude =
                position[1]

            guard
                longitude.isFinite,
                latitude.isFinite,
                longitude >= -180,
                longitude <= 180,
                latitude >= -90,
                latitude <= 90
            else {
                continue
            }

            let coordinate =
                CLLocationCoordinate2D(
                    latitude:
                        latitude,
                    longitude:
                        longitude
                )

            if
                let previous =
                    result.last,
                previous.latitude
                    ==
                    coordinate.latitude,
                previous.longitude
                    ==
                    coordinate.longitude
            {
                continue
            }

            result.append(
                coordinate
            )
        }

        return
            result.count >= 2
            ? result
            : []
    }

    // MARK: - WKT Compatibility

    private func decodeWKT(
        _ string:
            String
    )
        -> [CLLocationCoordinate2D]?
    {

        let value =
            string
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            value
                .uppercased()
                .hasPrefix(
                    "LINESTRING"
                )
        else {
            return nil
        }

        guard
            let opening =
                value.firstIndex(
                    of:
                        "("
                ),
            let closing =
                value.lastIndex(
                    of:
                        ")"
                )
        else {
            return nil
        }

        let body =
            value[
                value.index(
                    after:
                        opening
                )..<closing
            ]

        var result:
            [CLLocationCoordinate2D] = []

        for item in
            body.split(
                separator:
                    ","
            )
        {

            let parts =
                item.split {
                    $0 == " "
                    || $0 == "\t"
                    || $0 == "\n"
                    || $0 == "\r"
                }

            guard
                parts.count >= 2,
                let longitude =
                    Double(
                        parts[0]
                    ),
                let latitude =
                    Double(
                        parts[1]
                    ),
                longitude.isFinite,
                latitude.isFinite,
                longitude >= -180,
                longitude <= 180,
                latitude >= -90,
                latitude <= 90
            else {
                continue
            }

            result.append(
                CLLocationCoordinate2D(
                    latitude:
                        latitude,
                    longitude:
                        longitude
                )
            )
        }

        return
            result.count >= 2
            ? result
            : nil
    }

    // MARK: - Bounding Box

    private func makeBoundingBox(
        _ coordinates:
            [CLLocationCoordinate2D]
    )
        -> MKMapRect?
    {

        guard
            coordinates.count >= 2
        else {
            return nil
        }

        var rect =
            MKMapRect.null

        for coordinate in coordinates {

            let point =
                MKMapPoint(
                    coordinate
                )

            let pointRect =
                MKMapRect(
                    origin:
                        point,
                    size:
                        MKMapSize(
                            width:
                                0,
                            height:
                                0
                        )
                )

            rect =
                rect.union(
                    pointRect
                )
        }

        guard
            !rect.isNull,
            rect.width.isFinite,
            rect.height.isFinite
        else {
            return nil
        }

        return rect
    }

    // MARK: - Viewport

    private func makeVisibleMapRect(
        from region:
            MKCoordinateRegion,
        paddingFactor:
            Double
    )
        -> MKMapRect
    {

        let latitudeDelta =
            max(
                region.span.latitudeDelta,
                0.000001
            )

        let longitudeDelta =
            max(
                region.span.longitudeDelta,
                0.000001
            )

        let paddedLatitudeDelta =
            latitudeDelta
            * (1 + paddingFactor)

        let paddedLongitudeDelta =
            longitudeDelta
            * (1 + paddingFactor)

        let topLeft =
            MKMapPoint(
                CLLocationCoordinate2D(
                    latitude:
                        region.center.latitude
                        + paddedLatitudeDelta / 2,
                    longitude:
                        region.center.longitude
                        - paddedLongitudeDelta / 2
                )
            )

        let bottomRight =
            MKMapPoint(
                CLLocationCoordinate2D(
                    latitude:
                        region.center.latitude
                        - paddedLatitudeDelta / 2,
                    longitude:
                        region.center.longitude
                        + paddedLongitudeDelta / 2
                )
            )

        let minX =
            min(
                topLeft.x,
                bottomRight.x
            )

        let minY =
            min(
                topLeft.y,
                bottomRight.y
            )

        let width =
            abs(
                bottomRight.x
                -
                topLeft.x
            )

        let height =
            abs(
                bottomRight.y
                -
                topLeft.y
            )

        return
            MKMapRect(
                x:
                    minX,
                y:
                    minY,
                width:
                    width,
                height:
                    height
            )
    }

    // MARK: - HTTP

    private func validate(
        response:
            URLResponse
    ) throws {

        guard
            let http =
                response as?
                HTTPURLResponse
        else {
            throw
                SimRaHazardServiceError
                    .invalidResponse
        }

        guard
            (200...299)
                .contains(
                    http.statusCode
                )
        else {
            throw
                SimRaHazardServiceError
                    .httpStatus(
                        http.statusCode
                    )
        }
    }
}

// MARK: - DTOs

private struct StreetGridEntry:
    Decodable
{

    let highway:
        String

    let osmId:
        Int

    let way:
        String

    enum CodingKeys:
        String,
        CodingKey
    {
        case highway
        case osmId = "osm_id"
        case way
    }
}

private struct GeoJSONLineString:
    Decodable
{

    let type:
        String

    let coordinates:
        [[Double]]
}

// MARK: - Color Parsing

private extension UIColor {

    convenience init?(
        simRaColor:
            String
    ) {

        let value =
            simRaColor
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        switch value {

        case "red":

            self.init(
                red:
                    1,
                green:
                    0,
                blue:
                    0,
                alpha:
                    1
            )

        case "orange":

            self.init(
                red:
                    1,
                green:
                    0.55,
                blue:
                    0,
                alpha:
                    1
            )

        case "yellow":

            self.init(
                red:
                    1,
                green:
                    0.80,
                blue:
                    0,
                alpha:
                    1
            )

        case "green":

            self.init(
                red:
                    0.20,
                green:
                    0.75,
                blue:
                    0.35,
                alpha:
                    1
            )

        case "blue":

            self.init(
                red:
                    0.20,
                green:
                    0.45,
                blue:
                    1,
                alpha:
                    1
            )

        case "gray", "grey":

            self.init(
                red:
                    0.50,
                green:
                    0.50,
                blue:
                    0.50,
                alpha:
                    1
            )

        default:

            let hex =
                value
                    .replacingOccurrences(
                        of:
                            "#",
                        with:
                            ""
                    )
                    .replacingOccurrences(
                        of:
                            "0x",
                        with:
                            ""
                    )

            guard
                hex.count == 6
                    ||
                hex.count == 8,
                let integer =
                    UInt64(
                        hex,
                        radix:
                            16
                    )
            else {
                return nil
            }

            let red:
                UInt64

            let green:
                UInt64

            let blue:
                UInt64

            let alpha:
                UInt64

            if hex.count == 8 {

                red =
                    (integer >> 24)
                    & 0xFF

                green =
                    (integer >> 16)
                    & 0xFF

                blue =
                    (integer >> 8)
                    & 0xFF

                alpha =
                    integer
                    & 0xFF

            } else {

                red =
                    (integer >> 16)
                    & 0xFF

                green =
                    (integer >> 8)
                    & 0xFF

                blue =
                    integer
                    & 0xFF

                alpha =
                    0xFF
            }

            self.init(
                red:
                    CGFloat(red) / 255,
                green:
                    CGFloat(green) / 255,
                blue:
                    CGFloat(blue) / 255,
                alpha:
                    CGFloat(alpha) / 255
            )
        }
    }
}
