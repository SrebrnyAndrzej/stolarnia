import DomainCore
import Foundation

/// Mapper stanowi jedyne przejście między modelem domenowym a SwiftData.
/// SwiftUI ani DomainCore nie powinny tworzyć `ProjectRecord` bezpośrednio.
public enum ProjectRecordMapper {
    public static let payloadSchemaVersion = 1

    public static func makeRecord(
        from project: WorkshopProject
    ) throws -> ProjectRecord {
        ProjectRecord(
            projectID: project.id.rawValue,
            code: project.code.rawValue,
            name: project.name,
            customerID: project.customer.id.rawValue,
            customerDisplayName: project.customer.displayName,
            statusRawValue: project.status.rawValue,
            pricingTierRawValue: project.selectedPricingTier.rawValue,
            revisionNumber: project.currentRevision.number.rawValue,
            revisionStageRawValue: project.currentRevision.stage.rawValue,
            visibilityRawValue: project.protectionPolicy.visibility.rawValue,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            payloadSchemaVersion: payloadSchemaVersion,
            domainPayload: try encode(project)
        )
    }

    public static func update(
        _ record: ProjectRecord,
        from project: WorkshopProject
    ) throws {
        record.projectID = project.id.rawValue
        record.code = project.code.rawValue
        record.name = project.name
        record.customerID = project.customer.id.rawValue
        record.customerDisplayName = project.customer.displayName
        record.statusRawValue = project.status.rawValue
        record.pricingTierRawValue = project.selectedPricingTier.rawValue
        record.revisionNumber = project.currentRevision.number.rawValue
        record.revisionStageRawValue = project.currentRevision.stage.rawValue
        record.visibilityRawValue = project.protectionPolicy.visibility.rawValue
        record.createdAt = project.createdAt
        record.updatedAt = project.updatedAt
        record.payloadSchemaVersion = payloadSchemaVersion
        record.domainPayload = try encode(project)
    }

    public static func makeDomainProject(
        from record: ProjectRecord
    ) throws -> WorkshopProject {
        guard record.payloadSchemaVersion == payloadSchemaVersion else {
            throw PersistenceError.corruptedProjectPayload(
                record.projectID.uuidString.lowercased()
            )
        }

        do {
            return try decoder.decode(
                WorkshopProject.self,
                from: record.domainPayload
            )
        } catch {
            throw PersistenceError.corruptedProjectPayload(
                record.projectID.uuidString.lowercased()
            )
        }
    }

    private static func encode(
        _ project: WorkshopProject
    ) throws -> Data {
        try encoder.encode(project)
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
