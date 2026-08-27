import Foundation
import SwiftUI

enum FurnitureUsageKindV018:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case kitchen
    case wardrobe
    case dressingRoom
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kitchen:
            return "Kuchnia"
        case .wardrobe:
            return "Szafa"
        case .dressingRoom:
            return "Garderoba"
        case .custom:
            return "Własny"
        }
    }
}

enum FurnitureConstructionKindV021:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case kitchenCabinet
    case spaceTower
    case hingedWardrobe
    case slidingWardrobe
    case dressingRoomOpen
    case customCarcass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kitchenCabinet:
            return "Szafka kuchenna"
        case .spaceTower:
            return "SPACE TOWER"
        case .hingedWardrobe:
            return "Szafa uchylna"
        case .slidingWardrobe:
            return "Szafa przesuwna (legacy)"
        case .dressingRoomOpen:
            return "Garderoba otwarta"
        case .customCarcass:
            return "Korpus własny"
        }
    }
}

enum FurnitureFrontOpeningKindV018:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case leftHinged
    case rightHinged
    case liftUp
    case flapDown
    case drawer
    case sliding
    case fixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHinged:
            return "Zawias lewy"
        case .rightHinged:
            return "Zawias prawy"
        case .liftUp:
            return "Podnoszony do góry"
        case .flapDown:
            return "Opuszczany w dół"
        case .drawer:
            return "Szuflada"
        case .sliding:
            return "Przesuwny"
        case .fixed:
            return "Panel stały"
        }
    }

    var technicalSymbol: String {
        switch self {
        case .leftHinged:
            return "╲"
        case .rightHinged:
            return "╱"
        case .liftUp:
            return "↑"
        case .flapDown:
            return "↓"
        case .drawer:
            return "⇢"
        case .sliding:
            return "⇆"
        case .fixed:
            return "—"
        }
    }
}

enum FurnitureFinishPresetV018:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case whiteMatt
    case whiteGloss
    case cashmere
    case anthracite
    case blackMatt
    case oakNatural
    case oakLight
    case walnut
    case gray

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whiteMatt:
            return "Biały mat"
        case .whiteGloss:
            return "Biały połysk"
        case .cashmere:
            return "Kaszmir"
        case .anthracite:
            return "Antracyt"
        case .blackMatt:
            return "Czarny mat"
        case .oakNatural:
            return "Dąb naturalny"
        case .oakLight:
            return "Dąb jasny"
        case .walnut:
            return "Orzech"
        case .gray:
            return "Szary"
        }
    }

    var color: Color {
        switch self {
        case .whiteMatt:
            return Color(white: 0.93)
        case .whiteGloss:
            return .white
        case .cashmere:
            return Color(
                red: 0.76,
                green: 0.71,
                blue: 0.63
            )
        case .anthracite:
            return Color(
                red: 0.19,
                green: 0.21,
                blue: 0.22
            )
        case .blackMatt:
            return Color(white: 0.07)
        case .oakNatural:
            return Color(
                red: 0.62,
                green: 0.43,
                blue: 0.26
            )
        case .oakLight:
            return Color(
                red: 0.76,
                green: 0.62,
                blue: 0.43
            )
        case .walnut:
            return Color(
                red: 0.36,
                green: 0.20,
                blue: 0.12
            )
        case .gray:
            return Color(
                red: 0.50,
                green: 0.52,
                blue: 0.54
            )
        }
    }
}

enum CabinetBaseSupportKindV018:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case adjustableLegs
    case plinth
    case floorStanding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adjustableLegs:
            return "Nóżki regulowane"
        case .plinth:
            return "Cokół pełny"
        case .floorStanding:
            return "Na podłodze"
        }
    }
}

