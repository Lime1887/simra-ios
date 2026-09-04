//
//  BatteryOptimizationManager.swift
//  SimRa
//
//  Created for Battery Life Optimization
//

import CoreLocation
import CoreMotion
import Foundation

/// Manages battery optimization settings and configurations
@MainActor
final class BatteryOptimizationManager: NSObject, ObservableObject {
    
    static let shared = BatteryOptimizationManager()
    
    // MARK: - Battery Optimization Levels
    
    enum BatteryOptimizationLevel: Int {
        case maximum = 0  // Best accuracy, higher battery drain
        case balanced = 1  // Balanced accuracy and battery
        case maximum_battery_saving = 2  // Lower accuracy, better battery life
    }
    
    // MARK: - Published Properties
    
    @Published var optimizationLevel: BatteryOptimizationLevel = .balanced
    
    // MARK: - GPS Configuration
    
    /// Get recommended GPS accuracy based on optimization level
    func getOptimalGPSAccuracy() -> CLLocationAccuracy {
        switch optimizationLevel {
        case .maximum:
            return kCLLocationAccuracyBest  // ±5m
        case .balanced:
            return kCLLocationAccuracyNearestTenMeters  // ±10m
        case .maximum_battery_saving:
            return kCLLocationAccuracyHundredMeters  // ±100m
        }
    }
    
    /// Get recommended GPS update interval
    func getOptimalGPSUpdateInterval() -> TimeInterval {
        switch optimizationLevel {
        case .maximum:
            return 1.0  // 1 second
        case .balanced:
            return 2.0  // 2 seconds
        case .maximum_battery_saving:
            return 5.0  // 5 seconds
        }
    }
    
    /// Get recommended GPS distance filter
    func getOptimalGPSDistanceFilter() -> CLLocationDistance {
        switch optimizationLevel {
        case .maximum:
            return 0  // No filter
        case .balanced:
            return 5  // 5 meters
        case .maximum_battery_saving:
            return 10  // 10 meters
        }
    }
    
    // MARK: - Motion Manager Configuration
    
    /// Get recommended motion update interval
    func getOptimalMotionUpdateInterval() -> TimeInterval {
        switch optimizationLevel {
        case .maximum:
            return 0.016  // ~60 Hz
        case .balanced:
            return 0.05   // 20 Hz
        case .maximum_battery_saving:
            return 0.1    // 10 Hz
        }
    }
    
    /// Check if motion updates should be started
    func shouldUseMotionUpdates() -> Bool {
        switch optimizationLevel {
        case .maximum, .balanced:
            return true
        case .maximum_battery_saving:
            return false  // Disable motion sensing for battery savings
        }
    }
    
    // MARK: - Widget Update Configuration
    
    /// Get recommended widget update interval
    func getOptimalWidgetUpdateInterval() -> TimeInterval {
        switch optimizationLevel {
        case .maximum:
            return 1.0  // 1 second
        case .balanced:
            return 2.0  // 2 seconds (already using .never policy with event-based updates)
        case .maximum_battery_saving:
            return 5.0  // 5 seconds
        }
    }
    
    // MARK: - Background Task Configuration
    
    /// Check if background processing should be enabled
    func shouldEnableBackgroundProcessing() -> Bool {
        switch optimizationLevel {
        case .maximum:
            return true
        case .balanced:
            return true
        case .maximum_battery_saving:
            return false  // Disable background processing
        }
    }
    
    // MARK: - Display Configuration
    
    /// Check if map should update rendering frequency
    func getMapUpdateThrottle() -> TimeInterval {
        switch optimizationLevel {
        case .maximum:
            return 0.5  // Update 2x per second
        case .balanced:
            return 1.0  // Update 1x per second
        case .maximum_battery_saving:
            return 2.0  // Update every 2 seconds
        }
    }
    
    // MARK: - Persistence
    
    /// Save optimization level to UserDefaults
    func saveOptimizationLevel() {
        UserDefaults.standard.set(
            optimizationLevel.rawValue,
            forKey: "batteryOptimizationLevel"
        )
    }
    
    /// Load optimization level from UserDefaults
    func loadOptimizationLevel() {
        let savedLevel = UserDefaults.standard.integer(
            forKey: "batteryOptimizationLevel"
        )
        optimizationLevel = BatteryOptimizationLevel(rawValue: savedLevel) ?? .balanced
    }
    
    // MARK: - Settings
    
    /// Get all available optimization levels as string pairs
    @objc func getOptimizationLevelOptions() -> [[String: String]] {
        return [
            ["value": "0", "label": NSLocalizedString("Maximum Accuracy", comment: "Battery optimization level")],
            ["value": "1", "label": NSLocalizedString("Balanced", comment: "Battery optimization level")],
            ["value": "2", "label": NSLocalizedString("Maximum Battery Saving", comment: "Battery optimization level")]
        ]
    }
}
