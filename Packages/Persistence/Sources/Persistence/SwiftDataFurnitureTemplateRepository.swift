import DomainCore
import Foundation
import SwiftData

/// Przechowuje szablony systemowe, firmowe i prywatne.
/// Nie udostępnia usuwania, aby przypadkowo nie zerwać stabilnych `FurnitureTemplateID`.
@ModelActor
public actor SwiftDataFurnitureTemplateRepository {
    public func fetchAll() throws -> [FurnitureTemplate] {
        let descriptor = FetchDescriptor<FurnitureTemplateRecord>(
            sortBy: [
                SortDescriptor(\FurnitureTemplateRecord.categoryRawValue),
                SortDescriptor(\FurnitureTemplateRecord.name)
            ]
        )

        return try modelContext.fetch(descriptor).map {
            try FurnitureTemplateRecordMapper.makeDomainTemplate(from: $0)
        }
    }

    public func fetch(
        id: FurnitureTemplateID
    ) throws -> FurnitureTemplate? {
        guard let record = try fetchRecord(id: id.rawValue) else {
            return nil
        }

        return try FurnitureTemplateRecordMapper.makeDomainTemplate(
            from: record
        )
    }

    public func fetch(
        code: String
    ) throws -> FurnitureTemplate? {
        let descriptor = FetchDescriptor<FurnitureTemplateRecord>(
            predicate: #Predicate { record in
                record.code == code
            }
        )

        guard let record = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return try FurnitureTemplateRecordMapper.makeDomainTemplate(
            from: record
        )
    }

    public func save(
        _ template: FurnitureTemplate,
        at date: Date = Date()
    ) throws {
        try ensureCodeIsAvailable(
            template.code,
            excluding: template.id.rawValue
        )

        if let record = try fetchRecord(id: template.id.rawValue) {
            try FurnitureTemplateRecordMapper.update(
                record,
                from: template,
                updatedAt: date
            )
        } else {
            modelContext.insert(
                try FurnitureTemplateRecordMapper.makeRecord(
                    from: template,
                    updatedAt: date
                )
            )
        }

        try modelContext.save()
    }


    public func installCurrentSystemTemplates(
        at date: Date = Date()
    ) throws {
        try installSystemTemplates(
            [
                try SystemFurnitureTemplates.baseCabinet(),
                try SystemFurnitureTemplates.wallCabinet()
            ],
            at: date
        )
    }

    public func installSystemTemplates(
        _ templates: [FurnitureTemplate],
        at date: Date = Date()
    ) throws {
        for template in templates {
            guard template.visibility == .system else {
                continue
            }

            try ensureCodeIsAvailable(
                template.code,
                excluding: template.id.rawValue
            )

            if let record = try fetchRecord(id: template.id.rawValue) {
                try FurnitureTemplateRecordMapper.update(
                    record,
                    from: template,
                    updatedAt: date
                )
            } else {
                modelContext.insert(
                    try FurnitureTemplateRecordMapper.makeRecord(
                        from: template,
                        updatedAt: date
                    )
                )
            }
        }

        try modelContext.save()
    }

    public func count() throws -> Int {
        try modelContext.fetchCount(
            FetchDescriptor<FurnitureTemplateRecord>()
        )
    }

    private func fetchRecord(
        id: UUID
    ) throws -> FurnitureTemplateRecord? {
        let descriptor = FetchDescriptor<FurnitureTemplateRecord>(
            predicate: #Predicate { record in
                record.templateID == id
            }
        )

        return try modelContext.fetch(descriptor).first
    }

    private func ensureCodeIsAvailable(
        _ code: String,
        excluding templateID: UUID
    ) throws {
        let descriptor = FetchDescriptor<FurnitureTemplateRecord>(
            predicate: #Predicate { record in
                record.code == code && record.templateID != templateID
            }
        )

        guard try modelContext.fetch(descriptor).isEmpty else {
            throw PersistenceError.duplicateFurnitureTemplateCode(code)
        }
    }
}
