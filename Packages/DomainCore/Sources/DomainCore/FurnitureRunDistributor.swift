import Foundation

/// Rozkłada moduły wzdłuż ciągu meblowego (`FurnitureRun`) — parametryczny układ ściany
/// w stylu PRO100: albo dzieli dostępną długość na równe moduły, albo zachowuje szerokości
/// modułów i wchłania resztę w wypełniacz (filler) po zadanej stronie.
///
/// Uzupełnia `FurnitureRunLayoutEngine` (który liczy tylko dostępne/zajęte/pozostałe)
/// o konkretne pozycje modułów i szerokości wypełniaczy — domykając pętlę
/// więz-na-poziomie-ciągu → `FurniturePlacement.offsetAlongWall` → widoki 2D/3D.
public enum FurnitureRunDistributor {

    /// Strona, po której umieszczany jest wypełniacz absorbujący nadmiar długości.
    public enum FillerPlacement: String, Codable, Hashable, Sendable {
        case leading    // przy początku ciągu (startOffset)
        case trailing   // przy końcu ciągu (endOffset)
        case split      // po połowie na każdym końcu
        case none       // brak wypełniacza — nadmiar zostaje jako `remaining`
    }

    /// Pozycja pojedynczego modułu po rozłożeniu.
    public struct ModulePlacement: Codable, Hashable, Sendable {
        public var moduleID: FurnitureAssemblyID
        /// Lewa krawędź modułu liczona od origin ściany (spójne z `FurniturePlacement.offsetAlongWall`).
        public var offsetAlongWall: Millimeters
        public var width: Millimeters

        public init(moduleID: FurnitureAssemblyID, offsetAlongWall: Millimeters, width: Millimeters) {
            self.moduleID = moduleID
            self.offsetAlongWall = offsetAlongWall
            self.width = width
        }
    }

    /// Wynik rozłożenia ciągu.
    public struct Distribution: Codable, Hashable, Sendable {
        public var placements: [ModulePlacement]
        public var leadingFiller: Millimeters
        public var trailingFiller: Millimeters
        /// Niewchłonięty nadmiar (0 gdy wypełniacz absorbuje całość lub układ idealny).
        public var remaining: Millimeters
        /// `true`, gdy moduły są szersze niż dostępna długość ciągu.
        public var isOverfilled: Bool

        /// Sugerowana szerokość jednego modułu przy podziale równym (nil dla trybu stałego).
        public var equalModuleWidth: Millimeters?
    }

    // MARK: - Podział równy (equal split)

    /// Dzieli dostępną długość ciągu na `count` modułów o równej szerokości.
    /// Zwraca pozycje i wspólną szerokość — kaller może przeskalować zespoły do tej szerokości.
    public static func distributeEqualWidth(
        wallLength: Millimeters,
        run: FurnitureRun,
        moduleIDs: [FurnitureAssemblyID]? = nil
    ) throws -> Distribution {
        let ids = moduleIDs ?? run.moduleIDs
        guard !ids.isEmpty else {
            return Distribution(
                placements: [],
                leadingFiller: .zero,
                trailingFiller: .zero,
                remaining: try available(wallLength: wallLength, run: run),
                isOverfilled: false,
                equalModuleWidth: nil
            )
        }

        let avail = try available(wallLength: wallLength, run: run)
        guard avail > .zero else {
            throw DomainError.invalidDimension(field: "availableLength", value: avail.rawValue)
        }

        let width = avail / Double(ids.count)
        var placements: [ModulePlacement] = []
        var cursor = run.startOffset
        for id in ids {
            placements.append(ModulePlacement(moduleID: id, offsetAlongWall: cursor, width: width))
            cursor = cursor + width
        }

        return Distribution(
            placements: placements,
            leadingFiller: .zero,
            trailingFiller: .zero,
            remaining: .zero,
            isOverfilled: false,
            equalModuleWidth: width
        )
    }

