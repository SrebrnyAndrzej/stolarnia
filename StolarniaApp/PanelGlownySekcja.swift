import Foundation

enum PanelGlownySekcja:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case projekty
    case firma

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projekty:
            return "Klienci i projekty"
        case .firma:
            return "Firma i bazy"
        }
    }

    var subtitle: String {
        switch self {
        case .projekty:
            return "Zlecenia, pomieszczenia i projekty mebli"
        case .firma:
            return "Dane firmy, materiały, okucia i stawki"
        }
    }

    var systemImage: String {
        switch self {
        case .projekty:
            return "folder"
        case .firma:
            return "building.2"
        }
    }
}
