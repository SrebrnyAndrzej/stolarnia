import Foundation

enum SilnikWycenyWariantowej {
    static func oblicz(
        projekt: ProjektWyceny,
        ustawienia:
            UstawieniaStolarni,
        materialy:
            [MaterialStolarski],
        okucia:
            [OkucieMeblowe] = []
    ) -> [PodsumowanieWariantuWyceny] {
        WariantWyceny.allCases.map {
            oblicz(
                wariant: $0,
                projekt: projekt,
                ustawienia: ustawienia,
                materialy: materialy,
                okucia: okucia
            )
        }
    }

    static func oblicz(
        wariant:
            WariantWyceny,
        projekt: ProjektWyceny,
        ustawienia:
            UstawieniaStolarni,
        materialy:
            [MaterialStolarski],
        okucia:
            [OkucieMeblowe] = []
    ) -> PodsumowanieWariantuWyceny {
        let aktywne =
            materialy.filter(\.aktywny)

        let wybranaPlyta =
            DoborMaterialowWyceny.plyta(
                wariant: wariant,
                materialy: aktywne
            )

        let wybranyFront =
            DoborMaterialowWyceny.front(
                wariant: wariant,
                materialy: aktywne
            )

        let wybranyBlat =
            DoborMaterialowWyceny.blat(
                wariant: wariant,
                materialy: aktywne
            )

        let pozycjeOkuc:
            [PozycjaKosztowaWyceny]

        if projekt
            .okuciaV068
            .isEmpty {
            let dobraneOkucia =
                AutomatycznyDoborOkuc
                    .dobierz(
                        projekt: projekt,
                        wariant: wariant,
                        baza: okucia
                    )

            pozycjeOkuc =
                dobraneOkucia.map {
                    selection in

                    return PozycjaKosztowaWyceny(
                        nazwa:
                            selection
                                .nazwaPozycji,
                        kategoria:
                            selection.typ
                                == .wkręt
                            || selection.typ
                                == .klej
                            ? .akcesoria
                            : .okucia,
                        ilosc:
                            selection.ilosc,
                        jednostka:
                            selection.jednostka,
                        cenaJednostkowaNetto:
                            selection
                                .cenaJednostkowaNetto,
                        uwagi:
                            selection.uwagi
                    )
                }
        } else {
            pozycjeOkuc =
                projekt
                    .okuciaV068
                    .map {
                        hardware in

                        let name =
                            [
                                hardware
                                    .producent,
                                hardware
                                    .rodzina,
                                hardware
                                    .model
                            ]
                            .filter {
                                !$0.isEmpty
                            }
                            .joined(
                                separator: " • "
                            )

                        let brakCeny =
                            hardware.cenaJednostkowaNetto <= 0
                        let note =
                            brakCeny
                            ? "Okucie bez ceny — uzupełnij cennik w Bazie Okuć."
                            : "Dokładne okucie zapisane w karcie technicznej. Źródło ceny: \(hardware.zrodlo)."

                        return PozycjaKosztowaWyceny(
                            nazwa:
                                name.isEmpty
                                ? hardware
                                    .profilID
                                : name,
                            kategoria:
                                .okucia,
                            ilosc:
                                hardware.ilosc,
                            jednostka:
                                hardware.jednostka,
                            cenaJednostkowaNetto:
                                hardware
                                    .cenaJednostkowaNetto,
                            uwagi:
                                note,
                            jestBledemWyceny:
                                brakCeny
                        )
                    }
        }

        let pozycjeMaterialoweV068 =
            pozycjeMaterialoweV068(
                projekt: projekt,
                materialy: aktywne,
                fallbackPlyta:
                    wybranaPlyta,
                fallbackFront:
                    wybranyFront
            )

        let pozycjeBazowe:
            [PozycjaKosztowaWyceny] =
                pozycjeMaterialoweV068
                + [
            PozycjaKosztowaWyceny(
                nazwa: "Blat",
                kategoria: .blaty,
                ilosc:
                    projekt.metryBiezaceBlatu,
                jednostka: "mb",
                cenaJednostkowaNetto:
                    wybranyBlat.cenaJednostkowaNetto,
                uwagi:
                    "\(opisBlatu(wariant)) \(wybranyBlat.opis)"
            ),
            PozycjaKosztowaWyceny(
                nazwa: "Produkcja",
                kategoria: .robocizna,
                ilosc:
                    projekt.liczbaGodzinProdukcji,
                jednostka: "h",
                cenaJednostkowaNetto:
                    ustawienia
                        .finanse
                        .stawkaRoboczogodziny
                    * wariant.mnoznikRobocizny,
                uwagi: ""
            ),
            PozycjaKosztowaWyceny(
                nazwa: "Montaż",
                kategoria: .montaz,
                ilosc:
                    projekt.liczbaGodzinMontazu,
                jednostka: "h",
                cenaJednostkowaNetto:
                    ustawienia
                        .finanse
                        .kosztMontazuZaGodzine
                    * wariant.mnoznikRobocizny,
                uwagi: ""
            ),
            PozycjaKosztowaWyceny(
                nazwa: "Transport",
                kategoria: .transport,
                ilosc:
                    Double(
                        max(
                            projekt.liczbaTransportow,
                            1
                        )
                    ),
                jednostka: "kurs",
                cenaJednostkowaNetto:
                    ustawienia
                        .finanse
                        .kosztTransportuBazowy,
                uwagi: ""
            )
        ]

        let pozycje =
            pozycjeBazowe
            + pozycjeOkuc

        let kosztBazowy =
            pozycje.reduce(0) {
                $0 + $1.kosztNetto
            }

        let zapas =
            kosztBazowy
            * ustawienia
                .finanse
                .zapasKosztowyProcent
            / 100

        let narzut =
            (
                kosztBazowy
                + zapas
            )
            * ustawienia
                .finanse
                .narzutProcent
            / 100

        let bazaPoNarzucie =
            kosztBazowy
            + zapas
            + narzut

        let marza =
            bazaPoNarzucie
            * ustawienia
                .finanse
                .marzaProcent
            / 100

        let cenaNetto =
            max(
                bazaPoNarzucie
                + marza,
                ustawienia
                    .finanse
                    .minimalnaWartoscZlecenia
            )

        let vat =
            cenaNetto
            * ustawienia
                .finanse
                .vatProcent
            / 100

        return PodsumowanieWariantuWyceny(
            wariant: wariant,
            pozycje: pozycje,
            kosztBazowyNetto:
                kosztBazowy,
            narzutKwota: narzut,
            marzaKwota: marza,
            zapasKosztowyKwota:
                zapas,
            cenaNetto: cenaNetto,
            vatKwota: vat,
            cenaBrutto:
                cenaNetto + vat
        )
    }

