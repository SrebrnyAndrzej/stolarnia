import Foundation
import Testing
@testable import DomainCore

struct DrawerFrontStackTests {

    private typealias Stos = DrawerFrontStack

    /// **Reguła, na której stoi wszystko:** fronty zawsze wypełniają strefę
    /// co do milimetra. To jest ta wada, od której zaczęła się ta klasa —
    /// układ 140/140/280 w module 900 zostawiał 340 mm bryły bez frontu.
    @Test
    func frontyZawszeWypelniajaStrefeCoDoMilimetra() {
        let tryby: [Stos.Mode] = [
            .equal,
            .proportional([140, 140, 280]),
            .fixedWithFlexible([140, 140, 280], flexibleIndex: 2)
        ]
        for wysokosc in [Millimeters(560), 720, 900, 1_100, 483, 1_237] {
            for tryb in tryby {
                let r = Stos.heights(zoneHeight: wysokosc, count: 3, mode: tryb)
                #expect(!r.heights.isEmpty)
                #expect(Stos.fillsExactly(heights: r.heights, zoneHeight: wysokosc),
                        "\(wysokosc) \(tryb): \(r.heights)")
            }
        }
    }

    /// Podwyższenie mebla skaluje fronty, zamiast zostawiać stare wymiary.
    @Test
    func podwyzszenieMeblaSkalujeFronty() {
        let niski = Stos.heights(
            zoneHeight: 560, count: 3, mode: .proportional([140, 140, 280]))
        let wysoki = Stos.heights(
            zoneHeight: 900, count: 3, mode: .proportional([140, 140, 280]))

        #expect(wysoki.heights.reduce(Millimeters.zero, +)
                > niski.heights.reduce(Millimeters.zero, +))
        #expect(Stos.fillsExactly(heights: wysoki.heights, zoneHeight: 900))
    }

    /// Tryb proporcjonalny zachowuje zamysł projektanta: 1:1:2 zostaje 1:1:2.
    @Test
    func trybProporcjonalnyZachowujeStosunki() {
        let r = Stos.heights(
            zoneHeight: 1_000, count: 3, mode: .proportional([140, 140, 280]))
        let h = r.heights.map(\.rawValue)
        #expect(abs(h[0] - h[1]) <= 1, "dwa pierwsze mają być równe: \(h)")
        // Trzeci ma być ok. dwa razy wyższy; tolerancja na rozdział reszty.
        #expect(abs(h[2] / h[0] - 2.0) < 0.02, "stosunek 1:2 zgubiony: \(h)")
    }

    /// Tryb sztywny trzyma wymiar użytkowy górnych szuflad, a różnicę wchłania
    /// wskazana szuflada — tak robi się, gdy 140 mm to sztućce.
    @Test
    func trybSztywnyTrzymaWymiaryAResztaIdzieWJednaSzuflade() {
        let r = Stos.heights(
            zoneHeight: 900, count: 3,
            mode: .fixedWithFlexible([140, 140, 280], flexibleIndex: 2))
        let h = r.heights.map(\.rawValue)
        #expect(h[0] == 140)
        #expect(h[1] == 140)
        #expect(h[2] > 280, "elastyczna miała wchłonąć różnicę: \(h)")
        #expect(Stos.fillsExactly(heights: r.heights, zoneHeight: 900))
    }

    /// Gdy sztywne wysokości nie zostawiają miejsca na elastyczną, układ
    /// przechodzi na proporcje **i mówi o tym**, zamiast dać front 20 mm.
    @Test
    func zaCiasnyUkladSztywnyWracaDoProporcjiZOstrzezeniem() {
        // 340 − 3 − 3 − 2×4 = 326 dostępnego; sztywne 140+140 = 280,
        // więc na elastyczną zostaje 46 mm — poniżej progu 70.
        let r = Stos.heights(
            zoneHeight: 340, count: 3,
            mode: .fixedWithFlexible([140, 140, 280], flexibleIndex: 2))
        #expect(r.issues.contains { $0.severity == .warning })
        #expect(Stos.fillsExactly(heights: r.heights, zoneHeight: 340))
    }

    /// Zmniejszenie mebla nie wyrzuca układu — proporcje zostają zachowane.
    /// Wcześniej kod cicho wracał do równego podziału i projektant tracił pracę.
    @Test
    func zmniejszenieMeblaNieGubiUkladu() {
        let r = Stos.heights(
            zoneHeight: 420, count: 3, mode: .proportional([140, 140, 280]))
        let h = r.heights.map(\.rawValue)
        #expect(abs(h[0] - h[1]) <= 1)
        #expect(h[2] > h[0], "proporcja zgubiona przy zmniejszeniu: \(h)")
    }

    /// Za niski front to ostrzeżenie — uchwyt nie ma się gdzie zmieścić.
    @Test
    func zaNiskiFrontJestOstrzezeniem() {
        // 250 − 6 − 3×4 = 232 dostępnego, po 58 mm na front — poniżej progu 70.
        // Przy 300 mm wychodzi dokładnie 70, czyli jeszcze bez ostrzeżenia.
        let r = Stos.heights(zoneHeight: 250, count: 4, mode: .equal)
        #expect(r.issues.contains {
            $0.severity == .warning && $0.message.contains("poniżej")
        })
    }

    /// Strefa, w której nie mieszczą się nawet fugi, jest błędem, nie cichym zerem.
    @Test
    func zaNiskaStrefaJestBledem() {
        let r = Stos.heights(zoneHeight: 10, count: 4, mode: .equal)
        #expect(r.heights.isEmpty)
        #expect(r.issues.contains { $0.severity == .error })
    }

    /// Liczba szuflad wygrywa z długością podanej listy — dodanie szuflady
    /// nie może zostawić układu z poprzednią liczbą frontów.
    @Test
    func liczbaSzufladWygrywaZDlugosciaListy() {
        let r = Stos.heights(
            zoneHeight: 900, count: 4, mode: .proportional([140, 140, 280]))
        #expect(r.heights.count == 4)
        #expect(Stos.fillsExactly(heights: r.heights, zoneHeight: 900))
    }

    /// Wysokości są pełnymi milimetrami — hurtownia nie tnie na dziesiąte części.
    @Test
    func wysokosciSaPelnymiMilimetrami() {
        for wysokosc in [Millimeters(721), 913, 1_004] {
            let r = Stos.heights(
                zoneHeight: wysokosc, count: 3, mode: .proportional([1, 1, 2]))
            for h in r.heights {
                #expect(h.rawValue == h.rawValue.rounded(), "\(h) nie jest całkowite")
            }
        }
    }

    // MARK: - Maksymalna liczba frontów

    /// Limit liczby szuflad ma wynikać z wysokości, a nie z wpisanej liczby.
    ///
    /// W oknie szuflad stało `1...30` przy liczniku i `>= 10` przy dodawaniu —
    /// dwie różne wartości wzięte z powietrza. Trzydzieści frontów w szafce
    /// pod blatem to fronty po kilkanaście milimetrów.
    @Test
    func maksymalnaLiczbaWynikaZWysokosciStrefy() {
        // 720 − 3 − 3 = 714 użytecznej. Front min. 70 + fuga 4 = 74 na sztukę,
        // plus ostatnia bez fugi: (714 + 4) / 74 = 9,7 → 9.
        #expect(Stos.maximumCount(zoneHeight: 720) == 9)

        // Słupek mieści więcej niż szafka pod blatem — to jest cały powód,
        // dla którego limit nie może być jedną stałą dla obu.
        let slupek = Stos.maximumCount(zoneHeight: 2_000)
        #expect(slupek > Stos.maximumCount(zoneHeight: 720))
    }

    /// Przy tylu frontach, ile daje `maximumCount`, układ musi się jeszcze
    /// zmieścić — inaczej limit obiecywałby coś, czego generator nie zrobi.
    @Test
    func ukladNaGranicyLimituNadalWypelniaStrefe() {
        let wysokosc = Millimeters(720)
        let n = Stos.maximumCount(zoneHeight: wysokosc)
        let wynik = Stos.heights(zoneHeight: wysokosc, count: n, mode: .equal)

        #expect(wynik.heights.count == n)
        #expect(Stos.fillsExactly(heights: wynik.heights, zoneHeight: wysokosc))
        for h in wynik.heights {
            #expect(h >= Stos.minimumFrontHeight,
                    "front \(h) poniżej minimum przy limicie \(n)")
        }
    }

    /// Strefa niższa niż jeden minimalny front nie mieści żadnego.
    @Test
    func strefaBezMiejscaNaFrontDajeZero() {
        #expect(Stos.maximumCount(zoneHeight: 60) == 0)
    }
}

