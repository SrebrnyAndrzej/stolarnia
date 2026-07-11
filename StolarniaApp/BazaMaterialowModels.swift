import Foundation

enum TypMaterialuStolarskiego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case plytaLaminowana
    case mdf
    case hdf
    case sklejka
    case front
    case blatLaminowany
    case blatKompaktowy
    case blatKamienny
    case obrzeze
    case szklo
    case profil
    case systemSzuflady
    case okucie
    case akcesoriumMeblowe
    case inne

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .plytaLaminowana:
            return "Płyta laminowana"
        case .mdf:
            return "MDF"
        case .hdf:
            return "HDF"
        case .sklejka:
            return "Sklejka"
        case .front:
            return "Front"
        case .blatLaminowany:
            return "Blat laminowany"
        case .blatKompaktowy:
            return "Blat kompaktowy"
        case .blatKamienny:
            return "Blat kamienny"
        case .obrzeze:
            return "Obrzeże"
        case .szklo:
            return "Szkło"
        case .profil:
            return "Profil"
        case .systemSzuflady:
            return "System szuflady"
        case .okucie:
            return "Okucie"
        case .akcesoriumMeblowe:
            return "Akcesorium meblowe"
        case .inne:
            return "Inne"
        }
    }
}

enum JednostkaCenyMaterialu:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case sztuka
    case metrKwadratowy
    case metrBiezacy
    case kilogram
    case komplet
    case para
    case zestawDwochMetrow

    var id: String { rawValue }

    var skrot: String {
        switch self {
        case .sztuka:
            return "szt."
        case .metrKwadratowy:
            return "m²"
        case .metrBiezacy:
            return "mb"
        case .kilogram:
            return "kg"
        case .komplet:
            return "kpl."
        case .para:
            return "para"
        case .zestawDwochMetrow:
            return "kpl. 2 m"
        }
    }
}

struct MaterialStolarski:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var kod: String
    var nazwa: String
    var producent: String
    var dostawca: String
    var typ:
        TypMaterialuStolarskiego
    var dekor: String
    var gruboscMM: Double
    var szerokoscArkuszaMM: Double
    var wysokoscArkuszaMM: Double
    var jednostka:
        JednostkaCenyMaterialu
    var cenaNetto: Double
    var vatProcent: Double
    var rabatProcent: Double
    var aktywny = true
    var kierunekDekoru = false
    var kolorHEX: String
    var notatki: String
    var dataAktualizacji = Date()

    // Pola opcjonalne zachowują zgodność z rekordami zapisanymi przed v0.51.0.
    var profilAkcesoriumID: String?
    var kolekcja: String?
    var kodProducenta: String?
    var struktura: String?
    var grupaDekoru: String?
    var miniaturaNazwaZasobu: String?

    // Identyfikator grupy reprezentatywnej w CennikRynkowyPlyt.
    // Pole opcjonalne zachowuje zgodność ze starszymi rekordami.
    var cenaReferencyjnaPlytyID: String?

    var jestPozycjaKatalogowa: Bool {
        profilAkcesoriumID != nil
        || kolekcja != nil
        || kodProducenta != nil
    }

    var cenaPoRabacieNetto: Double {
        cenaNetto
        * (
            1
            - max(
                min(
                    rabatProcent,
                    100
                ),
                0
            ) / 100
        )
    }

    var cenaBrutto: Double {
        cenaPoRabacieNetto
        * (
            1
            + max(
                vatProcent,
                0
            ) / 100
        )
    }

    var powierzchniaArkuszaM2:
        Double?
    {
        guard
            szerokoscArkuszaMM > 0,
            wysokoscArkuszaMM > 0
        else {
            return nil
        }

        return (
            szerokoscArkuszaMM
            * wysokoscArkuszaMM
        ) / 1_000_000
    }

    var cenaZaM2Netto:
        Double?
    {
        guard
            jednostka == .sztuka,
            let powierzchniaArkuszaM2,
            powierzchniaArkuszaM2 > 0
        else {
            return jednostka
                == .metrKwadratowy
                ? cenaPoRabacieNetto
                : nil
        }

        return cenaPoRabacieNetto
            / powierzchniaArkuszaM2
    }
}

struct ImportMaterialowRaport:
    Hashable
{
    var dodane = 0
    var zaktualizowane = 0
    var pominiete = 0
    var bledy: [String] = []

    var komunikat: String {
        """
        Dodane: \(dodane)
        Zaktualizowane: \(zaktualizowane)
        Pominięte: \(pominiete)
        Błędy: \(bledy.count)
        """
    }
}
