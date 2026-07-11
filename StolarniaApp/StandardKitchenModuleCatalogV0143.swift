import Foundation

enum KitchenModuleCategoryV0143: String, Codable, CaseIterable, Hashable {
    case base
    case wall
    case tall
    case corner
    case appliance
    case open
}

enum KitchenModuleConstructionV0143: String, Codable, CaseIterable, Hashable {
    case shelves
    case drawers
    case cargo
    case sink
    case oven
    case dishwasherFront
    case hood
    case refrigerator
    case ovenTower
    case ovenMicrowaveTower
    case utility
    case blindCorner
    case lCorner
    case wallCorner
    case liftUp
    case openShelf
    case topBox
}

enum KitchenModuleAnchoringV0143: String, Codable, CaseIterable, Hashable {
    case floorStanding
    case wallMounted
    case builtIn
}

/// Neutralny model presetu. Nie zależy od inicjalizatora `FurnitureTemplate`,
/// dzięki czemu katalog można stabilnie utrzymywać niezależnie od zmian
/// w DomainCore. Adapter w aplikacji mapuje preset na `FurnitureTemplate`.
struct KitchenModulePresetV0143: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: KitchenModuleCategoryV0143
    let construction: KitchenModuleConstructionV0143
    let anchoring: KitchenModuleAnchoringV0143

    let widthMM: Int
    let heightMM: Int
    let depthMM: Int
    let bottomOffsetMM: Int

    /// Rozmiary alternatywne spotykane w popularnych systemach modułowych.
    /// Wartość domyślna pozostaje zgodna z dotychczasowym profilem aplikacji.
    let availableHeightsMM: [Int]
    let availableDepthsMM: [Int]

    let tags: [String]
}

