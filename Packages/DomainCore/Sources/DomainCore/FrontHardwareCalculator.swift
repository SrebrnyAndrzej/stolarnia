import Foundation

/// Dobór okuć wyprowadzony z geometrii mebla i gęstości materiału.
///
/// Uzupełnia `ProductionRules` (zawiasy, podpórki) o rzeczy, które zależą od
/// **masy frontu i głębokości korpusu**, a nie od samych wymiarów światła:
/// podnośniki i długość prowadnicy.
///
/// Reguły są celowo zapisane jako **wzory, nie jako listy SKU**. Zakresy
/// konkretnych mechanizmów różnią się między producentami i seriami, a katalog
/// bez potwierdzenia w tabeli producenta jest gorszy niż jego brak — dlatego
/// wynik niesie `requiresSKUConfirmation`, tak jak reszta reguł okuciowych
/// w tym projekcie.
public enum FrontHardwareCalculator {

    // MARK: - Masa frontu

    /// Gęstości nasypowe płyt meblowych.
    ///
    /// Płyta wiórowa laminowana ok. 650–700 kg/m³, MDF wyraźnie cięższy.
    /// Do doboru podnośnika liczy się realna masa skrzydła, więc materiał
    /// frontu zmienia wynik — front MDF 18 mm waży ok. 25% więcej niż wiórowy.
    public enum PanelDensity: Double, Codable, Hashable, Sendable, CaseIterable {
        case chipboard = 680
        case mdf = 750
        case plywood = 600
        case solidWood = 700

        public var displayName: String {
            switch self {
            case .chipboard: return "Płyta wiórowa"
            case .mdf:       return "MDF"
            case .plywood:   return "Sklejka"
            case .solidWood: return "Drewno lite"
            }
        }
    }

    /// Masa frontu w kilogramach.
    ///
    /// - Parameter extraLoad: doliczka na uchwyt, szkło, front nakładany
    ///   albo listwę — podnośnik dobiera się do masy realnej, nie samej płyty.
    public static func frontMass(
        width: Millimeters,
        height: Millimeters,
        thickness: Millimeters = 18,
        density: PanelDensity = .chipboard,
        extraLoad: Double = 0
    ) -> Double {
        let m3 = (width.rawValue / 1_000)
            * (height.rawValue / 1_000)
            * (thickness.rawValue / 1_000)
        return m3 * density.rawValue + extraLoad
    }

    // MARK: - Podnośniki

    public struct LiftSelection: Hashable, Sendable {
        /// Współczynnik mocy: wysokość frontu [mm] × masa frontu [kg].
        ///
        /// To jest wielkość, po której producenci podnośników dobierają
        /// siłownik — nie sama masa i nie sama wysokość. Wysoki lekki front
        /// i niski ciężki mogą wymagać tego samego mechanizmu.
        public var powerFactor: Double
        public var frontMass: Double
        public var requiresSKUConfirmation: Bool
        public var issues: [ProductionIssue]

        public init(powerFactor: Double, frontMass: Double,
                    requiresSKUConfirmation: Bool, issues: [ProductionIssue]) {
            self.powerFactor = powerFactor
            self.frontMass = frontMass
            self.requiresSKUConfirmation = requiresSKUConfirmation
            self.issues = issues
        }
    }

    /// Dwa siłowniki są regułą przy szerokich frontach — pojedynczy skręca
    /// skrzydło i front przestaje przylegać równo.
    public static let twoActuatorWidthThreshold: Millimeters = 900

    public static func selectLift(
        frontWidth: Millimeters,
        frontHeight: Millimeters,
        thickness: Millimeters = 18,
        density: PanelDensity = .chipboard,
        extraLoad: Double = 0
    ) -> LiftSelection {
        let masa = frontMass(
            width: frontWidth, height: frontHeight,
            thickness: thickness, density: density, extraLoad: extraLoad)
        let wspolczynnik = frontHeight.rawValue * masa

        var uwagi: [ProductionIssue] = []

        if frontWidth >= twoActuatorWidthThreshold {
            uwagi.append(ProductionIssue(
                severity: .note,
                message: String(
                    format: "front %.0f mm szerokości — przewidź dwa siłowniki",
                    frontWidth.rawValue),
                hint: "pojedynczy skręca szerokie skrzydło"))
        }
        if masa > 20 {
            uwagi.append(ProductionIssue(
                severity: .warning,
                message: String(format: "front waży ok. %.1f kg", masa),
                hint: "sprawdź nośność mechanizmu i mocowanie do korpusu"))
        }
        uwagi.append(ProductionIssue(
            severity: .note,
            message: String(
                format: "współczynnik mocy %.0f (wysokość × masa)", wspolczynnik),
            hint: "dobierz siłownik z tabeli producenta dla tego współczynnika"))

        return LiftSelection(
            powerFactor: wspolczynnik,
            frontMass: masa,
            requiresSKUConfirmation: true,
            issues: uwagi)
    }

