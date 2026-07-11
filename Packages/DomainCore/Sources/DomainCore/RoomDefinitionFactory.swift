import Foundation

/// Fabryka standardowych definicji pomieszczeń.
/// Tworzy poprawne modele domenowe bez przenoszenia reguł geometrii do SwiftUI.
public enum RoomDefinitionFactory {
    public static func makeRectangularRoom(
        projectID: ProjectID,
        name: String,
        width: Millimeters,
        depth: Millimeters,
        wallHeight: Millimeters,
        wallThickness: Millimeters,
        constructionType: ConstructionType = .unknown,
        createdAt: Date = Date()
    ) throws -> RoomDefinition {
        let boundary = try ClosedContour2D.rectangle(
            width: width,
            height: depth
        )

        let wallNames = [
            "Ściana A",
            "Ściana B",
            "Ściana C",
            "Ściana D"
        ]

        let walls = try zip(boundary.segments, wallNames).map { segment, wallName in
            try WallSegment(
                contourSegmentID: segment.id,
                name: wallName,
                thickness: wallThickness,
                startHeight: wallHeight,
                constructionType: constructionType
            )
        }

        let geometry = try RoomGeometry(
            boundary: boundary,
            walls: walls
        )

        return try RoomDefinition(
            projectID: projectID,
            name: name,
            geometry: geometry,
            createdAt: createdAt
        )
    }
}
