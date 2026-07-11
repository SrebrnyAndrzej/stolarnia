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
            return "Szafa przesuwna"
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

    mutating func recalculate() {
        if supportKind == .floorStanding {
            legHeightMM = 0
        }

        carcassHeightMM = max(
            targetWorktopHeightMM
                - legHeightMM
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
    }

    mutating func normalizeZoneHeights(
        totalHeightMM: Double
    ) {
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
        (lowerZoneHeightMM ?? 0)
        + (middleZoneHeightMM ?? 0)
        + (upperZoneHeightMM ?? 0)
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
            if !(5...7).contains(
                spaceTower.totalDrawerCount
            ) {
                result.append(
                    "SPACE TOWER musi mieć 5–7 szuflad."
                )
            }

            if !(2...3).contains(
                spaceTower.frontCount
            ) {
                result.append(
                    "SPACE TOWER wymaga 2 lub 3 frontów."
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
                    "Suma wysokości trzech stref SPACE TOWER musi odpowiadać wysokości użytkowej korpusu."
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
