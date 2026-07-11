import DomainCore
import Foundation

nonisolated enum StandardFurnitureModuleKindV077 {
    case kitchenIsland
    case kitchenDrawerBase
    case sinkBase
    case cornerBase
    case cargoCabinet
    case applianceHousing
    case kitchenWallCabinet
    case hoodWallCabinet
    case glassWallCabinet
    case slidingWardrobe
    case hingedWardrobe
    case builtInWardrobe
    case dressingRoom
    case bookcase
    case desk
    case table
    case storage
    case pantryStorage
    case bathroomVanity
    case bathroomTallCabinet
    case laundryUtility
    case utilityCabinet
    case hallwayShoeCabinet
    case hallwayBench
    case coatCloset
    case tvUnit
    case wallPanel
    case underStairsBuiltIn
    case slopedBuiltIn
}

nonisolated struct StandardFurniturePresetV077: Hashable {
    let id: String
    let name: String
    let kind: StandardFurnitureModuleKindV077
    let category: FurnitureTemplateCategory
    let builderType: FurnitureBuilderType
    let anchoring: FurnitureAnchoringMode
    let widthMM: Int
    let heightMM: Int
    let depthMM: Int
    let shelfCount: Int
    let frontEnabled: Bool
    let backType: CabinetBackType
    let topConstruction: CabinetTopConstruction
    let openingTechnology: OpeningTechnology
}

