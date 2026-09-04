import AppIntents

@available(iOS 16.0, *)
enum TrafficParticipantType: String, AppEnum, CaseIterable, Identifiable {
    case car
    case taxi
    case delivery
    case bus
    case truck
    case pedestrian
    case bicycle
    case motorcycle
    case escooter
    case other

    var id: String { rawValue }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Verkehrsteilnehmer")

    var displayRepresentation: DisplayRepresentation {
        switch self {
        case .car:
            return DisplayRepresentation("Auto", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .taxi:
            return DisplayRepresentation("Taxi", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .delivery:
            return DisplayRepresentation("Lieferfahrzeug", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .bus:
            return DisplayRepresentation("Bus", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .truck:
            return DisplayRepresentation("LKW", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .pedestrian:
            return DisplayRepresentation("Fußgänger", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .bicycle:
            return DisplayRepresentation("Fahrrad", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .motorcycle:
            return DisplayRepresentation("Motorrad", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .escooter:
            return DisplayRepresentation("E-Scooter", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        case .other:
            return DisplayRepresentation("Sonstige", 
                                         deferredLocalizedTitle: "\(self.localizedTitle())")
        }
    }

    private func localizedTitle() -> String {
        switch self {
        case .car: return "Auto"
        case .taxi: return "Taxi"
        case .delivery: return "Lieferfahrzeug"
        case .bus: return "Bus"
        case .truck: return "LKW"
        case .pedestrian: return "Fußgänger"
        case .bicycle: return "Fahrrad"
        case .motorcycle: return "Motorrad"
        case .escooter: return "E-Scooter"
        case .other: return "Sonstige"
        }
    }

    var userVisibleName: String {
        localizedTitle()
    }
}
