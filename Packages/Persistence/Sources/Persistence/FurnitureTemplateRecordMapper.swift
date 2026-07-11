import DomainCore
import Foundation

/// Jedyne przejście między `FurnitureTemplate` a rekordem SwiftData.
public enum FurnitureTemplateRecordMapper {
    public static let payloadSchemaVersion = 1

    public static func makeRecord(
        from template: FurnitureTemplate,
        updatedAt: Date
    ) throws -> FurnitureTemplateRecord {
        FurnitureTemplateRecord(
            templateID: template.id.rawValue,
            code: template.code,
            name: template.name,
            categoryRawValue: template.category.rawValue,
            visibilityRawValue: template.visibility.rawValue,
            builderTypeRawValue: template.builderType.rawValue,
            parameterCount: template.supportedParameters.count,
            updatedAt: updatedAt,
            payloadSchemaVersion: payloadSchemaVersion,
            domainPayload: try encode(template)
        )
    }

    public static func update(
        _ record: FurnitureTemplateRecord,
        from template: FurnitureTemplate,
        updatedAt: Date
    ) throws {
        record.templateID = template.id.rawValue
        record.code = template.code
        record.name = template.name
        record.categoryRawValue = template.category.rawValue
        record.visibilityRawValue = template.visibility.rawValue
        record.builderTypeRawValue = template.builderType.rawValue
        record.parameterCount = template.supportedParameters.count
        record.updatedAt = updatedAt
        record.payloadSchemaVersion = payloadSchemaVersion
        record.domainPayload = try encode(template)
    }

    public static func makeDomainTemplate(
        from record: FurnitureTemplateRecord
    ) throws -> FurnitureTemplate {
        guard record.payloadSchemaVersion == payloadSchemaVersion else {
            throw PersistenceError.corruptedFurnitureTemplatePayload(
                record.templateID.uuidString.lowercased()
            )
        }

        do {
            return try decoder.decode(
                FurnitureTemplate.self,
                from: record.domainPayload
            )
        } catch {
            throw PersistenceError.corruptedFurnitureTemplatePayload(
                record.templateID.uuidString.lowercased()
            )
        }
    }

    private static func encode(
        _ template: FurnitureTemplate
    ) throws -> Data {
        try encoder.encode(template)
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
