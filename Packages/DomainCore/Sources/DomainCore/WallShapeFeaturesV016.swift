import Foundation

public enum BayProjectionDirectionV016: String, Codable, CaseIterable, Sendable {
    case outward
    case inward
}

public struct BayProjectionDefinitionV016: Identifiable, Codable, Hashable, Sendable {
    public let id: BayProjectionID
    public let wallID: WallID
    public var name: String
    public var offsetFromWallStart: Millimeters
    public var bottomOffset: Millimeters
    public var width: Millimeters
    public var height: Millimeters
    public var depth: Millimeters
    public var direction: BayProjectionDirectionV016
    public var notes: String

    public init(
        id: BayProjectionID = BayProjectionID(),
        wallID: WallID,
        name: String,
        offsetFromWallStart: Millimeters,
        bottomOffset: Millimeters = .zero,
        width: Millimeters,
        height: Millimeters,
        depth: Millimeters,
        direction: BayProjectionDirectionV016 = .outward,
        notes: String = ""
    ) throws {
        let normalizedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation(
                "Nazwa wykuszu nie może być pusta."
            )
        }

        guard offsetFromWallStart >= .zero,
              bottomOffset >= .zero,
              width > .zero,
              height > .zero,
              depth > .zero else {
            throw DomainError.invariantViolation(
                "Położenie i wymiary wykuszu muszą mieć prawidłowe wartości."
            )
        }

        self.id = id
        self.wallID = wallID
        self.name = normalizedName
        self.offsetFromWallStart = offsetFromWallStart
        self.bottomOffset = bottomOffset
        self.width = width
        self.height = height
        self.depth = depth
        self.direction = direction
        self.notes = notes
    }
}
