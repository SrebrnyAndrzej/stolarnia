import Foundation
import Testing
@testable import DomainCore

struct RoomGeometryTests {
    @Test
    func roomGeometryMapsEveryBoundarySegmentToOneWall() throws {
        let geometry = try makeRoomGeometry()

        #expect(geometry.walls.count == 4)
        #expect(geometry.boundary.perimeter == Millimeters(10_000))
        #expect(geometry.geometry(of: geometry.walls[0].id) != nil)
    }

    @Test
    func missingWallForBoundarySegmentIsRejected() throws {
        let contour = try ClosedContour2D.rectangle(width: 3_000, height: 2_000)
        let firstThree = try contour.segments.prefix(3).enumerated().map { index, segment in
            try WallSegment(
                contourSegmentID: segment.id,
                name: "Ściana \(index + 1)",
                thickness: 120,
                startHeight: 2_500
            )
        }

        #expect(throws: DomainError.self) {
            try RoomGeometry(boundary: contour, walls: firstThree)
        }
    }

    @Test
    func roomRejectsOpeningAssignedToUnknownWall() throws {
        let geometry = try makeRoomGeometry()
        let placement = try WallOpeningPlacement(
            wallID: WallID(),
            offsetFromWallStart: 300,
            bottomOffset: 900,
            width: 1_200,
            height: 1_400
        )
        let window = try WindowDefinition(
            placement: placement,
            openingType: .tiltAndTurn
        )

        #expect(throws: DomainError.self) {
            try RoomDefinition(
                projectID: ProjectID(),
                name: "Kuchnia",
                geometry: geometry,
                windows: [window]
            )
        }
    }

    @Test
    func roomWithWindowDoorRecessAndObstacleRoundTripsThroughJSON() throws {
        let geometry = try makeRoomGeometry()
        let wall = geometry.walls[0]

        let windowPlacement = try WallOpeningPlacement(
            wallID: wall.id,
            offsetFromWallStart: 400,
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
            sillProjection: 40
        )

        let doorPlacement = try WallOpeningPlacement(
            wallID: geometry.walls[1].id,
            offsetFromWallStart: 200,
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
            wallID: geometry.walls[2].id,
            name: "Wnęka GK",
            openingContour: ClosedContour2D.rectangle(width: 800, height: 1_700),
            depth: 170,
            constructionType: .drywall
        )

        let obstacle = try ObstacleDefinition(
            type: .drywallHousing,
            name: "Zabudowa pionu",
            footprint: ClosedContour2D.rectangle(width: 300, height: 450),
            height: 2_500,
            constructionType: .drywall
        )

        let room = try RoomDefinition(
            projectID: ProjectID(),
            name: "Kuchnia",
            geometry: geometry,
            windows: [window],
            doors: [door],
            recesses: [recess],
            obstacles: [obstacle]
        )

        let data = try JSONEncoder().encode(room)
        let decoded = try JSONDecoder().decode(RoomDefinition.self, from: data)

        #expect(decoded == room)
    }

    private func makeRoomGeometry() throws -> RoomGeometry {
        let contour = try ClosedContour2D.rectangle(width: 3_000, height: 2_000)
        let walls = try contour.segments.enumerated().map { index, segment in
            try WallSegment(
                contourSegmentID: segment.id,
                name: "Ściana \(index + 1)",
                thickness: 120,
                startHeight: 2_500,
                constructionType: .masonry
            )
        }

        return try RoomGeometry(boundary: contour, walls: walls)
    }
}
