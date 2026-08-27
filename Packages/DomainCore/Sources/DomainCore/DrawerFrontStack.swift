import Foundation

/// Rozkłada fronty szuflad na wysokości strefy tak, żeby **zawsze ją wypełniały**.
///
/// Powstało z konkretnej wady zgłoszonej przez warsztat: po zmianie wysokości
/// mebla fronty szuflad zostawały na starych wymiarach. Kod robił:
///
/// ```swift
/// if sum <= availableHeight { return custom }   // bez skalowania
/// ```
///
/// Układ `[140, 140, 280]` sumuje się do 560 mm. W module 900 mm oznaczało to
/// **340 mm bryły bez frontu** — a przy zmniejszeniu mebla poniżej sumy układ
/// był po cichu wyrzucany i zastępowany równym podziałem, czyli projektant
/// tracił to, co ustawił.
///
/// Reguła jest jedna i nie ma od niej wyjątku:
///
/// ```
/// suma frontów + fuga × (n − 1) + luz dolny + luz górny = wysokość strefy
/// ```
///
/// Front, który tego nie spełnia, albo zostawia szparę, albo się nie domknie.
/// Dlatego wszystkie tryby poniżej kończą **dokładnym dopasowaniem do
/// milimetra**, a reszta z zaokrągleń jest rozdawana, nie gubiona.
public enum DrawerFrontStack {

    /// Jak układ ma się zachować przy zmianie wysokości mebla.
    public enum Mode: Hashable, Sendable {
        /// Wszystkie fronty równe.
        case equal
        /// Zadane wysokości traktowane jako **proporcje**.
        ///
        /// Układ `[140, 140, 280]` to stosunek 1:1:2 i po podwyższeniu mebla
        /// zostaje 1:1:2. To jest domyślne zachowanie, bo zachowuje zamysł
        /// projektanta: „dwie płytkie u góry, jedna głęboka na dole".
        case proportional([Millimeters])
        /// Zadane wysokości **utrzymywane co do milimetra**, a różnicę wchłania
        /// jedna szuflada.
        ///
        /// Tego chce się, gdy górne szuflady mają trzymać wymiar użytkowy
        /// (sztućce w 140 mm), a głęboka ma po prostu urosnąć.
        case fixedWithFlexible([Millimeters], flexibleIndex: Int)
    }

    public struct Result: Hashable, Sendable {
        public var heights: [Millimeters]
        public var issues: [ProductionIssue]

        public init(heights: [Millimeters], issues: [ProductionIssue]) {
            self.heights = heights
            self.issues = issues
        }
    }

    // MARK: - Granice technologiczne

    /// Najniższy sensowny front szuflady.
    ///
    /// Poniżej tego uchwyt nie ma się gdzie zmieścić, a szuflada przestaje być
    /// użyteczna — zostaje szczelina.
    public static let minimumFrontHeight: Millimeters = 70

    /// Najwyższy front pojedynczej szuflady.
    ///
    /// Powyżej tego skrzynka robi się nieporęczna i ciężka przy pełnym
    /// obciążeniu; w praktyce dzieli się ją wtedy na dwie.
    public static let maximumFrontHeight: Millimeters = 400

    /// Ile szuflad ma sens w **jednej strefie** elewacji.
    ///
    /// Strefa to jeden poziom podziału modułu, a nie cała szafka — moduł może
    /// mieć kilka stref szuflad jedna nad drugą. Sześć w jednej strefie to
    /// granica praktyczna: przy typowej wysokości ciągu dolnego siódmy front
    /// schodzi poniżej `minimumFrontHeight`.
    ///
    /// Ta wartość była wpisana liczbą w dwóch miejscach `ElevationZone`
    /// i w kontrolce kreatora. Trzymamy ją tutaj, bo obok stoją pozostałe
    /// granice technologiczne szuflad.
    public static let drawersPerZone: ClosedRange<Int> = 1...6

