import DomainCore
import Foundation

/// Jednostka wymiarowa neutralnego formatu importu DWG.
/// Konwerter poza aplikacją decyduje, w jakich jednostkach są footprinty.
enum DWGImportUnitV001: String, Codable, Sendable {
    case millimeters
    case centimeters
    case meters
    case unknown

    /// Domyślnie centymetry — najczęstsza jednostka w polskich projektach architektonicznych.
    static let defaultFallback: DWGImportUnitV001 = .centimeters
}

/// Sklasyfikowany typ mebla/AGD wykrytego przez zewnętrzny parser DWG.
enum DWGDetectedFurnitureKindV001: String, Codable, Sendable {
    case baseCabinetRun
    case tallCabinetRun
    case island
    case refrigerator
    case oven
    case cooktop
    case dishwasher
    case sink
    case stoolOrSeating
    case unknownFurniture

    var czytelnaNazwa: String {
        switch self {
        case .baseCabinetRun: return "Ciąg szafek dolnych"
        case .tallCabinetRun: return "Wysoka zabudowa"
        case .island: return "Wyspa"
        case .refrigerator: return "Lodówka"
        case .oven: return "Piekarnik"
        case .cooktop: return "Płyta grzewcza"
        case .dishwasher: return "Zmywarka"
        case .sink: return "Zlew"
        case .stoolOrSeating: return "Siedzisko"
        case .unknownFurniture: return "Nieznany mebel"
        }
    }

    var systemImage: String {
        switch self {
        case .baseCabinetRun: return "rectangle.split.3x1"
        case .tallCabinetRun: return "rectangle.portrait"
        case .island: return "square.dashed"
        case .refrigerator: return "refrigerator"
        case .oven: return "oven"
        case .cooktop: return "flame"
        case .dishwasher: return "dishwasher"
        case .sink: return "drop"
        case .stoolOrSeating: return "chair.lounge"
        case .unknownFurniture: return "questionmark.square"
        }
    }
}

struct DWGImportPointV001: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}

/// Prostokątny footprint mebla wykrytego w DWG. `x`, `y` w układzie źródłowym
/// (nieznormalizowanym), `width`, `depth` w jednostce dokumentu.
struct DWGImportRectV001: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var depth: Double
    var rotationDegrees: Double
}

struct DWGDetectedFurnitureItemV001: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var sourceHandle: String
    var sourceBlock: String
    var layer: String
    var rawName: String?
    var kind: DWGDetectedFurnitureKindV001
    var footprint: DWGImportRectV001
    var estimatedModuleCount: Int
    var confidence: Double
}

/// Dokument importu — cała jednostka pracy dla jednego pliku DWG.
struct DWGImportDocumentV001: Codable, Sendable {
    var sourceFileName: String
    var unit: DWGImportUnitV001
    var detectedItems: [DWGDetectedFurnitureItemV001]

    /// Znormalizowany bounding box wszystkich elementów — używany do
    /// przesunięcia całego układu do (0, 0) i doboru skali podglądu.
    var boundingBox: (minX: Double, minY: Double, maxX: Double, maxY: Double)? {
        guard let first = detectedItems.first else { return nil }
        var minX = first.footprint.x
        var minY = first.footprint.y
        var maxX = first.footprint.x + first.footprint.width
        var maxY = first.footprint.y + first.footprint.depth
        for item in detectedItems.dropFirst() {
            let r = item.footprint
            minX = min(minX, r.x)
            minY = min(minY, r.y)
            maxX = max(maxX, r.x + r.width)
            maxY = max(maxY, r.y + r.depth)
        }
        return (minX, minY, maxX, maxY)
    }
}

/// Konwersja jednostki dokumentu do milimetrów domenowych.
/// Używana w matcherze i mapperze — parser trzyma wartości surowe.
enum DWGImportUnitConverterV001 {
    static func mm(_ value: Double, unit: DWGImportUnitV001) -> Millimeters {
        switch unit {
        case .millimeters:
            return Millimeters(value)
        case .centimeters:
            return Millimeters(value * 10)
        case .meters:
            return Millimeters(value * 1000)
        case .unknown:
            // Domyślnie centymetry — user może zmienić skalę w UI podglądu.
            return Millimeters(value * 10)
        }
    }
}
