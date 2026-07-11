import DomainCore
import Foundation

/// Jedno źródło formatowania wymiarów zapisanych w `Millimeters`.
///
/// W v0.14.2 inspektor prezentował wartość 1400 mm jako „1,4 mm”,
/// ponieważ wartość była dzielona przez 1000, ale etykieta nadal miała
/// jednostkę „mm”. W inspektorze należy przekazywać surowe milimetry
/// bez dzielenia.
enum MebelWymiarFormatterV0143 {
    static func millimeters(
        _ value: Millimeters,
        maximumFractionDigits: Int = 1
    ) -> String {
        let formatted = value.rawValue.formatted(
            .number.precision(
                .fractionLength(0...max(0, maximumFractionDigits))
            )
        )
        return "\(formatted) mm"
    }

    static func meters(
        _ value: Millimeters,
        maximumFractionDigits: Int = 2
    ) -> String {
        let formatted = (value.rawValue / 1000).formatted(
            .number.precision(
                .fractionLength(0...max(0, maximumFractionDigits))
            )
        )
        return "\(formatted) m"
    }
}
