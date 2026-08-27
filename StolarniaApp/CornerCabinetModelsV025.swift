import DomainCore
import Foundation

enum CornerCabinetKindV025:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case lShaped
    case diagonalFront
    case blindCorner
    /// Półnarożnik — skrócony blat wychodzący na sąsiednią ścianę,
    /// widoczna martwa przestrzeń po jednej stronie. Stosowany gdy nie
    /// ma miejsca na pełny moduł L.
    case halfBlind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lShaped:
            return "Narożna L"
        case .diagonalFront:
            return "Front skośny"
        case .blindCorner:
            return "Ślepy narożnik"
        case .halfBlind:
            return "Półnarożnik"
        }
    }

    var systemImage: String {
        switch self {
        case .lShaped:      return "arrow.turn.down.right"
        case .diagonalFront: return "arrow.triangle.turn.up.right.diamond"
        case .blindCorner:  return "rectangle.split.2x1"
        case .halfBlind:    return "rectangle.split.1x2"
        }
    }
}

enum CornerCabinetHandednessV025:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left:
            return "Lewy"
        case .right:
            return "Prawy"
        }
    }
}

enum CornerCabinetFillerKindV086:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case none
    case wallScribe
    case cornerPost90
    case blindCornerFiller
    case mechanismClearance
    case applianceService

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Brak"
        case .wallScribe:
            return "Blenda przy ścianie"
        case .cornerPost90:
            return "Słupek narożny 90°"
        case .blindCornerFiller:
            return "Blenda ślepego narożnika"
        case .mechanismClearance:
            return "Blenda pod mechanizm"
        case .applianceService:
            return "Blenda serwisowa AGD"
        }
    }

    var productionDescription: String {
        switch self {
        case .none:
            return "Brak osobnej blendy produkcyjnej."
        case .wallScribe:
            return "Dopasuj do ściany i opisz jako element do docinki/szablonu."
        case .cornerPost90:
            return "Zastosuj pionowy słupek narożny rozdzielający fronty na dwóch ścianach."
        case .blindCornerFiller:
            return "Zastosuj widoczną blendę/pull przy ślepym narożniku i pokaż ukrytą martwą strefę."
        case .mechanismClearance:
            return "Zostaw prześwit na pracę okuć, tac i frontu sąsiedniego modułu."
        case .applianceService:
            return "Zostaw dostęp serwisowy i luz wentylacyjno-montażowy przy wysokim module lub AGD."
        }
    }
}

struct CornerCabinetTechnologyRuleV086:
    Codable,
    Hashable
{
    var technology:
        CornerCabinetAccessTechnologyV085
    var compatibleKinds:
        [CornerCabinetKindV025]
    var minimumFrontOpeningMM: Double
    var minimumInternalDepthMM: Double
    var minimumPrimarySpanMM: Double
    var minimumSecondarySpanMM: Double
    var minimumClearHeightMM: Double?
    var maximumClearHeightMM: Double?
    var loadCapacityPerLevelKG: Double?
    var totalLoadCapacityKG: Double?
    var minimumFillerWidthMM: Double
    var recommendedFillerWidthMM: Double
    var requiresMotionEnvelopeCheck: Bool
    var requiresOpeningAngleLimiter: Bool
    var requiresManufacturerTemplate: Bool
    var notes:
        [String]

    func isCompatible(
        with kind:
            CornerCabinetKindV025
    ) -> Bool {
        compatibleKinds.contains(kind)
    }
}

enum CornerCabinetRuleBookV086 {
    static func defaultAccessTechnology(
        for kind:
            CornerCabinetKindV025
    ) -> CornerCabinetAccessTechnologyV085 {
        switch kind {
        case .lShaped:
            return .shelves
        case .diagonalFront:
            return .carousel
        case .blindCorner:
            return .magicCorner
        case .halfBlind:
            return .leMans
        }
    }

    static func recommendedFillerKind(
        kind:
            CornerCabinetKindV025,
        technology:
            CornerCabinetAccessTechnologyV085
    ) -> CornerCabinetFillerKindV086 {
        switch (kind, technology) {
        case (.blindCorner, .magicCorner):
            return .blindCornerFiller
        case (.blindCorner, .leMans),
             (.halfBlind, .leMans):
            return .mechanismClearance
        case (.lShaped, .shelves),
             (.lShaped, .carousel),
             (.lShaped, .cornerDrawers):
            return .cornerPost90
        case (.diagonalFront, .carousel),
             (.diagonalFront, .cornerDrawers):
            return .mechanismClearance
        default:
            return technologyRule(for: technology).recommendedFillerWidthMM > 0
                ? .mechanismClearance
                : .none
        }
    }

