/// Punkt na płaszczyźnie w układzie milimetrowym.
public struct Point2MM: Codable, Hashable, Sendable {
    public var x: Millimeters
    public var y: Millimeters

    public init(x: Millimeters, y: Millimeters) {
        self.x = x
        self.y = y
    }

    public static let zero = Point2MM(x: .zero, y: .zero)
}

/// Punkt w przestrzeni w układzie milimetrowym.
public struct Point3MM: Codable, Hashable, Sendable {
    public var x: Millimeters
    public var y: Millimeters
    public var z: Millimeters

    public init(x: Millimeters, y: Millimeters, z: Millimeters) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Point3MM(x: .zero, y: .zero, z: .zero)
}

/// Wektor 2D używany do przesunięć i obliczeń geometrycznych.
public struct Vector2MM: Codable, Hashable, Sendable {
    public var dx: Millimeters
    public var dy: Millimeters

    public init(dx: Millimeters, dy: Millimeters) {
        self.dx = dx
        self.dy = dy
    }

    public static let zero = Vector2MM(dx: .zero, dy: .zero)
}

/// Gabaryt 2D. Walidator domenowy odpowiada za sprawdzenie dodatnich wartości.
public struct Size2MM: Codable, Hashable, Sendable {
    public var width: Millimeters
    public var height: Millimeters

    public init(width: Millimeters, height: Millimeters) {
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        width > .zero && height > .zero
    }
}

/// Gabaryt 3D. Kolejność pól jest stała: szerokość, wysokość, głębokość.
public struct Size3MM: Codable, Hashable, Sendable {
    public var width: Millimeters
    public var height: Millimeters
    public var depth: Millimeters

    public init(
        width: Millimeters,
        height: Millimeters,
        depth: Millimeters
    ) {
        self.width = width
        self.height = height
        self.depth = depth
    }

    public var isValid: Bool {
        width > .zero && height > .zero && depth > .zero
    }
}

public extension Point2MM {
    static func + (lhs: Point2MM, rhs: Vector2MM) -> Point2MM {
        Point2MM(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    static func - (lhs: Point2MM, rhs: Point2MM) -> Vector2MM {
        Vector2MM(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}
