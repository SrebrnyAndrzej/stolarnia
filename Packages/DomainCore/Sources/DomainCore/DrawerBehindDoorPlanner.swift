import Foundation

/// Liczy, ile miejsca zostaje na szufladę schowaną **za frontem uchylnym**.
///
/// Research 2026-08-26 (Blum, Rockler, WoodWeb, praktyka warsztatowa USA/PL):
///
/// - Zwykły zawias europejski otwarty na 90–110° **nie znika ze światła**.
///   Skrzydło zatrzymuje się w płaszczyźnie boku korpusu i zabiera pas szerokości
///   mniej więcej własnej grubości — źródła podają „martwą strefę" 1/2″–3/4″,
///   czyli **12,7–19 mm**. Amerykańska reguła warsztatowa mówi wprost:
///   „szerokość światła minus 1½″" (38 mm), czyli ok. 19 mm na stronę — ale to
///   dotyczy korpusów ramowych. W korpusie bezramowym pas zabiera tylko strona
///   zawiasu.
/// - Zawias **zero-protrusion** (Blum CLIP top BLUMOTION 155° i 125°) odrzuca
///   krawędź frontu poza światło. Blum opisuje go wprost jako rozwiązanie
///   „for cabinets with inner pull-outs or pull-out shelfs".
/// - **Zero-protrusion ma warunek, o którym łatwo zapomnieć: minimalną nakładkę
///   frontu 5/8″ ≈ 16 mm.** Przy mniejszej nakładce front i tak wejdzie
///   w światło, a zawias nie spełni obietnicy. Aplikacja tego warunku wcześniej
///   nie znała wcale.
/// - Wariant 155° ma też **limit grubości frontu 24 mm**.
///
/// **Najważniejszy wniosek: to jest problem niesymetryczny.** Front wystaje
/// wyłącznie po stronie zawiasu. Odsuwanie skrzynki po obu stronach — jak robił
/// to dotąd `SzufladyModuluEngine` — oddaje w korpusie 600 mm około 4 cm
/// szerokości szuflady bez żadnego powodu.
public enum DrawerBehindDoorPlanner {

    // MARK: - Progi z badań i katalogów

    /// Minimalna nakładka frontu, przy której zawias zero-protrusion faktycznie
    /// odrzuca skrzydło poza światło (5/8″).
    public static let minimumOverlayForZeroProtrusion: Millimeters = 16

    /// Maksymalna grubość frontu dla zero-protrusion 155°.
    public static let maximumDoorThicknessForZeroProtrusion: Millimeters = 24

    /// Luz bezpieczeństwa między krawędzią frontu a skrzynką.
    ///
    /// Front i tak pracuje: regulacja zawiasu, osiadanie, praca płyty. Bez tego
    /// zapasu skrzynka ociera o wewnętrzne lico frontu i rysuje je przy każdym
    /// wysunięciu.
    public static let safetyGap: Millimeters = 3

    // MARK: - Wejście

    /// Zachowanie zawiasu w świetle korpusu.
    public enum HingeBehaviour: String, Codable, Hashable, Sendable, CaseIterable {
        /// Zwykły zawias 95–110°: skrzydło zostaje w świetle.
        case standard
        /// Zero-protrusion 125°: odrzuca skrzydło, ale ciaśniej niż 155°.
        case zeroProtrusion125
        /// Zero-protrusion 155°: pełne odrzucenie skrzydła.
        case zeroProtrusion155

        public var displayName: String {
            switch self {
            case .standard:          return "Zwykły 95–110°"
            case .zeroProtrusion125: return "Zero-protrusion 125°"
            case .zeroProtrusion155: return "Zero-protrusion 155°"
            }
        }

        public var isZeroProtrusion: Bool { self != .standard }
    }

    public struct Input: Hashable, Sendable {
        /// Światło korpusu między bokami.
        public var innerWidth: Millimeters
        public var hinge: HingeBehaviour
        public var doorThickness: Millimeters
        /// O ile front zachodzi na bok korpusu po stronie zawiasu.
        public var doorOverlay: Millimeters

        public init(
            innerWidth: Millimeters,
            hinge: HingeBehaviour,
            doorThickness: Millimeters = 18,
            doorOverlay: Millimeters = 16
        ) {
            self.innerWidth = innerWidth
            self.hinge = hinge
            self.doorThickness = doorThickness
            self.doorOverlay = doorOverlay
        }
    }

    // MARK: - Wyjście

    public struct Plan: Hashable, Sendable {
        /// Pas oddany po stronie zawiasu.
        public var hingeSideInset: Millimeters
        /// Pas oddany po stronie wolnej — przy froncie jednoskrzydłowym zero.
        public var freeSideInset: Millimeters
        /// Ile zostaje na skrzynkę.
        public var usableWidth: Millimeters
        public var issues: [ProductionIssue]

