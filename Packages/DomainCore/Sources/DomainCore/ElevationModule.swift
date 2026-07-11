import Foundation

/// Typ zawartości strefy w kreatorze rysunkowym (elewacja modułu).
public enum ElevationZoneKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case drawers
    case doors
    case shelves
    case appliance

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .drawers: return "Szuflady"
        case .doors: return "Drzwi"
        case .shelves: return "Półki otwarte"
        case .appliance: return "AGD"
        }
    }
}

/// Pozioma strefa modułu. Strefa może być dzielona pionowymi przegrodami
/// na kolumny — każda kolumna powiela tę samą zawartość.
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

    public init(
        id: UUID = UUID(),
        kind: ElevationZoneKind = .doors,
        columns: Int = 1,
        shelfCount: Int = 2,
        drawerCount: Int = 3,
        drawerSystem: DrawerSystem = .amixSlimbox,
        drawerProfileName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.columns = min(max(columns, 1), 4)
        self.shelfCount = min(max(shelfCount, 0), 8)
        self.drawerCount = min(max(drawerCount, 1), 6)
        self.drawerSystem = drawerSystem
        self.drawerProfileName = drawerProfileName ?? drawerSystem.defaultProfileName
    }

    /// Wybrany profil szuflady z bezpiecznym domyślnym.
    public var drawerProfile: DrawerProfile {
        DrawerProfile.profile(system: drawerSystem, name: drawerProfileName)
            ?? DrawerProfile.defaultProfile(for: drawerSystem)
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

    public static let minimumZoneHeight: Millimeters = 100

    public init(
        name: String = "Nowy moduł",
        width: Millimeters = 600,
        height: Millimeters = 720,
        depth: Millimeters = 560,
        carcassThickness: Millimeters = 18,
        splits: [Millimeters] = [],
        zones: [ElevationZone] = []
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

    public var segments: [ZoneSegment] {
        let bounds = boundaries
        return zones.enumerated().map { index, zone in
            ZoneSegment(index: index, zone: zone, lower: bounds[index], upper: bounds[index + 1])
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
        return insertIndex
    }

    /// Usuwa podział pod strefą `zoneIndex` — strefa znika, strefa poniżej
    /// przejmuje jej wysokość.
    @discardableResult
    public mutating func removeSplitBelow(zoneIndex: Int) -> Bool {
        guard zoneIndex >= 1, zoneIndex < zones.count else { return false }
        splits.remove(at: zoneIndex - 1)
        zones.remove(at: zoneIndex)
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

    /// Modyfikuje strefę i normalizuje zakresy liczników.
    public mutating func updateZone(at index: Int, _ mutate: (inout ElevationZone) -> Void) {
        guard zones.indices.contains(index) else { return }
        mutate(&zones[index])
        zones[index].columns = min(max(zones[index].columns, 1), 4)
        zones[index].shelfCount = min(max(zones[index].shelfCount, 0), 8)
        zones[index].drawerCount = min(max(zones[index].drawerCount, 1), 6)
        if DrawerProfile.profile(
            system: zones[index].drawerSystem,
            name: zones[index].drawerProfileName
        ) == nil {
            zones[index].drawerProfileName = zones[index].drawerSystem.defaultProfileName
        }
    }

    // MARK: Walidacja szuflad

    public func drawerLayout(forZoneAt index: Int) -> DrawerLayout? {
        guard zones.indices.contains(index), zones[index].kind == .drawers else { return nil }
        let segment = segments[index]
        let zone = zones[index]
        return DrawerLayoutCalculator.layout(
            zoneHeight: segment.zoneHeight,
            drawerCount: zone.drawerCount,
            columnInnerWidth: columnInnerWidth(columns: zone.columns),
            profile: zone.drawerProfile
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
                add(
                    "Front szuflady (\(zone.drawerProfile.name))",
                    layout.frontHeight,
                    columnWidth - 3,
                    zone.drawerCount * cols,
                    .front18
                )
                add("Dno szuflady", depth - 60, layout.boxWidth, zone.drawerCount * cols, .hdf3)

            case .doors:
                add("Front drzwi", segment.zoneHeight - 3, columnWidth - 3, cols, .front18)

            case .shelves:
                add("Półka", columnWidth, depth - 20, zone.shelfCount * cols, .board18)

            case .appliance:
                break
            }
        }
        return items
    }

    var totalCutPieces: Int {
        cutList().reduce(0) { $0 + $1.count }
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
                shelfTotal: 0
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
                shelfTotal: group.count
            ))
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
            x: Millimeters, y: Millimeters, z: Millimeters
        ) throws {
            guard w > .zero, h > .zero, d > .zero else { return }
            components.append(try FurnitureComponent(
                code: code,
                role: role,
                size: Size3MM(width: w, height: h, depth: d),
                localPosition: Point3MM(x: x, y: y, z: z)
            ))
        }

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
                    for i in 0..<zone.drawerCount {
                        let frontY = segment.lower
                            + DrawerLayoutCalculator.bottomMargin
                            + (layout.frontHeight + DrawerLayoutCalculator.frontGap) * Double(i)
                        try add(
                            "\(columnTag)-FRONT-\(i + 1)", .front,
                            w: columnWidth - 3, h: layout.frontHeight, d: 18,
                            x: columnX + Millimeters(1.5), y: frontY, z: depth
                        )
                        try add(
                            "\(columnTag)-DNOSZ-\(i + 1)", .custom,
                            w: layout.boxWidth, h: 3, d: depth - 60,
                            x: columnX + zone.drawerSystem.sideThickness,
                            y: frontY + 20, z: 20
                        )
                    }

                case .doors:
                    try add(
                        "\(columnTag)-FRONT", .front,
                        w: columnWidth - 3, h: segment.zoneHeight - 3, d: 18,
                        x: columnX + Millimeters(1.5),
                        y: segment.lower + Millimeters(1.5), z: depth
                    )

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

                case .appliance:
                    break
                }
            }
        }

        return try FurnitureAssembly(
            name: assemblyName ?? name,
            kind: .cabinet,
            size: Size3MM(width: width, height: height, depth: depth),
            components: components
        )
    }
}
