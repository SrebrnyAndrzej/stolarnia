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
