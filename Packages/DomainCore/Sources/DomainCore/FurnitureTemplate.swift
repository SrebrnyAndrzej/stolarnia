import Foundation

public enum FurnitureTemplateCategory: String, Codable, CaseIterable, Sendable {
    case kitchenBaseCabinet
    case kitchenWallCabinet
    case kitchenTallCabinet
    case wardrobe
    case desk
    case shelving
    case table
    case recessBuiltIn
    case slidingWardrobe
    case custom
}

public enum TemplateVisibility: String, Codable, CaseIterable, Sendable {
    case system
    case company
    case privateTemplate
}

public enum FurnitureBuilderType: String, Codable, CaseIterable, Sendable {
    case baseCabinet
    case wallCabinet
    case tallCabinet
    case spaceTower
    case wardrobe
    case slidingWardrobe
    case desk
    case shelving
    case table
    case recessBuiltIn
    case custom
}

public enum CabinetBackType: String, Codable, CaseIterable, Sendable {
    case none
    case inset
}

public enum CabinetTopConstruction: String, Codable, CaseIterable, Sendable {
    case fullPanel
    case frontAndRearRails
}

public enum FurnitureParameterKey: String, Codable, CaseIterable, Sendable {
    case width
    case height
    case depth
    case carcassThickness
    case shelfCount
    case shelfFrontSetback
    case backType
    case backThickness
    case backInset
    case topConstruction
    case topRailDepth
    case frontEnabled
    case frontThickness
    case frontGap
    case frontInset
    case openingTechnology
    case bottomShortening
}

public enum FurnitureParameterValueKind: String, Codable, CaseIterable, Sendable {
    case millimeters
    case integer
    case boolean
    case cabinetBackType
    case cabinetTopConstruction
    case openingTechnology
}

public enum FurnitureParameterValue: Codable, Hashable, Sendable {
    case millimeters(Millimeters)
    case integer(Int)
    case boolean(Bool)
    case cabinetBackType(CabinetBackType)
    case cabinetTopConstruction(CabinetTopConstruction)
    case openingTechnology(OpeningTechnology)

    public var kind: FurnitureParameterValueKind {
        switch self {
        case .millimeters:
            return .millimeters
        case .integer:
            return .integer
        case .boolean:
            return .boolean
        case .cabinetBackType:
            return .cabinetBackType
        case .cabinetTopConstruction:
            return .cabinetTopConstruction
        case .openingTechnology:
            return .openingTechnology
        }
    }
}

public struct FurnitureParameterEntry: Codable, Hashable, Sendable {
    public var key: FurnitureParameterKey
    public var value: FurnitureParameterValue

    public init(
        key: FurnitureParameterKey,
        value: FurnitureParameterValue
    ) {
        self.key = key
        self.value = value
    }
}

public struct FurnitureParameterDefinition: Codable, Hashable, Sendable {
    public var key: FurnitureParameterKey
    public var displayName: String
    public var valueKind: FurnitureParameterValueKind
    public var isRequired: Bool

    public init(
        key: FurnitureParameterKey,
        displayName: String,
        valueKind: FurnitureParameterValueKind,
        isRequired: Bool = true
    ) throws {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Nazwa parametru mebla nie może być pusta.")
        }

        self.key = key
        self.displayName = displayName
        self.valueKind = valueKind
        self.isRequired = isRequired
    }
}

public struct FurnitureParameterSet: Codable, Hashable, Sendable {
    public private(set) var entries: [FurnitureParameterEntry]

    public init() {
        self.entries = []
    }

    public init(entries: [FurnitureParameterEntry]) throws {
        guard Set(entries.map(\.key)).count == entries.count else {
            throw DomainError.invariantViolation(
                "Zestaw parametrów mebla nie może zawierać powtórzonych kluczy."
            )
        }
        self.entries = entries
    }

    public func value(
        for key: FurnitureParameterKey
    ) -> FurnitureParameterValue? {
        entries.first { $0.key == key }?.value
    }

    public func merged(
        with overrides: FurnitureParameterSet
    ) throws -> FurnitureParameterSet {
        var mergedEntries = entries

        for override in overrides.entries {
            if let index = mergedEntries.firstIndex(where: { $0.key == override.key }) {
                mergedEntries[index] = override
            } else {
                mergedEntries.append(override)
            }
        }

        return try FurnitureParameterSet(entries: mergedEntries)
    }

    public func setting(
        _ value: FurnitureParameterValue,
        for key: FurnitureParameterKey
    ) throws -> FurnitureParameterSet {
        try merged(
            with: FurnitureParameterSet(
                entries: [FurnitureParameterEntry(key: key, value: value)]
            )
        )
    }

