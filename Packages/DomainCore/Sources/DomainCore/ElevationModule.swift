import Foundation

/// Typ zawartości strefy w kreatorze rysunkowym (elewacja modułu).
public enum ElevationZoneKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case drawers
    case doors
    case shelves
    case hanging
    case appliance

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .drawers: return "Szuflady"
        case .doors: return "Drzwi"
        case .shelves: return "Półki otwarte"
        case .hanging: return "Drążek"
        case .appliance: return "AGD"
        }
    }
}

/// Pozioma strefa modułu. Strefa może być dzielona pionowymi przegrodami
/// na kolumny — każda kolumna powiela tę samą zawartość.
/// Zachowanie układu szuflad przy zmianie wysokości mebla.
///
/// Bez tego wyboru projektant nie mógł powiedzieć „te dwie trzymaj wymiar,
/// tę rozciągnij" — a to jest realna decyzja warsztatowa: 140 mm to sztućce
/// i ma zostać 140, natomiast dolna szuflada może urosnąć dowolnie.
public enum DrawerLayoutMode: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// Zapisane wysokości są proporcjami i skalują się razem z meblem.
    case proportional
    /// Zapisane wysokości są trzymane co do milimetra, a różnicę wchłania
    /// jedna wskazana szuflada.
    case keepSizes
    /// Wszystkie fronty równe.
    case equal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .proportional: return "Skaluj proporcjonalnie"
        case .keepSizes:    return "Trzymaj wymiary"
        case .equal:        return "Równe fronty"
        }
    }

    public var opis: String {
        switch self {
        case .proportional:
            return "Stosunki między szufladami zostają; wszystkie rosną razem z meblem."
        case .keepSizes:
            return "Podane wysokości zostają, różnicę wchłania wybrana szuflada."
        case .equal:
            return "Wszystkie fronty tej samej wysokości."
        }
    }
}

public struct ElevationZone: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: ElevationZoneKind
    /// Liczba kolumn (przegrody pionowe = columns − 1). Zakres 1...4.
    public var columns: Int
    /// Liczba półek w kolumnie (dla `.shelves`). Zakres 0...8.
    public var shelfCount: Int
    /// Liczba szuflad w kolumnie (dla `.drawers`). Zakres 1...6.
    public var drawerCount: Int
    public var drawerSystem: DrawerSystem
    public var drawerProfileName: String
    /// Wysokość osi drążka od dna strefy. `0` oznacza auto przy górze strefy.
    public var railHeight: Millimeters
    /// Opcjonalne wysokości frontów szuflad od dołu do góry.
    ///
    /// **To są proporcje, nie wymiary sztywne** — patrz `DrawerFrontStack`.
    /// Fronty zawsze wypełniają strefę co do milimetra, więc zapisane liczby
    /// mówią o stosunkach między szufladami, a nie o docelowych wysokościach.
    /// Pusta lista oznacza równy podział.
    public var drawerFrontHeights: [Millimeters]

    /// Jak układ ma się zachować przy zmianie wysokości mebla.
    public var drawerLayoutMode: DrawerLayoutMode

    /// Która szuflada wchłania różnicę w trybie `.keepSizes`.
    /// Liczone od dołu; poza zakresem jest przycinane przy użyciu.
    public var flexibleDrawerIndex: Int

    public init(
        id: UUID = UUID(),
        kind: ElevationZoneKind = .doors,
        columns: Int = 1,
        shelfCount: Int = 2,
        drawerCount: Int = 3,
        drawerSystem: DrawerSystem = .amixSlimbox,
        drawerProfileName: String? = nil,
        railHeight: Millimeters = .zero,
        drawerFrontHeights: [Millimeters] = [],
        drawerLayoutMode: DrawerLayoutMode = .proportional,
        flexibleDrawerIndex: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.columns = min(max(columns, 1), 4)
        self.shelfCount = min(max(shelfCount, 0), 8)
        self.drawerCount = min(
            max(drawerCount, DrawerFrontStack.drawersPerZone.lowerBound),
            DrawerFrontStack.drawersPerZone.upperBound
        )
        self.drawerSystem = drawerSystem
        self.drawerProfileName = drawerProfileName ?? drawerSystem.defaultProfileName
        self.railHeight = max(railHeight, .zero)
        self.drawerLayoutMode = drawerLayoutMode
        self.flexibleDrawerIndex = max(flexibleDrawerIndex, 0)
        self.drawerFrontHeights = Self.normalizedDrawerFrontHeights(
            drawerFrontHeights,
            drawerCount: self.drawerCount
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case columns
        case shelfCount
        case drawerCount
        case drawerSystem
        case drawerProfileName
        case railHeight
        case drawerFrontHeights
        case drawerLayoutMode
        case flexibleDrawerIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSystem =
            try container.decodeIfPresent(
                DrawerSystem.self,
                forKey: .drawerSystem
            ) ?? .amixSlimbox
        let decodedDrawerCount =
            min(
                max(
                    try container.decodeIfPresent(
                        Int.self,
                        forKey: .drawerCount
                    ) ?? 3,
                    1
                ),
                6
            )

        self.id =
            try container.decodeIfPresent(
                UUID.self,
                forKey: .id
            ) ?? UUID()
        self.kind =
            try container.decodeIfPresent(
                ElevationZoneKind.self,
                forKey: .kind
            ) ?? .doors
        self.columns =
            min(
                max(
                    try container.decodeIfPresent(
                        Int.self,
                        forKey: .columns
                    ) ?? 1,
                    1
                ),
                4
            )
        self.shelfCount =
            min(
                max(
                    try container.decodeIfPresent(
                        Int.self,
                        forKey: .shelfCount
                    ) ?? 2,
                    0
                ),
                8
            )
        self.drawerCount = decodedDrawerCount
        self.drawerSystem = decodedSystem
        self.drawerProfileName =
            try container.decodeIfPresent(
                String.self,
                forKey: .drawerProfileName
            ) ?? decodedSystem.defaultProfileName
        self.railHeight =
            max(
                try container.decodeIfPresent(
                    Millimeters.self,
                    forKey: .railHeight
                ) ?? .zero,
                .zero
            )
        self.drawerFrontHeights =
            Self.normalizedDrawerFrontHeights(
                try container.decodeIfPresent(
                    [Millimeters].self,
                    forKey: .drawerFrontHeights
                ) ?? [],
                drawerCount: decodedDrawerCount
            )
        // Starsze zapisy nie mają trybu. Proporcjonalny jest właściwym
        // domyślnym, bo odtwarza zamysł układu po zmianie gabarytu.
        self.drawerLayoutMode =
            try container.decodeIfPresent(
                DrawerLayoutMode.self,
                forKey: .drawerLayoutMode
            ) ?? .proportional
        self.flexibleDrawerIndex =
            try container.decodeIfPresent(
                Int.self,
                forKey: .flexibleDrawerIndex
            ) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(drawerLayoutMode, forKey: .drawerLayoutMode)
        try container.encode(flexibleDrawerIndex, forKey: .flexibleDrawerIndex)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(columns, forKey: .columns)
        try container.encode(shelfCount, forKey: .shelfCount)
        try container.encode(drawerCount, forKey: .drawerCount)
        try container.encode(drawerSystem, forKey: .drawerSystem)
        try container.encode(
            drawerProfileName,
            forKey: .drawerProfileName
        )
        if railHeight > .zero {
            try container.encode(
                railHeight,
                forKey: .railHeight
            )
        }
        if !drawerFrontHeights.isEmpty {
            try container.encode(
                drawerFrontHeights,
                forKey: .drawerFrontHeights
            )
        }
    }

    fileprivate static func normalizedDrawerFrontHeights(
        _ heights: [Millimeters],
        drawerCount: Int
    ) -> [Millimeters] {
        Array(
            heights
                .filter { $0 > .zero }
                .prefix(
                    min(
                        max(drawerCount, DrawerFrontStack.drawersPerZone.lowerBound),
                        DrawerFrontStack.drawersPerZone.upperBound
                    )
                )
        )
    }

    /// Wybrany profil szuflady z bezpiecznym domyślnym.
    public var drawerProfile: DrawerProfile {
        DrawerProfile.profile(system: drawerSystem, name: drawerProfileName)
            ?? DrawerProfile.defaultProfile(for: drawerSystem)
    }
}

