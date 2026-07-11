import Foundation

public enum HingeSide: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case none
}

public enum OpeningDirection: String, Codable, CaseIterable, Sendable {
    case inward
    case outward
    case sliding
    case none
}

public enum WindowOpeningType: String, Codable, CaseIterable, Sendable {
    case fixed
    case tilt
    case turn
    case tiltAndTurn
    case sliding
    case custom
}

/// Wspólna pozycja otworu w lokalnym układzie ściany.
public struct WallOpeningPlacement: Identifiable, Codable, Hashable, Sendable {
    public let id: OpeningID
    public let wallID: WallID
    public var offsetFromWallStart: Millimeters
    public var bottomOffset: Millimeters
    public var width: Millimeters
    public var height: Millimeters
    public var revealDepth: Millimeters

    public init(
        id: OpeningID = OpeningID(),
        wallID: WallID,
        offsetFromWallStart: Millimeters,
        bottomOffset: Millimeters,
        width: Millimeters,
        height: Millimeters,
        revealDepth: Millimeters = .zero
    ) throws {
        guard offsetFromWallStart >= .zero,
              bottomOffset >= .zero,
              width > .zero,
              height > .zero,
              revealDepth >= .zero else {
            throw DomainError.invariantViolation(
                "Położenie i wymiary otworu muszą mieć prawidłowe wartości."
            )
        }

        self.id = id
        self.wallID = wallID
        self.offsetFromWallStart = offsetFromWallStart
        self.bottomOffset = bottomOffset
        self.width = width
        self.height = height
        self.revealDepth = revealDepth
    }
}

public struct WindowDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: WindowID
    public var placement: WallOpeningPlacement
    public var openingType: WindowOpeningType
    public var hingeSide: HingeSide
    public var openingDirection: OpeningDirection
    public var sillThickness: Millimeters
    public var sillProjection: Millimeters
    public var hasRadiatorBelow: Bool
    public var hasRollerShutter: Bool
    public var notes: String

    public init(
        id: WindowID = WindowID(),
        placement: WallOpeningPlacement,
        openingType: WindowOpeningType,
        hingeSide: HingeSide = .none,
        openingDirection: OpeningDirection = .inward,
        sillThickness: Millimeters = .zero,
        sillProjection: Millimeters = .zero,
        hasRadiatorBelow: Bool = false,
        hasRollerShutter: Bool = false,
        notes: String = ""
    ) throws {
        guard sillThickness >= .zero, sillProjection >= .zero else {
            throw DomainError.invariantViolation(
                "Wymiary parapetu nie mogą być ujemne."
            )
        }

        self.id = id
        self.placement = placement
        self.openingType = openingType
        self.hingeSide = hingeSide
        self.openingDirection = openingDirection
        self.sillThickness = sillThickness
        self.sillProjection = sillProjection
        self.hasRadiatorBelow = hasRadiatorBelow
        self.hasRollerShutter = hasRollerShutter
        self.notes = notes
    }
}

public struct DoorDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: DoorID
    public var placement: WallOpeningPlacement
    public var hingeSide: HingeSide
    public var openingDirection: OpeningDirection
    public var frameWidth: Millimeters
    public var architraveWidth: Millimeters
    public var hasThreshold: Bool
    public var notes: String

    public init(
        id: DoorID = DoorID(),
        placement: WallOpeningPlacement,
        hingeSide: HingeSide,
        openingDirection: OpeningDirection,
        frameWidth: Millimeters = .zero,
        architraveWidth: Millimeters = .zero,
        hasThreshold: Bool = false,
        notes: String = ""
    ) throws {
        guard frameWidth >= .zero, architraveWidth >= .zero else {
            throw DomainError.invariantViolation(
                "Wymiary ościeżnicy i opaski nie mogą być ujemne."
            )
        }

        self.id = id
        self.placement = placement
        self.hingeSide = hingeSide
        self.openingDirection = openingDirection
        self.frameWidth = frameWidth
        self.architraveWidth = architraveWidth
        self.hasThreshold = hasThreshold
        self.notes = notes
    }
}
