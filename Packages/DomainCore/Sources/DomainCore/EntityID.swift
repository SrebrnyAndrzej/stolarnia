import Foundation

/// Silnie typowany, stabilny identyfikator encji domenowej.
///
/// Dzięki parametrowi `Tag` identyfikatora jednego typu nie można omyłkowo
/// przekazać w miejsce identyfikatora innego typu.
public struct EntityID<Tag>: RawRepresentable, Hashable, Codable, Sendable,
    CustomStringConvertible, LosslessStringConvertible
{
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    /// Tworzy nowy stabilny identyfikator.
    public init() {
        self.init(rawValue: UUID())
    }

    /// Odtwarza identyfikator z zapisu UUID.
    public init?(_ description: String) {
        guard let uuid = UUID(uuidString: description) else {
            return nil
        }

        self.init(rawValue: uuid)
    }

    /// Kanoniczny zapis używany w JSON, logach, PDF i eksporcie.
    public var description: String {
        rawValue.uuidString.lowercased()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let encodedValue = try container.decode(String.self)

        guard let uuid = UUID(uuidString: encodedValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Nieprawidłowy identyfikator UUID: \(encodedValue)"
            )
        }

        self.init(rawValue: uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
