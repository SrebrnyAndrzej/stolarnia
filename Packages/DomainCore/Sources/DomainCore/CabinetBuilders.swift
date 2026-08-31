import Foundation

public protocol FurnitureBuilding: Sendable {
    var builderType: FurnitureBuilderType { get }

    func build(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly: FurnitureAssembly?
    ) throws -> FurnitureAssembly
}

public extension FurnitureBuilding {
    func build(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet = FurnitureParameterSet()
    ) throws -> FurnitureAssembly {
        try build(
            template: template,
            parameters: parameters,
            preservingIDsFrom: nil
        )
    }
}

public struct CabinetBuildParameters: Codable, Hashable, Sendable {
    public var width: Millimeters
    public var height: Millimeters
    public var depth: Millimeters
    public var carcassThickness: Millimeters
    public var shelfCount: Int
    public var shelfFrontSetback: Millimeters
    public var backType: CabinetBackType
    public var backThickness: Millimeters
    public var backInset: Millimeters
    public var topConstruction: CabinetTopConstruction
    public var topRailDepth: Millimeters
    public var frontEnabled: Bool
    public var frontThickness: Millimeters
    public var frontGap: Millimeters
    public var frontInset: Millimeters
    public var openingTechnology: OpeningTechnology
    public var bottomShortening: Millimeters

    public init(parameterSet: FurnitureParameterSet) throws {
        self.width = try parameterSet.millimeters(for: .width)
        self.height = try parameterSet.millimeters(for: .height)
        self.depth = try parameterSet.millimeters(for: .depth)
        self.carcassThickness = try parameterSet.millimeters(for: .carcassThickness)
        self.shelfCount = try parameterSet.integer(for: .shelfCount)
        self.shelfFrontSetback = try parameterSet.millimeters(for: .shelfFrontSetback)
        self.backType = try parameterSet.cabinetBackType(for: .backType)
        self.backThickness = try parameterSet.millimeters(for: .backThickness)
        self.backInset = try parameterSet.millimeters(for: .backInset)
        self.topConstruction = try parameterSet.cabinetTopConstruction(for: .topConstruction)
        self.topRailDepth = try parameterSet.millimeters(for: .topRailDepth)
        self.frontEnabled = try parameterSet.boolean(for: .frontEnabled)
        self.frontThickness = try parameterSet.millimeters(for: .frontThickness)
        self.frontGap = try parameterSet.millimeters(for: .frontGap)
        self.frontInset = try parameterSet.millimeters(for: .frontInset)
        self.openingTechnology = try parameterSet.openingTechnology(for: .openingTechnology)
        self.bottomShortening = try parameterSet.millimeters(for: .bottomShortening)

        try validate()
    }

    public var innerWidth: Millimeters {
        width - carcassThickness * 2
    }

    public var innerHeight: Millimeters {
        height - carcassThickness * 2
    }

    public var rearUsablePlane: Millimeters {
        switch backType {
        case .none:
            return depth
        case .inset:
            return depth - backInset - backThickness
        }
    }

    public var shelfDepth: Millimeters {
        rearUsablePlane - shelfFrontSetback
    }

