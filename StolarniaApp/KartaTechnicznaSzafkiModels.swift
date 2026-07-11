import Foundation

enum StronaElementuTechnicznego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case lewa
    case prawa
    case gora
    case dol
    case przod
    case tyl
    case wewnetrzna
    case zewnetrzna

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .lewa: return "Lewa"
        case .prawa: return "Prawa"
        case .gora: return "Góra"
        case .dol: return "Dół"
        case .przod: return "Przód"
        case .tyl: return "Tył"
        case .wewnetrzna: return "Wewnętrzna"
        case .zewnetrzna: return "Zewnętrzna"
        }
    }
}

enum TypPunktuWiercenia:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case prowadnica
    case zawias
    case podporaPolki
    case uchwyt
    case lacznik
    case kolkowanie
    case inny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .prowadnica: return "Prowadnica"
        case .zawias: return "Zawias"
        case .podporaPolki: return "Podpora półki"
        case .uchwyt: return "Uchwyt"
        case .lacznik: return "Łącznik"
        case .kolkowanie: return "Kołkowanie"
        case .inny: return "Inny"
        }
    }
}

struct PunktWierceniaSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var element = ""
    var typ:
        TypPunktuWiercenia = .inny
    var strona:
        StronaElementuTechnicznego = .wewnetrzna
    var xMM = 0.0
    var yMM = 0.0
    var srednicaMM = 5.0
    var glebokoscMM = 12.0
    var opis = ""
}

struct ZamkniecieBrylySzafki:
    Codable,
    Hashable
{
    var blendaLewa = false
    var szerokoscBlendyLewejMM = 50.0

    var blendaPrawa = false
    var szerokoscBlendyPrawejMM = 50.0

    var wieniecGorny = false
    var gruboscWiencaGornegoMM = 18.0
    var wysuniecieWiencaGornegoMM = 20.0

    var wieniecDolny = false
    var gruboscWiencaDolnegoMM = 18.0
    var wysuniecieWiencaDolnegoMM = 20.0

    var sciankaBocznaLewa = false
    var sciankaBocznaPrawa = false

    /// Domyślnie 20 mm, czyli 2 cm przed płaszczyznę frontu.
    var wysuniecieScianekPrzedFrontMM = 20.0
    var gruboscScianekMM = 18.0

    var posiadaElementyZamykajace:
        Bool
    {
        blendaLewa
        || blendaPrawa
        || wieniecGorny
        || wieniecDolny
        || sciankaBocznaLewa
        || sciankaBocznaPrawa
    }
}


enum TypElementuSzafki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case scianaBoczna = "SB"
    case dno = "DN"
    case wieniecGorny = "WG"
    case wieniecDolny = "WD"
    case polka = "PL"
    case plecy = "PC"
    case front = "FR"
    case blenda = "BL"
    case sciankaMaskujaca = "SM"
    case cokół = "CK"
    case listwa = "LS"
    case przegroda = "PR"
    case szuflada = "SZ"
    case inny = "IN"

    var id: String { rawValue }

    var kod: String { rawValue }

    var nazwa: String {
        switch self {
        case .scianaBoczna:
            return "Ściana boczna"
        case .dno:
            return "Dno"
        case .wieniecGorny:
            return "Wieniec górny"
        case .wieniecDolny:
            return "Wieniec dolny"
        case .polka:
            return "Półka"
        case .plecy:
            return "Plecy"
        case .front:
            return "Front"
        case .blenda:
            return "Blenda"
        case .sciankaMaskujaca:
            return "Ścianka maskująca"
        case .cokół:
            return "Cokół"
        case .listwa:
            return "Listwa"
        case .przegroda:
            return "Przegroda"
        case .szuflada:
            return "Szuflada"
        case .inny:
            return "Inny"
        }
    }
}

enum KierunekElementuSzafki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case pionowy
    case poziomy
    case bezZnaczenia

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .pionowy:
            return "Pionowy"
        case .poziomy:
            return "Poziomy"
        case .bezZnaczenia:
            return "Bez znaczenia"
        }
    }
}

