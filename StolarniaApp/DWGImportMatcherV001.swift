import DomainCore
import Foundation

/// Wynik dopasowania jednego wykrytego mebla z DWG do biblioteki szablonów aplikacji.
/// `suggestedTemplate == nil` oznacza brak dopasowania — użytkownik wybiera ręcznie w UI podglądu.
struct DWGModuleMatchV001: Identifiable, Sendable {
    var id: String
    var detected: DWGDetectedFurnitureItemV001
    var suggestedTemplate: FurnitureTemplate?
    var score: Double
    var reason: String
    var targetWidth: Millimeters
    var targetHeight: Millimeters
    var targetDepth: Millimeters
    var anchoringMode: FurnitureAnchoringMode
    var requiresReview: Bool

    /// Sugerowana domyślna wartość zaznaczenia w UI.
    var domyslnieZaznaczone: Bool {
        score >= 0.80 && !requiresReview
    }
}

/// Progi decyzyjne — jednolita klasyfikacja rekomendacji importu.
enum DWGImportMatchQualityV001 {
    static let autoAcceptThreshold: Double = 0.80
    static let reviewThreshold: Double = 0.55

    static func status(for score: Double) -> Status {
        if score >= autoAcceptThreshold { return .autoAccept }
        if score >= reviewThreshold { return .review }
        return .noMatch
    }

    enum Status {
        case autoAccept
        case review
        case noMatch

        var czytelnaNazwa: String {
            switch self {
            case .autoAccept: return "Gotowe do importu"
            case .review: return "Do sprawdzenia"
            case .noMatch: return "Bez dopasowania"
            }
        }
    }
}

enum DWGImportMatcherV001 {
    /// Główny punkt wejścia. Dopasowuje każdą pozycję z importu do najlepszego
    /// szablonu z aktualnie dostępnej biblioteki.
    static func dopasuj(
        document: DWGImportDocumentV001,
        dostepneTemplates templates: [FurnitureTemplate]
    ) -> [DWGModuleMatchV001] {
        document.detectedItems.map { item in
            dopasujPojedynczy(
                item: item,
                unit: document.unit,
                dostepneTemplates: templates
            )
        }
    }

    // MARK: - Pojedyncze dopasowanie

    private static func dopasujPojedynczy(
        item: DWGDetectedFurnitureItemV001,
        unit: DWGImportUnitV001,
        dostepneTemplates templates: [FurnitureTemplate]
    ) -> DWGModuleMatchV001 {
        let targetWidth = DWGImportUnitConverterV001.mm(item.footprint.width, unit: unit)
        let targetDepth = DWGImportUnitConverterV001.mm(item.footprint.depth, unit: unit)
        let targetHeight = domyslnaWysokosc(dla: item.kind)
        let anchoringMode = domyslnyAnchor(dla: item.kind)

        var bestScore: Double = 0
        var bestTemplate: FurnitureTemplate?
        var bestReason: String = "Brak dopasowania w bibliotece."

        for template in templates {
            let (score, reason) = obliczScore(
                template: template,
                item: item,
                targetWidth: targetWidth,
                targetDepth: targetDepth
            )
            if score > bestScore {
                bestScore = score
                bestTemplate = template
                bestReason = reason
            }
        }

        let status = DWGImportMatchQualityV001.status(for: bestScore)
        let requiresReview = status != .autoAccept

        return DWGModuleMatchV001(
            id: item.id,
            detected: item,
            suggestedTemplate: status == .noMatch ? nil : bestTemplate,
            score: bestScore,
            reason: bestReason,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            targetDepth: targetDepth,
            anchoringMode: anchoringMode,
            requiresReview: requiresReview
        )
    }

    // MARK: - Scoring

    private static func obliczScore(
        template: FurnitureTemplate,
        item: DWGDetectedFurnitureItemV001,
        targetWidth: Millimeters,
        targetDepth: Millimeters
    ) -> (score: Double, reason: String) {
        let scoreNazwa = scoreNazwa(template: template, item: item)
        let scoreWymiar = scoreWymiar(
            template: template,
            targetWidth: targetWidth,
            targetDepth: targetDepth
        )
        let scoreKategoria = scoreKategoria(template: template, kind: item.kind)
        let scoreOtoczenie: Double = 0.05

        let total = scoreNazwa * 0.35
            + scoreWymiar * 0.40
            + scoreKategoria * 0.15
            + scoreOtoczenie * 0.10

        let reason = powodDopasowania(
            template: template,
            item: item,
            nazwa: scoreNazwa,
            wymiar: scoreWymiar,
            kategoria: scoreKategoria
        )

        return (total, reason)
    }

