import Foundation

enum TypFrontuSzuflady:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case zewnetrzny
    case wewnetrzny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .zewnetrzny:
            return "Front zewnętrzny"
        case .wewnetrzny:
            return "Szuflada wewnętrzna"
        }
    }
}

struct SzufladaModulu:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var etykieta = ""
    var nazwa = ""
    var profilID = ""
    var typFrontu:
        TypFrontuSzuflady =
            .zewnetrzny

    /// Cofnięcie płaszczyzny frontu szuflady względem frontu zewnętrznego.
    /// `nil` zachowuje zgodność ze starszymi kartami i pozwala engine'owi
    /// wyliczyć wartość z technologii.
    var cofniecieOdFrontuMM:
        Double? = nil

    /// Wysokość dolnej krawędzi frontu względem wewnętrznego dna korpusu.
    var pozycjaDolnaYMM = 0.0
    var wysokoscFrontuMM = 140.0
    var wysokoscSkrzynkiMM = 120.0
    var nominalnaDlugoscMM = 450.0
    var luzDolnyMM = 2.5
    var luzGornyMM = 2.5
    var aktywna = true

    var gornaKrawedzYMM:
        Double
    {
        pozycjaDolnaYMM
        + wysokoscFrontuMM
    }

    var wysokoscZajetaMM:
        Double
    {
        wysokoscFrontuMM
        + luzDolnyMM
        + luzGornyMM
    }

    var efektywneCofniecieOdFrontuMM:
        Double
    {
        max(
            cofniecieOdFrontuMM ?? 0,
            0
        )
    }
}

enum TypKolizjiSzuflady:
    String,
    Codable,
    Hashable
{
    case nakladanieSzuflad
    case pozaKorpusem
    case polka
    case glebokosc
    case wysokoscSkrzynki
    case szerokosc
    case zawias
    case liczba
    case brakProfilu
}

enum PoziomKolizjiSzuflady:
    String,
    Codable,
    Hashable
{
    case informacja
    case ostrzezenie
    case blad
}

struct KolizjaSzuflady:
    Identifiable,
    Hashable
{
    let id = UUID()
    var typ:
        TypKolizjiSzuflady
    var poziom:
        PoziomKolizjiSzuflady
    var etykietaSzuflady = ""
    var komunikat = ""
    var etykietaElementuKolizyjnego:
        String?
}

struct ParametryAutomatycznegoUkladuSzuflad:
    Hashable
{
    var liczba = 3
    var wysokoscFrontuMM = 180.0
    var wysokoscSkrzynkiMM = 120.0
    var nominalnaDlugoscMM = 450.0
    var szczelinaMiedzyFrontamiMM = 3.0
    var marginesDolnyMM = 3.0
    var marginesGornyMM = 3.0
    var typFrontu:
        TypFrontuSzuflady =
            .zewnetrzny
    var profilID = ""
}

struct GeometriaWnetrzaSzafki:
    Hashable
{
    var szerokoscMM: Double
    var wysokoscMM: Double
    var glebokoscMM: Double
    var gruboscBokuMM: Double
    var gruboscDnaMM: Double
    var gruboscGoryMM: Double
    var gruboscPlecowMM: Double
}
