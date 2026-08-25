import SwiftUI
import CoreLocation
import CoreMotion

@main
struct SimRaApp: App {
    @StateObject private var bluetoothObserver = BluetoothObserver()

    init() {
        setupPreferences()
        applySystemBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .alert("SimRa", isPresented: $bluetoothObserver.showDisconnectAlert) {
                    Button("Return", role: .cancel) { }
                } message: {
                    Text("Device disconnected")
                }
                .onOpenURL { url in
                    handleDeeplink(url: url)
                }
        }
    }

    // MARK: - Initial Setup

    private func setupPreferences() {
        Utility.createSimraPrefs()
        Utility.createAppsPrefs()
        Utility.createProfilePrefs()
        Utility.createKeyPrefs()

        let defaults = UserDefaults.standard
        print("\(defaults.dictionaryRepresentation())")
        print("Path to user preference file: \(Utility.getDocumentDirectory() ?? "")")

        // Vorbereitung der Singleton-/Core-Dienste
        let _ = Regions()
        let _ = News()
        
        let lm = CLLocationManager()
        lm.requestWhenInUseAuthorization()

        let _ = CMMotionManager()
        let trips = Trips()
        trips.save()
    }

    private func applySystemBarAppearance() {
        let barButtonTitleColor = UIColor.label

        UIBarButtonItem.appearance().setTitleTextAttributes([
            .foregroundColor: barButtonTitleColor
        ], for: .normal)

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithDefaultBackground()
        navigationAppearance.shadowColor = .clear
        
        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigationAppearance
        navigationBar.compactAppearance = navigationAppearance
        navigationBar.scrollEdgeAppearance = navigationAppearance

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        toolbarAppearance.shadowColor = .clear
        
        let toolbar = UIToolbar.appearance()
        toolbar.standardAppearance = toolbarAppearance
        toolbar.scrollEdgeAppearance = toolbarAppearance
    }

    // MARK: - Deeplink Handling (simra://)

    private func handleDeeplink(url: URL) {
        guard url.scheme == "simra" else { return }

        if url.host == "recording" {
            if url.path == "/start" {
                _ = RecordingShortcutBridge.startRecording()
            } else if url.path == "/stop" {
                _ = RecordingShortcutBridge.stopRecording()
            }
        }
    }
}