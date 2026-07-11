import DomainCore
import Persistence
import SwiftData
import Testing

@MainActor
struct SwiftDataProjectRepositoryTests {
    @Test
    func projectPersistsAndKeepsStableIdentifier() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let repository = SwiftDataProjectRepository(modelContainer: container)
        let project = try makeProject(code: "PRJ-TEST-0001")

        try await repository.save(project)
        let restored = try await repository.fetch(id: project.id)

        #expect(restored == project)
        #expect(restored?.id == project.id)
        #expect(try await repository.count() == 1)
    }

    @Test
    func savingExistingProjectUpdatesInsteadOfDuplicating() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let repository = SwiftDataProjectRepository(modelContainer: container)
        var project = try makeProject(code: "PRJ-TEST-0002")

        try await repository.save(project)
        project.updateStatus(.designing)
        try await repository.save(project)

        let projects = try await repository.fetchAll()

        #expect(projects.count == 1)
        #expect(projects.first?.status == .designing)
        #expect(projects.first?.id == project.id)
    }

    @Test
    func duplicateProjectCodeIsRejected() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let repository = SwiftDataProjectRepository(modelContainer: container)

        try await repository.save(
            try makeProject(code: "PRJ-TEST-0003")
        )

        await #expect(throws: PersistenceError.self) {
            try await repository.save(
                try makeProject(code: "PRJ-TEST-0003")
            )
        }
    }

    private func makeProject(
        code: String
    ) throws -> WorkshopProject {
        try WorkshopProject(
            code: ProjectCode(code),
            name: "Projekt testowy",
            customer: Customer(displayName: "Klient testowy")
        )
    }
}