/// Front jako osobna warstwa nałożona na jedną lub wiele komór modułu.
/// Zakresy są inkluzywne: np. `lowerZoneIndex = 0`, `upperZoneIndex = 1`
/// oznacza front kryjący dwie strefy.
public struct ElevationFrontSpan: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var lowerZoneIndex: Int
    public var upperZoneIndex: Int
    public var leadingColumnIndex: Int
    public var trailingColumnIndex: Int
    public var opening: FurnitureFrontOpeningV020
    public var hardwareProfileID: String
    public var coversInternalDrawers: Bool
    public var sideGap: Millimeters
    public var verticalGap: Millimeters

    public init(
        id: UUID = UUID(),
        lowerZoneIndex: Int,
        upperZoneIndex: Int,
        leadingColumnIndex: Int = 0,
        trailingColumnIndex: Int = 0,
        opening: FurnitureFrontOpeningV020 = .leftHinged,
        hardwareProfileID: String = "",
        coversInternalDrawers: Bool = false,
        sideGap: Millimeters = 3,
        verticalGap: Millimeters = 3
    ) {
        self.id = id
        self.lowerZoneIndex = min(lowerZoneIndex, upperZoneIndex)
        self.upperZoneIndex = max(lowerZoneIndex, upperZoneIndex)
        self.leadingColumnIndex = min(leadingColumnIndex, trailingColumnIndex)
        self.trailingColumnIndex = max(leadingColumnIndex, trailingColumnIndex)
        self.opening = opening
        self.hardwareProfileID = hardwareProfileID
        self.coversInternalDrawers = coversInternalDrawers
        self.sideGap = max(sideGap, .zero)
        self.verticalGap = max(verticalGap, .zero)
    }

    public var displayName: String {
        switch opening {
        case .leftHinged, .rightHinged:
            return "Front drzwi"
        case .liftUp:
            return "Front podnoszony"
        case .flapDown:
            return "Front opuszczany"
        case .drawer:
            return "Front szuflady"
        case .sliding:
            return "Front przesuwny"
        case .fixed:
            return "Panel stały"
        }
    }
}

/// Moduł meblowy edytowany rysunkowo: gabaryt + poziome strefy od dołu do góry.
/// Podziały (`splits`) to wysokości cięć liczone od dna modułu; stref jest
/// zawsze o jeden więcej niż podziałów.
public struct ElevationModule: Codable, Hashable, Sendable {
    public var name: String
    public var width: Millimeters
    public var height: Millimeters
    public var depth: Millimeters
    public var carcassThickness: Millimeters

    public private(set) var splits: [Millimeters]
    public private(set) var zones: [ElevationZone]
    public private(set) var frontSpans: [ElevationFrontSpan]

    public static let minimumZoneHeight: Millimeters = 100

    public init(
        name: String = "Nowy moduł",
        width: Millimeters = 600,
        height: Millimeters = 720,
        depth: Millimeters = 560,
        carcassThickness: Millimeters = 18,
        splits: [Millimeters] = [],
        zones: [ElevationZone] = [],
        frontSpans: [ElevationFrontSpan] = []
    ) {
        self.name = name
        self.width = width
        self.height = height
        self.depth = depth
        self.carcassThickness = carcassThickness

        let sortedSplits = splits.sorted()
        self.splits = sortedSplits

        var normalized = zones
        let needed = sortedSplits.count + 1
        while normalized.count < needed {
            normalized.append(ElevationZone(kind: .doors))
        }
        if normalized.count > needed {
            normalized.removeLast(normalized.count - needed)
        }
        self.zones = normalized
        self.frontSpans = Self.normalizedFrontSpans(
            frontSpans,
            zoneCount: normalized.count
        )
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case width
        case height
        case depth
        case carcassThickness
        case splits
        case zones
        case frontSpans
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name:
                try container.decodeIfPresent(
                    String.self,
                    forKey: .name
                ) ?? "Nowy moduł",
            width:
                try container.decodeIfPresent(
                    Millimeters.self,
                    forKey: .width
                ) ?? 600,
            height:
                try container.decodeIfPresent(
                    Millimeters.self,
                    forKey: .height
                ) ?? 720,
            depth:
                try container.decodeIfPresent(
                    Millimeters.self,
                    forKey: .depth
                ) ?? 560,
            carcassThickness:
                try container.decodeIfPresent(
                    Millimeters.self,
                    forKey: .carcassThickness
                ) ?? 18,
            splits:
                try container.decodeIfPresent(
                    [Millimeters].self,
                    forKey: .splits
                ) ?? [],
            zones:
                try container.decodeIfPresent(
                    [ElevationZone].self,
                    forKey: .zones
                ) ?? [],
            frontSpans:
                try container.decodeIfPresent(
                    [ElevationFrontSpan].self,
                    forKey: .frontSpans
                ) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(depth, forKey: .depth)
        try container.encode(carcassThickness, forKey: .carcassThickness)
        try container.encode(splits, forKey: .splits)
        try container.encode(zones, forKey: .zones)
        if !frontSpans.isEmpty {
            try container.encode(frontSpans, forKey: .frontSpans)
        }
    }

    private static func normalizedFrontSpans(
        _ spans: [ElevationFrontSpan],
        zoneCount: Int
    ) -> [ElevationFrontSpan] {
        guard zoneCount > 0 else { return [] }
        return spans.map { span in
            ElevationFrontSpan(
                id: span.id,
                lowerZoneIndex:
                    min(max(span.lowerZoneIndex, 0), zoneCount - 1),
                upperZoneIndex:
                    min(max(span.upperZoneIndex, 0), zoneCount - 1),
                leadingColumnIndex:
                    min(max(span.leadingColumnIndex, 0), 3),
                trailingColumnIndex:
                    min(max(span.trailingColumnIndex, 0), 3),
                opening: span.opening,
                hardwareProfileID: span.hardwareProfileID,
                coversInternalDrawers: span.coversInternalDrawers,
                sideGap: span.sideGap,
                verticalGap: span.verticalGap
            )
        }
    }

    // MARK: Geometria stref

    /// Granice stref od dołu: [0, split..., height].
    public var boundaries: [Millimeters] {
        [Millimeters.zero] + splits + [height]
    }

    public struct ZoneSegment: Sendable {
        public let index: Int
        public let zone: ElevationZone
        public let lower: Millimeters
        public let upper: Millimeters
        public var zoneHeight: Millimeters { upper - lower }
    }

    /// Pojedyncza komora wynikająca z przecięcia poziomej strefy
    /// i pionowej kolumny. Na tym etapie komory są generowane z istniejących
    /// danych, więc nie wymagają migracji zapisanych modułów.
    public struct Cell: Identifiable, Hashable, Sendable {
        public var id: String { "z\(zoneIndex)-c\(columnIndex)" }
        public let zoneIndex: Int
        public let columnIndex: Int
        public let kind: ElevationZoneKind
        public let lower: Millimeters
        public let upper: Millimeters
        public let left: Millimeters
        public let right: Millimeters
        public let shelfCount: Int
        public let drawerCount: Int

        public var width: Millimeters { right - left }
        public var height: Millimeters { upper - lower }

        public var displayName: String {
            "Komora \(zoneIndex + 1).\(columnIndex + 1)"
        }
    }

    public var segments: [ZoneSegment] {
        let bounds = boundaries
        return zones.enumerated().map { index, zone in
            ZoneSegment(index: index, zone: zone, lower: bounds[index], upper: bounds[index + 1])
        }
    }

    /// Komory modułu od dołu do góry i od lewej do prawej.
    /// Dla stref AGD zwracana jest jedna pełna komora, niezależnie od liczby
    /// kolumn, bo AGD traktujemy jako pojedyncze światło techniczne.
    public var cells: [Cell] {
        segments.flatMap { segment in
            let zone = segment.zone
            let cols = zone.kind == .appliance
                ? 1
                : max(1, zone.columns)
            let columnWidth = zone.kind == .appliance
                ? width - carcassThickness * 2
                : columnInnerWidth(columns: cols)

            return (0..<cols).map { column in
                let left =
                    carcassThickness
                    + (columnWidth + carcassThickness)
                        * Double(column)
                let right = left + columnWidth

                return Cell(
                    zoneIndex: segment.index,
                    columnIndex: column,
                    kind: zone.kind,
                    lower: segment.lower,
                    upper: segment.upper,
                    left: left,
                    right: right,
                    shelfCount: zone.kind == .shelves
                        ? zone.shelfCount
                        : 0,
                    drawerCount: zone.kind == .drawers
                        ? zone.drawerCount
                        : 0
                )
            }
        }
    }

    /// Najmniejsza dopuszczalna wysokość modułu przy obecnych podziałach.
    public var minimumHeight: Millimeters {
        (splits.last ?? .zero) + Self.minimumZoneHeight
    }

    /// Światło kolumny przy zadanej liczbie kolumn (przegrody z płyty korpusowej).
    public func columnInnerWidth(columns: Int) -> Millimeters {
        let cols = Double(max(1, columns))
        return (width - carcassThickness * 2 - carcassThickness * (cols - 1)) / cols
    }

    // MARK: Operacje edycyjne

