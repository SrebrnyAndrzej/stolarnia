import Foundation

/// Rodzaj pozycji okuciowej generowanej dla modułu elewacji.
public enum ElevationHardwareKind: String, Codable, CaseIterable, Hashable, Sendable {
    case drawerRunner
    case hinge
    case shelfSupport
    case hangingRailSupport
    case liftMechanism
    case slidingTrack
}

/// Jedna pozycja zamówienia okuć.
///
/// Okucie celowo nie jest `ElevationCutItem`: nie ma wymiarów formatki ani
/// materiału płytowego. Zamiast tego niesie system, wariant produktu, jego
/// wymiar zamówieniowy oraz jednostkę, w której warsztat składa zamówienie.
public struct ElevationHardwareItem: Identifiable, Hashable, Sendable {
    public enum Unit: String, Codable, CaseIterable, Hashable, Sendable {
        case piece
        case pair
        case set
    }

    public var kind: ElevationHardwareKind
    public var system: String
    public var variant: String
    public var dimension: Millimeters
    public var count: Int
    public var unit: Unit

    /// `true`, gdy geometria pozwala policzyć i zwymiarować okucie, ale moduł
    /// nie wskazuje jeszcze konkretnej serii producenta.
    public var requiresVariantConfirmation: Bool

    public var id: String {
        [
            kind.rawValue,
            system,
            variant,
            String(dimension.rawValue),
            unit.rawValue
        ].joined(separator: "|")
    }

    public init(
        kind: ElevationHardwareKind,
        system: String,
        variant: String,
        dimension: Millimeters,
        count: Int,
        unit: Unit,
        requiresVariantConfirmation: Bool = false
    ) {
        self.kind = kind
        self.system = system
        self.variant = variant
        self.dimension = dimension
        self.count = max(count, 0)
        self.unit = unit
        self.requiresVariantConfirmation = requiresVariantConfirmation
    }
}

public extension ElevationModule {
    /// Okuciowa część listy produkcyjnej modułu.
    ///
    /// Prowadnice są dobierane z drabinki konkretnego producenta. Dla okuć,
    /// których serii moduł jeszcze nie przechowuje, wynik zachowuje wymiar
    /// potrzebny do doboru i jawnie wymaga potwierdzenia wariantu.
    func hardwareList() -> [ElevationHardwareItem] {
        var wynik: [ElevationHardwareItem] = []
        let uzywaWarstwyFrontow = !frontSpans.isEmpty

        func dodaj(_ pozycja: ElevationHardwareItem) {
            guard pozycja.count > 0, pozycja.dimension > .zero else { return }

            if let indeks = wynik.firstIndex(where: {
                $0.kind == pozycja.kind
                    && $0.system == pozycja.system
                    && $0.variant == pozycja.variant
                    && $0.dimension == pozycja.dimension
                    && $0.unit == pozycja.unit
                    && $0.requiresVariantConfirmation
                        == pozycja.requiresVariantConfirmation
            }) {
                wynik[indeks].count += pozycja.count
            } else {
                wynik.append(pozycja)
            }
        }

        for segment in segments {
            let strefa = segment.zone
            guard strefa.kind != .appliance else { continue }
            let kolumny = max(1, strefa.columns)

            switch strefa.kind {
            case .drawers:
                // **Światło, nie gabaryt.** `depth` to głębokość korpusu razem
                // z plecami; prowadnica do nich nie sięga, więc dostępne
                // światło jest krótsze o grubość pleców.
                //
                // Różnica bywa jedną szczeblą drabinki: przy korpusie 522 mm
                // liczenie z pełnej głębokości dobiera NL 500, która wymaga
                // 522 mm światła — a jest go 519. Prowadnica **nie weszłaby**.
                // Ta sama poprawka obowiązuje w edytorze elewacji
                // (`sekcjaProwadnicyV0103`), więc obie drogi muszą liczyć
                // z tej samej podstawy, inaczej ekran pokazuje co innego,
                // niż zamawia lista.
                let swiatloKorpusu = depth - ProductionRules.backPanelThickness
                guard let dlugosc = DrawerProfile.nominalLength(
                    for: strefa.drawerSystem,
                    cabinetInnerDepth: swiatloKorpusu
                ) else { continue }

                dodaj(ElevationHardwareItem(
                    kind: .drawerRunner,
                    system: strefa.drawerSystem.displayName,
                    variant: strefa.drawerProfile.name,
                    dimension: dlugosc,
                    count: drawerFrontHeights(forZoneAt: segment.index).count
                        * kolumny,
                    unit: .pair
                ))

            case .doors:
                guard !uzywaWarstwyFrontow else { continue }
                dodaj(ElevationHardwareItem(
                    kind: .hinge,
                    system: "Zawias puszkowy",
                    variant: "Nakładany",
                    dimension: ProductionRules.System32.hingeCupDiameter,
                    count: ProductionRules.hingeCount(
                        forFrontHeight: segment.zoneHeight
                    ) * kolumny,
                    unit: .piece,
                    requiresVariantConfirmation: true
                ))

            case .shelves:
                dodaj(ElevationHardwareItem(
                    kind: .shelfSupport,
                    system: "System 32",
                    variant: "Podpórka półki",
                    dimension: ProductionRules.System32.drillDiameter,
                    count: strefa.shelfCount
                        * kolumny
                        * ProductionRules.shelfSupportsPerShelf,
                    unit: .piece,
                    requiresVariantConfirmation: true
                ))

            case .hanging:
                // Model nie przechowuje jeszcze średnicy drążka. Wysokość osi
                // jest wymiarem montażowym, a nie zamówieniowym, więc nie wolno
                // udawać nią średnicy produktu i generować błędnej pozycji.
                break

            case .appliance:
                break
            }
        }

        if uzywaWarstwyFrontow {
            for front in frontSpans {
                guard let lico = frontSpanFaceV0104(front) else { continue }
                let wybranyWariant = front.hardwareProfileID.isEmpty
                    ? "Do potwierdzenia"
                    : front.hardwareProfileID

                switch front.opening {
                case .leftHinged, .rightHinged:
                    dodaj(ElevationHardwareItem(
                        kind: .hinge,
                        system: "Zawias puszkowy",
                        variant: wybranyWariant,
                        dimension: ProductionRules.System32.hingeCupDiameter,
                        count: ProductionRules.hingeCount(
                            forFrontHeight: lico.height
                        ),
                        unit: .piece,
                        requiresVariantConfirmation: front.hardwareProfileID.isEmpty
                    ))

                case .liftUp, .flapDown:
                    dodaj(ElevationHardwareItem(
                        kind: .liftMechanism,
                        system: "Podnośnik frontu",
                        variant: wybranyWariant,
                        dimension: lico.height,
                        count: 1,
                        unit: .set,
                        requiresVariantConfirmation: front.hardwareProfileID.isEmpty
                    ))

                case .sliding:
                    dodaj(ElevationHardwareItem(
                        kind: .slidingTrack,
                        system: "System drzwi przesuwnych",
                        variant: wybranyWariant,
                        dimension: lico.width,
                        count: 1,
                        unit: .set,
                        requiresVariantConfirmation: front.hardwareProfileID.isEmpty
                    ))

                case .drawer, .fixed:
                    break
                }
            }
        }

        return wynik
    }
}