nonisolated enum StandardFurnitureModuleCatalogV077 {
    private static let namespace =
        "StolarniaApp.StandardFurnitureModuleCatalog.v0.77"
    private static let codePrefix = "SYS-FURN-V077-"

    static let all: [StandardFurniturePresetV077] = [
        StandardFurniturePresetV077(
            id: "kitchen-island-1200",
            name: "Wyspa kuchenna robocza 1200",
            kind: .kitchenIsland,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1200,
            heightMM: 900,
            depthMM: 900,
            shelfCount: 1,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "kitchen-island-seating-1800",
            name: "Wyspa kuchenna z miejscem do siedzenia 1800",
            kind: .kitchenIsland,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1800,
            heightMM: 900,
            depthMM: 1000,
            shelfCount: 1,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "drawer-base-600-3",
            name: "Szafka dolna szufladowa 600 / 3 fronty",
            kind: .kitchenDrawerBase,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 600,
            heightMM: 720,
            depthMM: 560,
            shelfCount: 0,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "drawer-base-900-4",
            name: "Szafka dolna szufladowa 900 / 4 fronty",
            kind: .kitchenDrawerBase,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 900,
            heightMM: 720,
            depthMM: 560,
            shelfCount: 0,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "sink-base-800",
            name: "Szafka zlewozmywakowa 800",
            kind: .sinkBase,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 800,
            heightMM: 720,
            depthMM: 560,
            shelfCount: 0,
            frontEnabled: true,
            backType: .none,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "corner-base-l-900",
            name: "Szafka narożna L 900",
            kind: .cornerBase,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 900,
            heightMM: 720,
            depthMM: 900,
            shelfCount: 1,
            frontEnabled: true,
            backType: .none,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "cargo-base-150",
            name: "Cargo dolne 150",
            kind: .cargoCabinet,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 150,
            heightMM: 720,
            depthMM: 560,
            shelfCount: 3,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "cargo-tall-300",
            name: "Cargo wysokie 300",
            kind: .cargoCabinet,
            category: .kitchenTallCabinet,
            builderType: .wardrobe,
            anchoring: .builtIn,
            widthMM: 300,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "cargo-tall-600",
            name: "Cargo wysokie 600 tandem",
            kind: .cargoCabinet,
            category: .kitchenTallCabinet,
            builderType: .wardrobe,
            anchoring: .builtIn,
            widthMM: 600,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "oven-tower-600",
            name: "Słupek piekarnik 600",
            kind: .applianceHousing,
            category: .kitchenTallCabinet,
            builderType: .wardrobe,
            anchoring: .builtIn,
            widthMM: 600,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 3,
            frontEnabled: true,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "fridge-housing-700",
            name: "Zabudowa lodówki 700",
            kind: .applianceHousing,
            category: .kitchenTallCabinet,
            builderType: .wardrobe,
            anchoring: .builtIn,
            widthMM: 700,
            heightMM: 2200,
            depthMM: 650,
            shelfCount: 2,
            frontEnabled: true,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "dishwasher-front-600",
            name: "Front zmywarki 600 z blendą",
            kind: .applianceHousing,
            category: .kitchenBaseCabinet,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 600,
            heightMM: 720,
            depthMM: 560,
            shelfCount: 0,
            frontEnabled: true,
            backType: .none,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "wall-cabinet-600",
            name: "Szafka wisząca 600",
            kind: .kitchenWallCabinet,
            category: .kitchenWallCabinet,
            builderType: .wallCabinet,
            anchoring: .wallMounted,
            widthMM: 600,
            heightMM: 720,
            depthMM: 320,
            shelfCount: 2,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "wall-cabinet-900",
            name: "Szafka wisząca 900",
            kind: .kitchenWallCabinet,
            category: .kitchenWallCabinet,
            builderType: .wallCabinet,
            anchoring: .wallMounted,
            widthMM: 900,
            heightMM: 720,
            depthMM: 320,
            shelfCount: 2,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "hood-wall-600",
            name: "Szafka okapowa 600",
            kind: .hoodWallCabinet,
            category: .kitchenWallCabinet,
            builderType: .wallCabinet,
            anchoring: .wallMounted,
            widthMM: 600,
            heightMM: 360,
            depthMM: 320,
            shelfCount: 0,
            frontEnabled: true,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .pushToOpen
        ),
        StandardFurniturePresetV077(
            id: "glass-wall-800",
            name: "Witryna wisząca 800",
            kind: .glassWallCabinet,
            category: .kitchenWallCabinet,
            builderType: .wallCabinet,
            anchoring: .wallMounted,
            widthMM: 800,
            heightMM: 720,
            depthMM: 340,
            shelfCount: 2,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .pushToOpen
        ),
        StandardFurniturePresetV077(
            id: "wardrobe-sliding-1800",
            name: "Szafa przesuwna 2 skrzydła 1800",
            kind: .slidingWardrobe,
            category: .slidingWardrobe,
            builderType: .slidingWardrobe,
            anchoring: .builtIn,
            widthMM: 1800,
            heightMM: 2360,
            depthMM: 620,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "wardrobe-sliding-2700",
            name: "Szafa przesuwna 3 skrzydła 2700",
            kind: .slidingWardrobe,
            category: .slidingWardrobe,
            builderType: .slidingWardrobe,
            anchoring: .builtIn,
            widthMM: 2700,
            heightMM: 2360,
            depthMM: 620,
            shelfCount: 6,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "wardrobe-hinged-600",
            name: "Szafa uchylna jednodrzwiowa 600",
            kind: .hingedWardrobe,
            category: .wardrobe,
            builderType: .wardrobe,
            anchoring: .floorStanding,
            widthMM: 600,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 4,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "wardrobe-hinged-1200",
            name: "Szafa uchylna dwudrzwiowa 1200",
            kind: .hingedWardrobe,
            category: .wardrobe,
            builderType: .wardrobe,
            anchoring: .floorStanding,
            widthMM: 1200,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "built-in-wardrobe-2400",
            name: "Zabudowa wnękowa garderoby 2400",
            kind: .builtInWardrobe,
            category: .recessBuiltIn,
            builderType: .recessBuiltIn,
            anchoring: .builtIn,
            widthMM: 2400,
            heightMM: 2400,
            depthMM: 620,
            shelfCount: 6,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "dressing-open-800",
            name: "Moduł garderoby otwarty 800",
            kind: .dressingRoom,
            category: .wardrobe,
            builderType: .wardrobe,
            anchoring: .floorStanding,
            widthMM: 800,
            heightMM: 2200,
            depthMM: 500,
            shelfCount: 5,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "bookcase-800",
            name: "Regał na książki 800",
            kind: .bookcase,
            category: .shelving,
            builderType: .shelving,
            anchoring: .floorStanding,
            widthMM: 800,
            heightMM: 2200,
            depthMM: 320,
            shelfCount: 6,
            frontEnabled: false,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "bookcase-low-1200",
            name: "Regał niski 1200",
            kind: .bookcase,
            category: .shelving,
            builderType: .shelving,
            anchoring: .floorStanding,
            widthMM: 1200,
            heightMM: 1100,
            depthMM: 350,
            shelfCount: 3,
            frontEnabled: false,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "desk-1200",
            name: "Biurko 1200",
            kind: .desk,
            category: .desk,
            builderType: .desk,
            anchoring: .floorStanding,
            widthMM: 1200,
            heightMM: 740,
            depthMM: 700,
            shelfCount: 0,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "desk-1600",
            name: "Biurko 1600",
            kind: .desk,
            category: .desk,
            builderType: .desk,
            anchoring: .floorStanding,
            widthMM: 1600,
            heightMM: 740,
            depthMM: 800,
            shelfCount: 0,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "work-table-1400",
            name: "Stół roboczy 1400",
            kind: .table,
            category: .table,
            builderType: .table,
            anchoring: .floorStanding,
            widthMM: 1400,
            heightMM: 900,
            depthMM: 800,
            shelfCount: 0,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "sideboard-1600",
            name: "Komoda / kredens 1600",
            kind: .storage,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1600,
            heightMM: 820,
            depthMM: 450,
            shelfCount: 2,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "pantry-tall-600",
            name: "Słupek spiżarniany 600",
            kind: .pantryStorage,
            category: .kitchenTallCabinet,
            builderType: .wardrobe,
            anchoring: .builtIn,
            widthMM: 600,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "pantry-wide-900",
            name: "Spiżarnia z półkami 900",
            kind: .pantryStorage,
            category: .kitchenTallCabinet,
            builderType: .wardrobe,
            anchoring: .builtIn,
            widthMM: 900,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 6,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "bathroom-vanity-600",
            name: "Szafka pod umywalkę 600",
            kind: .bathroomVanity,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 600,
            heightMM: 560,
            depthMM: 480,
            shelfCount: 1,
            frontEnabled: true,
            backType: .none,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "bathroom-vanity-1200",
            name: "Szafka łazienkowa z szufladami 1200",
            kind: .bathroomVanity,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1200,
            heightMM: 560,
            depthMM: 500,
            shelfCount: 1,
            frontEnabled: true,
            backType: .none,
            topConstruction: .frontAndRearRails,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "bathroom-tall-400",
            name: "Słupek łazienkowy 400",
            kind: .bathroomTallCabinet,
            category: .wardrobe,
            builderType: .wardrobe,
            anchoring: .floorStanding,
            widthMM: 400,
            heightMM: 1800,
            depthMM: 350,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "laundry-tower-700",
            name: "Zabudowa pralka/suszarka 700",
            kind: .laundryUtility,
            category: .recessBuiltIn,
            builderType: .recessBuiltIn,
            anchoring: .builtIn,
            widthMM: 700,
            heightMM: 2200,
            depthMM: 700,
            shelfCount: 2,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "utility-tall-800",
            name: "Szafa gospodarcza 800",
            kind: .utilityCabinet,
            category: .wardrobe,
            builderType: .wardrobe,
            anchoring: .floorStanding,
            widthMM: 800,
            heightMM: 2200,
            depthMM: 600,
            shelfCount: 5,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "hallway-shoe-800",
            name: "Szafka na buty 800",
            kind: .hallwayShoeCabinet,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 800,
            heightMM: 900,
            depthMM: 350,
            shelfCount: 3,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "hallway-shoe-slim-1000",
            name: "Płytka szafka na buty 1000",
            kind: .hallwayShoeCabinet,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1000,
            heightMM: 1100,
            depthMM: 240,
            shelfCount: 4,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "hallway-bench-1200",
            name: "Siedzisko z szafką 1200",
            kind: .hallwayBench,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1200,
            heightMM: 460,
            depthMM: 420,
            shelfCount: 1,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "hallway-coat-900",
            name: "Szafa na odzież wierzchnią 900",
            kind: .coatCloset,
            category: .wardrobe,
            builderType: .wardrobe,
            anchoring: .floorStanding,
            widthMM: 900,
            heightMM: 2200,
            depthMM: 550,
            shelfCount: 2,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "tv-low-1800",
            name: "Szafka RTV niska 1800",
            kind: .tvUnit,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 1800,
            heightMM: 450,
            depthMM: 420,
            shelfCount: 1,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "tv-low-2400",
            name: "Szafka RTV długa 2400",
            kind: .tvUnit,
            category: .custom,
            builderType: .baseCabinet,
            anchoring: .floorStanding,
            widthMM: 2400,
            heightMM: 420,
            depthMM: 420,
            shelfCount: 2,
            frontEnabled: true,
            backType: .inset,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "tv-wall-panel-1800",
            name: "Panel ścienny RTV 1800",
            kind: .wallPanel,
            category: .recessBuiltIn,
            builderType: .recessBuiltIn,
            anchoring: .builtIn,
            widthMM: 1800,
            heightMM: 1400,
            depthMM: 80,
            shelfCount: 0,
            frontEnabled: false,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "under-stairs-built-in-2200",
            name: "Zabudowa pod schodami 2200",
            kind: .underStairsBuiltIn,
            category: .recessBuiltIn,
            builderType: .recessBuiltIn,
            anchoring: .builtIn,
            widthMM: 2200,
            heightMM: 1600,
            depthMM: 600,
            shelfCount: 5,
            frontEnabled: true,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        ),
        StandardFurniturePresetV077(
            id: "sloped-wardrobe-1600",
            name: "Zabudowa pod skosem 1600",
            kind: .slopedBuiltIn,
            category: .recessBuiltIn,
            builderType: .recessBuiltIn,
            anchoring: .builtIn,
            widthMM: 1600,
            heightMM: 1800,
            depthMM: 600,
            shelfCount: 4,
            frontEnabled: true,
            backType: .none,
            topConstruction: .fullPanel,
            openingTechnology: .handle
        )
    ]

    static func make() throws -> [FurnitureTemplate] {
        try all.map(makeTemplate)
    }

    static func kind(
        for template: FurnitureTemplate
    ) -> StandardFurnitureModuleKindV077? {
        preset(for: template.id)?.kind
    }

    static func anchoringMode(
        for template: FurnitureTemplate
    ) -> FurnitureAnchoringMode? {
        preset(for: template.id)?.anchoring
    }

    static func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters? {
        guard let preset = preset(for: template.id) else {
            return nil
        }

        return preset.anchoring == .wallMounted
            ? 1400
            : .zero
    }

    static func preset(
        for templateID: FurnitureTemplateID
    ) -> StandardFurniturePresetV077? {
        all.first {
            stableTemplateID(for: $0.id)
                == templateID
        }
    }

    private static func makeTemplate(
        from preset:
            StandardFurniturePresetV077
    ) throws -> FurnitureTemplate {
        var defaults =
            try baseParameters()

        defaults = try defaults.setting(
            .millimeters(
                Millimeters(
                    Double(preset.widthMM)
                )
            ),
            for: .width
        )
        defaults = try defaults.setting(
            .millimeters(
                Millimeters(
                    Double(preset.heightMM)
                )
            ),
            for: .height
        )
        defaults = try defaults.setting(
            .millimeters(
                Millimeters(
                    Double(preset.depthMM)
                )
            ),
            for: .depth
        )
        defaults = try defaults.setting(
            .integer(preset.shelfCount),
            for: .shelfCount
        )
        defaults = try defaults.setting(
            .boolean(preset.frontEnabled),
            for: .frontEnabled
        )
        defaults = try defaults.setting(
            .cabinetBackType(preset.backType),
            for: .backType
        )
        defaults = try defaults.setting(
            .cabinetTopConstruction(
                preset.topConstruction
            ),
            for: .topConstruction
        )
        defaults = try defaults.setting(
            .openingTechnology(
                preset.openingTechnology
            ),
            for: .openingTechnology
        )

        return try FurnitureTemplate(
            id: stableTemplateID(for: preset.id),
            code: stableCode(for: preset.id),
            name: preset.name,
            category: preset.category,
            visibility: .system,
            builderType: preset.builderType,
            supportedParameters:
                try parameterDefinitions(),
            defaultParameters: defaults
        )
    }

    private static func baseParameters()
        throws -> FurnitureParameterSet
    {
        try FurnitureParameterSet(entries: [
            .init(key: .width, value: .millimeters(600)),
            .init(key: .height, value: .millimeters(720)),
            .init(key: .depth, value: .millimeters(560)),
            .init(key: .carcassThickness, value: .millimeters(18)),
            .init(key: .shelfCount, value: .integer(1)),
            .init(key: .shelfFrontSetback, value: .millimeters(20)),
            .init(key: .backType, value: .cabinetBackType(.inset)),
            .init(key: .backThickness, value: .millimeters(3)),
            .init(key: .backInset, value: .millimeters(10)),
            .init(key: .topConstruction, value: .cabinetTopConstruction(.fullPanel)),
            .init(key: .topRailDepth, value: .millimeters(100)),
            .init(key: .frontEnabled, value: .boolean(true)),
            .init(key: .frontThickness, value: .millimeters(18)),
            .init(key: .frontGap, value: .millimeters(2)),
            .init(key: .frontInset, value: .millimeters(0)),
            .init(key: .openingTechnology, value: .openingTechnology(.handle)),
            .init(key: .bottomShortening, value: .millimeters(0))
        ])
    }

    private static func parameterDefinitions()
        throws -> [FurnitureParameterDefinition]
    {
        [
            try .init(key: .width, displayName: "Szerokość", valueKind: .millimeters),
            try .init(key: .height, displayName: "Wysokość", valueKind: .millimeters),
            try .init(key: .depth, displayName: "Głębokość", valueKind: .millimeters),
            try .init(key: .carcassThickness, displayName: "Grubość korpusu", valueKind: .millimeters),
            try .init(key: .shelfCount, displayName: "Liczba półek", valueKind: .integer),
            try .init(key: .shelfFrontSetback, displayName: "Cofnięcie półki", valueKind: .millimeters),
            try .init(key: .backType, displayName: "Plecy", valueKind: .cabinetBackType),
            try .init(key: .backThickness, displayName: "Grubość pleców", valueKind: .millimeters),
            try .init(key: .backInset, displayName: "Cofnięcie pleców", valueKind: .millimeters),
            try .init(key: .topConstruction, displayName: "Konstrukcja góry", valueKind: .cabinetTopConstruction),
            try .init(key: .topRailDepth, displayName: "Głębokość rygla", valueKind: .millimeters),
            try .init(key: .frontEnabled, displayName: "Front", valueKind: .boolean),
            try .init(key: .frontThickness, displayName: "Grubość frontu", valueKind: .millimeters),
            try .init(key: .frontGap, displayName: "Luz frontu", valueKind: .millimeters),
            try .init(key: .frontInset, displayName: "Cofnięcie frontu", valueKind: .millimeters),
            try .init(key: .openingTechnology, displayName: "Otwieranie", valueKind: .openingTechnology),
            try .init(key: .bottomShortening, displayName: "Podcięcie dna", valueKind: .millimeters)
        ]
    }

    private static func stableCode(
        for presetID: String
    ) -> String {
        let suffix =
            presetID
            .uppercased()
            .map {
                character -> Character in

                character.isLetter || character.isNumber
                ? character
                : "-"
            }

        return "\(codePrefix)\(String(suffix))"
    }

    private static func stableTemplateID(
        for presetID: String
    ) -> FurnitureTemplateID {
        FurnitureTemplateID(
            rawValue:
                stableUUID(
                    for:
                        "\(namespace).\(presetID)"
                )
        )
    }

    private static func stableUUID(
        for value: String
    ) -> UUID {
        let bytes = Array(value.utf8)

        var first: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            first ^= UInt64(byte)
            first &*= 1_099_511_628_211
        }

        var second: UInt64 = 1_099_511_628_211
        for byte in bytes.reversed() {
            second ^= UInt64(byte)
            second &*= 14_695_981_039_346_656_037
        }

        var uuidBytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            let shift = UInt64((7 - index) * 8)
            uuidBytes[index] =
                UInt8(truncatingIfNeeded: first >> shift)
            uuidBytes[index + 8] =
                UInt8(truncatingIfNeeded: second >> shift)
        }

        uuidBytes[6] =
            (uuidBytes[6] & 0x0f) | 0x40
        uuidBytes[8] =
            (uuidBytes[8] & 0x3f) | 0x80

        let tuple = (
            uuidBytes[0],
            uuidBytes[1],
            uuidBytes[2],
            uuidBytes[3],
            uuidBytes[4],
            uuidBytes[5],
            uuidBytes[6],
            uuidBytes[7],
            uuidBytes[8],
            uuidBytes[9],
            uuidBytes[10],
            uuidBytes[11],
            uuidBytes[12],
            uuidBytes[13],
            uuidBytes[14],
            uuidBytes[15]
        )

        return UUID(uuid: tuple)
    }
}