    private static func pozycjeMaterialoweV068(
        projekt:
            ProjektWyceny,
        materialy:
            [MaterialStolarski],
        fallbackPlyta:
            WybranyMaterialWyceny,
        fallbackFront:
            WybranyMaterialWyceny
    ) -> [PozycjaKosztowaWyceny] {
        guard !projekt
            .uzyciaMaterialowV068
            .isEmpty
        else {
            let warning =
                projekt
                    .ostrzezeniaV068
                    .joined(
                        separator: " "
                    )

            return [
                PozycjaKosztowaWyceny(
                    nazwa:
                        "Płyty korpusowe",
                    kategoria:
                        .plyty,
                    ilosc:
                        projekt
                            .powierzchniaPlytM2,
                    jednostka:
                        "m²",
                    cenaJednostkowaNetto:
                        fallbackPlyta
                            .cenaJednostkowaNetto,
                    uwagi:
                        [
                            fallbackPlyta.opis,
                            warning
                        ]
                        .filter {
                            !$0.isEmpty
                        }
                        .joined(
                            separator: " "
                        )
                ),
                PozycjaKosztowaWyceny(
                    nazwa:
                        "Fronty",
                    kategoria:
                        .fronty,
                    ilosc:
                        projekt
                            .powierzchniaFrontowM2,
                    jednostka:
                        "m²",
                    cenaJednostkowaNetto:
                        fallbackFront
                            .cenaJednostkowaNetto,
                    uwagi:
                        fallbackFront.opis
                )
            ]
        }

        var result:
            [PozycjaKosztowaWyceny] = []

        for usage in projekt
            .uzyciaMaterialowV068 {
            let selected =
                DoborMaterialowWyceny
                    .dokladnyMaterialV068(
                        id:
                            usage
                                .materialID,
                        materialy:
                            materialy
                    )

            let category:
                KategoriaKosztuWyceny
            let roleName: String

            switch usage.rola {
            case .korpus:
                category = .plyty
                roleName =
                    "Płyta korpusowa"
            case .front:
                category = .fronty
                roleName =
                    "Front"
            }

            let itemName =
                selected.material
                    .map {
                        let code =
                            $0.kodProducenta
                            ?? $0.kod
                        return "\(roleName) • \($0.producent) \(code)"
                    }
                ?? "\(roleName) • brak rekordu"

            let note: String
            let jestBlad: Bool
            switch selected.zrodlo {
            case "material-id":
                note =
                    "Dokładny materiał z projektu: \(selected.opis)."
                jestBlad = false
            case "brak-ceny":
                note =
                    "Materiał bez ceny — uzupełnij cennik."
                jestBlad = true
            case "material-nieaktywny":
                note =
                    "Materiał nieaktywny w bazie — reaktywuj go lub zmień."
                jestBlad = true
            default:
                note =
                    "Nie znaleziono materiału (ID: \(usage.materialID.uuidString.lowercased()))."
                jestBlad = true
            }

            result.append(
                PozycjaKosztowaWyceny(
                    nazwa:
                        itemName,
                    kategoria:
                        category,
                    ilosc:
                        usage.iloscM2,
                    jednostka:
                        "m²",
                    cenaJednostkowaNetto:
                        selected
                            .cenaJednostkowaNetto,
                    uwagi:
                        note,
                    jestBledemWyceny:
                        jestBlad
                )
            )
        }

        if !projekt
            .ostrzezeniaV068
            .isEmpty,
           !result.isEmpty {
            result[0].uwagi +=
                " "
                + projekt
                    .ostrzezeniaV068
                    .joined(
                        separator: " "
                    )
        }

        return result
    }

