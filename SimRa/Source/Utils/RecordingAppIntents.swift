import AppIntents

@available(iOS 16.0, *)
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Ride"
    static var description = IntentDescription("Starts a SimRa ride recording.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let started = await MainActor.run {
            RecordingShortcutBridge.startRecording()
        }
        guard started else {
            throw RecordingShortcutError.alreadyRecording
        }

        return .result(dialog: "Ride recording started.")
    }
}

@available(iOS 16.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Ride"
    static var description = IntentDescription("Stops the active SimRa ride recording.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let stopped = await MainActor.run {
            RecordingShortcutBridge.stopRecording()
        }
        guard stopped else {
            throw RecordingShortcutError.notRecording
        }

        return .result(dialog: "Ride recording stopped.")
    }
}

@available(iOS 16.0, *)
enum RecordingShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case alreadyRecording
    case notRecording

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .alreadyRecording:
            return "A ride is already being recorded."
        case .notRecording:
            return "No ride is currently being recorded."
        }
    }
}

@available(iOS 16.0, *)
struct SimRaShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start ride in \(.applicationName)",
                "Fahrt in \(.applicationName) starten"
            ],
            shortTitle: "Start Ride",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop ride in \(.applicationName)",
                "Fahrt in \(.applicationName) stoppen"
            ],
            shortTitle: "Stop Ride",
            systemImageName: "stop.fill"
        )
    }
}