nonisolated struct ParametricFurnitureBuilderV077:
    FurnitureBuilding
{
    let builderType: FurnitureBuilderType
    let assemblyKind: FurnitureAssemblyKind

    func build(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly:
            FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        guard template.builderType == builderType else {
            throw DomainError.invariantViolation(
                "Builder \(builderType.rawValue) nie może zbudować szablonu typu \(template.builderType.rawValue)."
            )
        }

        if let standardKind =
            StandardFurnitureModuleCatalogV077.kind(
                for: template
            ) {
            return try buildStandardModule(
                standardKind,
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly
            )
        }

        switch builderType {
        case .desk:
            return try buildDesk(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly
            )
        case .table:
            return try buildTable(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly
            )
        default:
            break
        }

        let proxyType: FurnitureBuilderType =
            builderType == .wallCabinet
            ? .wallCabinet
            : .baseCabinet
        let proxy = try FurnitureTemplate(
            id: template.id,
            code: template.code,
            name: template.name,
            category: template.category,
            visibility: template.visibility,
            builderType: proxyType,
            supportedParameters:
                template.supportedParameters,
            defaultParameters:
                template.defaultParameters
        )

        var assembly: FurnitureAssembly
        switch proxyType {
        case .wallCabinet:
            assembly = try WallCabinetBuilder()
                .build(
                    template: proxy,
                    parameters: parameters,
                    preservingIDsFrom:
                        existingAssembly
                )
        default:
            assembly = try BaseCabinetBuilder()
                .build(
                    template: proxy,
                    parameters: parameters,
                    preservingIDsFrom:
                        existingAssembly
                )
        }

        assembly.templateID = template.id
        assembly.kind = assemblyKind
        assembly.name = template.name
        return assembly
    }

    private enum SegmentedFrontStyleV077 {
        case none
        case hinged
        case drawerStack
        case sliding
        case doubleSided
    }

    private func buildStandardModule(
        _ kind: StandardFurnitureModuleKindV077,
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly:
            FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        switch kind {
        case .kitchenIsland:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                frontStyle: .doubleSided,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: true,
                subassemblyName: "Wyspa"
            )

        case .kitchenDrawerBase:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                minimumBayWidth: 120,
                frontStyle: .drawerStack,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Szafka szufladowa"
            )

        case .sinkBase:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 800,
                minimumBayWidth: 180,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Szafka zlewozmywakowa"
            )

        case .cornerBase:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 900,
                minimumBayWidth: 180,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: true,
                addWorktopOverhang: false,
                subassemblyName: "Szafka narożna"
            )

        case .cargoCabinet:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 300,
                minimumBayWidth: 70,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Cargo"
            )

        case .applianceHousing:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                minimumBayWidth: 180,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: true,
                addWorktopOverhang: false,
                subassemblyName: "Zabudowa AGD"
            )

        case .kitchenWallCabinet,
             .glassWallCabinet:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                minimumBayWidth: 180,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Szafka wisząca"
            )

        case .hoodWallCabinet:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                minimumBayWidth: 180,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Szafka okapowa"
            )

        case .slidingWardrobe:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 900,
                frontStyle: .sliding,
                addClothesRails: true,
                addMaskingPanels: true,
                addWorktopOverhang: false,
                subassemblyName: "Szafa przesuwna"
            )

        case .hingedWardrobe,
             .pantryStorage,
             .bathroomTallCabinet,
             .utilityCabinet,
             .coatCloset:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                frontStyle: .hinged,
                addClothesRails: kind == .hingedWardrobe
                    || kind == .coatCloset
                    || kind == .utilityCabinet,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Szafa"
            )

        case .builtInWardrobe,
             .dressingRoom,
             .laundryUtility,
             .underStairsBuiltIn,
             .slopedBuiltIn:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 750,
                frontStyle: .hinged,
                addClothesRails: kind == .builtInWardrobe
                    || kind == .dressingRoom,
                addMaskingPanels: true,
                addWorktopOverhang: false,
                subassemblyName: "Zabudowa"
            )

        case .bookcase:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 800,
                frontStyle: .none,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Regał"
            )

        case .storage,
             .bathroomVanity,
             .hallwayShoeCabinet,
             .hallwayBench,
             .tvUnit:
            return try buildSegmentedCarcass(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly,
                preferredBayWidth: 600,
                frontStyle: .hinged,
                addClothesRails: false,
                addMaskingPanels: false,
                addWorktopOverhang: false,
                subassemblyName: "Korpus modułowy"
            )

        case .wallPanel:
            return try buildWallPanel(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly
            )

        case .desk:
            return try buildDesk(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly
            )

        case .table:
            return try buildTable(
                template: template,
                parameters: parameters,
                preservingIDsFrom: existingAssembly
            )
        }
    }

    private func buildSegmentedCarcass(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly:
            FurnitureAssembly?,
        preferredBayWidth: Double,
        minimumBayWidth: Millimeters = 120,
        frontStyle: SegmentedFrontStyleV077,
        addClothesRails: Bool,
        addMaskingPanels: Bool,
        addWorktopOverhang: Bool,
        subassemblyName: String
    ) throws -> FurnitureAssembly {
        let resolved =
            try CabinetBuildParameters(
                parameterSet:
                    template.resolvedParameters(
                        overrides: parameters
                    )
            )
        let ids = try preservedIDs(
            template: template,
            existingAssembly: existingAssembly
        )
        let thickness = resolved.carcassThickness
        let bayCount = suggestedBayCount(
            width: resolved.width,
            preferredBayWidth: preferredBayWidth,
            maximum: frontStyle == .sliding ? 4 : 5
        )
        let dividerCount = max(0, bayCount - 1)
        let bayWidth =
            (resolved.innerWidth
                - thickness * Double(dividerCount))
            / Double(bayCount)

        guard bayWidth > minimumBayWidth,
              resolved.innerHeight > thickness else {
            throw DomainError.invariantViolation(
                "Moduł \(template.name) ma zbyt mały gabaryt dla podziału na komory."
            )
        }

        var components: [FurnitureComponent] = []
        try appendSegmentedCarcassShell(
            to: &components,
            resolved: resolved,
            bayWidth: bayWidth,
            bayCount: bayCount,
            existingAssembly: existingAssembly
        )
        try appendDistributedShelves(
            to: &components,
            resolved: resolved,
            bayWidth: bayWidth,
            bayCount: bayCount,
            existingAssembly: existingAssembly
        )

        if addClothesRails {
            try appendClothesRails(
                to: &components,
                resolved: resolved,
                bayWidth: bayWidth,
                bayCount: bayCount,
                existingAssembly: existingAssembly
            )
        }

        try appendFronts(
            to: &components,
            resolved: resolved,
            bayCount: bayCount,
            frontStyle: frontStyle,
            existingAssembly: existingAssembly
        )

        if addMaskingPanels {
            try appendMaskingPanels(
                to: &components,
                resolved: resolved,
                existingAssembly: existingAssembly
            )
        }

        if addWorktopOverhang {
            try appendIslandWorktop(
                to: &components,
                resolved: resolved,
                existingAssembly: existingAssembly
            )
        }

        return try makeAssembly(
            template: template,
            resolved: resolved,
            components: components,
            assemblyID: ids,
            existingAssembly: existingAssembly,
            subassemblyName: subassemblyName
        )
    }

    private func buildWallPanel(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly:
            FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        let resolved =
            try CabinetBuildParameters(
                parameterSet:
                    template.resolvedParameters(
                        overrides: parameters
                    )
            )
        let ids = try preservedIDs(
            template: template,
            existingAssembly: existingAssembly
        )
        let slatCount = max(
            4,
            min(
                16,
                Int((resolved.width.rawValue / 160).rounded())
            )
        )
        let slatWidth: Millimeters = 36
        let slatGap =
            (resolved.width - slatWidth * Double(slatCount))
            / Double(max(1, slatCount - 1))

        guard slatGap >= .zero else {
            throw DomainError.invariantViolation(
                "Panel ścienny jest zbyt wąski dla zadanej liczby lamelek."
            )
        }

        var components: [FurnitureComponent] = [
            try FurnitureComponent(
                id: componentID(
                    for: "PANEL-BAZA",
                    in: existingAssembly
                ),
                code: "PANEL-BAZA",
                role: .maskingPanel,
                size: Size3MM(
                    width: resolved.width,
                    height: resolved.height,
                    depth: resolved.depth
                ),
                localPosition: .zero
            )
        ]

        for index in 0..<slatCount {
            let code = String(
                format: "LAMELA-%02d",
                index + 1
            )
            components.append(
                try FurnitureComponent(
                    id: componentID(
                        for: code,
                        in: existingAssembly
                    ),
                    code: code,
                    role: .decorativeSide,
                    size: Size3MM(
                        width: slatWidth,
                        height: resolved.height,
                        depth: minMillimeters(
                            resolved.depth,
                            26
                        )
                    ),
                    localPosition: Point3MM(
                        x: (slatWidth + slatGap)
                            * Double(index),
                        y: .zero,
                        z: -minMillimeters(
                            resolved.depth,
                            26
                        )
                    )
                )
            )
        }

        return try makeAssembly(
            template: template,
            resolved: resolved,
            components: components,
            assemblyID: ids,
            existingAssembly: existingAssembly,
            subassemblyName: "Panel ścienny"
        )
    }

    private func appendSegmentedCarcassShell(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        bayWidth: Millimeters,
        bayCount: Int,
        existingAssembly: FurnitureAssembly?
    ) throws {
        let thickness = resolved.carcassThickness
        let rightX = resolved.width - thickness

        components.append(
            try FurnitureComponent(
                id: componentID(
                    for: "BOK-L",
                    in: existingAssembly
                ),
                code: "BOK-L",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: resolved.height,
                    depth: resolved.depth
                ),
                localPosition: .zero
            )
        )
        components.append(
            try FurnitureComponent(
                id: componentID(
                    for: "BOK-P",
                    in: existingAssembly
                ),
                code: "BOK-P",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: resolved.height,
                    depth: resolved.depth
                ),
                localPosition: Point3MM(
                    x: rightX,
                    y: .zero,
                    z: .zero
                )
            )
        )
        components.append(
            try FurnitureComponent(
                id: componentID(
                    for: "WIENIEC-D",
                    in: existingAssembly
                ),
                code: "WIENIEC-D",
                role: .bottom,
                size: Size3MM(
                    width: resolved.innerWidth,
                    height: thickness,
                    depth: resolved.depth
                ),
                localPosition: Point3MM(
                    x: thickness,
                    y: .zero,
                    z: .zero
                )
            )
        )
        switch resolved.topConstruction {
        case .fullPanel:
            components.append(
                try FurnitureComponent(
                    id: componentID(
                        for: "WIENIEC-G",
                        in: existingAssembly
                    ),
                    code: "WIENIEC-G",
                    role: .top,
                    size: Size3MM(
                        width: resolved.innerWidth,
                        height: thickness,
                        depth: resolved.depth
                    ),
                    localPosition: Point3MM(
                        x: thickness,
                        y: resolved.height - thickness,
                        z: .zero
                    )
                )
            )

        case .frontAndRearRails:
            let rearReservation: Millimeters =
                resolved.backType == .inset
                ? resolved.backInset + resolved.backThickness
                : .zero
            let rearZ =
                resolved.depth
                - resolved.topRailDepth
                - rearReservation

            for (code, z) in [
                ("WZM-G-P", Millimeters.zero),
                ("WZM-G-T", rearZ)
            ] {
                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: code,
                            in: existingAssembly
                        ),
                        code: code,
                        role: .reinforcement,
                        size: Size3MM(
                            width: resolved.innerWidth,
                            height: thickness,
                            depth: resolved.topRailDepth
                        ),
                        localPosition: Point3MM(
                            x: thickness,
                            y: resolved.height - thickness,
                            z: z
                        )
                    )
                )
            }
        }

        if resolved.backType == .inset {
            components.append(
                try FurnitureComponent(
                    id: componentID(
                        for: "PLECY",
                        in: existingAssembly
                    ),
                    code: "PLECY",
                    role: .back,
                    size: Size3MM(
                        width: resolved.innerWidth,
                        height: resolved.innerHeight,
                        depth: resolved.backThickness
                    ),
                    localPosition: Point3MM(
                        x: thickness,
                        y: thickness,
                        z: resolved.depth
                            - resolved.backInset
                            - resolved.backThickness
                    )
                )
            )
        }

        guard bayCount > 1 else {
            return
        }

        for index in 1..<bayCount {
            let code = String(
                format: "PRZEGRODA-%02d",
                index
            )
            components.append(
                try FurnitureComponent(
                    id: componentID(
                        for: code,
                        in: existingAssembly
                    ),
                    code: code,
                    role: .divider,
                    size: Size3MM(
                        width: thickness,
                        height: resolved.innerHeight,
                        depth: resolved.rearUsablePlane
                    ),
                    localPosition: Point3MM(
                        x: thickness
                            + bayWidth * Double(index)
                            + thickness * Double(index - 1),
                        y: thickness,
                        z: .zero
                    )
                )
            )
        }
    }

    private func appendDistributedShelves(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        bayWidth: Millimeters,
        bayCount: Int,
        existingAssembly: FurnitureAssembly?
    ) throws {
        let distribution = shelfDistribution(
            total: resolved.shelfCount,
            bays: bayCount
        )
        let thickness = resolved.carcassThickness

        for bayIndex in 0..<bayCount {
            let shelfCount = distribution[bayIndex]
            guard shelfCount > 0 else {
                continue
            }

            let clearHeight =
                resolved.innerHeight
                - thickness * Double(shelfCount)
            let clearGap =
                clearHeight / Double(shelfCount + 1)
            let bayX =
                thickness
                + (bayWidth + thickness)
                    * Double(bayIndex)

            for shelfIndex in 1...shelfCount {
                let code = String(
                    format: "POLKA-%02d-%02d",
                    bayIndex + 1,
                    shelfIndex
                )
                let y =
                    thickness
                    + clearGap * Double(shelfIndex)
                    + thickness
                        * Double(shelfIndex - 1)

                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: code,
                            in: existingAssembly
                        ),
                        code: code,
                        role: .shelf,
                        size: Size3MM(
                            width: bayWidth,
                            height: thickness,
                            depth: resolved.shelfDepth
                        ),
                        localPosition: Point3MM(
                            x: bayX,
                            y: y,
                            z: resolved.shelfFrontSetback
                        )
                    )
                )
            }
        }
    }

    private func appendClothesRails(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        bayWidth: Millimeters,
        bayCount: Int,
        existingAssembly: FurnitureAssembly?
    ) throws {
        guard resolved.height >= 1400,
              bayWidth > 260 else {
            return
        }

        let railSize: Millimeters = 28
        let railWidth = Millimeters(
            max(
                180,
                bayWidth.rawValue - 120
            )
        )
        let railY = Millimeters(
            min(
                resolved.height.rawValue
                    - resolved.carcassThickness.rawValue
                    - 120,
                max(
                    resolved.carcassThickness.rawValue + 140,
                    resolved.height.rawValue - 1150
                )
            )
        )
        let railZ = Millimeters(
            max(
                resolved.carcassThickness.rawValue + 80,
                resolved.depth.rawValue * 0.46
            )
        )

        for bayIndex in 0..<bayCount {
            let code = String(
                format: "DRAZEK-%02d",
                bayIndex + 1
            )
            let bayX =
                resolved.carcassThickness
                + (bayWidth + resolved.carcassThickness)
                    * Double(bayIndex)

            components.append(
                try FurnitureComponent(
                    id: componentID(
                        for: code,
                        in: existingAssembly
                    ),
                    code: code,
                    role: .rail,
                    size: Size3MM(
                        width: railWidth,
                        height: railSize,
                        depth: railSize
                    ),
                    localPosition: Point3MM(
                        x: bayX
                            + (bayWidth - railWidth) / 2,
                        y: railY,
                        z: minMillimeters(
                            railZ,
                            resolved.depth
                                - resolved.carcassThickness
                                - railSize
                        )
                    )
                )
            )
        }
    }

    private func appendFronts(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        bayCount: Int,
        frontStyle: SegmentedFrontStyleV077,
        existingAssembly: FurnitureAssembly?
    ) throws {
        guard resolved.frontEnabled,
              frontStyle != .none else {
            return
        }

        switch frontStyle {
        case .none:
            return

        case .hinged,
             .doubleSided:
            let frontCount = max(1, bayCount)
            let totalGap =
                resolved.frontGap
                * Double(frontCount + 1)
            let frontWidth =
                (resolved.width - totalGap)
                / Double(frontCount)
            let frontHeight =
                resolved.height - resolved.frontGap * 2

            guard frontWidth > .zero,
                  frontHeight > .zero else {
                throw DomainError.invariantViolation(
                    "Fronty nie mieszczą się w gabarycie modułu."
                )
            }

            for index in 0..<frontCount {
                let code = String(
                    format: "FRONT-%02d",
                    index + 1
                )
                let x =
                    resolved.frontGap
                    + (frontWidth + resolved.frontGap)
                        * Double(index)
                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: code,
                            in: existingAssembly
                        ),
                        code: code,
                        role: .front,
                        size: Size3MM(
                            width: frontWidth,
                            height: frontHeight,
                            depth: resolved.frontThickness
                        ),
                        localPosition: Point3MM(
                            x: x,
                            y: resolved.frontGap,
                            z: -resolved.frontThickness
                                + resolved.frontInset
                        )
                    )
                )

                guard frontStyle == .doubleSided else {
                    continue
                }

                let rearCode = String(
                    format: "FRONT-TYL-%02d",
                    index + 1
                )
                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: rearCode,
                            in: existingAssembly
                        ),
                        code: rearCode,
                        role: .front,
                        size: Size3MM(
                            width: frontWidth,
                            height: frontHeight,
                            depth: resolved.frontThickness
                        ),
                        localPosition: Point3MM(
                            x: x,
                            y: resolved.frontGap,
                            z: resolved.depth - resolved.frontInset
                        )
                    )
                )
            }

        case .drawerStack:
            try appendDrawerStack(
                to: &components,
                resolved: resolved,
                existingAssembly: existingAssembly
            )

        case .sliding:
            let doorCount = max(
                2,
                min(
                    4,
                    suggestedBayCount(
                        width: resolved.width,
                        preferredBayWidth: 900,
                        maximum: 4
                    )
                )
            )
            let overlap: Millimeters = 40
            let usableWidth =
                resolved.width - resolved.frontGap * 2
            let frontWidth =
                (usableWidth
                    + overlap * Double(doorCount - 1))
                / Double(doorCount)
            let frontHeight =
                resolved.height - resolved.frontGap * 2

            guard frontWidth > .zero,
                  frontHeight > .zero else {
                throw DomainError.invariantViolation(
                    "Drzwi przesuwne nie mieszczą się w gabarycie modułu."
                )
            }

            for index in 0..<doorCount {
                let code = String(
                    format: "DRZWI-PRZES-%02d",
                    index + 1
                )
                let trackOffset =
                    Millimeters(Double(index % 2) * 10)
                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: code,
                            in: existingAssembly
                        ),
                        code: code,
                        role: .front,
                        size: Size3MM(
                            width: frontWidth,
                            height: frontHeight,
                            depth: resolved.frontThickness
                        ),
                        localPosition: Point3MM(
                            x: resolved.frontGap
                                + (frontWidth - overlap)
                                    * Double(index),
                            y: resolved.frontGap,
                            z: -resolved.frontThickness
                                - trackOffset
                                + resolved.frontInset
                        )
                    )
                )
            }

            let guideDepth: Millimeters = 54
            let guideHeight: Millimeters = 28
            for (code, y) in [
                ("PROW-D", resolved.frontGap),
                (
                    "PROW-G",
                    resolved.height
                        - resolved.frontGap
                        - guideHeight
                )
            ] {
                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: code,
                            in: existingAssembly
                        ),
                        code: code,
                        role: .rail,
                        size: Size3MM(
                            width: resolved.width
                                - resolved.frontGap * 2,
                            height: guideHeight,
                            depth: guideDepth
                        ),
                        localPosition: Point3MM(
                            x: resolved.frontGap,
                            y: y,
                            z: -guideDepth
                        )
                    )
                )
            }
        }
    }

    private func appendDrawerStack(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        existingAssembly: FurnitureAssembly?
    ) throws {
        let drawerCount =
            resolved.width.rawValue >= 850
            ? 4
            : 3
        let totalGap =
            resolved.frontGap
            * Double(drawerCount + 1)
        let frontWidth =
            resolved.width - resolved.frontGap * 2
        let frontHeight =
            (resolved.height - totalGap)
            / Double(drawerCount)
        let sideThickness: Millimeters = minMillimeters(
            resolved.carcassThickness,
            16
        )
        let bottomThickness: Millimeters = 8
        let drawerSetback =
            resolved.frontThickness + Millimeters(42)
        let rearReservation: Millimeters =
            resolved.backType == .inset
            ? resolved.backInset + resolved.backThickness
            : .zero
        let drawerDepth = minMillimeters(
            resolved.depth
                - drawerSetback
                - rearReservation
                - Millimeters(24),
            500
        )
        let drawerWidth =
            resolved.innerWidth - Millimeters(26)
        let drawerSideHeight = Millimeters(
            min(
                180,
                max(
                    90,
                    frontHeight.rawValue - 72
                )
            )
        )

        guard frontWidth > .zero,
              frontHeight > .zero,
              drawerWidth > sideThickness * 2,
              drawerDepth > 180,
              drawerSideHeight > bottomThickness else {
            throw DomainError.invariantViolation(
                "Szuflady nie mieszczą się w gabarycie modułu."
            )
        }

        let frontZ =
            -resolved.frontThickness
            + resolved.frontInset
        let boxX =
            resolved.carcassThickness
            + (resolved.innerWidth - drawerWidth) / 2
        let boxZ = drawerSetback
        let guideHeight: Millimeters = 35
        let guideWidth: Millimeters = 12

        for index in 0..<drawerCount {
            let number = index + 1
            let frontY =
                resolved.frontGap
                + (frontHeight + resolved.frontGap)
                    * Double(index)
            let boxY =
                frontY
                + maxMillimeters(
                    18,
                    (frontHeight - drawerSideHeight) / 2
                )
            let frontCode = String(
                format: "FRONT-SZ-%02d",
                number
            )

            components.append(
                try FurnitureComponent(
                    id: componentID(
                        for: frontCode,
                        in: existingAssembly
                    ),
                    code: frontCode,
                    role: .front,
                    size: Size3MM(
                        width: frontWidth,
                        height: frontHeight,
                        depth: resolved.frontThickness
                    ),
                    localPosition: Point3MM(
                        x: resolved.frontGap,
                        y: frontY,
                        z: frontZ
                    )
                )
            )

            let drawerParts: [
                (
                    code: String,
                    role: FurnitureComponentRole,
                    size: Size3MM,
                    position: Point3MM
                )
            ] = [
                (
                    code: String(
                        format: "SZ-%02d-BOK-L",
                        number
                    ),
                    role: .side,
                    size: Size3MM(
                        width: sideThickness,
                        height: drawerSideHeight,
                        depth: drawerDepth
                    ),
                    position: Point3MM(
                        x: boxX,
                        y: boxY,
                        z: boxZ
                    )
                ),
                (
                    code: String(
                        format: "SZ-%02d-BOK-P",
                        number
                    ),
                    role: .side,
                    size: Size3MM(
                        width: sideThickness,
                        height: drawerSideHeight,
                        depth: drawerDepth
                    ),
                    position: Point3MM(
                        x: boxX + drawerWidth - sideThickness,
                        y: boxY,
                        z: boxZ
                    )
                ),
                (
                    code: String(format: "SZ-%02d-TYL", number),
                    role: .back,
                    size: Size3MM(
                        width: drawerWidth - sideThickness * 2,
                        height: drawerSideHeight,
                        depth: sideThickness
                    ),
                    position: Point3MM(
                        x: boxX + sideThickness,
                        y: boxY,
                        z: boxZ + drawerDepth - sideThickness
                    )
                ),
                (
                    code: String(format: "SZ-%02d-DNO", number),
                    role: .bottom,
                    size: Size3MM(
                        width: drawerWidth - sideThickness * 2,
                        height: bottomThickness,
                        depth: drawerDepth - sideThickness
                    ),
                    position: Point3MM(
                        x: boxX + sideThickness,
                        y: boxY,
                        z: boxZ
                    )
                ),
                (
                    code: String(
                        format: "SZ-%02d-PROW-L",
                        number
                    ),
                    role: .rail,
                    size: Size3MM(
                        width: guideWidth,
                        height: guideHeight,
                        depth: drawerDepth
                    ),
                    position: Point3MM(
                        x: resolved.carcassThickness,
                        y: boxY,
                        z: boxZ
                    )
                ),
                (
                    code: String(
                        format: "SZ-%02d-PROW-P",
                        number
                    ),
                    role: .rail,
                    size: Size3MM(
                        width: guideWidth,
                        height: guideHeight,
                        depth: drawerDepth
                    ),
                    position: Point3MM(
                        x: resolved.width
                            - resolved.carcassThickness
                            - guideWidth,
                        y: boxY,
                        z: boxZ
                    )
                )
            ]

            for part in drawerParts {
                components.append(
                    try FurnitureComponent(
                        id: componentID(
                            for: part.code,
                            in: existingAssembly
                        ),
                        code: part.code,
                        role: part.role,
                        size: part.size,
                        localPosition: part.position
                    )
                )
            }
        }
    }

    private func appendMaskingPanels(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        existingAssembly: FurnitureAssembly?
    ) throws {
        let height: Millimeters = minMillimeters(
            70,
            maxMillimeters(
                36,
                resolved.height * 0.035
            )
        )
        components.append(
            try FurnitureComponent(
                id: componentID(
                    for: "MASK-G",
                    in: existingAssembly
                ),
                code: "MASK-G",
                role: .maskingPanel,
                size: Size3MM(
                    width: resolved.width,
                    height: height,
                    depth: resolved.frontThickness
                ),
                localPosition: Point3MM(
                    x: .zero,
                    y: resolved.height - height,
                    z: -resolved.frontThickness
                )
            )
        )
    }

    private func appendIslandWorktop(
        to components: inout [FurnitureComponent],
        resolved: CabinetBuildParameters,
        existingAssembly: FurnitureAssembly?
    ) throws {
        let sideOverhang: Millimeters = 30
        let rearOverhang: Millimeters =
            resolved.depth >= 950 ? 260 : 80

        components.append(
            try FurnitureComponent(
                id: componentID(
                    for: "BLAT-WYSPA",
                    in: existingAssembly
                ),
                code: "BLAT-WYSPA",
                role: .worktop,
                size: Size3MM(
                    width: resolved.width + sideOverhang * 2,
                    height: resolved.carcassThickness,
                    depth: resolved.depth + rearOverhang
                ),
                localPosition: Point3MM(
                    x: -sideOverhang,
                    y: resolved.height
                        - resolved.carcassThickness,
                    z: -sideOverhang
                )
            )
        )
    }

    private func suggestedBayCount(
        width: Millimeters,
        preferredBayWidth: Double,
        maximum: Int
    ) -> Int {
        let roughCount = Int(
            (width.rawValue / preferredBayWidth).rounded()
        )
        return max(
            1,
            min(maximum, max(1, roughCount))
        )
    }

    private func shelfDistribution(
        total: Int,
        bays: Int
    ) -> [Int] {
        guard total > 0, bays > 0 else {
            return Array(repeating: 0, count: max(0, bays))
        }

        let base = total / bays
        let remainder = total % bays

        return (0..<bays).map {
            base + ($0 < remainder ? 1 : 0)
        }
    }

    private func minMillimeters(
        _ lhs: Millimeters,
        _ rhs: Millimeters
    ) -> Millimeters {
        lhs < rhs ? lhs : rhs
    }

    private func maxMillimeters(
        _ lhs: Millimeters,
        _ rhs: Millimeters
    ) -> Millimeters {
        lhs > rhs ? lhs : rhs
    }

    private func buildDesk(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly:
            FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        let resolved =
            try CabinetBuildParameters(
                parameterSet:
                    template.resolvedParameters(
                        overrides: parameters
                    )
            )
        let ids = try preservedIDs(
            template: template,
            existingAssembly: existingAssembly
        )
        let thickness = resolved.carcassThickness
        let sideHeight = resolved.height - thickness
        let innerWidth = resolved.width - thickness * 2

        guard sideHeight > .zero,
              innerWidth > .zero,
              resolved.depth > thickness else {
            throw DomainError.invariantViolation(
                "Biurko ma zbyt mały gabaryt dla blatu i boków."
            )
        }

        let rearPanelHeight = Millimeters(
            min(
                360,
                max(
                    90,
                    sideHeight.rawValue * 0.38
                )
            )
        )
        let rearPanelY = Millimeters(
            min(
                160,
                max(
                    0,
                    sideHeight.rawValue
                        - rearPanelHeight.rawValue
                )
            )
        )

        let components: [FurnitureComponent] = [
            try FurnitureComponent(
                id: componentID(
                    for: "BLAT",
                    in: existingAssembly
                ),
                code: "BLAT",
                role: .worktop,
                size: Size3MM(
                    width: resolved.width,
                    height: thickness,
                    depth: resolved.depth
                ),
                localPosition: Point3MM(
                    x: .zero,
                    y: resolved.height - thickness,
                    z: .zero
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "BOK-L",
                    in: existingAssembly
                ),
                code: "BOK-L",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: sideHeight,
                    depth: resolved.depth
                ),
                localPosition: .zero
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "BOK-P",
                    in: existingAssembly
                ),
                code: "BOK-P",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: sideHeight,
                    depth: resolved.depth
                ),
                localPosition: Point3MM(
                    x: resolved.width - thickness,
                    y: .zero,
                    z: .zero
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "BLENDA-TYL",
                    in: existingAssembly
                ),
                code: "BLENDA-TYL",
                role: .back,
                size: Size3MM(
                    width: innerWidth,
                    height: rearPanelHeight,
                    depth: thickness
                ),
                localPosition: Point3MM(
                    x: thickness,
                    y: rearPanelY,
                    z: resolved.depth - thickness
                )
            )
        ]

        return try makeAssembly(
            template: template,
            resolved: resolved,
            components: components,
            assemblyID: ids,
            existingAssembly: existingAssembly,
            subassemblyName: "Biurko"
        )
    }

    private func buildTable(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly:
            FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        let resolved =
            try CabinetBuildParameters(
                parameterSet:
                    template.resolvedParameters(
                        overrides: parameters
                    )
            )
        let ids = try preservedIDs(
            template: template,
            existingAssembly: existingAssembly
        )
        let thickness = resolved.carcassThickness
        let legSize = Millimeters(
            min(
                80,
                max(
                    45,
                    min(
                        resolved.width.rawValue,
                        resolved.depth.rawValue
                    ) * 0.08
                )
            )
        )
        let inset = Millimeters(
            min(
                120,
                max(
                    60,
                    min(
                        resolved.width.rawValue,
                        resolved.depth.rawValue
                    ) * 0.12
                )
            )
        )
        let legHeight = resolved.height - thickness

        guard legHeight > .zero,
              resolved.width > inset * 2 + legSize,
              resolved.depth > inset * 2 + legSize else {
            throw DomainError.invariantViolation(
                "Stół ma zbyt mały gabaryt dla nóg i blatu."
            )
        }

        let rearZ = resolved.depth - inset - legSize
        let rightX = resolved.width - inset - legSize
        let railWidth = resolved.width - inset * 2

        let components: [FurnitureComponent] = [
            try FurnitureComponent(
                id: componentID(
                    for: "BLAT",
                    in: existingAssembly
                ),
                code: "BLAT",
                role: .worktop,
                size: Size3MM(
                    width: resolved.width,
                    height: thickness,
                    depth: resolved.depth
                ),
                localPosition: Point3MM(
                    x: .zero,
                    y: resolved.height - thickness,
                    z: .zero
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "NOGA-LP",
                    in: existingAssembly
                ),
                code: "NOGA-LP",
                role: .leg,
                size: Size3MM(
                    width: legSize,
                    height: legHeight,
                    depth: legSize
                ),
                localPosition: Point3MM(
                    x: inset,
                    y: .zero,
                    z: inset
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "NOGA-PP",
                    in: existingAssembly
                ),
                code: "NOGA-PP",
                role: .leg,
                size: Size3MM(
                    width: legSize,
                    height: legHeight,
                    depth: legSize
                ),
                localPosition: Point3MM(
                    x: rightX,
                    y: .zero,
                    z: inset
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "NOGA-LT",
                    in: existingAssembly
                ),
                code: "NOGA-LT",
                role: .leg,
                size: Size3MM(
                    width: legSize,
                    height: legHeight,
                    depth: legSize
                ),
                localPosition: Point3MM(
                    x: inset,
                    y: .zero,
                    z: rearZ
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "NOGA-PT",
                    in: existingAssembly
                ),
                code: "NOGA-PT",
                role: .leg,
                size: Size3MM(
                    width: legSize,
                    height: legHeight,
                    depth: legSize
                ),
                localPosition: Point3MM(
                    x: rightX,
                    y: .zero,
                    z: rearZ
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "WZM-P",
                    in: existingAssembly
                ),
                code: "WZM-P",
                role: .reinforcement,
                size: Size3MM(
                    width: railWidth,
                    height: thickness,
                    depth: legSize
                ),
                localPosition: Point3MM(
                    x: inset,
                    y: resolved.height - thickness * 2,
                    z: inset
                )
            ),
            try FurnitureComponent(
                id: componentID(
                    for: "WZM-T",
                    in: existingAssembly
                ),
                code: "WZM-T",
                role: .reinforcement,
                size: Size3MM(
                    width: railWidth,
                    height: thickness,
                    depth: legSize
                ),
                localPosition: Point3MM(
                    x: inset,
                    y: resolved.height - thickness * 2,
                    z: rearZ
                )
            )
        ]

        return try makeAssembly(
            template: template,
            resolved: resolved,
            components: components,
            assemblyID: ids,
            existingAssembly: existingAssembly,
            subassemblyName: "Stół"
        )
    }

    private func preservedIDs(
        template: FurnitureTemplate,
        existingAssembly: FurnitureAssembly?
    ) throws -> FurnitureAssemblyID {
        if let existingAssembly,
           let existingTemplateID = existingAssembly.templateID,
           existingTemplateID != template.id {
            throw DomainError.invariantViolation(
                "Nie można przebudować zespołu przy użyciu innego FurnitureTemplateID."
            )
        }

        return existingAssembly?.id ?? FurnitureAssemblyID()
    }

    private func componentID(
        for code: String,
        in existingAssembly: FurnitureAssembly?
    ) -> ComponentID {
        existingAssembly?
            .components
            .first { $0.code == code }?
            .id
        ?? ComponentID()
    }

    private func subassemblyID(
        for name: String,
        in existingAssembly: FurnitureAssembly?
    ) -> SubassemblyID {
        existingAssembly?
            .subassemblies
            .first { $0.name == name }?
            .id
        ?? SubassemblyID()
    }

    private func preservedPlacement(
        from existingAssembly: FurnitureAssembly?,
        assemblyID: FurnitureAssemblyID
    ) throws -> FurniturePlacement? {
        guard let existingPlacement = existingAssembly?.placement else {
            return nil
        }

        return try FurniturePlacement(
            id: existingPlacement.id,
            roomID: existingPlacement.roomID,
            wallID: existingPlacement.wallID,
            assemblyID: assemblyID,
            offsetAlongWall: existingPlacement.offsetAlongWall,
            offsetFromWall: existingPlacement.offsetFromWall,
            bottomOffset: existingPlacement.bottomOffset,
            rotationDegrees: existingPlacement.rotationDegrees,
            anchoringMode: existingPlacement.anchoringMode
        )
    }

    private func makeAssembly(
        template: FurnitureTemplate,
        resolved: CabinetBuildParameters,
        components: [FurnitureComponent],
        assemblyID: FurnitureAssemblyID,
        existingAssembly: FurnitureAssembly?,
        subassemblyName: String
    ) throws -> FurnitureAssembly {
        try FurnitureAssembly(
            id: assemblyID,
            templateID: template.id,
            name: template.name,
            kind: assemblyKind,
            size: Size3MM(
                width: resolved.width,
                height: resolved.height,
                depth: resolved.depth
            ),
            components: components,
            subassemblies: [
                try FurnitureSubassembly(
                    id: subassemblyID(
                        for: subassemblyName,
                        in: existingAssembly
                    ),
                    name: subassemblyName,
                    componentIDs: components.map(\.id)
                )
            ],
            constraints: [],
            placement: try preservedPlacement(
                from: existingAssembly,
                assemblyID: assemblyID
            )
        )
    }
}
