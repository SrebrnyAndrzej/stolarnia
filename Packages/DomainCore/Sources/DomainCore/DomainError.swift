import Foundation

/// Wspólne błędy fundamentu domenowego.
public enum DomainError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case invalidDimension(field: String, value: Double)
    case invalidRange(field: String, minimum: Double, maximum: Double)
    case invariantViolation(String)
}

extension DomainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let value):
            return "Nieprawidłowy identyfikator: \(value)."

        case .invalidDimension(let field, let value):
            return "Nieprawidłowy wymiar \(field): \(value) mm."

        case .invalidRange(let field, let minimum, let maximum):
            return "Nieprawidłowy zakres \(field): \(minimum)...\(maximum)."

        case .invariantViolation(let message):
            return "Naruszenie reguły domenowej: \(message)"
        }
    }
}
