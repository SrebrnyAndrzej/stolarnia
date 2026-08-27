import DomainCore
import Foundation

nonisolated enum KitchenFinishingTemplateKindV015: String, CaseIterable, Hashable, Sendable {
    case baseFiller
    case wallFiller
    case tallFiller
    case topFiller
    case topCrown
    case baseClosingPanel
    case wallClosingPanel
    case tallClosingPanel

    var name: String {
        switch self {
        case .baseFiller:
            return "Blenda dolna"
        case .wallFiller:
            return "Blenda szafki wiszącej"
        case .tallFiller:
            return "Blenda wysokiej zabudowy"
        case .topFiller:
            return "Blenda górna"
        case .topCrown:
            return "Wieniec górny ciągu"
        case .baseClosingPanel:
            return "Ścianka boczna dolna"
        case .wallClosingPanel:
            return "Ścianka boczna wisząca"
        case .tallClosingPanel:
            return "Ścianka boczna wysoka"
        }
    }

    var code: String {
        switch self {
        case .baseFiller:
            return "SYS-KITCHEN-FINISH-BASE-V015"
        case .wallFiller:
            return "SYS-KITCHEN-FINISH-WALL-V015"
        case .tallFiller:
            return "SYS-KITCHEN-FINISH-TALL-V015"
        case .topFiller:
            return "SYS-KITCHEN-FINISH-TOP-V015"
        case .topCrown:
            return "SYS-KITCHEN-TOP-CROWN-V084"
        case .baseClosingPanel:
            return "SYS-KITCHEN-CLOSE-BASE-V080"
        case .wallClosingPanel:
            return "SYS-KITCHEN-CLOSE-WALL-V080"
        case .tallClosingPanel:
            return "SYS-KITCHEN-CLOSE-TALL-V080"
        }
    }

    var templateID: FurnitureTemplateID {
        let uuidString: String

        switch self {
        case .baseFiller:
            uuidString = "f1500000-0000-4000-8000-000000000001"
        case .wallFiller:
            uuidString = "f1500000-0000-4000-8000-000000000002"
        case .tallFiller:
            uuidString = "f1500000-0000-4000-8000-000000000003"
        case .topFiller:
            uuidString = "f1500000-0000-4000-8000-000000000004"
        case .topCrown:
            uuidString = "f1500000-0000-4000-8000-000000000008"
        case .baseClosingPanel:
            uuidString = "f1500000-0000-4000-8000-000000000005"
        case .wallClosingPanel:
            uuidString = "f1500000-0000-4000-8000-000000000006"
        case .tallClosingPanel:
            uuidString = "f1500000-0000-4000-8000-000000000007"
        }

        return FurnitureTemplateID(
            rawValue: UUID(uuidString: uuidString)!
        )
    }

    var anchoringMode: FurnitureAnchoringMode {
        switch self {
        case .baseFiller, .baseClosingPanel:
            return .floorStanding
        case .wallFiller,
             .topFiller,
             .topCrown,
             .wallClosingPanel:
            return .wallMounted
        case .tallFiller, .tallClosingPanel:
            return .builtIn
        }
    }

    var runKind: KitchenRunKindV015 {
        switch self {
        case .baseFiller, .baseClosingPanel:
            return .base
        case .wallFiller, .wallClosingPanel:
            return .wall
        case .topFiller, .topCrown:
            return .upper
        case .tallFiller, .tallClosingPanel:
            return .tall
        }
    }

    var defaultBottomOffset: Millimeters {
        switch self {
        case .baseFiller, .tallFiller, .baseClosingPanel, .tallClosingPanel:
            return .zero
        case .wallFiller, .wallClosingPanel:
            return 1_400
        case .topFiller, .topCrown:
            return 2_200
        }
    }

    var defaultHeight: Millimeters {
        switch self {
        case .baseFiller, .baseClosingPanel:
            return 720
        case .wallFiller, .wallClosingPanel:
            return 720
        case .tallFiller, .tallClosingPanel:
            return 2_070
        case .topFiller:
            return 100
        case .topCrown:
            return 18
        }
    }

    var defaultDepth: Millimeters {
        switch self {
        case .baseClosingPanel, .tallClosingPanel:
            return 560
        case .wallClosingPanel:
            return 350
        case .topCrown:
            return 560
        default:
            return 100
        }
    }

    var isClosingPanel: Bool {
        switch self {
        case .baseClosingPanel, .wallClosingPanel, .tallClosingPanel:
            return true
        default:
            return false
        }
    }

    var isTopCrown: Bool {
        self == .topCrown
    }

    var category: FurnitureTemplateCategory {
        switch self {
        case .baseFiller, .baseClosingPanel:
            return .kitchenBaseCabinet
        case .wallFiller, .wallClosingPanel:
            return .kitchenWallCabinet
        case .tallFiller, .tallClosingPanel:
            return .kitchenTallCabinet
        case .topFiller, .topCrown:
            return .custom
        }
    }
}

