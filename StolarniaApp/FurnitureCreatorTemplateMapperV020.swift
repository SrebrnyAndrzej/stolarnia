import DomainCore
import Foundation

enum FurnitureCreatorTemplateMapperV020 {
    struct Result {
        let template: FurnitureTemplate
        let specification:
            FurnitureTechnicalSpecificationV020
    }

    static func make(
        from draft: FurnitureCreatorDraftV018
    ) throws -> Result {
        let templateID = FurnitureTemplateID()
        let code =
            "USR-\(draft.id.uuidString.prefix(8).uppercased())"

        let category: FurnitureTemplateCategory
        switch draft.usage {
        case .kitchen:
            category = draft.heightMM >= 1_400
                ? .kitchenTallCabinet
                : .kitchenBaseCabinet
        case .wardrobe:
            category = .wardrobe
        case .dressingRoom:
            category = .wardrobe
        case .custom:
            category = .custom
        }

        // Existing application builders safely understand
        // base-cabinet parameters. Technical details are preserved
        // in the sidecar specification.
        let builderType: FurnitureBuilderType =
            draft.isSpaceTower
            ? .spaceTower
            : .baseCabinet

        let supported = try parameterDefinitions()

        let parameters = try FurnitureParameterSet(
            entries: [
                .init(
                    key: .width,
                    value: .millimeters(
                        Millimeters(draft.widthMM)
                    )
                ),
                .init(
                    key: .height,
                    value: .millimeters(
                        Millimeters(draft.heightMM)
                    )
                ),
                .init(
                    key: .depth,
                    value: .millimeters(
                        Millimeters(draft.depthMM)
                    )
                ),
                .init(
                    key: .carcassThickness,
                    value: .millimeters(18)
                ),
                .init(
                    key: .shelfCount,
                    value: .integer(
                        draft.isSpaceTower
                        ? draft.spaceTower.upperShelfCount
                        : 1
                    )
                ),
                .init(
                    key: .shelfFrontSetback,
                    value: .millimeters(20)
                ),
                .init(
                    key: .backType,
                    value: .cabinetBackType(.inset)
                ),
                .init(
                    key: .backThickness,
                    value: .millimeters(3)
                ),
                .init(
                    key: .backInset,
                    value: .millimeters(10)
                ),
                .init(
                    key: .topConstruction,
                    value: .cabinetTopConstruction(
                        .fullPanel
                    )
                ),
                .init(
                    key: .topRailDepth,
                    value: .millimeters(100)
                ),
                .init(
                    key: .frontEnabled,
                    value: .boolean(true)
                ),
                .init(
                    key: .frontThickness,
                    value: .millimeters(18)
                ),
                .init(
                    key: .frontGap,
                    value: .millimeters(2)
                ),
                .init(
                    key: .frontInset,
                    value: .millimeters(0)
                ),
                .init(
                    key: .openingTechnology,
                    value: .openingTechnology(.handle)
                ),
                .init(
                    key: .bottomShortening,
                    value: .millimeters(0)
                )
            ]
        )

        let template = try FurnitureTemplate(
            id: templateID,
            code: code,
            name: draft.name,
            category: category,
            visibility: .privateTemplate,
            builderType: builderType,
            supportedParameters: supported,
            defaultParameters: parameters
        )

        let specification =
            FurnitureTechnicalSpecificationV020(
                templateID: templateID,
                sourceDraftID: draft.id,
                segmentCount: draft.segmentCount,
                fronts: draft.fronts.map {
                    FurnitureFrontSpecificationV020(
                        id: $0.id,
                        segmentIndex: $0.segmentIndex,
                        opening: opening($0.openingKind),
                        openingAngleDegrees:
                            $0.openingAngleDegrees,
                        finish: finish($0.material)
                    )
                },
                carcassFinish:
                    finish(draft.carcassFinish),
                frontFinish:
                    finish(draft.frontFinish),
                targetWorktopHeightMM:
                    draft.baseHeightSystem
                        .targetWorktopHeightMM,
                legHeightMM:
                    draft.baseHeightSystem.legHeightMM,
                countertopThicknessMM:
                    draft.baseHeightSystem
                        .countertopThicknessMM,
                spaceTowerZones:
                    draft.spaceTowerZonesV019.map {
                        SpaceTowerZoneSpecificationV020(
                            id: $0.id,
                            kind: zoneKind($0.kind),
                            heightMM: $0.heightMM,
                            drawerCount: $0.drawerCount,
                            shelfCount: $0.shelfCount
                        )
                    }
            )

        return Result(
            template: template,
            specification: specification
        )
    }

