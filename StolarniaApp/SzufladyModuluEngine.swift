import Foundation
import DomainCore

enum SzufladyModuluEngine {
    private static let domyslnaGruboscFrontuMM = 18.0
    private static let minimalneCofniecieSzufladyWewnetrznejMM = 42.0
    private static let luzTechnologicznyZaFrontemMM = 24.0
    private static let autoDrawerMarker = "AUTO-SZUFLADA:"
    private static let autoDrawerBlockStart = "[AUTO_SZUFLADY_START]"
    private static let autoDrawerBlockEnd = "[AUTO_SZUFLADY_END]"
    private static let minimalnaSzerokoscListwyDystansowejMM = 60.0

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
        let doborProwadnicy = doborProwadnicy(
            profil: profile,
            w: card
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
                        doborProwadnicy?.nominalLength.rawValue
                        ?? parametry.nominalnaDlugoscMM,
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
            drawer.niewykorzystanaGlebokoscMM =
                doborProwadnicy?.unusedDepth.rawValue
            drawer.wymagaPotwierdzeniaSKUProwadnicy =
                doborProwadnicy?.requiresSKUConfirmation
            drawer.cofniecieOdFrontuMM =
                cofniecieOdFrontuMM(
                    dla: drawer,
                    profil: profile,
                    w: card
                )
            drawer.odsuniecieOdScianBocznychMM =
                odsuniecieOdScianBocznychMM(
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

    /// Generuje układ szuflad na podstawie presetu.
    /// Dla `.rowne(N)` deleguje do klasycznego `generuj(...)`.
    /// Dla wariantów niestandardowych oblicza wysokości frontów i rozmieszcza je od dołu.
    /// Dla `.cargo` zwraca pojedynczą szufladę Cargo pełnej użytecznej wysokości.
    static func generujZPresetu(
        preset: PresetUkladuSzuflad,
        parametryBazowe: ParametryAutomatycznegoUkladuSzuflad,
        dla card: KartaTechnicznaSzafki
    ) -> [SzufladaModulu] {
        switch preset {
        case .rowne(let liczba):
            var p = parametryBazowe
            p.liczba = max(liczba, 0)
            return generuj(parametry: p, dla: card)

        case .cargo:
            return generujCargo(
                parametry: parametryBazowe,
                dla: card
            )

        case .jednaWysokaDwieNiskie(let wysokaMM):
            let uzyteczna = uzytecznaWysokosc(
                parametry: parametryBazowe,
                dla: card
            )
            let wysoka = max(min(wysokaMM, uzyteczna), 0)
            let pozostala = max(
                uzyteczna
                - wysoka
                - parametryBazowe.szczelinaMiedzyFrontamiMM * 2,
                0
            )
            let niska = pozostala / 2
            return generujZWysokosciami(
                wysokosci: [niska, niska, wysoka],
                parametry: parametryBazowe,
                dla: card
            )

        case .wysokaNaDoleDwieNiskie(let wysokaMM):
            let uzyteczna = uzytecznaWysokosc(
                parametry: parametryBazowe,
                dla: card
            )
            let wysoka = max(min(wysokaMM, uzyteczna), 0)
            let pozostala = max(
                uzyteczna
                - wysoka
                - parametryBazowe.szczelinaMiedzyFrontamiMM * 2,
                0
            )
            let niska = pozostala / 2
            return generujZWysokosciami(
                wysokosci: [wysoka, niska, niska],
                parametry: parametryBazowe,
                dla: card
            )

        case .dwieWysokie:
            let uzyteczna = uzytecznaWysokosc(
                parametry: parametryBazowe,
                dla: card
            )
            let wysokoscFrontu = max(
                (uzyteczna
                 - parametryBazowe.szczelinaMiedzyFrontamiMM)
                / 2,
                0
            )
            return generujZWysokosciami(
                wysokosci: [wysokoscFrontu, wysokoscFrontu],
                parametry: parametryBazowe,
                dla: card
            )

        case .wysokosciNiestandardowe(let wysokosci):
            return generujZWysokosciami(
                wysokosci: wysokosci,
                parametry: parametryBazowe,
                dla: card
            )
        }
    }

    private static func uzytecznaWysokosc(
        parametry: ParametryAutomatycznegoUkladuSzuflad,
        dla card: KartaTechnicznaSzafki
    ) -> Double {
        let geometry = geometria(karty: card)
        return max(
            geometry.wysokoscMM
            - parametry.marginesDolnyMM
            - parametry.marginesGornyMM,
            0
        )
    }

    private static func generujZWysokosciami(
        wysokosci: [Double],
        parametry: ParametryAutomatycznegoUkladuSzuflad,
        dla card: KartaTechnicznaSzafki
    ) -> [SzufladaModulu] {
        let odfiltrowane = wysokosci.filter { $0 > 0 }
        guard !odfiltrowane.isEmpty else { return [] }

        // **Fronty muszą wypełnić szafkę co do milimetra.**
        //
        // Wcześniej ta funkcja układała podane wysokości od dolnego marginesu
        // w górę i na tym kończyła — nic ich nie skalowało. Układ 140/140/280
        // w szafce 900 mm zostawiał ponad 300 mm korpusu bez frontu, a UI
        // pokazywało tylko etykietę „Suma wysokości", której nic nie
        // egzekwowało.
        //
        // Reguła i jej uzasadnienie siedzą w `DrawerFrontStack` (DomainCore)
        // i tą samą drogą idzie już kreator rysunkowy przez `ElevationModule`.
        // **To jest jedyne miejsce, w którym wolno liczyć wysokości frontów** —
        // dwa silniki z własną arytmetyką dawały ten sam mebel policzony
        // dwiema metodami, zależnie od tego, którym oknem się do niego weszło.
        //
        // Tryb `.proportional` traktuje podane wysokości jako **proporcje**,
        // więc zamysł projektanta („dwie płytkie u góry, jedna głęboka na
        // dole") przeżywa zmianę gabarytu szafki. Presety wyżej liczą sumę
        // dokładnie, więc dla nich skalowanie jest tożsamością.
        let geometria = geometria(karty: card)
        let stos = DrawerFrontStack.heights(
            zoneHeight: Millimeters(geometria.wysokoscMM),
            count: odfiltrowane.count,
            mode: .proportional(odfiltrowane.map(Millimeters.init(_:))),
            gap: Millimeters(parametry.szczelinaMiedzyFrontamiMM),
            bottomMargin: Millimeters(parametry.marginesDolnyMM),
            topMargin: Millimeters(parametry.marginesGornyMM)
        )
        // Pusty wynik oznacza strefę, która nie pomieści tylu frontów.
        // Zostawiamy wtedy wysokości podane przez projektanta — walidacja
        // (`waliduj(szuflady:...)`) i tak to zgłosi, a ciche wyrzucenie układu
        // odbierałoby mu to, co ustawił.
        let wysokosciFrontow = stos.heights.isEmpty
            ? odfiltrowane
            : stos.heights.map(\.rawValue)

        let profile = KatalogRegulAkcesoriow.profil(
            id: parametry.profilID
        )
        let doborProwadnicy = doborProwadnicy(
            profil: profile,
            w: card
        )

        var drawers: [SzufladaModulu] = []
        var currentY = parametry.marginesDolnyMM
        let ostatniIndeks = wysokosciFrontow.count - 1

        for (index, wysokoscFrontu) in wysokosciFrontow.enumerated() {
            let label = "\(card.numerSzafki)_SZ_\(index + 1)"

            var drawer = SzufladaModulu(
                etykieta: label,
                nazwa: "Szuflada \(index + 1)",
                profilID: parametry.profilID,
                typFrontu: parametry.typFrontu,
                pozycjaDolnaYMM: currentY,
                wysokoscFrontuMM: wysokoscFrontu,
                wysokoscSkrzynkiMM: parametry.wysokoscSkrzynkiMM,
                nominalnaDlugoscMM: doborProwadnicy?.nominalLength.rawValue
                    ?? parametry.nominalnaDlugoscMM,
                luzDolnyMM: index == 0
                    ? parametry.marginesDolnyMM
                    : parametry.szczelinaMiedzyFrontamiMM / 2,
                luzGornyMM: index == ostatniIndeks
                    ? parametry.marginesGornyMM
                    : parametry.szczelinaMiedzyFrontamiMM / 2
            )
            drawer.niewykorzystanaGlebokoscMM =
                doborProwadnicy?.unusedDepth.rawValue
            drawer.wymagaPotwierdzeniaSKUProwadnicy =
                doborProwadnicy?.requiresSKUConfirmation
            drawer.wariantSzuflady = .standardowa
            drawer.cofniecieOdFrontuMM = cofniecieOdFrontuMM(
                dla: drawer,
                profil: profile,
                w: card
            )
            drawer.odsuniecieOdScianBocznychMM =
                odsuniecieOdScianBocznychMM(
                    dla: drawer,
                    profil: profile,
                    w: card
                )
            if let asymetryczne = odsunieciaAsymetryczneV0104(
                dla: drawer, profil: profile, w: card
            ) {
                drawer.odsuniecieStronaZawiasuMM = asymetryczne.zawias
                drawer.odsuniecieStronaWolnaMM = asymetryczne.wolna
            }
            drawers.append(drawer)

            currentY += wysokoscFrontu
                + parametry.szczelinaMiedzyFrontamiMM
        }

        return drawers
    }

    private static func generujCargo(
        parametry: ParametryAutomatycznegoUkladuSzuflad,
        dla card: KartaTechnicznaSzafki
    ) -> [SzufladaModulu] {
        let uzyteczna = uzytecznaWysokosc(
            parametry: parametry,
            dla: card
        )
        guard uzyteczna > 0 else { return [] }

        let profile = KatalogRegulAkcesoriow.profil(
            id: parametry.profilID
        )
        let doborProwadnicy = doborProwadnicy(
            profil: profile,
            w: card
        )

        var drawer = SzufladaModulu(
            etykieta: "\(card.numerSzafki)_CARGO",
            nazwa: "Cargo",
            profilID: parametry.profilID,
            typFrontu: .zewnetrzny,
            pozycjaDolnaYMM: parametry.marginesDolnyMM,
            wysokoscFrontuMM: uzyteczna,
            wysokoscSkrzynkiMM: parametry.wysokoscSkrzynkiMM,
            nominalnaDlugoscMM: doborProwadnicy?.nominalLength.rawValue
                ?? parametry.nominalnaDlugoscMM,
            luzDolnyMM: parametry.marginesDolnyMM,
            luzGornyMM: parametry.marginesGornyMM
        )
        drawer.niewykorzystanaGlebokoscMM =
            doborProwadnicy?.unusedDepth.rawValue
        drawer.wymagaPotwierdzeniaSKUProwadnicy =
            doborProwadnicy?.requiresSKUConfirmation
        drawer.wariantSzuflady = .cargo
        drawer.cofniecieOdFrontuMM = cofniecieOdFrontuMM(
            dla: drawer,
            profil: profile,
            w: card
        )
        drawer.odsuniecieOdScianBocznychMM =
            odsuniecieOdScianBocznychMM(
                dla: drawer,
                profil: profile,
                w: card
            )
        return [drawer]
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
            let sideInset =
                odsuniecieOdScianBocznychMM(
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
                let availableWidth =
                    geometry.szerokoscMM
                    - sideInset * 2
                let bottomWidth =
                    availableWidth
                    - reduction

                if availableWidth <= 0 {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .szerokosc,
                            poziom: .blad,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): boczne odsunięcia \(format(sideInset)) mm/strona zabierają całe światło korpusu."
                        )
                    )
                } else if bottomWidth <= 0 {
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

            if drawer.typFrontu == .wewnetrzny,
               sideInset > 0 {
                collisions.append(
                    KolizjaSzuflady(
                        typ: .szerokosc,
                        poziom: .informacja,
                        etykietaSzuflady:
                            drawer.etykieta,
                        komunikat:
                            "\(drawer.etykieta): szuflada wewnętrzna ma boczne odsunięcie \(format(sideInset)) mm na stronę; światło robocze jest pomniejszone o \(format(sideInset * 2)) mm."
                    )
                )
            }

            if drawer.typFrontu
                == .wewnetrzny {
                let frontRule =
                    regulaSzufladyZaFrontem(
                        w: card
                    )
                let requiredSetback =
                    wymaganeCofniecieSzufladyWewnetrznejMM(
                        profil:
                            profile,
                        w:
                            card
                    )
                let requiredSideInset =
                    wymaganeOdsuniecieSzufladyWewnetrznejMM(
                        profil:
                            profile,
                        rule:
                            frontRule
                    )
                let isRollOut =
                    drawer
                        .efektywnyWariant
                    == .cargo
                let isAllowed =
                    frontRule
                        .dopuszczaSzufladyWewnetrzne
                    || (
                        isRollOut
                        && frontRule
                            .dopuszczaRollOut
                    )

                if !isAllowed {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .zawias,
                            poziom:
                                .blad,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): szuflada za frontem wymaga zawiasu zero-protrusion min. \(format(frontRule.minimalnyKatOtwarciaStopnie))° albo potwierdzonego dystansu po stronie zawiasu. Obecna reguła odsuwa skrzynkę o \(format(frontRule.wymaganySymetrycznyDystansMM)) mm/strona."
                        )
                    )
                } else if frontRule
                    .wymagaPotwierdzeniaSKU {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .zawias,
                            poziom:
                                .ostrzezenie,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): zawias dopuszcza ten układ tylko po potwierdzeniu konkretnego SKU. Cofnięcie: \(format(frontSetback)) mm, dystans boczny: \(format(sideInset)) mm/strona."
                        )
                    )
                } else if maZawiasZeroUskoku(
                    card
                ) {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .zawias,
                            poziom:
                                .informacja,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): układ zgodny z regułą zero-protrusion; zostawiono \(format(frontRule.dodatkowyLuzBezpieczenstwaMM)) mm luzu bezpieczeństwa na stronę."
                        )
                    )
                }

                if profilZawiasuFrontu(card) == nil {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .zawias,
                            poziom:
                                .ostrzezenie,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): brak wybranego zawiasu frontu z regułą zero-protrusion. System przyjmuje regułę domyślną, ale przed produkcją trzeba wskazać konkretny SKU zawiasu/prowadnika."
                        )
                    )
                }

                if frontSetback + 0.5
                    < requiredSetback {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .zawias,
                            poziom:
                                .blad,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): cofnięcie \(format(frontSetback)) mm jest za małe dla szuflady za frontem. Minimum: \(format(requiredSetback)) mm od płaszczyzny frontu."
                        )
                    )
                }

                if sideInset + 0.5
                    < requiredSideInset {
                    collisions.append(
                        KolizjaSzuflady(
                            typ: .zawias,
                            poziom:
                                .blad,
                            etykietaSzuflady:
                                drawer.etykieta,
                            komunikat:
                                "\(drawer.etykieta): boczny dystans \(format(sideInset)) mm/strona jest za mały. Minimum z reguły zawiasu/prowadnicy: \(format(requiredSideInset)) mm/strona."
                        )
                    )
                }
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
                || $0.uwagi
                    .hasPrefix(
                        autoDrawerMarker
                    )
            }

        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi
                    .hasPrefix(
                        autoDrawerMarker
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
                            autoDrawerMarker
                        )
                }

            card
                .efektywneElementy[
                    index
                ]
                .efektywneLinieWiercenia
                .removeAll {
                    $0.opis
                        .hasPrefix(
                            autoDrawerMarker
                        )
                }
        }

        let geometry =
            geometria(
                karty: card
            )
        let doborProwadnicy = doborProwadnicy(
            profil: profil,
            w: card
        )

        let effectiveDrawers =
            szuflady.map {
                drawer -> SzufladaModulu in

                var resolvedDrawer =
                    drawer
                if let doborProwadnicy {
                    resolvedDrawer.nominalnaDlugoscMM =
                        doborProwadnicy.nominalLength.rawValue
                    resolvedDrawer.niewykorzystanaGlebokoscMM =
                        doborProwadnicy.unusedDepth.rawValue
                    resolvedDrawer.wymagaPotwierdzeniaSKUProwadnicy =
                        doborProwadnicy.requiresSKUConfirmation
                }
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
                if resolvedDrawer
                    .odsuniecieOdScianBocznychMM
                    == nil {
                    resolvedDrawer
                        .odsuniecieOdScianBocznychMM =
                        odsuniecieOdScianBocznychMM(
                            dla: resolvedDrawer,
                            profil: profil,
                            w: card
                        )
                }
                return resolvedDrawer
            }

        for drawer in effectiveDrawers {
            // Suma obu odsunięć, nie „jedno razy dwa".
            //
            // Front uchylny wystaje w światło **tylko po stronie zawiasu**,
            // więc mnożenie przez dwa oddawało szerokość skrzynki po stronie,
            // gdzie nic nie przeszkadza. Przy nieznanej stronie zawiasu
            // `lacznaSzerokoscOdsunieciaV0104` sama wraca do wariantu
            // symetrycznego.
            let elementWidth =
                max(
                    geometry.szerokoscMM
                    - drawer.lacznaSzerokoscOdsunieciaV0104,
                    0
                )

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
                        elementWidth,
                    gruboscMM:
                        16,
                    ilosc: 1,
                    material:
                        "System \(profil.producent) \(profil.rodzina)",
                    kierunek:
                        .poziomy,
                    uwagi:
                        "\(autoDrawerMarker) \(drawer.id.uuidString) • Pozycja Y: \(format(drawer.pozycjaDolnaYMM)) mm; front: \(format(drawer.wysokoscFrontuMM)) mm; długość nominalna: \(format(drawer.nominalnaDlugoscMM)) mm; cofnięcie od frontu: \(format(drawer.efektywneCofniecieOdFrontuMM)) mm; odsunięcie od ścian bocznych: \(drawer.opisOdsunieciaV0104).",
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
                        niewykorzystanaGlebokoscMM:
                            drawer.niewykorzystanaGlebokoscMM,
                        wymagaPotwierdzeniaSKU:
                            drawer.wymagaPotwierdzeniaSKUProwadnicy,
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
                            "\(autoDrawerMarker)\(drawer.id.uuidString)"
                    )
                )

            dodajPunktyProwadnic(
                dla: drawer,
                profil: profil,
                do: &card
            )

            dodajListwyDystansoweSzufladyWewnetrznej(
                dla:
                    drawer,
                profil:
                    profil,
                geometry:
                    geometry,
                do:
                    &card
            )
        }

        card.efektywneSzuflady =
            effectiveDrawers
        card.uwagi =
            replacingAutoDrawerBlock(
                in:
                    card.uwagi,
                drawers:
                    effectiveDrawers,
                profile:
                    profil
            )
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

        return wymaganeCofniecieSzufladyWewnetrznejMM(
            frontThickness:
                frontThickness,
            pushReserve:
                pushReserve
        )
    }

    private static func wymaganeCofniecieSzufladyWewnetrznejMM(
        profil:
            ProfilAkcesoriumMeblowego?,
        w card:
            KartaTechnicznaSzafki
    ) -> Double {
        wymaganeCofniecieSzufladyWewnetrznejMM(
            frontThickness:
                gruboscFrontuZewnetrznegoMM(
                    w: card
                ),
            pushReserve:
                wymagaRezerwyPushToOpen(
                    profil
                )
                ? 10.0
                : 0.0
        )
    }

    private static func wymaganeCofniecieSzufladyWewnetrznejMM(
        frontThickness:
            Double,
        pushReserve:
            Double
    ) -> Double {
        return max(
            minimalneCofniecieSzufladyWewnetrznejMM,
            frontThickness
            + luzTechnologicznyZaFrontemMM
            + pushReserve
        )
    }

    /// Odsunięcia skrzynki **osobno dla strony zawiasu i strony wolnej**.
    ///
    /// Zwraca `nil`, gdy karta nie zna strony zawiasu — wtedy wołający zostaje
    /// przy wartości symetrycznej. Zgadywanie strony byłoby gorsze niż jej
    /// brak: skrzynka wyszłaby odsunięta w złą stronę i nie zmieściłaby się
    /// przy zawiasie.
    static func odsunieciaAsymetryczneV0104(
        dla drawer: SzufladaModulu,
        profil: ProfilAkcesoriumMeblowego?,
        w card: KartaTechnicznaSzafki
    ) -> (zawias: Double, wolna: Double)? {
        guard drawer.typFrontu == .wewnetrzny,
              drawer.odsuniecieOdScianBocznychMM == nil,
              let strona = card.stronaZawiasuV0104,
              strona == .leftHinged || strona == .rightHinged
        else {
            return nil
        }

        let rule = regulaSzufladyZaFrontem(w: card)
        let zachowanie: DrawerBehindDoorPlanner.HingeBehaviour
        if rule.zeroProtrusion {
            zachowanie = rule.minimalnyKatOtwarciaStopnie >= 150
                ? .zeroProtrusion155
                : .zeroProtrusion125
        } else {
            zachowanie = .standard
        }

        let plan = DrawerBehindDoorPlanner.plan(
            .init(
                innerWidth: 600,
                hinge: zachowanie,
                doorThickness: 18
            )
        )

        // Minimum z formuły profilu obowiązuje po obu stronach — to jest
        // wymóg systemu prowadnic, niezależny od zawiasu.
        let minimumProfilu =
            profil?.formulaSzuflady?.minimalneOdsuniecieOdScianBocznychMM ?? 0

        return (
            zawias: max(plan.hingeSideInset.rawValue, minimumProfilu),
            wolna: max(plan.freeSideInset.rawValue, minimumProfilu)
        )
    }

    static func odsuniecieOdScianBocznychMM(
        dla drawer:
            SzufladaModulu,
        profil:
            ProfilAkcesoriumMeblowego?,
        w card:
            KartaTechnicznaSzafki
    ) -> Double {
        if let explicit =
            drawer
                .odsuniecieOdScianBocznychMM {
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

        let frontRule =
            regulaSzufladyZaFrontem(
                w: card
            )

        return wymaganeOdsuniecieSzufladyWewnetrznejMM(
            profil:
                profil,
            rule:
                frontRule
        )
    }

    /// Odsunięcie skrzynki od boków dla szuflady schowanej za frontem.
    ///
    /// Liczbę podaje `DrawerBehindDoorPlanner` (DomainCore), zbudowany na danych
    /// producentów: zwykły zawias zostaje w świetle i zabiera pas grubości
    /// frontu plus luz (18 + 3 = 21 mm), zawias zero-protrusion odrzuca skrzydło
    /// poza światło i zostaje sam luz (3 mm). Wcześniej reguła stosowała
    /// ryczałtowe 50 mm na stronę — w korpusie 600 oddawało to prawie 10 cm
    /// szerokości skrzynki bez podstawy technicznej.
    ///
    /// **Zwraca wartość dla strony zawiasu** — czyli tę większą z dwóch.
    ///
    /// Do 2026-08-27 była stosowana po obu stronach, bo strona zawiasu nie
    /// docierała do karty. Teraz dociera (`KartaTechnicznaSzafki.stronaZawiasuV0104`,
    /// wypełniane z `FurnitureComponent.opening`), więc rozkładem po stronach
    /// zajmuje się `odsunieciaAsymetryczneV0104`.
    ///
    /// Ta funkcja zostaje jako **wartość zachowawcza dla nieznanej strony
    /// zawiasu**: front szufladowy, przesuwny albo stary zapis bez kierunku.
    /// Wtedy odsuwamy obie strony po tyle, ile wymaga strona zawiasu — węższa
    /// skrzynka jest wykonalna, odsunięta w złą stronę nie jest.
    private static func wymaganeOdsuniecieSzufladyWewnetrznejMM(
        profil:
            ProfilAkcesoriumMeblowego?,
        rule:
            RegulaSzufladyZaFrontem
    ) -> Double {
        let zachowanie: DrawerBehindDoorPlanner.HingeBehaviour
        if rule.zeroProtrusion {
            zachowanie = rule.minimalnyKatOtwarciaStopnie >= 150
                ? .zeroProtrusion155
                : .zeroProtrusion125
        } else {
            zachowanie = .standard
        }

        let plan = DrawerBehindDoorPlanner.plan(
            .init(
                // Szerokość nie wpływa na samo wcięcie — liczy się zachowanie
                // zawiasu. Podajemy wartość roboczą, żeby nie zgłaszał „za wąski".
                innerWidth: 600,
                hinge: zachowanie,
                doorThickness: 18
            )
        )

        return max(
            profil?
                .formulaSzuflady?
                .minimalneOdsuniecieOdScianBocznychMM
            ?? 0,
            plan.hingeSideInset.rawValue
        )
    }

    private static func dodajListwyDystansoweSzufladyWewnetrznej(
        dla drawer:
            SzufladaModulu,
        profil:
            ProfilAkcesoriumMeblowego,
        geometry:
            GeometriaWnetrzaSzafki,
        do card:
            inout KartaTechnicznaSzafki
    ) {
        guard drawer.typFrontu == .wewnetrzny else {
            return
        }

        let sideInset =
            drawer.efektywneOdsuniecieOdScianBocznychMM

        guard sideInset > 0.5 else {
            return
        }

        let railLength =
            min(
                drawer.nominalnaDlugoscMM,
                max(
                    geometry.glebokoscMM
                    - drawer.efektywneCofniecieOdFrontuMM,
                    0
                )
            )
        let stripWidth =
            minimalnaSzerokoscListwyDystansowejMM
        let material =
            card.materialKorpusu
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
            ? "Materiał korpusu"
            : card.materialKorpusu

        for side in [
            "lewa",
            "prawa"
        ] {
            card
                .efektywneElementy
                .append(
                    ElementTechnicznySzafki(
                        etykieta:
                            "\(drawer.etykieta)-DST-\(side.uppercased())",
                        typ:
                            .listwa,
                        nazwa:
                            "Listwa dystansowa prowadnicy \(side)",
                        dlugoscMM:
                            max(
                                railLength,
                                120
                            ),
                        szerokoscMM:
                            stripWidth,
                        gruboscMM:
                            sideInset,
                        ilosc:
                            1,
                        material:
                            material,
                        kierunek:
                            .poziomy,
                        uwagi:
                            "\(autoDrawerMarker) \(drawer.id.uuidString) • Szuflada wewnętrzna za frontem. Listwa odsuwa prowadnicę o \(format(sideInset)) mm od boku; pierwszy otwór prowadnicy wg rysunku montażowego. Przy dystansie >18 mm wykonać pakiet dystansowy albo użyć dedykowanego adaptera producenta."
                    )
                )
        }
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
            let sideInset =
                drawer
                    .efektywneOdsuniecieOdScianBocznychMM

            let railLength =
                min(
                    max(
                        drawer
                            .nominalnaDlugoscMM,
                        0
                    ),
                    max(
                        side.szerokoscMM
                        - setback,
                        0
                    )
                )
            let lineA =
                isRight
                ? max(
                    side.szerokoscMM
                    - setback
                    - railLength,
                    0
                )
                : min(
                    setback,
                    side.szerokoscMM
                )
            let lineB =
                isRight
                ? max(
                    side.szerokoscMM
                    - setback,
                    0
                )
                : min(
                    setback
                    + railLength,
                    side.szerokoscMM
                )

            card
                .efektywneElementy[
                    index
                ]
                .efektywneLinieWiercenia
                .append(
                    LiniaWierceniaSzafki(
                        element:
                            side.nazwa,
                        typ:
                            .osProwadnicySzuflady,
                        strona:
                            .wewnetrzna,
                        xStartMM:
                            min(lineA, lineB),
                        xEndMM:
                            max(lineA, lineB),
                        yMM: y,
                        etykieta:
                            drawer.etykieta,
                        opis:
                            "AUTO-SZUFLADA: \(drawer.etykieta) • \(profil.producent) \(profil.rodzina) • linia prowadnicy L=\(format(drawer.nominalnaDlugoscMM)) mm • cofnięcie od frontu \(format(setback)) mm • odsunięcie od boku \(format(sideInset)) mm"
                    )
                )

            let holeOffsets =
                otworyBazoweProwadnicyMM(
                    nominalnaDlugoscMM:
                        drawer
                            .nominalnaDlugoscMM,
                    glebokoscBokuMM:
                        side
                            .szerokoscMM,
                    cofniecieOdFrontuMM:
                        setback
                )

            for (
                holeIndex,
                offset
            ) in holeOffsets
                .enumerated()
            {
                let x =
                    isRight
                    ? max(
                        side.szerokoscMM
                        - setback
                        - offset,
                        0
                    )
                    : min(
                        setback
                        + offset,
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
                            srednicaMM: 2.5,
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
                                "AUTO-SZUFLADA: \(drawer.etykieta) • \(profil.producent) \(profil.rodzina) • punkt bazowy prowadnicy H\(holeIndex + 1), X=\(format(offset)) mm od frontu prowadnicy • potwierdzić z konkretnym SKU"
                        )
                    )
            }
        }
    }

    private static func replacingAutoDrawerBlock(
        in text: String,
        drawers:
            [SzufladaModulu],
        profile:
            ProfilAkcesoriumMeblowego
    ) -> String {
        var result =
            text

        while let start =
            result.range(
                of:
                    autoDrawerBlockStart
            ),
              let end =
                result.range(
                    of:
                        autoDrawerBlockEnd,
                    range:
                        start.upperBound
                        ..< result.endIndex
                ) {
            result.removeSubrange(
                start.lowerBound
                ..< end.upperBound
            )
        }

        let active =
            drawers
                .filter(\.aktywna)

        guard !active.isEmpty else {
            return result
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
        }

        let internalDrawers =
            active
                .filter {
                    $0.typFrontu
                    == .wewnetrzny
                }
        var lines = [
            autoDrawerBlockStart,
            "Szuflady: \(active.count) × \(profile.producent) \(profile.rodzina) \(profile.model)"
        ]

        if let first = active.first {
            lines.append(
                "Prowadnica: NL \(format(first.nominalnaDlugoscMM)) mm"
                    + (first.niewykorzystanaGlebokoscMM.map {
                        "; niewykorzystana głębokość \(format($0)) mm"
                    } ?? "")
            )
            if first.wymagaPotwierdzeniaSKUProwadnicy == true {
                lines.append(
                    "Prowadnica: konkretny SKU potwierdzić w tabeli producenta; kalkulator wskazuje wymiar, nie model."
                )
            }
        }

        if !internalDrawers.isEmpty {
            let spacerCount =
                internalDrawers
                    .filter {
                        $0.efektywneOdsuniecieOdScianBocznychMM > 0.5
                    }
                    .count * 2
            lines.append(
                "Szuflady za frontem: \(internalDrawers.count) szt.; listwy dystansowe L/P: \(spacerCount) szt."
            )
            lines.append(
                "Montaż: pierwszy otwór prowadnicy według rysunku, dalsze otwory według szablonu/SKU producenta."
            )

            for drawer in internalDrawers {
                lines.append(
                    "- \(drawer.etykieta): cofnięcie \(format(drawer.efektywneCofniecieOdFrontuMM)) mm, dystans boczny \(format(drawer.efektywneOdsuniecieOdScianBocznychMM)) mm/strona."
                )
            }
        }

        lines.append(autoDrawerBlockEnd)

        let trimmed =
            result
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
        let block =
            lines.joined(
                separator:
                    "\n"
            )

        if trimmed.isEmpty {
            return block
        }

        return [
            trimmed,
            block
        ]
        .joined(separator: "\n\n")
    }

    private static func otworyBazoweProwadnicyMM(
        nominalnaDlugoscMM:
            Double,
        glebokoscBokuMM:
            Double,
        cofniecieOdFrontuMM:
            Double
    ) -> [Double] {
        let dostepnaDlugosc =
            min(
                max(
                    nominalnaDlugoscMM,
                    0
                ),
                max(
                    glebokoscBokuMM
                    - cofniecieOdFrontuMM,
                    0
                )
            )
        let roboczeX =
            [
                37.0,
                128.0,
                256.0,
                448.0
            ]

        let wynik =
            roboczeX
                .filter {
                    $0 <= dostepnaDlugosc - 12
                }

        return wynik.isEmpty
            ? [
                min(
                    37,
                    max(
                        dostepnaDlugosc / 2,
                        0
                    )
                )
            ]
            : wynik
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
        regulaSzufladyZaFrontem(
            w: card
        )
        .zeroProtrusion
    }

    private static func regulaSzufladyZaFrontem(
        w card:
            KartaTechnicznaSzafki
    ) -> RegulaSzufladyZaFrontem {
        profilZawiasuFrontu(
            card
        )?
        .regulaSzufladyZaFrontem
        ?? .standard110
    }

    private static func profilZawiasuFrontu(
        _ card:
            KartaTechnicznaSzafki
    ) -> ProfilAkcesoriumMeblowego? {
        card
            .efektywneAkcesoria
            .compactMap {
                accessory
                    -> ProfilAkcesoriumMeblowego? in

                if let profile =
                    KatalogRegulAkcesoriow
                        .profil(
                            id: accessory
                                .profilID
                        ),
                   profile
                    .kategoria == .zawias {
                    return profile
                }

                guard accessory
                    .kategoria == .zawias
                else {
                    return nil
                }

                return KatalogRegulAkcesoriow
                    .profil(
                        id: accessory
                            .profilID
                    )
            }
            .first
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

    /// Dobór wymiaru wynika z geometrii karty. Profil dostarcza wyłącznie
    /// drabinkę dostępnych długości; wynik nadal wymaga potwierdzenia
    /// konkretnego SKU, bo kalkulator nie wybiera modelu producenta.
    private static func doborProwadnicy(
        profil: ProfilAkcesoriumMeblowego?,
        w card: KartaTechnicznaSzafki
    ) -> FrontHardwareCalculator.RunnerSelection? {
        let drabinka = profil?.dozwoloneDlugosciMM
            .filter { $0 > 0 }
            .map(Millimeters.init(_:))
        let dostepneDlugosci: [Millimeters]
        if let drabinka, !drabinka.isEmpty {
            dostepneDlugosci = drabinka
        } else {
            dostepneDlugosci = FrontHardwareCalculator.runnerLengths
        }

        return FrontHardwareCalculator.selectRunner(
            forCabinetDepth: Millimeters(card.glebokoscMM),
            availableLengths: dostepneDlugosci
        )
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
