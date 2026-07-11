import Foundation
import SwiftData

/// Pierwsza zamrożona wersja schematu trwałych danych aplikacji.
/// Nazwy modelu i zapisanych pól nie mogą być zmieniane bez migracji.
public enum PersistenceSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [ProjectRecord.self]
    }

    @Model
    public final class ProjectRecord {
        public var projectID: UUID
        public var code: String
        public var name: String
        public var customerID: UUID
        public var customerDisplayName: String
        public var statusRawValue: String
        public var pricingTierRawValue: String
        public var revisionNumber: Int
        public var revisionStageRawValue: String
        public var visibilityRawValue: String
        public var createdAt: Date
        public var updatedAt: Date
        public var payloadSchemaVersion: Int
        public var domainPayload: Data

        public init(
            projectID: UUID,
            code: String,
            name: String,
            customerID: UUID,
            customerDisplayName: String,
            statusRawValue: String,
            pricingTierRawValue: String,
            revisionNumber: Int,
            revisionStageRawValue: String,
            visibilityRawValue: String,
            createdAt: Date,
            updatedAt: Date,
            payloadSchemaVersion: Int,
            domainPayload: Data
        ) {
            self.projectID = projectID
            self.code = code
            self.name = name
            self.customerID = customerID
            self.customerDisplayName = customerDisplayName
            self.statusRawValue = statusRawValue
            self.pricingTierRawValue = pricingTierRawValue
            self.revisionNumber = revisionNumber
            self.revisionStageRawValue = revisionStageRawValue
            self.visibilityRawValue = visibilityRawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.payloadSchemaVersion = payloadSchemaVersion
            self.domainPayload = domainPayload
        }
    }
}

public typealias ProjectRecord = PersistenceSchemaV1.ProjectRecord
