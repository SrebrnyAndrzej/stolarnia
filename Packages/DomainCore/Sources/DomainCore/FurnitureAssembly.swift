import Foundation

public enum FurnitureAssemblyKind: String, Codable, CaseIterable, Sendable {
    case cabinet
    case wardrobe
    case desk
    case shelving
    case table
    case recessBuiltIn
    case slidingWardrobe
    case custom
}

public enum FurnitureComponentRole: String, Codable, CaseIterable, Sendable {
    case side
    case top
    case bottom
    case shelf
    case divider
    case back
    case front
    case worktop
    case plinth
    case filler
    case maskingPanel
    case decorativeSide
    case reinforcement
    case rail
    case leg
    /// Element skrzynki szuflady: dno, boki i tył.
    ///
    /// Miały rolę `.custom`, więc w rozkroju i BOM nie różniły się od dowolnej
    /// listwy — nie dało się ich ani odfiltrować, ani policzyć osobno.
    /// A skrzynka rządzi się innymi regułami niż korpus: inna grubość płyty,
    /// inne obrzeże, i **nie zawsze robi się ją samemu** — przy systemach
    /// z gotową skrzynką (Amix Slim Box, Blum LEGRABOX) te formatki w ogóle
    /// nie idą na piłę.
    ///
    /// Nowy przypadek jest bezpieczny dla zapisanych danych: stare rekordy
    /// nie mają tej wartości, więc dekodują się jak dotąd.
    case drawerBox
    case custom
}

public struct FurnitureComponent: Identifiable, Codable, Hashable, Sendable {
    public let id: ComponentID
    public var code: String
    public var role: FurnitureComponentRole
    public var size: Size3MM
    public var localPosition: Point3MM
    public var rotationDegrees: Double
    public var isShared: Bool
    /// Sposób otwierania — tylko dla komponentów o roli `.front`.
    ///
    /// **Bez tego strona zawiasu nie dociera nigdzie poza edytor.** Kierunek
    /// mieszka w `ElevationFrontSpan.opening`, ale zespół go nie niósł, więc
    /// karta techniczna i silnik szuflad nie miały skąd wiedzieć, po której
    /// stronie front wystaje w światło. Skutkowało to symetrycznym odsunięciem
    /// skrzynki szuflady — po obu stronach, choć zawias jest po jednej.
    ///
    /// `Optional`, bo dla płyt, półek i pleców pytanie nie ma sensu, a starsze
    /// zapisy nie mają tego klucza.
    public var opening: FurnitureFrontOpeningV020?

    public init(
        id: ComponentID = ComponentID(),
        code: String,
        role: FurnitureComponentRole,
        size: Size3MM,
        localPosition: Point3MM = .zero,
        rotationDegrees: Double = 0,
        isShared: Bool = false,
        opening: FurnitureFrontOpeningV020? = nil
    ) throws {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Kod komponentu nie może być pusty.")
        }
        guard size.isValid else {
            throw DomainError.invariantViolation("Komponent musi mieć dodatni gabaryt 3D.")
        }
        guard rotationDegrees.isFinite else {
            throw DomainError.invariantViolation("Kąt komponentu musi być skończony.")
        }

        self.id = id
        self.code = code
        self.role = role
        self.size = size
        self.localPosition = localPosition
        self.rotationDegrees = rotationDegrees
        self.isShared = isShared
        self.opening = opening
    }
}

public struct FurnitureSubassembly: Identifiable, Codable, Hashable, Sendable {
    public let id: SubassemblyID
    public var name: String
    public var componentIDs: [ComponentID]

    public init(
        id: SubassemblyID = SubassemblyID(),
        name: String,
        componentIDs: [ComponentID]
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Nazwa podzespołu nie może być pusta.")
        }
        guard Set(componentIDs).count == componentIDs.count else {
            throw DomainError.invariantViolation("Podzespół nie może zawierać powtórzonych ComponentID.")
        }

        self.id = id
        self.name = name
        self.componentIDs = componentIDs
    }
}

