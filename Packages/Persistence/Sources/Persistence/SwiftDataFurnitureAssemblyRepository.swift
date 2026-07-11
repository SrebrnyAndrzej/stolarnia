import DomainCore
import Foundation
import SwiftData

/// Zapisuje moduły meblowe razem z parametrami potrzebnymi do ich ponownej budowy.
@ModelActor
public actor SwiftDataFurnitureAssemblyRepository {
    public func fetchAll(
        roomID: RoomID
    ) throws -> [StoredFurnitureAssembly] {
        let rawRoomID = roomID.rawValue
        let descriptor = FetchDescriptor<FurnitureAssemblyRecord>(
            predicate: #Predicate { record in
                record.roomID == rawRoomID
            },
            sortBy: [
                SortDescriptor(\FurnitureAssemblyRecord.updatedAt)
            ]
        )

        return try modelContext.fetch(descriptor).map {
            try FurnitureAssemblyRecordMapper.makeStoredAssembly(from: $0)
        }
    }

    public func fetch(
        id: FurnitureAssemblyID
    ) throws -> StoredFurnitureAssembly? {
        guard let record = try fetchRecord(id: id.rawValue) else {
            return nil
        }

        return try FurnitureAssemblyRecordMapper.makeStoredAssembly(
            from: record
        )
    }

    public func save(
        _ stored: StoredFurnitureAssembly
    ) throws {
        let room = try requireRoom(id: stored.roomID)
        let normalizedStored = try normalized(stored, in: room)

        if let existingRecord = try fetchRecord(
            id: normalizedStored.assembly.id.rawValue
        ) {
            guard existingRecord.roomID == normalizedStored.roomID.rawValue else {
                throw PersistenceError.furnitureRoomMismatch(
                    assemblyID: normalizedStored.assembly.id.description,
                    roomID: normalizedStored.roomID.description
                )
            }

            try FurnitureAssemblyRecordMapper.update(
                existingRecord,
                from: normalizedStored
            )
        } else {
            modelContext.insert(
                try FurnitureAssemblyRecordMapper.makeRecord(from: normalizedStored)
            )
        }

        try modelContext.save()
    }

    public func delete(
        id: FurnitureAssemblyID,
        at date: Date = Date()
    ) throws {
        guard let record = try fetchRecord(id: id.rawValue) else {
            throw PersistenceError.furnitureAssemblyNotFound(id.description)
        }

        let rawRoomID = record.roomID
        let runDescriptor = FetchDescriptor<FurnitureRunRecord>(
            predicate: #Predicate { runRecord in
                runRecord.roomID == rawRoomID
            }
        )

        for runRecord in try modelContext.fetch(runDescriptor) {
            var run = try FurnitureRunRecordMapper.makeDomainRun(
                from: runRecord
            )

            guard run.moduleIDs.contains(id) else {
                continue
            }

            run.moduleIDs.removeAll { $0 == id }
            try FurnitureRunRecordMapper.update(
                runRecord,
                from: run,
                updatedAt: date
            )
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    public func count(
        roomID: RoomID
    ) throws -> Int {
        let rawRoomID = roomID.rawValue
        let descriptor = FetchDescriptor<FurnitureAssemblyRecord>(
            predicate: #Predicate { record in
                record.roomID == rawRoomID
            }
        )

        return try modelContext.fetchCount(descriptor)
    }

    private func normalized(
        _ stored: StoredFurnitureAssembly,
        in room: RoomDefinition
    ) throws -> StoredFurnitureAssembly {
        var resolvedParameters = stored.parameters
        if let placement = stored.assembly.placement {
            guard placement.roomID == stored.roomID else {
                throw PersistenceError.furnitureRoomMismatch(
                    assemblyID: stored.assembly.id.description,
                    roomID: stored.roomID.description
                )
            }

            if let wallID = placement.wallID,
               room.geometry.wall(id: wallID) == nil {
                throw PersistenceError.furnitureWallMismatch(
                    assemblyID: stored.assembly.id.description,
                    wallID: wallID.description
                )
            }
        }

        if let templateID = stored.assembly.templateID {
            guard let templateRecord = try fetchTemplateRecord(
                id: templateID.rawValue
            ) else {
                throw PersistenceError.furnitureTemplateNotFound(
                    templateID.description
                )
            }

            let template = try FurnitureTemplateRecordMapper
                .makeDomainTemplate(from: templateRecord)

            resolvedParameters = try template.resolvedParameters(
                overrides: stored.parameters
            )
        }

        return StoredFurnitureAssembly(
            roomID: stored.roomID,
            assembly: stored.assembly,
            parameters: resolvedParameters,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt
        )
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

    private func fetchRecord(
        id: UUID
    ) throws -> FurnitureAssemblyRecord? {
        let descriptor = FetchDescriptor<FurnitureAssemblyRecord>(
            predicate: #Predicate { record in
                record.assemblyID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }

    private func fetchTemplateRecord(
        id: UUID
    ) throws -> FurnitureTemplateRecord? {
        let descriptor = FetchDescriptor<FurnitureTemplateRecord>(
            predicate: #Predicate { record in
                record.templateID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }
}
