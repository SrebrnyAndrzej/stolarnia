import Foundation

/// Kanoniczne polecenie ręcznej edycji danych ściany.
/// Ten sam wzorzec będzie później używany dla wymiarów mebli i formatek.
public struct WallMeasurementUpdate: Codable, Hashable, Sendable {
    public let wallID: WallID
    public var name: String
    public var length: Millimeters
    public var thickness: Millimeters
    public var startHeight: Millimeters
    public var endHeight: Millimeters
    public var constructionType: ConstructionType
    public var notes: String

    public init(
        wallID: WallID,
        name: String,
        length: Millimeters,
        thickness: Millimeters,
        startHeight: Millimeters,
        endHeight: Millimeters,
        constructionType: ConstructionType,
        notes: String
    ) {
        self.wallID = wallID
        self.name = name
        self.length = length
        self.thickness = thickness
        self.startHeight = startHeight
        self.endHeight = endHeight
        self.constructionType = constructionType
        self.notes = notes
    }
}

public extension RoomDefinition {
    /// Aktualizuje ścianę bez zmiany jej `WallID` ani `ContourSegmentID`.
    ///
    /// Dla odcinka prostego zmiana długości przesuwa jego punkt końcowy
    /// wzdłuż dotychczasowego kierunku. Punkt początkowy kolejnego odcinka
    /// jest przesuwany razem z nim, aby obrys pozostał ciągły i zamknięty.
    /// Może to celowo zmienić długość sąsiedniej ściany — odpowiada to
    /// rzeczywistym, nieprostokątnym pomiarom pomieszczenia.
    mutating func applyWallMeasurementUpdate(
        _ update: WallMeasurementUpdate,
        at date: Date = Date()
    ) throws {
        let normalizedName = update.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation(
                "Nazwa ściany nie może być pusta."
            )
        }

        guard update.length > .zero else {
            throw DomainError.invalidDimension(
                field: "długość ściany",
                value: update.length.rawValue
            )
        }

        guard update.thickness > .zero else {
            throw DomainError.invalidDimension(
                field: "grubość ściany",
                value: update.thickness.rawValue
            )
        }

        guard update.startHeight > .zero, update.endHeight > .zero else {
            throw DomainError.invariantViolation(
                "Wysokości ściany muszą być dodatnie."
            )
        }

        guard let wallIndex = geometry.walls.firstIndex(
            where: { $0.id == update.wallID }
        ) else {
            throw DomainError.invariantViolation(
                "Nie znaleziono ściany wskazanej do edycji."
            )
        }

        let editedWall = geometry.walls[wallIndex]
        guard let segmentIndex = geometry.boundary.segments.firstIndex(
            where: { $0.id == editedWall.contourSegmentID }
        ) else {
            throw DomainError.invariantViolation(
                "Ściana nie ma odpowiadającego segmentu obrysu."
            )
        }

        var updatedSegments = geometry.boundary.segments
        let selectedSegment = updatedSegments[segmentIndex]

        switch selectedSegment {
        case .line(let selectedLine):
            let currentLength = selectedLine.length

            if abs(currentLength.rawValue - update.length.rawValue) > 0.001 {
                let dx = selectedLine.end.x.rawValue - selectedLine.start.x.rawValue
                let dy = selectedLine.end.y.rawValue - selectedLine.start.y.rawValue
                let magnitude = hypot(dx, dy)

                guard magnitude > 0 else {
                    throw DomainError.invariantViolation(
                        "Nie można edytować odcinka o zerowej długości."
                    )
                }

                let newEnd = Point2MM(
                    x: Millimeters(
                        selectedLine.start.x.rawValue
                        + dx / magnitude * update.length.rawValue
                    ),
                    y: Millimeters(
                        selectedLine.start.y.rawValue
                        + dy / magnitude * update.length.rawValue
                    )
                )

                updatedSegments[segmentIndex] = .line(
                    try LineSegment2D(
                        id: selectedLine.id,
                        start: selectedLine.start,
                        end: newEnd
                    )
                )

                let nextIndex = (segmentIndex + 1) % updatedSegments.count
                let nextSegment = updatedSegments[nextIndex]

                switch nextSegment {
                case .line(let nextLine):
                    updatedSegments[nextIndex] = .line(
                        try LineSegment2D(
                            id: nextLine.id,
                            start: newEnd,
                            end: nextLine.end
                        )
                    )

                case .arc:
                    throw DomainError.invariantViolation(
                        "Zmiana długości ściany bezpośrednio poprzedzającej łuk "
                        + "wymaga edytora geometrii łukowej."
                    )
                }
            }

        case .arc:
            if abs(selectedSegment.length.rawValue - update.length.rawValue) > 0.001 {
                throw DomainError.invariantViolation(
                    "Długość ściany łukowej będzie edytowana w dedykowanym "
                    + "edytorze promienia i kąta."
                )
            }
        }

        var updatedWalls = geometry.walls
        updatedWalls[wallIndex] = try WallSegment(
            id: editedWall.id,
            contourSegmentID: editedWall.contourSegmentID,
            name: normalizedName,
            thickness: update.thickness,
            startHeight: update.startHeight,
            endHeight: update.endHeight,
            constructionType: update.constructionType,
            notes: update.notes
        )

        let updatedBoundary = try ClosedContour2D(
            segments: updatedSegments
        )
        let updatedGeometry = try RoomGeometry(
            boundary: updatedBoundary,
            walls: updatedWalls
        )

        try replaceGeometry(updatedGeometry, at: date)
    }
}
