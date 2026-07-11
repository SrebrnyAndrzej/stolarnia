import DomainCore
import Persistence
import SwiftData
import Testing

@MainActor
struct SwiftDataRoomRepositoryTests {
    @Test
    func roomPersistsWithAllGeometryAndStableIdentifiers() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let projectRepository = SwiftDataProjectRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let project = try makeProject(code: "PRJ-ROOM-0001")
        let room = try makeRoom(projectID: project.id)

        try await projectRepository.save(project)
        try await roomRepository.save(room)

        let restored = try await roomRepository.fetch(id: room.id)

        #expect(restored == room)
        #expect(restored?.id == room.id)
        #expect(restored?.geometry.walls.map(\.id) == room.geometry.walls.map(\.id))
        #expect(restored?.windows.map(\.id) == room.windows.map(\.id))
        #expect(restored?.doors.map(\.id) == room.doors.map(\.id))
        #expect(restored?.recesses.map(\.id) == room.recesses.map(\.id))
        #expect(restored?.obstacles.map(\.id) == room.obstacles.map(\.id))
        #expect(restored?.wallProfiles.map(\.id) == room.wallProfiles.map(\.id))
        #expect(try await roomRepository.count(projectID: project.id) == 1)
    }

    @Test
    func savingRoomAddsItsIdentifierToParentProject() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let projectRepository = SwiftDataProjectRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let project = try makeProject(code: "PRJ-ROOM-0002")
        let room = try makeRoom(projectID: project.id)

        try await projectRepository.save(project)
        try await roomRepository.save(room)

        let restoredProject = try await projectRepository.fetch(id: project.id)

        #expect(restoredProject?.roomIDs == [room.id])
    }

    @Test
    func savingExistingRoomUpdatesInsteadOfDuplicating() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let projectRepository = SwiftDataProjectRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let project = try makeProject(code: "PRJ-ROOM-0003")
        var room = try makeRoom(projectID: project.id)

        try await projectRepository.save(project)
        try await roomRepository.save(room)

        room.addObstacle(
            try ObstacleDefinition(
                type: .column,
                name: "Słup dodatkowy",
                footprint: ClosedContour2D.rectangle(width: 250, height: 250),
                height: 2_500,
                constructionType: .concrete
            )
        )

        try await roomRepository.save(room)
        let rooms = try await roomRepository.fetchAll(projectID: project.id)

        #expect(rooms.count == 1)
        #expect(rooms.first?.obstacles.count == 2)
        #expect(rooms.first?.id == room.id)
    }

    @Test
    func deletingRoomRemovesItFromParentProject() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let projectRepository = SwiftDataProjectRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let project = try makeProject(code: "PRJ-ROOM-0004")
        let room = try makeRoom(projectID: project.id)

        try await projectRepository.save(project)
        try await roomRepository.save(room)
        try await roomRepository.delete(id: room.id)

        let restoredProject = try await projectRepository.fetch(id: project.id)

        #expect(restoredProject?.roomIDs.isEmpty == true)
        #expect(try await roomRepository.count(projectID: project.id) == 0)
    }

    @Test
    func deletingProjectAlsoDeletesItsRooms() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let projectRepository = SwiftDataProjectRepository(modelContainer: container)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let project = try makeProject(code: "PRJ-ROOM-0005")
        let room = try makeRoom(projectID: project.id)

        try await projectRepository.save(project)
        try await roomRepository.save(room)
        try await projectRepository.delete(id: project.id)

        #expect(try await roomRepository.count(projectID: project.id) == 0)
        #expect(try await projectRepository.fetch(id: project.id) == nil)
    }

    @Test
    func roomCannotBeSavedWithoutExistingParentProject() async throws {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        let roomRepository = SwiftDataRoomRepository(modelContainer: container)
        let room = try makeRoom(projectID: ProjectID())

        await #expect(throws: PersistenceError.self) {
            try await roomRepository.save(room)
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

    private func makeRoom(
        projectID: ProjectID
    ) throws -> RoomDefinition {
        let contour = try ClosedContour2D.rectangle(
            width: 3_600,
            height: 2_800
        )

        let walls = try contour.segments.enumerated().map { index, segment in
            try WallSegment(
                contourSegmentID: segment.id,
                name: "Ściana \(index + 1)",
                thickness: 120,
                startHeight: 2_600,
                constructionType: index == 2 ? .drywall : .masonry
            )
        }

        let geometry = try RoomGeometry(
            boundary: contour,
            walls: walls
        )

        let windowPlacement = try WallOpeningPlacement(
            wallID: walls[0].id,
            offsetFromWallStart: 450,
            bottomOffset: 850,
            width: 1_200,
            height: 1_300,
            revealDepth: 180
        )

        let window = try WindowDefinition(
            placement: windowPlacement,
            openingType: .tiltAndTurn,
            hingeSide: .right,
            sillThickness: 30,
            sillProjection: 40,
            hasRadiatorBelow: true
        )

        let doorPlacement = try WallOpeningPlacement(
            wallID: walls[1].id,
            offsetFromWallStart: 250,
            bottomOffset: 0,
            width: 900,
            height: 2_050
        )

        let door = try DoorDefinition(
            placement: doorPlacement,
            hingeSide: .left,
            openingDirection: .inward,
            frameWidth: 90,
            architraveWidth: 70
        )

        let recess = try RecessDefinition(
            wallID: walls[2].id,
            name: "Wnęka GK",
            openingContour: ClosedContour2D.rectangle(
                width: 850,
                height: 1_700
            ),
            depth: 170,
            constructionType: .drywall
        )

        let obstacle = try ObstacleDefinition(
            type: .drywallHousing,
            name: "Zabudowa pionu",
            footprint: ClosedContour2D.rectangle(
                width: 300,
                height: 450
            ),
            height: 2_500,
            constructionType: .drywall,
            requiredClearance: 20
        )

        let profile = try WallProfileDefinition(
            wallID: walls[2].id,
            name: "Profil prawej krawędzi wnęki",
            direction: .vertical,
            referenceEdge: .wallStart,
            points: [
                try WallProfilePoint(
                    distanceAlongProfile: 0,
                    offsetFromReference: -7,
                    isConfirmed: true
                ),
                try WallProfilePoint(
                    distanceAlongProfile: 850,
                    offsetFromReference: 2,
                    isConfirmed: true
                ),
                try WallProfilePoint(
                    distanceAlongProfile: 1_700,
                    offsetFromReference: 8,
                    isConfirmed: true
                )
            ],
            productionAllowance: 5,
            installationAllowance: 3,
            targetGap: 1.5
        )

        return try RoomDefinition(
            projectID: projectID,
            name: "Kuchnia",
            geometry: geometry,
            windows: [window],
            doors: [door],
            recesses: [recess],
            obstacles: [obstacle],
            wallProfiles: [profile]
        )
    }
}