    /// Dzieli moduł poziomo na wysokości `y` (od dna). Nowa strefa (szuflady)
    /// zajmuje część poniżej cięcia. Zwraca indeks nowej strefy albo nil,
    /// gdy cięcie wypada za blisko istniejącej granicy.
    @discardableResult
    public mutating func splitZone(at y: Millimeters) -> Int? {
        let minH = Self.minimumZoneHeight.rawValue
        let farEnough = boundaries.allSatisfy { abs(($0 - y).rawValue) >= minH }
        guard farEnough, y > .zero, y < height else { return nil }

        let insertIndex = splits.firstIndex(where: { $0 > y }) ?? splits.count
        splits.insert(y, at: insertIndex)
        zones.insert(ElevationZone(kind: .drawers), at: insertIndex)
        frontSpans = Self.normalizedFrontSpans(
            frontSpans,
            zoneCount: zones.count
        )
        return insertIndex
    }

    /// Usuwa podział pod strefą `zoneIndex` — strefa znika, strefa poniżej
    /// przejmuje jej wysokość.
    @discardableResult
    public mutating func removeSplitBelow(zoneIndex: Int) -> Bool {
        guard zoneIndex >= 1, zoneIndex < zones.count else { return false }
        splits.remove(at: zoneIndex - 1)
        zones.remove(at: zoneIndex)
        frontSpans = Self.normalizedFrontSpans(
            frontSpans,
            zoneCount: zones.count
        )
        return true
    }

    /// Przesuwa podział z zachowaniem minimalnej wysokości sąsiednich stref.
    public mutating func moveSplit(at index: Int, to y: Millimeters) {
        guard splits.indices.contains(index) else { return }
        let lowerBound = (index == 0 ? .zero : splits[index - 1]) + Self.minimumZoneHeight
        let upperBound = (index == splits.count - 1 ? height : splits[index + 1]) - Self.minimumZoneHeight
        guard upperBound >= lowerBound else { return }
        splits[index] = min(max(y, lowerBound), upperBound)
    }

    /// Ustawia wysokość strefy. Dla najwyższej strefy zmienia wysokość modułu,
    /// dla pozostałych przesuwa podział nad strefą.
    public mutating func setZoneHeight(_ zoneHeight: Millimeters, forZoneAt index: Int) {
        guard zones.indices.contains(index), zoneHeight >= Self.minimumZoneHeight else { return }
        let lower = boundaries[index]
        if index == zones.count - 1 {
            height = max(lower + zoneHeight, minimumHeight)
        } else {
            moveSplit(at: index, to: lower + zoneHeight)
        }
    }

    /// Zmienia wysokość modułu nie schodząc poniżej najwyższego podziału.
    public mutating func setHeightClamped(_ newHeight: Millimeters) {
        height = max(newHeight, minimumHeight)
    }

    public mutating func addTopExtension(
        height extensionHeight: Millimeters,
        kind: ElevationZoneKind = .shelves
    ) {
        guard extensionHeight >= Self.minimumZoneHeight else {
            return
        }

        let split =
            height
        height =
            height + extensionHeight
        splits.append(split)
        zones.append(
            ElevationZone(
                kind:
                    kind,
                shelfCount:
                    kind == .shelves ? 1 : 0
            )
        )
        frontSpans = Self.normalizedFrontSpans(
            frontSpans,
            zoneCount: zones.count
        )
    }

    /// Modyfikuje strefę i normalizuje zakresy liczników.
    public mutating func updateZone(at index: Int, _ mutate: (inout ElevationZone) -> Void) {
        guard zones.indices.contains(index) else { return }
        mutate(&zones[index])
        zones[index].columns = min(max(zones[index].columns, 1), 4)
        zones[index].shelfCount = min(max(zones[index].shelfCount, 0), 8)
        zones[index].drawerCount = min(max(zones[index].drawerCount, 1), 6)
        zones[index].railHeight = max(zones[index].railHeight, .zero)
        zones[index].drawerFrontHeights =
            ElevationZone.normalizedDrawerFrontHeights(
                zones[index].drawerFrontHeights,
                drawerCount: zones[index].drawerCount
            )
        if DrawerProfile.profile(
            system: zones[index].drawerSystem,
            name: zones[index].drawerProfileName
        ) == nil {
            zones[index].drawerProfileName = zones[index].drawerSystem.defaultProfileName
        }
        frontSpans = Self.normalizedFrontSpans(
            frontSpans,
            zoneCount: zones.count
        )
    }

    /// Zastępuje warstwę frontów z zachowaniem normalizacji zakresów.
    public mutating func setFrontSpans(
        _ spans: [ElevationFrontSpan]
    ) {
        frontSpans = Self.normalizedFrontSpans(
            spans,
            zoneCount: zones.count
        )
    }

    public mutating func updateFrontSpan(
        id: UUID,
        _ mutate: (inout ElevationFrontSpan) -> Void
    ) {
        guard let index = frontSpans.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutate(&frontSpans[index])
        frontSpans = Self.normalizedFrontSpans(
            frontSpans,
            zoneCount: zones.count
        )
    }

    public mutating func removeFrontSpan(
        id: UUID
    ) {
        frontSpans.removeAll { $0.id == id }
    }

    public mutating func clearFrontSpans() {
        frontSpans = []
    }

    // MARK: Walidacja szuflad

    public func drawerLayout(forZoneAt index: Int) -> DrawerLayout? {
        guard zones.indices.contains(index), zones[index].kind == .drawers else { return nil }
        let segment = segments[index]
        let zone = zones[index]
        let baseLayout = DrawerLayoutCalculator.layout(
            zoneHeight: segment.zoneHeight,
            drawerCount: zone.drawerCount,
            columnInnerWidth: columnInnerWidth(columns: zone.columns),
            profile: zone.drawerProfile
        )
        let heights = drawerFrontHeights(forZoneAt: index)
        guard !heights.isEmpty else {
            return baseLayout
        }

        let minimumHeight =
            heights.map(\.rawValue).min()
            ?? baseLayout.frontHeight.rawValue
        let availableHeight =
            segment.zoneHeight
            - DrawerLayoutCalculator.bottomMargin
            - DrawerLayoutCalculator.topMargin
            - DrawerLayoutCalculator.frontGap
                * Double(max(zone.drawerCount - 1, 0))
        let sum =
            heights.reduce(0.0) {
                $0 + $1.rawValue
            }
        let fitsHeight =
            sum <= availableHeight.rawValue + 0.5
        let fitsProfile =
            heights.allSatisfy {
                $0 >= baseLayout.minimumOpening
            }

        return DrawerLayout(
            frontHeight: Millimeters(minimumHeight),
            minimumOpening: baseLayout.minimumOpening,
            maximumCount: baseLayout.maximumCount,
            boxWidth: baseLayout.boxWidth,
            isValid: fitsHeight && fitsProfile
        )
    }

    public func effectiveRailHeight(
        forZoneAt index: Int
    ) -> Millimeters? {
        guard zones.indices.contains(index),
              zones[index].kind == .hanging else {
            return nil
        }

        let segment =
            segments[index]
        let maximum =
            max(
                segment.zoneHeight - 60,
                .zero
            )
        guard maximum > .zero else {
            return nil
        }

        let automatic =
            max(
                min(
                    segment.zoneHeight - 180,
                    maximum
                ),
                min(maximum, 80)
            )

        let requested =
            zones[index].railHeight > .zero
            ? zones[index].railHeight
            : automatic

        return min(
            max(requested, min(maximum, 60)),
            maximum
        )
    }

    /// Szerokość jednego frontu nakładanego przy zadanej liczbie kolumn.
    ///
    /// **Front nakładany zakrywa korpus**, więc liczy się go od podziałki
    /// modułu, a nie od światła między bokami. Poprzednia wersja robiła
    /// `columnInnerWidth - 3` w pięciu miejscach — dla modułu 600 dawało to
    /// front **561 mm zamiast 596 mm**, czyli 35 mm odsłoniętego korpusu,
    /// a zaszyta trójka nie zgadzała się z żadną regułą projektu
    /// (`frontClearancePerEdge` = 2, `frontToFrontGap` = 4).
    ///
    /// Reguła: całe lico minus luz po obu stronach, minus fugi między frontami,
    /// podzielone na kolumny.
    ///
    /// Sam wzór mieszka w `ProductionRules`, bo ten sam rząd frontów rysuje
    /// też podgląd przestrzenny karty — i **rozjechał się**, licząc fugę
    /// także na obu skrajach zamiast luzu.
    public func frontWidth(forColumns columns: Int) -> Millimeters {
        ProductionRules.frontWidth(forModulePitch: width, columns: columns)
    }

