import Foundation

enum KatalogRegulAkcesoriow {
    static let profile:
        [ProfilAkcesoriumMeblowego] = [

            ProfilAkcesoriumMeblowego(
                id: "gtv.gx2a.h45.eco",
                producent: "GTV",
                rodzina: "GX2-A H45",
                model: "Pełny wysuw",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PK-0H45250GX2-A",
                    "PK-0H45300GX2-A",
                    "PK-0H45350GX2-A",
                    "PK-0H45400GX2-A",
                    "PK-0H45450GX2-A",
                    "PK-0H45500GX2-A",
                    "PK-0H45550GX2-A"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350, 400, 450, 500, 550
                ],
                regulaGrubosciDna: .brak(
                    "Dno i boki wykonywane indywidualnie; prowadnica boczna."
                ),
                regulaGrubosciTylu: .brak(
                    "Ścianka tylna zależy od konstrukcji skrzynki."
                ),
                regulaGrubosciBoku: .brak(
                    "Szerokość skrzynki: światło korpusu minus 25,4–26 mm."
                ),
                maksymalneObciazenieKG: 25,
                trwaloscCykle: 50_000,
                formulaSzuflady: FormulaWymiarowaniaSzuflady(
                    opis:
                        "Szerokość zewnętrzna skrzynki = światło korpusu - 25,4 mm. Korpus powinien być głębszy od prowadnicy o minimum 3–5 mm."
                ),
                funkcje: [
                    "Pełny wysuw",
                    "Montaż boczny",
                    "Wypinanie szuflady",
                    "Ocynkowana stal"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Domyślna prowadnica segmentu Eco.",
                    "Cena referencyjna dotyczy kompletu lewa + prawa, L=500 mm.",
                    "Dla ciężkich szuflad należy użyć wariantu PRO 50 kg."
                ],
                zrodlo:
                    "GTV GX2-A H45 — oficjalna karta produktu; raport techniczny 20.06.2026."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.prestige.h45.eco",
                producent: "GTV",
                rodzina: "PRESTIGE H45",
                model: "Pełny wysuw 35 kg",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PK-0-H45-250",
                    "PK-0-H45-300",
                    "PK-0-H45-350",
                    "PK-0-H45-400",
                    "PK-0-H45-450",
                    "PK-0-H45-500",
                    "PK-0-H45-550",
                    "PK-0-H45-600"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350, 400, 450, 500, 550, 600
                ],
                regulaGrubosciDna: .brak(
                    "Dno i boki wykonywane indywidualnie; prowadnica boczna."
                ),
                regulaGrubosciTylu: .brak(
                    "Ścianka tylna zależy od konstrukcji skrzynki."
                ),
                regulaGrubosciBoku: .brak(
                    "Szerokość skrzynki: światło korpusu minus 25,4–26 mm."
                ),
                maksymalneObciazenieKG: 35,
                trwaloscCykle: 60_000,
                formulaSzuflady: FormulaWymiarowaniaSzuflady(
                    opis:
                        "Szerokość zewnętrzna skrzynki = światło korpusu - 25,4 mm."
                ),
                funkcje: [
                    "Pełny wysuw",
                    "Montaż boczny",
                    "Wypinanie szuflady",
                    "Ocynkowana stal"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Ekonomiczna prowadnica do standardowych szuflad drewnianych.",
                    "Cena referencyjna dotyczy kompletu lewa + prawa, L=500 mm."
                ],
                zrodlo:
                    "GTV PRESTIGE H45 — oficjalna karta produktu; raport techniczny 20.06.2026."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.prestige.h45.selfclose",
                producent: "GTV",
                rodzina: "PRESTIGE H45",
                model: "Samodociąg",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PK-S-H45-250",
                    "PK-S-H45-300",
                    "PK-S-H45-350",
                    "PK-S-H45-400",
                    "PK-S-H45-450",
                    "PK-S-H45-500",
                    "PK-S-H45-550",
                    "PK-S-H45-600"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350, 400, 450, 500, 550, 600
                ],
                regulaGrubosciDna: .brak(
                    "Prowadnica boczna do skrzynki wykonywanej indywidualnie."
                ),
                regulaGrubosciTylu: .brak(
                    "Ścianka tylna zależy od konstrukcji skrzynki."
                ),
                regulaGrubosciBoku: .brak(
                    "Szerokość skrzynki: światło korpusu minus 25,4–26 mm."
                ),
                maksymalneObciazenieKG: 35,
                trwaloscCykle: 60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Samodociąg",
                    "Montaż boczny",
                    "Wypinanie szuflady"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wariant Eco+ dla projektów wymagających samodociągu.",
                    "Cena referencyjna dotyczy kompletu lewa + prawa, L=500 mm."
                ],
                zrodlo:
                    "GTV PRESTIGE H45 z samodociągiem — oficjalna karta produktu."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.pro.h45.50kg",
                producent: "GTV",
                rodzina: "PRO H45",
                model: "Pełny wysuw 50 kg",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PK-PRO-H45-300",
                    "PK-PRO-H45-400",
                    "PK-PRO-H45-450",
                    "PK-PRO-H45-500",
                    "PK-PRO-H45-550",
                    "PK-PRO-H45-600",
                    "PK-PRO-H45-650",
                    "PK-PRO-H45-700",
                    "PK-PRO-H45-750"
                ],
                dozwoloneDlugosciMM: [
                    300, 400, 450, 500, 550, 600, 650, 700, 750
                ],
                regulaGrubosciDna: .brak(
                    "Prowadnica boczna do skrzynki wykonywanej indywidualnie."
                ),
                regulaGrubosciTylu: .brak(
                    "Ścianka tylna zależy od konstrukcji skrzynki."
                ),
                regulaGrubosciBoku: .brak(
                    "Szerokość skrzynki: światło korpusu minus 25,4–26 mm."
                ),
                maksymalneObciazenieKG: 50,
                trwaloscCykle: 60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Nośność 50 kg",
                    "Montaż boczny",
                    "Wypinanie szuflady"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wariant wzmacniany do ciężkich szuflad i zastosowań warsztatowych.",
                    "Nie jest domyślną prowadnicą segmentu Eco."
                ],
                zrodlo:
                    "GTV PRO H45 — oficjalna karta produktu."
            ),

            ProfilAkcesoriumMeblowego(
                id: "gtv.axispro.softclose",
                producent: "GTV",
                rodzina: "AXIS PRO",
                model: "Soft close",
                kategoria: .systemSzuflady,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-AXISPRO-KPL450A",
                    "PB-AXISPRO-KPL450B",
                    "PB-AXISPRO-KPL450C",
                    "PB-AXISPRO-KPL450D"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350, 400,
                    450, 500, 550, 600
                ],
                dozwoloneWysokosciMM: [
                    86, 120, 168, 200
                ],
                regulaGrubosciDna:
                    .stala(
                        16,
                        opis:
                            "Elementy dna z płyty 16 mm."
                    ),
                regulaGrubosciTylu:
                    .stala(
                        16,
                        opis:
                            "Ścianka tylna z płyty 16 mm."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki stalowe systemowe."
                    ),
                maksymalneObciazenieKG:
                    40,
                trwaloscCykle:
                    60_000,
                formulaSzuflady:
                    FormulaWymiarowaniaSzuflady(
                        opis:
                            "Wymiary dna i tyłu należy pobrać z karty technicznej właściwego indeksu AXIS PRO."
                    ),
                progRelinguDlaFrontuMM:
                    284,
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Regulacja pionowa i pozioma",
                    "Regulacja pochylenia frontu"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Dla frontów wyższych niż 284 mm zalecany jest reling.",
                    "Warianty wysokości i długości należy potwierdzić dla konkretnego indeksu."
                ],
                zrodlo:
                    "GTV AXIS PRO — karta techniczna 06/2024 i katalog AXIS PRO."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.axispro.p2o",
                producent: "GTV",
                rodzina: "AXIS PRO",
                model: "Push to open",
                kategoria: .systemSzuflady,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-AXISPRO-P2O-KPL450A",
                    "PB-AXISPRO-P2O-KPL450B",
                    "PB-AXISPRO-P2O-KPL450C",
                    "PB-AXISPRO-P2O-KPL450D"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350, 400,
                    450, 500, 550, 600
                ],
                dozwoloneWysokosciMM: [
                    69, 86, 120, 168, 200
                ],
                regulaGrubosciDna:
                    .stala(
                        16,
                        opis:
                            "Zalecana grubość dna 16 mm."
                    ),
                regulaGrubosciTylu:
                    .stala(
                        16,
                        opis:
                            "Ścianka tylna z płyty 16 mm."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki stalowe systemowe."
                    ),
                maksymalneObciazenieKG:
                    40,
                trwaloscCykle:
                    60_000,
                minimalnaWysokoscKorpusuMM:
                    100,
                formulaSzuflady:
                    FormulaWymiarowaniaSzuflady(
                        redukcjaSynchronizatoraMM:
                            127,
                        opis:
                            "Pręt synchronizujący: SPP = LW - 127 mm."
                    ),
                wymagaSynchronizatoraGdySzerokoscPrzekraczaDlugosc:
                    true,
                progRelinguDlaFrontuMM:
                    284,
                funkcje: [
                    "Pełny wysuw",
                    "Push to open",
                    "Synchronizacja otwierania",
                    "Regulacja pionowa i pozioma"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Minimalna szczelina frontu dla P2O: 2,5 mm.",
                    "Gdy szerokość szuflady przekracza nominalną długość prowadnicy, zalecany jest synchronizator.",
                    "Wariant H69 ma minimalną wysokość korpusu 100 mm."
                ],
                zrodlo:
                    "GTV AXIS PRO Push to open — oficjalna karta techniczna."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.modernbox.softclose",
                producent: "GTV",
                rodzina: "MODERN BOX",
                model: "Soft close",
                kategoria: .systemSzuflady,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-D-KPL350A",
                    "PB-D-KPL350B",
                    "PB-D-KPL350C"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350,
                    400, 450, 500, 550
                ],
                dozwoloneWysokosciMM: [
                    68, 83, 146, 210
                ],
                regulaGrubosciDna:
                    .potwierdzenie(
                        "Grubość dna należy sprawdzić w karcie technicznej konkretnego indeksu."
                    ),
                regulaGrubosciTylu:
                    .potwierdzenie(
                        "Grubość tyłu zależy od wybranego zestawu i łączników."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki stalowe systemowe."
                    ),
                maksymalneObciazenieKG:
                    40,
                trwaloscCykle:
                    60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Synchronizacja toru jazdy",
                    "Regulacja pionowa i pozioma ±2 mm"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Dostępne fronty nakładane, wpuszczane i wewnętrzne.",
                    "Dostępne relingi, boki perforowane i organizery."
                ],
                zrodlo:
                    "GTV MODERN BOX — oficjalna karta produktu."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.modernbox.square",
                producent: "GTV",
                rodzina: "MODERN BOX Square",
                model: "Soft close",
                kategoria: .systemSzuflady,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-KW-KPL250C2"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350,
                    400, 450, 500, 550
                ],
                dozwoloneWysokosciMM: [
                    83, 146, 210
                ],
                regulaGrubosciDna:
                    .potwierdzenie(
                        "Sprawdź kartę techniczną właściwego zestawu."
                    ),
                regulaGrubosciTylu:
                    .potwierdzenie(
                        "Sprawdź kartę techniczną właściwego zestawu."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki stalowe systemowe."
                    ),
                maksymalneObciazenieKG:
                    40,
                trwaloscCykle:
                    60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Regulacja pionowa i pozioma",
                    "Regulacja pochylenia frontu"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                zrodlo:
                    "GTV MODERN BOX Square — oficjalna karta produktu."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.modernslide.3d.softclose",
                producent: "GTV",
                rodzina: "Modern Slide 3D",
                model: "Soft close",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-3D0SHX18-450-H"
                ],
                dozwoloneDlugosciMM: [
                    300, 350, 400,
                    450, 500, 550
                ],
                regulaGrubosciBoku:
                    .zakres(
                        16,
                        19,
                        opis:
                            "Bok drewnianej szuflady 16–19 mm."
                    ),
                maksymalneObciazenieKG:
                    30,
                trwaloscCykle:
                    60_000,
                formulaSzuflady:
                    FormulaWymiarowaniaSzuflady(
                        redukcjaSzerokosciDnaMM:
                            49,
                        redukcjaDlugosciDnaMM:
                            10,
                        zapasGlebokosciKorpusuMM:
                            10,
                        opis:
                            "SKW = LW - 49 mm; SKL = NL - 10 mm."
                    ),
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Regulacja 3D",
                    "Szuflada standardowa i wewnętrzna"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                zrodlo:
                    "GTV Prowadnice — karta Modern Slide 3D."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.0shx.softclose",
                producent: "GTV",
                rodzina: "0SHX",
                model: "Dolny montaż, soft close",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-0SHX-350-A"
                ],
                dozwoloneDlugosciMM: [
                    250, 270, 300, 350,
                    400, 450, 500, 550, 600
                ],
                regulaGrubosciBoku:
                    .stala(
                        16,
                        opis:
                            "Prowadnica przeznaczona do płyty 16 mm."
                    ),
                maksymalneObciazenieKG:
                    35,
                trwaloscCykle:
                    60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Regulacja pionowa 0–3 mm",
                    "Montaż nasuwany"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                zrodlo:
                    "GTV Prowadnice — oficjalny katalog 0SHX."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.0fpo18.p2o",
                producent: "GTV",
                rodzina: "0FPO18",
                model: "Dolny montaż, push to open",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-0FPO18-350"
                ],
                dozwoloneDlugosciMM: [
                    250, 300, 350, 400,
                    450, 500, 550, 600
                ],
                regulaGrubosciBoku:
                    .zakres(
                        16,
                        19,
                        opis:
                            "Bok drewnianej szuflady 16–19 mm."
                    ),
                maksymalneObciazenieKG:
                    25,
                trwaloscCykle:
                    60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Push to open",
                    "Regulacja 3D",
                    "Opcjonalny stabilizator"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                zrodlo:
                    "GTV Prowadnice — oficjalny katalog 0FPO18."
            ),
            ProfilAkcesoriumMeblowego(
                id: "gtv.g10hx.softclose",
                producent: "GTV",
                rodzina: "G10HX",
                model: "Dolny montaż, soft close",
                kategoria: .prowadnica,
                status: .oficjalnaDokumentacja,
                indeksyPrzykladowe: [
                    "PB-G10HX-450-H"
                ],
                dozwoloneDlugosciMM: [
                    300, 350, 400,
                    450, 500, 550
                ],
                regulaGrubosciBoku:
                    .stala(
                        16,
                        opis:
                            "Prowadnica przeznaczona do płyty 16 mm."
                    ),
                maksymalneObciazenieKG:
                    25,
                trwaloscCykle:
                    60_000,
                formulaSzuflady:
                    FormulaWymiarowaniaSzuflady(
                        redukcjaSzerokosciDnaMM:
                            42,
                        redukcjaDlugosciDnaMM:
                            10,
                        zapasGlebokosciKorpusuMM:
                            3,
                        opis:
                            "SKW = LW - 42 mm; SKL = NL - 10 mm."
                    ),
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Regulacja pionowa 0–4 mm",
                    "Montaż nakładany"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                zrodlo:
                    "GTV Prowadnice — oficjalny katalog G10HX."
            ),
            ProfilAkcesoriumMeblowego(
                id: "hafele.minifix15",
                producent: "Häfele",
                rodzina: "Minifix",
                model: "Minifix 15",
                kategoria:
                    .zlaczeKonstrukcyjne,
                status:
                    .dokumentBranzowy,
                regulaGrubosciBoku:
                    .zakres(
                        15,
                        26,
                        opis:
                            "Wariant złącza należy dobrać do grubości płyty."
                    ),
                srednicaPuszkiMM:
                    15,
                funkcje: [
                    "Złącze mimośrodowe",
                    "Wielokrotny montaż i demontaż"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .wieniecGorny,
                    .wieniecDolny,
                    .dno,
                    .polka
                ],
                uwagi: [
                    "Dla płyt 15–16 mm typowa głębokość gniazda to 12 mm.",
                    "Dla płyt od 18 mm stosuje się warianty około 13,5–14 mm.",
                    "Wymiar od krawędzi zależy od trzpienia 24 lub 34 mm."
                ],
                zrodlo:
                    "Przesłana dokumentacja techniczna okuć."
            ),
            ProfilAkcesoriumMeblowego(
                id: "hafele.rafix20",
                producent: "Häfele",
                rodzina: "Rafix",
                model: "Rafix 20",
                kategoria:
                    .zlaczeKonstrukcyjne,
                status:
                    .dokumentBranzowy,
                regulaGrubosciBoku:
                    .zakres(
                        16,
                        26
                    ),
                srednicaPuszkiMM:
                    20,
                funkcje: [
                    "Złącze półek i wieńców",
                    "Montaż od góry"
                ],
                elementyDocelowe: [
                    .polka,
                    .wieniecGorny,
                    .wieniecDolny,
                    .dno
                ],
                uwagi: [
                    "Dla płyty od 16 mm typowa głębokość wynosi 12,7 mm.",
                    "Dla wybranych wariantów płyt 19–26 mm stosuje się około 14,2 mm."
                ],
                zrodlo:
                    "Przesłana dokumentacja techniczna okuć."
            ),
            ProfilAkcesoriumMeblowego(
                id: "hettich.vb",
                producent: "Hettich",
                rodzina: "VB",
                model: "VB 35 / VB 36",
                kategoria:
                    .zlaczeKonstrukcyjne,
                status:
                    .wymagaPotwierdzenia,
                regulaGrubosciBoku:
                    .wybor(
                        [16, 19],
                        opis:
                            "Dobierz wariant VB do grubości płyty."
                    ),
                elementyDocelowe: [
                    .wieniecGorny,
                    .wieniecDolny,
                    .dno,
                    .polka
                ],
                uwagi: [
                    "Geometria wiercenia zależy od dokładnego modelu VB."
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "volpato.leg.standard",
                producent: "Volpato",
                rodzina: "Nóżki kuchenne",
                model: "H100 / H150",
                kategoria:
                    .nozkaIPodpora,
                status:
                    .dokumentBranzowy,
                dozwoloneWysokosciMM: [
                    100, 120, 150
                ],
                maksymalneObciazenieKG:
                    400,
                funkcje: [
                    "Regulacja wysokości",
                    "Klips cokołu"
                ],
                elementyDocelowe: [
                    .dno,
                    .wieniecDolny,
                    .cokół
                ],
                uwagi: [
                    "Nośność należy potwierdzić dla konkretnego modelu i sposobu mocowania."
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "hafele.axilo",
                producent: "Häfele / Würth",
                rodzina: "Axilo",
                model: "Stopka regulowana",
                kategoria:
                    .nozkaIPodpora,
                status:
                    .dokumentBranzowy,
                funkcje: [
                    "Regulacja od czoła",
                    "Regulacja przez otwór od góry"
                ],
                elementyDocelowe: [
                    .dno,
                    .wieniecDolny
                ],
                uwagi: [
                    "Wariant wciskowy może wymagać gniazda Ø35 mm."
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "camar.306",
                producent: "Camar",
                rodzina: "Regulator poziomu",
                model: "306",
                kategoria:
                    .nozkaIPodpora,
                status:
                    .dokumentBranzowy,
                funkcje: [
                    "Regulacja kluczem SW6",
                    "Montaż w boku płyty"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .dno
                ],
                uwagi: [
                    "Minimalna grubość płyty i nośność zależą od konkretnego wariantu."
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "blum.cliptop.110",
                producent: "Blum",
                rodzina: "CLIP top BLUMOTION",
                model: "110°",
                kategoria:
                    .zawias,
                status:
                    .dokumentBranzowy,
                regulaGrubosciBoku:
                    .zakres(
                        16,
                        26,
                        opis:
                            "Zakres frontu zależy od konkretnego indeksu."
                    ),
                katOtwarciaStopnie:
                    110,
                srednicaPuszkiMM:
                    35,
                funkcje: [
                    "Cichy domyk",
                    "Regulacja 3D",
                    "Montaż CLIP"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wymiar C i głębokość puszki muszą pochodzić z karty konkretnego zawiasu."
                ],
                regulaSzufladyZaFrontem:
                    .standard110,
                zrodlo:
                    "Przesłana dokumentacja techniczna okuć."
            ),
            ProfilAkcesoriumMeblowego(
                id: "blum.cliptop.155.zero",
                producent: "Blum",
                rodzina: "CLIP top BLUMOTION",
                model: "155° zero protrusion",
                kategoria:
                    .zawias,
                status:
                    .dokumentBranzowy,
                katOtwarciaStopnie:
                    155,
                srednicaPuszkiMM:
                    35,
                funkcje: [
                    "Zerowy uskok",
                    "Cichy domyk",
                    "Do szuflad wewnętrznych i cargo"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                regulaSzufladyZaFrontem:
                    .zeroProtrusion155,
                zrodlo:
                    "Blum Hinge systems, 2024: CLIP top BLUMOTION 155° zero protrusion do szafek z szufladami wewnętrznymi."
            ),
            ProfilAkcesoriumMeblowego(
                id: "blum.cliptop.125.zero",
                producent: "Blum",
                rodzina: "CLIP top BLUMOTION",
                model: "125° zero protrusion",
                kategoria:
                    .zawias,
                status:
                    .oficjalnaDokumentacja,
                katOtwarciaStopnie:
                    125,
                srednicaPuszkiMM:
                    35,
                funkcje: [
                    "Zerowy uskok",
                    "Do wewnętrznych roll-outów",
                    "Cichy domyk zależnie od wariantu"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Reguła dopuszcza roll-out/cargo za drzwiami; pełne szuflady wewnętrzne wymagają 155° albo potwierdzenia konkretnego SKU."
                ],
                regulaSzufladyZaFrontem:
                    .zeroProtrusion125RollOut,
                zrodlo:
                    "Blum Hinge systems, 2024: 125° zero protrusion jako rozwiązanie dla interior roll-outs."
            ),
            ProfilAkcesoriumMeblowego(
                id: "salice.silentia",
                producent: "Salice",
                rodzina: "Silentia+",
                model: "Zawias z tłumieniem",
                kategoria:
                    .zawias,
                status:
                    .wymagaPotwierdzenia,
                srednicaPuszkiMM:
                    35,
                funkcje: [
                    "Podwójny tłumik",
                    "Regulacja 3D"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Kąt, głębokość puszki i zakres grubości frontu zależą od indeksu."
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "amix.fgv.175",
                producent: "AMIX / FGV",
                rodzina: "Zawias szerokokątny",
                model: "175°",
                kategoria:
                    .zawias,
                status:
                    .wymagaPotwierdzenia,
                katOtwarciaStopnie:
                    175,
                srednicaPuszkiMM:
                    35,
                funkcje: [
                    "Szeroki kąt otwarcia",
                    "Soft close zależnie od wariantu"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                regulaSzufladyZaFrontem:
                    RegulaSzufladyZaFrontem(
                        zeroProtrusion: false,
                        dopuszczaSzufladyWewnetrzne: false,
                        dopuszczaRollOut: false,
                        minimalnyKatOtwarciaStopnie: 155,
                        zalecaneOdsuniecieOdZawiasuMM: 50,
                        zalecaneOdsuniecieOdStronyWolnejMM: 0,
                        dodatkowyLuzBezpieczenstwaMM: 0,
                        wymagaPotwierdzeniaSKU: true,
                        opis:
                            "Szeroki kąt otwarcia nie oznacza automatycznie zero-protrusion. Do szuflad za frontem wymagaj karty konkretnego zawiasu."
                    ),
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "italiana.kimana",
                producent: "Italiana Ferramenta",
                rodzina: "Kimana",
                model: "Zawias barkowy",
                kategoria:
                    .zawias,
                status:
                    .dokumentBranzowy,
                srednicaPuszkiMM:
                    26,
                funkcje: [
                    "Front otwierany do dołu",
                    "Symetryczne gniazda w dnie i froncie"
                ],
                elementyDocelowe: [
                    .front,
                    .dno,
                    .wieniecDolny
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "blum.aventos.hf",
                producent: "Blum",
                rodzina: "AVENTOS",
                model: "HF",
                kategoria:
                    .podnosnikFrontu,
                status:
                    .dokumentBranzowy,
                minimalnaGlebokoscSwiatlaMM:
                    264,
                funkcje: [
                    "Front składany dwuczęściowy",
                    "BLUMOTION",
                    "Dobór według współczynnika LF"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Dobór siłownika zależy od wysokości korpusu oraz łącznej masy frontów i uchwytów."
                ],
                zrodlo:
                    "Przesłana dokumentacja techniczna okuć."
            ),
            ProfilAkcesoriumMeblowego(
                id: "kessebohmer.lemans2",
                producent: "Kesseböhmer",
                rodzina: "Le Mans II",
                model: "System narożny",
                kategoria:
                    .systemNarozny,
                status:
                    .dokumentBranzowy,
                maksymalneObciazenieKG:
                    25,
                minimalnaGlebokoscSwiatlaMM:
                    500,
                funkcje: [
                    "Czteropunktowa kinematyka",
                    "ClickFixx",
                    "Kierunek lewy lub prawy"
                ],
                elementyDocelowe: [
                    .dno,
                    .wieniecGorny,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wymagane światło frontu i szerokość korpusu zależą od wariantu tacy.",
                    "W dokumentacji pokaż kopertę ruchu półek, ogranicznik kąta otwarcia i linie wierceń z szablonu producenta."
                ],
                zrodlo:
                    "Kesseböhmer LeMans, dokumentacja produktowa producenta."
            ),
            ProfilAkcesoriumMeblowego(
                id: "kessebohmer.magiccorner",
                producent: "Kesseböhmer",
                rodzina: "Magic Corner",
                model: "System do ślepego narożnika",
                kategoria:
                    .systemNarozny,
                status:
                    .dokumentBranzowy,
                maksymalneObciazenieKG:
                    32,
                minimalnaGlebokoscSwiatlaMM:
                    500,
                funkcje: [
                    "Kosze frontowe i tylna strefa wysuwu",
                    "SoftSTOPP",
                    "Kierunek lewy lub prawy"
                ],
                elementyDocelowe: [
                    .dno,
                    .wieniecGorny,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wymaga blendy/pull przy ślepym narożniku oraz opisanej martwej strefy za sąsiednim modułem.",
                    "W dokumentacji pokaż podział na część frontową, część tylną, kopertę wysuwu i linie wierceń producenta."
                ],
                zrodlo:
                    "Kesseböhmer Magic Corner, dokumentacja produktowa producenta."
            ),
            ProfilAkcesoriumMeblowego(
                id: "kessebohmer.revo90",
                producent: "Kesseböhmer",
                rodzina: "REVO 90",
                model: "Karuzela narożna",
                kategoria:
                    .systemNarozny,
                status:
                    .dokumentBranzowy,
                maksymalneObciazenieKG:
                    57,
                minimalnaGlebokoscSwiatlaMM:
                    560,
                funkcje: [
                    "Obrót w obie strony",
                    "Korpus narożny 80/90 cm",
                    "Regulacja wysokości półek"
                ],
                elementyDocelowe: [
                    .dno,
                    .wieniecGorny,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wymaga osi obrotu, kontroli promienia półek i światła wysokości dla kolumny.",
                    "W dokumentacji pokaż położenie trzpienia/kolumny, promień półek oraz ograniczenia obrotu."
                ],
                zrodlo:
                    "Kesseböhmer REVO 90, dokumentacja produktowa producenta."
            ),
            ProfilAkcesoriumMeblowego(
                id: "agd.ventilation.200",
                producent: "Norma projektowa",
                rodzina: "Wentylacja AGD",
                model: "Kanał konwekcyjny",
                kategoria:
                    .wentylacjaAGD,
                status:
                    .dokumentBranzowy,
                minimalnaPowierzchniaWentylacjiCM2:
                    200,
                funkcje: [
                    "Wlot w cokole",
                    "Wylot nad korpusem",
                    "Kanał za urządzeniem"
                ],
                elementyDocelowe: [
                    .cokół,
                    .plecy,
                    .wieniecGorny,
                    .wieniecDolny
                ],
                uwagi: [
                    "Rzeczywisty wolny przekrój kratki musi uwzględniać lamele.",
                    "Instrukcja konkretnego urządzenia AGD ma pierwszeństwo."
                ],
                zrodlo:
                    "Przesłany raport technologiczny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "push.tipon.generic",
                producent: "Wielu producentów",
                rodzina: "Push / TIP-ON",
                model: "Mechanizm bezuchwytowy",
                kategoria:
                    .mechanizmBezuchwytowy,
                status:
                    .wymagaPotwierdzenia,
                funkcje: [
                    "Otwarcie przez naciśnięcie",
                    "Wymagana szczelina robocza"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Szczelina, skok wyrzutnika i pozycja wiercenia zależą od modelu."
                ],
                zrodlo:
                    "Profil ogólny do zastąpienia kartą producenta."
            ),
            ProfilAkcesoriumMeblowego(
                id: "cabinet.hanger.generic",
                producent: "Wielu producentów",
                rodzina: "Zawieszka szafki",
                model: "Regulowana",
                kategoria:
                    .zawieszkaSzafki,
                status:
                    .wymagaPotwierdzenia,
                funkcje: [
                    "Regulacja pionowa",
                    "Regulacja głębokości",
                    "Listwa montażowa"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .plecy,
                    .wieniecGorny
                ],
                uwagi: [
                    "Nośność, liczba zawieszek i wiercenia muszą wynikać z konkretnego systemu."
                ],
                zrodlo:
                    "Profil ogólny."
            ),
            ProfilAkcesoriumMeblowego(
                id: "led.profile.generic",
                producent: "Wielu producentów",
                rodzina: "Profil LED",
                model: "Wpustowy / nawierzchniowy",
                kategoria:
                    .oswietlenie,
                status:
                    .wymagaPotwierdzenia,
                funkcje: [
                    "Kanał przewodu",
                    "Profil aluminiowy",
                    "Osłona"
                ],
                elementyDocelowe: [
                    .polka,
                    .wieniecDolny,
                    .wieniecGorny,
                    .scianaBoczna
                ],
                uwagi: [
                    "Frez, głębokość i odprowadzanie ciepła zależą od profilu."
                ],
                zrodlo:
                    "Profil ogólny."
            ),
            // MARK: - Systemy szuflad

            ProfilAkcesoriumMeblowego(
                id: "blum.tandembox.antaro",
                producent: "Blum",
                rodzina: "Tandembox Antaro",
                model: "Soft close",
                kategoria: .systemSzuflady,
                status: .dokumentBranzowy,
                dozwoloneDlugosciMM: [
                    270, 300, 350, 400,
                    450, 500, 550, 600
                ],
                dozwoloneWysokosciMM: [
                    86, 126, 186
                ],
                regulaGrubosciDna:
                    .stala(
                        16,
                        opis:
                            "Dno HDF 16 mm montowane w boczniku stalowym."
                    ),
                regulaGrubosciTylu:
                    .stala(
                        16,
                        opis:
                            "Tylna płyta HDF/melamin 16 mm."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki stalowe systemowe Blum."
                    ),
                maksymalneObciazenieKG:
                    50,
                trwaloscCykle:
                    100_000,
                formulaSzuflady:
                    FormulaWymiarowaniaSzuflady(
                        opis:
                            "Wymiary dna i tyłu wg karty technicznej właściwego indeksu TANDEMBOX."
                    ),
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk Blumotion",
                    "Regulacja 3D",
                    "Klips CLIP",
                    "Boki białe lub stalowe"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Wariant Antaro do kuchni i łazienek.",
                    "Cena referencyjna: komplet L=500 mm, H86."
                ],
                zrodlo:
                    "Blum Tandembox Antaro — dokumentacja techniczna 2026."
            ),
            ProfilAkcesoriumMeblowego(
                id: "blum.legrabox.pure",
                producent: "Blum",
                rodzina: "Legrabox Pure",
                model: "Soft close",
                kategoria: .systemSzuflady,
                status: .dokumentBranzowy,
                dozwoloneDlugosciMM: [
                    270, 300, 350, 400,
                    450, 500, 550, 600, 650
                ],
                dozwoloneWysokosciMM: [
                    58, 86, 126, 186
                ],
                regulaGrubosciDna:
                    .stala(
                        16,
                        opis:
                            "Dno HDF 16 mm."
                    ),
                regulaGrubosciTylu:
                    .stala(
                        16,
                        opis:
                            "Tył 16 mm HDF/MDF."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki systemowe Blum, grubość 13 mm."
                    ),
                maksymalneObciazenieKG:
                    70,
                trwaloscCykle:
                    150_000,
                funkcje: [
                    "Pełny wysuw",
                    "Blumotion cichy domyk",
                    "Regulacja 3D",
                    "Boki cienkie 13 mm",
                    "Dostępny biały, antracyt, stalowy"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "Flagowy system szuflad Blum — segment Premium/VIP.",
                    "Cena referencyjna: komplet L=500 mm, H86."
                ],
                zrodlo:
                    "Blum Legrabox Pure — dokumentacja techniczna 2026."
            ),
            ProfilAkcesoriumMeblowego(
                id: "amix.fgv.drawbox",
                producent: "Amix / FGV",
                rodzina: "DrawBox",
                model: "Soft close",
                kategoria: .systemSzuflady,
                status: .wymagaPotwierdzenia,
                dozwoloneDlugosciMM: [
                    300, 350, 400,
                    450, 500, 550
                ],
                dozwoloneWysokosciMM: [
                    86, 120, 168
                ],
                regulaGrubosciDna:
                    .stala(
                        16,
                        opis:
                            "Dno 16 mm HDF."
                    ),
                regulaGrubosciTylu:
                    .stala(
                        16,
                        opis:
                            "Tył 16 mm HDF."
                    ),
                regulaGrubosciBoku:
                    .brak(
                        "Boki stalowe systemowe."
                    ),
                maksymalneObciazenieKG:
                    35,
                trwaloscCykle:
                    60_000,
                funkcje: [
                    "Pełny wysuw",
                    "Cichy domyk",
                    "Regulacja 3D"
                ],
                elementyDocelowe: [
                    .szuflada,
                    .scianaBoczna
                ],
                uwagi: [
                    "System ekonomiczny — segment Eco.",
                    "Cena referencyjna: komplet L=450 mm."
                ],
                zrodlo:
                    "Profil uśredniony na podstawie danych rynkowych 2026."
            ),

            // MARK: - Zawiasy

            ProfilAkcesoriumMeblowego(
                id: "gtv.zawias.110.standard",
                producent: "GTV",
                rodzina: "Zawias puszkowy",
                model: "110° standard",
                kategoria: .zawias,
                status: .wymagaPotwierdzenia,
                katOtwarciaStopnie: 110,
                srednicaPuszkiMM: 35,
                funkcje: [
                    "Montaż na płycie 16–19 mm",
                    "Nakładany lub wpuszczany",
                    "Bez tłumienia"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Zawias bez cichego domyku — segment Eco.",
                    "Cena referencyjna za 1 szt."
                ],
                regulaSzufladyZaFrontem:
                    .standard110,
                zrodlo:
                    "Profil rynkowy — zawias puszkowy GTV 110°."
            ),

            // MARK: - Elementy montażowe

            ProfilAkcesoriumMeblowego(
                id: "listwa.montazowa.szafek",
                producent: "Wielu producentów",
                rodzina: "Listwa montażowa",
                model: "Szafki wiszące / UNICLICK",
                kategoria: .zawieszkaSzafki,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Montaż do ściany",
                    "Zawieszenie szafek górnych",
                    "Regulacja poziomowania"
                ],
                elementyDocelowe: [
                    .wieniecGorny,
                    .plecy
                ],
                uwagi: [
                    "Cena za 1 mb listwy stalowej.",
                    "Typowe długości odcinków: 1250 mm lub 2000 mm."
                ],
                zrodlo:
                    "Profil rynkowy — listwa montażowa UNICLICK lub stalowa."
            ),

            // MARK: - Drążki i rozety

            ProfilAkcesoriumMeblowego(
                id: "drazek.garderobowy.komplet",
                producent: "Wielu producentów",
                rodzina: "Drążek garderobowy",
                model: "Okrągły Ø25 mm + 2 rozety",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Montaż do bocznic lub do ściany",
                    "Komplet z rozetami 2 szt.",
                    "Chromowany, biały lub antracyt"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .wieniecGorny
                ],
                uwagi: [
                    "Cena za 1 mb z rozetami.",
                    "Do szafy garderobianej — 1 drążek na każdy segment 60 cm."
                ],
                zrodlo:
                    "Profil rynkowy — drążek garderobowy Ø25 mm z rozetami."
            ),

            // MARK: - Podpory półek

            ProfilAkcesoriumMeblowego(
                id: "podpora.polki.5mm",
                producent: "Wielu producentów",
                rodzina: "Podpora półki",
                model: "Kielichowa Ø5 mm",
                kategoria: .nozkaIPodpora,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Montaż w otwór Ø5 mm",
                    "Nośność do 50 kg / szt."
                ],
                elementyDocelowe: [
                    .polka,
                    .scianaBoczna
                ],
                uwagi: [
                    "Cena za 1 szt.",
                    "4 szt. na każdą półkę regulowaną."
                ],
                zrodlo:
                    "Profil rynkowy — kołek półkowy kielichowy Ø5 mm."
            ),

            // MARK: - Oświetlenie LED

            ProfilAkcesoriumMeblowego(
                id: "zasilacz.led.30w",
                producent: "Wielu producentów",
                rodzina: "Zasilacz LED",
                model: "12 V / 30 W",
                kategoria: .oswietlenie,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Wyjście 12 V DC",
                    "Do 2–3 m taśmy LED 5050",
                    "Montaż ukryty w szafce"
                ],
                elementyDocelowe: [
                    .wieniecDolny,
                    .wieniecGorny
                ],
                uwagi: [
                    "1 zasilacz na ok. 2,5 m taśmy LED.",
                    "Cena za 1 szt."
                ],
                zrodlo:
                    "Profil rynkowy — zasilacz LED 12 V 30 W."
            ),
            ProfilAkcesoriumMeblowego(
                id: "tasma.led.neutral",
                producent: "Wielu producentów",
                rodzina: "Taśma LED",
                model: "Neutral white 5050",
                kategoria: .oswietlenie,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "4000–4500 K, neutral white",
                    "Gęstość 60 LED/m",
                    "Samoprzylepna strona"
                ],
                elementyDocelowe: [
                    .wieniecDolny,
                    .polka,
                    .wieniecGorny
                ],
                uwagi: [
                    "Cena za 1 mb.",
                    "Do stosowania z profilem LED aluminiowym i zasilaczem 12 V."
                ],
                zrodlo:
                    "Profil rynkowy — taśma LED 5050 neutral white."
            ),

            // MARK: - Cokół i mocowania

            ProfilAkcesoriumMeblowego(
                id: "cokol.pvc.100mm",
                producent: "Wielu producentów",
                rodzina: "Cokół PVC",
                model: "H100 mm",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Wykończenie frontu korpusów dolnych",
                    "Montaż na klipsach do nóżek"
                ],
                elementyDocelowe: [
                    .cokół
                ],
                uwagi: [
                    "Cena za 1 mb.",
                    "Dostępny biały, wenge, dąb, antracyt.",
                    "Standardowa listwa cięta na wymiar na budowie."
                ],
                zrodlo:
                    "Profil rynkowy — cokół PVC H100 mm."
            ),
            ProfilAkcesoriumMeblowego(
                id: "klips.cokolu",
                producent: "Wielu producentów",
                rodzina: "Klips cokołu",
                model: "Do nóżki meblowej H100",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Montaż na nóżce meblowej",
                    "Retencja cokołu PVC"
                ],
                elementyDocelowe: [
                    .cokół
                ],
                uwagi: [
                    "Cena za 1 szt.",
                    "Szacunek: 4 klipsy na każdy mb cokołu."
                ],
                zrodlo:
                    "Profil rynkowy — klips cokołu meblowego."
            ),

            // MARK: - Elementy złączne (wkręty)

            ProfilAkcesoriumMeblowego(
                id: "wkret.zawias.3x16",
                producent: "Wielu producentów",
                rodzina: "Wkręt meblowy",
                model: "3,5×16 mm do zawiasów",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Mocowanie zawiasów do płyty 16–19 mm",
                    "Łeb stożkowy PZ2"
                ],
                elementyDocelowe: [
                    .front,
                    .scianaBoczna
                ],
                uwagi: [
                    "Cena za 1 szt. Pakowany po 100 szt.",
                    "Użyj 2 szt. na każdy zawias."
                ],
                zrodlo:
                    "Profil rynkowy — wkręt 3,5×16 mm do zawiasów."
            ),
            ProfilAkcesoriumMeblowego(
                id: "wkret.matrix.pro",
                producent: "Würth / Wielu",
                rodzina: "Wkręt samonawiercający",
                model: "Matrix Pro 4,2×16 mm",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Samonawiercający — bez wiercenia pilotowego",
                    "Do blach, prowadnic, profili stalowych"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .wieniecGorny,
                    .wieniecDolny
                ],
                uwagi: [
                    "Cena za 1 szt. Pakowany po 200 szt.",
                    "Użyj ok. 4 szt. na moduł (prowadnice, zasilacze, listwy)."
                ],
                zrodlo:
                    "Profil rynkowy — wkręt Matrix Pro 4,2×16 mm."
            ),
            ProfilAkcesoriumMeblowego(
                id: "wkret.lacznik.3x30",
                producent: "Wielu producentów",
                rodzina: "Wkręt łącznikowy",
                model: "3,5×30 mm",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Łączenie korpusów ze sobą",
                    "Mocowanie tylnej ściany do korpusu"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .plecy
                ],
                uwagi: [
                    "Cena za 1 szt. Pakowany po 200 szt.",
                    "Użyj ok. 8–12 szt. na moduł."
                ],
                zrodlo:
                    "Profil rynkowy — wkręt łącznikowy 3,5×30 mm."
            ),

            // MARK: - Systemy przesuwne

            ProfilAkcesoriumMeblowego(
                id: "prowadnica.szafy.przesuwan",
                producent: "GTV / Forte / Sevroll",
                rodzina: "Prowadnica przesuwna",
                model: "Górna + dolna, 1 skrzydło",
                kategoria: .prowadnica,
                status: .wymagaPotwierdzenia,
                dozwoloneDlugosciMM: [
                    1000, 1200, 1600,
                    2000, 2400
                ],
                maksymalneObciazenieKG: 70,
                funkcje: [
                    "Prowadnica górna + dolna",
                    "1 skrzydło drzwi przesuwnych",
                    "Cichy domyk opcjonalnie"
                ],
                elementyDocelowe: [
                    .wieniecGorny,
                    .wieniecDolny,
                    .plecy
                ],
                uwagi: [
                    "Komplet na 1 skrzydło drzwi.",
                    "Do szafy 2-drzwiowej potrzebne 2 komplety.",
                    "Rama aluminiowa drzwi sprzedawana osobno."
                ],
                zrodlo:
                    "Profil rynkowy — prowadnica szafy przesuwnej."
            ),

            // MARK: - Obrzeże ABS

            ProfilAkcesoriumMeblowego(
                id: "obrzeze.abs.standard",
                producent: "EGGER / Rehau",
                rodzina: "Obrzeże ABS",
                model: "1 × 22 mm standard",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Oklejanie krawędzi płyt meblowych",
                    "Grubość 1 mm, szerokość 22 mm",
                    "Dopasowanie kolorystyczne do płyty"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .wieniecGorny,
                    .wieniecDolny
                ],
                uwagi: [
                    "Sprzedawane na metry bieżące lub rolki 50 mb.",
                    "Zamów z 10% naddatkiem na odpady cięcia.",
                    "Do klejenia na okleiniarce lub ręcznie żelazkiem."
                ],
                zrodlo:
                    "Profil rynkowy — obrzeże ABS 1×22 mm standard; research 25.06.2026."
            ),

            ProfilAkcesoriumMeblowego(
                id: "obrzeze.abs.premium",
                producent: "EGGER / Rehau",
                rodzina: "Obrzeże ABS premium",
                model: "2 × 23 mm synchronizowane",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Obrzeże synchronizowane z dekorem frontu lub płyty premium",
                    "Grubość 2 mm, szerokość 23 mm",
                    "Efekt Softtouch lub wysoki połysk"
                ],
                elementyDocelowe: [
                    .scianaBoczna,
                    .front
                ],
                uwagi: [
                    "Stosowane w segmencie premium i VIP.",
                    "Kolor i tekstura synchronizowana z dekorem płyty (SU-efekt).",
                    "Cena za 1 mb; sprzedaż na metry lub rolki 25 mb."
                ],
                zrodlo:
                    "Profil rynkowy — obrzeże ABS 2×23 mm premium/synchronized; research 25.06.2026."
            ),

            // MARK: - Uchwyty meblowe

            ProfilAkcesoriumMeblowego(
                id: "uchwyt.bar.standard",
                producent: "GTV / JUSTOR",
                rodzina: "Uchwyt meblowy",
                model: "Klamkowy 96–128 mm stalowy",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Uchwyt klamkowy do frontów szafek i szuflad",
                    "Rozstaw otworów 96–128 mm",
                    "Stal chromowana lub satyna"
                ],
                elementyDocelowe: [
                    .front
                ],
                uwagi: [
                    "1 szt. na każdy front drzwiczek lub szuflady.",
                    "Cena za 1 szt. bez wkrętów montażowych.",
                    "Wkręty M4×35 mm dobierz osobno."
                ],
                zrodlo:
                    "Profil rynkowy — uchwyt klamkowy standard; research 25.06.2026."
            ),

            ProfilAkcesoriumMeblowego(
                id: "uchwyt.bar.premium",
                producent: "GTV premium / Viefe / Furnipart",
                rodzina: "Uchwyt meblowy premium",
                model: "Klamkowy 160–256 mm aluminium",
                kategoria: .inne,
                status: .wymagaPotwierdzenia,
                funkcje: [
                    "Uchwyt designerski do frontów premium i VIP",
                    "Rozstaw otworów 160–256 mm",
                    "Szczotkowane aluminium lub stal nierdzewna"
                ],
                elementyDocelowe: [
                    .front
                ],
                uwagi: [
                    "1 szt. na każdy front.",
                    "Segment premium i VIP.",
                    "Cena za 1 szt."
                ],
                zrodlo:
                    "Profil rynkowy — uchwyt klamkowy premium/designerski; research 25.06.2026."
            ),

            // MARK: - Akcesorium domyślne

            ProfilAkcesoriumMeblowego(
                id: "custom.accessory.generic",
                producent: "Własny",
                rodzina: "Akcesorium niestandardowe",
                model: "Do uzupełnienia",
                kategoria:
                    .inne,
                status:
                    .wymagaPotwierdzenia,
                funkcje: [
                    "Ręczne przypisanie do szafki lub elementu",
                    "Dokumentacja przez uwagi projektu"
                ],
                uwagi: [
                    "Wpisz numer katalogowy, producenta, parametry i wymagania montażowe w uwagach projektu.",
                    "Nie zatwierdzaj do realizacji bez karty technicznej producenta."
                ],
                zrodlo:
                    "Profil rezerwowy dla akcesoriów nieujętych w katalogu."
            )
        ]

    static func profil(
        id: String
    ) -> ProfilAkcesoriumMeblowego? {
        profile.first {
            $0.id == id
        }
    }

    static func profile(
        kategoria:
            KategoriaAkcesoriumMeblowego?
    ) -> [ProfilAkcesoriumMeblowego] {
        profile
            .filter {
                guard let kategoria else {
                    return true
                }
                return $0.kategoria
                    == kategoria
            }
            .sorted {
                if $0.producent
                    == $1.producent {
                    return $0.rodzina
                        .localizedCaseInsensitiveCompare(
                            $1.rodzina
                        )
                        == .orderedAscending
                }

                return $0.producent
                    .localizedCaseInsensitiveCompare(
                        $1.producent
                    )
                    == .orderedAscending
            }
    }
}