    // MARK: - Podział stały + wypełniacz (fixed widths + filler)

    /// Zachowuje szerokości modułów i wchłania resztę długości w wypełniacz po zadanej stronie.
    /// Gdy `filler == nil`, strona jest wyprowadzana z `run.technology` (RunEndStrategy.filler),
    /// a przy braku takiej deklaracji domyślnie `.trailing`.
    public static func distributeFixedWidth(
        wallLength: Millimeters,
        run: FurnitureRun,
        assemblies: [FurnitureAssembly],
        filler: FillerPlacement? = nil
    ) throws -> Distribution {
        let byID = Dictionary(uniqueKeysWithValues: assemblies.map { ($0.id, $0) })
        let avail = try available(wallLength: wallLength, run: run)

        var widths: [(id: FurnitureAssemblyID, width: Millimeters)] = []
        var occupied: Millimeters = .zero
        for id in run.moduleIDs {
            guard let assembly = byID[id] else {
                throw DomainError.invariantViolation("Ciąg odwołuje się do nieistniejącego FurnitureAssemblyID.")
            }
            widths.append((id, assembly.size.width))
            occupied = occupied + assembly.size.width
        }

        let leftover = avail - occupied
        let placement = filler ?? fillerPlacement(from: run.technology)

        // Nadmiar modułów — nie mieszczą się w ciągu.
        guard leftover >= .zero else {
            let placements = sequentialPlacements(widths: widths, startingAt: run.startOffset)
            return Distribution(
                placements: placements,
                leadingFiller: .zero,
                trailingFiller: .zero,
                remaining: leftover,
                isOverfilled: true,
                equalModuleWidth: nil
            )
        }

        var leading: Millimeters = .zero
        var trailing: Millimeters = .zero
        var remaining: Millimeters = .zero

        switch placement {
        case .leading:
            leading = leftover
        case .trailing:
            trailing = leftover
        case .split:
            leading = leftover * 0.5
            trailing = leftover - leading   // reszta z podziału trafia na koniec (unika utraty 0.5 mm)
        case .none:
            remaining = leftover
        }

        let placements = sequentialPlacements(widths: widths, startingAt: run.startOffset + leading)
        return Distribution(
            placements: placements,
            leadingFiller: leading,
            trailingFiller: trailing,
            remaining: remaining,
            isOverfilled: false,
            equalModuleWidth: nil
        )
    }

    // MARK: - Pomocnicze

    /// Dostępna długość ciągu = długość ściany − odsunięcia.
    public static func available(wallLength: Millimeters, run: FurnitureRun) throws -> Millimeters {
        guard wallLength > .zero else {
            throw DomainError.invalidDimension(field: "wallLength", value: wallLength.rawValue)
        }
        guard run.startOffset + run.endOffset < wallLength else {
            throw DomainError.invariantViolation("Suma odsunięć ciągu musi być mniejsza od długości ściany.")
        }
        return wallLength - run.startOffset - run.endOffset
    }

    /// Wyprowadza stronę wypełniacza z technologii końców ciągu.
    public static func fillerPlacement(from technology: CabinetRunTechnology) -> FillerPlacement {
        switch (technology.leftEnd == .filler, technology.rightEnd == .filler) {
        case (true, true):   return .split
        case (true, false):  return .leading
        case (false, true):  return .trailing
        case (false, false): return .trailing   // domyślnie nadmiar na końcu
        }
    }

    private static func sequentialPlacements(
        widths: [(id: FurnitureAssemblyID, width: Millimeters)],
        startingAt: Millimeters
    ) -> [ModulePlacement] {
        var placements: [ModulePlacement] = []
        var cursor = startingAt
        for entry in widths {
            placements.append(ModulePlacement(moduleID: entry.id, offsetAlongWall: cursor, width: entry.width))
            cursor = cursor + entry.width
        }
        return placements
    }
}