    /// Pozycja lewej krawędzi frontu nakładanego dla kolumny `column`.
    ///
    /// Liczona **na licu modułu**, nie w świetle korpusu: luz 2 mm od krawędzi
    /// i fuga 4 mm między frontami. Dla modułu 600 z jedną kolumną daje
    /// x = 2 i front 2…598; przy dwóch kolumnach 2…298 i 302…598, czyli
    /// dokładnie 4 mm fugi — tyle, ile sprawdza `AssemblyInspector`.
    ///
    /// Wcześniej pozycja szła od `columnX + 1.5`, czyli od wnętrza korpusu.
    /// Po poprawieniu samej szerokości front wychodził poza gabaryt i kontrola
    /// produkcyjna słusznie to zgłaszała.
    public func frontX(forColumn column: Int, of columns: Int) -> Millimeters {
        let n = max(columns, 1)
        let c = min(max(column, 0), n - 1)
        let luz = ProductionRules.frontClearancePerEdge
        let szerokosc = frontWidth(forColumns: n)
        return luz + (szerokosc + ProductionRules.frontToFrontGap) * Double(c)
    }

    /// Wysokość frontu drzwiowego kryjącego strefę.
    ///
    /// Ta sama zasada co przy szerokości: luz 2 mm u góry i u dołu.
    public func doorFrontHeight(forZoneHeight zoneHeight: Millimeters) -> Millimeters {
        max(zoneHeight - ProductionRules.frontToFrontGap, Millimeters(1))
    }

    public func drawerFrontHeights(
        forZoneAt index: Int
    ) -> [Millimeters] {
        guard zones.indices.contains(index),
              zones[index].kind == .drawers else {
            return []
        }

        let zone = zones[index]
        let segment = segments[index]
        let count = max(zone.drawerCount, 1)
        let custom =
            ElevationZone.normalizedDrawerFrontHeights(
                zone.drawerFrontHeights,
                drawerCount: count
            )

        // **Fronty muszą wypełnić strefę co do milimetra.**
        //
        // Poprzednia wersja zwracała zapisane wysokości bez skalowania, jeśli
        // tylko mieściły się w świetle — układ 140/140/280 w module 900 mm
        // zostawiał 340 mm bryły bez frontu. A gdy suma przekraczała światło,
        // układ był po cichu wyrzucany i zastępowany równym podziałem, więc
        // projektant tracił to, co ustawił.
        //
        // `DrawerFrontStack` traktuje zapisane wysokości jako **proporcje**
        // i skaluje je do aktualnej wysokości strefy, więc zamysł („dwie
        // płytkie u góry, jedna głęboka na dole") przeżywa zmianę gabarytu.
        let tryb: DrawerFrontStack.Mode
        switch zone.drawerLayoutMode {
        case .equal:
            tryb = .equal
        case .proportional:
            tryb = custom.isEmpty ? .equal : .proportional(custom)
        case .keepSizes:
            tryb = custom.isEmpty
                ? .equal
                : .fixedWithFlexible(custom, flexibleIndex: zone.flexibleDrawerIndex)
        }

        let stos = DrawerFrontStack.heights(
            zoneHeight: segment.zoneHeight,
            count: count,
            mode: tryb,
            gap: DrawerLayoutCalculator.frontGap,
            bottomMargin: DrawerLayoutCalculator.bottomMargin,
            topMargin: DrawerLayoutCalculator.topMargin
        )
        if !stos.heights.isEmpty {
            return stos.heights
        }

        let layout = DrawerLayoutCalculator.layout(
            zoneHeight: segment.zoneHeight,
            drawerCount: count,
            columnInnerWidth: columnInnerWidth(columns: zone.columns),
            profile: zone.drawerProfile
        )
        return Array(
            repeating: layout.frontHeight,
            count: count
        )
    }

    /// Liczba stref szuflad, w których wybrany profil się nie mieści.
    public var invalidDrawerZoneCount: Int {
        zones.indices.reduce(0) { acc, index in
            guard zones[index].kind == .drawers else { return acc }
            let valid = drawerLayout(forZoneAt: index)?.isValid ?? true
            return acc + (valid ? 0 : 1)
        }
    }
}

// MARK: - Lista formatek

public enum ElevationCutMaterial: String, Codable, CaseIterable, Sendable {
    case board18
    case front18
    case hdf3

    public var displayName: String {
        switch self {
        case .board18: return "Płyta 18 mm"
        case .front18: return "Front 18 mm"
        case .hdf3: return "HDF 3 mm"
        }
    }

    public var thickness: Millimeters {
        switch self {
        case .board18, .front18: return 18
        case .hdf3: return 3
        }
    }
}

public struct ElevationCutItem: Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var length: Millimeters
    public var width: Millimeters
    public var count: Int
    public var material: ElevationCutMaterial

    public init(
        name: String,
        length: Millimeters,
        width: Millimeters,
        count: Int,
        material: ElevationCutMaterial
    ) {
        self.name = name
        self.length = length
        self.width = width
        self.count = count
        self.material = material
    }
}

public extension ElevationModule {
    /// Lista formatek modułu: korpus + zawartość stref.
    /// Uproszczenia frontów: luz 3 mm; strefa AGD nie generuje elementów.
    func cutList() -> [ElevationCutItem] {
        var items: [ElevationCutItem] = []
        let t = carcassThickness
        let innerWidth = width - t * 2

        func add(
            _ itemName: String,
            _ length: Millimeters,
            _ itemWidth: Millimeters,
            _ count: Int,
            _ material: ElevationCutMaterial
        ) {
            guard count > 0, length > .zero, itemWidth > .zero else { return }
            items.append(ElevationCutItem(
                name: itemName,
                length: length,
                width: itemWidth,
                count: count,
                material: material
            ))
        }

        add("Bok", height, depth, 2, .board18)
        add("Dno", innerWidth, depth, 1, .board18)
        add("Trawers", innerWidth, 100, 2, .board18)
        add("Plecy", height - t * 2, innerWidth, 1, .hdf3)
        let useFrontLayer = !frontSpans.isEmpty

        for segment in segments {
            let zone = segment.zone
            guard zone.kind != .appliance else { continue }

            let cols = max(1, zone.columns)
            let columnWidth = columnInnerWidth(columns: cols)

            if cols > 1 {
                add("Przegroda pionowa", segment.zoneHeight, depth - 20, cols - 1, .board18)
            }

            switch zone.kind {
            case .drawers:
                let layout = DrawerLayoutCalculator.layout(
                    zoneHeight: segment.zoneHeight,
                    drawerCount: zone.drawerCount,
                    columnInnerWidth: columnWidth,
                    profile: zone.drawerProfile
                )
                let frontHeights =
                    drawerFrontHeights(
                        forZoneAt: segment.index
                    )
                let uniqueHeights =
                    Set(
                        frontHeights.map {
                            Int($0.rawValue.rounded())
                        }
                    )

                if !useFrontLayer {
                    if uniqueHeights.count <= 1,
                       let height = frontHeights.first {
                        add(
                            "Front szuflady (\(zone.drawerProfile.name))",
                            height,
                            frontWidth(forColumns: cols),
                            frontHeights.count * cols,
                            .front18
                        )
                    } else {
                        for (index, height) in frontHeights.enumerated() {
                            add(
                                "Front szuflady \(index + 1) (\(zone.drawerProfile.name))",
                                height,
                                frontWidth(forColumns: cols),
                                cols,
                                .front18
                            )
                        }
                    }
                }

                add(
                    "Dno szuflady",
                    depth - 60,
                    layout.boxWidth,
                    frontHeights.count * cols,
                    .hdf3
                )

            case .doors:
                if !useFrontLayer {
                    add("Front drzwi", doorFrontHeight(forZoneHeight: segment.zoneHeight), frontWidth(forColumns: cols), cols, .front18)
                }

            case .shelves:
                add("Półka", columnWidth, depth - 20, zone.shelfCount * cols, .board18)

            case .hanging:
                break

            case .appliance:
                break
            }
        }

        if useFrontLayer {
            for span in frontSpans {
                guard let lico = frontSpanFaceV0104(span) else { continue }
                add(
                    span.displayName,
                    lico.height,
                    lico.width,
                    1,
                    .front18
                )
            }
        }
        return items
    }

    var totalCutPieces: Int {
        cutList().reduce(0) { $0 + $1.count }
    }

