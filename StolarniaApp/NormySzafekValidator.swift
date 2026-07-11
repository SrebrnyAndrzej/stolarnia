import Foundation

enum NormySzafekValidator {
    static func validate(
        norma:
            NormaSzafki,
        widthMM: Double,
        heightMM: Double,
        depthMM: Double,
        frontHeightMM: Double?
            = nil
    ) -> [WynikWalidacjiNormySzafki] {
        var results:
            [WynikWalidacjiNormySzafki] = []

        if !norma.glebokoscMM
            .contains(depthMM) {
            results.append(
                WynikWalidacjiNormySzafki(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Głębokość \(format(depthMM)) mm jest poza zakresem \(format(norma.glebokoscMM.minimum))–\(format(norma.glebokoscMM.maximum)) mm."
                )
            )
        }

        if !norma.wysokoscKorpusuMM
            .contains(heightMM) {
            results.append(
                WynikWalidacjiNormySzafki(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Wysokość \(format(heightMM)) mm jest poza zakresem \(format(norma.wysokoscKorpusuMM.minimum))–\(format(norma.wysokoscKorpusuMM.maximum)) mm."
                )
            )
        }

        if !norma.typoweSzerokosciMM
            .isEmpty
            && !norma.typoweSzerokosciMM
                .contains(widthMM) {
            results.append(
                WynikWalidacjiNormySzafki(
                    poziom:
                        .informacja,
                    komunikat:
                        "Szerokość niestandardowa. Typowe: \(norma.typoweSzerokosciMM.map(format).joined(separator: ", ")) mm."
                )
            )
        }

        if let frontHeightMM,
           frontHeightMM > 900 {
            results.append(
                WynikWalidacjiNormySzafki(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Front powyżej 900 mm wymaga ostrzeżenia o możliwości wygięcia i rozważenia napinacza."
                )
            )
        }

        if results.isEmpty {
            results.append(
                WynikWalidacjiNormySzafki(
                    poziom:
                        .informacja,
                    komunikat:
                        "Wymiary mieszczą się w normie wybranego typu szafki."
                )
            )
        }

        return results
    }

    static func nearestWidth(
        to value: Double,
        in norma:
            NormaSzafki
    ) -> Double {
        norma.typoweSzerokosciMM
            .min {
                abs($0 - value)
                < abs($1 - value)
            }
        ?? value
    }

    private static func format(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }
}