    static func technologyRule(
        for technology:
            CornerCabinetAccessTechnologyV085
    ) -> CornerCabinetTechnologyRuleV086 {
        switch technology {
        case .shelves:
            return CornerCabinetTechnologyRuleV086(
                technology: .shelves,
                compatibleKinds: CornerCabinetKindV025.allCases,
                minimumFrontOpeningMM: 300,
                minimumInternalDepthMM: 300,
                minimumPrimarySpanMM: 600,
                minimumSecondarySpanMM: 300,
                minimumClearHeightMM: nil,
                maximumClearHeightMM: nil,
                loadCapacityPerLevelKG: nil,
                totalLoadCapacityKG: nil,
                minimumFillerWidthMM: 0,
                recommendedFillerWidthMM: 30,
                requiresMotionEnvelopeCheck: false,
                requiresOpeningAngleLimiter: false,
                requiresManufacturerTemplate: false,
                notes: [
                    "Półki stałe są dopuszczalne, ale wymagają czytelnego dostępu z wybranego frontu.",
                    "Przy ścianie lub wysokim boku dodaj blendę do pasowania, jeżeli front może ocierać."
                ]
            )
        case .leMans:
            return CornerCabinetTechnologyRuleV086(
                technology: .leMans,
                compatibleKinds: [.blindCorner, .halfBlind],
                minimumFrontOpeningMM: 450,
                minimumInternalDepthMM: 500,
                minimumPrimarySpanMM: 900,
                minimumSecondarySpanMM: 500,
                minimumClearHeightMM: nil,
                maximumClearHeightMM: nil,
                loadCapacityPerLevelKG: 25,
                totalLoadCapacityKG: nil,
                minimumFillerWidthMM: 30,
                recommendedFillerWidthMM: 50,
                requiresMotionEnvelopeCheck: true,
                requiresOpeningAngleLimiter: true,
                requiresManufacturerTemplate: true,
                notes: [
                    "Tace LeMans pracują po łuku i muszą mieć sprawdzoną kopertę ruchu.",
                    "Zaznacz strony montażu, punkty mocowań oraz ogranicznik kąta otwarcia frontu.",
                    "Dobór wariantu wymaga finalnej tabeli producenta dla szerokości frontu i korpusu."
                ]
            )
        case .magicCorner:
            return CornerCabinetTechnologyRuleV086(
                technology: .magicCorner,
                compatibleKinds: [.blindCorner],
                minimumFrontOpeningMM: 450,
                minimumInternalDepthMM: 500,
                minimumPrimarySpanMM: 900,
                minimumSecondarySpanMM: 500,
                minimumClearHeightMM: nil,
                maximumClearHeightMM: nil,
                loadCapacityPerLevelKG: nil,
                totalLoadCapacityKG: 32,
                minimumFillerWidthMM: 40,
                recommendedFillerWidthMM: 80,
                requiresMotionEnvelopeCheck: true,
                requiresOpeningAngleLimiter: false,
                requiresManufacturerTemplate: true,
                notes: [
                    "Magic Corner wymaga podziału na kosze frontowe i tylną strefę wysuwu.",
                    "Ślepy narożnik musi mieć opisaną blendę/pull oraz martwą strefę za sąsiednim modułem.",
                    "Dobór wariantu wymaga finalnej tabeli producenta dla strony lewej/prawej."
                ]
            )
        case .carousel:
            return CornerCabinetTechnologyRuleV086(
                technology: .carousel,
                compatibleKinds: [.lShaped, .diagonalFront],
                minimumFrontOpeningMM: 400,
                minimumInternalDepthMM: 560,
                minimumPrimarySpanMM: 800,
                minimumSecondarySpanMM: 800,
                minimumClearHeightMM: nil,
                maximumClearHeightMM: nil,
                loadCapacityPerLevelKG: 25,
                totalLoadCapacityKG: 57,
                minimumFillerWidthMM: 20,
                recommendedFillerWidthMM: 50,
                requiresMotionEnvelopeCheck: true,
                requiresOpeningAngleLimiter: false,
                requiresManufacturerTemplate: true,
                notes: [
                    "Karuzela/REVO wymaga osi obrotu, promienia półek i kontroli kolizji z frontami.",
                    "Dla REVO 90 przewiduj korpus narożny 80/90 cm oraz osobne światło wysokości.",
                    "W dokumentacji pokaż trzpień/kolumnę oraz ograniczenia obrotu."
                ]
            )
        case .cornerDrawers:
            return CornerCabinetTechnologyRuleV086(
                technology: .cornerDrawers,
                compatibleKinds: [.lShaped, .diagonalFront],
                minimumFrontOpeningMM: 600,
                minimumInternalDepthMM: 560,
                minimumPrimarySpanMM: 900,
                minimumSecondarySpanMM: 900,
                minimumClearHeightMM: nil,
                maximumClearHeightMM: nil,
                loadCapacityPerLevelKG: nil,
                totalLoadCapacityKG: nil,
                minimumFillerWidthMM: 30,
                recommendedFillerWidthMM: 60,
                requiresMotionEnvelopeCheck: true,
                requiresOpeningAngleLimiter: false,
                requiresManufacturerTemplate: true,
                notes: [
                    "Szuflady narożne wymagają skośnych frontów, prowadnic po obu stronach i kontroli kolizji uchwytów.",
                    "Każda szuflada musi dostać osobne formatki, prowadnice i linie wierceń."
                ]
            )
        }
    }
}