    /// Geometria frontu warstwowego **na licu modułu**.
    ///
    /// `frontSpanBounds` zwraca obrys **komór**, czyli światło między bokami
    /// korpusu. Liczenie z niego szerokości frontu powtarza dokładnie ten błąd,
    /// który 2026-08-27 dał front 561 mm w module 600: front nakładany zakrywa
    /// korpus, więc mierzy się go od podziałki modułu, a nie od wnętrza.
    ///
    /// Ta funkcja liczy tak samo jak `frontWidth(forColumns:)` i
    /// `frontX(forColumn:of:)` dla frontów generowanych per strefa — jedna
    /// reguła dla obu dróg, bo inaczej ten sam mebel dostawałby fronty różniące
    /// się o 2 mm zależnie od tego, czy ma własną warstwę frontów.
    ///
    /// **`sideGap` i `verticalGap` nie biorą tu udziału.** Zostały w modelu dla
    /// zgodności zapisów (domyślnie 3 mm, co nie zgadza się z konwencją
    /// `frontToFrontGap` = 4 mm), ale geometria idzie z `ProductionRules`.
    func frontSpanFaceV0104(
        _ span: ElevationFrontSpan
    ) -> (x: Millimeters, y: Millimeters, width: Millimeters, height: Millimeters)? {
        guard let bounds = frontSpanBounds(span) else { return nil }

        // Liczba kolumn bierze się ze strefy, którą front przykrywa —
        // podziałka frontu zależy od podziału tej strefy, nie od modułu.
        let zoneIndex = min(max(span.lowerZoneIndex, 0), max(zones.count - 1, 0))
        let cols = zones.indices.contains(zoneIndex)
            ? max(1, zones[zoneIndex].columns)
            : 1

        let pierwsza = min(max(span.leadingColumnIndex, 0), cols - 1)
        let ostatnia = min(max(span.trailingColumnIndex, 0), cols - 1)

        let x = frontX(forColumn: pierwsza, of: cols)
        let prawaKrawedz =
            frontX(forColumn: ostatnia, of: cols)
            + frontWidth(forColumns: cols)

        // Wysokość: pełny zakres przykrytych stref minus luz u góry i u dołu —
        // ta sama reguła co `doorFrontHeight(forZoneHeight:)`.
        let wysokosc = max(
            bounds.upper - bounds.lower - ProductionRules.frontToFrontGap,
            Millimeters(1)
        )

        return (
            x: x,
            y: bounds.lower + ProductionRules.frontClearancePerEdge,
            width: max(prawaKrawedz - x, Millimeters(1)),
            height: wysokosc
        )
    }

    func frontSpanBounds(
        _ span: ElevationFrontSpan
    ) -> (
        left: Millimeters,
        right: Millimeters,
        lower: Millimeters,
        upper: Millimeters,
        width: Millimeters,
        height: Millimeters
    )? {
        let covered = cells.filter { cell in
            cell.zoneIndex >= span.lowerZoneIndex
            && cell.zoneIndex <= span.upperZoneIndex
            && cell.columnIndex >= span.leadingColumnIndex
            && cell.columnIndex <= span.trailingColumnIndex
        }
        guard !covered.isEmpty else { return nil }

        let left = covered.map(\.left).min() ?? .zero
        let right = covered.map(\.right).max() ?? .zero
        let lower = covered.map(\.lower).min() ?? .zero
        let upper = covered.map(\.upper).max() ?? .zero

        return (
            left: left,
            right: right,
            lower: lower,
            upper: upper,
            width: right - left,
            height: upper - lower
        )
    }
}

// MARK: - Produkcyjny snapshot i delta

public struct ElevationProductionSnapshot: Hashable, Sendable {
    public var cutItemRows: Int
    public var cutPieceCount: Int
    public var boardPieceCount: Int
    public var frontPieceCount: Int
    public var hdfPieceCount: Int
    public var shelfCount: Int
    public var drawerBoxCount: Int
    public var dividerCount: Int
    public var boardAreaM2: Double
    public var frontAreaM2: Double
    public var hdfAreaM2: Double
    public var totalAreaM2: Double
    public var estimatedBandingM: Double
    public var hingeCount: Int
    public var drawerRunnerPairCount: Int
    public var shelfSupportCount: Int
    public var liftMechanismSetCount: Int
    public var slidingTrackSetCount: Int
    public var hardwareItemCount: Int
    public var estimatedHardwareCostNetto: Double
    public var estimatedBoardCostNetto: Double
    public var estimatedFrontCostNetto: Double
    public var estimatedHdfCostNetto: Double
    public var estimatedBandingCostNetto: Double
    public var estimatedMaterialCostNetto: Double
    public var estimatedLaborCostNetto: Double
    public var estimatedBaseCostNetto: Double
    public var estimatedRetailPriceNetto: Double
    public var estimatedMarginNetto: Double

    public init(
        cutItemRows: Int,
        cutPieceCount: Int,
        boardPieceCount: Int,
        frontPieceCount: Int,
        hdfPieceCount: Int,
        shelfCount: Int,
        drawerBoxCount: Int,
        dividerCount: Int,
        boardAreaM2: Double,
        frontAreaM2: Double,
        hdfAreaM2: Double,
        totalAreaM2: Double,
        estimatedBandingM: Double,
        hingeCount: Int,
        drawerRunnerPairCount: Int,
        shelfSupportCount: Int,
        liftMechanismSetCount: Int,
        slidingTrackSetCount: Int,
        hardwareItemCount: Int,
        estimatedHardwareCostNetto: Double,
        estimatedBoardCostNetto: Double,
        estimatedFrontCostNetto: Double,
        estimatedHdfCostNetto: Double,
        estimatedBandingCostNetto: Double,
        estimatedMaterialCostNetto: Double,
        estimatedLaborCostNetto: Double,
        estimatedBaseCostNetto: Double,
        estimatedRetailPriceNetto: Double,
        estimatedMarginNetto: Double
    ) {
        self.cutItemRows = cutItemRows
        self.cutPieceCount = cutPieceCount
        self.boardPieceCount = boardPieceCount
        self.frontPieceCount = frontPieceCount
        self.hdfPieceCount = hdfPieceCount
        self.shelfCount = shelfCount
        self.drawerBoxCount = drawerBoxCount
        self.dividerCount = dividerCount
        self.boardAreaM2 = boardAreaM2
        self.frontAreaM2 = frontAreaM2
        self.hdfAreaM2 = hdfAreaM2
        self.totalAreaM2 = totalAreaM2
        self.estimatedBandingM = estimatedBandingM
        self.hingeCount = hingeCount
        self.drawerRunnerPairCount = drawerRunnerPairCount
        self.shelfSupportCount = shelfSupportCount
        self.liftMechanismSetCount = liftMechanismSetCount
        self.slidingTrackSetCount = slidingTrackSetCount
        self.hardwareItemCount = hardwareItemCount
        self.estimatedHardwareCostNetto = estimatedHardwareCostNetto
        self.estimatedBoardCostNetto = estimatedBoardCostNetto
        self.estimatedFrontCostNetto = estimatedFrontCostNetto
        self.estimatedHdfCostNetto = estimatedHdfCostNetto
        self.estimatedBandingCostNetto = estimatedBandingCostNetto
        self.estimatedMaterialCostNetto = estimatedMaterialCostNetto
        self.estimatedLaborCostNetto = estimatedLaborCostNetto
        self.estimatedBaseCostNetto = estimatedBaseCostNetto
        self.estimatedRetailPriceNetto = estimatedRetailPriceNetto
        self.estimatedMarginNetto = estimatedMarginNetto
    }
}

public struct ElevationProductionDelta: Hashable, Sendable {
    public var cutItemRows: Int
    public var cutPieceCount: Int
    public var boardPieceCount: Int
    public var frontPieceCount: Int
    public var hdfPieceCount: Int
    public var shelfCount: Int
    public var drawerBoxCount: Int
    public var dividerCount: Int
    public var boardAreaM2: Double
    public var frontAreaM2: Double
    public var hdfAreaM2: Double
    public var totalAreaM2: Double
    public var estimatedBandingM: Double
    public var hingeCount: Int
    public var drawerRunnerPairCount: Int
    public var shelfSupportCount: Int
    public var liftMechanismSetCount: Int
    public var slidingTrackSetCount: Int
    public var hardwareItemCount: Int
    public var estimatedHardwareCostNetto: Double
    public var estimatedBoardCostNetto: Double
    public var estimatedFrontCostNetto: Double
    public var estimatedHdfCostNetto: Double
    public var estimatedBandingCostNetto: Double
    public var estimatedMaterialCostNetto: Double
    public var estimatedLaborCostNetto: Double
    public var estimatedBaseCostNetto: Double
    public var estimatedRetailPriceNetto: Double
    public var estimatedMarginNetto: Double

