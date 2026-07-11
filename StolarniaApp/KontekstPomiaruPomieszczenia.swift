import Foundation

enum StatusPomiaruPomieszczenia:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case rozpoczęty
    case wymagaUzupełnienia
    case kompletny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .rozpoczęty:
            return "Rozpoczęty"
        case .wymagaUzupełnienia:
            return "Wymaga uzupełnienia"
        case .kompletny:
            return "Kompletny"
        }
    }

    var systemImage: String {
        switch self {
        case .rozpoczęty:
            return "pencil.circle"
        case .wymagaUzupełnienia:
            return "exclamationmark.triangle"
        case .kompletny:
            return "checkmark.circle.fill"
        }
    }
}

struct KontekstPomiaruPomieszczenia:
    Hashable,
    Codable
{
    var projectID: String
    var roomID: String
    var projectName: String
    var roomName: String
    var customerName: String

    init(
        projectID: String,
        roomID: String,
        projectName: String,
        roomName: String,
        customerName: String
    ) {
        self.projectID = projectID
        self.roomID = roomID
        self.projectName = projectName
        self.roomName = roomName
        self.customerName = customerName
    }
}