struct CornerCabinetDefinitionV025:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var assemblyID:
        FurnitureAssemblyID
    var kind:
        CornerCabinetKindV025
    var handedness:
        CornerCabinetHandednessV025

    var leftArmMM: Double
    var rightArmMM: Double
    var depthMM: Double
    var frontWidthMM: Double
    var deadSpaceMM: Double
    var frontAngleDegrees: Double
    var shelfCount: Int
    var accessTechnologyOverride:
        CornerCabinetAccessTechnologyV085?
    var fillerKindOverride:
        CornerCabinetFillerKindV086?
    var fillerWidthMM:
        Double?
    var clearHeightMM:
        Double?
    var handleProjectionMM:
        Double?

    init(
        id: UUID = UUID(),
        assemblyID:
            FurnitureAssemblyID,
        kind:
            CornerCabinetKindV025 =
                .lShaped,
        handedness:
            CornerCabinetHandednessV025 =
                .left,
        leftArmMM: Double = 900,
        rightArmMM: Double = 900,
        depthMM: Double = 560,
        frontWidthMM: Double = 450,
        deadSpaceMM: Double = 300,
        frontAngleDegrees: Double = 45,
        shelfCount: Int = 2,
        accessTechnologyOverride:
            CornerCabinetAccessTechnologyV085? = nil,
        fillerKindOverride:
            CornerCabinetFillerKindV086? = nil,
        fillerWidthMM:
            Double? = nil,
        clearHeightMM:
            Double? = nil,
        handleProjectionMM:
            Double? = nil
    ) {
        self.id = id
        self.assemblyID = assemblyID
        self.kind = kind
        self.handedness =
            handedness
        self.leftArmMM =
            max(leftArmMM, 300)
        self.rightArmMM =
            max(rightArmMM, 300)
        self.depthMM =
            max(depthMM, 300)
        self.frontWidthMM =
            max(frontWidthMM, 200)
        self.deadSpaceMM =
            max(deadSpaceMM, 0)
        self.frontAngleDegrees =
            min(
                max(
                    frontAngleDegrees,
                    20
                ),
                70
            )
        self.shelfCount =
            min(
                max(
                    shelfCount,
                    0
                ),
                8
            )
        self.accessTechnologyOverride =
            accessTechnologyOverride
        self.fillerKindOverride =
            fillerKindOverride
        self.fillerWidthMM =
            fillerWidthMM.map { max($0, 0) }
        self.clearHeightMM =
            clearHeightMM.map { max($0, 0) }
        self.handleProjectionMM =
            handleProjectionMM.map { max($0, 0) }
    }

    var effectiveAccessTechnology:
        CornerCabinetAccessTechnologyV085
    {
        accessTechnologyOverride
            ?? CornerCabinetRuleBookV086
                .defaultAccessTechnology(
                    for: kind
                )
    }

    var effectiveFillerKind:
        CornerCabinetFillerKindV086
    {
        fillerKindOverride
            ?? CornerCabinetRuleBookV086
                .recommendedFillerKind(
                    kind: kind,
                    technology: effectiveAccessTechnology
                )
    }

    var effectiveFillerWidthMM:
        Double
    {
        fillerWidthMM
            ?? CornerCabinetRuleBookV086
                .technologyRule(
                    for: effectiveAccessTechnology
                )
                .recommendedFillerWidthMM
    }

    var validationMessages:
        [String]
    {
        var messages: [String] = []

        if leftArmMM < depthMM {
            messages.append(
                "Lewe ramię jest krótsze niż głębokość."
            )
        }

        if rightArmMM < depthMM {
            messages.append(
                "Prawe ramię jest krótsze niż głębokość."
            )
        }

        if kind == .blindCorner,
           deadSpaceMM < 150 {
            messages.append(
                "Ślepy narożnik wymaga martwej przestrzeni minimum 150 mm."
            )
        }

        if kind == .halfBlind,
           deadSpaceMM < 50 {
            messages.append(
                "Półnarożnik wymaga wysuniecia minimum 50 mm."
            )
        }

        if kind == .diagonalFront,
           !(20...70).contains(
                frontAngleDegrees
           ) {
            messages.append(
                "Kąt frontu skośnego musi mieścić się w zakresie 20–70°."
            )
        }

        let technology =
            effectiveAccessTechnology
        let rule =
            CornerCabinetRuleBookV086
                .technologyRule(
                    for: technology
                )

        if !rule.isCompatible(
            with: kind
        ) {
            messages.append(
                "\(technology.title) nie pasuje do typu: \(kind.title)."
            )
        }

        if frontWidthMM < rule.minimumFrontOpeningMM {
            messages.append(
                "\(technology.title) wymaga światła frontu minimum \(Int(rule.minimumFrontOpeningMM)) mm."
            )
        }

        if depthMM < rule.minimumInternalDepthMM {
            messages.append(
                "\(technology.title) wymaga światła głębokości minimum \(Int(rule.minimumInternalDepthMM)) mm."
            )
        }

        if leftArmMM < rule.minimumPrimarySpanMM,
           rightArmMM < rule.minimumPrimarySpanMM {
            messages.append(
                "\(technology.title) wymaga przynajmniej jednego ramienia minimum \(Int(rule.minimumPrimarySpanMM)) mm."
            )
        }

        if max(leftArmMM, rightArmMM) >= rule.minimumPrimarySpanMM,
           min(leftArmMM, rightArmMM) < rule.minimumSecondarySpanMM {
            messages.append(
                "\(technology.title) wymaga drugiego ramienia minimum \(Int(rule.minimumSecondarySpanMM)) mm."
            )
        }

        if effectiveFillerKind != .none,
           effectiveFillerWidthMM < rule.minimumFillerWidthMM {
            messages.append(
                "\(effectiveFillerKind.title) ma mniej niż minimalne \(Int(rule.minimumFillerWidthMM)) mm."
            )
        }

        if effectiveFillerKind == .none,
           rule.minimumFillerWidthMM > 0 {
            messages.append(
                "\(technology.title) wymaga blendy lub luzu technologicznego minimum \(Int(rule.minimumFillerWidthMM)) mm."
            )
        }

        if let clearHeightMM,
           let minimumClearHeight =
            rule.minimumClearHeightMM,
           clearHeightMM < minimumClearHeight {
            messages.append(
                "\(technology.title) wymaga światła wysokości minimum \(Int(minimumClearHeight)) mm."
            )
        }

        if let clearHeightMM,
           let maximumClearHeight =
            rule.maximumClearHeightMM,
           clearHeightMM > maximumClearHeight {
            messages.append(
                "\(technology.title) przekracza światło wysokości \(Int(maximumClearHeight)) mm."
            )
        }

        return messages
    }
}