/// Dane systemów szuflad zweryfikowane wobec katalogów producentów
/// (`scraper/catalogs/`), nie wobec pamięci ani wyszukiwarki.
struct DrawerSystemDataTests {

    /// GTV AXIS PRO ma pięć wysokości boku: 69, 86, **120**, 168, 200.
    /// Aplikacja miała 116 — wariant, którego producent nie robi.
    @Test func gtvMaWysokosciZKatalogu() {
        let wysokosci = DrawerProfile.catalog(for: .gtvAxisPro)
            .map(\.profileHeight.rawValue).sorted()
        #expect(wysokosci == [69, 86, 120, 168, 200])
        #expect(!DrawerProfile.catalog(for: .gtvAxisPro).contains { $0.name == "H116" })
    }

    /// Amix Slim Box zgadza się z katalogiem co do dziesiątej milimetra.
    @Test func amixMaWysokosciZKatalogu() {
        let wysokosci = DrawerProfile.catalog(for: .amixSlimbox)
            .map(\.profileHeight.rawValue).sorted()
        #expect(wysokosci == [62.5, 88, 126, 172, 238])
    }

    /// Każdy system ma **własną** drabinkę długości — dobieranie „najbliższej
    /// okrągłej" kończy się zamówieniem prowadnicy, której producent nie robi.
    @Test func kazdySystemMaWlasnaDrabinkeDlugosci() {
        #expect(DrawerProfile.nominalLengths(for: .gtvAxisPro).contains(250))
        #expect(!DrawerProfile.nominalLengths(for: .amixSlimbox).contains(250))
        #expect(DrawerProfile.nominalLengths(for: .blumLegrabox).contains(650))
        #expect(!DrawerProfile.nominalLengths(for: .gtvAxisPro).contains(650))
    }

