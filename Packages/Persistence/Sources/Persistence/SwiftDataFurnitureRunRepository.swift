import DomainCore
import Foundation
import SwiftData

/// Zapisuje ciągi meblowe i pilnuje, aby wskazywały moduły z tego samego pomieszczenia.
@ModelActor
public actor SwiftDataFurnitureRunRepository {
    public func fetchAll(
        roomID: RoomID
    ) throws -> [FurnitureRun] {
        let rawRoomID = roomID.rawValue
        let descriptor = FetchDescriptor<FurnitureRunRecord>(
            predicate: #Predicate { record in
                record.roomID == rawRoomID
            },
            sortBy: [
                SortDescriptor(\FurnitureRunRecord.name)
            ]
        )

        return try modelContext.fetch(descriptor).map {
            try FurnitureRunRecordMapper.makeDomainRun(from: $0)
        }
    }

    public func fetch(
        id: FurnitureRunID
    ) throws -> FurnitureRun? {
        guard let record = try fetchRecord(id: id.rawValue) else {
            return nil
        }

        return try FurnitureRunRecordMapper.makeDomainRun(from: record)
    }

    public func save(
        _ run: FurnitureRun,
        at date: Date = Date()
    ) throws {
        let room = try requireRoom(id: run.roomID)

        guard room.geometry.wall(id: run.wallID) != nil else {
            throw PersistenceError.furnitureRunWallMismatch(
                runID: run.id.description,
                wallID: run.wallID.description
            )
        }

        let availableModuleIDs = try assemblyIDs(roomID: run.roomID)
        for moduleID in run.moduleIDs where !availableModuleIDs.contains(moduleID) {
            throw PersistenceError.furnitureRunMissingModule(
                runID: run.id.description,
                assemblyID: moduleID.description
            )
        }

        if let existingRecord = try fetchRecord(id: run.id.rawValue) {
            guard existingRecord.roomID == run.roomID.rawValue else {
                throw PersistenceError.furnitureRunRoomMismatch(
                    runID: run.id.description,
                    roomID: run.roomID.description
                )
            }

            try FurnitureRunRecordMapper.update(
                existingRecord,
                from: run,
                updatedAt: date
            )
        } else {
            modelContext.insert(
                try FurnitureRunRecordMapper.makeRecord(
                    from: run,
                    createdAt: date,
                    updatedAt: date
                )
            )
        }

        try modelContext.save()
    }

    public func delete(
        id: FurnitureRunID
    ) throws {
        guard let record = try fetchRecord(id: id.rawValue) else {
            throw PersistenceError.furnitureRunNotFound(id.description)
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    public func count(
        roomID: RoomID
    ) throws -> Int {
        let rawRoomID = roomID.rawValue
        let descriptor = FetchDescriptor<FurnitureRunRecord>(
            predicate: #Predicate { record in
                record.roomID == rawRoomID
            }
        )

        return try modelContext.fetchCount(descriptor)
    }

    private func requireRoom(
        id: RoomID
    ) throws -> RoomDefinition {
        let rawRoomID = id.rawValue
        let descriptor = FetchDescriptor<RoomRecord>(
            predicate: #Predicate { record in
                record.roomID == rawRoomID
            }
        )

        guard let record = try modelContext.fetch(descriptor).first else {
            throw PersistenceError.roomNotFound(id.description)
        }

        return try RoomRecordMapper.makeDomainRoom(from: record)
    }

    private func assemblyIDs(
        roomID: RoomID
    ) throws -> Set<FurnitureAssemblyID> {
        let rawRoomID = roomID.rawValue
        let descriptor = FetchDescriptor<FurnitureAssemblyRecord>(
            predicate: #Predicate { record in
                record.roomID == rawRoomID
            }
        )

        return Set(
            try modelContext.fetch(descriptor).map {
                FurnitureAssemblyID(rawValue: $0.assemblyID)
            }
        )
    }

    private func fetchRecord(
        id: UUID
    ) throws -> FurnitureRunRecord? {
        let descriptor = FetchDescriptor<FurnitureRunRecord>(
            predicate: #Predicate { record in
                record.runID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }
}
