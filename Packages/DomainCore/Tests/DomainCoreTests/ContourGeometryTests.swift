import Testing
@testable import DomainCore

struct ContourGeometryTests {
    @Test
    func rectangleCreatesClosedContourWithCorrectPerimeter() throws {
        let contour = try ClosedContour2D.rectangle(width: 2_000, height: 1_000)

        #expect(contour.segments.count == 4)
        #expect(contour.perimeter == Millimeters(6_000))
    }

    @Test
    func openContourIsRejected() throws {
        let p1 = Point2MM(x: 0, y: 0)
        let p2 = Point2MM(x: 1_000, y: 0)
        let p3 = Point2MM(x: 1_000, y: 1_000)

        #expect(throws: DomainError.self) {
            try ClosedContour2D(
                segments: [
                    .line(try LineSegment2D(start: p1, end: p2)),
                    .line(try LineSegment2D(start: p2, end: p3))
                ]
            )
        }
    }
}
