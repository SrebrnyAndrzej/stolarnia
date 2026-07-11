import Foundation
import SwiftData

/// Trzecia, niezmienna wersja schematu trwałych danych.
/// Dodaje szablony mebli, instancje modułów i ciągi meblowe.
public enum PersistenceSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            PersistenceSchemaV1.ProjectRecord.self,
            PersistenceSchemaV2.RoomRecord.self,
            FurnitureTemplateRecord.self,
            FurnitureAssemblyRecord.self,
            FurnitureRunRecord.self
        ]
    }

    @Model
    public final class FurnitureTemplateRecord {
        public var templateID: UUID
        public var code: String
        public var name: String
        public var categoryRawValue: String
        public var visibilityRawValue: String
        public var builderTypeRawValue: String
        public var parameterCount: Int
        public var updatedAt: Date
        public var payloadSchemaVersion: Int
        public var domainPayload: Data

        public init(
            templateID: UUID,
            code: String,
            name: String,
            categoryRawValue: String,
            visibilityRawValue: String,
            builderTypeRawValue: String,
            parameterCount: Int,
            updatedAt: Date,
            payloadSchemaVersion: Int,
            domainPayload: Data
        ) {
            self.templateID = templateID
            self.code = code
            self.name = name
            self.categoryRawValue = categoryRawValue
            self.visibilityRawValue = visibilityRawValue
            self.builderTypeRawValue = builderTypeRawValue
            self.parameterCount = parameterCount
            self.updatedAt = updatedAt
            self.payloadSchemaVersion = payloadSchemaVersion
            self.domainPayload = domainPayload
        }
    }

    @Model
    public final class FurnitureAssemblyRecord {
        public var assemblyID: UUID
        public var roomID: UUID
        public var wallID: UUID?
        public var templateID: UUID?
        public var placementID: UUID?
        public var name: String
        public var kindRawValue: String
        public var width: Double
        public var height: Double
        public var depth: Double
        public var componentCount: Int
        public var parameterCount: Int
        public var createdAt: Date
        public var updatedAt: Date
        public var payloadSchemaVersion: Int
        public var domainPayload: Data

        public init(
            assemblyID: UUID,
            roomID: UUID,
            wallID: UUID?,
            templateID: UUID?,
            placementID: UUID?,
            name: String,
            kindRawValue: String,
            width: Double,
            height: Double,
            depth: Double,
            componentCount: Int,
            parameterCount: Int,
            createdAt: Date,
            updatedAt: Date,
            payloadSchemaVersion: Int,
            domainPayload: Data
        ) {
            self.assemblyID = assemblyID
            self.roomID = roomID
            self.wallID = wallID
            self.templateID = templateID
            self.placementID = placementID
            self.name = name
            self.kindRawValue = kindRawValue
            self.width = width
            self.height = height
            self.depth = depth
            self.componentCount = componentCount
            self.parameterCount = parameterCount
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.payloadSchemaVersion = payloadSchemaVersion
            self.domainPayload = domainPayload
        }
    }

    @Model
    public final class FurnitureRunRecord {
        public var runID: UUID
        public var roomID: UUID
        public var wallID: UUID
        public var name: String
        public var kindRawValue: String
        public var moduleCount: Int
        public var createdAt: Date
        public var updatedAt: Date
        public var payloadSchemaVersion: Int
        public var domainPayload: Data

        public init(
            runID: UUID,
            roomID: UUID,
            wallID: UUID,
            name: String,
            kindRawValue: String,
            moduleCount: Int,
            createdAt: Date,
            updatedAt: Date,
            payloadSchemaVersion: Int,
            domainPayload: Data
        ) {
            self.runID = runID
            self.roomID = roomID
            self.wallID = wallID
            self.name = name
            self.kindRawValue = kindRawValue
            self.moduleCount = moduleCount
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.payloadSchemaVersion = payloadSchemaVersion
            self.domainPayload = domainPayload
        }
    }
}

public typealias FurnitureTemplateRecord = PersistenceSchemaV3.FurnitureTemplateRecord
public typealias FurnitureAssemblyRecord = PersistenceSchemaV3.FurnitureAssemblyRecord
public typealias FurnitureRunRecord = PersistenceSchemaV3.FurnitureRunRecord
