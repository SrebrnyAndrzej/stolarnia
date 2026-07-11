import SwiftData

public enum PersistenceController {
    /// Tworzy wspólny kontener danych całej aplikacji.
    /// `inMemory` jest używane wyłącznie w testach i podglądach SwiftUI.
    @MainActor
    public static func makeModelContainer(
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PersistenceSchemaV3.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: StolarniaMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
