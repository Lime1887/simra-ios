//
//  TripPaginationManager.swift
//  SimRa
//
//  Created for Performance Optimization
//

import Foundation

/// Manages pagination and lazy loading of trips to improve memory usage
@MainActor
final class TripPaginationManager: NSObject, ObservableObject {
    
    static let shared = TripPaginationManager()
    
    // MARK: - Constants
    
    private enum Constants {
        static let tripsPerPage = 25
        static let preloadThreshold = 5
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var currentPage = 0
    @Published private(set) var loadedTrips: [TripInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMoreTrips = true
    
    // MARK: - Private Properties
    
    private var allTripIdentifiers: [Int] = []
    private var totalTripsCount = 0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        reloadTripIdentifiers()
    }
    
    // MARK: - Public Methods
    
    /// Reload all trip identifiers from storage
    @objc func reloadTripIdentifiers() {
        guard let trips = AppDelegate.shared().trips else { return }
        
        // Get all trip IDs and sort them (newest first)
        let allIDs = trips.tripInfos.keys.sorted { $0 > $1 }
        allTripIdentifiers = allIDs
        totalTripsCount = allIDs.count
        currentPage = 0
        loadedTrips = []
        hasMoreTrips = totalTripsCount > 0
        
        // Load first page
        loadNextPage()
    }
    
    /// Load next page of trips
    @objc func loadNextPage() {
        guard !isLoading && hasMoreTrips else { return }
        
        isLoading = true
        
        let startIndex = currentPage * Constants.tripsPerPage
        let endIndex = min(startIndex + Constants.tripsPerPage, totalTripsCount)
        
        guard startIndex < totalTripsCount else {
            isLoading = false
            hasMoreTrips = false
            return
        }
        
        // Load trips for current page
        let pageIdentifiers = allTripIdentifiers[startIndex..<endIndex]
        guard let trips = AppDelegate.shared().trips else {
            isLoading = false
            return
        }
        
        var pageTripInfos: [TripInfo] = []
        for id in pageIdentifiers {
            if let tripInfo = trips.tripInfos[id] {
                pageTripInfos.append(tripInfo)
            }
        }
        
        loadedTrips.append(contentsOf: pageTripInfos)
        currentPage += 1
        hasMoreTrips = (currentPage * Constants.tripsPerPage) < totalTripsCount
        isLoading = false
    }
    
    /// Check if should preload based on current scroll position
    @objc func checkPreload(visibleRowsCount: Int) {
        let loadedCount = loadedTrips.count
        let distanceToEnd = loadedCount - visibleRowsCount
        
        if distanceToEnd < Constants.preloadThreshold && hasMoreTrips && !isLoading {
            loadNextPage()
        }
    }
    
    /// Clear all loaded trips
    @objc func resetPagination() {
        currentPage = 0
        loadedTrips = []
        hasMoreTrips = true
    }
}
