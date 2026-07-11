import DomainCore
import Foundation
import SwiftData

/// Jedyny moduł odpowiedzialny za zapis i odczyt pomieszczeń w SwiftData.
/// Zapis pomieszczenia i aktualizacja `WorkshopProject.roomIDs` odbywają się
/// w jednym `ModelContext`.
@ModelActor
public actor SwiftDataRoomRepository {
    public func fetchAll(
        projectID: ProjectID
    ) throws -> [RoomDefinition] {
        let rawProjectID = projectID.rawValue
        let descriptor = FetchDescriptor<RoomRecord>(
            predicate: #Predicate { record in
                record.projectID == rawProjectID
            },
            sortBy: [
                SortDescriptor(\RoomRecord.name, order: .forward)
            ]
        )

        return try modelContext.fetch(descriptor).map {
            try RoomRecordMapper.makeDomainRoom(from: $0)
        }
    }

    public func fetch(
        id: RoomID
    ) throws -> RoomDefinition? {
        guard let record = try fetchRecord(id: id.rawValue) else {
            return nil
        }

        return try RoomRecordMapper.makeDomainRoom(from: record)
    }

    public func save(
        _ room: RoomDefinition
    ) throws {
        guard let projectRecord = try fetchProjectRecord(
            id: room.projectID.rawValue
        ) else {
            throw PersistenceError.projectNotFound(
                room.projectID.description
            )
        }

        var project = try ProjectRecordMapper.makeDomainProject(
            from: projectRecord
        )

        guard project.id == room.projectID else {
            throw PersistenceError.roomProjectMismatch(
                roomID: room.id.description,
                projectID: room.projectID.description
            )
        }

        if let existingRecord = try fetchRecord(id: room.id.rawValue) {
            guard existingRecord.projectID == room.projectID.rawValue else {
                throw PersistenceError.roomProjectMismatch(
                    roomID: room.id.description,
                    projectID: room.projectID.description
                )
            }

            try RoomRecordMapper.update(existingRecord, from: room)
        } else {
            modelContext.insert(
                try RoomRecordMapper.makeRecord(from: room)
            )
        }

        project.addRoom(id: room.id, at: room.updatedAt)
        try ProjectRecordMapper.update(projectRecord, from: project)
        try modelContext.save()
    }

    public func delete(
        id: RoomID
    ) throws {
        guard let roomRecord = try fetchRecord(id: id.rawValue) else {
            throw PersistenceError.roomNotFound(id.description)
        }

        guard let projectRecord = try fetchProjectRecord(
            id: roomRecord.projectID
        ) else {
            throw PersistenceError.projectNotFound(
                roomRecord.projectID.uuidString.lowercased()
            )
        }

        var project = try ProjectRecordMapper.makeDomainProject(
            from: projectRecord
        )

        try deleteFurniture(roomID: roomRecord.roomID)
        project.removeRoom(id: id)
        try ProjectRecordMapper.update(projectRecord, from: project)
        modelContext.delete(roomRecord)
        try modelContext.save()
    }

    public func count(
        projectID: ProjectID
    ) throws -> Int {
        let rawProjectID = projectID.rawValue
        let descriptor = FetchDescriptor<RoomRecord>(
            predicate: #Predicate { record in
                record.projectID == rawProjectID
            }
        )

        return try modelContext.fetchCount(descriptor)
    }

    private func deleteFurniture(
        roomID: UUID
    ) throws {
        let runDescriptor = FetchDescriptor<FurnitureRunRecord>(
            predicate: #Predicate { record in
                record.roomID == roomID
            }
        )
        for record in try modelContext.fetch(runDescriptor) {
            modelContext.delete(record)
        }

        let assemblyDescriptor = FetchDescriptor<FurnitureAssemblyRecord>(
            predicate: #Predicate { record in
                record.roomID == roomID
            }
        )
        for record in try modelContext.fetch(assemblyDescriptor) {
            modelContext.delete(record)
        }
    }

    private func fetchRecord(
        id: UUID
    ) throws -> RoomRecord? {
        let descriptor = FetchDescriptor<RoomRecord>(
            predicate: #Predicate { record in
                record.roomID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }

    private func fetchProjectRecord(
        id: UUID
    ) throws -> ProjectRecord? {
        let descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { record in
                record.projectID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }
}
