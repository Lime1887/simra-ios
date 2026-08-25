// AppDelegate.swift
// Modify the application:didFinishLaunchingWithOptions: method

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    
    Utility.createSimraPrefs()
    Utility.createAppsPrefs()
    Utility.createProfilePrefs()
    Utility.createKeyPrefs()

    print(defaults.dictionaryRepresentation())
    print("Path to user preference file: \(Utility.getDocumentDirectory() ?? "")")

    lm.requestWhenInUseAuthorization()
    
    // FIX: Run trip recovery in background after initial setup
    dispatchAsyncTripRecovery()
    
    trips.save()
    return true
}

// Add this new method:
private func dispatchAsyncTripRecovery() {
    // Run recovery in background so it doesn't block the UI
    let group = OperationQueue.main
    group.maxConcurrentOperationCount = 1
    
    // Create a background operation for trip recovery
    let recoveryOp = Operation(block: { [weak self] in
        Task { @MainActor in
            // Ensure AppDelegate is available
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                // Only recover if we haven't already done this in this session
                if !appDelegate.defaults.bool(forKey: "tripRecoveryAlreadyDone") {
                    // Run recovery in background
                    self?.runTripRecoveryBackground(appDelegate.trips)
                }
            }
        }
    })
    
    group.add(recoveryOp)
}

// Another method to handle the background recovery:
private func runTripRecoveryBackground(_ trips: Trips) {
    // Run on background queue
    DispatchQueue.global(qos: .userInteractive).async { // Use appropriate QoS
        do {
            // Call the recoverIncompleteTrips method
            // This needs to be bridged to Swift
        } catch {
            // Handle errors
        }
    }
}
