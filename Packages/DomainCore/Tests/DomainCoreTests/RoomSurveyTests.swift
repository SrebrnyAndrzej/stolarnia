import Testing
@testable import DomainCore

struct RoomSurveyTests {
    @Test
    func guidedSurveyCreatesNonRectangularClosedRoom() throws {
        var session = try RoomSurveySession(
            projectID: ProjectID(),
            roomName: "Wykusz",
            wallHeight: 2600,
            wallThickness: 120
        )

        try session.appendSegment(length: 2000, turnAfterSegment: .right90)
        try session.appendSegment(length: 500, turnAfterSegment: .left90)
        try session.appendSegment(length: 800, turnAfterSegment: .left90)
        try session.appendSegment(length: 500, turnAfterSegment: .right90)
        try session.appendSegment(length: 2000, turnAfterSegment: .right90)
        try session.appendSegment(length: 3000, turnAfterSegment: .right90)

        let room = try session.completeRoom()

        #expect(room.geometry.walls.count >= 6)
        #expect(room.geometry.boundary.segments.count == room.geometry.walls.count)
        #expect(session.state == .completed)
    }

    @Test
    func rightTurnChangesHeadingClockwise() throws {
        var session = try RoomSurveySession(
            projectID: ProjectID(),
            roomName: "Test",
            wallHeight: 2500,
            wallThickness: 100
        )

        try session.appendSegment(length: 1000, turnAfterSegment: .right90)
        try session.appendSegment(length: 500, turnAfterSegment: .straight)

        #expect(session.measuredSegments[0].end == Point2MM(x: 1000, y: 0))
        #expect(abs(session.measuredSegments[1].end.y.rawValue + 500) < 0.001)
    }

    @Test
    func explicitClosingSegmentCanBeMeasuredAsOwnWall() throws {
        var session = try RoomSurveySession(
            projectID: ProjectID(),
            roomName: "Nieregularne",
            wallHeight: 2600,
            wallThickness: 120
        )

        try session.appendSegment(length: 2200, turnAfterSegment: .right90)
        try session.appendSegment(length: 1800, turnAfterSegment: .right90)
        try session.appendSegment(length: 900, turnAfterSegment: .left90)

        try session.appendClosingSegment()

        #expect(session.measuredSegments.count == 4)
        #expect(session.closureDistance.rawValue < 0.001)

        let room = try session.completeRoom()

        #expect(room.geometry.walls.count == 4)
        #expect(room.geometry.boundary.segments.count == 4)
    }

    @Test
    func undoKeepsHeadingForReplacementSegment() throws {
        var session = try RoomSurveySession(
            projectID: ProjectID(),
            roomName: "Korekta",
            wallHeight: 2500,
            wallThickness: 100
        )

        try session.appendSegment(length: 1000, turnAfterSegment: .right90)
        try session.appendSegment(length: 500, turnAfterSegment: .left90)
        session.removeLastSegment()
        try session.appendSegment(length: 700, turnAfterSegment: .straight)

        #expect(abs(session.measuredSegments[1].end.x.rawValue - 1000) < 0.001)
        #expect(abs(session.measuredSegments[1].end.y.rawValue + 700) < 0.001)
    }
}