    private static func parameterDefinitions()
        throws -> [FurnitureParameterDefinition]
    {
        [
            try .init(
                key: .width,
                displayName: "Szerokość",
                valueKind: .millimeters
            ),
            try .init(
                key: .height,
                displayName: "Wysokość",
                valueKind: .millimeters
            ),
            try .init(
                key: .depth,
                displayName: "Głębokość",
                valueKind: .millimeters
            ),
            try .init(
                key: .carcassThickness,
                displayName: "Grubość korpusu",
                valueKind: .millimeters
            ),
            try .init(
                key: .shelfCount,
                displayName: "Liczba półek",
                valueKind: .integer
            ),
            try .init(
                key: .shelfFrontSetback,
                displayName: "Cofnięcie półki",
                valueKind: .millimeters
            ),
            try .init(
                key: .backType,
                displayName: "Plecy",
                valueKind: .cabinetBackType
            ),
            try .init(
                key: .backThickness,
                displayName: "Grubość pleców",
                valueKind: .millimeters
            ),
            try .init(
                key: .backInset,
                displayName: "Cofnięcie pleców",
                valueKind: .millimeters
            ),
            try .init(
                key: .topConstruction,
                displayName: "Wieniec górny",
                valueKind: .cabinetTopConstruction
            ),
            try .init(
                key: .topRailDepth,
                displayName: "Głębokość rygla",
                valueKind: .millimeters
            ),
            try .init(
                key: .frontEnabled,
                displayName: "Front",
                valueKind: .boolean
            ),
            try .init(
                key: .frontThickness,
                displayName: "Grubość frontu",
                valueKind: .millimeters
            ),
            try .init(
                key: .frontGap,
                displayName: "Szczelina frontu",
                valueKind: .millimeters
            ),
            try .init(
                key: .frontInset,
                displayName: "Cofnięcie frontu",
                valueKind: .millimeters
            ),
            try .init(
                key: .openingTechnology,
                displayName: "Otwieranie",
                valueKind: .openingTechnology
            ),
            try .init(
                key: .bottomShortening,
                displayName: "Skrócenie dna",
                valueKind: .millimeters
            )
        ]
    }

    private static func opening(
        _ value: FurnitureFrontOpeningKindV018
    ) -> FurnitureFrontOpeningV020 {
        switch value {
        case .leftHinged: return .leftHinged
        case .rightHinged: return .rightHinged
        case .liftUp: return .liftUp
        case .flapDown: return .flapDown
        case .drawer: return .drawer
        case .sliding: return .sliding
        case .fixed: return .fixed
        }
    }

    private static func finish(
        _ value: FurnitureFinishPresetV018
    ) -> FurnitureFinishV020 {
        switch value {
        case .whiteMatt: return .whiteMatt
        case .whiteGloss: return .whiteGloss
        case .cashmere: return .cashmere
        case .anthracite: return .anthracite
        case .blackMatt: return .blackMatt
        case .oakNatural: return .oakNatural
        case .oakLight: return .oakLight
        case .walnut: return .walnut
        case .gray: return .gray
        }
    }

    private static func zoneKind(
        _ value: SpaceTowerZoneV019.Kind
    ) -> SpaceTowerZoneSpecificationV020.Kind {
        switch value {
        case .lowerDrawers:
            return .lowerDrawers
        case .middleDrawers:
            return .middleDrawers
        case .upperOpen:
            return .upperOpen
        case .upperShelves:
            return .upperShelves
        case .upperClosed:
            return .upperClosed
        }
    }
}
