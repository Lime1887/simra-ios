//
//  SimRaHazardService.swift
//  SimRa
//
//  Loads the real SimRa street safety map from the
//  current Result Viewer infrastructure.
//

import Foundation
import MapKit
import UIKit

// MARK: - Public Models

struct SimRaHazardOverlay: Identifiable {
    let id: Int
    let polyline: MKPolyline
    let color: UIColor
}

enum SimRaHazardServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case invalidStreetMap
    case noStreetData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "SimRa returned an invalid response."
        case .httpStatus(let status):
            return "SimRa returned HTTP \(status)."
        case .invalidStreetMap:
            return "The SimRa street map could not be decoded."
        case .noStreetData:
            return "No SimRa street geometry is available."
        }
    }
}

// MARK: - Service

final class SimRaHazardService {

    static let shared = SimRaHazardService()

    private let session: URLSession

    private let baseURL = URL(string: "https://simra.3s-rg.de")!

    private var streetGridCache: [Int: [CLLocationCoordinate2D]]?
    private var colorCache: [Int: UIColor]?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true

        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Loads the complete SimRa street danger overlay.
    ///
    /// The current SimRa Result Viewer uses:
    /// - /assets/maplibre/street-map.json
    /// - /api/safety-metrics/region-map
    ///
    /// The safety endpoint returns a mapping of street IDs to colors.
    func loadHazardOverlay() async throws -> [SimRaHazardOverlay] {

        async let streetGrid = loadStreetGrid()
        async let streetColors = loadRegionColors()

        let (grid, colors) = try await (streetGrid, streetColors)

        guard !grid.isEmpty else {
            throw SimRaHazardServiceError.noStreetData
        }

        var overlays: [SimRaHazardOverlay] = []
        overlays.reserveCapacity(colors.count)

        for (streetID, color) in colors {
            guard let coordinates = grid[streetID],
                  coordinates.count >= 2 else {
                continue
            }

            let polyline = MKPolyline(
                coordinates: coordinates,
                count: coordinates.count
            )

            overlays.append(
                SimRaHazardOverlay(
                    id: streetID,
                    polyline: polyline,
                    color: color
                )
            )
        }

        guard !overlays.isEmpty else {
            throw SimRaHazardServiceError.noStreetData
        }

        return overlays
    }

    /// Clears in-memory cached SimRa data.
    func clearCache() {
        streetGridCache = nil
        colorCache = nil
    }

    // MARK: - Street Geometry

    private func loadStreetGrid() async throws -> [Int: [CLLocationCoordinate2D]] {

        if let cached = streetGridCache {
            return cached
        }

        let url = baseURL.appendingPathComponent(
            "assets/maplibre/street-map.json"
        )

        let (data, response) = try await session.data(from: url)

        try validate(response: response)

        let decoder = JSONDecoder()

        guard let root = try? decoder.decode(
            StreetMapRoot.self,
            from: data
        ) else {
            // The file format has changed between versions of the
            // dashboard, therefore try a second, permissive parser.
            let grid = try parseStreetGridPermissively(data)
            streetGridCache = grid
            return grid
        }

        let grid = root.asCoordinateMap()

        guard !grid.isEmpty else {
            throw SimRaHazardServiceError.invalidStreetMap
        }

        streetGridCache = grid
        return grid
    }

    // MARK: - Safety Colors

    private func loadRegionColors() async throws -> [Int: UIColor] {

        if let cached = colorCache {
            return cached
        }

        let url = baseURL.appendingPathComponent(
            "api/safety-metrics/region-map"
        )

        let (data, response) = try await session.data(from: url)

        try validate(response: response)

        // The current frontend requests:
        //
        //   Map<number, string>
        //
        // from /api/safety-metrics/region-map.
        //
        // JSON objects arrive in Swift as [String: String].
        let raw = try JSONSerialization.jsonObject(
            with: data,
            options: []
        )

        guard let dictionary = raw as? [String: Any] else {
            throw SimRaHazardServiceError.invalidResponse
        }

        var result: [Int: UIColor] = [:]
        result.reserveCapacity(dictionary.count)

        for (key, value) in dictionary {

            guard let streetID = Int(key) else {
                continue
            }

            guard let colorString = value as? String else {
                continue
            }

            guard let color = UIColor(
                simRaHexOrNamedColor: colorString
            ) else {
                continue
            }

            result[streetID] = color
        }

        colorCache = result
        return result
    }

    // MARK: - Validation

    private func validate(response: URLResponse) throws {

        guard let http = response as? HTTPURLResponse else {
            throw SimRaHazardServiceError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw SimRaHazardServiceError.httpStatus(http.statusCode)
        }
    }

    // MARK: - Permissive Street JSON Parsing

    private func parseStreetGridPermissively(
        _ data: Data
    ) throws -> [Int: [CLLocationCoordinate2D]] {

        let json = try JSONSerialization.jsonObject(
            with: data,
            options: []
        )

        var result: [Int: [CLLocationCoordinate2D]] = [:]

        if let array = json as? [[String: Any]] {
            for object in array {
                parseStreetObject(
                    object,
                    into: &result
                )
            }
        }

        if let dictionary = json as? [String: Any] {
            for (key, value) in dictionary {

                if let object = value as? [String: Any] {
                    var objectWithID = object
                    objectWithID["id"] = key

                    parseStreetObject(
                        objectWithID,
                        into: &result
                    )
                }
            }
        }

        guard !result.isEmpty else {
            throw SimRaHazardServiceError.invalidStreetMap
        }

        return result
    }

