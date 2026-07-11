import Foundation

/// Kierunek prowadzenia obrysu względem wejścia do pomieszczenia.
public enum RoomSurveyWinding: String, Codable, CaseIterable, Sendable {
    case clockwiseFromEntranceRight
    case counterClockwiseFromEntranceLeft
    case custom
}

/// Stan prowadzonego pomiaru pomieszczenia.
public enum RoomSurveyState: String, Codable, Sendable {
    case selectingStartPoint
    case measuringSegment
    case reviewingSegment
    case checkingClosure
    case completed
}

/// Zmiana kierunku wykonywana po zapisaniu bieżącego odcinka.
public enum SurveyTurn: Codable, Hashable, Sendable {
    case straight
    case right90
    case left90
    case custom(degrees: Double)

    public var angleDeltaDegrees: Double {
        switch self {
        case .straight: 0
        case .right90: -90
        case .left90: 90
        case .custom(let degrees): degrees
        }
    }
}

/// Odcinek zarejestrowany podczas prowadzonego pomiaru.
public struct MeasuredWallSegment: Identifiable, Codable, Hashable, Sendable {
    public let id: ContourSegmentID
    public let wallID: WallID
    public var name: String
    public var start: Point2MM
    public var end: Point2MM
    public var measuredLength: Millimeters
    public var headingDegrees: Double

    public init(
        id: ContourSegmentID = ContourSegmentID(),
        wallID: WallID = WallID(),
        name: String,
        start: Point2MM,
        end: Point2MM,
        measuredLength: Millimeters,
        headingDegrees: Double
    ) {
        self.id = id
        self.wallID = wallID
        self.name = name
        self.start = start
        self.end = end
        self.measuredLength = measuredLength
        self.headingDegrees = headingDegrees
    }
}

/// Sesja budująca rzeczywisty obrys ściana po ścianie.
/// Domyślnie zaczynamy po prawej stronie wejścia i poruszamy się zgodnie z ruchem wskazówek zegara.
public struct RoomSurveySession: Codable, Hashable, Sendable {
    public let projectID: ProjectID
    public var roomName: String
    public var winding: RoomSurveyWinding
    public var startPoint: Point2MM
    public private(set) var currentPoint: Point2MM
    public private(set) var currentHeadingDegrees: Double
    public private(set) var measuredSegments: [MeasuredWallSegment]
    public private(set) var state: RoomSurveyState

    public var wallHeight: Millimeters
    public var wallThickness: Millimeters
    public var constructionType: ConstructionType

    public init(
        projectID: ProjectID,
        roomName: String,
        winding: RoomSurveyWinding = .clockwiseFromEntranceRight,
        startPoint: Point2MM = .zero,
        initialHeadingDegrees: Double = 0,
        wallHeight: Millimeters,
        wallThickness: Millimeters,
        constructionType: ConstructionType = .unknown
    ) throws {
        let normalizedName = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa pomieszczenia nie może być pusta.")
        }
        guard wallHeight > .zero, wallThickness > .zero else {
            throw DomainError.invariantViolation("Wysokość i grubość ściany muszą być dodatnie.")
        }