    /// Ile frontów **faktycznie** zmieści się w strefie o danej wysokości.
    ///
    /// Osobno od `drawersPerZone`, bo to inne pytanie: tamto jest granicą
    /// sensu dla jednej strefy elewacji, to jest twardą arytmetyką wysokości.
    /// Słupek 2000 mm pomieści więcej szuflad niż szafka pod blatem i limit
    /// interfejsu nie powinien tego przesądzać za projektanta — ale front
    /// poniżej `minimumFrontHeight` nie ma gdzie zmieścić uchwytu.
    public static func maximumCount(
        zoneHeight: Millimeters,
        gap: Millimeters = ProductionRules.frontToFrontGap,
        bottomMargin: Millimeters = 3,
        topMargin: Millimeters = 3
    ) -> Int {
        let dostepne = zoneHeight - bottomMargin - topMargin
        guard dostepne > .zero else { return 0 }
        // n frontów potrzebuje n × min + (n − 1) × fuga, czyli
        // n × (min + fuga) − fuga ≤ dostępne.
        let krok = minimumFrontHeight.rawValue + gap.rawValue
        guard krok > 0 else { return 0 }
        return max(Int(((dostepne.rawValue + gap.rawValue) / krok).rounded(.down)), 0)
    }

    // MARK: - Rozkład

    /// Zwraca wysokości frontów wypełniające strefę **dokładnie**.
    ///
    /// - Parameters:
    ///   - zoneHeight: wysokość strefy w świetle frontu.
    ///   - count: liczba szuflad.
    ///   - mode: zachowanie przy zmianie wysokości.
    ///   - gap: fuga między frontami.
    ///   - bottomMargin/topMargin: luzy skrajne strefy.
    public static func heights(
        zoneHeight: Millimeters,
        count: Int,
        mode: Mode,
        gap: Millimeters = ProductionRules.frontToFrontGap,
        bottomMargin: Millimeters = 3,
        topMargin: Millimeters = 3
    ) -> Result {
        let n = max(count, 1)
        var uwagi: [ProductionIssue] = []

        let dostepne = zoneHeight
            - bottomMargin - topMargin
            - gap * Double(n - 1)

        guard dostepne > .zero else {
            return Result(heights: [], issues: [ProductionIssue(
                severity: .error,
                message: String(
                    format: "strefa %.0f mm nie pomieści %d frontów "
                        + "po odjęciu fug i luzów",
                    zoneHeight.rawValue, n),
                hint: "zmniejsz liczbę szuflad albo podwyższ strefę")])
        }

        let surowe: [Double]
        switch mode {
        case .equal:
            surowe = Array(repeating: dostepne.rawValue / Double(n), count: n)

        case .proportional(let zadane):
            surowe = proporcjonalnie(zadane, n: n, dostepne: dostepne.rawValue)

        case .fixedWithFlexible(let zadane, let elastyczny):
            surowe = zeSztywnymi(
                zadane, elastyczny: elastyczny,
                n: n, dostepne: dostepne.rawValue, uwagi: &uwagi)
        }

        let wysokosci = dopasujDoMilimetra(surowe, suma: dostepne.rawValue)
        uwagi += sprawdz(wysokosci, zoneHeight: zoneHeight, gap: gap,
                         bottomMargin: bottomMargin, topMargin: topMargin)

        return Result(heights: wysokosci.map(Millimeters.init(_:)), issues: uwagi)
    }

    // MARK: - Tryby

    private static func proporcjonalnie(
        _ zadane: [Millimeters], n: Int, dostepne: Double
    ) -> [Double] {
        let bazowe = uzupelnij(zadane, do: n)
        let suma = bazowe.reduce(0.0) { $0 + $1.rawValue }
        guard suma > 0 else {
            return Array(repeating: dostepne / Double(n), count: n)
        }
        // Skala liczona raz dla całego stosu — dzięki temu proporcje zostają
        // dokładnie zachowane, a nie „prawie".
        let skala = dostepne / suma
        return bazowe.map { $0.rawValue * skala }
    }

    private static func zeSztywnymi(
        _ zadane: [Millimeters], elastyczny: Int,
        n: Int, dostepne: Double, uwagi: inout [ProductionIssue]
    ) -> [Double] {
        let bazowe = uzupelnij(zadane, do: n).map(\.rawValue)
        let indeks = min(max(elastyczny, 0), n - 1)
        let sztywneSuma = bazowe.enumerated()
            .filter { $0.offset != indeks }
            .reduce(0.0) { $0 + $1.element }
        let reszta = dostepne - sztywneSuma

        if reszta < minimumFrontHeight.rawValue {
            uwagi.append(ProductionIssue(
                severity: .warning,
                message: String(
                    format: "szuflada elastyczna wyszłaby %.0f mm — poniżej "
                        + "minimum %.0f mm", reszta, minimumFrontHeight.rawValue),
                hint: "układ przeliczony proporcjonalnie zamiast sztywnego"))
            return proporcjonalnie(
                uzupelnij(zadane, do: n), n: n, dostepne: dostepne)
        }

        var wynik = bazowe
        wynik[indeks] = reszta
        return wynik
    }

