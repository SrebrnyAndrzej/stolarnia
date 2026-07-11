import Foundation

public enum ObstacleType: String, Codable, CaseIterable, Sendable {
    case column
    case chimney
    case installationShaft
    case drywallHousing
    case beam
    case radiator
    case electricalCabinet
    case custom
}

/// Wnęka osadzona w konkretnej ścianie. Kontur otworu działa w lokalnym
/// układzie ściany: X wzdłuż ściany, Y od podłogi.
public struct RecessDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: RecessID
    public let wallID: WallID
    public var name: String
    public var openingContour: ClosedContour2D
    public var depth: Millimeters
    public var constructionType: ConstructionType
    public var notes: String

    public init(
        id: RecessID = RecessID(),
        wallID: WallID,
        name: String,
        openingContour: ClosedContour2D,
        depth: Millimeters,
        constructionType: ConstructionType = .unknown,
        notes: String = ""
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa wnęki nie może być pusta.")
        }

        guard depth > .zero else {
            throw DomainError.invariantViolation("Głębokość wnęki musi być dodatnia.")
        }

        self.id = id
        self.wallID = wallID
        self.name = normalizedName
        self.openingContour = openingContour
        self.depth = depth
        self.constructionType = constructionType
        self.notes = notes
    }
}

/// Element wystający wewnątrz pomieszczenia, np. słup lub zabudowa GK.
public struct ObstacleDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: ObstacleID
    public var type: ObstacleType
    public var name: String
    public var footprint: ClosedContour2D
    public var bottomOffset: Millimeters
    public var height: Millimeters
    public var constructionType: ConstructionType
    public var requiredClearance: Millimeters
    public var notes: String

    public init(
        id: ObstacleID = ObstacleID(),
        type: ObstacleType,
        name: String,
        footprint: ClosedContour2D,
        bottomOffset: Millimeters = .zero,
        height: Millimeters,
        constructionType: ConstructionType = .unknown,
        requiredClearance: Millimeters = .zero,
        notes: String = ""
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa przeszkody nie może być pusta.")
        }

        guard bottomOffset >= .zero,
              height > .zero,
              requiredClearance >= .zero else {
            throw DomainError.invariantViolation(
                "Wymiary przeszkody muszą mieć prawidłowe wartości."
            )
        }

        self.id = id
        self.type = type
        self.name = normalizedName
        self.footprint = footprint
        self.bottomOffset = bottomOffset
        self.height = height
        self.constructionType = constructionType
        self.requiredClearance = requiredClearance
        self.notes = notes
    }
}
