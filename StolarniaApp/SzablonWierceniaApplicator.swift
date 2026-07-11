import Foundation

enum SzablonWierceniaApplicator {
    static func apply(
        template:
            SzablonWierceniaOkucia,
        to element:
            ElementTechnicznySzafki,
        baseYMM: Double
    ) -> [PunktWierceniaSzafki] {
        template.punkty.map {
            source in

            let x: Double
            let y: Double

            switch template.orientacja {
            case .pozioma:
                x =
                    template
                        .punktBazowyXMM
                    + source.odsunXMM
                y =
                    baseYMM
                    + template
                        .punktBazowyYMM
                    + source.odsunYMM

            case .pionowa:
                x =
                    template
                        .punktBazowyXMM
                    + source.odsunXMM
                y =
                    baseYMM
                    + template
                        .punktBazowyYMM
                    + source.odsunYMM
            }

            return PunktWierceniaSzafki(
                element:
                    element.nazwa,
                typ:
                    template.typ,
                strona:
                    template.strona,
                xMM:
                    clamp(
                        x,
                        min: 0,
                        max:
                            element
                                .szerokoscMM
                    ),
                yMM:
                    clamp(
                        y,
                        min: 0,
                        max:
                            element
                                .dlugoscMM
                    ),
                srednicaMM:
                    source.srednicaMM,
                glebokoscMM:
                    source.glebokoscMM,
                opis:
                    [
                        template.nazwa,
                        template.kodOkucia,
                        source.opis
                    ]
                    .filter {
                        !$0.isEmpty
                    }
                    .joined(
                        separator: " • "
                    )
            )
        }
    }

    private static func clamp(
        _ value: Double,
        min minimum: Double,
        max maximum: Double
    ) -> Double {
        Swift.min(
            Swift.max(
                value,
                minimum
            ),
            maximum
        )
    }
}
