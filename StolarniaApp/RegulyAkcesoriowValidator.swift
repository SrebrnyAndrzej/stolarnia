import Foundation

enum RegulyAkcesoriowValidator {
    static func validate(
        profil:
            ProfilAkcesoriumMeblowego,
        instancja:
            InstancjaAkcesoriumSzafki,
        karta:
            KartaTechnicznaSzafki
    ) -> [WynikWalidacjiAkcesorium] {
        var results:
            [WynikWalidacjiAkcesorium] = []

        validateValue(
            instancja.gruboscDnaMM,
            rule:
                profil.regulaGrubosciDna,
            label:
                "Grubość dna",
            into:
                &results
        )

        validateValue(
            instancja.gruboscTyluMM,
            rule:
                profil.regulaGrubosciTylu,
            label:
                "Grubość tyłu",
            into:
                &results
        )

        validateValue(
            instancja.gruboscBokuMM,
            rule:
                profil.regulaGrubosciBoku,
            label:
                "Grubość boku",
            into:
                &results
        )

        if !profil
            .dozwoloneDlugosciMM
            .isEmpty {
            guard let length =
                    instancja
                        .nominalnaDlugoscMM
            else {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "Wybierz nominalną długość."
                    )
                )
                return results
            }

            if !profil
                .dozwoloneDlugosciMM
                .contains(
                    where: {
                        abs($0 - length)
                        < 0.01
                    }
                ) {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "Długość \(format(length)) mm nie występuje w tym profilu."
                    )
                )
            }

            let minimumDepth =
                length
                + (
                    profil
                        .formulaSzuflady?
                        .zapasGlebokosciKorpusuMM
                    ?? 0
                )

            if karta.glebokoscMM
                < minimumDepth {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "Korpus ma \(format(karta.glebokoscMM)) mm głębokości, a system wymaga co najmniej \(format(minimumDepth)) mm."
                    )
                )
            }

            let innerWidth =
                max(
                    karta.szerokoscMM
                    - instancja
                        .gruboscKorpusuMM
                    * 2,
                    0
                )

            if profil
                .wymagaSynchronizatoraGdySzerokoscPrzekraczaDlugosc,
               innerWidth > length {
                results.append(
                    .init(
                        poziom:
                            .ostrzezenie,
                        komunikat:
                            "Wewnętrzna szerokość \(format(innerWidth)) mm przekracza długość prowadnicy \(format(length)) mm. Zastosuj synchronizator."
                    )
                )
            }
        }

        if !profil
            .dozwoloneWysokosciMM
            .isEmpty,
           let height =
                instancja
                    .wariantWysokosciMM,
           !profil
                .dozwoloneWysokosciMM
                .contains(
                    where: {
                        abs($0 - height)
                        < 0.01
                    }
                ) {
            results.append(
                .init(
                    poziom: .blad,
                    komunikat:
                        "Wybrana wysokość nie występuje w tym profilu."
                )
            )
        }

        if let minimumHeight =
                profil
                    .minimalnaWysokoscKorpusuMM,
           karta.wysokoscMM
                < minimumHeight {
            results.append(
                .init(
                    poziom: .blad,
                    komunikat:
                        "Korpus jest niższy niż wymagane \(format(minimumHeight)) mm."
                )
            )
        }

        if let minimumDepth =
                profil
                    .minimalnaGlebokoscSwiatlaMM,
           karta.glebokoscMM
                < minimumDepth {
            results.append(
                .init(
                    poziom: .blad,
                    komunikat:
                        "Dostępna głębokość jest mniejsza niż wymagane \(format(minimumDepth)) mm."
                )
            )
        }

        if let maxLoad =
                profil
                    .maksymalneObciazenieKG,
           let load =
                instancja
                    .masaObciazeniaKG,
           load > maxLoad {
            results.append(
                .init(
                    poziom: .blad,
                    komunikat:
                        "Planowane obciążenie \(format(load)) kg przekracza limit \(format(maxLoad)) kg."
                )
            )
        }

        if let minimumArea =
                profil
                    .minimalnaPowierzchniaWentylacjiCM2 {
            guard let area =
                    instancja
                        .powierzchniaWentylacjiCM2
            else {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "Podaj czynny przekrój wentylacji."
                    )
                )
                return results
            }

            if area < minimumArea {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "Czynny przekrój \(format(area)) cm² jest mniejszy niż wymagane \(format(minimumArea)) cm²."
                    )
                )
            }
        }

        if let threshold =
                profil
                    .progRelinguDlaFrontuMM,
           let frontHeight =
                instancja
                    .wysokoscFrontuMM,
           frontHeight > threshold {
            results.append(
                .init(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Front ma więcej niż \(format(threshold)) mm. Profil zaleca dodatkowy reling."
                )
            )
        }

        if profil.status
            == .wymagaPotwierdzenia {
            results.append(
                .init(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "Profil wymaga potwierdzenia z aktualną kartą techniczną konkretnego indeksu."
                )
            )
        }

        if results.isEmpty {
            results.append(
                .init(
                    poziom:
                        .informacja,
                    komunikat:
                        "Konfiguracja jest zgodna z zapisanymi regułami profilu."
                )
            )
        }

        return results
    }

    static func dimensions(
        profil:
            ProfilAkcesoriumMeblowego,
        instancja:
            InstancjaAkcesoriumSzafki,
        karta:
            KartaTechnicznaSzafki
    ) -> WynikWymiarowaniaSzuflady? {
        guard let formula =
                profil.formulaSzuflady
        else {
            return nil
        }

        let innerWidth =
            max(
                karta.szerokoscMM
                - instancja
                    .gruboscKorpusuMM
                * 2,
                0
            )

        let length =
            instancja.nominalnaDlugoscMM

        return WynikWymiarowaniaSzuflady(
            szerokoscWewnetrznaKorpusuMM:
                innerWidth,
            szerokoscDnaMM:
                formula
                    .redukcjaSzerokosciDnaMM
                    .map {
                        max(
                            innerWidth - $0,
                            0
                        )
                    },
            dlugoscDnaMM:
                calculatedDifference(
                    base: length,
                    reduction:
                        formula
                            .redukcjaDlugosciDnaMM
                ),
            szerokoscTyluMM:
                formula
                    .redukcjaSzerokosciTyluMM
                    .map {
                        max(
                            innerWidth - $0,
                            0
                        )
                    },
            dlugoscSynchronizatoraMM:
                formula
                    .redukcjaSynchronizatoraMM
                    .map {
                        max(
                            innerWidth - $0,
                            0
                        )
                    },
            minimalnaGlebokoscKorpusuMM:
                length.map {
                    $0
                    + formula
                        .zapasGlebokosciKorpusuMM
                }
        )
    }

    private static func validateValue(
        _ value: Double?,
        rule:
            RegulaGrubosciPlyty,
        label: String,
        into results:
            inout [
                WynikWalidacjiAkcesorium
            ]
    ) {
        switch rule.tryb {
        case .brak:
            return

        case .wymagaPotwierdzenia:
            results.append(
                .init(
                    poziom:
                        .ostrzezenie,
                    komunikat:
                        "\(label): \(rule.opisSkrocony)."
                )
            )

        case .stala,
             .zakres,
             .wybor:
            guard let value else {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "Podaj wartość: \(label.lowercased())."
                    )
                )
                return
            }

            if !rule.accepts(value) {
                results.append(
                    .init(
                        poziom: .blad,
                        komunikat:
                            "\(label) \(format(value)) mm jest niezgodna z regułą \(rule.opisSkrocony)."
                    )
                )
            }
        }
    }

    private static func calculatedDifference(
        base: Double?,
        reduction: Double?
    ) -> Double? {
        guard let base,
              let reduction
        else {
            return nil
        }

        return max(
            base - reduction,
            0
        )
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