struct KitchenBaseHeightSystemV018:
    Codable,
    Hashable
{
    var supportKind:
        CabinetBaseSupportKindV018 = .adjustableLegs
    var targetWorktopHeightMM = 900.0
    var legHeightMM = 100.0
    var countertopThicknessMM = 38.0
    var carcassHeightMM = 762.0

    var finishedWorktopHeightMM: Double {
        carcassHeightMM
            + effectiveLegHeightMM
            + countertopThicknessMM
    }

    var effectiveLegHeightMM: Double {
        supportKind == .floorStanding
            ? 0
            : legHeightMM
    }

    mutating func recalculate() {
        if supportKind == .floorStanding {
            legHeightMM = 0
        }

        carcassHeightMM =
            Self.carcassHeight(
                targetWorktopHeightMM:
                    targetWorktopHeightMM,
                supportKind:
                    supportKind,
                legHeightMM:
                    legHeightMM,
                countertopThicknessMM:
                    countertopThicknessMM
            )
    }

    func recalculated() -> KitchenBaseHeightSystemV018 {
        var copy = self
        copy.recalculate()
        return copy
    }

    static func carcassHeight(
        targetWorktopHeightMM: Double,
        supportKind:
            CabinetBaseSupportKindV018,
        legHeightMM: Double,
        countertopThicknessMM: Double
    ) -> Double {
        let effectiveLegHeight =
            supportKind == .floorStanding
            ? 0
            : legHeightMM

        return max(
            targetWorktopHeightMM
                - effectiveLegHeight
                - countertopThicknessMM,
            100
        )
    }
}

enum SpaceTowerUpperZoneV018:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case open
    case shelves
    case closed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            return "Otwarta"
        case .shelves:
            return "Z półkami"
        case .closed:
            return "Zamknięta frontem"
        }
    }
}

enum SpaceTowerCompartmentKindV083:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case lower
    case middle
    case upper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lower:
            return "Dolna"
        case .middle:
            return "Środkowa"
        case .upper:
            return "Górna"
        }
    }
}

enum SpaceTowerDrawerHeightKindV083:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case low
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            return "Niska"
        case .high:
            return "Wysoka"
        }
    }

    var heightMM: Double {
        switch self {
        case .low:
            return 140
        case .high:
            return 280
        }
    }

    static func nearest(
        for heightMM: Double
    ) -> Self {
        abs(heightMM - low.heightMM)
            <= abs(heightMM - high.heightMM)
        ? .low
        : .high
    }
}

struct SpaceTowerCompartmentV083:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var kind:
        SpaceTowerCompartmentKindV083
    var heightMM: Double
    var drawerHeightsMM: [Double]

    var drawerSummary: String {
        drawerHeightsMM
            .map {
                SpaceTowerDrawerHeightKindV083
                    .nearest(for: $0)
                    .title
                    .lowercased()
            }
            .joined(separator: " + ")
    }

    var zoneKindV019:
        SpaceTowerZoneV019.Kind
    {
        switch kind {
        case .lower:
            return .lowerDrawers
        case .middle:
            return .middleDrawers
        case .upper:
            return .upperDrawers
        }
    }
}