public enum FurnitureConstraint: Codable, Hashable, Sendable {
    case alignLeft(componentID: ComponentID, referenceID: ComponentID)
    case alignRight(componentID: ComponentID, referenceID: ComponentID)
    case alignTop(componentID: ComponentID, referenceID: ComponentID)
    case alignBottom(componentID: ComponentID, referenceID: ComponentID)
    case centerHorizontal(componentID: ComponentID, referenceID: ComponentID)
    case centerVertical(componentID: ComponentID, referenceID: ComponentID)
    case equalSpacing(componentIDs: [ComponentID])
    case equalWidth(componentIDs: [ComponentID])
    case equalHeight(componentIDs: [ComponentID])
    case fixedGap(firstID: ComponentID, secondID: ComponentID, value: Millimeters)
    case offset(componentID: ComponentID, referenceID: ComponentID, value: Vector2MM)
    case sharedPartition(componentID: ComponentID, subassemblyIDs: [SubassemblyID])
}

public struct FurnitureAssembly: Identifiable, Codable, Hashable, Sendable {
    public let id: FurnitureAssemblyID
    public var templateID: FurnitureTemplateID?
    public var name: String
    public var kind: FurnitureAssemblyKind
    public var size: Size3MM
    /// Dobrana długość nominalna prowadnicy szuflady.
    ///
    /// To jest wymiar zamówieniowy, nie głębokość skrzynki ani korpusu.
    /// `Optional` zachowuje zgodność ze starszymi zapisami oraz rozróżnia
    /// zespół bez szuflad od zespołu z dobraną prowadnicą. `nil` oznacza
    /// również zespół niejednoznaczny: jego strefy używają różnych systemów
    /// albo różnych długości. Pole opisuje cały mebel, więc nie może wtedy
    /// udawać wartości pierwszej strefy.
    public var drawerRunnerNominalLength: Millimeters?
    public var components: [FurnitureComponent]
    public var subassemblies: [FurnitureSubassembly]
    public var constraints: [FurnitureConstraint]
    public var placement: FurniturePlacement?

    public init(
        id: FurnitureAssemblyID = FurnitureAssemblyID(),
        templateID: FurnitureTemplateID? = nil,
        name: String,
        kind: FurnitureAssemblyKind,
        size: Size3MM,
        drawerRunnerNominalLength: Millimeters? = nil,
        components: [FurnitureComponent] = [],
        subassemblies: [FurnitureSubassembly] = [],
        constraints: [FurnitureConstraint] = [],
        placement: FurniturePlacement? = nil
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.invariantViolation("Nazwa zespołu meblowego nie może być pusta.")
        }
        guard size.isValid else {
            throw DomainError.invariantViolation("Zespół meblowy musi mieć dodatni gabaryt 3D.")
        }
        if let drawerRunnerNominalLength,
           drawerRunnerNominalLength <= .zero {
            throw DomainError.invariantViolation(
                "Długość nominalna prowadnicy musi być dodatnia."
            )
        }
        guard Set(components.map(\.id)).count == components.count else {
            throw DomainError.invariantViolation("Zespół nie może zawierać powtórzonych ComponentID.")
        }
        guard Set(subassemblies.map(\.id)).count == subassemblies.count else {
            throw DomainError.invariantViolation("Zespół nie może zawierać powtórzonych SubassemblyID.")
        }

        let componentIDs = Set(components.map(\.id))
        let unknownComponentIDs = subassemblies
            .flatMap(\.componentIDs)
            .filter { !componentIDs.contains($0) }
        guard unknownComponentIDs.isEmpty else {
            throw DomainError.invariantViolation(
                "Podzespół odwołuje się do komponentu, który nie istnieje w FurnitureAssembly."
            )
        }
        if let placement, placement.assemblyID != id {
            throw DomainError.invariantViolation(
                "FurniturePlacement musi wskazywać ID tego samego FurnitureAssembly."
            )
        }

        self.id = id
        self.templateID = templateID
        self.name = name
        self.kind = kind
        self.size = size
        self.drawerRunnerNominalLength = drawerRunnerNominalLength
        self.components = components
        self.subassemblies = subassemblies
        self.constraints = constraints
        self.placement = placement
    }

    public func component(id: ComponentID) -> FurnitureComponent? {
        components.first { $0.id == id }
    }
}
