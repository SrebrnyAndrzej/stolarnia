import Foundation

enum StronaRzeduSystemu32:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case przedni
    case tylny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .przedni:
            return "Rząd przedni"
        case .tylny:
            return "Rząd tylny"
        }
    }

    var kod: String {
        switch self {
        case .przedni:
            return "P"
        case .tylny:
            return "T"
        }
    }
}

enum TrybKompensacjiObrzezaSystemu32:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case brak
    case dodajDoOdsuniecia
    case odejmijOdOdsuniecia

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .brak:
            return "Bez kompensacji"
        case .dodajDoOdsuniecia:
            return "Dodaj grubość obrzeża"
        case .odejmijOdOdsuniecia:
            return "Odejmij grubość obrzeża"
        }
    }
}

struct ParametrySystemu32:
    Codable,
    Hashable
{
    var aktywny = true

    var generujRzadPrzedni = true
    var generujRzadTylny = true

    var odsunOdPrzoduMM = 37.0
    var odsunOdTyluMM = 37.0
    var skokMM = 32.0
    var srednicaMM = 5.0
    var glebokoscMM = 12.0

    var poczatekYMM = 96.0
    var koniecOdGoryMM = 96.0

    var gruboscObrzezaPrzodMM = 0.0
    var gruboscObrzezaTylMM = 0.0
    var kompensacjaObrzeza:
        TrybKompensacjiObrzezaSystemu32 =
            .brak

    var lustrzaneOdbiciePrawegoBoku = true

    /// Indeksy otworów liczone od zera w danym rzędzie.
    var pominieteIndeksyPrzednie:
        Set<Int> = []
    var pominieteIndeksyTylne:
        Set<Int> = []

    var efektywnyOdsunPrzodMM:
        Double
    {
        kompensowany(
            bazowy: odsunOdPrzoduMM,
            obrzeze:
                gruboscObrzezaPrzodMM
        )
    }

    var efektywnyOdsunTylMM:
        Double
    {
        kompensowany(
            bazowy: odsunOdTyluMM,
            obrzeze:
                gruboscObrzezaTylMM
        )
    }

    private func kompensowany(
        bazowy: Double,
        obrzeze: Double
    ) -> Double {
        switch kompensacjaObrzeza {
        case .brak:
            return bazowy
        case .dodajDoOdsuniecia:
            return bazowy + obrzeze
        case .odejmijOdOdsuniecia:
            return max(
                bazowy - obrzeze,
                0
            )
        }
    }
}

struct WynikWalidacjiSystemu32:
    Identifiable,
    Hashable
{
    enum Poziom:
        Hashable
    {
        case informacja
        case ostrzezenie
        case blad
    }

    let id = UUID()
    var poziom:
        Poziom
    var komunikat: String
}