    // MARK: - Prowadnice

    /// Długości nominalne prowadnic trzymane przez hurtownie.
    /// Ogólna drabinka długości — **tylko gdy system nie jest znany**.
    ///
    /// Gdy wiadomo, jaki system szuflad jest wybrany, właściwą listę daje
    /// `DrawerProfile.nominalLengths(for:)` — każdy producent ma własną
    /// i dobieranie „najbliższej okrągłej" kończy się zamówieniem prowadnicy,
    /// której nikt nie robi (Amix zaczyna od 270, GTV od 250).
    public static let runnerLengths: [Millimeters] = [
        250, 300, 350, 400, 450, 500, 550, 600
    ]

    public struct RunnerSelection: Hashable, Sendable {
        public var nominalLength: Millimeters
        public var unusedDepth: Millimeters
        /// Kalkulator dobiera wymiar, nie model z katalogu producenta.
        public var requiresSKUConfirmation: Bool

        public init(
            nominalLength: Millimeters,
            unusedDepth: Millimeters,
            requiresSKUConfirmation: Bool
        ) {
            self.nominalLength = nominalLength
            self.unusedDepth = unusedDepth
            self.requiresSKUConfirmation = requiresSKUConfirmation
        }
    }

    /// Dobiera wymiar prowadnicy i zachowuje informację, że konkretny model
    /// nadal trzeba potwierdzić w drabince wybranego producenta.
    ///
    /// `availableLengths` pozwala silnikowi przekazać drabinkę już wybranego
    /// systemu. Kalkulator nadal nie wybiera SKU — jedynie najdłuższy wymiar,
    /// który mieści się w geometrii korpusu.
    /// Zapas głębokości korpusu ponad długość nominalną prowadnicy.
    ///
    /// **Ujednolicone 2026-08-27.** Wcześniej stały tu dwie liczby
    /// (`backPanelAllowance` 20 + `frontAllowance` 10 = 30 mm), niezależne od
    /// `DrawerProfile.requiredDepthMargin` (22 mm). Ta sama wielkość liczona
    /// dwiema regułami — dokładnie ta klasa błędu, która tego samego dnia dała
    /// prowadnicę niemieszczącą się w korpusie 522 mm.
    ///
    /// Prawdą jest wartość z `DrawerProfile`, bo pochodzi z danych producenta
    /// (Blum podaje 555 mm światła dla NL 533). Tutaj dochodzi tylko grubość
    /// pleców, bo ta funkcja bierze **głębokość całkowitą**, a tamta światło.
    ///
    /// Uwaga na nazwy: `forCabinetDepth` to gabaryt, `cabinetInnerDepth`
    /// w `DrawerProfile` to światło. Pomylenie ich zmienia wynik o szczebel
    /// drabinki.
    public static var cabinetDepthAllowance: Millimeters {
        ProductionRules.backPanelThickness + DrawerProfile.requiredDepthMargin
    }

    public static func selectRunner(
        forCabinetDepth depth: Millimeters,
        availableLengths: [Millimeters] = runnerLengths,
        allowance: Millimeters = cabinetDepthAllowance
    ) -> RunnerSelection? {
        let dostepne = depth - allowance
        guard let nominalna = availableLengths
            .filter({ $0 > .zero && $0 <= dostepne })
            .max()
        else {
            return nil
        }

        return RunnerSelection(
            nominalLength: nominalna,
            unusedDepth: unusedDepth(cabinetDepth: depth, runner: nominalna),
            requiresSKUConfirmation: true
        )
    }

    /// Dobiera najdłuższą prowadnicę mieszczącą się w korpusie.
    ///
    /// Prowadnica nie może sięgać pleców: zostawiamy zapas na płytę tylną
    /// i na to, że korpus nigdy nie jest idealnie prostokątny.
    ///
    /// - Returns: `nil`, gdy korpus jest za płytki nawet na najkrótszą.
    public static func runnerLength(
        forCabinetDepth depth: Millimeters,
        allowance: Millimeters = cabinetDepthAllowance
    ) -> Millimeters? {
        selectRunner(
            forCabinetDepth: depth,
            allowance: allowance
        )?.nominalLength
    }

    /// Ile głębokości korpusu zostaje niewykorzystane po doborze prowadnicy.
    ///
    /// Liczba do pokazania projektantowi: przy korpusie 560 i prowadnicy 500
    /// marnuje się 60 mm, co przy szufladzie bywa całą warstwą przechowywania.
    public static func unusedDepth(
        cabinetDepth: Millimeters,
        runner: Millimeters
    ) -> Millimeters {
        max(cabinetDepth - runner, .zero)
    }
}
