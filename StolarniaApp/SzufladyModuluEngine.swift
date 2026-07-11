import Foundation

enum SzufladyModuluEngine {
    private static let domyslnaGruboscFrontuMM = 18.0
    private static let minimalneCofniecieSzufladyWewnetrznejMM = 42.0
    private static let luzTechnologicznyZaFrontemMM = 24.0

    static func geometria(
        karty card:
            KartaTechnicznaSzafki
    ) -> GeometriaWnetrzaSzafki {
        let sideThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ
                    == .scianaBoczna
                }?
                .gruboscMM
            ?? 18

        let bottomThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ == .dno
                    || $0.typ
                        == .wieniecDolny
                }?
                .gruboscMM
            ?? 18

        let topThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ
                    == .wieniecGorny
                }?
                .gruboscMM
            ?? 18

        let backThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ == .plecy
                }?
                .gruboscMM
            ?? 3

        return GeometriaWnetrzaSzafki(
            szerokoscMM:
                max(
                    card.szerokoscMM
                    - sideThickness * 2,
                    0
                ),
            wysokoscMM:
                max(
                    card.wysokoscMM
                    - bottomThickness
                    - topThickness,
                    0
                ),
            glebokoscMM:
                max(
                    card.glebokoscMM
                    - backThickness,
                    0
                ),
            gruboscBokuMM:
                sideThickness,
            gruboscDnaMM:
                bottomThickness,
            gruboscGoryMM:
                topThickness,
            gruboscPlecowMM:
                backThickness
        )
    }

    static func maksymalnaLiczba(
        parametry:
            ParametryAutomatycznegoUkladuSzuflad,
        w card:
            KartaTechnicznaSzafki
    ) -> Int {
        let geometry =
            geometria(
                karty: card
            )

        let usableHeight =
            max(
                geometry.wysokoscMM
                - parametry.marginesDolnyMM
                - parametry.marginesGornyMM,
                0
            )

        let step =
            max(
                parametry.wysokoscFrontuMM
                + parametry
                    .szczelinaMiedzyFrontamiMM,
                0.1
            )

        return max(
            Int(
                floor(
                    (
                        usableHeight
                        + parametry
                            .szczelinaMiedzyFrontamiMM
                    )
                    / step
                )
            ),
            0
        )
    }

    static func generuj(
        parametry:
            ParametryAutomatycznegoUkladuSzuflad,
        dla card:
            KartaTechnicznaSzafki
    ) -> [SzufladaModulu] {
        let requestedCount =
            max(
                parametry.liczba,
                0
            )

        guard requestedCount > 0 else {
            return []
        }

        var drawers:
            [SzufladaModulu] = []
        let profile =
            KatalogRegulAkcesoriow
                .profil(
                    id:
                        parametry.profilID
                )

        var currentY =
            parametry.marginesDolnyMM

        for index in 0..<requestedCount {
            let label =
                "\(card.numerSzafki)_SZ_\(index + 1)"

            var drawer =
                SzufladaModulu(
                    etykieta: label,
                    nazwa:
                        "Szuflada \(index + 1)",
                    profilID:
                        parametry.profilID,
                    typFrontu:
                        parametry.typFrontu,
                    pozycjaDolnaYMM:
                        currentY,
                    wysokoscFrontuMM:
                        parametry
                            .wysokoscFrontuMM,
                    wysokoscSkrzynkiMM:
                        parametry
                            .wysokoscSkrzynkiMM,
                    nominalnaDlugoscMM:
                        parametry
                            .nominalnaDlugoscMM,
                    luzDolnyMM:
                        index == 0
                        ? parametry
                            .marginesDolnyMM
                        : parametry
                            .szczelinaMiedzyFrontamiMM
                            / 2,
                    luzGornyMM:
                        index
                        == requestedCount - 1
                        ? parametry
                            .marginesGornyMM
                        : parametry
                            .szczelinaMiedzyFrontamiMM
                            / 2
                )
            drawer.cofniecieOdFrontuMM =
                cofniecieOdFrontuMM(
                    dla: drawer,
                    profil: profile,
                    w: card
                )

            drawers.append(
                drawer
            )

            currentY +=
                parametry.wysokoscFrontuMM
                + parametry
                    .szczelinaMiedzyFrontamiMM
        }

        return drawers
    }

    static func waliduj(
        szuflady:
            [SzufladaModulu],
        w card:
            KartaTechnicznaSzafki
    ) -> [KolizjaSzuflady] {
        let geometry =
            geometria(
                karty: card
            )

        var collisions:
            [KolizjaSzuflady] = []

        let sorted =
            szuflady
                .filter(\.aktywna)
                .sorted {
                    $0.pozycjaDolnaYMM
                    < $1.pozycjaDolnaYMM
                }

        if sorted.isEmpty {
            return [
                KolizjaSzuflady(
                    typ: .liczba,
                    poziom: .informacja,
                    komunikat:
                        "Nie dodano żadnych szuflad."
                )
            ]
        }

        for drawer in sorted {
            guard let profile =
                    KatalogRegulAkcesoriow
                        .profil(
                            id:
                                drawer.profilID
                        )
            else {
                collisions.append(
                    KolizjaSzuflady(
                        typ: .brakProfilu,
                        poziom: .blad,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta): nie znaleziono profilu systemu szuflady."
                    )
                )
                continue
            }

            if drawer.pozycjaDolnaYMM
                < 0
                || drawer.gornaKrawedzYMM
                    > geometry.wysokoscMM {
                collisions.append(
                    KolizjaSzuflady(
                        typ: .pozaKorpusem,
                        poziom: .blad,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta): front wychodzi poza światło korpusu \(format(geometry.wysokoscMM)) mm."
                    )
                )
            }

            if drawer.wysokoscSkrzynkiMM
                + drawer.luzDolnyMM
                + drawer.luzGornyMM
                > drawer.wysokoscFrontuMM {
                collisions.append(
                    KolizjaSzuflady(
                        typ:
                            .wysokoscSkrzynki,
                        poziom: .blad,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta): skrzynka \(format(drawer.wysokoscSkrzynkiMM)) mm nie mieści się za frontem \(format(drawer.wysokoscFrontuMM)) mm z wymaganymi luzami."
                    )
                )
            }

            let depthReserve =
                profile
                    .formulaSzuflady?
                    .zapasGlebokosciKorpusuMM
                ?? 3
            let frontSetback =
                cofniecieOdFrontuMM(
                    dla: drawer,
                    profil: profile,
                    w: card
                )

            let requiredDepth =
                drawer.nominalnaDlugoscMM
                + depthReserve
                + frontSetback

            if requiredDepth
                > geometry.glebokoscMM {
                collisions.append(
                    KolizjaSzuflady(
                        typ: .glebokosc,
                        poziom: .blad,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta): system wymaga \(format(requiredDepth)) mm głębokości z cofnięciem \(format(frontSetback)) mm; dostępne światło to \(format(geometry.glebokoscMM)) mm."
                    )
                )
            }

            if let formula =
                    profile.formulaSzuflady,
               let reduction =
                    formula
                        .redukcjaSzerokosciDnaMM {
                let bottomWidth =
                    geometry.szerokoscMM
                    - reduction

                if bottomWidth <= 0 {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .szerokosc,
                            poziom: .blad,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): po redukcji systemowej szerokość dna jest niedodatnia."
                        )
                    )
                } else if bottomWidth < 100 {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .szerokosc,
                            poziom:
                                .ostrzezenie,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): wynikowa szerokość dna \(format(bottomWidth)) mm jest bardzo mała."
                        )
                    )
                }
            }

            if drawer.typFrontu
                == .wewnetrzny,
               !maZawiasZeroUskoku(
                    card
               ) {
                collisions.append(
                    KolizjaSzuflady(
                        typ: .zawias,
                        poziom:
                            .ostrzezenie,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta): szuflada wewnętrzna jest cofnięta o \(format(frontSetback)) mm. Dodaj zawias 155° z zerowym uskokiem albo potwierdź brak kolizji toru frontu."
                    )
                )
            }
        }

        for index in sorted.indices {
            guard index + 1
                < sorted.count
            else {
                break
            }

            let lower =
                sorted[index]
            let upper =
                sorted[index + 1]

            if lower.gornaKrawedzYMM
                + lower.luzGornyMM
                + upper.luzDolnyMM
                > upper.pozycjaDolnaYMM {
                collisions.append(
                    KolizjaSzuflady(
                        typ:
                            .nakladanieSzuflad,
                        poziom: .blad,
                        etykietaSzuflady:
                            upper.etykieta,
                        komunikat:
                            "\(lower.etykieta) i \(upper.etykieta) nachodzą na siebie."
                    )
                )
            }
        }

        let shelfPositions =
            pozycjePolek(
                w: card,
                geometry:
                    geometry
            )

        for drawer in sorted {
            let boxBottom =
                drawer.pozycjaDolnaYMM
                + drawer.luzDolnyMM
            let boxTop =
                boxBottom
                + drawer
                    .wysokoscSkrzynkiMM

            for shelf in shelfPositions
            where shelf.yMM
                >= boxBottom - 3
                && shelf.yMM
                    <= boxTop + 3 {
                collisions.append(
                    KolizjaSzuflady(
                        typ: .polka,
                        poziom: .blad,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta) koliduje z \(shelf.label) na wysokości \(format(shelf.yMM)) mm.",
                        etykietaElementuKolizyjnego:
                            shelf.label
                    )
                )
            }
        }

        if collisions.isEmpty {
            collisions.append(
                KolizjaSzuflady(
                    typ: .liczba,
                    poziom:
                        .informacja,
                    komunikat:
                        "Układ \(sorted.count) szuflad mieści się w korpusie i nie wykryto kolizji."
                )
            )
        }

        return collisions
    }

    static func zastosuj(
        szuflady:
            [SzufladaModulu],
        profil:
            ProfilAkcesoriumMeblowego,
        usunKolidujacePolki: Bool,
        do card:
            inout KartaTechnicznaSzafki
    ) {
        let collisions =
            waliduj(
                szuflady:
                    szuflady,
                w: card
            )

        if usunKolidujacePolki {
            let labels =
                Set(
                    collisions
                        .compactMap {
                            $0
                                .etykietaElementuKolizyjnego
                        }
                )

            card.efektywneElementy
                .removeAll {
                    labels.contains(
                        $0.etykieta
                    )
                }

            card.liczbaPolek =
                card
                    .efektywneElementy
                    .filter {
                        $0.typ == .polka
                    }
                    .count
        }

        card.efektywneElementy
            .removeAll {
                $0.typ == .szuflada
            }

        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi
                    .hasPrefix(
                        "AUTO-SZUFLADA:"
                    )
            }

        for index in card
            .efektywneElementy
            .indices {
            card
                .efektywneElementy[
                    index
                ]
                .punktyWiercenia
                .removeAll {
                    $0.opis
                        .hasPrefix(
                            "AUTO-SZUFLADA:"
                        )
                }
        }

        let geometry =
            geometria(
                karty: card
            )

        let effectiveDrawers =
            szuflady.map {
                drawer -> SzufladaModulu in

                var resolvedDrawer =
                    drawer
                if resolvedDrawer
                    .cofniecieOdFrontuMM
                    == nil {
                    resolvedDrawer
                        .cofniecieOdFrontuMM =
                        cofniecieOdFrontuMM(
                            dla: resolvedDrawer,
                            profil: profil,
                            w: card
                        )
                }
                return resolvedDrawer
            }

        for drawer in effectiveDrawers {
            let element =
                ElementTechnicznySzafki(
                    etykieta:
                        drawer.etykieta,
                    typ: .szuflada,
                    nazwa:
                        drawer.nazwa,
                    dlugoscMM:
                        drawer
                            .wysokoscSkrzynkiMM,
                    szerokoscMM:
                        geometry.szerokoscMM,
                    gruboscMM:
                        16,
                    ilosc: 1,
                    material:
                        "System \(profil.producent) \(profil.rodzina)",
                    kierunek:
                        .poziomy,
                    uwagi:
                        "Pozycja Y: \(format(drawer.pozycjaDolnaYMM)) mm; front: \(format(drawer.wysokoscFrontuMM)) mm; długość nominalna: \(format(drawer.nominalnaDlugoscMM)) mm; cofnięcie od frontu: \(format(drawer.efektywneCofniecieOdFrontuMM)) mm.",
                    punktyWiercenia: []
                )

            card.efektywneElementy
                .append(element)

            let marketPrice =
                profil.cenaRynkowa

            card.efektywneAkcesoria
                .append(
                    InstancjaAkcesoriumSzafki(
                        profilID:
                            profil.id,
                        producent:
                            profil.producent,
                        rodzina:
                            profil.rodzina,
                        model:
                            profil.model,
                        kategoria:
                            profil.kategoria,
                        ilosc: 1,
                        docelowaEtykietaElementu:
                            drawer.etykieta,
                        nominalnaDlugoscMM:
                            drawer
                                .nominalnaDlugoscMM,
                        wariantWysokosciMM:
                            drawer
                                .wysokoscSkrzynkiMM,
                        gruboscDnaMM:
                            domyslnaGrubosc(
                                profil
                                    .regulaGrubosciDna
                            ),
                        gruboscTyluMM:
                            domyslnaGrubosc(
                                profil
                                    .regulaGrubosciTylu
                            ),
                        gruboscBokuMM:
                            domyslnaGrubosc(
                                profil
                                    .regulaGrubosciBoku
                            ),
                        gruboscKorpusuMM:
                            geometry
                                .gruboscBokuMM,
                        wysokoscFrontuMM:
                            drawer
                                .wysokoscFrontuMM,
                        cenaJednostkowaNettoPLN:
                            marketPrice?
                                .cenaSredniaNettoPLN,
                        cenaJednostkowaBruttoPLN:
                            marketPrice?
                                .cenaSredniaBruttoPLN,
                        jednostkaCeny:
                            marketPrice?
                                .jednostka
                                .skrot,
                        dataCeny:
                            marketPrice?
                                .dataResearchu,
                        liczbaProbekCeny:
                            marketPrice?
                                .liczbaProbek,
                        uwagi:
                            "AUTO-SZUFLADA:\(drawer.id.uuidString)"
                    )
                )

            dodajPunktyProwadnic(
                dla: drawer,
                profil: profil,
                do: &card
            )
        }

        card.efektywneSzuflady =
            effectiveDrawers
        card.dataAktualizacji =
            Date()
    }

    static func cofniecieOdFrontuMM(
        dla drawer:
            SzufladaModulu,
        profil:
            ProfilAkcesoriumMeblowego?,
        w card:
            KartaTechnicznaSzafki
    ) -> Double {
        if let explicit =
            drawer
                .cofniecieOdFrontuMM {
            return max(
                explicit,
                0
            )
        }

        guard drawer.typFrontu
            == .wewnetrzny
        else {
            return 0
        }

        let frontThickness =
            gruboscFrontuZewnetrznegoMM(
                w: card
            )
        let pushReserve =
            wymagaRezerwyPushToOpen(
                profil
            )
            ? 10.0
            : 0.0

        return max(
            minimalneCofniecieSzufladyWewnetrznejMM,
            frontThickness
            + luzTechnologicznyZaFrontemMM
            + pushReserve
        )
    }

    private static func dodajPunktyProwadnic(
        dla drawer:
            SzufladaModulu,
        profil:
            ProfilAkcesoriumMeblowego,
        do card:
            inout KartaTechnicznaSzafki
    ) {
        let y =
            drawer.pozycjaDolnaYMM
            + drawer
                .wysokoscSkrzynkiMM
                / 2

        for index in card
            .efektywneElementy
            .indices
        where card
            .efektywneElementy[index]
            .typ == .scianaBoczna {
            let side =
                card
                    .efektywneElementy[
                        index
                    ]

            let isRight =
                side.nazwa
                    .localizedCaseInsensitiveContains(
                        "praw"
                    )
            let setback =
                drawer
                    .efektywneCofniecieOdFrontuMM

            let baseX =
                isRight
                ? max(
                    side.szerokoscMM
                    - 37,
                    0
                )
                : 37
            let x =
                isRight
                ? max(
                    baseX - setback,
                    0
                )
                : min(
                    baseX + setback,
                    max(
                        side.szerokoscMM,
                        0
                    )
                )

            card
                .efektywneElementy[
                    index
                ]
                .punktyWiercenia
                .append(
                    PunktWierceniaSzafki(
                        element:
                            side.nazwa,
                        typ:
                            .prowadnica,
                        strona:
                            .wewnetrzna,
                        xMM: x,
                        yMM: y,
                        srednicaMM: 5,
                        glebokoscMM:
                            min(
                                12,
                                max(
                                    side.gruboscMM
                                    - 2,
                                    0
                                )
                            ),
                        opis:
                            "AUTO-SZUFLADA: \(drawer.etykieta) • \(profil.producent) \(profil.rodzina) • oś montażowa prowadnicy • cofnięcie od frontu \(format(setback)) mm"
                    )
                )
        }
    }

    private static func pozycjePolek(
        w card:
            KartaTechnicznaSzafki,
        geometry:
            GeometriaWnetrzaSzafki
    ) -> [
        (
            label: String,
            yMM: Double
        )
    ] {
        let shelves =
            card
                .efektywneElementy
                .filter {
                    $0.typ == .polka
                }

        guard !shelves.isEmpty else {
            return []
        }

        return shelves
            .enumerated()
            .map {
                index,
                shelf in

                (
                    label:
                        shelf.etykieta,
                    yMM:
                        geometry.wysokoscMM
                        * Double(index + 1)
                        / Double(
                            shelves.count + 1
                        )
                )
            }
    }

    private static func maZawiasZeroUskoku(
        _ card:
            KartaTechnicznaSzafki
    ) -> Bool {
        card
            .efektywneAkcesoria
            .contains {
                $0.profilID
                == "blum.cliptop.155.zero"
            }
    }

    private static func domyslnaGrubosc(
        _ rule:
            RegulaGrubosciPlyty
    ) -> Double? {
        switch rule.tryb {
        case .stala:
            return rule.stalaMM
        case .zakres:
            return rule.minimumMM
        case .wybor:
            return rule.dozwoloneMM
                .first
        case .brak,
             .wymagaPotwierdzenia:
            return nil
        }
    }

    private static func gruboscFrontuZewnetrznegoMM(
        w card:
            KartaTechnicznaSzafki
    ) -> Double {
        card
            .efektywneElementy
            .first {
                $0.typ == .front
            }?
            .gruboscMM
        ?? domyslnaGruboscFrontuMM
    }

    private static func wymagaRezerwyPushToOpen(
        _ profil:
            ProfilAkcesoriumMeblowego?
    ) -> Bool {
        guard let profil else {
            return false
        }

        let joined =
            (
                [
                    profil.rodzina,
                    profil.model
                ]
                + profil.funkcje
            )
            .joined(
                separator: " "
            )
            .lowercased()

        return joined.contains("push")
            || joined.contains("p2o")
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
