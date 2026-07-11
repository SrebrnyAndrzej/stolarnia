import DomainCore
import Foundation
import SwiftData

/// Jedyny moduł odpowiedzialny za zapis i odczyt projektów w SwiftData.
/// Dostęp do `ModelContext` jest serializowany przez `@ModelActor`.
@ModelActor
public actor SwiftDataProjectRepository {
    public func fetchAll() throws -> [WorkshopProject] {
        let descriptor = FetchDescriptor<ProjectRecord>(
            sortBy: [
                SortDescriptor(\ProjectRecord.updatedAt, order: .reverse)
            ]
        )

        return try modelContext.fetch(descriptor).map {
            try ProjectRecordMapper.makeDomainProject(from: $0)
        }
    }

    public func fetch(
        id: ProjectID
    ) throws -> WorkshopProject? {
        let rawID = id.rawValue
        let descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { record in
                record.projectID == rawID
            }
        )

        guard let record = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return try ProjectRecordMapper.makeDomainProject(from: record)
    }

    public func save(
        _ project: WorkshopProject
    ) throws {
        try ensureCodeIsAvailable(
            project.code.rawValue,
            excluding: project.id.rawValue
        )

        if let existingRecord = try fetchRecord(id: project.id.rawValue) {
            try ProjectRecordMapper.update(existingRecord, from: project)
        } else {
            let newRecord = try ProjectRecordMapper.makeRecord(from: project)
            modelContext.insert(newRecord)
        }

        try modelContext.save()
    }

    public func delete(
        id: ProjectID
    ) throws {
        guard let record = try fetchRecord(id: id.rawValue) else {
            throw PersistenceError.projectNotFound(id.description)
        }

        let rawProjectID = id.rawValue
        let roomDescriptor = FetchDescriptor<RoomRecord>(
            predicate: #Predicate { roomRecord in
                roomRecord.projectID == rawProjectID
            }
        )
        let roomRecords = try modelContext.fetch(roomDescriptor)

        for roomRecord in roomRecords {
            try deleteFurniture(roomID: roomRecord.roomID)
            modelContext.delete(roomRecord)
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    public func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<ProjectRecord>())
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
    ) throws -> ProjectRecord? {
        let descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { record in
                record.projectID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }

    private func ensureCodeIsAvailable(
        _ code: String,
        excluding projectID: UUID
    ) throws {
        let descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { record in
                record.code == code && record.projectID != projectID
            }
        )

        guard try modelContext.fetch(descriptor).isEmpty else {
            throw PersistenceError.duplicateProjectCode(code)
        }
    }
}
