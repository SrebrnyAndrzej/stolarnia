import DomainCore
import Foundation

/// Jedyne przejście między `RoomDefinition` a rekordem SwiftData.
public enum RoomRecordMapper {
    public static let payloadSchemaVersion = 1

    public static func makeRecord(
        from room: RoomDefinition
    ) throws -> RoomRecord {
        RoomRecord(
            roomID: room.id.rawValue,
            projectID: room.projectID.rawValue,
            name: room.name,
            createdAt: room.createdAt,
            updatedAt: room.updatedAt,
            boundarySegmentCount: room.geometry.boundary.segments.count,
            wallCount: room.geometry.walls.count,
            windowCount: room.windows.count,
            doorCount: room.doors.count,
            recessCount: room.recesses.count,
            obstacleCount: room.obstacles.count,
            wallProfileCount: room.wallProfiles.count,
            payloadSchemaVersion: payloadSchemaVersion,
            domainPayload: try encode(room)
        )
    }

    public static func update(
        _ record: RoomRecord,
        from room: RoomDefinition
    ) throws {
        record.roomID = room.id.rawValue
        record.projectID = room.projectID.rawValue
        record.name = room.name
        record.createdAt = room.createdAt
        record.updatedAt = room.updatedAt
        record.boundarySegmentCount = room.geometry.boundary.segments.count
        record.wallCount = room.geometry.walls.count
        record.windowCount = room.windows.count
        record.doorCount = room.doors.count
        record.recessCount = room.recesses.count
        record.obstacleCount = room.obstacles.count
        record.wallProfileCount = room.wallProfiles.count
        record.payloadSchemaVersion = payloadSchemaVersion
        record.domainPayload = try encode(room)
    }

    public static func makeDomainRoom(
        from record: RoomRecord
    ) throws -> RoomDefinition {
        guard record.payloadSchemaVersion == payloadSchemaVersion else {
            throw PersistenceError.corruptedRoomPayload(
                record.roomID.uuidString.lowercased()
            )
        }

        do {
            return try decoder.decode(
                RoomDefinition.self,
                from: record.domainPayload
            )
        } catch {
            throw PersistenceError.corruptedRoomPayload(
                record.roomID.uuidString.lowercased()
            )
        }
    }

    private static func encode(
        _ room: RoomDefinition
    ) throws -> Data {
        try encoder.encode(room)
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