    private static func materialCenaM2(
        typy:
            [TypMaterialuStolarskiego],
        materialy:
            [MaterialStolarski],
        fallback: Double
    ) -> Double {
        let values =
            materialy
                .filter {
                    typy.contains($0.typ)
                }
                .compactMap(
                    \.cenaZaM2Netto
                )
                .filter {
                    $0 > 0
                }

        guard !values.isEmpty else {
            return fallback
        }

        return values.reduce(0, +)
            / Double(values.count)
    }

    private static func materialCenaJednostkowa(
        typy:
            [TypMaterialuStolarskiego],
        materialy:
            [MaterialStolarski],
        fallback: Double
    ) -> Double {
        let values =
            materialy
                .filter {
                    typy.contains($0.typ)
                }
                .map(
                    \.cenaPoRabacieNetto
                )
                .filter {
                    $0 > 0
                }

        guard !values.isEmpty else {
            return fallback
        }

        return values.reduce(0, +)
            / Double(values.count)
    }

    private static func blatTypes(
        for wariant:
            WariantWyceny
    ) -> [TypMaterialuStolarskiego] {
        switch wariant {
        case .eco,
             .standard:
            return [
                .blatLaminowany
            ]
        case .premium:
            return [
                .blatKompaktowy,
                .blatLaminowany
            ]
        case .vip:
            return [
                .blatKamienny,
                .blatKompaktowy
            ]
        }
    }

    private static func opisOkuc(
        _ wariant:
            WariantWyceny
    ) -> String {
        switch wariant {
        case .eco:
            return "Podstawowe systemy GTV lub równoważne."
        case .standard:
            return "GTV premium / Blum podstawowy."
        case .premium:
            return "Blum Merivobox, Tandembox lub równoważne."
        case .vip:
            return "Blum Legrabox i systemy najwyższej klasy."
        }
    }

    private static func opisBlatu(
        _ wariant:
            WariantWyceny
    ) -> String {
        switch wariant {
        case .eco:
            return "Podstawowy blat laminowany."
        case .standard:
            return "Blat laminowany wyższej klasy."
        case .premium:
            return "Blat kompaktowy lub HPL."
        case .vip:
            return "Kamień, spiek lub blat premium."
        }
    }
}