    private static func scoreNazwa(
        template: FurnitureTemplate,
        item: DWGDetectedFurnitureItemV001
    ) -> Double {
        let raw = (item.rawName ?? "").lowercased()
        let name = template.name.lowercased()
        let code = template.code.lowercased()

        // Konkretne słowa-klucze mające najsilniejsze mapowanie do konkretnych typów.
        let slowaAGD: [(String, String)] = [
            ("lodowka", "refrigerator"),
            ("lodówka", "refrigerator"),
            ("fridge", "refrigerator"),
            ("refrigerator", "refrigerator"),
            ("piekarnik", "oven"),
            ("oven", "oven"),
            ("plyta", "cooktop"),
            ("płyta", "cooktop"),
            ("cooktop", "cooktop"),
            ("bora", "cooktop"),
            ("zmywarka", "dishwasher"),
            ("dishwasher", "dishwasher"),
            ("zlew", "sink"),
            ("sink", "sink"),
            ("wyspa", "island"),
            ("island", "island")
        ]

        for (rawKeyword, templateKeyword) in slowaAGD where raw.contains(rawKeyword) {
            if name.contains(templateKeyword) || code.contains(templateKeyword) {
                return 1.0
            }
        }

        // Ogólny fallback — częściowe pokrycie stringów.
        if !raw.isEmpty {
            if name.contains(raw) || code.contains(raw) {
                return 0.7
            }
        }
        return 0
    }

    private static func scoreWymiar(
        template: FurnitureTemplate,
        targetWidth: Millimeters,
        targetDepth: Millimeters
    ) -> Double {
        guard let templateWidth = wymiarSzablonu(template, key: .width) else {
            return 0.3
        }
        let widthDiffMM = abs(templateWidth.rawValue - targetWidth.rawValue)

        // Tolerancja 30mm = pełny wynik, powyżej 300mm = 0.
        if widthDiffMM <= 30 { return 1.0 }
        if widthDiffMM >= 300 { return 0 }
        return 1.0 - (widthDiffMM - 30) / 270
    }

    private static func scoreKategoria(
        template: FurnitureTemplate,
        kind: DWGDetectedFurnitureKindV001
    ) -> Double {
        switch (kind, template.category) {
        case (.baseCabinetRun, .kitchenBaseCabinet),
             (.sink, .kitchenBaseCabinet),
             (.cooktop, .kitchenBaseCabinet),
             (.dishwasher, .kitchenBaseCabinet),
             (.oven, .kitchenBaseCabinet):
            return 1.0
        case (.tallCabinetRun, .kitchenTallCabinet),
             (.refrigerator, .kitchenTallCabinet),
             (.oven, .kitchenTallCabinet):
            return 1.0
        case (.island, .kitchenBaseCabinet):
            return 0.7
        default:
            return 0.2
        }
    }

    private static func powodDopasowania(
        template: FurnitureTemplate,
        item: DWGDetectedFurnitureItemV001,
        nazwa: Double,
        wymiar: Double,
        kategoria: Double
    ) -> String {
        var powody: [String] = []
        if nazwa >= 0.9 {
            powody.append("nazwa DWG (\(item.rawName ?? "-")) pasuje do szablonu")
        }
        if wymiar >= 0.85 {
            powody.append("wymiar zbieżny ±30 mm")
        }
        if kategoria >= 0.9 {
            powody.append("kategoria dopasowana (\(template.category.rawValue))")
        }
        if powody.isEmpty {
            return "Częściowe dopasowanie do szablonu \(template.name)."
        }
        return powody.joined(separator: " • ")
    }

    // MARK: - Pomocnicze

    private static func wymiarSzablonu(
        _ template: FurnitureTemplate,
        key: FurnitureParameterKey
    ) -> Millimeters? {
        for entry in template.defaultParameters.entries where entry.key == key {
            if case .millimeters(let value) = entry.value {
                return value
            }
        }
        return nil
    }

    private static func domyslnaWysokosc(dla kind: DWGDetectedFurnitureKindV001) -> Millimeters {
        switch kind {
        case .baseCabinetRun, .cooktop, .sink, .dishwasher:
            return 720
        case .oven:
            return 720
        case .tallCabinetRun, .refrigerator:
            return 2200
        case .island:
            return 900
        case .stoolOrSeating:
            return 450
        case .unknownFurniture:
            return 720
        }
    }

    private static func domyslnyAnchor(dla kind: DWGDetectedFurnitureKindV001) -> FurnitureAnchoringMode {
        switch kind {
        case .island, .stoolOrSeating:
            return .freestanding
        case .refrigerator, .dishwasher, .oven, .cooktop:
            return .builtIn
        default:
            return .floorStanding
        }
    }
}