        public var totalInset: Millimeters { hingeSideInset + freeSideInset }

        public init(
            hingeSideInset: Millimeters,
            freeSideInset: Millimeters,
            usableWidth: Millimeters,
            issues: [ProductionIssue]
        ) {
            self.hingeSideInset = hingeSideInset
            self.freeSideInset = freeSideInset
            self.usableWidth = usableWidth
            self.issues = issues
        }
    }

    // MARK: - Obliczenie

    public static func plan(_ input: Input) -> Plan {
        var issues: [ProductionIssue] = []

        // Zero-protrusion działa tylko przy dostatecznej nakładce. Poniżej progu
        // zawias zachowuje się jak zwykły i trzeba liczyć pełne wcięcie.
        let nakladkaWystarcza = input.doorOverlay >= minimumOverlayForZeroProtrusion
        let dziala = input.hinge.isZeroProtrusion && nakladkaWystarcza

        if input.hinge.isZeroProtrusion && !nakladkaWystarcza {
            issues.append(ProductionIssue(
                severity: .error,
                message: String(
                    format: "nakładka frontu %.0f mm jest mniejsza niż %.0f mm — "
                        + "zawias zero-protrusion nie odrzuci skrzydła poza światło",
                    input.doorOverlay.rawValue,
                    minimumOverlayForZeroProtrusion.rawValue),
                hint: "zwiększ nakładkę albo policz szufladę jak za zwykłym zawiasem"))
        }

        if input.hinge == .zeroProtrusion155,
           input.doorThickness > maximumDoorThicknessForZeroProtrusion {
            issues.append(ProductionIssue(
                severity: .warning,
                message: String(
                    format: "front %.0f mm przekracza %.0f mm dopuszczalne dla "
                        + "zero-protrusion 155°",
                    input.doorThickness.rawValue,
                    maximumDoorThicknessForZeroProtrusion.rawValue),
                hint: "sprawdź wariant do grubych frontów albo potwierdź SKU"))
        }

        let hingeSide: Millimeters
        if dziala {
            switch input.hinge {
            case .zeroProtrusion155:
                // Skrzydło poza światłem — zostaje sam luz bezpieczeństwa.
                hingeSide = safetyGap
            case .zeroProtrusion125:
                // Mniejszy kąt odrzuca skrzydło ciaśniej; praktyka mówi
                // o kilku milimetrach zapasu ponad sam luz.
                hingeSide = safetyGap + 5
            case .standard:
                hingeSide = .zero   // nieosiągalne — `dziala` jest wtedy false
            }
        } else {
            // Skrzydło zostaje w świetle: oddajemy pas własnej grubości frontu
            // plus luz. Dla frontu 18 mm daje to 21 mm — zgodne z „martwą strefą"
            // 12,7–19 mm z literatury, powiększoną o zapas na regulację.
            hingeSide = input.doorThickness + safetyGap
        }

        // Strona wolna nie ma czego omijać — front się tam nie otwiera.
        let freeSide = Millimeters.zero

        let usable = input.innerWidth - hingeSide - freeSide
        if usable <= .zero {
            issues.append(ProductionIssue(
                severity: .error,
                message: String(
                    format: "po odjęciu %.0f mm na front nie zostaje miejsca na "
                        + "skrzynkę (światło %.0f mm)",
                    hingeSide.rawValue, input.innerWidth.rawValue),
                hint: "za wąski korpus na szufladę za frontem"))
        }

        if input.hinge == .standard {
            issues.append(ProductionIssue(
                severity: .warning,
                message: String(
                    format: "zwykły zawias zabiera %.0f mm światła po stronie zawiasu",
                    hingeSide.rawValue),
                hint: "zero-protrusion 155° odzyskuje z tego "
                    + String(format: "%.0f mm", (hingeSide - safetyGap).rawValue)))
        }

        return Plan(
            hingeSideInset: hingeSide,
            freeSideInset: freeSide,
            usableWidth: max(usable, .zero),
            issues: issues)
    }

    /// Ile szerokości odzyskuje zamiana zwykłego zawiasu na zero-protrusion.
    ///
    /// Liczba do pokazania projektantowi przy wyborze okucia — różnica bywa
    /// większa niż cała podziałka cargo.
    public static func widthGainFromZeroProtrusion(
        innerWidth: Millimeters,
        doorThickness: Millimeters = 18,
        doorOverlay: Millimeters = 16
    ) -> Millimeters {
        let zwykly = plan(Input(
            innerWidth: innerWidth, hinge: .standard,
            doorThickness: doorThickness, doorOverlay: doorOverlay))
        let zero = plan(Input(
            innerWidth: innerWidth, hinge: .zeroProtrusion155,
            doorThickness: doorThickness, doorOverlay: doorOverlay))
        return zero.usableWidth - zwykly.usableWidth
    }
}
