import Foundation
import Testing
@testable import DomainCore

@Test
func roomDefinitionDecodesPayloadWithoutBayProjectionField() throws {
    let room = try RoomDefinitionFactory.makeRectangularRoom(
        projectID: ProjectID(),
        name: "Kuchnia",
        width: 4_000,
        depth: 3_000,
        wallHeight: 2_600,
        wallThickness: 120
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let encoded = try encoder.encode(room)
    var object = try #require(
        JSONSerialization.jsonObject(
            with: encoded
        ) as? [String: Any]
    )
    object.removeValue(
        forKey: "bayProjectionsV016"
    )
    let legacyData = try JSONSerialization.data(
        withJSONObject: object
    )

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(
        RoomDefinition.self,
        from: legacyData
    )

    #expect(decoded.bayProjections.isEmpty)
    #expect(decoded.id == room.id)
}

@Test
func roomDefinitionStoresBayProjection() throws {
    var room = try RoomDefinitionFactory.makeRectangularRoom(
        projectID: ProjectID(),
        name: "Kuchnia",
        width: 4_000,
        depth: 3_000,
        wallHeight: 2_600,
        wallThickness: 120
    )
    let wall = try #require(
        room.geometry.walls.first
    )
    let bay = try BayProjectionDefinitionV016(
        wallID: wall.id,
        name: "Wykusz",
        offsetFromWallStart: 500,
        width: 1_200,
        height: 2_600,
        depth: 300,
        direction: .outward
    )

    try room.addBayProjection(bay)

    #expect(room.bayProjections == [bay])

    let data = try JSONEncoder().encode(room)
    let decoded = try JSONDecoder().decode(
        RoomDefinition.self,
        from: data
    )
    #expect(decoded.bayProjections == [bay])
}