struct SpaceTowerDefinitionV018:
    Codable,
    Hashable
{
    var totalDrawerCount = 6
    var lowerZoneDrawerCount = 3
    var middleZoneDrawerCount = 3
    var upperZone:
        SpaceTowerUpperZoneV018 = .shelves
    var upperShelfCount = 2
    var frontCount = 2

    // Optional fields keep decoding of old saved drafts safe.
    var lowerZoneHeightMM: Double?
    var middleZoneHeightMM: Double?
    var upperZoneHeightMM: Double?

    // v0.83: SPACE TOWER as 2-3 independent front compartments.
    // Each compartment can have its own height and a high/low drawer scheme.
    var compartmentsV083:
        [SpaceTowerCompartmentV083]?

    mutating func normalize(
        totalHeightMM: Double = 2_070
    ) {
        totalDrawerCount = min(
            max(totalDrawerCount, 5),
            7
        )

        lowerZoneDrawerCount = min(
            max(lowerZoneDrawerCount, 2),
            totalDrawerCount - 2
        )

        middleZoneDrawerCount =
            totalDrawerCount
            - lowerZoneDrawerCount

        frontCount = min(
            max(frontCount, 2),
            3
        )

        if upperZone != .shelves {
            upperShelfCount = 0
        }

        let usable = max(
            totalHeightMM - 36,
            600
        )

        if lowerZoneHeightMM == nil
            || middleZoneHeightMM == nil
            || upperZoneHeightMM == nil {
            lowerZoneHeightMM = usable * 0.36
            middleZoneHeightMM = usable * 0.36
            upperZoneHeightMM =
                usable
                - (lowerZoneHeightMM ?? 0)
                - (middleZoneHeightMM ?? 0)
        }

        normalizeZoneHeights(
            totalHeightMM: totalHeightMM
        )

        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )
    }

    mutating func normalizeZoneHeights(
        totalHeightMM: Double
    ) {
        if compartmentsV083 != nil {
            normalizeCompartmentsV083(
                totalHeightMM: totalHeightMM
            )
            return
        }

        let usable = max(
            totalHeightMM - 36,
            600
        )

        var lower = max(
            lowerZoneHeightMM ?? usable * 0.36,
            220
        )
        var middle = max(
            middleZoneHeightMM ?? usable * 0.36,
            220
        )
        var upper = max(
            upperZoneHeightMM
                ?? (usable - lower - middle),
            180
        )

        let sum = lower + middle + upper

        if sum > usable {
            let scale = usable / sum
            lower *= scale
            middle *= scale
            upper *= scale
        } else if sum < usable {
            upper += usable - sum
        }

        lowerZoneHeightMM = lower
        middleZoneHeightMM = middle
        upperZoneHeightMM = upper
    }

    var zoneHeightSumMM: Double {
        if let compartmentsV083,
           !compartmentsV083.isEmpty {
            return compartmentsV083.reduce(0) {
                $0 + $1.heightMM
            }
        }

        return (lowerZoneHeightMM ?? 0)
        + (middleZoneHeightMM ?? 0)
        + (upperZoneHeightMM ?? 0)
    }

    var compartmentCountV083: Int {
        min(
            max(
                frontCount,
                2
            ),
            3
        )
    }

    func resolvedCompartmentsV083(
        totalHeightMM: Double = 2_070
    ) -> [SpaceTowerCompartmentV083] {
        let count =
            min(
                max(
                    frontCount,
                    2
                ),
                3
            )

        let usable = max(
            totalHeightMM - 36,
            600
        )

        var base =
            compartmentsV083
            ?? legacyCompartmentsV083(
                count: count,
                usableHeightMM: usable
            )

        if base.count < count {
            for index in base.count..<count {
                base.append(
                    Self.defaultCompartmentV083(
                        index: index,
                        count: count,
                        heightMM:
                            usable
                            / Double(count)
                    )
                )
            }
        }

        if base.count > count {
            base = Array(base.prefix(count))
        }

        return base.enumerated().map {
            index,
            compartment in
            var copy = compartment
            copy.kind =
                Self.compartmentKind(
                    index: index,
                    count: count
                )
            copy.drawerHeightsMM =
                normalizedDrawerHeightsV083(
                    copy.drawerHeightsMM
                )
            return copy
        }
    }

    mutating func setCompartmentCountV083(
        _ count: Int,
        totalHeightMM: Double
    ) {
        frontCount = min(max(count, 2), 3)
        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )
    }

    mutating func setCompartmentHeightV083(
        at index: Int,
        heightMM: Double,
        totalHeightMM: Double
    ) {
        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )

        guard compartmentsV083?.indices.contains(index)
            == true else {
            return
        }

        compartmentsV083?[index].heightMM =
            max(heightMM, 220)

        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )
    }

    mutating func setDrawerHeightKindV083(
        compartmentIndex: Int,
        drawerIndex: Int,
        kind: SpaceTowerDrawerHeightKindV083,
        totalHeightMM: Double
    ) {
        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )

        guard compartmentsV083?.indices
            .contains(compartmentIndex) == true,
              compartmentsV083?[compartmentIndex]
            .drawerHeightsMM.indices
            .contains(drawerIndex) == true else {
            return
        }

        compartmentsV083?[compartmentIndex]
            .drawerHeightsMM[drawerIndex] =
            kind.heightMM

        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )
    }

    mutating func addDrawerV083(
        compartmentIndex: Int,
        kind: SpaceTowerDrawerHeightKindV083,
        totalHeightMM: Double
    ) {
        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )

        guard compartmentsV083?.indices
            .contains(compartmentIndex) == true,
              (compartmentsV083?[compartmentIndex]
                .drawerHeightsMM.count ?? 0) < 4 else {
            return
        }

        compartmentsV083?[compartmentIndex]
            .drawerHeightsMM
            .append(kind.heightMM)

        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )
    }

    mutating func removeDrawerV083(
        compartmentIndex: Int,
        drawerIndex: Int,
        totalHeightMM: Double
    ) {
        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )

        guard compartmentsV083?.indices
            .contains(compartmentIndex) == true,
              (compartmentsV083?[compartmentIndex]
                .drawerHeightsMM.count ?? 0) > 1,
              compartmentsV083?[compartmentIndex]
            .drawerHeightsMM.indices
            .contains(drawerIndex) == true else {
            return
        }

        compartmentsV083?[compartmentIndex]
            .drawerHeightsMM
            .remove(at: drawerIndex)

        normalizeCompartmentsV083(
            totalHeightMM: totalHeightMM
        )
    }

    mutating func normalizeCompartmentsV083(
        totalHeightMM: Double
    ) {
        let count =
            min(
                max(
                    frontCount,
                    2
                ),
                3
            )
        let usable = max(
            totalHeightMM - 36,
            600
        )
        var compartments =
            resolvedCompartmentsV083(
                totalHeightMM: totalHeightMM
            )

        var sum =
            compartments
                .reduce(0) {
                    $0 + max($1.heightMM, 220)
                }

        if sum <= 0 {
            sum = usable
        }

        if abs(sum - usable) > 0.5 {
            let scale = usable / sum
            compartments =
                compartments.map {
                    compartment in
                    var copy = compartment
                    copy.heightMM =
                        max(
                            compartment.heightMM
                                * scale,
                            220
                        )
                    return copy
                }
        }

        let adjustedSum =
            compartments.reduce(0) {
                $0 + $1.heightMM
            }

        if let lastIndex = compartments.indices.last,
           abs(adjustedSum - usable) > 0.5 {
            compartments[lastIndex].heightMM =
                max(
                    compartments[lastIndex].heightMM
                    + usable
                    - adjustedSum,
                    220
                )
        }

        compartments = compartments.enumerated().map {
            index,
            compartment in
            var copy = compartment
            copy.kind =
                Self.compartmentKind(
                    index: index,
                    count: count
                )
            copy.drawerHeightsMM =
                normalizedDrawerHeightsV083(
                    copy.drawerHeightsMM
                )
            return copy
        }

        compartmentsV083 = compartments
        frontCount = count
        totalDrawerCount =
            compartments.reduce(0) {
                $0 + $1.drawerHeightsMM.count
            }
        lowerZoneDrawerCount =
            compartments.first?
                .drawerHeightsMM.count
            ?? 0
        middleZoneDrawerCount =
            compartments.dropFirst().first?
                .drawerHeightsMM.count
            ?? 0
        lowerZoneHeightMM =
            compartments.first?.heightMM
        middleZoneHeightMM =
            compartments.dropFirst().first?
                .heightMM
        upperZoneHeightMM =
            count == 3
            ? compartments.dropFirst(2).first?
                .heightMM
            : 0
    }

    private func legacyCompartmentsV083(
        count: Int,
        usableHeightMM: Double
    ) -> [SpaceTowerCompartmentV083] {
        (0..<count).map {
            index in
            let height =
                heightForLegacyCompartmentV083(
                    index: index,
                    count: count,
                    usableHeightMM:
                        usableHeightMM
                )

            return Self.defaultCompartmentV083(
                index: index,
                count: count,
                heightMM: height
            )
        }
    }

    private func heightForLegacyCompartmentV083(
        index: Int,
        count: Int,
        usableHeightMM: Double
    ) -> Double {
        switch (count, index) {
        case (3, 0):
            return lowerZoneHeightMM
                ?? usableHeightMM / 3
        case (3, 1):
            return middleZoneHeightMM
                ?? usableHeightMM / 3
        case (3, 2):
            return upperZoneHeightMM
                ?? usableHeightMM / 3
        case (2, 0):
            return lowerZoneHeightMM
                ?? usableHeightMM / 2
        case (2, 1):
            return usableHeightMM
                - (
                    lowerZoneHeightMM
                    ?? usableHeightMM / 2
                )
        default:
            return usableHeightMM
                / Double(max(count, 1))
        }
    }

    private static func defaultCompartmentV083(
        index: Int,
        count: Int,
        heightMM: Double
    ) -> SpaceTowerCompartmentV083 {
        SpaceTowerCompartmentV083(
            kind:
                compartmentKind(
                    index: index,
                    count: count
                ),
            heightMM: max(heightMM, 220),
            drawerHeightsMM:
                count == 3
                ? [280, 140]
                : [280, 140, 140]
        )
    }

    private static func compartmentKind(
        index: Int,
        count: Int
    ) -> SpaceTowerCompartmentKindV083 {
        if count == 2 {
            return index == 0 ? .lower : .upper
        }

        switch index {
        case 0:
            return .lower
        case 1:
            return .middle
        default:
            return .upper
        }
    }

    private func normalizedDrawerHeightsV083(
        _ heights: [Double]
    ) -> [Double] {
        let source =
            heights.isEmpty
            ? [280, 140]
            : heights

        return source
            .prefix(4)
            .map {
                SpaceTowerDrawerHeightKindV083
                    .nearest(for: $0)
                    .heightMM
            }
    }
}