    private func validate() throws {
        let positiveDimensions: [(String, Millimeters)] = [
            ("width", width),
            ("height", height),
            ("depth", depth),
            ("carcassThickness", carcassThickness),
            ("frontThickness", frontThickness)
        ]

        for (field, value) in positiveDimensions where value <= .zero {
            throw DomainError.invalidDimension(field: field, value: value.rawValue)
        }

        let nonNegativeDimensions: [(String, Millimeters)] = [
            ("shelfFrontSetback", shelfFrontSetback),
            ("backThickness", backThickness),
            ("backInset", backInset),
            ("topRailDepth", topRailDepth),
            ("frontGap", frontGap),
            ("frontInset", frontInset),
            ("bottomShortening", bottomShortening)
        ]

        for (field, value) in nonNegativeDimensions where value < .zero {
            throw DomainError.invalidDimension(field: field, value: value.rawValue)
        }

        guard shelfCount >= 0, shelfCount <= 20 else {
            throw DomainError.invariantViolation("Liczba półek musi mieścić się w zakresie 0...20.")
        }
        guard width > carcassThickness * 2 else {
            throw DomainError.invariantViolation("Szerokość mebla musi być większa niż suma grubości boków.")
        }
        guard height > carcassThickness * 2 else {
            throw DomainError.invariantViolation("Wysokość mebla musi być większa niż suma grubości wieńców.")
        }
        guard frontGap * 2 < width, frontGap * 2 < height else {
            throw DomainError.invariantViolation("Luz frontu jest zbyt duży dla gabarytu mebla.")
        }
        guard shelfFrontSetback < rearUsablePlane else {
            throw DomainError.invariantViolation("Cofnięcie półki pozostawia niedodatnią głębokość półki.")
        }
        guard shelfDepth > .zero else {
            throw DomainError.invariantViolation("Głębokość półki musi być dodatnia.")
        }

        if backType == .inset {
            guard backThickness > .zero else {
                throw DomainError.invariantViolation("Plecy wpuszczane muszą mieć dodatnią grubość.")
            }
            guard backInset + backThickness < depth else {
                throw DomainError.invariantViolation("Plecy i ich cofnięcie nie mieszczą się w głębokości korpusu.")
            }
        }

        if topConstruction == .frontAndRearRails {
            guard topRailDepth > .zero else {
                throw DomainError.invariantViolation("Wzmocnienia górne muszą mieć dodatnią głębokość.")
            }

            let rearReservation: Millimeters = backType == .inset
                ? backInset + backThickness
                : .zero

            guard topRailDepth * 2 + rearReservation <= depth else {
                throw DomainError.invariantViolation(
                    "Przednie i tylne wzmocnienie górne nie mieszczą się w głębokości korpusu."
                )
            }
        }

        if openingTechnology == .shortenedBottomFingerPull {
            guard bottomShortening > .zero, bottomShortening < depth else {
                throw DomainError.invariantViolation(
                    "Skrócenie dolnego wieńca musi być dodatnie i mniejsze od głębokości mebla."
                )
            }
        }

        if shelfCount > 0 {
            let availableClearHeight = innerHeight - carcassThickness * Double(shelfCount)
            guard availableClearHeight > .zero else {
                throw DomainError.invariantViolation(
                    "Wysokość korpusu jest zbyt mała dla zadanej liczby półek."
                )
            }
        }
    }
}

public struct BaseCabinetBuilder: FurnitureBuilding {
    public let builderType: FurnitureBuilderType = .baseCabinet

    public init() {}

    public func build(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly: FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        guard template.builderType == builderType else {
            throw DomainError.invariantViolation(
                "BaseCabinetBuilder nie może zbudować szablonu typu \(template.builderType.rawValue)."
            )
        }

        let resolvedSet = try template.resolvedParameters(overrides: parameters)
        let resolved = try CabinetBuildParameters(parameterSet: resolvedSet)
        let ids = try CabinetStableIDResolver(
            template: template,
            existingAssembly: existingAssembly
        )

        var components = try CabinetComponentFactory.standardCarcassComponents(
            parameters: resolved,
            ids: ids,
            shortenedBottom: false
        )

        components.append(contentsOf: try CabinetComponentFactory.topComponents(
            parameters: resolved,
            ids: ids
        ))
        components.append(contentsOf: try CabinetComponentFactory.shelfComponents(
            parameters: resolved,
            ids: ids
        ))
        components.append(contentsOf: try CabinetComponentFactory.backComponents(
            parameters: resolved,
            ids: ids
        ))
        components.append(contentsOf: try CabinetComponentFactory.frontComponents(
            parameters: resolved,
            ids: ids
        ))

        return try CabinetAssemblyFactory.makeAssembly(
            template: template,
            parameters: resolved,
            components: components,
            ids: ids,
            existingAssembly: existingAssembly
        )
    }
}

public struct WallCabinetBuilder: FurnitureBuilding {
    public let builderType: FurnitureBuilderType = .wallCabinet

    public init() {}

    public func build(
        template: FurnitureTemplate,
        parameters: FurnitureParameterSet,
        preservingIDsFrom existingAssembly: FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        guard template.builderType == builderType else {
            throw DomainError.invariantViolation(
                "WallCabinetBuilder nie może zbudować szablonu typu \(template.builderType.rawValue)."
            )
        }

        let resolvedSet = try template.resolvedParameters(overrides: parameters)
        let resolved = try CabinetBuildParameters(parameterSet: resolvedSet)
        let ids = try CabinetStableIDResolver(
            template: template,
            existingAssembly: existingAssembly
        )

        var components = try CabinetComponentFactory.standardCarcassComponents(
            parameters: resolved,
            ids: ids,
            shortenedBottom: resolved.openingTechnology == .shortenedBottomFingerPull
        )

        components.append(contentsOf: try CabinetComponentFactory.topComponents(
            parameters: resolved,
            ids: ids
        ))
        components.append(contentsOf: try CabinetComponentFactory.shelfComponents(
            parameters: resolved,
            ids: ids
        ))
        components.append(contentsOf: try CabinetComponentFactory.backComponents(
            parameters: resolved,
            ids: ids
        ))
        components.append(contentsOf: try CabinetComponentFactory.frontComponents(
            parameters: resolved,
            ids: ids
        ))

        return try CabinetAssemblyFactory.makeAssembly(
            template: template,
            parameters: resolved,
            components: components,
            ids: ids,
            existingAssembly: existingAssembly
        )
    }
}

