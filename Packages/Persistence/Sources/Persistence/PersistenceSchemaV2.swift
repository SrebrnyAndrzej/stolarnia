import Foundation
import SwiftData

/// Druga, niezmienna wersja schematu trwałych danych.
/// Dodaje osobny zapis pomieszczeń bez modyfikowania `PersistenceSchemaV1`.
public enum PersistenceSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            PersistenceSchemaV1.ProjectRecord.self,
            RoomRecord.self
        ]
    }

    @Model
    public final class RoomRecord {
        public var roomID: UUID
        public var projectID: UUID
        public var name: String
        public var createdAt: Date
        public var updatedAt: Date

        public var boundarySegmentCount: Int
        public var wallCount: Int
        public var windowCount: Int
        public var doorCount: Int
        public var recessCount: Int
        public var obstacleCount: Int
        public var wallProfileCount: Int

        public var payloadSchemaVersion: Int
        public var domainPayload: Data

        public init(
            roomID: UUID,
            projectID: UUID,
            name: String,
            createdAt: Date,
            updatedAt: Date,
            boundarySegmentCount: Int,
            wallCount: Int,
            windowCount: Int,
            doorCount: Int,
            recessCount: Int,
            obstacleCount: Int,
            wallProfileCount: Int,
            payloadSchemaVersion: Int,
            domainPayload: Data
        ) {
            self.roomID = roomID
            self.projectID = projectID
            self.name = name
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.boundarySegmentCount = boundarySegmentCount
            self.wallCount = wallCount
            self.windowCount = windowCount
            self.doorCount = doorCount
            self.recessCount = recessCount
            self.obstacleCount = obstacleCount
            self.wallProfileCount = wallProfileCount
            self.payloadSchemaVersion = payloadSchemaVersion
            self.domainPayload = domainPayload
        }
    }
}

public typealias RoomRecord = PersistenceSchemaV2.RoomRecord
