import DomainCore
import Foundation

/// Jedyne przejście między `FurnitureRun` a rekordem SwiftData.
public enum FurnitureRunRecordMapper {
    public static let payloadSchemaVersion = 1

    public static func makeRecord(
        from run: FurnitureRun,
        createdAt: Date,
        updatedAt: Date
    ) throws -> FurnitureRunRecord {
        FurnitureRunRecord(
            runID: run.id.rawValue,
            roomID: run.roomID.rawValue,
            wallID: run.wallID.rawValue,
            name: run.name,
            kindRawValue: run.kind.rawValue,
            moduleCount: run.moduleIDs.count,
            createdAt: createdAt,
            updatedAt: updatedAt,
            payloadSchemaVersion: payloadSchemaVersion,
            domainPayload: try encode(run)
        )
    }

    public static func update(
        _ record: FurnitureRunRecord,
        from run: FurnitureRun,
        updatedAt: Date
    ) throws {
        record.runID = run.id.rawValue
        record.roomID = run.roomID.rawValue
        record.wallID = run.wallID.rawValue
        record.name = run.name
        record.kindRawValue = run.kind.rawValue
        record.moduleCount = run.moduleIDs.count
        record.updatedAt = updatedAt
        record.payloadSchemaVersion = payloadSchemaVersion
        record.domainPayload = try encode(run)
    }

    public static func makeDomainRun(
        from record: FurnitureRunRecord
    ) throws -> FurnitureRun {
        guard record.payloadSchemaVersion == payloadSchemaVersion else {
            throw PersistenceError.corruptedFurnitureRunPayload(
                record.runID.uuidString.lowercased()
            )
        }

        do {
            return try decoder.decode(
                FurnitureRun.self,
                from: record.domainPayload
            )
        } catch {
            throw PersistenceError.corruptedFurnitureRunPayload(
                record.runID.uuidString.lowercased()
            )
        }
    }

    private static func encode(
        _ run: FurnitureRun
    ) throws -> Data {
        try encoder.encode(run)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}