public extension FurnitureAssembly {
    func component(code: String) -> FurnitureComponent? {
        components.first { $0.code == code }
    }
}

private struct CabinetStableIDResolver {
    let assemblyID: FurnitureAssemblyID
    private let existingAssembly: FurnitureAssembly?

    init(
        template: FurnitureTemplate,
        existingAssembly: FurnitureAssembly?
    ) throws {
        if let existingAssembly,
           let existingTemplateID = existingAssembly.templateID,
           existingTemplateID != template.id {
            throw DomainError.invariantViolation(
                "Nie można przebudować zespołu przy użyciu innego FurnitureTemplateID."
            )
        }

        self.assemblyID = existingAssembly?.id ?? FurnitureAssemblyID()
        self.existingAssembly = existingAssembly
    }

    func componentID(for code: String) -> ComponentID {
        existingAssembly?.components.first { $0.code == code }?.id ?? ComponentID()
    }

    func subassemblyID(for name: String) -> SubassemblyID {
        existingAssembly?.subassemblies.first { $0.name == name }?.id ?? SubassemblyID()
    }
}

private enum CabinetComponentFactory {
    /// Zawsze dwa pełne boki (BOK-L, BOK-P) — nigdy współdzielone z sąsiednim
    /// modułem w ciągu. Każdy moduł w tej stolarni jest osobnym meblem
    /// montowanym obok sąsiada, nie skrzynią z dzielonymi przegrodami.
    /// Reguła z [[regula-modul-w-ciagu-osobny-mebel]] — patrz komentarz przy
    /// `ElevationModule.makeAssembly` po drugą, symetryczną implementację.
    static func standardCarcassComponents(
        parameters: CabinetBuildParameters,
        ids: CabinetStableIDResolver,
        shortenedBottom: Bool
    ) throws -> [FurnitureComponent] {
        let thickness = parameters.carcassThickness
        let rightX = parameters.width - thickness
        let bottomDepth = shortenedBottom
            ? parameters.depth - parameters.bottomShortening
            : parameters.depth
        let bottomZ = shortenedBottom
            ? parameters.bottomShortening
            : .zero

        return [
            try FurnitureComponent(
                id: ids.componentID(for: "BOK-L"),
                code: "BOK-L",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: parameters.height,
                    depth: parameters.depth
                ),
                localPosition: .zero
            ),
            try FurnitureComponent(
                id: ids.componentID(for: "BOK-P"),
                code: "BOK-P",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: parameters.height,
                    depth: parameters.depth
                ),
                localPosition: Point3MM(x: rightX, y: .zero, z: .zero)
            ),
            try FurnitureComponent(
                id: ids.componentID(for: "WIENIEC-D"),
                code: "WIENIEC-D",
                role: .bottom,
                size: Size3MM(
                    width: parameters.innerWidth,
                    height: thickness,
                    depth: bottomDepth
                ),
                localPosition: Point3MM(x: thickness, y: .zero, z: bottomZ)
            )
        ]
    }

    static func topComponents(
        parameters: CabinetBuildParameters,
        ids: CabinetStableIDResolver
    ) throws -> [FurnitureComponent] {
        let y = parameters.height - parameters.carcassThickness

        switch parameters.topConstruction {
        case .fullPanel:
            return [
                try FurnitureComponent(
                    id: ids.componentID(for: "WIENIEC-G"),
                    code: "WIENIEC-G",
                    role: .top,
                    size: Size3MM(
                        width: parameters.innerWidth,
                        height: parameters.carcassThickness,
                        depth: parameters.depth
                    ),
                    localPosition: Point3MM(
                        x: parameters.carcassThickness,
                        y: y,
                        z: .zero
                    )
                )
            ]

        case .frontAndRearRails:
            let rearReservation: Millimeters = parameters.backType == .inset
                ? parameters.backInset + parameters.backThickness
                : .zero
            let rearZ = parameters.depth - parameters.topRailDepth - rearReservation

            return [
                try FurnitureComponent(
                    id: ids.componentID(for: "WZM-G-P"),
                    code: "WZM-G-P",
                    role: .reinforcement,
                    size: Size3MM(
                        width: parameters.innerWidth,
                        height: parameters.carcassThickness,
                        depth: parameters.topRailDepth
                    ),
                    localPosition: Point3MM(
                        x: parameters.carcassThickness,
                        y: y,
                        z: .zero
                    )
                ),
                try FurnitureComponent(
                    id: ids.componentID(for: "WZM-G-T"),
                    code: "WZM-G-T",
                    role: .reinforcement,
                    size: Size3MM(
                        width: parameters.innerWidth,
                        height: parameters.carcassThickness,
                        depth: parameters.topRailDepth
                    ),
                    localPosition: Point3MM(
                        x: parameters.carcassThickness,
                        y: y,
                        z: rearZ
                    )
                )
            ]
        }
    }

    static func shelfComponents(
        parameters: CabinetBuildParameters,
        ids: CabinetStableIDResolver
    ) throws -> [FurnitureComponent] {
        guard parameters.shelfCount > 0 else {
            return []
        }

        let thickness = parameters.carcassThickness
        let clearHeight = parameters.innerHeight - thickness * Double(parameters.shelfCount)
        let clearGap = clearHeight / Double(parameters.shelfCount + 1)

        return try (1...parameters.shelfCount).map { index in
            let y = thickness
                + clearGap * Double(index)
                + thickness * Double(index - 1)
            let code = String(format: "POLKA-%02d", index)

            return try FurnitureComponent(
                id: ids.componentID(for: code),
                code: code,
                role: .shelf,
                size: Size3MM(
                    width: parameters.innerWidth,
                    height: thickness,
                    depth: parameters.shelfDepth
                ),
                localPosition: Point3MM(
                    x: thickness,
                    y: y,
                    z: parameters.shelfFrontSetback
                )
            )
        }
    }

    static func backComponents(
        parameters: CabinetBuildParameters,
        ids: CabinetStableIDResolver
    ) throws -> [FurnitureComponent] {
        guard parameters.backType == .inset else {
            return []
        }

        return [
            try FurnitureComponent(
                id: ids.componentID(for: "PLECY"),
                code: "PLECY",
                role: .back,
                size: Size3MM(
                    width: parameters.innerWidth,
                    height: parameters.innerHeight,
                    depth: parameters.backThickness
                ),
                localPosition: Point3MM(
                    x: parameters.carcassThickness,
                    y: parameters.carcassThickness,
                    z: parameters.depth - parameters.backInset - parameters.backThickness
                )
            )
        ]
    }

    static func frontComponents(
        parameters: CabinetBuildParameters,
        ids: CabinetStableIDResolver
    ) throws -> [FurnitureComponent] {
        guard parameters.frontEnabled else {
            return []
        }

        return [
            try FurnitureComponent(
                id: ids.componentID(for: "FRONT-01"),
                code: "FRONT-01",
                role: .front,
                size: Size3MM(
                    width: parameters.width - parameters.frontGap * 2,
                    height: parameters.height - parameters.frontGap * 2,
                    depth: parameters.frontThickness
                ),
                localPosition: Point3MM(
                    x: parameters.frontGap,
                    y: parameters.frontGap,
                    z: -parameters.frontThickness + parameters.frontInset
                )
            )
        ]
    }
}