    public func millimeters(
        for key: FurnitureParameterKey
    ) throws -> Millimeters {
        guard case .millimeters(let value) = value(for: key) else {
            throw parameterTypeError(key: key, expected: .millimeters)
        }
        return value
    }

    public func integer(
        for key: FurnitureParameterKey
    ) throws -> Int {
        guard case .integer(let value) = value(for: key) else {
            throw parameterTypeError(key: key, expected: .integer)
        }
        return value
    }

    public func boolean(
        for key: FurnitureParameterKey
    ) throws -> Bool {
        guard case .boolean(let value) = value(for: key) else {
            throw parameterTypeError(key: key, expected: .boolean)
        }
        return value
    }

    public func cabinetBackType(
        for key: FurnitureParameterKey
    ) throws -> CabinetBackType {
        guard case .cabinetBackType(let value) = value(for: key) else {
            throw parameterTypeError(key: key, expected: .cabinetBackType)
        }
        return value
    }

    public func cabinetTopConstruction(
        for key: FurnitureParameterKey
    ) throws -> CabinetTopConstruction {
        guard case .cabinetTopConstruction(let value) = value(for: key) else {
            throw parameterTypeError(key: key, expected: .cabinetTopConstruction)
        }
        return value
    }

    public func openingTechnology(
        for key: FurnitureParameterKey
    ) throws -> OpeningTechnology {
        guard case .openingTechnology(let value) = value(for: key) else {
            throw parameterTypeError(key: key, expected: .openingTechnology)
        }
        return value
    }

    private func parameterTypeError(
        key: FurnitureParameterKey,
        expected: FurnitureParameterValueKind
    ) -> DomainError {
        DomainError.invariantViolation(
            "Parametr \(key.rawValue) nie istnieje albo ma inny typ niż \(expected.rawValue)."
        )
    }
}

public struct FurnitureTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: FurnitureTemplateID
    public var code: String
    public var name: String
    public var category: FurnitureTemplateCategory
    public var visibility: TemplateVisibility
    public var builderType: FurnitureBuilderType
    public var supportedParameters: [FurnitureParameterDefinition]
    public var defaultParameters: FurnitureParameterSet

    public init(
        id: FurnitureTemplateID,
        code: String,
        name: String,
        category: FurnitureTemplateCategory,
        visibility: TemplateVisibility,
        builderType: FurnitureBuilderType,
        supportedParameters: [FurnitureParameterDefinition],
        defaultParameters: FurnitureParameterSet
    ) throws {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Kod szablonu mebla nie może być pusty.")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Nazwa szablonu mebla nie może być pusta.")
        }
        guard Set(supportedParameters.map(\.key)).count == supportedParameters.count else {
            throw DomainError.invariantViolation(
                "Szablon nie może zawierać powtórzonych definicji parametrów."
            )
        }

        let definitionsByKey = Dictionary(
            uniqueKeysWithValues: supportedParameters.map { ($0.key, $0) }
        )

        for entry in defaultParameters.entries {
            guard let definition = definitionsByKey[entry.key] else {
                throw DomainError.invariantViolation(
                    "Domyślny parametr \(entry.key.rawValue) nie jest obsługiwany przez szablon."
                )
            }
            guard definition.valueKind == entry.value.kind else {
                throw DomainError.invariantViolation(
                    "Domyślna wartość parametru \(entry.key.rawValue) ma nieprawidłowy typ."
                )
            }
        }

        let missingRequiredKeys = supportedParameters
            .filter(\.isRequired)
            .map(\.key)
            .filter { defaultParameters.value(for: $0) == nil }

        guard missingRequiredKeys.isEmpty else {
            throw DomainError.invariantViolation(
                "Szablon nie zawiera domyślnych wartości wszystkich wymaganych parametrów."
            )
        }

        self.id = id
        self.code = code
        self.name = name
        self.category = category
        self.visibility = visibility
        self.builderType = builderType
        self.supportedParameters = supportedParameters
        self.defaultParameters = defaultParameters
    }

    public func resolvedParameters(
        overrides: FurnitureParameterSet
    ) throws -> FurnitureParameterSet {
        let supportedByKey = Dictionary(
            uniqueKeysWithValues: supportedParameters.map { ($0.key, $0) }
        )

        for entry in overrides.entries {
            guard let definition = supportedByKey[entry.key] else {
                throw DomainError.invariantViolation(
                    "Parametr \(entry.key.rawValue) nie jest obsługiwany przez szablon \(code)."
                )
            }
            guard definition.valueKind == entry.value.kind else {
                throw DomainError.invariantViolation(
                    "Parametr \(entry.key.rawValue) ma nieprawidłowy typ dla szablonu \(code)."
                )
            }
        }

        return try defaultParameters.merged(with: overrides)
    }
}

