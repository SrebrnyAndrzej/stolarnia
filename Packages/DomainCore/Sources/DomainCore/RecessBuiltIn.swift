import Foundation

/// Sposób osadzenia mebla względem pomieszczenia.
public enum BuiltInFurnitureType: String, Codable, CaseIterable, Sendable {
    case freestanding
    case wallToWall
    case recessBuiltIn
    case recessBuiltInWithScribedFillers
    case custom
}

/// Układ zabudowy wnękowej. Nazwy i znaczenie przypadków są od tej wersji stałe.
public enum RecessBuiltInLayoutType: String, Codable, CaseIterable, Sendable {
    case simpleCarcass
    case framedOpening
    case fullHeightDecorativeFrame
    case multiZoneBuiltIn
    case custom
}

/// Płaszczyzna, do której wyrównujemy fronty, blendy i panele dekoracyjne.
public enum BuiltInFacePlane: String, Codable, CaseIterable, Sendable {
    case frontFace
    case carcassFace
    case decorativePanelFace
    case wallFace
    case custom
}

public enum BuiltInZoneKind: String, Codable, CaseIterable, Sendable {
    case open
    case closed
    case technical
    case decorative
    case appliance
    case custom
}

public enum FillerSide: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
}

public enum ScribeElementType: String, Codable, CaseIterable, Sendable {
    case sideFiller
    case topFiller
    case bottomFiller
    case plinth
    case overlaySide
    case maskingPanel
    case custom
}

/// Blenda lub maskownica przeznaczona do dopasowania do rzeczywistej wnęki.
public struct ScribeElementDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: ComponentID
    public var code: String
    public var type: ScribeElementType
    public var side: FillerSide
    public var nominalWidth: Millimeters
    public var productionWidth: Millimeters
    public var height: Millimeters
    public var productionAllowance: Millimeters
    public var targetGap: Millimeters
    public var wallProfileID: WallProfileID?
    public var requiresOnSiteScribing: Bool
    public var notes: String

    public init(
        id: ComponentID = ComponentID(),
        code: String,
        type: ScribeElementType,
        side: FillerSide,
        nominalWidth: Millimeters,
        productionWidth: Millimeters,
        height: Millimeters,
        productionAllowance: Millimeters,
        targetGap: Millimeters,
        wallProfileID: WallProfileID? = nil,
        requiresOnSiteScribing: Bool,
        notes: String = ""
    ) throws {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            throw DomainError.invariantViolation("Kod blendy lub maskownicy nie może być pusty.")
        }
        guard nominalWidth >= .zero,
              productionWidth >= nominalWidth,
              height > .zero,
              productionAllowance >= .zero,
              targetGap >= .zero else {
            throw DomainError.invariantViolation(
                "Wymiary blendy lub maskownicy mają nieprawidłowe wartości."
            )
        }

        self.id = id
        self.code = normalizedCode
        self.type = type
        self.side = side
        self.nominalWidth = nominalWidth
        self.productionWidth = productionWidth
        self.height = height
        self.productionAllowance = productionAllowance
        self.targetGap = targetGap
        self.wallProfileID = wallProfileID
        self.requiresOnSiteScribing = requiresOnSiteScribing
        self.notes = notes
    }
}

/// Widoczny, pełnowysoki bok ramy zabudowy. Nie jest bokiem korpusu.
public struct DecorativeSideDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: ComponentID
    public var code: String
    public var side: FillerSide
    public var size: Size3MM
    public var facePlane: BuiltInFacePlane
    public var topAllowance: Millimeters
    public var bottomAllowance: Millimeters
    public var wallProfileID: WallProfileID?
    public var notes: String

    public init(
        id: ComponentID = ComponentID(),
        code: String,
        side: FillerSide,
        size: Size3MM,
        facePlane: BuiltInFacePlane = .decorativePanelFace,
        topAllowance: Millimeters = .zero,
        bottomAllowance: Millimeters = .zero,
        wallProfileID: WallProfileID? = nil,
        notes: String = ""
    ) throws {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            throw DomainError.invariantViolation("Kod boku dekoracyjnego nie może być pusty.")
        }
        guard size.isValid,
              topAllowance >= .zero,
              bottomAllowance >= .zero else {
            throw DomainError.invariantViolation("Wymiary boku dekoracyjnego są nieprawidłowe.")
        }
        guard side == .left || side == .right else {
            throw DomainError.invariantViolation(
                "Pełnowysoki bok dekoracyjny może znajdować się tylko po lewej lub prawej stronie."
            )
        }

        self.id = id
        self.code = normalizedCode
        self.side = side
        self.size = size
        self.facePlane = facePlane
        self.topAllowance = topAllowance
        self.bottomAllowance = bottomAllowance
        self.wallProfileID = wallProfileID
        self.notes = notes
    }
}