struct WardrobeDefinitionV021:
    Codable,
    Hashable
{
    var bayCount = 2
    var slidingDoorCount = 2
    var shelfCountPerBay = 3
    var hangingRailEnabled = true
    var drawerCount = 2

    mutating func normalize(
        constructionKind:
            FurnitureConstructionKindV021
    ) {
        bayCount = min(max(bayCount, 1), 4)
        shelfCountPerBay = min(
            max(shelfCountPerBay, 0),
            8
        )
        drawerCount = min(
            max(drawerCount, 0),
            8
        )

        switch constructionKind {
        case .slidingWardrobe:
            slidingDoorCount = min(
                max(slidingDoorCount, 2),
                4
            )
        default:
            slidingDoorCount = 0
        }
    }
}

struct FurnitureFrontDefinitionV018:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var segmentIndex: Int
    var openingKind:
        FurnitureFrontOpeningKindV018
    var openingAngleDegrees = 105.0
    var material:
        FurnitureFinishPresetV018 = .cashmere
}

struct FurnitureCreatorDraftV018:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var name = "Nowy mebel"
    var usage:
        FurnitureUsageKindV018 = .kitchen
    var widthMM = 600.0
    var heightMM = 720.0
    var depthMM = 560.0
    var segmentCount = 1
    var fronts = [
        FurnitureFrontDefinitionV018(
            segmentIndex: 0,
            openingKind: .leftHinged
        )
    ]
    var carcassFinish:
        FurnitureFinishPresetV018 = .whiteMatt
    var frontFinish:
        FurnitureFinishPresetV018 = .cashmere
    var baseHeightSystem =
        KitchenBaseHeightSystemV018()
    var isSpaceTower = false
    var spaceTower =
        SpaceTowerDefinitionV018()

    // Optional additions preserve compatibility with drafts from v0.18-v0.20.
    var constructionKindV021:
        FurnitureConstructionKindV021?
    var wardrobeV021:
        WardrobeDefinitionV021?

    // v0.75: system drzwi przesuwnych (tylko dla slidingWardrobe)
    var systemPrzesuwnV075:
        SzafaPrzesuwnaDefinicjaV075?

    // v0.75: materiały z bazy zamiast FurnitureFinishPreset
    var korpusMaterialID: UUID?    // → BazaMaterialowRepository
    var frontMaterialID: UUID?     // → BazaMaterialowRepository

    // v0.80: wnęki specjalne dla customCarcass (np. miejsce na iRobota)
    // Pola opcjonalne zachowują zgodność ze starszymi zapisami JSON.
    var wnekiSpecjalneV080: [WnekaSpecjalnaV080]?

    var wneki: [WnekaSpecjalnaV080] {
        get { wnekiSpecjalneV080 ?? [] }
        set { wnekiSpecjalneV080 = newValue.isEmpty ? nil : newValue }
    }

    var effectiveConstructionKind:
        FurnitureConstructionKindV021
    {
        if isSpaceTower {
            return .spaceTower
        }

        if let constructionKindV021 {
            return constructionKindV021
        }

        switch usage {
        case .kitchen:
            return .kitchenCabinet
        case .wardrobe:
            return .hingedWardrobe
        case .dressingRoom:
            return .dressingRoomOpen
        case .custom:
            return .customCarcass
        }
    }

    mutating func setConstructionKind(
        _ kind: FurnitureConstructionKindV021
    ) {
        constructionKindV021 = kind
        isSpaceTower = kind == .spaceTower

        switch kind {
        case .kitchenCabinet,
             .spaceTower:
            usage = .kitchen

        case .hingedWardrobe,
             .slidingWardrobe:
            usage = .wardrobe

        case .dressingRoomOpen:
            usage = .dressingRoom

        case .customCarcass:
            usage = .custom
        }

        normalize()
    }

    mutating func normalize() {
        segmentCount = min(
            max(segmentCount, 1),
            4
        )

        let kind = effectiveConstructionKind

        if kind == .spaceTower {
            isSpaceTower = true
            segmentCount = 3
            spaceTower.normalize(
                totalHeightMM: heightMM
            )

            while fronts.count
                    < spaceTower.frontCount {
                fronts.append(
                    FurnitureFrontDefinitionV018(
                        segmentIndex:
                            fronts.count,
                        openingKind:
                            fronts.count == 2
                            ? .leftHinged
                            : .drawer
                    )
                )
            }

            if fronts.count
                > spaceTower.frontCount {
                fronts = Array(
                    fronts.prefix(
                        spaceTower.frontCount
                    )
                )
            }

            return
        }

        isSpaceTower = false

        if kind == .hingedWardrobe
            || kind == .slidingWardrobe
            || kind == .dressingRoomOpen {
            if wardrobeV021 == nil {
                wardrobeV021 =
                    WardrobeDefinitionV021()
            }

            wardrobeV021?.normalize(
                constructionKind: kind
            )

            segmentCount =
                wardrobeV021?.bayCount ?? 2

            let desiredFrontCount: Int

            switch kind {
            case .slidingWardrobe:
                desiredFrontCount =
                    wardrobeV021?
                        .slidingDoorCount
                    ?? 2

            case .dressingRoomOpen:
                desiredFrontCount = 0

            default:
                desiredFrontCount =
                    segmentCount
            }

            while fronts.count
                    < desiredFrontCount {
                fronts.append(
                    FurnitureFrontDefinitionV018(
                        segmentIndex:
                            fronts.count,
                        openingKind:
                            kind
                                == .slidingWardrobe
                            ? .sliding
                            : (
                                fronts.count
                                    .isMultiple(of: 2)
                                ? .leftHinged
                                : .rightHinged
                            )
                    )
                )
            }

            if fronts.count
                > desiredFrontCount {
                fronts = Array(
                    fronts.prefix(
                        desiredFrontCount
                    )
                )
            }

            // v0.75: synchronizuj wymiary do silnika szaf przesuwnych
            if kind == .slidingWardrobe {
                if systemPrzesuwnV075 == nil {
                    systemPrzesuwnV075 = SzafaPrzesuwnaDefinicjaV075()
                }
                systemPrzesuwnV075?.szerokoscCalkowitaMM = widthMM
                systemPrzesuwnV075?.wysokoscCalkowitaMM  = heightMM
                systemPrzesuwnV075?.glebokoscMM          = depthMM
                systemPrzesuwnV075?.liczbaDrzwi =
                    wardrobeV021?.slidingDoorCount ?? 2
                systemPrzesuwnV075?.normalize()
            }

            return
        }

        while fronts.count < segmentCount {
            fronts.append(
                FurnitureFrontDefinitionV018(
                    segmentIndex:
                        fronts.count,
                    openingKind:
                        .leftHinged
                )
            )
        }

        if fronts.count > segmentCount {
            fronts = Array(
                fronts.prefix(segmentCount)
            )
        }
    }

    var validationMessages: [String] {
        var result: [String] = []

        if widthMM <= 0
            || heightMM <= 0
            || depthMM <= 0 {
            result.append(
                "Wymiary muszą być dodatnie."
            )
        }

        if effectiveConstructionKind
            == .spaceTower {
            let compartments =
                spaceTower
                    .resolvedCompartmentsV083(
                        totalHeightMM:
                            heightMM
                    )

            if !(2...3).contains(compartments.count) {
                result.append(
                    "SPACE TOWER wymaga 2 lub 3 komór/frontów."
                )
            }

            if compartments.contains(where: {
                $0.drawerHeightsMM.isEmpty
            }) {
                result.append(
                    "Każda komora SPACE TOWER musi mieć co najmniej jedną szufladę."
                )
            }

            if compartments.contains(where: {
                $0.drawerHeightsMM.count > 4
            }) {
                result.append(
                    "Jedna komora SPACE TOWER może mieć maksymalnie 4 szuflady."
                )
            }

            let usable = max(
                heightMM - 36,
                600
            )

            if abs(
                spaceTower.zoneHeightSumMM
                - usable
            ) > 1 {
                result.append(
                    "Suma wysokości komór SPACE TOWER musi odpowiadać wysokości użytkowej korpusu."
                )
            }
        }

        if effectiveConstructionKind
            == .slidingWardrobe,
           (wardrobeV021?.slidingDoorCount ?? 0) < 2 {
            result.append(
                "Szafa przesuwna wymaga co najmniej 2 skrzydeł."
            )
        }

        return result
    }
}
