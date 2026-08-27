import Foundation

/// Konwencje warsztatu w jednym miejscu.
///
/// Powstało dlatego, że ta sama zasada była zapisana w siedmiu plikach i nigdzie
/// się nie zgadzała: `CabinetBuilders` liczyło front jako `width - frontGap * 2`
/// przy `frontGap = 2`, `DrawerLayoutCalculator` miał własne `frontGap = 3`,
/// a `UstawieniaKonstrukcyjneStolarni.szczelinaFrontowMM` było wyświetlane
/// w panelu ustawień i nie wpływało na nic.
///
/// **Uwaga na nazewnictwo — to źródło realnego błędu.** „Szczelina" znaczy w tym
/// projekcie dwie różne rzeczy i wartości różnią się dwukrotnie:
///
/// - `frontClearancePerEdge` — luz **na jedno lico**, o tyle front jest cofnięty
///   od krawędzi korpusu. To jest to, co przyjmuje parametr `frontGap`.
/// - `frontToFrontGap` — fuga **między dwoma sąsiednimi frontami**, czyli suma
///   dwóch luzów.
///
/// Kto poda 4 tam, gdzie oczekiwany jest luz na lico, dostanie 8 mm w fudze.
/// Dlatego `frontToFrontGap` jest wyliczane, a nie wpisywane osobno.
public enum ProductionRules {

    // MARK: - Fronty

    /// Luz frontu na jedno lico. Front jest o tyle cofnięty od krawędzi korpusu.
    public static let frontClearancePerEdge: Millimeters = 2

    /// Fuga między sąsiednimi frontami — zawsze dwa luzy.
    ///
    /// Mniej niż 3 mm i skrzydła ocierają się przy najmniejszym rozjeździe
    /// montażu albo pracy płyty; więcej niż 5 mm i widać wnętrze korpusu.
    public static var frontToFrontGap: Millimeters {
        frontClearancePerEdge * 2
    }

    /// Szerokość frontu nakładanego dla zadanej podziałki modułu.
    public static func frontWidth(forModulePitch pitch: Millimeters) -> Millimeters {
        pitch - frontToFrontGap
    }

    /// Szerokość jednego z **kilku** frontów w rzędzie.
    ///
    /// Rząd frontów zabiera: luz przy lewej krawędzi, luz przy prawej i po
    /// jednej fudze między każdą sąsiednią parą. Stąd `n − 1`, a nie `n + 1` —
    /// front nakładany jest cofnięty od krawędzi korpusu o **luz** (2 mm),
    /// nie o pełną fugę (4 mm).
    ///
    /// Ta pomyłka realnie się zdarzyła: podgląd przestrzenny karty liczył
    /// `(W − fuga × (n + 1)) / n` i rysował fronty o 2 mm węższe niż te,
    /// które wychodziły z listy formatek. Dlatego wzór stoi tutaj, a nie
    /// w każdym generatorze osobno.
    public static func frontWidth(
        forModulePitch pitch: Millimeters,
        columns: Int
    ) -> Millimeters {
        let n = max(columns, 1)
        let szerokosc = (
            pitch
            - frontClearancePerEdge * 2
            - frontToFrontGap * Double(n - 1)
        ) / Double(n)
        return max(szerokosc, Millimeters(1))
    }

    /// Wysokość frontu dla zadanej wysokości korpusu — po luzie u góry i u dołu.
    public static func frontHeight(forCarcassHeight height: Millimeters) -> Millimeters {
        height - frontToFrontGap
    }

    // MARK: - Płyta i obrzeże

    public static let carcassThickness: Millimeters = 18
    public static let drawerBoxThickness: Millimeters = 18
    public static let backPanelThickness: Millimeters = 3

    /// Grubości, które hurtownia trzyma z półki. Wartość spoza listy nie jest
    /// błędem, ale prawie zawsze jest literówką.
    public static let stockThicknesses: Set<Double> = [
        3, 8, 10, 12, 16, 18, 19, 22, 25, 36, 38
    ]

    /// Obrzeże standardowe. Formatka rośnie o grubość obrzeża na każdej
    /// oklejanej krawędzi, stąd kompensacja przy zamawianiu.
    public static let edgeBandingThickness: Millimeters = 0.8