/// Niezależna strefa funkcjonalna w zabudowie, np. otwarta wnęka, szafka lub strefa techniczna.
public struct BuiltInZone: Identifiable, Codable, Hashable, Sendable {
    public let id: SubassemblyID
    public var name: String
    public var kind: BuiltInZoneKind
    public var bottomOffset: Millimeters
    public var height: Millimeters
    public var leftBoundaryComponentID: ComponentID
    public var rightBoundaryComponentID: ComponentID
    public var backPanelID: ComponentID?
    public var shelfIDs: [ComponentID]
    public var frontIDs: [ComponentID]
    public var notes: String

    public init(
        id: SubassemblyID = SubassemblyID(),
        name: String,
        kind: BuiltInZoneKind,
        bottomOffset: Millimeters,
        height: Millimeters,
        leftBoundaryComponentID: ComponentID,
        rightBoundaryComponentID: ComponentID,
        backPanelID: ComponentID? = nil,
        shelfIDs: [ComponentID] = [],
        frontIDs: [ComponentID] = [],
        notes: String = ""
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa strefy zabudowy nie może być pusta.")
        }
        guard bottomOffset >= .zero, height > .zero else {
            throw DomainError.invariantViolation("Położenie i wysokość strefy są nieprawidłowe.")
        }
        guard leftBoundaryComponentID != rightBoundaryComponentID else {
            throw DomainError.invariantViolation(
                "Lewa i prawa granica strefy muszą wskazywać różne komponenty."
            )
        }

        self.id = id
        self.name = normalizedName
        self.kind = kind
        self.bottomOffset = bottomOffset
        self.height = height
        self.leftBoundaryComponentID = leftBoundaryComponentID
        self.rightBoundaryComponentID = rightBoundaryComponentID
        self.backPanelID = backPanelID
        self.shelfIDs = shelfIDs
        self.frontIDs = frontIDs
        self.notes = notes
    }
}

/// Kanoniczna definicja zabudowy wnękowej. Korpus, blendy, maskownice i boki
/// dekoracyjne pozostają osobnymi komponentami, lecz korzystają ze wspólnej płaszczyzny licowania.
public struct RecessBuiltInDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: FurnitureAssemblyID
    public var name: String
    public var builtInType: BuiltInFurnitureType
    public var layoutType: RecessBuiltInLayoutType
    public var recessID: RecessID
    public var carcassAssemblyID: FurnitureAssemblyID?
    public var facePlane: BuiltInFacePlane
    public var carcassSetback: Millimeters
    public var targetReveal: Millimeters
    public var leftDecorativeSide: DecorativeSideDefinition?
    public var rightDecorativeSide: DecorativeSideDefinition?
    public var fillers: [ScribeElementDefinition]
    public var zones: [BuiltInZone]
    public var notes: String

    public init(
        id: FurnitureAssemblyID = FurnitureAssemblyID(),
        name: String,
        builtInType: BuiltInFurnitureType = .recessBuiltInWithScribedFillers,
        layoutType: RecessBuiltInLayoutType,
        recessID: RecessID,
        carcassAssemblyID: FurnitureAssemblyID? = nil,
        facePlane: BuiltInFacePlane = .decorativePanelFace,
        carcassSetback: Millimeters = .zero,
        targetReveal: Millimeters = 2,
        leftDecorativeSide: DecorativeSideDefinition? = nil,
        rightDecorativeSide: DecorativeSideDefinition? = nil,
        fillers: [ScribeElementDefinition] = [],
        zones: [BuiltInZone] = [],
        notes: String = ""
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa zabudowy wnękowej nie może być pusta.")
        }
        guard carcassSetback >= .zero, targetReveal >= .zero else {
            throw DomainError.invariantViolation(
                "Cofnięcie korpusu i szczelina docelowa nie mogą być ujemne."
            )
        }

        let fillerSides = fillers.map(\.side)
        guard Set(fillerSides).count == fillerSides.count else {
            throw DomainError.invariantViolation(
                "Zabudowa może zawierać najwyżej jedną blendę lub maskownicę dla każdej strony."
            )
        }

        let zoneIDs = zones.map(\.id)
        guard Set(zoneIDs).count == zoneIDs.count else {
            throw DomainError.invariantViolation("Strefy zabudowy muszą mieć unikalne ID.")
        }

        self.id = id
        self.name = normalizedName
        self.builtInType = builtInType
        self.layoutType = layoutType
        self.recessID = recessID
        self.carcassAssemblyID = carcassAssemblyID
        self.facePlane = facePlane
        self.carcassSetback = carcassSetback
        self.targetReveal = targetReveal
        self.leftDecorativeSide = leftDecorativeSide
        self.rightDecorativeSide = rightDecorativeSide
        self.fillers = fillers
        self.zones = zones
        self.notes = notes
    }
}

