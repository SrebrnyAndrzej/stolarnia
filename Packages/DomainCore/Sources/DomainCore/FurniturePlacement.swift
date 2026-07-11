import Foundation

public enum FurnitureAnchoringMode: String, Codable, CaseIterable, Sendable {
    case floorStanding
    case wallMounted
    case ceilingMounted
    case freestanding
    case builtIn
    case custom
}

/// Jednoznaczne osadzenie zespołu meblowego w pomieszczeniu.
/// Jeśli `wallID` jest ustawione, `offsetAlongWall` jest liczony od początku tej ściany.
public struct FurniturePlacement: Identifiable, Codable, Hashable, Sendable {
    public let id: FurniturePlacementID
    public var roomID: RoomID
    public var wallID: WallID?
    public var assemblyID: FurnitureAssemblyID

    public var offsetAlongWall: Millimeters
    public var offsetFromWall: Millimeters
    public var bottomOffset: Millimeters
    public var rotationDegrees: Double
    public var anchoringMode: FurnitureAnchoringMode

    public init(
        id: FurniturePlacementID = FurniturePlacementID(),
        roomID: RoomID,
        wallID: WallID?,
        assemblyID: FurnitureAssemblyID,
        offsetAlongWall: Millimeters = .zero,
        offsetFromWall: Millimeters = .zero,
        bottomOffset: Millimeters = .zero,
        rotationDegrees: Double = 0,
        anchoringMode: FurnitureAnchoringMode = .floorStanding
    ) throws {
        guard offsetAlongWall >= .zero else {
            throw DomainError.invalidDimension(
                field: "offsetAlongWall",
                value: offsetAlongWall.rawValue
            )
        }
        guard offsetFromWall >= .zero else {
            throw DomainError.invalidDimension(
                field: "offsetFromWall",
                value: offsetFromWall.rawValue
            )
        }
        guard bottomOffset >= .zero else {
            throw DomainError.invalidDimension(
                field: "bottomOffset",
                value: bottomOffset.rawValue
            )
        }
        guard rotationDegrees.isFinite else {
            throw DomainError.invariantViolation("Kąt obrotu mebla musi być skończony.")
        }

        self.id = id
        self.roomID = roomID
        self.wallID = wallID
        self.assemblyID = assemblyID
        self.offsetAlongWall = offsetAlongWall
        self.offsetFromWall = offsetFromWall
        self.bottomOffset = bottomOffset
        self.rotationDegrees = rotationDegrees
        self.anchoringMode = anchoringMode
    }
}
