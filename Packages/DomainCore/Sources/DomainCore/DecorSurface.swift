import Foundation

/// Opis powierzchni dekoru sterujący wizualizacją proceduralną.
///
/// Research 2026-08-26 (katalogi EGGER i Kronospan, karty dekorów).
///
/// **Sedno: wygląd powierzchni opisuje kod struktury, nie nazwa dekoru.**
/// Renderer 3D dobierał dotąd materiał, dopasowując napisy w nazwie („dab",
/// „oak", „orzech", „polysk"). To działa dla „Dąb Halifax", ale nie dla `H1176`,
/// `K358` czy „Silk Flow" — a producenci nazywają dekory właśnie tak. Kod
/// struktury jest przy dekorze zawsze i znaczy dokładnie to, co trzeba wiedzieć
/// do renderu: poziom połysku, głębokość wytłoczenia i czy por jest
/// zsynchronizowany z nadrukiem.
///
/// Znaczenia kodów pochodzą z opisów producentów:
/// - `ST9` Smoothtouch Matt — neutralna, aksamitnie matowa; uni, drewno, materiał;
/// - `ST10` Deepskin Rough — wyraźnie szorstka, ale powściągliwa, jednolicie matowa;
/// - `ST19` Deepskin Excellent — łączy pola matowe i błyszczące, przez co usłojenie
///   „żyje" nawet na jasnych dekorach;
/// - `ST37` Feelwood Rift / `ST38` Feelwood Conifer — **por zsynchronizowany
///   z nadrukiem**, czyli wytłoczenie pokrywa się z rysunkiem słojów; ST38
///   dokłada perłowy efekt mat/połysk;
/// - `PW` Pure Wood (Kronospan) — struktura drewna do dekorów drewnopodobnych;
/// - `RT`, `SM`, `SU`, `BS`, `PE` — pozostałe struktury Kronospanu.
public struct DecorSurface: Hashable, Sendable, Codable {

    /// Rodzina dekoru — decyduje, jaki wzór rysować.
    public enum Family: String, Codable, Hashable, Sendable, CaseIterable {
        case uni
        case wood
        case stone
        case concrete
        case fabric

        public var displayName: String {
            switch self {
            case .uni:      return "Jednolity"
            case .wood:     return "Drewnopodobny"
            case .stone:    return "Kamień"
            case .concrete: return "Beton"
            case .fabric:   return "Tkanina"
            }
        }
    }

    public var structureCode: String
    public var family: Family
    /// 0 = głęboki mat, 1 = wysoki połysk.
    public var glossLevel: Double
    /// 0 = gładka, 1 = mocno wytłoczona.
    public var embossDepth: Double
    /// Czy wytłoczenie pokrywa się z rysunkiem nadruku (Feelwood, Pure Wood).
    /// Por zsynchronizowany to najbardziej kosztotwórcza cecha struktury i to
    /// ona sprawia, że płyta wygląda jak lite drewno.
    public var synchronisedPore: Bool
    /// Jak mocno usłojenie odcina się od tła. Struktury łączące mat i połysk
    /// (`ST19`, `ST38`) mają je wyraźnie wyższe.
    public var grainContrast: Double
    public var displayName: String

    public init(
        structureCode: String,
        family: Family,
        glossLevel: Double,
        embossDepth: Double,
        synchronisedPore: Bool,
        grainContrast: Double,
        displayName: String
    ) {
        self.structureCode = structureCode
        self.family = family
        self.glossLevel = glossLevel
        self.embossDepth = embossDepth
        self.synchronisedPore = synchronisedPore
        self.grainContrast = grainContrast
        self.displayName = displayName
    }
}

public enum DecorSurfaceCatalog {