public enum FillerDistributionMode: String, Codable, CaseIterable, Sendable {
    case equal
    case leftPriority
    case rightPriority
    case custom
}

public struct FillerCalculationInput: Codable, Hashable, Sendable {
    public var recessWidth: Millimeters
    public var carcassWidth: Millimeters
    public var leftDecorativeSideWidth: Millimeters
    public var rightDecorativeSideWidth: Millimeters
    public var leftInstallationGap: Millimeters
    public var rightInstallationGap: Millimeters
    public var mode: FillerDistributionMode
    public var customLeftFillerWidth: Millimeters?

    public init(
        recessWidth: Millimeters,
        carcassWidth: Millimeters,
        leftDecorativeSideWidth: Millimeters = .zero,
        rightDecorativeSideWidth: Millimeters = .zero,
        leftInstallationGap: Millimeters = .zero,
        rightInstallationGap: Millimeters = .zero,
        mode: FillerDistributionMode = .equal,
        customLeftFillerWidth: Millimeters? = nil
    ) {
        self.recessWidth = recessWidth
        self.carcassWidth = carcassWidth
        self.leftDecorativeSideWidth = leftDecorativeSideWidth
        self.rightDecorativeSideWidth = rightDecorativeSideWidth
        self.leftInstallationGap = leftInstallationGap
        self.rightInstallationGap = rightInstallationGap
        self.mode = mode
        self.customLeftFillerWidth = customLeftFillerWidth
    }
}

public struct FillerCalculationResult: Codable, Hashable, Sendable {
    public var availableForFillers: Millimeters
    public var leftFillerWidth: Millimeters
    public var rightFillerWidth: Millimeters
}

public enum FillerCalculationEngine {
    /// Oblicza nominalne blendy po odjęciu korpusu, boków dekoracyjnych i luzów montażowych.
    /// Naddatek do trasowania jest dodawany później indywidualnie na podstawie profilu ściany.
    public static func calculate(
        _ input: FillerCalculationInput
    ) throws -> FillerCalculationResult {
        guard input.recessWidth > .zero, input.carcassWidth > .zero else {
            throw DomainError.invariantViolation("Szerokość wnęki i korpusu muszą być dodatnie.")
        }

        let nonFillerWidth = input.carcassWidth
            + input.leftDecorativeSideWidth
            + input.rightDecorativeSideWidth
            + input.leftInstallationGap
            + input.rightInstallationGap

        let available = input.recessWidth - nonFillerWidth
        guard available >= .zero else {
            throw DomainError.invariantViolation(
                "Korpus, boki dekoracyjne i luzy są szersze niż światło wnęki."
            )
        }

        let left: Millimeters
        switch input.mode {
        case .equal:
            left = available / 2
        case .leftPriority:
            left = available
        case .rightPriority:
            left = .zero
        case .custom:
            guard let customLeft = input.customLeftFillerWidth,
                  customLeft >= .zero,
                  customLeft <= available else {
                throw DomainError.invariantViolation(
                    "Niestandardowa szerokość lewej blendy musi mieścić się w dostępnej przestrzeni."
                )
            }
            left = customLeft
        }

        return FillerCalculationResult(
            availableForFillers: available,
            leftFillerWidth: left,
            rightFillerWidth: available - left
        )
    }
}