        self.projectID = projectID
        self.roomName = normalizedName
        self.winding = winding
        self.startPoint = startPoint
        self.currentPoint = startPoint
        self.currentHeadingDegrees = initialHeadingDegrees
        self.measuredSegments = []
        self.state = .measuringSegment
        self.wallHeight = wallHeight
        self.wallThickness = wallThickness
        self.constructionType = constructionType
    }

    public mutating func appendSegment(
        length: Millimeters,
        turnAfterSegment: SurveyTurn
    ) throws {
        guard state != .completed else {
            throw DomainError.invariantViolation("Zakończonej sesji pomiarowej nie można edytować.")
        }
        guard length > .zero else {
            throw DomainError.invariantViolation("Długość ściany musi być dodatnia.")
        }

        let radians = currentHeadingDegrees * .pi / 180
        let end = Point2MM(
            x: currentPoint.x + Millimeters(cos(radians) * length.rawValue),
            y: currentPoint.y + Millimeters(sin(radians) * length.rawValue)
        )
        let index = measuredSegments.count
        let segment = MeasuredWallSegment(
            name: Self.wallName(index: index),
            start: currentPoint,
            end: end,
            measuredLength: length,
            headingDegrees: currentHeadingDegrees
        )
        measuredSegments.append(segment)
        currentPoint = end
        currentHeadingDegrees = Self.normalizedAngle(
            currentHeadingDegrees + turnAfterSegment.angleDeltaDegrees
        )
        state = .reviewingSegment
    }

    public mutating func removeLastSegment() {
        guard state != .completed, !measuredSegments.isEmpty else { return }
        let removedSegment = measuredSegments.removeLast()
        currentPoint = measuredSegments.last?.end ?? startPoint
        currentHeadingDegrees = measuredSegments.isEmpty
            ? 0
            : Self.normalizedAngle(removedSegment.headingDegrees)
        state = .measuringSegment
    }

    /// Dopisuje jawny odcinek domykający do punktu startowego.
    /// Dzięki temu ostatnia ściana może dostać własne cechy terenowe
    /// zamiast pojawiać się dopiero automatycznie przy zapisie.
    public mutating func appendClosingSegment(
        minimumLength: Millimeters = 2
    ) throws {
        guard state != .completed else {
            throw DomainError.invariantViolation("Zakończonej sesji pomiarowej nie można edytować.")
        }
        guard measuredSegments.count >= 2 else {
            throw DomainError.invariantViolation(
                "Do domknięcia obrysu potrzebne są co najmniej dwa zmierzone odcinki."
            )
        }

        let length = closureDistance
        guard length > minimumLength else {
            throw DomainError.invariantViolation(
                "Obrys jest już domknięty w tolerancji."
            )
        }

        let heading = atan2(
            startPoint.y.rawValue - currentPoint.y.rawValue,
            startPoint.x.rawValue - currentPoint.x.rawValue
        ) * 180 / .pi

        let segment = MeasuredWallSegment(
            name: Self.wallName(index: measuredSegments.count),
            start: currentPoint,
            end: startPoint,
            measuredLength: length,
            headingDegrees: Self.normalizedAngle(heading)
        )
        measuredSegments.append(segment)
        currentPoint = startPoint
        currentHeadingDegrees = Self.normalizedAngle(heading)
        state = .reviewingSegment
    }

    public var closureVector: Vector2MM {
        Vector2MM(
            dx: startPoint.x - currentPoint.x,
            dy: startPoint.y - currentPoint.y
        )
    }

    public var closureDistance: Millimeters {
        Millimeters(hypot(closureVector.dx.rawValue, closureVector.dy.rawValue))
    }

    /// Tworzy zamknięte pomieszczenie. Brakujący odcinek do punktu P0 jest dodawany jako ostatnia ściana.
    public mutating func completeRoom(
        id: RoomID = RoomID(),
        closureTolerance: Millimeters = 2,
        createdAt: Date = Date()
    ) throws -> RoomDefinition {
        guard measuredSegments.count >= 2 else {
            throw DomainError.invariantViolation(
                "Do zamknięcia obrysu potrzebne są co najmniej dwa zmierzone odcinki."
            )
        }

        state = .checkingClosure
        var finalSegments = measuredSegments

        if closureDistance > closureTolerance {
            let closingLength = closureDistance
            finalSegments.append(
                MeasuredWallSegment(
                    name: Self.wallName(index: finalSegments.count),
                    start: currentPoint,
                    end: startPoint,
                    measuredLength: closingLength,
                    headingDegrees: atan2(
                        startPoint.y.rawValue - currentPoint.y.rawValue,
                        startPoint.x.rawValue - currentPoint.x.rawValue
                    ) * 180 / .pi
                )
            )
        } else if let last = finalSegments.last {
            var corrected = last
            corrected.end = startPoint
            corrected.measuredLength = try LineSegment2D(
                id: corrected.id,
                start: corrected.start,
                end: startPoint
            ).length
            finalSegments[finalSegments.count - 1] = corrected
        }

        let contourSegments: [ContourSegment2D] = try finalSegments.map { measured in
            .line(
                try LineSegment2D(
                    id: measured.id,
                    start: measured.start,
                    end: measured.end
                )
            )
        }
        let boundary = try ClosedContour2D(segments: contourSegments)
        let walls = try finalSegments.map { measured in
            try WallSegment(
                id: measured.wallID,
                contourSegmentID: measured.id,
                name: measured.name,
                thickness: wallThickness,
                startHeight: wallHeight,
                constructionType: constructionType
            )
        }
        let geometry = try RoomGeometry(boundary: boundary, walls: walls)
        state = .completed

        return try RoomDefinition(
            id: id,
            projectID: projectID,
            name: roomName,
            geometry: geometry,
            createdAt: createdAt
        )
    }

    private static func wallName(index: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        if index < alphabet.count {
            return "Ściana \(alphabet[index])"
        }
        return "Ściana \(index + 1)"
    }

    private static func normalizedAngle(_ degrees: Double) -> Double {
        var result = degrees.truncatingRemainder(dividingBy: 360)
        if result < -180 { result += 360 }
        if result > 180 { result -= 360 }
        return result
    }
}
