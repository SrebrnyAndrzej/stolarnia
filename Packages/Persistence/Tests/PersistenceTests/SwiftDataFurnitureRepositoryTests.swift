import DomainCore
import Foundation
import Persistence
import SwiftData
import Testing

@MainActor
struct SwiftDataFurnitureRepositoryTests {
    @Test
    func systemTemplatesPersistWithStableIdentifiers() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let repository = SwiftDataFurnitureTemplateRepository(modelContainer: container)
        try await repository.installCurrentSystemTemplates(
            at: fixedDate(1)
        )

        let restored = try await repository.fetchAll()

        #expect(restored.count == 2)
        #expect(restored.map(\.id).contains(SystemFurnitureTemplates.baseCabinetID))
        #expect(restored.map(\.id).contains(SystemFurnitureTemplates.wallCabinetID))
        #expect(try await repository.count() == 2)
    }

    @Test
    func assemblyPersistsWithParametersPlacementAndStableComponentIDs() async throws {
        let context = try await makePreparedContext(code: "PRJ-FURN-0001")
        let template = try SystemFurnitureTemplates.baseCabinet()
        let overrides = try FurnitureParameterSet(entries: [
            .init(key: .width, value: .millimeters(800))
        ])
        let stored = try makeStoredAssembly(
            room: context.room,
            template: template,
            overrides: overrides,
            createdAt: fixedDate(2)
        )

        try await context.assemblyRepository.save(stored)
        let restored = try await context.assemblyRepository.fetch(id: stored.id)

        #expect(restored == stored)
        #expect(restored?.assembly.id == stored.assembly.id)
        #expect(restored?.assembly.components.map(\.id) == stored.assembly.components.map(\.id))
        #expect(restored?.assembly.placement?.wallID == context.room.geometry.walls[0].id)
        #expect(
            restored?.parameters.value(for: .width)
                == FurnitureParameterValue.millimeters(800)
        )
        #expect(try await context.assemblyRepository.count(roomID: context.room.id) == 1)
    }

    @Test
    func savingRebuiltAssemblyUpdatesInsteadOfDuplicating() async throws {
        let context = try await makePreparedContext(code: "PRJ-FURN-0002")
        let template = try SystemFurnitureTemplates.baseCabinet()
        let original = try makeStoredAssembly(
            room: context.room,
            template: template,
            overrides: FurnitureParameterSet(),
            createdAt: fixedDate(3)
        )
        try await context.assemblyRepository.save(original)

        let newOverrides = try FurnitureParameterSet(entries: [
            .init(key: .width, value: .millimeters(900))
        ])
        let rebuiltAssembly = try BaseCabinetBuilder().build(
            template: template,
            parameters: newOverrides,
            preservingIDsFrom: original.assembly
        )
        let rebuilt = try attachPlacement(
            to: rebuiltAssembly,
            room: context.room,
            preserving: original.assembly.placement
        )
        let updated = StoredFurnitureAssembly(
            roomID: context.room.id,
            assembly: rebuilt,
            parameters: try template.resolvedParameters(overrides: newOverrides),
            createdAt: original.createdAt,
            updatedAt: fixedDate(4)
        )

        try await context.assemblyRepository.save(updated)
        let fetched = try await context.assemblyRepository.fetch(id: original.id)
        let restored = try #require(fetched)

        #expect(try await context.assemblyRepository.count(roomID: context.room.id) == 1)
        #expect(restored.assembly.id == original.assembly.id)
        #expect(restored.assembly.component(code: "BOK-L")?.id == original.assembly.component(code: "BOK-L")?.id)
        #expect(restored.assembly.size.width == 900)
        #expect(restored.updatedAt == fixedDate(4))
    }

    @Test
    func furnitureRunPersistsAndReferencesModulesFromSameRoom() async throws {
        let context = try await makePreparedContext(code: "PRJ-FURN-0003")
        let template = try SystemFurnitureTemplates.baseCabinet()
        let stored = try makeStoredAssembly(
            room: context.room,
            template: template,
            overrides: FurnitureParameterSet(),
            createdAt: fixedDate(5)
        )
        try await context.assemblyRepository.save(stored)

        let run = try FurnitureRun(
            roomID: context.room.id,
            wallID: context.room.geometry.walls[0].id,
            name: "Ciąg dolny A",
            kind: .base,
            startOffset: 50,
            endOffset: 50,
            moduleIDs: [stored.id],
            technology: try CabinetRunTechnology(
                leftEnd: .overlaySideAndExtendedTop,
                rightEnd: .filler
            )
        )

        try await context.runRepository.save(run, at: fixedDate(6))
        let restored = try await context.runRepository.fetch(id: run.id)

        #expect(restored == run)
        #expect(try await context.runRepository.count(roomID: context.room.id) == 1)
    }

    @Test
    func runRejectsReferenceToMissingModule() async throws {
        let context = try await makePreparedContext(code: "PRJ-FURN-0004")
        let missingID = FurnitureAssemblyID()
        let run = try FurnitureRun(
            roomID: context.room.id,
            wallID: context.room.geometry.walls[0].id,
            name: "Niepoprawny ciąg",
            kind: .base,
            startOffset: 0,
            endOffset: 0,
            moduleIDs: [missingID],
            technology: try CabinetRunTechnology()
        )

        await #expect(throws: PersistenceError.self) {
            try await context.runRepository.save(run)
        }
    }

    @Test
    func assemblyCannotBeSavedWithoutExistingRoom() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let templateRepository = SwiftDataFurnitureTemplateRepository(modelContainer: container)
        let assemblyRepository = SwiftDataFurnitureAssemblyRepository(modelContainer: container)
        let template = try SystemFurnitureTemplates.baseCabinet()
        try await templateRepository.save(template)

        let assembly = try BaseCabinetBuilder().build(template: template)
        let stored = StoredFurnitureAssembly(
            roomID: RoomID(),
            assembly: assembly,
            parameters: FurnitureParameterSet()
        )

        await #expect(throws: PersistenceError.self) {
            try await assemblyRepository.save(stored)
        }
    }

    @Test
    func deletingAssemblyRemovesItsIdentifierFromRun() async throws {
        let context = try await makePreparedContext(code: "PRJ-FURN-0005")
        let template = try SystemFurnitureTemplates.baseCabinet()
        let stored = try makeStoredAssembly(
            room: context.room,
            template: template,
            overrides: FurnitureParameterSet(),
            createdAt: fixedDate(7)
        )
        try await context.assemblyRepository.save(stored)

        let run = try FurnitureRun(
            roomID: context.room.id,
            wallID: context.room.geometry.walls[0].id,
            name: "Ciąg do aktualizacji",
            kind: .base,
            startOffset: 0,
            endOffset: 0,
            moduleIDs: [stored.id],
            technology: try CabinetRunTechnology()
        )
        try await context.runRepository.save(run)

        try await context.assemblyRepository.delete(
            id: stored.id,
            at: fixedDate(8)
        )
        let fetchedRun = try await context.runRepository.fetch(id: run.id)
        let restoredRun = try #require(fetchedRun)

        #expect(restoredRun.moduleIDs.isEmpty)
        #expect(try await context.assemblyRepository.count(roomID: context.room.id) == 0)
    }

    @Test
    func deletingRoomAlsoDeletesAssembliesAndRuns() async throws {
        let context = try await makePreparedContext(code: "PRJ-FURN-0006")
        let template = try SystemFurnitureTemplates.baseCabinet()
        let stored = try makeStoredAssembly(
            room: context.room,
            template: template,
            overrides: FurnitureParameterSet(),
            createdAt: fixedDate(9)
        )
        try await context.assemblyRepository.save(stored)

        let run = try FurnitureRun(
            roomID: context.room.id,
            wallID: context.room.geometry.walls[0].id,
            name: "Ciąg kasowany z pomieszczeniem",
            kind: .base,
            startOffset: 0,
            endOffset: 0,
            moduleIDs: [stored.id],
            technology: try CabinetRunTechnology()
        )
        try await context.runRepository.save(run)

        try await context.roomRepository.delete(id: context.room.id)

        #expect(try await context.assemblyRepository.count(roomID: context.room.id) == 0)
        #expect(try await context.runRepository.count(roomID: context.room.id) == 0)
    }

    private struct PreparedContext {
        let room: RoomDefinition
        let roomRepository: SwiftDataRoomRepository
        let assemblyRepository: SwiftDataFurnitureAssemblyRepository
        let runRepository: SwiftDataFurnitureRunRepository
    }

    private func makePreparedContext(
        code: String
    ) async throws -> PreparedContext {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let projectRepository = SwiftDataProjectRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let templateRepository = SwiftDataFurnitureTemplateRepository(modelContainer: container)
        let assemblyRepository = SwiftDataFurnitureAssemblyRepository(modelContainer: container)
        let runRepository = SwiftDataFurnitureRunRepository(modelContainer: container)

        let project = try WorkshopProject(
            code: ProjectCode(code),
            name: "Projekt meblowy",
            customer: Customer(displayName: "Klient testowy")
        )
        let room = try RoomDefinitionFactory.makeRectangularRoom(
            projectID: project.id,
            name: "Kuchnia",
            width: 4_000,
            depth: 3_000,
            wallHeight: 2_600,
            wallThickness: 120,
            createdAt: fixedDate(0)
        )

        try await projectRepository.save(project)
        try await roomRepository.save(room)
        try await templateRepository.installCurrentSystemTemplates()

        return PreparedContext(
            room: room,
            roomRepository: roomRepository,
            assemblyRepository: assemblyRepository,
            runRepository: runRepository
        )
    }

    private func makeStoredAssembly(
        room: RoomDefinition,
        template: FurnitureTemplate,
        overrides: FurnitureParameterSet,
        createdAt: Date
    ) throws -> StoredFurnitureAssembly {
        let built = try BaseCabinetBuilder().build(
            template: template,
            parameters: overrides
        )
        let placed = try attachPlacement(
            to: built,
            room: room,
            preserving: nil
        )

        return StoredFurnitureAssembly(
            roomID: room.id,
            assembly: placed,
            parameters: try template.resolvedParameters(overrides: overrides),
            createdAt: createdAt
        )
    }

    private func attachPlacement(
        to assembly: FurnitureAssembly,
        room: RoomDefinition,
        preserving existingPlacement: FurniturePlacement?
    ) throws -> FurnitureAssembly {
        let placement: FurniturePlacement

        if let existingPlacement {
            placement = existingPlacement
        } else {
            placement = try FurniturePlacement(
                roomID: room.id,
                wallID: room.geometry.walls[0].id,
                assemblyID: assembly.id,
                offsetAlongWall: 100,
                anchoringMode: .floorStanding
            )
        }

        return try FurnitureAssembly(
            id: assembly.id,
            templateID: assembly.templateID,
            name: assembly.name,
            kind: assembly.kind,
            size: assembly.size,
            components: assembly.components,
            subassemblies: assembly.subassemblies,
            constraints: assembly.constraints,
            placement: placement
        )
    }

    private func fixedDate(
        _ offset: TimeInterval
    ) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + offset)
    }
}