private enum CabinetAssemblyFactory {
    static func makeAssembly(
        template: FurnitureTemplate,
        parameters: CabinetBuildParameters,
        components: [FurnitureComponent],
        ids: CabinetStableIDResolver,
        existingAssembly: FurnitureAssembly?
    ) throws -> FurnitureAssembly {
        let carcassComponentIDs = components
            .filter { $0.role != .front }
            .map(\.id)
        let frontComponentIDs = components
            .filter { $0.role == .front }
            .map(\.id)

        var subassemblies = [
            try FurnitureSubassembly(
                id: ids.subassemblyID(for: "Korpus"),
                name: "Korpus",
                componentIDs: carcassComponentIDs
            )
        ]

        if !frontComponentIDs.isEmpty {
            subassemblies.append(
                try FurnitureSubassembly(
                    id: ids.subassemblyID(for: "Fronty"),
                    name: "Fronty",
                    componentIDs: frontComponentIDs
                )
            )
        }

        let placement: FurniturePlacement?
        if let existingPlacement = existingAssembly?.placement {
            placement = try FurniturePlacement(
                id: existingPlacement.id,
                roomID: existingPlacement.roomID,
                wallID: existingPlacement.wallID,
                assemblyID: ids.assemblyID,
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
            id: ids.assemblyID,
            templateID: template.id,
            name: template.name,
            kind: .cabinet,
            size: Size3MM(
                width: parameters.width,
                height: parameters.height,
                depth: parameters.depth
            ),
            components: components,
            subassemblies: subassemblies,
            constraints: [],
            placement: placement
        )
    }
}
