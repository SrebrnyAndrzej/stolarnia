import Foundation

enum KategoriaZdjeciaPomiarowego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case widokOgólny
    case lewyNarożnik
    case prawyNarożnik
    case skos
    case okno
    case drzwi
    case instalacje
    case przeszkoda
    case podłoga
    case sufit
    case inne

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .widokOgólny:
            return "Widok ogólny"
        case .lewyNarożnik:
            return "Lewy narożnik"
        case .prawyNarożnik:
            return "Prawy narożnik"
        case .skos:
            return "Skos"
        case .okno:
            return "Okno"
        case .drzwi:
            return "Drzwi"
        case .instalacje:
            return "Instalacje"
        case .przeszkoda:
            return "Przeszkoda"
        case .podłoga:
            return "Podłoga"
        case .sufit:
            return "Sufit"
        case .inne:
            return "Inne"
        }
    }

    var systemImage: String {
        switch self {
        case .widokOgólny:
            return "rectangle.expand.vertical"
        case .lewyNarożnik:
            return "arrow.turn.up.left"
        case .prawyNarożnik:
            return "arrow.turn.up.right"
        case .skos:
            return "triangle.righthalf.filled"
        case .okno:
            return "window.vertical.closed"
        case .drzwi:
            return "door.left.hand.closed"
        case .instalacje:
            return "bolt.circle"
        case .przeszkoda:
            return "exclamationmark.triangle"
        case .podłoga:
            return "rectangle.bottomhalf.filled"
        case .sufit:
            return "rectangle.tophalf.filled"
        case .inne:
            return "photo"
        }
    }
}

struct ZdjeciePomiarowe:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var projectID: String
    var roomID: String
    var projectName: String
    var roomName: String
    var customerName: String

    var fileName: String
    var thumbnailFileName: String?
    var category:
        KategoriaZdjeciaPomiarowego
    var caption: String
    var createdAt = Date()
    var modifiedAt = Date()
}
