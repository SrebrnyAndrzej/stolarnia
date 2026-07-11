import Foundation

enum StatusOfertyKlienta:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case szkic
    case wysłana
    case zaakceptowana
    case odrzucona
    case wygasła

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .szkic:
            return "Szkic"
        case .wysłana:
            return "Wysłana"
        case .zaakceptowana:
            return "Zaakceptowana"
        case .odrzucona:
            return "Odrzucona"
        case .wygasła:
            return "Wygasła"
        }
    }

    var systemImage: String {
        switch self {
        case .szkic:
            return "doc"
        case .wysłana:
            return "paperplane.fill"
        case .zaakceptowana:
            return "checkmark.seal.fill"
        case .odrzucona:
            return "xmark.seal.fill"
        case .wygasła:
            return "clock.badge.exclamationmark"
        }
    }
}

struct ZarchiwizowanaOfertaKlienta:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var projectName: String
    var customerName: String
    var variantName: String
    var grossPrice: Double
    var netPrice: Double
    var vatAmount: Double
    var status:
        StatusOfertyKlienta = .szkic
    var createdAt = Date()
    var modifiedAt = Date()
    var validUntil: Date
    var fileName: String
    var notes = ""

    var isExpired: Bool {
        status != .zaakceptowana
        && status != .odrzucona
        && validUntil < Date()
    }

    var effectiveStatus:
        StatusOfertyKlienta
    {
        isExpired
        ? .wygasła
        : status
    }
}