enum CornerCabinetAccessTechnologyV085:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case shelves
    case leMans
    case magicCorner
    case carousel
    case cornerDrawers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelves:
            return "Półki stałe"
        case .leMans:
            return "LeMans"
        case .magicCorner:
            return "Magic Corner"
        case .carousel:
            return "Karuzela"
        case .cornerDrawers:
            return "Szuflady narożne"
        }
    }
}

struct CornerCabinetFootprintV085:
    Hashable
{
    var assemblyID:
        FurnitureAssemblyID
    var kind:
        CornerCabinetKindV025
    var handedness:
        CornerCabinetHandednessV025
    var primaryWallSpanMM: Double
    var secondaryWallSpanMM: Double
    var depthMM: Double
    var frontOpeningMM: Double
    var deadZoneMM: Double
    var frontAngleDegrees: Double
    var shelfCount: Int
    var accessTechnology:
        CornerCabinetAccessTechnologyV085
    var fillerKind:
        CornerCabinetFillerKindV086
    var fillerWidthMM: Double
    var clearHeightMM: Double
    var handleProjectionMM: Double

    init(
        definition:
            CornerCabinetDefinitionV025,
        assembly:
            FurnitureAssembly
    ) {
        let primaryArm =
            definition.handedness == .left
            ? definition.leftArmMM
            : definition.rightArmMM
        let secondaryArm =
            definition.handedness == .left
            ? definition.rightArmMM
            : definition.leftArmMM

        assemblyID =
            definition.assemblyID
        kind =
            definition.kind
        handedness =
            definition.handedness
        primaryWallSpanMM =
            max(
                primaryArm,
                assembly.size.width.rawValue
            )
        secondaryWallSpanMM =
            max(
                secondaryArm,
                assembly.size.depth.rawValue
            )
        depthMM =
            max(
                definition.depthMM,
                assembly.size.depth.rawValue
            )
        frontOpeningMM =
            min(
                max(
                    definition.frontWidthMM,
                    200
                ),
                primaryWallSpanMM
            )
        deadZoneMM =
            max(
                definition.deadSpaceMM,
                0
            )
        frontAngleDegrees =
            definition.frontAngleDegrees
        shelfCount =
            definition.shelfCount
        accessTechnology =
            definition.effectiveAccessTechnology
        fillerKind =
            definition.effectiveFillerKind
        fillerWidthMM =
            definition.effectiveFillerWidthMM
        clearHeightMM =
            definition.clearHeightMM
                ?? assembly.size.height.rawValue
        handleProjectionMM =
            definition.handleProjectionMM
                ?? 0
    }

    var technologyRule:
        CornerCabinetTechnologyRuleV086
    {
        CornerCabinetRuleBookV086
            .technologyRule(
                for: accessTechnology
            )
    }

    var requiresSecondaryWallProjection:
        Bool
    {
        secondaryWallSpanMM > 1
    }

    var primaryElevationWidthMM:
        Double
    {
        primaryWallSpanMM
    }

    var secondaryElevationWidthMM:
        Double
    {
        secondaryWallSpanMM
    }

    var shouldShowDeadZone:
        Bool
    {
        switch kind {
        case .blindCorner,
             .halfBlind:
            return deadZoneMM > 0
        case .lShaped,
             .diagonalFront:
            return false
        }
    }

    var productionNotes:
        [String]
    {
        let rule =
            technologyRule
        var notes = [
            "Moduł narożny wymaga jednej bryły 3D i dwóch projekcji elewacyjnych.",
            "Zaznaczenie dowolnej projekcji powinno wybierać ten sam moduł."
        ]

        if shouldShowDeadZone {
            notes.append(
                "W dokumentacji pokaż martwą strefę \(Int(deadZoneMM)) mm i światło otworu \(Int(frontOpeningMM)) mm."
            )
        }

        if fillerKind != .none {
            notes.append(
                "\(fillerKind.title): \(Int(fillerWidthMM)) mm. \(fillerKind.productionDescription)"
            )
        }

        if handleProjectionMM > 0 {
            notes.append(
                "Kontrola kolizji uchwytu: wystawanie \(Int(handleProjectionMM)) mm względem blendy i sąsiedniego frontu."
            )
        }

        switch accessTechnology {
        case .shelves:
            notes.append(
                "Półki stałe wymagają osobnej kontroli dojścia z obu ramion narożnika."
            )
        case .leMans:
            notes.append(
                "LeMans wymaga rezerwy na ruch półek po łuku i punktów mocowań systemu."
            )
        case .magicCorner:
            notes.append(
                "Magic Corner wymaga wydzielenia części frontowej i tylnej strefy wysuwu."
            )
        case .carousel:
            notes.append(
                "Karuzela wymaga osi obrotu oraz kontroli promienia półek."
            )
        case .cornerDrawers:
            notes.append(
                "Szuflady narożne wymagają skośnych frontów i kolizji prowadnic po obu stronach."
            )
        }

        if let load =
            rule.loadCapacityPerLevelKG {
            notes.append(
                "Nośność referencyjna: \(Int(load)) kg na poziom/tacę, do potwierdzenia z kartą producenta."
            )
        }

        if let load =
            rule.totalLoadCapacityKG {
            notes.append(
                "Nośność całkowita referencyjna: \(Int(load)) kg, do potwierdzenia z kartą producenta."
            )
        }

        if rule.requiresMotionEnvelopeCheck {
            notes.append(
                "Wymagana koperta ruchu mechanizmu w rzucie 2D, elewacji i widoku 3D."
            )
        }

        if rule.requiresOpeningAngleLimiter {
            notes.append(
                "Wymagany ogranicznik kąta otwarcia frontu chroniący sąsiednie fronty."
            )
        }

        if rule.requiresManufacturerTemplate {
            notes.append(
                "Przed produkcją potwierdź wariant z aktualną tabelą producenta i przenieś linie wierceń do karty technicznej."
            )
        }

        notes.append(
            contentsOf:
                rule.notes
        )
        notes.append(
            contentsOf:
                ruleValidationMessages
        )

        return notes
    }

    var ruleValidationMessages:
        [String]
    {
        let rule =
            technologyRule
        var messages: [String] = []

        if !rule.isCompatible(
            with: kind
        ) {
            messages.append(
                "Błąd reguł: \(accessTechnology.title) nie pasuje do typu \(kind.title)."
            )
        }

        if frontOpeningMM < rule.minimumFrontOpeningMM {
            messages.append(
                "Błąd reguł: światło frontu \(Int(frontOpeningMM)) mm < \(Int(rule.minimumFrontOpeningMM)) mm."
            )
        }

        if depthMM < rule.minimumInternalDepthMM {
            messages.append(
                "Błąd reguł: głębokość \(Int(depthMM)) mm < \(Int(rule.minimumInternalDepthMM)) mm."
            )
        }

        if primaryWallSpanMM < rule.minimumPrimarySpanMM {
            messages.append(
                "Błąd reguł: ramię główne \(Int(primaryWallSpanMM)) mm < \(Int(rule.minimumPrimarySpanMM)) mm."
            )
        }

        if secondaryWallSpanMM < rule.minimumSecondarySpanMM {
            messages.append(
                "Błąd reguł: ramię pomocnicze \(Int(secondaryWallSpanMM)) mm < \(Int(rule.minimumSecondarySpanMM)) mm."
            )
        }

        if fillerKind == .none,
           rule.minimumFillerWidthMM > 0 {
            messages.append(
                "Błąd reguł: brak blendy/luzu technologicznego dla \(accessTechnology.title)."
            )
        }

        if fillerKind != .none,
           fillerWidthMM < rule.minimumFillerWidthMM {
            messages.append(
                "Błąd reguł: blenda \(Int(fillerWidthMM)) mm < \(Int(rule.minimumFillerWidthMM)) mm."
            )
        }

        if let minimumClearHeight =
            rule.minimumClearHeightMM,
           clearHeightMM < minimumClearHeight {
            messages.append(
                "Błąd reguł: światło wysokości \(Int(clearHeightMM)) mm < \(Int(minimumClearHeight)) mm."
            )
        }

        if let maximumClearHeight =
            rule.maximumClearHeightMM,
           clearHeightMM > maximumClearHeight {
            messages.append(
                "Błąd reguł: światło wysokości \(Int(clearHeightMM)) mm > \(Int(maximumClearHeight)) mm."
            )
        }

        return messages
    }
}

extension CornerCabinetDefinitionV025 {
    func footprint(
        for assembly:
            FurnitureAssembly
    ) -> CornerCabinetFootprintV085 {
        CornerCabinetFootprintV085(
            definition: self,
            assembly: assembly
        )
    }
}