enum StandardKitchenModuleCatalogV0143 {
    /// Profil zachowujący dotychczasowe wymiary projektu:
    /// korpus dolny 720 × 560 mm, wiszący 720 × 320 mm,
    /// dolna krawędź wiszącego 1400 mm.
    static let all: [KitchenModulePresetV0143] = {
        var result: [KitchenModulePresetV0143] = []

        func add(
            id: String,
            name: String,
            category: KitchenModuleCategoryV0143,
            construction: KitchenModuleConstructionV0143,
            anchoring: KitchenModuleAnchoringV0143,
            width: Int,
            height: Int,
            depth: Int,
            bottom: Int,
            heights: [Int],
            depths: [Int],
            tags: [String] = []
        ) {
            result.append(
                KitchenModulePresetV0143(
                    id: id,
                    name: name,
                    category: category,
                    construction: construction,
                    anchoring: anchoring,
                    widthMM: width,
                    heightMM: height,
                    depthMM: depth,
                    bottomOffsetMM: bottom,
                    availableHeightsMM: heights,
                    availableDepthsMM: depths,
                    tags: tags
                )
            )
        }

        // MARK: - Dolne: drzwi i półki

        for width in [300, 400, 450, 500, 600, 800, 900] {
            add(
                id: "base-shelves-\(width)",
                name: "Szafka dolna z półkami \(width)",
                category: .base,
                construction: .shelves,
                anchoring: .floorStanding,
                width: width,
                height: 720,
                depth: 560,
                bottom: 0,
                heights: [720, 800],
                depths: [560, 600],
                tags: ["dolna", "drzwi", "półki"]
            )
        }

        // MARK: - Dolne: szuflady

        for width in [300, 400, 450, 500, 600, 800, 900] {
            add(
                id: "base-drawers-\(width)",
                name: "Szafka dolna z szufladami \(width)",
                category: .base,
                construction: .drawers,
                anchoring: .floorStanding,
                width: width,
                height: 720,
                depth: 560,
                bottom: 0,
                heights: [720, 800],
                depths: [560, 600],
                tags: ["dolna", "szuflady"]
            )
        }

        // MARK: - Cargo

        for width in [150, 200, 300] {
            add(
                id: "base-cargo-\(width)",
                name: "Cargo dolne \(width)",
                category: .base,
                construction: .cargo,
                anchoring: .floorStanding,
                width: width,
                height: 720,
                depth: 560,
                bottom: 0,
                heights: [720, 800],
                depths: [560, 600],
                tags: ["dolna", "cargo", "wysuw"]
            )
        }

        // MARK: - Zlew

        for width in [450, 500, 600, 800, 900] {
            add(
                id: "base-sink-\(width)",
                name: "Szafka pod zlew \(width)",
                category: .appliance,
                construction: .sink,
                anchoring: .floorStanding,
                width: width,
                height: 720,
                depth: 560,
                bottom: 0,
                heights: [720, 800],
                depths: [560, 600],
                tags: ["dolna", "zlew", "sortowanie"]
            )
        }

        add(
            id: "base-oven-600",
            name: "Szafka pod piekarnik 600",
            category: .appliance,
            construction: .oven,
            anchoring: .floorStanding,
            width: 600,
            height: 720,
            depth: 560,
            bottom: 0,
            heights: [720, 800],
            depths: [560, 600],
            tags: ["dolna", "AGD", "piekarnik"]
        )

        for width in [450, 600] {
            add(
                id: "dishwasher-front-\(width)",
                name: "Zabudowa zmywarki \(width)",
                category: .appliance,
                construction: .dishwasherFront,
                anchoring: .builtIn,
                width: width,
                height: 720,
                depth: 560,
                bottom: 0,
                heights: [720, 800],
                depths: [550, 560, 600],
                tags: ["AGD", "zmywarka", "front"]
            )
        }

        // MARK: - Dolne narożne

        for width in [900, 1000, 1100] {
            add(
                id: "base-blind-corner-\(width)",
                name: "Szafka narożna ślepa \(width)",
                category: .corner,
                construction: .blindCorner,
                anchoring: .floorStanding,
                width: width,
                height: 720,
                depth: 560,
                bottom: 0,
                heights: [720, 800],
                depths: [560, 600],
                tags: ["dolna", "narożna", "ślepa"]
            )
        }

        add(
            id: "base-l-corner-900",
            name: "Szafka narożna L 900 × 900",
            category: .corner,
            construction: .lCorner,
            anchoring: .floorStanding,
            width: 900,
            height: 720,
            depth: 900,
            bottom: 0,
            heights: [720, 800],
            depths: [900],
            tags: ["dolna", "narożna", "L"]
        )

        // MARK: - Wiszące: drzwi i półki

        for width in [300, 400, 450, 500, 600, 800, 900] {
            add(
                id: "wall-shelves-\(width)",
                name: "Szafka wisząca z półkami \(width)",
                category: .wall,
                construction: .shelves,
                anchoring: .wallMounted,
                width: width,
                height: 720,
                depth: 320,
                bottom: 1400,
                heights: [400, 600, 720, 800, 900, 1000],
                depths: [320, 350, 370],
                tags: ["wisząca", "drzwi", "półki"]
            )
        }

        // MARK: - Wiszące uchylne

        for width in [600, 800, 900] {
            add(
                id: "wall-lift-up-\(width)",
                name: "Szafka wisząca uchylna \(width)",
                category: .wall,
                construction: .liftUp,
                anchoring: .wallMounted,
                width: width,
                height: 400,
                depth: 320,
                bottom: 1600,
                heights: [360, 400, 500, 600],
                depths: [320, 350, 370],
                tags: ["wisząca", "uchylna"]
            )
        }

        // MARK: - Okap

        for width in [600, 800, 900] {
            add(
                id: "wall-hood-\(width)",
                name: "Szafka wisząca pod okap \(width)",
                category: .appliance,
                construction: .hood,
                anchoring: .wallMounted,
                width: width,
                height: 720,
                depth: 320,
                bottom: 1400,
                heights: [600, 720, 800],
                depths: [320, 350, 370],
                tags: ["wisząca", "AGD", "okap"]
            )
        }

        add(
            id: "wall-corner-600",
            name: "Szafka wisząca narożna 600 × 600",
            category: .corner,
            construction: .wallCorner,
            anchoring: .wallMounted,
            width: 600,
            height: 720,
            depth: 600,
            bottom: 1400,
            heights: [600, 720, 800, 900],
            depths: [600],
            tags: ["wisząca", "narożna"]
        )

        // MARK: - Wysokie

        for width in [400, 500, 600] {
            add(
                id: "tall-pantry-\(width)",
                name: "Słupek spiżarniany \(width)",
                category: .tall,
                construction: .shelves,
                anchoring: .builtIn,
                width: width,
                height: 2070,
                depth: 560,
                bottom: 0,
                heights: [2000, 2070, 2200],
                depths: [560, 600],
                tags: ["wysoka", "spiżarnia", "półki"]
            )
        }

        add(
            id: "tall-refrigerator-600",
            name: "Słupek pod lodówkę 600",
            category: .appliance,
            construction: .refrigerator,
            anchoring: .builtIn,
            width: 600,
            height: 2070,
            depth: 600,
            bottom: 0,
            heights: [2000, 2070, 2200],
            depths: [560, 600, 650],
            tags: ["wysoka", "AGD", "lodówka"]
        )

        add(
            id: "tall-oven-600",
            name: "Słupek z piekarnikiem 600",
            category: .appliance,
            construction: .ovenTower,
            anchoring: .builtIn,
            width: 600,
            height: 2070,
            depth: 560,
            bottom: 0,
            heights: [2000, 2070, 2200],
            depths: [560, 600],
            tags: ["wysoka", "AGD", "piekarnik"]
        )

        add(
            id: "tall-oven-microwave-600",
            name: "Słupek piekarnik + mikrofalówka 600",
            category: .appliance,
            construction: .ovenMicrowaveTower,
            anchoring: .builtIn,
            width: 600,
            height: 2070,
            depth: 560,
            bottom: 0,
            heights: [2000, 2070, 2200],
            depths: [560, 600],
            tags: ["wysoka", "AGD", "piekarnik", "mikrofalówka"]
        )

        add(
            id: "tall-utility-600",
            name: "Słupek gospodarczy 600",
            category: .tall,
            construction: .utility,
            anchoring: .builtIn,
            width: 600,
            height: 2070,
            depth: 560,
            bottom: 0,
            heights: [2000, 2070, 2200],
            depths: [560, 600],
            tags: ["wysoka", "gospodarcza"]
        )

        // MARK: - Nadstawki i otwarte

        for width in [600, 800, 900] {
            add(
                id: "top-box-\(width)",
                name: "Nadstawka górna \(width)",
                category: .wall,
                construction: .topBox,
                anchoring: .wallMounted,
                width: width,
                height: 400,
                depth: 320,
                bottom: 2200,
                heights: [360, 400, 500],
                depths: [320, 350, 370],
                tags: ["wisząca", "nadstawka"]
            )
        }

        for width in [300, 600, 900] {
            add(
                id: "open-shelf-\(width)",
                name: "Regał otwarty \(width)",
                category: .open,
                construction: .openShelf,
                anchoring: .wallMounted,
                width: width,
                height: 720,
                depth: 300,
                bottom: 1400,
                heights: [400, 600, 720, 800],
                depths: [250, 300, 320],
                tags: ["wisząca", "otwarta", "półki"]
            )
        }

        return result
    }()

    static func modules(
        in category: KitchenModuleCategoryV0143
    ) -> [KitchenModulePresetV0143] {
        all.filter { $0.category == category }
    }

    static func search(
        _ query: String
    ) -> [KitchenModulePresetV0143] {
        let normalized = query
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pl_PL")
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return all
        }

        return all.filter { preset in
            let haystack = ([preset.name] + preset.tags)
                .joined(separator: " ")
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: Locale(identifier: "pl_PL")
                )

            return haystack.contains(normalized)
        }
    }
}
