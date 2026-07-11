import DomainCore
import Foundation

/// Pełny stan roboczego modułu meblowego zapisany przez warstwę Persistence.
/// `parameters` przechowuje pełny, rozwiązany zestaw wartości użyty do zbudowania
/// mebla. Dzięki temu późniejsza zmiana domyślnych wartości szablonu nie zmienia
/// istniejącego projektu.
public struct StoredFurnitureAssembly:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    public var id: FurnitureAssemblyID {
        assembly.id
    }

    public var roomID: RoomID
    public var assembly: FurnitureAssembly
    public var parameters: FurnitureParameterSet
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        roomID: RoomID,
        assembly: FurnitureAssembly,
        parameters: FurnitureParameterSet,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.roomID = roomID
        self.assembly = assembly
        self.parameters = parameters
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
