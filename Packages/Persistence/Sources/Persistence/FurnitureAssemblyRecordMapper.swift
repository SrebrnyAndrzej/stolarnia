import DomainCore
import Foundation

/// Jedyne przejście między pełnym stanem modułu meblowego a SwiftData.
public enum FurnitureAssemblyRecordMapper {
    public static let payloadSchemaVersion = 1

    public static func makeRecord(
        from stored: StoredFurnitureAssembly
    ) throws -> FurnitureAssemblyRecord {
        FurnitureAssemblyRecord(
            assemblyID: stored.assembly.id.rawValue,
            roomID: stored.roomID.rawValue,
            wallID: stored.assembly.placement?.wallID?.rawValue,
            templateID: stored.assembly.templateID?.rawValue,
            placementID: stored.assembly.placement?.id.rawValue,
            name: stored.assembly.name,
            kindRawValue: stored.assembly.kind.rawValue,
            width: stored.assembly.size.width.rawValue,
            height: stored.assembly.size.height.rawValue,
            depth: stored.assembly.size.depth.rawValue,
            componentCount: stored.assembly.components.count,
            parameterCount: stored.parameters.entries.count,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt,
            payloadSchemaVersion: payloadSchemaVersion,
            domainPayload: try encode(stored)
        )
    }

    public static func update(
        _ record: FurnitureAssemblyRecord,
        from stored: StoredFurnitureAssembly
    ) throws {
        record.assemblyID = stored.assembly.id.rawValue
        record.roomID = stored.roomID.rawValue
        record.wallID = stored.assembly.placement?.wallID?.rawValue
        record.templateID = stored.assembly.templateID?.rawValue
        record.placementID = stored.assembly.placement?.id.rawValue
        record.name = stored.assembly.name
        record.kindRawValue = stored.assembly.kind.rawValue
        record.width = stored.assembly.size.width.rawValue
        record.height = stored.assembly.size.height.rawValue
        record.depth = stored.assembly.size.depth.rawValue
        record.componentCount = stored.assembly.components.count
        record.parameterCount = stored.parameters.entries.count
        record.createdAt = stored.createdAt
        record.updatedAt = stored.updatedAt
        record.payloadSchemaVersion = payloadSchemaVersion
        record.domainPayload = try encode(stored)
    }

    public static func makeStoredAssembly(
        from record: FurnitureAssemblyRecord
    ) throws -> StoredFurnitureAssembly {
        guard record.payloadSchemaVersion == payloadSchemaVersion else {
            throw PersistenceError.corruptedFurnitureAssemblyPayload(
                record.assemblyID.uuidString.lowercased()
            )
        }

        do {
            return try decoder.decode(
                StoredFurnitureAssembly.self,
                from: record.domainPayload
            )
        } catch {
            throw PersistenceError.corruptedFurnitureAssemblyPayload(
                record.assemblyID.uuidString.lowercased()
            )
        }
    }

    private static func encode(
        _ stored: StoredFurnitureAssembly
    ) throws -> Data {
        try encoder.encode(stored)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
