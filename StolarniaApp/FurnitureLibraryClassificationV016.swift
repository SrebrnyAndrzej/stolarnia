import DomainCore

nonisolated enum FurnitureLibraryGroupV016: String, CaseIterable, Identifiable, Sendable {
    case kitchen
    case wardrobes
    case dressingRoom
    case bathroomUtility
    case hallway
    case livingAndWork
    case livingRoom
    case specialBuiltIns
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kitchen: return "Kuchnia"
        case .wardrobes: return "Szafy"
        case .dressingRoom: return "Garderoba"
        case .bathroomUtility: return "Łazienka i gospodarcze"
        case .hallway: return "Przedpokój"
        case .livingAndWork: return "Biuro i regały"
        case .livingRoom: return "Salon / RTV"
        case .specialBuiltIns: return "Zabudowy specjalne"
        case .custom: return "Własne"
        }
    }

    var systemImage: String {
        switch self {
        case .kitchen: return "cabinet"
        case .wardrobes: return "door.sliding.left.hand.closed"
        case .dressingRoom: return "hanger"
        case .bathroomUtility: return "drop"
        case .hallway: return "figure.walk"
        case .livingAndWork: return "books.vertical"
        case .livingRoom: return "tv"
        case .specialBuiltIns: return "wrench.and.screwdriver"
        case .custom: return "slider.horizontal.3"
        }
    }
}

nonisolated enum FurnitureLibraryCategoryV016: String, CaseIterable, Identifiable, Sendable {
    case kitchenBase
    case kitchenWall
    case kitchenTall
    case kitchenIsland
    case kitchenDrawers
    case sinkCabinet
    case kitchenCorner
    case cargo
    case applianceHousing
    case pantryStorage
    case kitchenFinishing
    case slidingWardrobe
    case hingedWardrobe
    case builtInWardrobe
    case dressingCarcass
    case dressingShelf
    case dressingAccessory
    case bathroomVanity
    case bathroomTall
    case laundry
    case utilityStorage
    case shoeCabinet
    case coatCloset
    case hallwayBench
    case desk
    case bookcase
    case table
    case storage
    case tvUnit
    case wallPanel
    case underStairs
    case slopedBuiltIn
    case savedCustom

    var id: String { rawValue }

    var group: FurnitureLibraryGroupV016 {
        switch self {
        case .kitchenBase, .kitchenWall, .kitchenTall,
             .kitchenIsland, .kitchenDrawers,
             .sinkCabinet, .kitchenCorner,
             .cargo, .applianceHousing,
             .pantryStorage,
             .kitchenFinishing:
            return .kitchen
        case .slidingWardrobe, .hingedWardrobe, .builtInWardrobe:
            return .wardrobes
        case .dressingCarcass, .dressingShelf, .dressingAccessory:
            return .dressingRoom
        case .bathroomVanity, .bathroomTall,
             .laundry, .utilityStorage:
            return .bathroomUtility
        case .shoeCabinet, .coatCloset, .hallwayBench:
            return .hallway
        case .desk, .bookcase, .table, .storage:
            return .livingAndWork
        case .tvUnit, .wallPanel:
            return .livingRoom
        case .underStairs, .slopedBuiltIn:
            return .specialBuiltIns
        case .savedCustom:
            return .custom
        }
    }

    var title: String {
        switch self {
        case .kitchenBase: return "Dolne"
        case .kitchenWall: return "Wiszące"
        case .kitchenTall: return "Wysokie"
        case .kitchenIsland: return "Wyspy"
        case .kitchenDrawers: return "Szuflady"
        case .sinkCabinet: return "Zlewy"
        case .kitchenCorner: return "Narożniki"
        case .cargo: return "Cargo"
        case .applianceHousing: return "AGD"
        case .pantryStorage: return "Spiżarnia"
        case .kitchenFinishing: return "Blendy"
        case .slidingWardrobe: return "Przesuwne"
        case .hingedWardrobe: return "Uchylne"
        case .builtInWardrobe: return "Wnękowe"
        case .dressingCarcass: return "Korpusy"
        case .dressingShelf: return "Półki"
        case .dressingAccessory: return "Akcesoria"
        case .bathroomVanity: return "Pod umywalkę"
        case .bathroomTall: return "Słupki"
        case .laundry: return "Pralnia"
        case .utilityStorage: return "Gospodarcze"
        case .shoeCabinet: return "Buty"
        case .coatCloset: return "Odzież"
        case .hallwayBench: return "Siedziska"
        case .desk: return "Biurka"
        case .bookcase: return "Regały"
        case .table: return "Stoły"
        case .storage: return "Komody"
        case .tvUnit: return "RTV"
        case .wallPanel: return "Panele"
        case .underStairs: return "Pod schodami"
        case .slopedBuiltIn: return "Pod skosem"
        case .savedCustom: return "Zapisane"
        }
    }

    var systemImage: String {
        switch self {
        case .kitchenBase: return "cabinet"
        case .kitchenWall: return "square.topthird.inset.filled"
        case .kitchenTall: return "rectangle.portrait"
        case .kitchenIsland: return "rectangle.center.inset.filled"
        case .kitchenDrawers: return "rectangle.split.3x1"
        case .sinkCabinet: return "drop"
        case .kitchenCorner: return "square.split.bottomrightquarter"
        case .cargo: return "rectangle.stack"
        case .applianceHousing: return "oven"
        case .pantryStorage: return "cabinet"
        case .kitchenFinishing: return "rectangle.split.3x1"
        case .slidingWardrobe: return "door.sliding.left.hand.closed"
        case .hingedWardrobe: return "door.left.hand.closed"
        case .builtInWardrobe: return "rectangle.inset.filled"
        case .dressingCarcass: return "square.grid.2x2"
        case .dressingShelf: return "books.vertical"
        case .dressingAccessory: return "hanger"
        case .bathroomVanity: return "drop"
        case .bathroomTall: return "rectangle.portrait"
        case .laundry: return "washer"
        case .utilityStorage: return "archivebox"
        case .shoeCabinet: return "shoeprints.fill"
        case .coatCloset: return "hanger"
        case .hallwayBench: return "chair"
        case .desk: return "desktopcomputer"
        case .bookcase: return "books.vertical"
        case .table: return "table.furniture"
        case .storage: return "archivebox"
        case .tvUnit: return "tv"
        case .wallPanel: return "rectangle.inset.filled"
        case .underStairs: return "stairs"
        case .slopedBuiltIn: return "angle"
        case .savedCustom: return "square.and.pencil"
        }
    }
}

