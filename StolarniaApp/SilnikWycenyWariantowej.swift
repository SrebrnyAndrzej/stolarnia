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

                        // **Wymiar wchodzi do nazwy pozycji.**
                        //
                        // „GTV • AXIS PRO • H120" mówi, jaki to system, ale
                        // nie mówi, jaką sztukę zamówić — prowadnica 450
                        // i 500 to dwa różne indeksy w hurtowni. Wymiar był
                        // w karcie technicznej i gubił się po drodze.
                        let name =
                            (
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
                                + [
                                    hardware
                                        .opisWymiaruV0103
                                ]
                                .compactMap { $0 }
                            )
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

        let pozycjeDodatkow = pozycjeDodatkowProjektu(
            wariant: wariant,
            projekt: projekt,
            materialy: aktywne,
            wybranaPlyta: wybranaPlyta,
            wybranyFront: wybranyFront
        )

        let pozycje =
            pozycjeBazowe
            + pozycjeOkuc
            + pozycjeDodatkow

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

    // MARK: - v0.28.0 Dodatki projektu (LED / blendy / oblożenie ścian)

    /// Generuje pozycje kosztowe dla trzech dodatków projektu wg wartości
    /// wpisanych w `ProjektWyceny`. Zerowe pola są pomijane, żeby nie zaśmiecać wyceny.
    private static func pozycjeDodatkowProjektu(
        wariant: WariantWyceny,
        projekt: ProjektWyceny,
        wybranaPlyta: WybranyMaterialWyceny,
        wybranyFront: WybranyMaterialWyceny
    ) -> [PozycjaKosztowaWyceny] {
        var pozycje: [PozycjaKosztowaWyceny] = []

        // 1) Listwy LED — stawka rynkowa taśma+profil aluminiowy+zasilacz per mb.
        // Wariant premium/vip: +20% za profile o wyższej jakości i CRI 90+.
        if projekt.metryBiezaceListewLED > 0 {
            let bazaLED: Double = 65 // zł/mb netto (taśma LED 24V + profil AL + kołnierz zasilania)
            let mnoznik: Double = wariant == .premium || wariant == .vip ? 1.2 : 1.0
            pozycje.append(
                PozycjaKosztowaWyceny(
                    nazwa: "Listwa LED pod szafki wiszące",
                    kategoria: .oswietlenie,
                    ilosc: projekt.metryBiezaceListewLED,
                    jednostka: "mb",
                    cenaJednostkowaNetto: bazaLED * mnoznik,
                    uwagi: "Taśma 24V + profil aluminiowy + zasilacz. Wariant \(wariant.nazwa)."
                )
            )
        }

        // 2) Blendy domykające ciąg — cena z materiału frontu × pole blendy.
        // Wysokość zabudowy 720 mm (dolne) do szacowania powierzchni; wysoka
        // zabudowa też wpada w tę grupę — dokładność wystarczająca do wyceny.
        if projekt.liczbaBlendDomykajacych > 0 {
            let wysokoscBlendyMM: Double = 720
            let powierzchniaBlendyM2 =
                (projekt.szerokoscBlendyMM / 1000)
                * (wysokoscBlendyMM / 1000)
            let iloscM2 =
                Double(projekt.liczbaBlendDomykajacych)
                * powierzchniaBlendyM2

            pozycje.append(
                PozycjaKosztowaWyceny(
                    nazwa: "Blendy domykające ciąg",
                    kategoria: .plyty,
                    ilosc: iloscM2,
                    jednostka: "m²",
                    cenaJednostkowaNetto: wybranyFront.cenaJednostkowaNetto,
                    uwagi: "\(projekt.liczbaBlendDomykajacych) × blenda \(Int(projekt.szerokoscBlendyMM)) mm × 720 mm w cenie frontu wariantu \(wariant.nazwa)."
                )
            )
        }

        // 3) Oblożenie ścian płytą meblową (fartuch / panele) — cena z płyty korpusu.
        // W wariancie VIP dodatkowy narzut 30% (materiał lakierowany / laminat premium).
        if projekt.powierzchniaOblozeniaScianM2 > 0 {
            let mnoznik: Double = wariant == .vip ? 1.3 : 1.0
            pozycje.append(
                PozycjaKosztowaWyceny(
                    nazwa: "Oblożenie ścian płytą meblową",
                    kategoria: .plyty,
                    ilosc: projekt.powierzchniaOblozeniaScianM2,
                    jednostka: "m²",
                    cenaJednostkowaNetto: wybranaPlyta.cenaJednostkowaNetto * mnoznik,
                    uwagi: "Panele ścienne (fartuch) w wariancie \(wariant.nazwa). Materiał: \(wybranaPlyta.opis)."
                )
            )
        }

        return pozycje
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

    private static func pozycjeDodatkowProjektu(
        wariant:
            WariantWyceny,
        projekt:
            ProjektWyceny,
        materialy:
            [MaterialStolarski],
        wybranaPlyta:
            WybranyMaterialWyceny,
        wybranyFront:
            WybranyMaterialWyceny
    ) -> [PozycjaKosztowaWyceny] {
        var result:
            [PozycjaKosztowaWyceny] = []

        if projekt.metryBiezaceListewLED > 0 {
            result.append(
                PozycjaKosztowaWyceny(
                    nazwa:
                        "Listwa LED z projektu",
                    kategoria:
                        .oswietlenie,
                    ilosc:
                        projekt.metryBiezaceListewLED,
                    jednostka:
                        "mb",
                    cenaJednostkowaNetto:
                        cenaListewLEDNetto(
                            materialy:
                                materialy
                        ),
                    uwagi:
                        "Dokładna długość z projektu. Zasilacze i osprzęt mogą być doliczone przez automatyczny dobór okuć."
                )
            )
        }

        if projekt.liczbaBlendDomykajacych > 0,
           projekt.szerokoscBlendyMM > 0 {
            let powierzchniaBlendM2 =
                Double(
                    projekt.liczbaBlendDomykajacych
                )
                * projekt.szerokoscBlendyMM
                / 1_000
                * 0.72

            result.append(
                PozycjaKosztowaWyceny(
                    nazwa:
                        "Blendy domykające",
                    kategoria:
                        .fronty,
                    ilosc:
                        powierzchniaBlendM2,
                    jednostka:
                        "m²",
                    cenaJednostkowaNetto:
                        wybranyFront
                            .cenaJednostkowaNetto,
                    uwagi:
                        [
                            "\(projekt.liczbaBlendDomykajacych) szt. × \(Int(projekt.szerokoscBlendyMM.rounded())) mm.",
                            "Szacunek wysokości: 720 mm.",
                            wybranyFront.opis
                        ]
                        .filter {
                            !$0.isEmpty
                        }
                        .joined(
                            separator: " "
                        )
                )
            )
        }

        if projekt.powierzchniaOblozeniaScianM2 > 0 {
            result.append(
                PozycjaKosztowaWyceny(
                    nazwa:
                        "Obłożenie ścian płytą",
                    kategoria:
                        .plyty,
                    ilosc:
                        projekt
                            .powierzchniaOblozeniaScianM2,
                    jednostka:
                        "m²",
                    cenaJednostkowaNetto:
                        wybranaPlyta
                            .cenaJednostkowaNetto
                        * mnoznikOblozeniaScian(
                            wariant
                        ),
                    uwagi:
                        [
                            "Fartuch/panele ścienne z projektu.",
                            wybranaPlyta.opis
                        ]
                        .filter {
                            !$0.isEmpty
                        }
                        .joined(
                            separator: " "
                        )
                )
            )
        }

        return result
    }

    private static func cenaListewLEDNetto(
        materialy:
            [MaterialStolarski]
    ) -> Double {
        let wartosci =
            materialy
                .filter {
                    $0.aktywny
                    && $0.typ == .akcesoriumMeblowe
                    && $0.jednostka == .metrBiezacy
                    && tekstWskazujeLED($0.nazwa + " " + $0.notatki)
                }
                .map(
                    \.cenaPoRabacieNetto
                )
                .filter {
                    $0 > 0
                }

        guard !wartosci.isEmpty else {
            return 8.94
        }

        return wartosci.reduce(0, +)
            / Double(wartosci.count)
    }

    private static func tekstWskazujeLED(
        _ value:
            String
    ) -> Bool {
        let normalized =
            value.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pl_PL")
            )

        return normalized.contains("led")
            || normalized.contains("tasma")
            || normalized.contains("oswietlenie")
    }

    private static func mnoznikOblozeniaScian(
        _ wariant:
            WariantWyceny
    ) -> Double {
        switch wariant {
        case .eco,
             .standard:
            return 1
        case .premium:
            return 1.12
        case .vip:
            return 1.25
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
