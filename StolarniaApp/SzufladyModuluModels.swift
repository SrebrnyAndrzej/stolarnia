import DomainCore
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

/// Rodzaj szuflady — standardowa lub Cargo (system jednofrontowy typu SPACE TOWER).
enum WariantSzuflady:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case standardowa
    case cargo

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .standardowa:
            return "Standardowa"
        case .cargo:
            return "Cargo"
        }
    }
}

/// Standardowe wysokości frontów szuflad kuchennych stosowane w stolarni.
/// Wartości uśrednione z katalogów producentów prowadnic (Blum LEGRABOX M/C/K, GTV H86/H116/H168).
/// Używane w kreatorze meblowym jako szybkie skróty zamiast ręcznego wpisywania mm.
enum StandardWysokoscSzuflady:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case niska        // klasyczna szuflada na sztućce/drobiazgi
    case srednia      // uniwersalna
    case wysoka       // na garnki, wysoka zabudowa
    case bardzoWysoka // pod zlewem, cargo mid-range

    var id: String { rawValue }

    var wysokoscFrontuMM: Double {
        switch self {
        case .niska:        return 140
        case .srednia:      return 180
        case .wysoka:       return 280
        case .bardzoWysoka: return 320
        }
    }

    var nazwa: String {
        switch self {
        case .niska:        return "Niska"
        case .srednia:      return "Średnia"
        case .wysoka:       return "Wysoka"
        case .bardzoWysoka: return "Bardzo wysoka"
        }
    }

    var opis: String {
        "\(nazwa) (\(Int(wysokoscFrontuMM)) mm)"
    }
}

/// Preset układu szuflad w strefie roboczej modułu.
/// Zapewnia szybki wybór typowych konfiguracji zamiast ręcznego wpisywania każdej wysokości.
enum PresetUkladuSzuflad: Hashable {
    /// N szuflad o tej samej wysokości (klasyczne zachowanie).
    case rowne(liczba: Int)
    /// Dwie niskie szuflady pod spodem + jedna wysoka na górze.
    case jednaWysokaDwieNiskie(wysokaMM: Double)
    /// Jedna wysoka szuflada na dole + dwie niskie powyżej.
    case wysokaNaDoleDwieNiskie(wysokaMM: Double)
    /// Dwie szuflady wysokie (równy podział strefy na 2).
    case dwieWysokie
    /// Dowolna lista wysokości frontów (od dołu do góry).
    case wysokosciNiestandardowe([Double])
    /// Pojedyncza szuflada Cargo zajmująca całą strefę.
    case cargo

    var etykieta: String {
        switch self {
        case .rowne:
            return "Równe"
        case .jednaWysokaDwieNiskie:
            return "2 niskie + wysoka u góry"
        case .wysokaNaDoleDwieNiskie:
            return "Wysoka na dole + 2 niskie"
        case .dwieWysokie:
            return "2 wysokie"
        case .wysokosciNiestandardowe:
            return "Niestandardowe"
        case .cargo:
            return "Cargo"
        }
    }

