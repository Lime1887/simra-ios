// SimRaApp.swift
// Replace the init() method with this:

override init() {
    setupPreferences()
    applySystemBarAppearance()
    
    // FIX: Move trip recovery to background thread
    Task { @MainActor in
        // Trip recovery should happen in background, not blocking main thread
        // Dispatch to global background queue
        await runTripRecovery()
    }
    
    // Keep preferences setup on main thread for immediate UI readiness
    // The UI can show while background processing happens
}

private func runTripRecovery() async {
    // Run the recovery in the background
    // This should not block the UI
}
