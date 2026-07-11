import DomainCore
import Foundation

/// Adapter katalogu v0.14.3 do stabilnych szablonów `FurnitureTemplate`.
///
/// Presety korzystają z istniejących builderów korpusów:
/// - moduły wiszące: `WallCabinetBuilder`,
/// - pozostałe moduły: `BaseCabinetBuilder`.
///
/// Dzięki temu wszystkie pozycje są od razu dostępne w aktualnym interfejsie.
/// Specjalistyczne wnętrza cargo, szuflad i AGD pozostają nazwanymi presetami
/// gabarytowymi do czasu dodania dedykowanych builderów technologicznych.
enum StandardKitchenTemplatesV0143 {
    private static let namespace = "StolarniaApp.StandardKitchenModuleCatalog.v0.14.3"

    static func make() throws -> [FurnitureTemplate] {
        try StandardKitchenModuleCatalogV0143.all.map(makeTemplate)
    }

    static func preset(
        for templateID: FurnitureTemplateID
    ) -> KitchenModulePresetV0143? {
        StandardKitchenModuleCatalogV0143.all.first {
            stableTemplateID(for: $0.id) == templateID
        }
    }

    static func anchoringMode(
        for template: FurnitureTemplate
    ) -> FurnitureAnchoringMode? {
        guard let preset = preset(for: template.id) else {
            return nil
        }

        switch preset.anchoring {
        case .floorStanding:
            return .floorStanding
        case .wallMounted:
            return .wallMounted
        case .builtIn:
            return .builtIn
        }
    }

    static func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters? {
        preset(for: template.id).map {
            Millimeters(Double($0.bottomOffsetMM))
        }
    }

    private static func makeTemplate(
        from preset: KitchenModulePresetV0143
    ) throws -> FurnitureTemplate {
        let baseTemplate: FurnitureTemplate
        let builderType: FurnitureBuilderType

        switch preset.anchoring {
        case .wallMounted:
            baseTemplate = try SystemFurnitureTemplates.wallCabinet()
            builderType = .wallCabinet
        case .floorStanding, .builtIn:
            baseTemplate = try SystemFurnitureTemplates.baseCabinet()
            builderType = .baseCabinet
        }

        var defaults = baseTemplate.defaultParameters
        defaults = try defaults.setting(
            .millimeters(Millimeters(Double(preset.widthMM))),
            for: .width
        )
        defaults = try defaults.setting(
            .millimeters(Millimeters(Double(preset.heightMM))),
            for: .height
        )
        defaults = try defaults.setting(
            .millimeters(Millimeters(Double(preset.depthMM))),
            for: .depth
        )
        defaults = try defaults.setting(
            .integer(defaultShelfCount(for: preset.construction)),
            for: .shelfCount
        )

        return try FurnitureTemplate(
            id: stableTemplateID(for: preset.id),
            code: stableCode(for: preset.id),
            name: preset.name,
            category: domainCategory(for: preset),
            visibility: .system,
            builderType: builderType,
            supportedParameters: baseTemplate.supportedParameters,
            defaultParameters: defaults
        )
    }

    private static func domainCategory(
        for preset: KitchenModulePresetV0143
    ) -> FurnitureTemplateCategory {
        switch preset.anchoring {
        case .wallMounted:
            return .kitchenWallCabinet
        case .builtIn:
            return preset.heightMM >= 1600
                ? .kitchenTallCabinet
                : .kitchenBaseCabinet
        case .floorStanding:
            return preset.heightMM >= 1600
                ? .kitchenTallCabinet
                : .kitchenBaseCabinet
        }
    }

    private static func defaultShelfCount(
        for construction: KitchenModuleConstructionV0143
    ) -> Int {
        switch construction {
        case .shelves:
            return 2
        case .utility:
            return 4
        case .openShelf:
            return 3
        case .blindCorner, .lCorner, .wallCorner, .topBox:
            return 1
        case .drawers, .cargo, .sink, .oven, .dishwasherFront,
             .hood, .refrigerator, .ovenTower, .ovenMicrowaveTower,
             .liftUp:
            return 0
        }
    }

    private static func stableCode(
        for presetID: String
    ) -> String {
        let suffix = presetID
            .uppercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "-"
            }

        return "SYS-KITCHEN-V0143-\(String(suffix))"
    }

    private static func stableTemplateID(
        for presetID: String
    ) -> FurnitureTemplateID {
        FurnitureTemplateID(
            rawValue: stableUUID(
                for: "\(namespace).\(presetID)"
            )
        )
    }

    /// Deterministyczny identyfikator UUID oparty na zamrożonej nazwie presetu.
    /// Nie korzysta z `Hasher`, którego wynik nie jest stabilny między procesami.
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
            uuidBytes[index] = UInt8(truncatingIfNeeded: first >> shift)
            uuidBytes[index + 8] = UInt8(truncatingIfNeeded: second >> shift)
        }

        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x80
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
}
