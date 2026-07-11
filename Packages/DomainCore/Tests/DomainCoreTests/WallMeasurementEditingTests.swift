import Testing
@testable import DomainCore

struct WallMeasurementEditingTests {
    @Test
    func updatePreservesStableWallAndSegmentIDs() throws {
        var room = try RoomDefinitionFactory.makeRectangularRoom(
            projectID: ProjectID(),
            name: "Kuchnia",
            width: 4000,
            depth: 3000,
            wallHeight: 2600,
            wallThickness: 120,
            constructionType: .masonry
        )

        let originalWall = try #require(room.geometry.walls.first)
        let originalSegmentID = originalWall.contourSegmentID

        try room.applyWallMeasurementUpdate(
            WallMeasurementUpdate(
                wallID: originalWall.id,
                name: "Ściana A po pomiarze",
                length: 3987,
                thickness: 125,
                startHeight: 2598,
                endHeight: 2604,
                constructionType: .concrete,
                notes: "Pomiar z palca"
            )
        )

        let updatedWall = try #require(
            room.geometry.wall(id: originalWall.id)
        )

        #expect(updatedWall.id == originalWall.id)
        #expect(updatedWall.contourSegmentID == originalSegmentID)
        #expect(updatedWall.name == "Ściana A po pomiarze")
        #expect(updatedWall.thickness == 125)
        #expect(updatedWall.startHeight == 2598)
        #expect(updatedWall.endHeight == 2604)
        #expect(updatedWall.constructionType == .concrete)
        #expect(room.geometry.geometry(of: originalWall.id)?.length == 3987)
    }

    @Test
    func changingLengthKeepsContourClosedAndMovesNextSegmentStart() throws {
        var room = try RoomDefinitionFactory.makeRectangularRoom(
            projectID: ProjectID(),
            name: "Pomieszczenie",
            width: 4000,
            depth: 3000,
            wallHeight: 2600,
            wallThickness: 120,
            constructionType: .masonry
        )

        let firstWall = room.geometry.walls[0]
        let nextWall = room.geometry.walls[1]

        try room.applyWallMeasurementUpdate(
            WallMeasurementUpdate(
                wallID: firstWall.id,
                name: firstWall.name,
                length: 3900,
                thickness: firstWall.thickness,
                startHeight: firstWall.startHeight,
                endHeight: firstWall.endHeight,
                constructionType: firstWall.constructionType,
                notes: firstWall.notes
            )
        )

        let firstSegment = try #require(
            room.geometry.geometry(of: firstWall.id)
        )
        let nextSegment = try #require(
            room.geometry.geometry(of: nextWall.id)
        )

        #expect(firstSegment.end == nextSegment.start)
        #expect(firstSegment.length == 3900)
        #expect(room.geometry.boundary.segments.last?.end
            == room.geometry.boundary.segments.first?.start)
    }

    @Test
    func rejectsNonPositiveMeasurement() throws {
        var room = try RoomDefinitionFactory.makeRectangularRoom(
            projectID: ProjectID(),
            name: "Pomieszczenie",
            width: 4000,
            depth: 3000,
            wallHeight: 2600,
            wallThickness: 120,
            constructionType: .masonry
        )

        let wall = room.geometry.walls[0]

        #expect(throws: DomainError.self) {
            try room.applyWallMeasurementUpdate(
                WallMeasurementUpdate(
                    wallID: wall.id,
                    name: wall.name,
                    length: 0,
                    thickness: wall.thickness,
                    startHeight: wall.startHeight,
                    endHeight: wall.endHeight,
                    constructionType: wall.constructionType,
                    notes: wall.notes
                )
            )
        }
    }
}
