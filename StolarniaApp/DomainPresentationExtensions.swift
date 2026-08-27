import DomainCore

extension ConstructionType {
    var displayName: String {
        switch self {
        case .masonry:
            return "Murowana"
        case .concrete:
            return "Betonowa"
        case .drywall:
            return "Karton-gips"
        case .woodFrame:
            return "Konstrukcja drewniana"
        case .furniturePanel:
            return "Płyta meblowa"
        case .unknown:
            return "Nieustalona"
        }
    }
}

extension ProjectStatus {
    var displayName: String {
        switch self {
        case .inquiry:
            return "Zapytanie"
        case .measurementScheduled:
            return "Umówiony pomiar"
        case .measurementCompleted:
            return "Pomiar wykonany"
        case .designing:
            return "Projektowanie"
        case .offerSent:
            return "Oferta wysłana"
        case .accepted:
            return "Zaakceptowane"
        case .readyForProduction:
            return "Do produkcji"
        case .installation:
            return "Montaż"
        case .handover:
            return "Odbiór"
        case .service:
            return "Serwis"
        case .archived:
            return "Archiwum"
        }
    }
}

extension PricingTier {
    var displayName: String {
        switch self {
        case .eco:
            return "Eco"
        case .standard:
            return "Standard"
        case .premium:
            return "Premium"
        case .vip:
            return "VIP"
        }
    }
}