    private func parseStreetObject(
        _ object: [String: Any],
        into result: inout [Int: [CLLocationCoordinate2D]]
    ) {

        let possibleIDKeys = [
            "id",
            "streetId",
            "streetID",
            "osmId",
            "osmID"
        ]

        var streetID: Int?

        for key in possibleIDKeys {
            if let value = object[key] {

                if let intValue = value as? Int {
                    streetID = intValue
                    break
                }

                if let number = value as? NSNumber {
                    streetID = number.intValue
                    break
                }

                if let string = value as? String,
                   let intValue = Int(string) {
                    streetID = intValue
                    break
                }
            }
        }

        guard let streetID else {
            return
        }

        if let coordinates = extractCoordinates(from: object),
           coordinates.count >= 2 {
            result[streetID] = coordinates
        }
    }

    private func extractCoordinates(
        from object: [String: Any]
    ) -> [CLLocationCoordinate2D]? {

        let possibleGeometryKeys = [
            "coordinates",
            "geometry",
            "line",
            "points",
            "path"
        ]

        for key in possibleGeometryKeys {
            guard let value = object[key] else {
                continue
            }

            if let coordinates = decodeCoordinateArray(value) {
                return coordinates
            }

            if let geometry = value as? [String: Any],
               let geometryCoordinates = geometry["coordinates"],
               let coordinates = decodeCoordinateArray(geometryCoordinates) {
                return coordinates
            }
        }

        return nil
    }

    private func decodeCoordinateArray(
        _ value: Any
    ) -> [CLLocationCoordinate2D]? {

        // GeoJSON:
        // [
        //   [longitude, latitude],
        //   [longitude, latitude]
        // ]
        //
        if let array = value as? [[Any]] {

            var coordinates: [CLLocationCoordinate2D] = []
            coordinates.reserveCapacity(array.count)

            for item in array {

                guard item.count >= 2 else {
                    continue
                }

                let longitude = number(from: item[0])
                let latitude = number(from: item[1])

                guard let longitude,
                      let latitude else {
                    continue
                }

                coordinates.append(
                    CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    )
                )
            }

            return coordinates.isEmpty ? nil : coordinates
        }

        // Alternate format:
        // [
        //   {"lat": ..., "lon": ...},
        //   ...
        // ]
        //
        if let array = value as? [[String: Any]] {

            var coordinates: [CLLocationCoordinate2D] = []
            coordinates.reserveCapacity(array.count)

            for item in array {

                let latitude =
                    number(from: item["lat"])
                    ?? number(from: item["latitude"])

                let longitude =
                    number(from: item["lon"])
                    ?? number(from: item["lng"])
                    ?? number(from: item["longitude"])

                guard let latitude,
                      let longitude else {
                    continue
                }

                coordinates.append(
                    CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    )
                )
            }

            return coordinates.isEmpty ? nil : coordinates
        }

        return nil
    }

    private func number(from value: Any?) -> Double? {

        if let value = value as? Double {
            return value
        }

        if let value = value as? Float {
            return Double(value)
        }

        if let value = value as? Int {
            return Double(value)
        }

        if let value = value as? NSNumber {
            return value.doubleValue
        }

        if let value = value as? String {
            return Double(value)
        }

        return nil
    }
}

// MARK: - Current SimRa Street Map DTOs

private struct StreetMapRoot: Decodable {

    let streets: [StreetMapEntry]?

    enum CodingKeys: String, CodingKey {
        case streets
    }

    func asCoordinateMap() -> [Int: [CLLocationCoordinate2D]] {

        guard let streets else {
            return [:]
        }

        var result: [Int: [CLLocationCoordinate2D]] = [:]
        result.reserveCapacity(streets.count)

        for street in streets {
            let coordinates = street.coordinates.map {
                CLLocationCoordinate2D(
                    latitude: $0[1],
                    longitude: $0[0]
                )
            }

            guard coordinates.count >= 2 else {
                continue
            }

            result[street.id] = coordinates
        }

        return result
    }
}

private struct StreetMapEntry: Decodable {

    let id: Int
    let coordinates: [[Double]]

    enum CodingKeys: String, CodingKey {
        case id
        case coordinates
    }
}

// MARK: - UIColor helper

private extension UIColor {

    convenience init?(simRaHexOrNamedColor string: String) {

        let value = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "red":
            self.init(.systemRed)

        case "orange":
            self.init(.systemOrange)

        case "yellow":
            self.init(.systemYellow)

        case "green":
            self.init(.systemGreen)

        case "blue":
            self.init(.systemBlue)

        case "gray", "grey":
            self.init(.systemGray)

        default:

            let hex = value
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "0x", with: "")

            guard
                hex.count == 6 || hex.count == 8,
                let integer = UInt64(hex, radix: 16)
            else {
                return nil
            }

            let red: UInt64
            let green: UInt64
            let blue: UInt64
            let alpha: UInt64

            if hex.count == 8 {
                red = (integer >> 24) & 0xFF
                green = (integer >> 16) & 0xFF
                blue = (integer >> 8) & 0xFF
                alpha = integer & 0xFF
            } else {
                red = (integer >> 16) & 0xFF
                green = (integer >> 8) & 0xFF
                blue = integer & 0xFF
                alpha = 0xFF
            }

            self.init(
                red: CGFloat(red) / 255.0,
                green: CGFloat(green) / 255.0,
                blue: CGFloat(blue) / 255.0,
                alpha: CGFloat(alpha) / 255.0
            )
        }
    }
}