    /// Prowadnica wymaga NL + 22 mm głębokości wewnętrznej.
    /// Korpus 560 mieści 500 (500 + 22 = 522 ≤ 560), ale nie 550.
    @Test func prowadnicaWymagaZapasuGlebokosci() {
        let nl = DrawerProfile.nominalLength(
            for: .gtvAxisPro, cabinetInnerDepth: 560)
        #expect(nl == Millimeters(500))

        for system in DrawerSystem.allCases {
            for glebokosc in [Millimeters(300), 400, 500, 560, 600, 650] {
                guard let dobrana = DrawerProfile.nominalLength(
                    for: system, cabinetInnerDepth: glebokosc) else { continue }
                #expect(dobrana + DrawerProfile.requiredDepthMargin <= glebokosc,
                        "\(system) \(dobrana) w korpusie \(glebokosc)")
            }
        }
    }

    /// Za płytki korpus nie dostaje prowadnicy na siłę.
    @Test func zaPlytkiKorpusNieDostajeProwadnicy() {
        #expect(DrawerProfile.nominalLength(
            for: .gtvAxisPro, cabinetInnerDepth: 200) == nil)
    }
}

/// Sprzężenie długości prowadnicy z głębokością korpusu.
///
/// To jest reguła, na której stoi pewność przy zamawianiu: projektant ustawia
/// głębokość mebla, a aplikacja mówi, jaką prowadnicę zamówić. Pomyłka tutaj
/// kończy się prowadnicą, która nie wchodzi albo której producent nie robi.
struct DoborProwadnicyDoGlebokosciTests {

    /// Korpus 560 mieści prowadnicę 500, nie 550.
    ///
    /// Reguła NL + 22 mm: przy świetle 557 mm (560 − 3 mm pleców) zostaje
    /// 535 mm na prowadnicę, więc 550 nie wchodzi.
    @Test
    func korpus560MiesciProwadnice500() {
        let swiatlo = Millimeters(560) - ProductionRules.backPanelThickness
        let dobrana = DrawerProfile.nominalLength(
            for: .gtvAxisPro,
            cabinetInnerDepth: swiatlo
        )
        #expect(dobrana == Millimeters(500), "wyszło: \(String(describing: dobrana))")
    }