    /// Ile odjąć od wymiaru gotowego, żeby dostać wymiar cięcia,
    /// przy oklejaniu wszystkich czterech krawędzi.
    public static var edgeCompensationAllRound: Millimeters {
        edgeBandingThickness * 2
    }

    // MARK: - Arkusz

    public static let sheetWidth: Millimeters = 2_800
    public static let sheetHeight: Millimeters = 2_070
    public static let sawKerf: Millimeters = 4.2

    /// Czy formatka mieści się w arkuszu przy dowolnym obrocie.
    public static func fitsOnSheet(_ length: Millimeters, _ width: Millimeters) -> Bool {
        let dluzszy = max(length, width)
        let krotszy = min(length, width)
        return dluzszy <= max(sheetWidth, sheetHeight)
            && krotszy <= min(sheetWidth, sheetHeight)
    }

    // MARK: - System 32

    public enum System32 {
        public static let firstHoleFromEdge: Millimeters = 37
        public static let holeSpacing: Millimeters = 32
        public static let drillDiameter: Millimeters = 5
        public static let drillDepth: Millimeters = 12
        public static let rowFromFront: Millimeters = 37
        public static let rowFromBack: Millimeters = 37
        public static let fieldStartAboveBottom: Millimeters = 96
        public static let fieldEndBelowTop: Millimeters = 96
        public static let hingeCupDiameter: Millimeters = 35
        public static let hingeCupAxisFromEdge: Millimeters = 22.5
    }

    // MARK: - Okucia wyprowadzane z geometrii

    /// Podpórki na jedną półkę regulowaną.
    public static let shelfSupportsPerShelf = 4

    /// Liczba zawiasów dla frontu o zadanej wysokości.
    public static func hingeCount(forFrontHeight height: Millimeters) -> Int {
        switch height.rawValue {
        case ..<900: return 2
        case ..<1_600: return 3
        default: return 4
        }
    }
}

// MARK: - Kontrola zespołu

/// Pojedyncze zastrzeżenie do zespołu.
public struct ProductionIssue: Hashable, Sendable {

    public enum Severity: String, Codable, Sendable, CaseIterable {
        /// Tego nie da się zbudować — blokuje wydanie dokumentacji.
        case error
        /// Da się, ale prawie na pewno nie o to chodziło.
        case warning
        /// Do wiadomości.
        case note
    }

    public var severity: Severity
    public var componentCode: String?
    public var message: String
    public var hint: String

    public init(
        severity: Severity,
        componentCode: String? = nil,
        message: String,
        hint: String = ""
    ) {
        self.severity = severity
        self.componentCode = componentCode
        self.message = message
        self.hint = hint
    }
}

/// Sprawdza, czy zbudowany zespół da się wykonać.
///
/// Powstało po tym, jak w generatorze dokumentacji fronty liczone jako
/// `sw + 2T` od `x - T` nachodziły na siebie o grubość boku przez kilkanaście
/// przebiegów renderu i nikt tego nie zauważył — nachodzące fronty wyglądają
/// jak jedna płyta, a to z kolei wygląda jak zwykły front bezuchwytowy.
/// Ta sama klasa błędu jest możliwa po stronie aplikacji, bo `CabinetBuilders`
/// i solver więzów liczą pozycje niezależnie.
public enum AssemblyInspector {

    /// Ile milimetrów tolerancji, zanim uznamy różnicę za realną.
    private static let tolerance = 0.5

    public static func inspect(_ assembly: FurnitureAssembly) -> [ProductionIssue] {
        var issues: [ProductionIssue] = []
        issues += checkFrontGaps(assembly)
        issues += checkBounds(assembly)
        issues += checkPanels(assembly)
        return issues
    }

    /// Czy zespół nadaje się do wydania na warsztat.
    public static func isBuildable(_ assembly: FurnitureAssembly) -> Bool {
        !inspect(assembly).contains { $0.severity == .error }
    }

    // MARK: Fronty

