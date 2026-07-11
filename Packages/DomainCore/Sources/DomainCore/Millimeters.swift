import Foundation

/// Jedyna bazowa jednostka długości używana przez silnik domenowy.
public struct Millimeters: Codable, Hashable, Comparable, Sendable,
    AdditiveArithmetic, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral
{
    public let rawValue: Double

    public init(_ rawValue: Double) {
        precondition(rawValue.isFinite, "Wartość Millimeters musi być skończona.")
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        self.init(Double(value))
    }

    public init(floatLiteral value: Double) {
        self.init(value)
    }

    public static let zero = Millimeters(0)

    public static func < (lhs: Millimeters, rhs: Millimeters) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func + (lhs: Millimeters, rhs: Millimeters) -> Millimeters {
        Millimeters(lhs.rawValue + rhs.rawValue)
    }

    public static func - (lhs: Millimeters, rhs: Millimeters) -> Millimeters {
        Millimeters(lhs.rawValue - rhs.rawValue)
    }

    public static prefix func - (value: Millimeters) -> Millimeters {
        Millimeters(-value.rawValue)
    }

    public static func * (lhs: Millimeters, rhs: Double) -> Millimeters {
        Millimeters(lhs.rawValue * rhs)
    }

    public static func * (lhs: Double, rhs: Millimeters) -> Millimeters {
        Millimeters(lhs * rhs.rawValue)
    }

    public static func / (lhs: Millimeters, rhs: Double) -> Millimeters {
        precondition(rhs != 0, "Nie można dzielić długości przez zero.")
        return Millimeters(lhs.rawValue / rhs)
    }

    public func ratio(to other: Millimeters) -> Double {
        precondition(other.rawValue != 0, "Nie można dzielić długości przez zero.")
        return rawValue / other.rawValue
    }

    public var meters: Double {
        rawValue / 1_000
    }

    public var isNegative: Bool {
        rawValue < 0
    }

    public var isZero: Bool {
        rawValue == 0
    }

    public func rounded(toDecimalPlaces places: Int = 3) -> Millimeters {
        precondition(places >= 0, "Liczba miejsc po przecinku nie może być ujemna.")
        let factor = pow(10, Double(places))
        return Millimeters((rawValue * factor).rounded() / factor)
    }
}

extension Millimeters: CustomStringConvertible {
    public var description: String {
        "\(rawValue) mm"
    }
}
