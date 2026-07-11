import Foundation

// MARK: - Snapshot systemu szuflad

/// Migawka systemu szuflad wybranego z bazy materiałowej.
/// Przechowuje tylko dane identyfikacyjne — rzeczywiste parametry
/// techniczne są w BazaMaterialow (TypMaterialuStolarskiego.systemSzuflady).
struct SystemSzufladMigawka:
    Codable,
    Hashable
{
    var kod: String
    var nazwa: String
    var producent: String
    var seria: String          // np. "Tandembox", "Legrabox", "ArciTech"

    static let brakSystemu = Self(
        kod: "",
        nazwa: "Brak systemu",
        producent: "",
        seria: ""
    )

    var jestWybrany: Bool {
        !kod.isEmpty
    }

    init(
        kod: String,
        nazwa: String,
        producent: String,
        seria: String = ""
    ) {
        self.kod = kod
        self.nazwa = nazwa
        self.producent = producent
        self.seria = seria.isEmpty
            ? Self.extractSeria(from: nazwa)
            : seria
    }

    init(material: MaterialStolarski) {
        self.init(
            kod: material.kodProducenta ?? material.kod,
            nazwa: material.nazwa,
            producent: material.producent,
            seria: ""
        )
    }

    private static func extractSeria(
        from nazwa: String
    ) -> String {
        // Próbuje wyciągnąć markową serię z nazwy
        let znane = [
            "Tandembox", "Legrabox", "Intivo",
            "ArciTech", "Movento", "Tip-On",
            "Slido", "Push-Open"
        ]
        for s in znane where nazwa.contains(s) {
            return s
        }
        return ""
    }
}

// MARK: - Globalny kolor / wykończenie

/// Rozszerzenie MigawkaMaterialuGlobalnego o dodatkowe dane wyświetlane
/// w panelu globalnych materiałów projektu.
extension MigawkaMaterialuGlobalnego {
    var opisSkrocony: String {
        producent.isEmpty
            ? nazwa
            : "\(producent) — \(nazwa)"
    }

    var kolorSwiftUI: some Hashable {
        kolorHEX
    }
}

// MARK: - Model projektu

/// Globalne materiały projektu — wspólne domyślne wykończenia dla całego projektu.
///
/// Różnica wobec `GlobalneMaterialyPomieszczenia` (zakres: pomieszczenie):
/// tu zakres to projekt — wartości domyślne dla nowo dodawanych mebli,
/// kopiowane do materiałów konkretnego pomieszczenia lub modułu.
struct GlobalneMaterialyProjektu:
    Codable,
    Hashable
{
    var projectID: String
    var korpus: MigawkaMaterialuGlobalnego
    var front: MigawkaMaterialuGlobalnego
    var systemSzuflad: SystemSzufladMigawka
    var dataAktualizacji: Date

    // MARK: Dodatkowe opcje projektu

    /// Grubość płyty korpusowej w mm (domyślnie 18 mm)
    var gruboscKorpusuMM: Double

    /// Grubość płyty frontowej / drzwi w mm (domyślnie 18 mm)
    var gruboscFrontuMM: Double

    /// Preferowany system zawiasów dla frontów uchylnych
    var systemZawiasow: SystemZawiasow

    /// Preferowany typ uchwytu
    var typUchwytu: TypUchwytuwProjekcie

    static func domyslne(
        projectID: String
    ) -> Self {
        Self(
            projectID: projectID,
            korpus: .domyslnyKorpus,
            front: .domyslnyFront,
            systemSzuflad: .brakSystemu,
            dataAktualizacji: Date(),
            gruboscKorpusuMM: 18,
            gruboscFrontuMM: 18,
            systemZawiasow: .blum,
            typUchwytu: .bar
        )
    }
}

// MARK: - Pomocnicze enumy projektu

enum SystemZawiasow:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case blum
    case hettich
    case hafele
    case grass
    case inny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .blum:    return "Blum"
        case .hettich: return "Hettich"
        case .hafele:  return "Häfele"
        case .grass:   return "Grass"
        case .inny:    return "Inny"
        }
    }
}

enum TypUchwytuwProjekcie:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case bar
    case grebykNasadzany
    case grebykWbudowany
    case knob
    case bezUchwytu
    case inny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .bar:               return "Rączka listwowa"
        case .grebykNasadzany:   return "Grzybek nasadzany"
        case .grebykWbudowany:   return "Grzybek wpuszczany"
        case .knob:              return "Gałka"
        case .bezUchwytu:        return "Bez uchwytu (push)"
        case .inny:              return "Inny"
        }
    }

    var systemImage: String {
        switch self {
        case .bar, .grebykNasadzany, .grebykWbudowany, .knob:
            return "rectangle.and.hand.point.up.left.fill"
        case .bezUchwytu:
            return "hand.tap"
        case .inny:
            return "questionmark.circle"
        }
    }
}
