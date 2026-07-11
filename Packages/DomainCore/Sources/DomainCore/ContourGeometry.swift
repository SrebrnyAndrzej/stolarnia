import Foundation

/// Odcinek prosty konturu w układzie milimetrowym.
public struct LineSegment2D: Identifiable, Codable, Hashable, Sendable {
    public let id: ContourSegmentID
    public var start: Point2MM
    public var end: Point2MM

    public init(
        id: ContourSegmentID = ContourSegmentID(),
        start: Point2MM,
        end: Point2MM
    ) throws {
        guard start != end else {
            throw DomainError.invariantViolation(
                "Odcinek konturu nie może mieć zerowej długości."
            )
        }

        self.id = id
        self.start = start
        self.end = end
    }

    public var length: Millimeters {
        let dx = end.x.rawValue - start.x.rawValue
        let dy = end.y.rawValue - start.y.rawValue
        return Millimeters(hypot(dx, dy))
    }
}

/// Łuk kołowy konturu. Kierunek określa przebieg od `start` do `end`.
public struct ArcSegment2D: Identifiable, Codable, Hashable, Sendable {
    public let id: ContourSegmentID
    public var start: Point2MM
    public var end: Point2MM
    public var center: Point2MM
    public var clockwise: Bool

    public init(
        id: ContourSegmentID = ContourSegmentID(),
        start: Point2MM,
        end: Point2MM,
        center: Point2MM,
        clockwise: Bool
    ) throws {
        let startRadius = Self.distance(from: center, to: start)
        let endRadius = Self.distance(from: center, to: end)

        guard startRadius > .zero else {
            throw DomainError.invariantViolation(
                "Promień łuku musi być większy od zera."
            )
        }

        guard abs(startRadius.rawValue - endRadius.rawValue) <= 0.01 else {
            throw DomainError.invariantViolation(
                "Punkty początku i końca łuku muszą leżeć na tym samym promieniu."
            )
        }

        guard start != end else {
            throw DomainError.invariantViolation(
                "Łuk nie może mieć identycznego punktu początku i końca."
            )
        }

        self.id = id
        self.start = start
        self.end = end
        self.center = center
        self.clockwise = clockwise
    }

    public var radius: Millimeters {
        Self.distance(from: center, to: start)
    }

    public var length: Millimeters {
        let startAngle = atan2(
            start.y.rawValue - center.y.rawValue,
            start.x.rawValue - center.x.rawValue
        )
        let endAngle = atan2(
            end.y.rawValue - center.y.rawValue,
            end.x.rawValue - center.x.rawValue
        )

        var delta = endAngle - startAngle

        if clockwise {
            if delta >= 0 {
                delta -= 2 * .pi
            }
        } else if delta <= 0 {
            delta += 2 * .pi
        }

        return Millimeters(abs(delta) * radius.rawValue)
    }

    private static func distance(
        from first: Point2MM,
        to second: Point2MM
    ) -> Millimeters {
        let dx = second.x.rawValue - first.x.rawValue
        let dy = second.y.rawValue - first.y.rawValue
        return Millimeters(hypot(dx, dy))
    }
}

/// Segment ogólnego konturu. Prostokąt jest tylko zestawem czterech linii.
public enum ContourSegment2D: Codable, Hashable, Sendable {
    case line(LineSegment2D)
    case arc(ArcSegment2D)

    public var id: ContourSegmentID {
        switch self {
        case .line(let segment): segment.id
        case .arc(let segment): segment.id
        }
    }

    public var start: Point2MM {
        switch self {
        case .line(let segment): segment.start
        case .arc(let segment): segment.start
        }
    }

    public var end: Point2MM {
        switch self {
        case .line(let segment): segment.end
        case .arc(let segment): segment.end
        }
    }

    public var length: Millimeters {
        switch self {
        case .line(let segment): segment.length
        case .arc(let segment): segment.length
        }
    }
}

/// Zamknięty kontur używany przez pomieszczenia, wnęki, przeszkody
/// oraz później przez nietypowe formatki meblowe.
public struct ClosedContour2D: Codable, Hashable, Sendable {
    public let segments: [ContourSegment2D]

    public init(
        segments: [ContourSegment2D],
        closureTolerance: Millimeters = 0.01
    ) throws {
        guard segments.count >= 2 else {
            throw DomainError.invariantViolation(
                "Zamknięty kontur musi zawierać co najmniej dwa segmenty."
            )
        }

        let identifiers = segments.map(\.id)
        guard Set(identifiers).count == identifiers.count else {
            throw DomainError.invariantViolation(
                "Segmenty konturu muszą mieć unikalne identyfikatory."
            )
        }

        for index in segments.indices {
            let current = segments[index]
            let next = segments[(index + 1) % segments.count]

            guard Self.distance(current.end, next.start) <= closureTolerance else {
                throw DomainError.invariantViolation(
                    "Kontur nie jest ciągły lub zamknięty."
                )
            }
        }

        self.segments = segments
    }

    public var perimeter: Millimeters {
        segments.reduce(.zero) { partial, segment in
            partial + segment.length
        }
    }

    public func segment(id: ContourSegmentID) -> ContourSegment2D? {
        segments.first { $0.id == id }
    }

    public static func rectangle(
        width: Millimeters,
        height: Millimeters,
        origin: Point2MM = .zero
    ) throws -> ClosedContour2D {
        guard width > .zero, height > .zero else {
            throw DomainError.invariantViolation(
                "Wymiary prostokątnego konturu muszą być dodatnie."
            )
        }

        let p1 = origin
        let p2 = Point2MM(x: origin.x + width, y: origin.y)
        let p3 = Point2MM(x: origin.x + width, y: origin.y + height)
        let p4 = Point2MM(x: origin.x, y: origin.y + height)

        return try ClosedContour2D(
            segments: [
                .line(try LineSegment2D(start: p1, end: p2)),
                .line(try LineSegment2D(start: p2, end: p3)),
                .line(try LineSegment2D(start: p3, end: p4)),
                .line(try LineSegment2D(start: p4, end: p1))
            ]
        )
    }

    private static func distance(
        _ first: Point2MM,
        _ second: Point2MM
    ) -> Millimeters {
        let dx = second.x.rawValue - first.x.rawValue
        let dy = second.y.rawValue - first.y.rawValue
        return Millimeters(hypot(dx, dy))
    }
}