nonisolated enum StandardKitchenFinishingTemplatesV015 {
    static func make() throws -> [FurnitureTemplate] {
        try KitchenFinishingTemplateKindV015.allCases.map(
            makeTemplate
        )
    }

    static func kind(
        for template: FurnitureTemplate
    ) -> KitchenFinishingTemplateKindV015? {
        kind(for: template.id)
    }

    static func kind(
        for templateID: FurnitureTemplateID
    ) -> KitchenFinishingTemplateKindV015? {
        KitchenFinishingTemplateKindV015.allCases.first {
            $0.templateID == templateID
        }
    }

    static func isFinishingTemplate(
        _ template: FurnitureTemplate
    ) -> Bool {
        kind(for: template) != nil
    }

    static func template(
        for kind: KitchenFinishingTemplateKindV015,
        in templates: [FurnitureTemplate]
    ) -> FurnitureTemplate? {
        templates.first {
            $0.id == kind.templateID
        }
    }

    static func anchoringMode(
        for template: FurnitureTemplate
    ) -> FurnitureAnchoringMode? {
        kind(for: template)?.anchoringMode
    }

    static func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters? {
        kind(for: template)?.defaultBottomOffset
    }

    private static func makeTemplate(
        kind: KitchenFinishingTemplateKindV015
    ) throws -> FurnitureTemplate {
        let source: FurnitureTemplate

        switch kind {
        case .wallFiller,
             .topFiller,
             .topCrown,
             .wallClosingPanel:
            source = try SystemFurnitureTemplates.wallCabinet()
        case .baseFiller, .tallFiller, .baseClosingPanel, .tallClosingPanel:
            source = try SystemFurnitureTemplates.baseCabinet()
        }

        let defaultWidth: Millimeters = kind.isClosingPanel ? 18 : 50

        var defaults = source.defaultParameters
        defaults = try defaults.setting(
            .millimeters(defaultWidth),
            for: .width
        )
        defaults = try defaults.setting(
            .millimeters(kind.defaultHeight),
            for: .height
        )
        defaults = try defaults.setting(
            .millimeters(kind.defaultDepth),
            for: .depth
        )
        defaults = try defaults.setting(
            .integer(0),
            for: .shelfCount
        )
        defaults = try defaults.setting(
            .cabinetBackType(.none),
            for: .backType
        )
        defaults = try defaults.setting(
            .boolean(false),
            for: .frontEnabled
        )

        return try FurnitureTemplate(
            id: kind.templateID,
            code: kind.code,
            name: kind.name,
            category: kind.category,
            visibility: .system,
            builderType: .custom,
            supportedParameters: source.supportedParameters,
            defaultParameters: defaults
        )
    }
}

nonisolated struct KitchenFillerBuilderV015: FurnitureBuilding {
    let builderType: FurnitureBuilderType = .custom

    func build(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly: FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        guard StandardKitchenFinishingTemplatesV015
            .isFinishingTemplate(template) else {
            throw DomainError.invariantViolation(
                "KitchenFillerBuilderV015 obsługuje wyłącznie szablony wykończeniowe."
            )
        }

        let resolved = try template.resolvedParameters(
            overrides: parameters
        )
        let width = try resolved.millimeters(for: .width)
        let height = try resolved.millimeters(for: .height)
        let depth = try resolved.millimeters(for: .depth)

        guard width > .zero,
              height > .zero,
              depth > .zero else {
            throw DomainError.invariantViolation(
                "Blenda musi mieć dodatnią szerokość, wysokość i głębokość."
            )
        }

        let assemblyID =
            existingAssembly?.id
            ?? FurnitureAssemblyID()
        let finishingKind =
            StandardKitchenFinishingTemplatesV015.kind(
                for: template
            )
        let isClosingPanel =
            finishingKind?.isClosingPanel ?? false
        let isTopCrown =
            finishingKind?.isTopCrown ?? false
        let componentRole: FurnitureComponentRole =
            isTopCrown
            ? .top
            : (isClosingPanel ? .decorativeSide : .filler)
        let componentCode =
            isTopCrown
            ? "WIENIEC-GORNY-CIAG-01"
            : (isClosingPanel ? "SCIANKA-BOCZNA-01" : "BLENDA-01")
        let componentID =
            existingAssembly?.components.first(where: {
                $0.role == .filler
                    || $0.role == .maskingPanel
                    || $0.role == .decorativeSide
                    || $0.role == .top
            })?.id
            ?? ComponentID()
        let subassemblyID =
            existingAssembly?.subassemblies.first?.id
            ?? SubassemblyID()

        let component = try FurnitureComponent(
            id: componentID,
            code: componentCode,
            role: componentRole,
            size: Size3MM(
                width: width,
                height: height,
                depth: depth
            )
        )

        let subassembly = try FurnitureSubassembly(
            id: subassemblyID,
            name:
                isTopCrown
                ? "Wieniec górny ciągu"
                : "Wykończenie",
            componentIDs: [component.id]
        )

        let placement: FurniturePlacement?
        if let existingPlacement = existingAssembly?.placement {
            placement = try FurniturePlacement(
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
        } else {
            placement = nil
        }

        return try FurnitureAssembly(
            id: assemblyID,
            templateID: template.id,
            name: template.name,
            kind: .custom,
            size: Size3MM(
                width: width,
                height: height,
                depth: depth
            ),
            components: [component],
            subassemblies: [subassembly],
            placement: placement
        )
    }
}