    public init(
        before: ElevationProductionSnapshot,
        after: ElevationProductionSnapshot
    ) {
        cutItemRows = after.cutItemRows - before.cutItemRows
        cutPieceCount = after.cutPieceCount - before.cutPieceCount
        boardPieceCount = after.boardPieceCount - before.boardPieceCount
        frontPieceCount = after.frontPieceCount - before.frontPieceCount
        hdfPieceCount = after.hdfPieceCount - before.hdfPieceCount
        shelfCount = after.shelfCount - before.shelfCount
        drawerBoxCount = after.drawerBoxCount - before.drawerBoxCount
        dividerCount = after.dividerCount - before.dividerCount
        boardAreaM2 = after.boardAreaM2 - before.boardAreaM2
        frontAreaM2 = after.frontAreaM2 - before.frontAreaM2
        hdfAreaM2 = after.hdfAreaM2 - before.hdfAreaM2
        totalAreaM2 = after.totalAreaM2 - before.totalAreaM2
        estimatedBandingM = after.estimatedBandingM - before.estimatedBandingM
        hingeCount = after.hingeCount - before.hingeCount
        drawerRunnerPairCount =
            after.drawerRunnerPairCount - before.drawerRunnerPairCount
        shelfSupportCount = after.shelfSupportCount - before.shelfSupportCount
        liftMechanismSetCount =
            after.liftMechanismSetCount - before.liftMechanismSetCount
        slidingTrackSetCount =
            after.slidingTrackSetCount - before.slidingTrackSetCount
        hardwareItemCount = after.hardwareItemCount - before.hardwareItemCount
        estimatedHardwareCostNetto =
            after.estimatedHardwareCostNetto
            - before.estimatedHardwareCostNetto
        estimatedBoardCostNetto =
            after.estimatedBoardCostNetto - before.estimatedBoardCostNetto
        estimatedFrontCostNetto =
            after.estimatedFrontCostNetto - before.estimatedFrontCostNetto
        estimatedHdfCostNetto =
            after.estimatedHdfCostNetto - before.estimatedHdfCostNetto
        estimatedBandingCostNetto =
            after.estimatedBandingCostNetto - before.estimatedBandingCostNetto
        estimatedMaterialCostNetto =
            after.estimatedMaterialCostNetto - before.estimatedMaterialCostNetto
        estimatedLaborCostNetto =
            after.estimatedLaborCostNetto - before.estimatedLaborCostNetto
        estimatedBaseCostNetto =
            after.estimatedBaseCostNetto - before.estimatedBaseCostNetto
        estimatedRetailPriceNetto =
            after.estimatedRetailPriceNetto - before.estimatedRetailPriceNetto
        estimatedMarginNetto =
            after.estimatedMarginNetto - before.estimatedMarginNetto
    }

    public var hasChanges: Bool {
        cutItemRows != 0
        || cutPieceCount != 0
        || boardPieceCount != 0
        || frontPieceCount != 0
        || hdfPieceCount != 0
        || shelfCount != 0
        || drawerBoxCount != 0
        || dividerCount != 0
        || abs(boardAreaM2) > 0.0001
        || abs(frontAreaM2) > 0.0001
        || abs(hdfAreaM2) > 0.0001
        || abs(totalAreaM2) > 0.0001
        || abs(estimatedBandingM) > 0.0001
        || hingeCount != 0
        || drawerRunnerPairCount != 0
        || shelfSupportCount != 0
        || liftMechanismSetCount != 0
        || slidingTrackSetCount != 0
        || hardwareItemCount != 0
        || abs(estimatedHardwareCostNetto) > 0.0001
        || abs(estimatedMaterialCostNetto) > 0.0001
        || abs(estimatedLaborCostNetto) > 0.0001
        || abs(estimatedBaseCostNetto) > 0.0001
        || abs(estimatedRetailPriceNetto) > 0.0001
        || abs(estimatedMarginNetto) > 0.0001
    }
}

public extension ElevationModule {
    func productionSnapshot() -> ElevationProductionSnapshot {
        let items = cutList()

        func count(
            where predicate: (ElevationCutItem) -> Bool
        ) -> Int {
            items
                .filter(predicate)
                .reduce(0) {
                    $0 + $1.count
                }
        }

        func area(
            for material:
                ElevationCutMaterial
        ) -> Double {
            items
                .filter {
                    $0.material == material
                }
                .reduce(0.0) {
                    $0 + $1.areaM2
                }
        }

        let boardArea =
            area(for: .board18)
        let frontArea =
            area(for: .front18)
        let hdfArea =
            area(for: .hdf3)
        let hardware =
            estimatedHardwareUsage()
        let cutPieceCount =
            items.reduce(0) {
                $0 + $1.count
            }
        let estimatedBanding =
            items.reduce(0.0) {
                $0 + $1.estimatedBandingM
            }
        let boardCost =
            boardArea
            * Self.estimatedBoardCostNettoPerM2
        let frontCost =
            frontArea
            * Self.estimatedFrontCostNettoPerM2
        let hdfCost =
            hdfArea
            * Self.estimatedHdfCostNettoPerM2
        let bandingCost =
            estimatedBanding
            * Self.estimatedBandingCostNettoPerM
        let materialCost =
            boardCost
            + frontCost
            + hdfCost
            + bandingCost
        let laborCost =
            Double(cutPieceCount)
            * Self.estimatedCutPieceLaborCostNetto
            + Double(hardware.itemCount)
            * Self.estimatedHardwareHandlingCostNetto
        let baseCost =
            materialCost
            + hardware.estimatedCostNetto
            + laborCost
        let retailPrice =
            baseCost
            * Self.estimatedRetailMarkupFactor

        return ElevationProductionSnapshot(
            cutItemRows:
                items.count,
            cutPieceCount:
                cutPieceCount,
            boardPieceCount:
                count {
                    $0.material == .board18
                },
            frontPieceCount:
                count {
                    $0.material == .front18
                },
            hdfPieceCount:
                count {
                    $0.material == .hdf3
                },
            shelfCount:
                count {
                    $0.name == "Półka"
                },
            drawerBoxCount:
                count {
                    $0.name == "Dno szuflady"
                },
            dividerCount:
                count {
                    $0.name == "Przegroda pionowa"
                },
            boardAreaM2:
                boardArea,
            frontAreaM2:
                frontArea,
            hdfAreaM2:
                hdfArea,
            totalAreaM2:
                boardArea
                + frontArea
                + hdfArea,
            estimatedBandingM:
                estimatedBanding,
            hingeCount:
                hardware.hingeCount,
            drawerRunnerPairCount:
                hardware.drawerRunnerPairCount,
            shelfSupportCount:
                hardware.shelfSupportCount,
            liftMechanismSetCount:
                hardware.liftMechanismSetCount,
            slidingTrackSetCount:
                hardware.slidingTrackSetCount,
            hardwareItemCount:
                hardware.itemCount,
            estimatedHardwareCostNetto:
                hardware.estimatedCostNetto,
            estimatedBoardCostNetto:
                boardCost,
            estimatedFrontCostNetto:
                frontCost,
            estimatedHdfCostNetto:
                hdfCost,
            estimatedBandingCostNetto:
                bandingCost,
            estimatedMaterialCostNetto:
                materialCost,
            estimatedLaborCostNetto:
                laborCost,
            estimatedBaseCostNetto:
                baseCost,
            estimatedRetailPriceNetto:
                retailPrice,
            estimatedMarginNetto:
                retailPrice - baseCost
        )
    }
}

private struct ElevationEstimatedHardwareUsage: Hashable, Sendable {
    var hingeCount: Int = 0
    var drawerRunnerPairCount: Int = 0
    var shelfSupportCount: Int = 0
    var liftMechanismSetCount: Int = 0
    var slidingTrackSetCount: Int = 0
    var estimatedCostNetto: Double = 0

    var itemCount: Int {
        hingeCount
        + drawerRunnerPairCount
        + shelfSupportCount
        + liftMechanismSetCount
        + slidingTrackSetCount
    }
}

private extension ElevationModule {
    func estimatedHardwareUsage() -> ElevationEstimatedHardwareUsage {
        var usage =
            ElevationEstimatedHardwareUsage()
        let useFrontLayer =
            !frontSpans.isEmpty

        for segment in segments {
            let zone =
                segment.zone
            guard zone.kind != .appliance else { continue }

            let cols =
                max(1, zone.columns)

            switch zone.kind {
            case .drawers:
                let heights =
                    drawerFrontHeights(
                        forZoneAt: segment.index
                    )
                usage.drawerRunnerPairCount +=
                    heights.count * cols
                for height in heights {
                    usage.estimatedCostNetto +=
                        Self.estimatedDrawerRunnerPairCost(
                            system: zone.drawerSystem,
                            frontHeight: height
                        )
                        * Double(cols)
                }

            case .doors:
                guard !useFrontLayer else { continue }
                let hingesPerFront =
                    ProductionRules.hingeCount(
                        forFrontHeight: segment.zoneHeight
                    )
                usage.hingeCount +=
                    hingesPerFront * cols
                usage.estimatedCostNetto +=
                    Double(hingesPerFront * cols)
                    * Self.estimatedHingeCostNetto

            case .shelves:
                let supports =
                    zone.shelfCount
                    * cols
                    * ProductionRules.shelfSupportsPerShelf
                usage.shelfSupportCount +=
                    supports
                usage.estimatedCostNetto +=
                    Double(supports)
                    * Self.estimatedShelfSupportCostNetto

            case .hanging:
                let supports =
                    cols * 2
                usage.shelfSupportCount +=
                    supports
                usage.estimatedCostNetto +=
                    Double(supports)
                    * Self.estimatedShelfSupportCostNetto

            case .appliance:
                break
            }
        }

        if useFrontLayer {
            for span in frontSpans {
                guard let bounds =
                    frontSpanBounds(span)
                else { continue }

                switch span.opening {
                case .leftHinged, .rightHinged:
                    let count =
                        ProductionRules.hingeCount(
                            forFrontHeight: bounds.height
                        )
                    usage.hingeCount += count
                    usage.estimatedCostNetto +=
                        Double(count)
                        * Self.estimatedHingeCostNetto

                case .liftUp, .flapDown:
                    usage.liftMechanismSetCount += 1
                    usage.estimatedCostNetto +=
                        Self.estimatedLiftMechanismSetCostNetto

                case .sliding:
                    usage.slidingTrackSetCount += 1
                    usage.estimatedCostNetto +=
                        Self.estimatedSlidingTrackSetCostNetto

                case .drawer, .fixed:
                    break
                }
            }
        }

        return usage
    }

