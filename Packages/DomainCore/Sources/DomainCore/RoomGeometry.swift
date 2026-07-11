import Foundation

public enum ConstructionType: String, Codable, CaseIterable, Sendable {
    case masonry
    case concrete
    case drywall
    case woodFrame
    case furniturePanel
    case unknown
}

/// Właściwości budowlane ściany są oddzielone od jej segmentu geometrycznego.
/// `contourSegmentID` wskazuje dokładnie jeden segment obrysu pomieszczenia.
public struct WallSegment: Identifiable, Codable, Hashable, Sendable {
    public let id: WallID
    public let contourSegmentID: ContourSegmentID
    public var name: String
    public var thickness: Millimeters
    public var startHeight: Millimeters
    public var endHeight: Millimeters
    public var constructionType: ConstructionType
    public var notes: String

    public init(
        id: WallID = WallID(),
        contourSegmentID: ContourSegmentID,
        name: String,
        thickness: Millimeters,
        startHeight: Millimeters,
        endHeight: Millimeters? = nil,
        constructionType: ConstructionType = .unknown,
        notes: String = ""
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa ściany nie może być pusta.")
        }

        guard thickness > .zero else {
            throw DomainError.invariantViolation("Grubość ściany musi być dodatnia.")
        }

        let resolvedEndHeight = endHeight ?? startHeight
        guard startHeight > .zero, resolvedEndHeight > .zero else {
            throw DomainError.invariantViolation("Wysokość ściany musi być dodatnia.")
        }

        self.id = id
        self.contourSegmentID = contourSegmentID
        self.name = normalizedName
        self.thickness = thickness
        self.startHeight = startHeight
        self.endHeight = resolvedEndHeight
        self.constructionType = constructionType
        self.notes = notes
    }
}

/// Kanoniczna geometria pomieszczenia. Obrys może zawierać linie i łuki,
/// dzięki czemu od początku obsługuje wykusze i układy niestandardowe.
public struct RoomGeometry: Codable, Hashable, Sendable {
    public let boundary: ClosedContour2D
    public private(set) var walls: [WallSegment]

    public init(
        boundary: ClosedContour2D,
        walls: [WallSegment]
    ) throws {
        let wallIDs = walls.map(\.id)
        guard Set(wallIDs).count == wallIDs.count else {
            throw DomainError.invariantViolation(
                "Ściany pomieszczenia muszą mieć unikalne identyfikatory."
            )
        }

        let mappedSegmentIDs = walls.map(\.contourSegmentID)
        guard Set(mappedSegmentIDs).count == mappedSegmentIDs.count else {
            throw DomainError.invariantViolation(
                "Jeden segment obrysu nie może należeć do kilku ścian."
            )
        }

        let boundarySegmentIDs = Set(boundary.segments.map(\.id))
        guard Set(mappedSegmentIDs) == boundarySegmentIDs else {
            throw DomainError.invariantViolation(
                "Każdy segment obrysu musi mieć dokładnie jedną definicję ściany."
            )
        }

        self.boundary = boundary
        self.walls = walls
    }

    public func wall(id: WallID) -> WallSegment? {
        walls.first { $0.id == id }
    }

    public func geometry(of wallID: WallID) -> ContourSegment2D? {
        guard let wall = wall(id: wallID) else {
            return nil
        }

        return boundary.segment(id: wall.contourSegmentID)
    }
}