    static var domyslnePresety: [PresetUkladuSzuflad] {
        [
            .rowne(liczba: 3),
            .jednaWysokaDwieNiskie(wysokaMM: 280),
            .wysokaNaDoleDwieNiskie(wysokaMM: 280),
            .dwieWysokie,
            .cargo
        ]
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

    /// Boczne odsunięcie skrzynki/prowadnic od ścian bocznych korpusu.
    /// Przy szufladach wewnętrznych engine ustawia standardowy dystans,
    /// żeby ominąć tor frontu, zawias i dystanse montażowe.
    var odsuniecieOdScianBocznychMM:
        Double? = nil

    /// Wysokość dolnej krawędzi frontu względem wewnętrznego dna korpusu.
    var pozycjaDolnaYMM = 0.0
    var wysokoscFrontuMM = 140.0
    var wysokoscSkrzynkiMM = 120.0
    var nominalnaDlugoscMM = 450.0
    /// Różnica między głębokością korpusu a dobranym NL.
    /// `nil` dla kart zapisanych przed wpięciem kalkulatora geometrii.
    var niewykorzystanaGlebokoscMM: Double? = nil
    /// Kalkulator wskazuje wymiar, ale nie konkretny indeks producenta.
    var wymagaPotwierdzeniaSKUProwadnicy: Bool? = nil
    var luzDolnyMM = 2.5
    var luzGornyMM = 2.5
    var aktywna = true
    /// Wariant szuflady — nil traktowane jako `.standardowa` (zgodność wstecz z zapisami sprzed presetów).
    var wariantSzuflady: WariantSzuflady? = nil

    var efektywnyWariant: WariantSzuflady {
        wariantSzuflady ?? .standardowa
    }

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

    var efektywneOdsuniecieOdScianBocznychMM:
        Double
    {
        max(
            odsuniecieOdScianBocznychMM ?? 0,
            0
        )
    }

    /// Odsunięcie **po stronie zawiasu**.
    ///
    /// Problem szuflady za frontem uchylnym jest niesymetryczny: front zostaje
    /// w płaszczyźnie boku tylko po tej stronie, po której wisi na zawiasie.
    /// Po drugiej stronie skrzynka może iść niemal do boku korpusu.
    ///
    /// Do 2026-08-27 silnik stosował wartość dla strony zawiasu **po obu
    /// stronach**, bo pole było jedno — w korpusie 600 oddawało to kilka
    /// centymetrów szerokości skrzynki bez powodu.
    ///
    /// `nil` oznacza „nieznana strona zawiasu": wtedy zostajemy przy wariancie
    /// symetrycznym, bo zgadnięcie strony jest gorsze niż jego brak — skrzynka
    /// wyszłaby odsunięta w złą stronę.
    var odsuniecieStronaZawiasuMM: Double? = nil
    /// Odsunięcie po stronie wolnej — tam, gdzie front nie wchodzi w światło.
    var odsuniecieStronaWolnaMM: Double? = nil

    /// Suma obu odsunięć, czyli ile szerokości zabiera front i luzy montażowe.
    ///
    /// To jest liczba, o którą pomniejsza się skrzynkę. Przy nieznanej stronie
    /// zawiasu wraca do symetrycznego `odsunięcie × 2`.
    var lacznaSzerokoscOdsunieciaV0104: Double {
        if let zawias = odsuniecieStronaZawiasuMM,
           let wolna = odsuniecieStronaWolnaMM {
            return max(zawias, 0) + max(wolna, 0)
        }
        return efektywneOdsuniecieOdScianBocznychMM * 2
    }

    /// Opis odsunięć do uwag na karcie — mówi wprost, czy jest asymetryczne.
    var opisOdsunieciaV0104: String {
        if let zawias = odsuniecieStronaZawiasuMM,
           let wolna = odsuniecieStronaWolnaMM {
            return "zawias \(Int(zawias.rounded())) mm / wolna \(Int(wolna.rounded())) mm"
        }
        return "\(Int(efektywneOdsuniecieOdScianBocznychMM.rounded())) mm/strona"
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
    /// Fuga między frontami — **z konwencji warsztatu**, nie z literału.
    ///
    /// Stało tu wpisane `3.0`, podczas gdy kanoniczna fuga projektu to 4 mm
    /// (`ProductionRules.frontToFrontGap`, czyli dwa luzy po 2 mm). Wartość
    /// idzie wprost do `DrawerFrontStack` przy liczeniu wysokości frontów,
    /// więc ta sama szafka dostawała inne fronty zależnie od tego, czy liczył
    /// ją kreator elewacji (4 mm), czy okno szuflad (3 mm).
    ///
    /// Pozostałe zaszyte fugi wymienione w handoffie z 2026-08-26 00:10:
    /// `PaneleProdukcyjneSkosuV0691` (2 mm) i `SzufladyGTVAxisProEngineV081`.
    var szczelinaMiedzyFrontamiMM =
        ProductionRules.frontToFrontGap.rawValue
    var marginesDolnyMM = 3.0
    var marginesGornyMM = 3.0
    var typFrontu:
        TypFrontuSzuflady =
            .zewnetrzny
    var profilID = ""
    var odsuniecieOdScianBocznychMM:
        Double? = nil
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
