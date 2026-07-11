import Foundation

/// Stałe poziomy wariantu wyceny używane w całej aplikacji.
public enum PricingTier: String, Codable, CaseIterable, Sendable {
    case eco
    case standard
    case premium
    case vip
}

/// Etap obsługi projektu. Wartości `rawValue` są stabilne i nie mogą być zmieniane
/// po zapisaniu danych produkcyjnych.
public enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case inquiry
    case measurementScheduled
    case measurementCompleted
    case designing
    case offerSent
    case accepted
    case readyForProduction
    case installation
    case handover
    case service
    case archived
}

/// Zakres widoczności projektu lub szablonu.
public enum ProjectVisibility: String, Codable, CaseIterable, Sendable {
    case privateOwner
    case company
    case system
}

/// Ochrona własności projektu. Pozwala chronić prywatne produkty firmowe
/// przed przypadkową publikacją lub eksportem jako szablon.
public struct ProjectProtectionPolicy: Codable, Hashable, Sendable {
    public var visibility: ProjectVisibility
    public var allowsTemplateExport: Bool
    public var allowsPublication: Bool
    public var allowsCrossCompanyDuplication: Bool

    public init(
        visibility: ProjectVisibility,
        allowsTemplateExport: Bool,
        allowsPublication: Bool,
        allowsCrossCompanyDuplication: Bool
    ) {
        self.visibility = visibility
        self.allowsTemplateExport = allowsTemplateExport
        self.allowsPublication = allowsPublication
        self.allowsCrossCompanyDuplication = allowsCrossCompanyDuplication
    }

    /// Domyślna polityka dla zwykłego projektu klienta i prywatnego produktu firmy.
    public static let privateProject = ProjectProtectionPolicy(
        visibility: .privateOwner,
        allowsTemplateExport: false,
        allowsPublication: false,
        allowsCrossCompanyDuplication: false
    )

    /// Szablon dostępny wyłącznie w obrębie jednej firmy.
    public static let companyTemplate = ProjectProtectionPolicy(
        visibility: .company,
        allowsTemplateExport: true,
        allowsPublication: false,
        allowsCrossCompanyDuplication: false
    )
}

/// Stabilny, czytelny kod projektu używany w dokumentach, eksporcie i etykietach.
public struct ProjectCode: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ value: String) throws {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty else {
            throw DomainError.invariantViolation("Kod projektu nie może być pusty.")
        }

        guard normalized.count <= 40 else {
            throw DomainError.invariantViolation(
                "Kod projektu nie może przekraczać 40 znaków."
            )
        }

        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_"))

        guard normalized.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
            throw DomainError.invariantViolation(
                "Kod projektu może zawierać wyłącznie litery, cyfry, myślnik i podkreślenie."
            )
        }

        self.rawValue = normalized
    }

    public var description: String {
        rawValue
    }
}

public struct Customer: Identifiable, Codable, Hashable, Sendable {
    public let id: CustomerID
    public var displayName: String
    public var phone: String?
    public var email: String?
    public var notes: String

    public init(
        id: CustomerID = CustomerID(),
        displayName: String,
        phone: String? = nil,
        email: String? = nil,
        notes: String = ""
    ) throws {
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa klienta nie może być pusta.")
        }

        self.id = id
        self.displayName = normalizedName
        self.phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes
    }
}

public struct PostalAddress: Codable, Hashable, Sendable {
    public var street: String
    public var buildingNumber: String
    public var apartmentNumber: String?
    public var postalCode: String
    public var city: String
    public var countryCode: String

    public init(
        street: String = "",
        buildingNumber: String = "",
        apartmentNumber: String? = nil,
        postalCode: String = "",
        city: String = "",
        countryCode: String = "PL"
    ) {
        self.street = street
        self.buildingNumber = buildingNumber
        self.apartmentNumber = apartmentNumber
        self.postalCode = postalCode
        self.city = city
        self.countryCode = countryCode.uppercased()
    }
}

public struct ProjectSite: Identifiable, Codable, Hashable, Sendable {
    public let id: ProjectSiteID
    public var address: PostalAddress
    public var floor: Int?
    public var hasElevator: Bool?
    public var accessNotes: String
    public var parkingNotes: String
    public var transportNotes: String

    public init(
        id: ProjectSiteID = ProjectSiteID(),
        address: PostalAddress = PostalAddress(),
        floor: Int? = nil,
        hasElevator: Bool? = nil,
        accessNotes: String = "",
        parkingNotes: String = "",
        transportNotes: String = ""
    ) {
        self.id = id
        self.address = address
        self.floor = floor
        self.hasElevator = hasElevator
        self.accessNotes = accessNotes
        self.parkingNotes = parkingNotes
        self.transportNotes = transportNotes
    }
}