    /// Dobrana prowadnica zawsze mieści się w świetle z wymaganym zapasem.
    @Test
    func dobranaProwadnicaZawszeMiesciSieZZapasem() {
        for system in DrawerSystem.allCases {
            for glebokosc in stride(from: 300.0, through: 700.0, by: 10.0) {
                let swiatlo = Millimeters(glebokosc)
                guard let nl = DrawerProfile.nominalLength(
                    for: system, cabinetInnerDepth: swiatlo
                ) else { continue }

                #expect(
                    nl + DrawerProfile.requiredDepthMargin <= swiatlo,
                    "\(system) przy świetle \(glebokosc) dobrał NL \(nl)"
                )
                #expect(
                    DrawerProfile.nominalLengths(for: system).contains(nl),
                    "\(system): NL \(nl) nie jest w drabince producenta"
                )
            }
        }
    }

    /// Za płytki korpus nie dostaje prowadnicy „na siłę".
    ///
    /// Zwrócenie najkrótszej mimo braku miejsca byłoby gorsze niż `nil` —
    /// projektant zamówiłby sztukę, która nie wchodzi.
    @Test
    func zaPlytkiKorpusNieDostajeProwadnicy() {
        for system in DrawerSystem.allCases {
            let najkrotsza = DrawerProfile.nominalLengths(for: system).min()!
            let zaMalo = najkrotsza + DrawerProfile.requiredDepthMargin - Millimeters(1)
            #expect(
                DrawerProfile.nominalLength(for: system, cabinetInnerDepth: zaMalo) == nil,
                "\(system) dobrał prowadnicę przy świetle \(zaMalo)"
            )
        }
    }
}


/// Lista okuć i edytor muszą dobierać **tę samą** prowadnicę.
///
/// Pierwsza wersja `hardwareList()` liczyła z pełnej głębokości korpusu,
/// a edytor ze światła (głębokość minus plecy). Przy 522 mm dawało to
/// odpowiednio NL 500 i NL 450 — czyli lista zamawiała prowadnicę, która
/// nie wchodzi. Różnica jest wąska (kilka milimetrów na szczebel), więc
/// łatwo ją przeoczyć bez testu na granicach.
struct ZgodnoscDoboruProwadnicyTests {

    @Test
    func listaOkucLiczyZeSwiatla() throws {
        // 522 − 3 mm pleców = 519 mm światła. NL 500 wymaga 522 → nie wchodzi.
        let modul = ElevationModule(
            name: "Dolna 600 · płytka",
            width: 600, height: 720, depth: 522,
            zones: [ElevationZone(kind: .drawers, drawerCount: 3)]
        )

        let prowadnica = try #require(
            modul.hardwareList().first { $0.kind == .drawerRunner }
        )
        #expect(prowadnica.dimension == Millimeters(450),
                "zamówiono NL \(prowadnica.dimension) — nie zmieści się")
    }

    /// Na całym zakresie głębokości lista nigdy nie zamawia prowadnicy
    /// dłuższej, niż mieści światło korpusu.
    @Test
    func listaNigdyNieZamawiaZaDlugiejProwadnicy() {
        for glebokosc in stride(from: 320.0, through: 700.0, by: 1.0) {
            let modul = ElevationModule(
                name: "test",
                width: 600, height: 720, depth: Millimeters(glebokosc),
                zones: [ElevationZone(kind: .drawers, drawerCount: 2)]
            )
            guard let prowadnica = modul.hardwareList()
                .first(where: { $0.kind == .drawerRunner })
            else { continue }

            let swiatlo = Millimeters(glebokosc) - ProductionRules.backPanelThickness
            #expect(
                prowadnica.dimension + DrawerProfile.requiredDepthMargin <= swiatlo,
                "głębokość \(glebokosc): NL \(prowadnica.dimension) nie mieści się w świetle \(swiatlo)"
            )
        }
    }
}