    static func estimatedDrawerRunnerPairCost(
        system: DrawerSystem,
        frontHeight: Millimeters
    ) -> Double {
        let isHighDrawer =
            frontHeight.rawValue >= 220

        switch system {
        case .amixSlimbox:
            return isHighDrawer ? 100 : 80
        case .gtvAxisPro:
            return isHighDrawer ? 130 : 95
        case .blumLegrabox:
            return isHighDrawer ? 260 : 220
        }
    }

    static var estimatedHingeCostNetto: Double { 12 }
    static var estimatedShelfSupportCostNetto: Double { 0.80 }
    static var estimatedLiftMechanismSetCostNetto: Double { 90 }
    static var estimatedSlidingTrackSetCostNetto: Double { 140 }
    static var estimatedBoardCostNettoPerM2: Double { 75 }
    static var estimatedFrontCostNettoPerM2: Double { 180 }
    static var estimatedHdfCostNettoPerM2: Double { 20 }
    static var estimatedBandingCostNettoPerM: Double { 4 }
    static var estimatedCutPieceLaborCostNetto: Double { 10 }
    static var estimatedHardwareHandlingCostNetto: Double { 3 }
    static var estimatedRetailMarkupFactor: Double { 1.55 }
}

private extension ElevationCutItem {
    var areaM2: Double {
        length.rawValue
        * width.rawValue
        * Double(count)
        / 1_000_000
    }

    var estimatedBandingM: Double {
        switch material {
        case .front18:
            return 2
                * (
                    length.rawValue
                    + width.rawValue
                )
                * Double(count)
                / 1000

        case .board18:
            return visibleBoardEdgeMM
                * Double(count)
                / 1000

        case .hdf3:
            return 0
        }
    }

    var visibleBoardEdgeMM: Double {
        switch name {
        case "Bok",
             "Dno",
             "Trawers",
             "Półka",
             "Przegroda pionowa":
            return length.rawValue
        default:
            return 0
        }
    }
}

// MARK: - Rekonstrukcja z FurnitureAssembly (mapowanie wsteczne)

public extension ElevationModule {
    /// Odtwarza edytowalny moduł elewacji z istniejącego zespołu.
    ///
    /// Mapowanie jest stratne, ale deterministyczne: gabaryt i grubość płyty
    /// przenoszą się zawsze; strefy odtwarzane są z geometrii komponentów —
    /// fronty grupowane w poziome pasma (wiele wierszy o równej wysokości =
    /// szuflady, pojedynczy wiersz = drzwi; odrębne kolumny X = przegrody),
    /// półki poza pasmami frontów tworzą strefę półek, a przerwa > 150 mm
    /// między pasmami staje się strefą AGD. System/profil szuflad wraca do
    /// domyślnych (geometria ich nie koduje); pojedyncza szuflada odtworzy
    /// się jako drzwi.
    static func reconstructed(from assembly: FurnitureAssembly) -> ElevationModule {
        let carcass = assembly.components.first { $0.role == .side }?.size.width
            ?? Millimeters(18)

        struct Row {
            var y0: Double
            var y1: Double
            var xKeys: Set<Int>
            var height: Double { y1 - y0 }
        }
        struct Band {
            var kind: ElevationZoneKind
            var lower: Double
            var upper: Double
            var rows: Int
            var columns: Int
            var shelfTotal: Int
            var railHeight: Double = 0
        }

        // 1. Fronty → wiersze (klaster po dolnej krawędzi, tolerancja 2 mm).
        let fronts = assembly.components
            .filter { $0.role == .front }
            .sorted { $0.localPosition.y < $1.localPosition.y }

        var rows: [Row] = []
        for front in fronts {
            let y0 = front.localPosition.y.rawValue
            let y1 = y0 + front.size.height.rawValue
            let xKey = Int((front.localPosition.x.rawValue / 5).rounded())
            if var last = rows.last, abs(last.y0 - y0) < 2 {
                last.xKeys.insert(xKey)
                last.y1 = max(last.y1, y1)
                rows[rows.count - 1] = last
            } else {
                rows.append(Row(y0: y0, y1: y1, xKeys: [xKey]))
            }
        }

        // 2. Wiersze → pasma: mała przerwa (≤ 12 mm) i zbliżona wysokość
        //    frontu (±30 mm) = stos szuflad; inaczej nowe pasmo.
        var bands: [Band] = []
        var index = 0
        while index < rows.count {
            var last = index
            var columns = rows[index].xKeys.count
            while last + 1 < rows.count,
                  rows[last + 1].y0 - rows[last].y1 <= 12,
                  abs(rows[last + 1].height - rows[index].height) <= 30 {
                last += 1
                columns = max(columns, rows[last].xKeys.count)
            }
            let rowCount = last - index + 1
            bands.append(Band(
                kind: rowCount > 1 ? .drawers : .doors,
                lower: rows[index].y0,
                upper: rows[last].y1,
                rows: rowCount,
                columns: max(1, columns),
                shelfTotal: 0,
                railHeight: 0
            ))
            index = last + 1
        }

        // 3. Półki poza pasmami frontów → pasma półek.
        let looseShelves = assembly.components
            .filter { $0.role == .shelf }
            .map { (y: $0.localPosition.y.rawValue,
                    xKey: Int(($0.localPosition.x.rawValue / 5).rounded())) }
            .filter { shelf in
                !bands.contains { shelf.y >= $0.lower - 2 && shelf.y <= $0.upper + 2 }
            }
            .sorted { $0.y < $1.y }

        var shelfGroups: [[(y: Double, xKey: Int)]] = []
        for shelf in looseShelves {
            if var group = shelfGroups.last,
               let previous = group.last,
               shelf.y - previous.y <= 600 {
                group.append(shelf)
                shelfGroups[shelfGroups.count - 1] = group
            } else {
                shelfGroups.append([shelf])
            }
        }
        for group in shelfGroups {
            guard let first = group.first, let lastShelf = group.last else { continue }
            let columns = max(1, Set(group.map(\.xKey)).count)
            bands.append(Band(
                kind: .shelves,
                lower: first.y,
                upper: lastShelf.y + carcass.rawValue,
                rows: 0,
                columns: columns,
                shelfTotal: group.count,
                railHeight: 0
            ))
        }

        let rails = assembly.components
            .filter { $0.role == .rail }
            .sorted { $0.localPosition.y < $1.localPosition.y }

        if bands.isEmpty, let rail = rails.first {
            bands.append(
                Band(
                    kind: .hanging,
                    lower: 0,
                    upper: assembly.size.height.rawValue,
                    rows: 0,
                    columns: 1,
                    shelfTotal: 0,
                    railHeight: rail.localPosition.y.rawValue
                )
            )
        }

        bands.sort { $0.lower < $1.lower }

        // 4. Brak frontów i półek → pojedyncza strefa drzwi.
        guard !bands.isEmpty else {
            return ElevationModule(
                name: assembly.name,
                width: assembly.size.width,
                height: assembly.size.height,
                depth: assembly.size.depth,
                carcassThickness: carcass
            )
        }

        func zone(for band: Band) -> ElevationZone {
            switch band.kind {
            case .drawers:
                return ElevationZone(
                    kind: .drawers,
                    columns: band.columns,
                    drawerCount: min(band.rows, 6)
                )
            case .doors:
                return ElevationZone(kind: .doors, columns: band.columns)
            case .shelves:
                return ElevationZone(
                    kind: .shelves,
                    columns: band.columns,
                    shelfCount: min(max(band.shelfTotal / band.columns, 0), 8)
                )
            case .hanging:
                return ElevationZone(
                    kind: .hanging,
                    columns: band.columns,
                    railHeight:
                        Millimeters(
                            max(band.railHeight, 0)
                        )
                )
            case .appliance:
                return ElevationZone(kind: .appliance)
            }
        }

        // 5. Pasma → strefy i podziały; duża przerwa = strefa AGD.
        var zones: [ElevationZone] = [zone(for: bands[0])]
        var splits: [Millimeters] = []
        for k in 1..<bands.count {
            let gap = bands[k].lower - bands[k - 1].upper
            if gap > 150 {
                splits.append(Millimeters((bands[k - 1].upper + 3).rounded()))
                zones.append(ElevationZone(kind: .appliance))
                splits.append(Millimeters((bands[k].lower - 3).rounded()))
                zones.append(zone(for: bands[k]))
            } else {
                let mid = ((bands[k - 1].upper + bands[k].lower) / 2).rounded()
                splits.append(Millimeters(mid))
                zones.append(zone(for: bands[k]))
            }
        }

        return ElevationModule(
            name: assembly.name,
            width: assembly.size.width,
            height: assembly.size.height,
            depth: assembly.size.depth,
            carcassThickness: carcass,
            splits: splits,
            zones: zones
        )
    }
}

