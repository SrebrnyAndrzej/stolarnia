import Foundation

enum System32Generator {
    static func generate(
        for element:
            ElementTechnicznySzafki,
        parameters:
            ParametrySystemu32
    ) -> [PunktWierceniaSzafki] {
        guard parameters.aktywny,
              element.typ
                == .scianaBoczna
                || element.typ
                    == .sciankaMaskujaca
        else {
            return []
        }

        let usableLength =
            max(
                element.dlugoscMM
                - parameters.poczatekYMM
                - parameters.koniecOdGoryMM,
                0
            )

        guard parameters.skokMM > 0,
              usableLength >= 0
        else {
            return []
        }

        let count =
            Int(
                floor(
                    usableLength
                    / parameters.skokMM
                )
            ) + 1

        guard count > 0 else {
            return []
        }

        var result:
            [PunktWierceniaSzafki] = []

        if parameters.generujRzadPrzedni {
            result.append(
                contentsOf:
                    makeRow(
                        side:
                            .przedni,
                        element:
                            element,
                        parameters:
                            parameters,
                        count:
                            count,
                        omitted:
                            parameters
                                .pominieteIndeksyPrzednie
                    )
            )
        }

        if parameters.generujRzadTylny {
            result.append(
                contentsOf:
                    makeRow(
                        side:
                            .tylny,
                        element:
                            element,
                        parameters:
                            parameters,
                        count:
                            count,
                        omitted:
                            parameters
                                .pominieteIndeksyTylne
                    )
            )
        }

        return result
    }

    static func validate(
        element:
            ElementTechnicznySzafki,
        parameters:
            ParametrySystemu32
    ) -> [WynikWalidacjiSystemu32] {
        var messages:
            [WynikWalidacjiSystemu32] = []

        guard parameters.aktywny else {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom: .informacja,
                    komunikat:
                        "System 32 jest wyłączony dla tego elementu."
                )
            )
            return messages
        }

        if parameters.skokMM <= 0 {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom: .blad,
                    komunikat:
                        "Skok systemu musi być większy od 0 mm."
                )
            )
        } else if parameters.skokMM
                    .truncatingRemainder(
                        dividingBy: 32
                    )
                    != 0
                    && parameters.skokMM != 32 {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Skok różni się od bazowych 32 mm."
                )
            )
        }

        if parameters.srednicaMM != 5 {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Średnica bazowego otworu Systemu 32 zwykle wynosi 5 mm."
                )
            )
        }

        if parameters.poczatekYMM
            + parameters.koniecOdGoryMM
            > element.dlugoscMM {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom: .blad,
                    komunikat:
                        "Zakres otworowania jest większy niż długość elementu."
                )
            )
        }

        let front =
            parameters
                .efektywnyOdsunPrzodMM
        let rear =
            parameters
                .efektywnyOdsunTylMM

        if front < 0
            || front > element.szerokoscMM {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom: .blad,
                    komunikat:
                        "Przedni rząd wypada poza elementem."
                )
            )
        }

        if rear < 0
            || rear > element.szerokoscMM {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom: .blad,
                    komunikat:
                        "Tylny rząd wypada poza elementem."
                )
            )
        }

        if parameters.generujRzadPrzedni
            && parameters.generujRzadTylny
            && front + rear
                >= element.szerokoscMM {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Przedni i tylny rząd nachodzą na siebie lub pozostawiają zbyt małe światło."
                )
            )
        }

        if parameters.glebokoscMM
            >= element.gruboscMM {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Głębokość wiercenia jest równa lub większa od grubości elementu."
                )
            )
        }

        if parameters.kompensacjaObrzeza
            != .brak
            && parameters.gruboscObrzezaPrzodMM
                == 0
            && parameters.gruboscObrzezaTylMM
                == 0 {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom:
                        .informacja,
                    komunikat:
                        "Włączono kompensację obrzeża, ale jego grubość wynosi 0 mm."
                )
            )
        }

        if messages.isEmpty {
            messages.append(
                WynikWalidacjiSystemu32(
                    poziom: .informacja,
                    komunikat:
                        "Parametry Systemu 32 są poprawne."
                )
            )
        }

        return messages
    }

    private static func makeRow(
        side:
            StronaRzeduSystemu32,
        element:
            ElementTechnicznySzafki,
        parameters:
            ParametrySystemu32,
        count: Int,
        omitted: Set<Int>
    ) -> [PunktWierceniaSzafki] {
        let isRightSide =
            element.nazwa
                .localizedCaseInsensitiveContains(
                    "praw"
                )

        let baseX: Double

        switch side {
        case .przedni:
            let raw =
                parameters
                    .efektywnyOdsunPrzodMM

            if isRightSide
                && parameters
                    .lustrzaneOdbiciePrawegoBoku {
                baseX =
                    element.szerokoscMM
                    - raw
            } else {
                baseX = raw
            }

        case .tylny:
            let raw =
                parameters
                    .efektywnyOdsunTylMM

            if isRightSide
                && parameters
                    .lustrzaneOdbiciePrawegoBoku {
                baseX = raw
            } else {
                baseX =
                    element.szerokoscMM
                    - raw
            }
        }

        return (0..<count)
            .filter {
                !omitted.contains($0)
            }
            .map { index in
                let y =
                    parameters.poczatekYMM
                    + Double(index)
                    * parameters.skokMM

                return PunktWierceniaSzafki(
                    element:
                        element.nazwa,
                    typ:
                        .podporaPolki,
                    strona:
                        .wewnetrzna,
                    xMM:
                        max(
                            min(
                                baseX,
                                element
                                    .szerokoscMM
                            ),
                            0
                        ),
                    yMM:
                        max(
                            min(
                                y,
                                element
                                    .dlugoscMM
                            ),
                            0
                        ),
                    srednicaMM:
                        parameters.srednicaMM,
                    glebokoscMM:
                        parameters.glebokoscMM,
                    opis:
                        "System 32 • rząd \(side.kod) • indeks \(index) • skok \(parameters.skokMM.formatted(.number.precision(.fractionLength(0...1)))) mm"
                )
            }
    }
}