struct ElementTechnicznySzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var etykieta = ""
    var typ:
        TypElementuSzafki = .inny
    var nazwa = ""
    var dlugoscMM = 0.0
    var szerokoscMM = 0.0
    var gruboscMM = 18.0
    var ilosc = 1
    var material = ""

    // Stabilne powiązanie z rekordem w Bazie materiałów.
    // Pole opcjonalne zachowuje odczyt starszych kart.
    var materialID: UUID? = nil

    var kierunek:
        KierunekElementuSzafki =
            .bezZnaczenia
    var uwagi = ""
    var punktyWiercenia:
        [PunktWierceniaSzafki] = []
    var parametrySystemu32:
        ParametrySystemu32?

    // v0.69.1: cut angle at the top edge when cabinet is under a slope.
    // Nil means the element is rectangular (no slope cut required).
    var katCieciaGornejKrawedziStopnieV0691: Double? = nil

    // For fronts/backs under a slope the outline is non-rectangular.
    // Stored in local element coordinates: (0,0) = bottom-left corner.
    var konturSkosuV0691: [PunktKonturuPaneluV0691]? = nil

    var jestScietySkosemV0691: Bool {
        katCieciaGornejKrawedziStopnieV0691 != nil
        || konturSkosuV0691 != nil
    }
}

struct KartaTechnicznaSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var draftID: UUID
    var numerSzafki = ""
    var nazwa = ""
    var szerokoscMM = 0.0
    var wysokoscMM = 0.0
    var glebokoscMM = 0.0
    var rodzajKonstrukcji = ""
    var materialKorpusu = ""
    var materialFrontu = ""
    var liczbaSegmentow = 1
    var punktyWiercenia:
        [PunktWierceniaSzafki] = []
    var uwagi = ""
    var dataAktualizacji = Date()

    // v0.54.0: karta należy do konkretnej instancji mebla, a nie tylko
    // do pary „kod szablonu + nazwa”. Pola opcjonalne zachowują pełną
    // zgodność z kartami utworzonymi we wcześniejszych wersjach.
    var kluczModulu: String? = nil
    var materialKorpusuID: UUID? = nil
    var materialFrontuID: UUID? = nil
    var wersjaSchematu: Int? = nil

    // v0.68.0: jedno źródło prawdy dla frontów, kierunku otwierania
    // oraz systemu szuflad. Pole opcjonalne zachowuje odczyt starszych kart.
    var konfiguracjaFunkcjonalnaV068:
        KonfiguracjaFunkcjonalnaModuluV068? = nil

    // v0.69.1: produkcyjny kontur paneli wynikający z profilu skosu.
    // Pole opcjonalne zachowuje odczyt wszystkich kart sprzed tej wersji.
    var raportPaneliSkosuV0691:
        RaportPaneliSkosuV0691? = nil

    // v0.80: wnęki specjalne dla customCarcass (np. iRobot).
    // Pole opcjonalne zachowuje odczyt kart sprzed tej wersji.
    var wnekiSpecjalneV080: [WnekaSpecjalnaV080]? = nil

    var wneki: [WnekaSpecjalnaV080] {
        wnekiSpecjalneV080 ?? []
    }

    var efektywnaKonfiguracjaFunkcjonalnaV068:
        KonfiguracjaFunkcjonalnaModuluV068
    {
        get {
            konfiguracjaFunkcjonalnaV068
            ?? KonfiguracjaFunkcjonalnaModuluV068()
        }
        set {
            konfiguracjaFunkcjonalnaV068 =
                newValue
        }
    }

    // Pola opcjonalne zachowują odczyt kart zapisanych w v0.45.0.
    var kodSzablonuZrodlowego:
        String?
    var jestGotowymModulem:
        Bool?
    var liczbaPolek:
        Int?
    var zamkniecieBryly:
        ZamkniecieBrylySzafki?
    var elementy:
        [ElementTechnicznySzafki]?
    var akcesoria:
        [InstancjaAkcesoriumSzafki]?
    var szuflady:
        [SzufladaModulu]?

    var efektywneSzuflady:
        [SzufladaModulu]
    {
        get {
            szuflady ?? []
        }
        set {
            szuflady = newValue
        }
    }

    var efektywneAkcesoria:
        [InstancjaAkcesoriumSzafki]
    {
        get {
            akcesoria ?? []
        }
        set {
            akcesoria = newValue
        }
    }

    var efektywneElementy:
        [ElementTechnicznySzafki]
    {
        get {
            elementy ?? []
        }
        set {
            elementy = newValue
        }
    }

    var efektywneZamkniecieBryly:
        ZamkniecieBrylySzafki
    {
        get {
            zamkniecieBryly
            ?? ZamkniecieBrylySzafki()
        }
        set {
            zamkniecieBryly = newValue
        }
    }
}
