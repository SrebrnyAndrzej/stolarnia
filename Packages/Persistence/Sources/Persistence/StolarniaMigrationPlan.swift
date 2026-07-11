import SwiftData

/// Centralny plan migracji SwiftData.
/// V3 zachowuje projekty i pomieszczenia, dodając dane meblowe.
public enum StolarniaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            PersistenceSchemaV1.self,
            PersistenceSchemaV2.self,
            PersistenceSchemaV3.self
        ]
    }

    public static var stages: [MigrationStage] {
        [
            migrateV1ToV2,
            migrateV2ToV3
        ]
    }

    private static let migrateV1ToV2 = MigrationStage.lightweight(
        fromVersion: PersistenceSchemaV1.self,
        toVersion: PersistenceSchemaV2.self
    )

    private static let migrateV2ToV3 = MigrationStage.lightweight(
        fromVersion: PersistenceSchemaV2.self,
        toVersion: PersistenceSchemaV3.self
    )
}