nonisolated enum FurnitureLibraryClassificationV016 {
    static func category(
        for template: FurnitureTemplate
    ) -> FurnitureLibraryCategoryV016 {
        if StandardKitchenFinishingTemplatesV015
            .isFinishingTemplate(template) {
            return .kitchenFinishing
        }

        if let kind =
            StandardFurnitureModuleCatalogV077
            .kind(for: template) {
            switch kind {
            case .kitchenIsland:
                return .kitchenIsland
            case .kitchenDrawerBase:
                return .kitchenDrawers
            case .sinkBase:
                return .sinkCabinet
            case .cornerBase:
                return .kitchenCorner
            case .cargoCabinet:
                return .cargo
            case .applianceHousing:
                return .applianceHousing
            case .kitchenWallCabinet,
                 .hoodWallCabinet,
                 .glassWallCabinet:
                return .kitchenWall
            case .slidingWardrobe:
                return .slidingWardrobe
            case .hingedWardrobe:
                return .hingedWardrobe
            case .builtInWardrobe:
                return .builtInWardrobe
            case .dressingRoom:
                return .dressingCarcass
            case .bookcase:
                return .bookcase
            case .desk:
                return .desk
            case .table:
                return .table
            case .storage:
                return .storage
            case .pantryStorage:
                return .pantryStorage
            case .bathroomVanity:
                return .bathroomVanity
            case .bathroomTallCabinet:
                return .bathroomTall
            case .laundryUtility:
                return .laundry
            case .utilityCabinet:
                return .utilityStorage
            case .hallwayShoeCabinet:
                return .shoeCabinet
            case .hallwayBench:
                return .hallwayBench
            case .coatCloset:
                return .coatCloset
            case .tvUnit:
                return .tvUnit
            case .wallPanel:
                return .wallPanel
            case .underStairsBuiltIn:
                return .underStairs
            case .slopedBuiltIn:
                return .slopedBuiltIn
            }
        }

        switch template.category {
        case .kitchenBaseCabinet:
            return .kitchenBase
        case .kitchenWallCabinet:
            return .kitchenWall
        case .kitchenTallCabinet:
            return .kitchenTall
        case .slidingWardrobe:
            return .slidingWardrobe
        case .wardrobe:
            return .hingedWardrobe
        case .recessBuiltIn:
            return .builtInWardrobe
        case .shelving:
            return .bookcase
        case .desk:
            return .desk
        case .table:
            return .table
        case .custom:
            return .savedCustom
        }
    }

    static func categories(
        in group: FurnitureLibraryGroupV016
    ) -> [FurnitureLibraryCategoryV016] {
        FurnitureLibraryCategoryV016.allCases.filter {
            $0.group == group
        }
    }

    static func supportedByCurrentBuilder(
        _ template: FurnitureTemplate
    ) -> Bool {
        switch template.builderType {
        case .baseCabinet, .wallCabinet, .wardrobe,
             .slidingWardrobe, .desk, .shelving,
             .table, .recessBuiltIn:
            return true
        case .custom:
            return StandardKitchenFinishingTemplatesV015
                .isFinishingTemplate(template)
        default:
            return false
        }
    }
}