/// Pomieszczenie jest osobną encją domenową powiązaną stabilnym `ProjectID`.
public struct RoomDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: RoomID
    public let projectID: ProjectID
    public let createdAt: Date

    public var name: String
    public private(set) var geometry: RoomGeometry
    public private(set) var windows: [WindowDefinition]
    public private(set) var doors: [DoorDefinition]
    public private(set) var recesses: [RecessDefinition]
    public private(set) var obstacles: [ObstacleDefinition]
    public private(set) var wallProfiles: [WallProfileDefinition]

    /// Pole opcjonalne utrzymuje zgodność z JSON-em zapisanym przed v0.16.0.
    public private(set) var bayProjectionsV016: [BayProjectionDefinitionV016]?

    public private(set) var updatedAt: Date

    public var bayProjections: [BayProjectionDefinitionV016] {
        bayProjectionsV016 ?? []
    }

    public init(
        id: RoomID = RoomID(),
        projectID: ProjectID,
        name: String,
        geometry: RoomGeometry,
        windows: [WindowDefinition] = [],
        doors: [DoorDefinition] = [],
        recesses: [RecessDefinition] = [],
        obstacles: [ObstacleDefinition] = [],
        wallProfiles: [WallProfileDefinition] = [],
        bayProjections: [BayProjectionDefinitionV016] = [],
        createdAt: Date = Date()
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa pomieszczenia nie może być pusta.")
        }

        try Self.validateReferences(
            geometry: geometry,
            windows: windows,
            doors: doors,
            recesses: recesses,
            wallProfiles: wallProfiles,
            bayProjections: bayProjections
        )

        try Self.validateUniqueIDs(
            windows: windows,
            doors: doors,
            recesses: recesses,
            obstacles: obstacles,
            wallProfiles: wallProfiles,
            bayProjections: bayProjections
        )

        self.id = id
        self.projectID = projectID
        self.createdAt = createdAt
        self.name = normalizedName
        self.geometry = geometry
        self.windows = windows
        self.doors = doors
        self.recesses = recesses
        self.obstacles = obstacles
        self.wallProfiles = wallProfiles
        self.bayProjectionsV016 = bayProjections.isEmpty
            ? nil
            : bayProjections
        self.updatedAt = createdAt
    }

    public mutating func replaceGeometry(
        _ newGeometry: RoomGeometry,
        at date: Date = Date()
    ) throws {
        try Self.validateReferences(
            geometry: newGeometry,
            windows: windows,
            doors: doors,
            recesses: recesses,
            wallProfiles: wallProfiles,
            bayProjections: bayProjections
        )

        geometry = newGeometry
        updatedAt = date
    }

    public mutating func addWindow(
        _ window: WindowDefinition,
        at date: Date = Date()
    ) throws {
        try ensureWallExists(window.placement.wallID)
        guard !windows.contains(where: { $0.id == window.id }) else { return }
        windows.append(window)
        updatedAt = date
    }

    public mutating func addDoor(
        _ door: DoorDefinition,
        at date: Date = Date()
    ) throws {
        try ensureWallExists(door.placement.wallID)
        guard !doors.contains(where: { $0.id == door.id }) else { return }
        doors.append(door)
        updatedAt = date
    }

    public mutating func addRecess(
        _ recess: RecessDefinition,
        at date: Date = Date()
    ) throws {
        try ensureWallExists(recess.wallID)
        guard !recesses.contains(where: { $0.id == recess.id }) else { return }
        recesses.append(recess)
        updatedAt = date
    }

    public mutating func addObstacle(
        _ obstacle: ObstacleDefinition,
        at date: Date = Date()
    ) {
        guard !obstacles.contains(where: { $0.id == obstacle.id }) else { return }
        obstacles.append(obstacle)
        updatedAt = date
    }

    public mutating func addBayProjection(
        _ projection: BayProjectionDefinitionV016,
        at date: Date = Date()
    ) throws {
        try ensureWallExists(projection.wallID)

        var updated = bayProjections
        guard !updated.contains(where: { $0.id == projection.id }) else {
            return
        }

        updated.append(projection)
        bayProjectionsV016 = updated
        updatedAt = date
    }

    public mutating func removeWindow(
        id: WindowID,
        at date: Date = Date()
    ) {
        windows.removeAll { $0.id == id }
        updatedAt = date
    }

    public mutating func removeDoor(
        id: DoorID,
        at date: Date = Date()
    ) {
        doors.removeAll { $0.id == id }
        updatedAt = date
    }

    public mutating func removeRecess(
        id: RecessID,
        at date: Date = Date()
    ) {
        recesses.removeAll { $0.id == id }
        updatedAt = date
    }

    public mutating func removeBayProjection(
        id: BayProjectionID,
        at date: Date = Date()
    ) {
        let updated = bayProjections.filter {
            $0.id != id
        }
        bayProjectionsV016 = updated.isEmpty
            ? nil
            : updated
        updatedAt = date
    }

    public mutating func addWallProfile(
        _ profile: WallProfileDefinition,
        at date: Date = Date()
    ) throws {
        try ensureWallExists(profile.wallID)
        guard !wallProfiles.contains(where: { $0.id == profile.id }) else { return }
        wallProfiles.append(profile)
        updatedAt = date
    }

    private func ensureWallExists(_ wallID: WallID) throws {
        guard geometry.wall(id: wallID) != nil else {
            throw DomainError.invariantViolation(
                "Element pomieszczenia wskazuje nieistniejącą ścianę."
            )
        }
    }

    private static func validateReferences(
        geometry: RoomGeometry,
        windows: [WindowDefinition],
        doors: [DoorDefinition],
        recesses: [RecessDefinition],
        wallProfiles: [WallProfileDefinition],
        bayProjections: [BayProjectionDefinitionV016]
    ) throws {
        let wallIDs = Set(geometry.walls.map(\.id))
        let referencedWallIDs = windows.map(\.placement.wallID)
            + doors.map(\.placement.wallID)
            + recesses.map(\.wallID)
            + wallProfiles.map(\.wallID)
            + bayProjections.map(\.wallID)

        guard referencedWallIDs.allSatisfy(wallIDs.contains) else {
            throw DomainError.invariantViolation(
                "Element pomieszczenia wskazuje nieistniejącą ścianę."
            )
        }
    }

    private static func validateUniqueIDs(
        windows: [WindowDefinition],
        doors: [DoorDefinition],
        recesses: [RecessDefinition],
        obstacles: [ObstacleDefinition],
        wallProfiles: [WallProfileDefinition],
        bayProjections: [BayProjectionDefinitionV016]
    ) throws {
        guard Set(windows.map(\.id)).count == windows.count,
              Set(doors.map(\.id)).count == doors.count,
              Set(recesses.map(\.id)).count == recesses.count,
              Set(obstacles.map(\.id)).count == obstacles.count,
              Set(wallProfiles.map(\.id)).count == wallProfiles.count,
              Set(bayProjections.map(\.id)).count == bayProjections.count else {
            throw DomainError.invariantViolation(
                "Elementy pomieszczenia muszą mieć unikalne identyfikatory."
            )
        }
    }
}