    /// Uzupełnia albo przycina listę do wymaganej liczby szuflad.
    private static func uzupelnij(
        _ zadane: [Millimeters], do n: Int
    ) -> [Millimeters] {
        let czyste = zadane.filter { $0 > .zero }
        if czyste.count == n { return czyste }
        if czyste.count > n { return Array(czyste.prefix(n)) }
        // Brakujące pozycje dostają średnią z podanych — układ zostaje
        // rozpoznawalny, zamiast wracać do równego podziału.
        let srednia = czyste.isEmpty
            ? Millimeters(140)
            : Millimeters(czyste.reduce(0.0) { $0 + $1.rawValue } / Double(czyste.count))
        return czyste + Array(repeating: srednia, count: n - czyste.count)
    }

    // MARK: - Dokładne dopasowanie

    /// Zaokrągla wysokości do pełnych milimetrów tak, by **suma zgadzała się
    /// co do jednego**.
    ///
    /// Zaokrąglanie każdej pozycji osobno gubi albo dokłada milimetry i front
    /// przestaje domykać mebel. Dlatego zaokrąglamy w dół, a resztę rozdajemy
    /// po jednym milimetrze, zaczynając od najwyższych frontów — tam różnica
    /// jednego milimetra jest wizualnie nieodczuwalna.
    private static func dopasujDoMilimetra(
        _ surowe: [Double], suma docelowa: Double
    ) -> [Double] {
        guard !surowe.isEmpty else { return [] }
        var wynik = surowe.map { ($0).rounded(.down) }
        var reszta = Int((docelowa - wynik.reduce(0, +)).rounded())

        let kolejnosc = surowe.enumerated()
            .sorted { $0.element > $1.element }
            .map(\.offset)
        var i = 0
        while reszta > 0 {
            wynik[kolejnosc[i % kolejnosc.count]] += 1
            reszta -= 1
            i += 1
        }
        while reszta < 0 {
            wynik[kolejnosc[i % kolejnosc.count]] -= 1
            reszta += 1
            i += 1
        }
        return wynik
    }

    private static func sprawdz(
        _ wysokosci: [Double], zoneHeight: Millimeters, gap: Millimeters,
        bottomMargin: Millimeters, topMargin: Millimeters
    ) -> [ProductionIssue] {
        var uwagi: [ProductionIssue] = []
        for (i, h) in wysokosci.enumerated() {
            if h < minimumFrontHeight.rawValue {
                uwagi.append(ProductionIssue(
                    severity: .warning,
                    message: String(
                        format: "front %d ma %.0f mm — poniżej %.0f mm",
                        i + 1, h, minimumFrontHeight.rawValue),
                    hint: "uchwyt się nie zmieści; rozważ mniej szuflad"))
            }
            if h > maximumFrontHeight.rawValue {
                uwagi.append(ProductionIssue(
                    severity: .note,
                    message: String(
                        format: "front %d ma %.0f mm — powyżej %.0f mm",
                        i + 1, h, maximumFrontHeight.rawValue),
                    hint: "skrzynka będzie ciężka przy pełnym obciążeniu"))
            }
        }
        return uwagi
    }

    /// Sprawdza tożsamość, na której stoi cały mechanizm.
    ///
    /// Wystawione publicznie, bo to jest **reguła warsztatowa, nie szczegół
    /// implementacji** — każdy generator frontów powinien dać się nią zmierzyć.
    public static func fillsExactly(
        heights: [Millimeters],
        zoneHeight: Millimeters,
        gap: Millimeters = ProductionRules.frontToFrontGap,
        bottomMargin: Millimeters = 3,
        topMargin: Millimeters = 3,
        tolerance: Double = 0.5
    ) -> Bool {
        guard !heights.isEmpty else { return false }
        let suma = heights.reduce(Millimeters.zero, +)
            + gap * Double(heights.count - 1)
            + bottomMargin + topMargin
        return abs(suma.rawValue - zoneHeight.rawValue) <= tolerance
    }
}
