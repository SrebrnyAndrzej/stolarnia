import Testing
@testable import DomainCore

struct RoomDefinitionFactoryTests {
    @Test
    func createsRectangularRoomWithFourStableWalls() throws {
        let projectID = ProjectID()

        let room = try RoomDefinitionFactory.makeRectangularRoom(
            projectID: projectID,
            name: "Kuchnia",
            width: 4_000,
            depth: 3_000,
            wallHeight: 2_600,
            wallThickness: 120,
            constructionType: .masonry
        )

        #expect(room.projectID == projectID)
        #expect(room.name == "Kuchnia")
        #expect(room.geometry.boundary.segments.count == 4)
        #expect(room.geometry.walls.count == 4)
        #expect(room.geometry.boundary.perimeter == Millimeters(14_000))
        #expect(room.geometry.walls.map(\.name) == [
            "Ściana A",
            "Ściana B",
            "Ściana C",
            "Ściana D"
        ])
        #expect(room.geometry.walls.allSatisfy { $0.startHeight == 2_600 })
        #expect(room.geometry.walls.allSatisfy { $0.thickness == 120 })
        #expect(room.geometry.walls.allSatisfy { $0.constructionType == .masonry })
    }

    @Test
    func rejectsInvalidRectangularDimensions() {
        #expect(throws: Error.self) {
            try RoomDefinitionFactory.makeRectangularRoom(
                projectID: ProjectID(),
                name: "Błędne pomieszczenie",
                width: 0,
                depth: 3_000,
                wallHeight: 2_600,
                wallThickness: 120
            )
        }
    }
}