public enum SystemFurnitureTemplates {
    public static let baseCabinetID = FurnitureTemplateID(
        rawValue: UUID(uuidString: "b1500000-0000-4000-8000-000000000001")!
    )

    public static let wallCabinetID = FurnitureTemplateID(
        rawValue: UUID(uuidString: "b1500000-0000-4000-8000-000000000002")!
    )

    public static func baseCabinet() throws -> FurnitureTemplate {
        try FurnitureTemplate(
            id: baseCabinetID,
            code: "SYS-KITCHEN-BASE-001",
            name: "Szafka dolna z półką",
            category: .kitchenBaseCabinet,
            visibility: .system,
            builderType: .baseCabinet,
            supportedParameters: try standardCabinetParameterDefinitions(),
            defaultParameters: try FurnitureParameterSet(entries: [
                .init(key: .width, value: .millimeters(600)),
                .init(key: .height, value: .millimeters(720)),
                .init(key: .depth, value: .millimeters(560)),
                .init(key: .carcassThickness, value: .millimeters(18)),
                .init(key: .shelfCount, value: .integer(1)),
                .init(key: .shelfFrontSetback, value: .millimeters(20)),
                .init(key: .backType, value: .cabinetBackType(.inset)),
                .init(key: .backThickness, value: .millimeters(3)),
                .init(key: .backInset, value: .millimeters(10)),
                .init(key: .topConstruction, value: .cabinetTopConstruction(.frontAndRearRails)),
                .init(key: .topRailDepth, value: .millimeters(100)),
                .init(key: .frontEnabled, value: .boolean(true)),
                .init(key: .frontThickness, value: .millimeters(18)),
                .init(key: .frontGap, value: .millimeters(2)),
                .init(key: .frontInset, value: .millimeters(0)),
                .init(key: .openingTechnology, value: .openingTechnology(.handle)),
                .init(key: .bottomShortening, value: .millimeters(0))
            ])
        )
    }

    public static func wallCabinet() throws -> FurnitureTemplate {
        try FurnitureTemplate(
            id: wallCabinetID,
            code: "SYS-KITCHEN-WALL-001",
            name: "Szafka wisząca z półkami",
            category: .kitchenWallCabinet,
            visibility: .system,
            builderType: .wallCabinet,
            supportedParameters: try standardCabinetParameterDefinitions(),
            defaultParameters: try FurnitureParameterSet(entries: [
                .init(key: .width, value: .millimeters(600)),
                .init(key: .height, value: .millimeters(720)),
                .init(key: .depth, value: .millimeters(320)),
                .init(key: .carcassThickness, value: .millimeters(18)),
                .init(key: .shelfCount, value: .integer(2)),
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
                .init(key: .bottomShortening, value: .millimeters(30))
            ])
        )
    }

    private static func standardCabinetParameterDefinitions() throws -> [FurnitureParameterDefinition] {
        [
            try .init(key: .width, displayName: "Szerokość", valueKind: .millimeters),
            try .init(key: .height, displayName: "Wysokość", valueKind: .millimeters),
            try .init(key: .depth, displayName: "Głębokość", valueKind: .millimeters),
            try .init(key: .carcassThickness, displayName: "Grubość korpusu", valueKind: .millimeters),
            try .init(key: .shelfCount, displayName: "Liczba półek", valueKind: .integer),
            try .init(key: .shelfFrontSetback, displayName: "Cofnięcie półki od frontu", valueKind: .millimeters),
            try .init(key: .backType, displayName: "Typ pleców", valueKind: .cabinetBackType),
            try .init(key: .backThickness, displayName: "Grubość pleców", valueKind: .millimeters),
            try .init(key: .backInset, displayName: "Cofnięcie pleców", valueKind: .millimeters),
            try .init(key: .topConstruction, displayName: "Konstrukcja góry", valueKind: .cabinetTopConstruction),
            try .init(key: .topRailDepth, displayName: "Głębokość wzmocnień górnych", valueKind: .millimeters),
            try .init(key: .frontEnabled, displayName: "Front", valueKind: .boolean),
            try .init(key: .frontThickness, displayName: "Grubość frontu", valueKind: .millimeters),
            try .init(key: .frontGap, displayName: "Luz frontu", valueKind: .millimeters),
            try .init(key: .frontInset, displayName: "Cofnięcie frontu", valueKind: .millimeters),
            try .init(key: .openingTechnology, displayName: "Technologia otwierania", valueKind: .openingTechnology),
            try .init(key: .bottomShortening, displayName: "Skrócenie dolnego wieńca", valueKind: .millimeters)
        ]
    }
}