// MARK: - Adapter do FurnitureAssembly

public extension ElevationModule {
    /// Buduje `FurnitureAssembly` z komponentami odpowiadającymi liście formatek.
    /// Konwencja pozycji jak w `CabinetComponentFactory`: `localPosition` = róg
    /// minimalny (dolny-lewy-przód), X = szerokość, Y = wysokość, Z = głębokość.
    func makeAssembly(named assemblyName: String? = nil) throws -> FurnitureAssembly {
        var components: [FurnitureComponent] = []
        let t = carcassThickness
        let innerWidth = width - t * 2

        func add(
            _ code: String,
            _ role: FurnitureComponentRole,
            w: Millimeters, h: Millimeters, d: Millimeters,
            x: Millimeters, y: Millimeters, z: Millimeters,
            opening: FurnitureFrontOpeningV020? = nil
        ) throws {
            guard w > .zero, h > .zero, d > .zero else { return }
            components.append(try FurnitureComponent(
                code: code,
                role: role,
                size: Size3MM(width: w, height: h, depth: d),
                localPosition: Point3MM(x: x, y: y, z: z),
                opening: opening
            ))
        }

        // **Warstwa frontów wygrywa z frontami generowanymi per strefa.**
        //
        // `cutList()` respektowało ją od dawna, a `makeAssembly` nie —
        // ten sam moduł miał więc inne fronty na liście formatek i inne
        // w zespole, który karmi kontrolę produkcyjną, kartę techniczną i 3D.
        // Kontrola sprawdzała fronty, których lista formatek nie zamawiała.
        let useFrontLayer = !frontSpans.isEmpty

        try add("BOK-L", .side, w: t, h: height, d: depth, x: .zero, y: .zero, z: .zero)
        try add("BOK-P", .side, w: t, h: height, d: depth, x: width - t, y: .zero, z: .zero)
        try add("DNO", .bottom, w: innerWidth, h: t, d: depth, x: t, y: .zero, z: .zero)
        try add("TRAWERS-P", .reinforcement, w: innerWidth, h: t, d: 100, x: t, y: height - t, z: .zero)
        try add("TRAWERS-T", .reinforcement, w: innerWidth, h: t, d: 100, x: t, y: height - t, z: depth - 100)
        try add("PLECY", .back, w: innerWidth, h: height - t * 2, d: 3, x: t, y: t, z: depth - 13)

        for segment in segments {
            let zone = segment.zone
            guard zone.kind != .appliance else { continue }

            let cols = max(1, zone.columns)
            let columnWidth = columnInnerWidth(columns: cols)
            let zoneTag = "S\(segment.index + 1)"

            if cols > 1 {
                for j in 1..<cols {
                    let x = t + (columnWidth + t) * Double(j - 1) + columnWidth
                    try add(
                        "\(zoneTag)-PRZEGRODA-\(j)", .divider,
                        w: t, h: segment.zoneHeight, d: depth - 20,
                        x: x, y: segment.lower, z: .zero
                    )
                }
            }

            for column in 0..<cols {
                let columnX = t + (columnWidth + t) * Double(column)
                let columnTag = "\(zoneTag)K\(column + 1)"

                switch zone.kind {
                case .drawers:
                    let layout = DrawerLayoutCalculator.layout(
                        zoneHeight: segment.zoneHeight,
                        drawerCount: zone.drawerCount,
                        columnInnerWidth: columnWidth,
                        profile: zone.drawerProfile
                    )
                    let frontHeights =
                        drawerFrontHeights(
                            forZoneAt: segment.index
                        )
                    var frontY =
                        segment.lower
                        + DrawerLayoutCalculator.bottomMargin

                    for (i, frontHeight) in frontHeights.enumerated() {
                        if !useFrontLayer {
                            try add(
                                "\(columnTag)-FRONT-\(i + 1)", .front,
                                w: frontWidth(forColumns: cols), h: frontHeight, d: 18,
                                x: frontX(forColumn: column, of: cols), y: frontY, z: depth,
                                opening: .drawer
                            )
                        }
                        // Dno skrzynki, nie „element własny" — patrz
                        // `FurnitureComponentRole.drawerBox`. Ta sama pomyłka
                        // była w `KonfiguracjaFunkcjonalnaModuluV068`.
                        try add(
                            "\(columnTag)-DNOSZ-\(i + 1)", .drawerBox,
                            w: layout.boxWidth, h: 3, d: depth - 60,
                            x: columnX + zone.drawerSystem.sideThickness,
                            y: frontY + 20, z: 20
                        )
                        frontY =
                            frontY
                            + frontHeight
                            + DrawerLayoutCalculator.frontGap
                    }

                case .doors:
                    if !useFrontLayer {
                        try add(
                            "\(columnTag)-FRONT", .front,
                            w: frontWidth(forColumns: cols),
                            h: doorFrontHeight(forZoneHeight: segment.zoneHeight), d: 18,
                            x: frontX(forColumn: column, of: cols),
                            y: segment.lower + ProductionRules.frontClearancePerEdge,
                            z: depth,
                            // Bez warstwy frontów nie wiadomo, po której stronie
                            // jest zawias — i tego się nie zgaduje. `nil` znaczy
                            // „nieokreślony", a nie „lewy".
                            opening: nil
                        )
                    }

                case .shelves:
                    guard zone.shelfCount > 0 else { break }
                    for i in 0..<zone.shelfCount {
                        let fraction = Double(i + 1) / Double(zone.shelfCount + 1)
                        let shelfY = segment.lower + segment.zoneHeight * fraction
                        try add(
                            "\(columnTag)-POLKA-\(i + 1)", .shelf,
                            w: columnWidth, h: t, d: depth - 20,
                            x: columnX, y: shelfY, z: .zero
                        )
                    }

                case .hanging:
                    let railY =
                        effectiveRailHeight(
                            forZoneAt:
                                segment.index
                        )
                        ?? segment.zoneHeight / 2
                    try add(
                        "\(columnTag)-DRAZEK", .rail,
                        w: columnWidth, h: 25, d: 25,
                        x: columnX,
                        y: segment.lower + railY,
                        z: depth / 2
                    )

                case .appliance:
                    break
                }
            }
        }
        // Fronty z warstwy frontów — jeden front może przykrywać kilka stref
        // i kolumn, np. jedno lico nad zestawem szuflad wewnętrznych.
        //
        // Geometria idzie przez `frontSpanFaceV0104`, czyli tę samą regułę
        // `ProductionRules`, co fronty per strefa. Wcześniej warstwa frontów
        // miała własną arytmetykę liczoną od światła korpusu i dawała fronty
        // o 2 mm węższe.
        if useFrontLayer {
            for span in frontSpans {
                guard let lico = frontSpanFaceV0104(span) else { continue }
                try add(
                    span.displayName,
                    .front,
                    w: lico.width, h: lico.height, d: 18,
                    x: lico.x, y: lico.y, z: depth,
                    // **To jest cel całej zmiany:** kierunek otwierania jedzie
                    // razem z frontem do zespołu, więc karta techniczna i silnik
                    // szuflad wiedzą wreszcie, po której stronie jest zawias.
                    opening: span.opening
                )
            }
        }

        return try FurnitureAssembly(
            name: assemblyName ?? name,
            kind: .cabinet,
            size: Size3MM(width: width, height: height, depth: depth),
            // Jedno źródło prawdy: zespół zapisuje wartość z tej samej listy,
            // która idzie do zamówienia. Pole opisuje jednak cały mebel, więc
            // przy kilku systemach albo długościach nie wybiera pierwszej strefy,
            // tylko uczciwie pozostaje `nil`.
            drawerRunnerNominalLength: unambiguousDrawerRunnerNominalLength,
            components: components
        )
    }

    private var unambiguousDrawerRunnerNominalLength: Millimeters? {
        let runners = hardwareList().filter { $0.kind == .drawerRunner }
        guard !runners.isEmpty,
              Set(runners.map(\.system)).count == 1,
              Set(runners.map(\.dimension)).count == 1
        else {
            return nil
        }
        return runners[0].dimension
    }
}