    /// Struktury opisane przez producentów.
    ///
    /// `family` jest tu **domyślna dla struktury** — ostateczną rodzinę ustala
    /// grupa dekoru (`resolve(structureCode:group:)`), bo np. `ST9` występuje
    /// zarówno na dekorach uni, jak i drewnopodobnych.
    public static let byStructure: [String: DecorSurface] = [
        "ST9":  DecorSurface(structureCode: "ST9", family: .uni,
                             glossLevel: 0.06, embossDepth: 0.10,
                             synchronisedPore: false, grainContrast: 0.30,
                             displayName: "Smoothtouch Matt"),
        "ST10": DecorSurface(structureCode: "ST10", family: .wood,
                             glossLevel: 0.05, embossDepth: 0.55,
                             synchronisedPore: false, grainContrast: 0.45,
                             displayName: "Deepskin Rough"),
        "ST19": DecorSurface(structureCode: "ST19", family: .wood,
                             glossLevel: 0.22, embossDepth: 0.45,
                             synchronisedPore: false, grainContrast: 0.72,
                             displayName: "Deepskin Excellent"),
        "ST37": DecorSurface(structureCode: "ST37", family: .wood,
                             glossLevel: 0.10, embossDepth: 0.80,
                             synchronisedPore: true, grainContrast: 0.65,
                             displayName: "Feelwood Rift"),
        "ST38": DecorSurface(structureCode: "ST38", family: .wood,
                             glossLevel: 0.20, embossDepth: 0.78,
                             synchronisedPore: true, grainContrast: 0.70,
                             displayName: "Feelwood Conifer"),
        "ST40": DecorSurface(structureCode: "ST40", family: .wood,
                             glossLevel: 0.12, embossDepth: 0.75,
                             synchronisedPore: true, grainContrast: 0.62,
                             displayName: "Feelwood Nature"),
        "ST7":  DecorSurface(structureCode: "ST7", family: .uni,
                             glossLevel: 0.10, embossDepth: 0.22,
                             synchronisedPore: false, grainContrast: 0.28,
                             displayName: "Smoothtouch Woodpore"),
        "PW":   DecorSurface(structureCode: "PW", family: .wood,
                             glossLevel: 0.09, embossDepth: 0.62,
                             synchronisedPore: true, grainContrast: 0.58,
                             displayName: "Pure Wood"),
        "RT":   DecorSurface(structureCode: "RT", family: .concrete,
                             glossLevel: 0.08, embossDepth: 0.35,
                             synchronisedPore: false, grainContrast: 0.25,
                             displayName: "Rough Touch"),
        "SM":   DecorSurface(structureCode: "SM", family: .uni,
                             glossLevel: 0.04, embossDepth: 0.06,
                             synchronisedPore: false, grainContrast: 0.15,
                             displayName: "Super Matt"),
        "SU":   DecorSurface(structureCode: "SU", family: .uni,
                             glossLevel: 0.55, embossDepth: 0.05,
                             synchronisedPore: false, grainContrast: 0.18,
                             displayName: "Supreme"),
        "BS":   DecorSurface(structureCode: "BS", family: .uni,
                             glossLevel: 0.85, embossDepth: 0.02,
                             synchronisedPore: false, grainContrast: 0.12,
                             displayName: "Brilliant Shine"),
        "PE":   DecorSurface(structureCode: "PE", family: .stone,
                             glossLevel: 0.30, embossDepth: 0.28,
                             synchronisedPore: false, grainContrast: 0.55,
                             displayName: "Pearl"),
    ]

    /// Powierzchnia dla dekoru: struktura daje parametry, grupa nadpisuje rodzinę.
    ///
    /// Grupa („Uni", „Drewno", „Kamień", „Materiał") jest przy dekorze w bazie
    /// materiałów i jest pewniejsza niż zgadywanie z nazwy — dlatego wygrywa
    /// z domyślną rodziną struktury.
    public static func resolve(
        structureCode: String?,
        group: String?
    ) -> DecorSurface {
        let kod = (structureCode ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        var powierzchnia = byStructure[kod] ?? fallback

        if let rodzina = family(forGroup: group) {
            powierzchnia.family = rodzina
        }
        return powierzchnia
    }

    /// Rodzina z grupy dekoru używanej w bazie materiałów.
    public static func family(forGroup group: String?) -> DecorSurface.Family? {
        // Uwaga na „ł": w Unicode to **osobna litera**, a nie „l" z diakrytykiem,
        // więc `diacriticInsensitive` jej nie składa i „Materiał" nie zamienia się
        // w „material". Trzeba ją podmienić jawnie — inaczej cała grupa dekorów
        // technicznych po cichu wpada w gałąź `default`.
        guard let g = group?
            .replacingOccurrences(of: "ł", with: "l")
            .replacingOccurrences(of: "Ł", with: "L")
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "pl_PL"))
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !g.isEmpty
        else { return nil }

        switch g {
        case "uni":       return .uni
        case "drewno":    return .wood
        case "kamien":    return .stone
        case "beton":     return .concrete
        case "tkanina":   return .fabric
        // „Materiał" to u producentów zbiorcza grupa dekorów technicznych —
        // beton, metal, tekstylia. Beton jest z nich najczęstszy w kuchniach.
        case "material":  return .concrete
        default:          return nil
        }
    }

    /// Gdy struktura jest nieznana albo pusta — neutralny mat, nie połysk.
    /// Płyta matowa wygląda źle jako błyszcząca dużo bardziej niż odwrotnie.
    public static let fallback = DecorSurface(
        structureCode: "",
        family: .uni,
        glossLevel: 0.08,
        embossDepth: 0.12,
        synchronisedPore: false,
        grainContrast: 0.30,
        displayName: "Struktura nieokreślona")
}
