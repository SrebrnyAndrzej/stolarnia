import Foundation

/// Numer rewizji projektu. Rewizje zaczynają się od 1 i są prezentowane jako R01, R02 itd.
public struct ProjectRevisionNumber: Codable, Hashable, Comparable, Sendable {
    public let rawValue: Int

    public init(_ rawValue: Int) throws {
        guard rawValue >= 1 else {
            throw DomainError.invalidDimension(
                field: "numer rewizji",
                value: Double(rawValue)
            )
        }

        self.rawValue = rawValue
    }

    public static func < (
        lhs: ProjectRevisionNumber,
        rhs: ProjectRevisionNumber
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var code: String {
        String(format: "R%02d", rawValue)
    }

    public func next() throws -> ProjectRevisionNumber {
        try ProjectRevisionNumber(rawValue + 1)
    }
}
