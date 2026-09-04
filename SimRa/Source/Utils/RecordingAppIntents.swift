//  RecordingAppIntents.swift
//  SimRa
//
//  App Intents and Siri Shortcuts for starting/stopping recordings.
//

import AppIntents

// MARK: - Start Recording

@available(iOS 16.0, *)
struct StartRecordingIntent: AppIntent {

    static var title: LocalizedStringResource =
        "Aufzeichnung starten"

    static var description =
        IntentDescription(
            "Starts a SimRa recording."
        )

    static var openAppWhenRun = true

    func perform()
        async
        throws
        -> some IntentResult & ProvidesDialog
    {
        let started =
            await MainActor.run {
                RecordingShortcutBridge.startRecording()
            }

        guard started else {
            throw RecordingShortcutError.alreadyRecording
        }

        return .result(
            dialog:
                IntentDialog(
                    LocalizationHelper.localizedStringResource(
                        for:
                            "Recording started."
                    )
                )
        )
    }
}

// MARK: - Stop Recording

@available(iOS 16.0, *)
struct StopRecordingIntent: AppIntent {

    static var title: LocalizedStringResource =
        "Aufzeichnung stoppen"

    static var description =
        IntentDescription(
            "Stops the active SimRa recording."
        )

    static var openAppWhenRun = true

    func perform()
        async
        throws
        -> some IntentResult & ProvidesDialog
    {
        let stopped =
            await MainActor.run {
                RecordingShortcutBridge.stopRecording()
            }

        guard stopped else {
            throw RecordingShortcutError.notRecording
        }

        return .result(
            dialog:
                IntentDialog(
                    LocalizationHelper.localizedStringResource(
                        for:
                            "Recording stopped."
                    )
                )
        )
    }
}

// MARK: - Mark Incident

@available(iOS 16.0, *)
struct MarkGeneralIncidentIntent: AppIntent {

    static var title: LocalizedStringResource =
        "Mark Danger"

    static var description =
        IntentDescription(
            "Marks a danger during the current SimRa recording."
        )

    static var openAppWhenRun = true

    func perform()
        async
        throws
        -> some IntentResult & ProvidesDialog
    {
        let marked = await MainActor.run {
            RecordingShortcutBridge.markIncident(
                0,
                source: "Siri"
            )
        }

        guard marked else {
            throw RecordingShortcutError.notRecording
        }

        return .result(
            dialog:
                IntentDialog("Gefahr erfasst.")
        )
    }
}

@available(iOS 16.0, *)
struct MarkIncidentIntent: AppIntent {

    static var title: LocalizedStringResource =
        "Mark Incident"

    static var description =
        IntentDescription(
            "Marks an incident or hazard during the current SimRa recording."
        )

    static var openAppWhenRun = true

    @Parameter(title: "Incident Type")
    var incidentType: IncidentType?

    init() {
        self.incidentType = .generalHazard
    }

    init(incidentType: IncidentType) {
        self.incidentType = incidentType
    }

    func perform()
        async
        throws
        -> some IntentResult & ProvidesDialog
    {
        let selectedType = incidentType ?? .generalHazard

        let marked = await MainActor.run {
            RecordingShortcutBridge.markIncident(
                selectedType.incidentID,
                source: "Siri"
            )
        }

        guard marked else {
            throw RecordingShortcutError.notRecording
        }

        return .result(
            dialog:
                IntentDialog(
                    LocalizationHelper.localizedStringResource(
                        for:
                            "\(selectedType.localizedName) erfasst. Details kannst du nach der Fahrt ausfüllen."
                    )
                )
        )
    }
}

// MARK: - Incident Type

@available(iOS 16.0, *)
enum IncidentType: String, AppEnum {

