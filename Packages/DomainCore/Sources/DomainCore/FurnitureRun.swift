import Foundation

public enum FurnitureRunKind: String, Codable, CaseIterable, Sendable {
    case base
    case wall
    case tall
    case wardrobe
    case bathroom
    case hall
    case custom
}

public enum RunEndStrategy: String, Codable, CaseIterable, Sendable {
    case none
    case filler
    case overlaySide
    case overlaySideAndExtendedTop
    case verticalWallFiller
    case maskingFrame
    case siteTrim
    case custom
}

public enum OpeningTechnology: String, Codable, CaseIterable, Sendable {
    case handle
    case edgeHandle
    case pushToOpen
    case shortenedBottomFingerPull
    case gola
    case routedFront
    case custom
}

public struct CabinetRunTechnology: Codable, Hashable, Sendable {
    public var leftEnd: RunEndStrategy
    public var rightEnd: RunEndStrategy
    public var openingTechnology: OpeningTechnology
    public var overlaySideExtraDepth: Millimeters
    public var topExtension: Millimeters
    public var frontInset: Millimeters
    public var shortenedBottomDepth: Millimeters
    public var minimumFingerClearance: Millimeters
    public var continuousFingerPull: Bool

    public init(
        leftEnd: RunEndStrategy = .none,
        rightEnd: RunEndStrategy = .none,
        openingTechnology: OpeningTechnology = .handle,
        overlaySideExtraDepth: Millimeters = 20,
        topExtension: Millimeters = 20,
        frontInset: Millimeters = 2,
        shortenedBottomDepth: Millimeters = 30,
        minimumFingerClearance: Millimeters = 25,
        continuousFingerPull: Bool = false
    ) throws {
        let dimensions = [
            overlaySideExtraDepth,
            topExtension,
            frontInset,
            shortenedBottomDepth,
            minimumFingerClearance
        ]
        guard dimensions.allSatisfy({ $0 >= .zero }) else {
            throw DomainError.invariantViolation("Parametry technologii ciągu nie mogą być ujemne.")
        }

        self.leftEnd = leftEnd
        self.rightEnd = rightEnd
        self.openingTechnology = openingTechnology
        self.overlaySideExtraDepth = overlaySideExtraDepth
        self.topExtension = topExtension
        self.frontInset = frontInset
        self.shortenedBottomDepth = shortenedBottomDepth
        self.minimumFingerClearance = minimumFingerClearance
        self.continuousFingerPull = continuousFingerPull
    }
}

public struct FurnitureRun: Identifiable, Codable, Hashable, Sendable {
    public let id: FurnitureRunID
    public var roomID: RoomID
    public var wallID: WallID
    public var name: String
    public var kind: FurnitureRunKind
    public var startOffset: Millimeters
    public var endOffset: Millimeters
    public var moduleIDs: [FurnitureAssemblyID]
    public var technology: CabinetRunTechnology

    public init(
        id: FurnitureRunID = FurnitureRunID(),
        roomID: RoomID,
        wallID: WallID,
        name: String,
        kind: FurnitureRunKind,
        startOffset: Millimeters,
        endOffset: Millimeters,
        moduleIDs: [FurnitureAssemblyID] = [],
        technology: CabinetRunTechnology
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Nazwa ciągu meblowego nie może być pusta.")
        }
        guard startOffset >= .zero, endOffset >= .zero else {
            throw DomainError.invariantViolation("Odsunięcia ciągu nie mogą być ujemne.")
        }
        guard Set(moduleIDs).count == moduleIDs.count else {
            throw DomainError.invariantViolation("Ciąg nie może zawierać powtórzonego FurnitureAssemblyID.")
        }

        self.id = id
        self.roomID = roomID
        self.wallID = wallID
        self.name = name
        self.kind = kind
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.moduleIDs = moduleIDs
        self.technology = technology
    }
}

public struct FurnitureRunLayoutResult: Codable, Hashable, Sendable {
    public var availableLength: Millimeters
    public var occupiedLength: Millimeters
    public var remainingLength: Millimeters
    public var isOverfilled: Bool

    public init(
        availableLength: Millimeters,
        occupiedLength: Millimeters
    ) {
        self.availableLength = availableLength
        self.occupiedLength = occupiedLength
        self.remainingLength = availableLength - occupiedLength
        self.isOverfilled = occupiedLength > availableLength
    }
}

public enum FurnitureRunLayoutEngine {
    public static func calculate(
        wallLength: Millimeters,
        run: FurnitureRun,
        assemblies: [FurnitureAssembly]
    ) throws -> FurnitureRunLayoutResult {
        guard wallLength > .zero else {
            throw DomainError.invalidDimension(field: "wallLength", value: wallLength.rawValue)
        }
        guard run.startOffset + run.endOffset < wallLength else {
            throw DomainError.invariantViolation(
                "Suma odsunięć ciągu musi być mniejsza od długości ściany."
            )
        }

        let assembliesByID = Dictionary(uniqueKeysWithValues: assemblies.map { ($0.id, $0) })
        var occupied: Millimeters = .zero

        for moduleID in run.moduleIDs {
            guard let assembly = assembliesByID[moduleID] else {
                throw DomainError.invariantViolation(
                    "Ciąg odwołuje się do nieistniejącego FurnitureAssemblyID."
                )
            }
            occupied = occupied + assembly.size.width
        }

        let available = wallLength - run.startOffset - run.endOffset
        return FurnitureRunLayoutResult(
            availableLength: available,
            occupiedLength: occupied
        )
    }
}