    private static func checkFrontGaps(_ assembly: FurnitureAssembly) -> [ProductionIssue] {
        let fronts = assembly.components
            .filter { $0.role == .front }
            .sorted { $0.localPosition.x < $1.localPosition.x }
        guard fronts.count > 1 else { return [] }

        let expected = ProductionRules.frontToFrontGap.rawValue
        var issues: [ProductionIssue] = []

        for (left, right) in zip(fronts, fronts.dropFirst()) {
            let leftEdge = (left.localPosition.x + left.size.width).rawValue
            let gap = right.localPosition.x.rawValue - leftEdge

            // Fronty jeden nad drugim w tej samej kolumnie — pion sprawdzamy osobno.
            let sameColumn = abs(right.localPosition.x.rawValue - left.localPosition.x.rawValue) < tolerance
            if sameColumn { continue }

            if gap < -tolerance {
                issues.append(ProductionIssue(
                    severity: .error,
                    componentCode: "\(left.code) / \(right.code)",
                    message: String(
                        format: "fronty nachodzą na siebie o %.1f mm", -gap),
                    hint: "nachodzące fronty renderują się jak jedna płyta — "
                        + "błąd wygląda wtedy jak front bezuchwytowy"))
            } else if abs(gap - expected) > tolerance {
                issues.append(ProductionIssue(
                    severity: .warning,
                    componentCode: "\(left.code) / \(right.code)",
                    message: String(
                        format: "fuga %.1f mm zamiast %.1f mm", gap, expected),
                    hint: String(
                        format: "ProductionRules.frontToFrontGap to dwa luzy po %.1f mm",
                        ProductionRules.frontClearancePerEdge.rawValue)))
            }
        }
        return issues
    }

    // MARK: Gabaryt

    private static func checkBounds(_ assembly: FurnitureAssembly) -> [ProductionIssue] {
        var issues: [ProductionIssue] = []
        for c in assembly.components {
            let poza =
                c.localPosition.x.rawValue < -tolerance
                || c.localPosition.y.rawValue < -tolerance
                || (c.localPosition.x + c.size.width).rawValue
                    > assembly.size.width.rawValue + tolerance
                || (c.localPosition.y + c.size.height).rawValue
                    > assembly.size.height.rawValue + tolerance
            if poza {
                issues.append(ProductionIssue(
                    severity: .error,
                    componentCode: c.code,
                    message: "element wychodzi poza gabaryt zespołu",
                    hint: String(
                        format: "x %.0f…%.0f, y %.0f…%.0f przy zespole %.0f×%.0f",
                        c.localPosition.x.rawValue,
                        (c.localPosition.x + c.size.width).rawValue,
                        c.localPosition.y.rawValue,
                        (c.localPosition.y + c.size.height).rawValue,
                        assembly.size.width.rawValue,
                        assembly.size.height.rawValue)))
            }
        }
        return issues
    }

    // MARK: Formatki

    private static func checkPanels(_ assembly: FurnitureAssembly) -> [ProductionIssue] {
        var issues: [ProductionIssue] = []
        for c in assembly.components {
            let w = c.size.width, h = c.size.height, d = c.size.depth
            if min(w, min(h, d)).rawValue <= 0 {
                issues.append(ProductionIssue(
                    severity: .error,
                    componentCode: c.code,
                    message: String(
                        format: "niedodatni wymiar %.0f×%.0f×%.0f",
                        w.rawValue, h.rawValue, d.rawValue)))
                continue
            }
            // Grubość to najmniejszy z trzech wymiarów płyty.
            let thickness = min(w, min(h, d)).rawValue
            if !ProductionRules.stockThicknesses.contains(thickness) {
                issues.append(ProductionIssue(
                    severity: .note,
                    componentCode: c.code,
                    message: String(format: "grubość %.1f mm nie jest z półki", thickness),
                    hint: "literówka albo materiał na zamówienie"))
            }
            // Dwa większe wymiary muszą zmieścić się w arkuszu.
            let sorted = [w, h, d].sorted()
            if !ProductionRules.fitsOnSheet(sorted[1], sorted[2]) {
                issues.append(ProductionIssue(
                    severity: .error,
                    componentCode: c.code,
                    message: String(
                        format: "formatka %.0f×%.0f nie mieści się w arkuszu %.0f×%.0f",
                        sorted[2].rawValue, sorted[1].rawValue,
                        ProductionRules.sheetWidth.rawValue,
                        ProductionRules.sheetHeight.rawValue),
                    hint: "podziel element albo zmień format arkusza"))
            }
        }
        return issues
    }
}