    case generalHazard = "General Hazard"
    case closePassing = "Close Passing"
    case dooring = "Dooring"
    case turningAccident = "Turning Accident"
    case oncomingTraffic = "Oncoming Traffic"
    case parkingCar = "Parking Car"
    case tailgating = "Tailgating"
    case sidestep = "Sidestep"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: "Incident Type"
        )
    }

    static var caseDisplayRepresentations:
        [IncidentType: DisplayRepresentation] {
        [
            .generalHazard:
                "Gefahr / Incident",

            .closePassing:
                "Zu nahes Überholen",

            .dooring:
                "Dooring / Autotür",

            .turningAccident:
                "Abbiegeunfall",

            .oncomingTraffic:
                "Gegenverkehr",

            .parkingCar:
                "Einparkendes Auto",

            .tailgating:
                "Auffahren / Drängeln",

            .sidestep:
                "Ausweichen / Hindernis"
        ]
    }

    /// Numeric incident ID used by the existing SimRa recording bridge.
    var incidentID: Int {
        switch self {
        case .generalHazard:
            return 0

        case .closePassing:
            return 1

        case .dooring:
            return 2

        case .turningAccident:
            return 3

        case .oncomingTraffic:
            return 4

        case .parkingCar:
            return 5

        case .tailgating:
            return 6

        case .sidestep:
            return 7
        }
    }

    var localizedName: String {
        switch self {
        case .generalHazard:
            return "Gefahr"

        case .closePassing:
            return "Zu nahes Überholen"

        case .dooring:
            return "Dooring"

        case .turningAccident:
            return "Abbiegeunfall"

        case .oncomingTraffic:
            return "Gegenverkehr"

        case .parkingCar:
            return "Einparkendes Auto"

        case .tailgating:
            return "Auffahren"

        case .sidestep:
            return "Ausweichen"
        }
    }
}

// MARK: - Errors

@available(iOS 16.0, *)
enum RecordingShortcutError:
    Error,
    CustomLocalizedStringResourceConvertible
{
    case alreadyRecording
    case notRecording
    case invalidIncidentType

    var localizedStringResource:
        LocalizedStringResource
    {
        switch self {
        case .alreadyRecording:
            return
                LocalizationHelper.localizedStringResource(
                    for:
                        "Eine SimRa-Aufnahme läuft bereits."
                )

        case .notRecording:
            return
                LocalizationHelper.localizedStringResource(
                    for:
                        "Aktuell läuft keine SimRa-Aufnahme."
                )

        case .invalidIncidentType:
            return
                LocalizationHelper.localizedStringResource(
                    for:
                        "Kein Vorfalltyp ausgewählt."
                )
        }
    }
}

// MARK: - App Shortcuts

@available(iOS 16.0, *)
struct SimRaShortcuts:
    AppShortcutsProvider
{

    @AppShortcutsBuilder
    static var appShortcuts:
        [AppShortcut]
    {

        AppShortcut(
            intent:
                StartRecordingIntent(),
            phrases:
                [
                    "Aufzeichnung in \(.applicationName) starten",
                    "Fahrt in \(.applicationName) starten"
                ],
            shortTitle:
                "Aufzeichnung starten",
            systemImageName:
                "play.fill"
        )

        AppShortcut(
            intent:
                StopRecordingIntent(),
            phrases:
                [
                    "Aufzeichnung in \(.applicationName) stoppen",
                    "Fahrt in \(.applicationName) beenden"
                ],
            shortTitle:
                "Aufzeichnung stoppen",
            systemImageName:
                "stop.fill"
        )

        // Incident marking shortcuts
        AppShortcut(
            intent: MarkGeneralIncidentIntent(),
            phrases: [
                "Gefahr melden in \(.applicationName)",
                "Gefahr in \(.applicationName) melden",
                "Gefahrenstelle in \(.applicationName) melden",
                "Incident in \(.applicationName) melden",
                "Vorfall in \(.applicationName) erfassen",
                "Erfasse einen Vorfall in \(.applicationName)",
                "Melde einen Vorfall in \(.applicationName)",
                "Mark hazard in \(.applicationName)",
                "Mark incident in \(.applicationName)",
                "Mark close passing in \(.applicationName)",
                "Mark dooring in \(.applicationName)",
                "Zeichne zu nahes Überholen in \(.applicationName) auf",
                "Zeichne Einparkendes Auto in \(.applicationName) auf",
                "Zeichne Abbiegeunfall in \(.applicationName) auf",
                "Zeichne Gegenverkehr in \(.applicationName) auf",
                "Zeichne Auffahren in \(.applicationName) auf",
                "Zeichne Türöffnen in \(.applicationName) auf",
                "Zeichne Ausweichen in \(.applicationName) auf"
            ],
            shortTitle: "Vorfall erfassen",
            systemImageName: "exclamationmark.triangle"
        )
    }
}

// MARK: - Localization

struct LocalizationHelper {

    static func localizedString(
        for key: String
    ) -> String {

        NSLocalizedString(
            key,
            bundle:
                .main,
            comment:
                ""
        )
    }

    static func localizedStringResource(
        for key: String
    ) -> LocalizedStringResource {

        LocalizedStringResource(
            stringLiteral:
                key
        )
    }
}
