import Foundation

// MARK: - Modele systemu drzwi przesuwnych

enum SystemProfiluSzafyPrzesuwanej:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    // Bonari — domyślny/główny system (auto-dobór serii)
    case bonariAutomatic    // Bonari — seria dobierana automatycznie
    case bonariBL40
    case bonariBL60
    case bonariBL80
    case bonariBL100
    case bonariPartition40  // ścianka dzieląca lekka
    case bonariPartition80  // ścianka dzieląca szklana

    // Inne systemy
    case hettich
    case hafeleSlido
    case komandor
    case alumeco
    case ikea
    case wlasny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .bonariAutomatic:   return "Bonari (auto-seria)"
        case .bonariBL40:        return "Bonari BL-40"
        case .bonariBL60:        return "Bonari BL-60"
        case .bonariBL80:        return "Bonari BL-80"
        case .bonariBL100:       return "Bonari BL-100"
        case .bonariPartition40: return "Bonari Partition 40 (ścianka)"
        case .bonariPartition80: return "Bonari Partition 80 (ścianka szklana)"
        case .hettich:           return "Hettich"
        case .hafeleSlido:       return "Häfele Slido"
        case .komandor:          return "Komandor"
        case .alumeco:           return "Alumeco"
        case .ikea:              return "IKEA PAX"
        case .wlasny:            return "System własny"
        }
    }

    var isBonari: Bool {
        switch self {
        case .bonariAutomatic, .bonariBL40, .bonariBL60,
             .bonariBL80, .bonariBL100,
             .bonariPartition40, .bonariPartition80:
            return true
        default:
            return false
        }
    }

    var jestSciankaPodziałowa: Bool {
        self == .bonariPartition40 || self == .bonariPartition80
    }

    var seriaBonari: SeriaBonari? {
        switch self {
        case .bonariBL40:        return .bl40
        case .bonariBL60:        return .bl60
        case .bonariBL80:        return .bl80
        case .bonariBL100:       return .bl100
        case .bonariPartition40: return .partition40
        case .bonariPartition80: return .partition80
        default:                 return nil
        }
    }

    /// Typowa wysokość prowadnicy górnej [mm]
    var wysokoscProwadnicyGornejMM: Double {
        if let seria = seriaBonari {
            return seria.profil.wysokoscProwadnicyGornejMM
        }
        switch self {
        case .hettich:     return 30
        case .hafeleSlido: return 35
        case .komandor:    return 32
        case .alumeco:     return 28
        case .ikea:        return 25
        default:           return 30
        }
    }

    /// Typowa wysokość prowadnicy dolnej [mm]
    var wysokoscProwadnicyDolnejMM: Double {
        if let seria = seriaBonari {
            return seria.profil.wysokoscPrzewodnicyDolnejMM
        }
        switch self {
        case .hettich:     return 12
        case .hafeleSlido: return 15
        case .komandor:    return 12
        case .alumeco:     return 10
        case .ikea:        return 10
        default:           return 12
        }
    }

    var clearanceMM: Double {
        seriaBonari?.profil.clearanceMM ?? 3
    }

    var nadmiaryNaProwadniceMM: Double { 2 }

    var zachodZalecanyMM: Double {
        seriaBonari?.profil.zachodZalecanyMM ?? 60
    }
}

enum KonstrukcjaDrzwiPrzesuwnychV075:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case plytaLaminowana
    case lustro
    case szklo
    case lacobel
    case aluminium
    case mieszana

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .plytaLaminowana: return "Płyta laminowana"
        case .lustro:          return "Lustro"
        case .szklo:           return "Szkło"
        case .lacobel:         return "Lacobel (szkło lakierowane)"
        case .aluminium:       return "Aluminium ramiakowe"
        case .mieszana:        return "Mieszana"
        }
    }

    /// Typowa waga [kg/m²] używana do doboru systemu
    var wagaKgM2: Double {
        switch self {
        case .plytaLaminowana: return 8
        case .lustro:          return 12
        case .szklo:           return 10
        case .lacobel:         return 10
        case .aluminium:       return 6
        case .mieszana:        return 10
        }
    }
}

enum TorSzafyPrzesuwanej:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case gorny          // drzwi zawieszone od góry (zawieszane)
    case dolny          // drzwi oparte na torze dolnym (stare systemy)
    case gornyIDolny    // prowadnica górna i dolna (standard)

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .gorny:        return "Górny (zawieszane)"
        case .dolny:        return "Dolny (tarciowe)"
        case .gornyIDolny:  return "Górny + dolny (standard)"
        }
    }
}

// MARK: - Tryb montażu systemu przesuwnego

/// Określa jak system przesuwny jest zamontowany względem obudowy.
///
/// - `wolnostojacaSzafa`:    kompletna szafa — corpus dostarcza obydwie stronice
/// - `dostawionyDoSzafki`:   system dostawiony do istniejącej szafy/szafki;
///                            jedna strona to bok korpusu mebla, druga to ściana
///                            (lub inny mebel). Wymaga listwy przymykowej.
/// - `miedzyDwamiSzafkami`:  system między dwoma szafkami; prowadnica opiera się
///                            na bokach obu korpusów. Może wymagać listew przymykowych.
enum TrybMontazuSzafyPrzesuwanej:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case wolnostojacaSzafa
    case dostawionyDoSzafki
    case miedzyDwamiSzafkami

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .wolnostojacaSzafa:    return "Wolnostojąca szafa"
        case .dostawionyDoSzafki:   return "Dostawiony do szafki"
        case .miedzyDwamiSzafkami:  return "Między dwiema szafkami"
        }
    }

    var opis: String {
        switch self {
        case .wolnostojacaSzafa:
            return "Kompletna szafa — corpus sam w sobie."
        case .dostawionyDoSzafki:
            return "System na boku szafki do ściany. Potrzebna listwa przymykowa po stronie ściany (i opcjonalnie po stronie szafki)."
        case .miedzyDwamiSzafkami:
            return "Prowadnica oparta na bokach obu korpusów. Listwy przymykowe opcjonalne."
        }
    }

    var wymagaListwyPrzymykowej: Bool {
        self != .wolnostojacaSzafa
    }
}

// MARK: - Listwa przymykowa

/// Profil/deska przymykowa montowana pionowo:
/// - po stronie **ściany** — zakrywa szczelinę między otwartym skrzydłem a ścianą
/// - po stronie **szafy**  — wykończenie boku szafy (gdy prowadnica wychodzi poza bok)
///
/// Typowe wymiary: szerokość 50–120 mm, materiał = bok szafy lub aluminium.
struct ListwaPrzymykowa:
    Codable,
    Hashable
{
    /// Strona montażu (lewa/prawa w rzucie z przodu szafy).
    enum Strona: String, Codable, Hashable, CaseIterable, Identifiable {
        case lewa
        case prawa
        var id: String { rawValue }
        var nazwa: String { self == .lewa ? "Lewa" : "Prawa" }
    }

    var strona: Strona = .prawa

    /// Szerokość listwy [mm]. Zasada: ≥ (skrzydło − zachód) / 2 + 20 mm bufor,
    /// zwykle 50–120 mm.
    var szerokoscMM: Double = 80

    /// Wysokość listwy [mm] — zwykle = wysokość szafy (do wieńca lub sufitu).
    var wysokoscMM: Double = 2400

    /// Grubość listwy [mm] — zazwyczaj = grubość boku szafy (18–22 mm).
    var gruboscMM: Double = 18

    /// Materiał listwy — kod materiału z bazy lub opis wolny.
    var materialOpis: String = "Materiał jak bok szafy"

    /// Kolor (HEX) do podglądu.
    var kolorHEX: String = "#F5F5F0"

    /// Czy listwa jest mocowana do ściany (kołki/klejonka) czy do boku szafy.
    var mocowanieDoSciany: Bool = true

    var opisBOM: String {
        "Listwa przymykowa \(strona.nazwa.lowercased()) \(Int(szerokoscMM))×\(Int(gruboscMM))×\(Int(wysokoscMM)) mm"
    }

    /// Minimalna zalecana szerokość listwy dla danej konfiguracji skrzydeł.
    static func minSzerokoscMM(
        szerokoscSkrzydlaMM: Double,
        zachodMM: Double
    ) -> Double {
        // Gdy drzwi otwarte maksymalnie, jedno skrzydło wyjeżdża poza obrys o:
        // (szerokosc_skrzydla - zachod) + 20 mm bezpieczeństwa
        let wysiag = szerokoscSkrzydlaMM - zachodMM
        return max(wysiag + 20, 50)
    }
}

// MARK: - Definicja szafy przesuwnej

struct SzafaPrzesuwnaDefinicjaV075:
    Codable,
    Hashable
{
    // Gabaryty
    var szerokoscCalkowitaMM: Double = 2000
    var wysokoscCalkowitaMM: Double  = 2400
    var glebokoscMM: Double          = 600

    // System drzwi
    var liczbaDrzwi: Int                 = 2
    var zachodMM: Double                 = 60       // overlap między skrzydłami
    var systemProfili: SystemProfiluSzafyPrzesuwanej = .hettich
    var konstrukjaDrzwi: KonstrukcjaDrzwiPrzesuwnychV075 = .plytaLaminowana
    var systemToru: TorSzafyPrzesuwanej  = .gornyIDolny

    // Opcje
    var miekkieZamykanie: Bool   = true
    var systemSoftClose: Bool    = true
    var uchwytTyp: TypUchwytuwProjekcie = .bar
    var gruboscDrzwiMM: Double   = 18

    // Tryb montażu i listwy przymykowe
    var trybMontazu: TrybMontazuSzafyPrzesuwanej = .wolnostojacaSzafa
    /// Listwy przymykowe (0–2 szt.); typowo 1 po stronie ściany (tryb dostawiony)
    var listwPrzymykowe: [ListwaPrzymykowa] = []

    /// Kod wypełnienia drzwi z `BonariKatalog.wypelnienia` (np. "PLY-WHITE-MATT").
    /// Pusty string = wypełnienie nieokreślone / własne.
    var wypelnienieDrzwiID: String = ""

    // Obliczone przez normalize()
    private(set) var szerokoscSkrzydlaMM: Double = 0
    private(set) var wysokoscSkrzydlaMM: Double  = 0

    mutating func normalize() {
        liczbaDrzwi = min(max(liczbaDrzwi, 2), 4)
        zachodMM    = min(max(zachodMM, 40), 100)

        let prowadnicaGorna = systemProfili.wysokoscProwadnicyGornejMM
        let prowadnicaDolna = systemToru == .gorny ? 0 : systemProfili.wysokoscProwadnicyDolnejMM
        let clearance = systemProfili.clearanceMM

        // Szerokość skrzydła: (W + (N-1)×zachód) / N
        szerokoscSkrzydlaMM = (szerokoscCalkowitaMM + Double(liczbaDrzwi - 1) * zachodMM) / Double(liczbaDrzwi)

        // Wysokość skrzydła: H - górna - dolna - luzy
        wysokoscSkrzydlaMM = wysokoscCalkowitaMM
            - prowadnicaGorna
            - prowadnicaDolna
            - clearance * 2

        // Sync wysokości listw przymykowych z wysokością szafy
        for i in listwPrzymykowe.indices {
            listwPrzymykowe[i].wysokoscMM = wysokoscCalkowitaMM
        }
    }

    /// Sugerowana minimalna szerokość listwy przymykowej dla bieżącej konfiguracji.
    var sugerowanaListwaMM: Double {
        ListwaPrzymykowa.minSzerokoscMM(
            szerokoscSkrzydlaMM: szerokoscSkrzydlaMM,
            zachodMM: zachodMM
        )
    }

    /// Dodaje domyślną listwę przymykową po stronie ściany jeśli jej jeszcze nie ma.
    mutating func dodajDomyslnaListwePrzymykowaPrawą() {
        guard !listwPrzymykowe.contains(where: { $0.strona == .prawa }) else { return }
        let listwa = ListwaPrzymykowa(
            strona: .prawa,
            szerokoscMM: sugerowanaListwaMM,
            wysokoscMM: wysokoscCalkowitaMM,
            gruboscMM: 18,
            materialOpis: "Materiał jak bok szafy",
            kolorHEX: "#F5F5F0",
            mocowanieDoSciany: true
        )
        listwPrzymykowe.append(listwa)
    }

    mutating func dodajDomyslnaListwePrzymykowaLewa() {
        guard !listwPrzymykowe.contains(where: { $0.strona == .lewa }) else { return }
        var listwa = ListwaPrzymykowa(
            strona: .lewa,
            szerokoscMM: sugerowanaListwaMM,
            wysokoscMM: wysokoscCalkowitaMM,
            gruboscMM: 18,
            materialOpis: "Materiał jak bok szafy",
            kolorHEX: "#F5F5F0",
            mocowanieDoSciany: false
        )
        listwa.mocowanieDoSciany = false
        listwPrzymykowe.append(listwa)
    }

    mutating func usunListwePrzymykowa(strona: ListwaPrzymykowa.Strona) {
        listwPrzymykowe.removeAll { $0.strona == strona }
    }

    var wagaDrzwiKg: Double {
        let powierzchniaM2 = (szerokoscSkrzydlaMM / 1000) * (wysokoscSkrzydlaMM / 1000)
        return powierzchniaM2 * konstrukjaDrzwi.wagaKgM2
    }

    /// Liczba torów prowadnicy górnej (zwykle: ⌈N/2⌉ dla drzwi przesuwnych na 2 torach)
    var liczbaTorów: Int {
        liczbaDrzwi <= 2 ? 2 : (liczbaDrzwi <= 3 ? 2 : 3)
    }

    /// Orientacyjna głębokość zajęta przez tory, skrzydła i luz pracy.
    /// To nie zastępuje karty producenta, ale pozwala szybko wykryć
    /// szafy, które w projekcie "na papierze" mają 600 mm, a realnie po
    /// torach nie dają miejsca na wieszanie ani szuflady.
    var glebokoscZajetaPrzezToryMM: Double {
        Double(liczbaTorów)
            * (gruboscDrzwiMM + 10)
            + 24
    }

    var glebokoscUzytkowaPoTorachMM: Double {
        max(
            glebokoscMM
            - glebokoscZajetaPrzezToryMM,
            0
        )
    }

    var swiatloDostepuPoOdsunieciuSkrzydlaMM: Double {
        max(
            szerokoscCalkowitaMM
            - szerokoscSkrzydlaMM,
            0
        )
    }

    var szerokoscSekcjiReferencyjnejMM: Double {
        szerokoscCalkowitaMM
            / Double(max(liczbaDrzwi, 1))
    }

    var zalecaneOdsuniecieSzufladOdBokuMM: Double {
        max(
            zachodMM + 20,
            80
        )
    }
}

// MARK: - Elementy raportu

enum TypElementuSzafyPrzesuwanej:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case liscDrzwi
    case materialDrzwi      // płyta, lustro, szkło — wypełnienie skrzydła
    case prowadnicaGorna
    case prowadnicaDolna
    case stopperGorny
    case stopperDolny
    case uchwyt
    case wozekJezdny
    case zaworSoftClose
    case profil
    case listwaPrzymykowa

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .liscDrzwi:          return "Liść drzwi"
        case .materialDrzwi:      return "Materiał wypełnienia"
        case .prowadnicaGorna:    return "Prowadnica górna"
        case .prowadnicaDolna:    return "Prowadnica dolna"
        case .stopperGorny:       return "Ogranicznik górny"
        case .stopperDolny:       return "Ogranicznik dolny"
        case .uchwyt:             return "Uchwyt"
        case .wozekJezdny:        return "Wózek jezdny"
        case .zaworSoftClose:     return "Soft-close"
        case .profil:             return "Profil aluminiowy"
        case .listwaPrzymykowa:   return "Listwa przymykowa"
        }
    }

    var jednostka: String {
        switch self {
        case .prowadnicaGorna, .prowadnicaDolna, .profil:
            return "mb"
        case .materialDrzwi:
            return "szt."
        case .listwaPrzymykowa:
            return "szt."
        default:
            return "szt."
        }
    }
}

struct ElementSzafyPrzesuwanej:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var typ: TypElementuSzafyPrzesuwanej
    var ilosc: Int
    var szerokoscMM: Double?    // dla liści i prowadnic
    var wysokoscMM: Double?     // dla liści
    var opis: String
    var uwagi: String?

    var wymiarOpis: String {
        switch typ {
        case .liscDrzwi:
            let w = Int(szerokoscMM?.rounded() ?? 0)
            let h = Int(wysokoscMM?.rounded() ?? 0)
            return "\(w) × \(h) mm"
        case .prowadnicaGorna, .prowadnicaDolna:
            let l = Int(szerokoscMM?.rounded() ?? 0)
            return "\(l) mm"
        case .materialDrzwi:
            let w = Int(szerokoscMM?.rounded() ?? 0)
            let h = Int(wysokoscMM?.rounded() ?? 0)
            return "\(w) × \(h) mm"
        case .listwaPrzymykowa:
            let w = Int(szerokoscMM?.rounded() ?? 0)
            let h = Int(wysokoscMM?.rounded() ?? 0)
            return "\(w) × \(h) mm"
        default:
            return ""
        }
    }
}

// MARK: - Raport

struct RaportSzafyPrzesuwanejV075:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var definicja: SzafaPrzesuwnaDefinicjaV075
    var elementy: [ElementSzafyPrzesuwanej]
    var ostrzezenia: [String]
    var wygenerowano: Date

    var liścieDrzwi: [ElementSzafyPrzesuwanej] {
        elementy.filter { $0.typ == .liscDrzwi }
    }

    var sumaLisciM2: Double {
        liścieDrzwi.reduce(0) { acc, el in
            let w = (el.szerokoscMM ?? 0) / 1000
            let h = (el.wysokoscMM ?? 0) / 1000
            return acc + w * h * Double(el.ilosc)
        }
    }

    var sumaWagaKg: Double {
        definicja.wagaDrzwiKg * Double(definicja.liczbaDrzwi)
    }
}

// MARK: - Silnik

enum SilnikSzafyPrzesuwanejV075 {

    // MARK: Główny punkt wejścia

    static func raport(
        dla def: SzafaPrzesuwnaDefinicjaV075,
        at date: Date = Date()
    ) -> RaportSzafyPrzesuwanejV075 {
        var definicja = def
        definicja.normalize()

        var elementy: [ElementSzafyPrzesuwanej] = []
        var ostrzezenia: [String] = []

        // --- Liście drzwi ---
        let lisc = ElementSzafyPrzesuwanej(
            typ: .liscDrzwi,
            ilosc: definicja.liczbaDrzwi,
            szerokoscMM: definicja.szerokoscSkrzydlaMM,
            wysokoscMM:  definicja.wysokoscSkrzydlaMM,
            opis: "\(definicja.liczbaDrzwi) × \(definicja.konstrukjaDrzwi.nazwa)",
            uwagi: definicja.gruboscDrzwiMM != 18
                ? "Grubość niestandardowa: \(Int(definicja.gruboscDrzwiMM)) mm"
                : nil
        )
        elementy.append(lisc)

        // --- Materiał wypełnienia (płyta/lustro/szkło) ---
        let wypelnienieBonari = BonariKatalog.wypelnienia.first { $0.id == definicja.wypelnienieDrzwiID }
        let nazwaWypelnienia: String
        let gruboscWypelnienia: Double
        let wagaM2: Double

        if let w = wypelnienieBonari {
            // Dane z katalogu Bonari
            nazwaWypelnienia = w.nazwa
            gruboscWypelnienia = w.gruboscMM
            wagaM2 = w.wagaKgM2

            // Sprawdź czy tafla mieści się w max. szerokości katalogu
            if definicja.szerokoscSkrzydlaMM > w.maxSzerokoscMM {
                ostrzezenia.append(
                    "Wypelnienie \"\(w.nazwa)\" ma max. szerokosc tafli \(Int(w.maxSzerokoscMM)) mm, a skrzydlo ma \(Int(definicja.szerokoscSkrzydlaMM.rounded())) mm. Wymagany podzial tafli lub wybor innego materialu."
                )
            }
            if definicja.wysokoscSkrzydlaMM > w.maxWysokoscMM {
                ostrzezenia.append(
                    "Wypelnienie \"\(w.nazwa)\" ma max. wysokosc tafli \(Int(w.maxWysokoscMM)) mm, a skrzydlo ma \(Int(definicja.wysokoscSkrzydlaMM.rounded())) mm."
                )
            }
        } else {
            // Brak wyboru z katalogu — użyj danych z KonstrukcjaDrzwiPrzesuwnychV075
            nazwaWypelnienia = definicja.konstrukjaDrzwi.nazwa
            gruboscWypelnienia = definicja.gruboscDrzwiMM
            wagaM2 = definicja.konstrukjaDrzwi.wagaKgM2
        }

        let powierzchniaSztMM2 = definicja.szerokoscSkrzydlaMM * definicja.wysokoscSkrzydlaMM
        let powierzchniaM2 = powierzchniaSztMM2 / 1_000_000
        let wagaJednegoDrzwiKg = powierzchniaM2 * wagaM2

        elementy.append(ElementSzafyPrzesuwanej(
            typ: .materialDrzwi,
            ilosc: definicja.liczbaDrzwi,
            szerokoscMM: definicja.szerokoscSkrzydlaMM,
            wysokoscMM:  definicja.wysokoscSkrzydlaMM,
            opis: "\(nazwaWypelnienia) \(Int(gruboscWypelnienia)) mm",
            uwagi: String(format: "%.2f m² / szt. · %.1f kg / szt.", powierzchniaM2, wagaJednegoDrzwiKg)
        ))

        // --- Prowadnica górna ---
        let dlProwadnicy = definicja.szerokoscCalkowitaMM
            + definicja.systemProfili.nadmiaryNaProwadniceMM * 2
        for tor in 0 ..< definicja.liczbaTorów {
            elementy.append(ElementSzafyPrzesuwanej(
                typ: .prowadnicaGorna,
                ilosc: 1,
                szerokoscMM: dlProwadnicy,
                opis: "Prowadnica górna tor \(tor + 1) — \(definicja.systemProfili.nazwa)",
                uwagi: nil
            ))
        }

        // --- Prowadnica dolna (jeśli wymagana) ---
        if definicja.systemToru != .gorny {
            elementy.append(ElementSzafyPrzesuwanej(
                typ: .prowadnicaDolna,
                ilosc: 1,
                szerokoscMM: dlProwadnicy,
                opis: "Prowadnica dolna — \(definicja.systemProfili.nazwa)",
                uwagi: nil
            ))
        }

        // --- Wózki jezdne ---
        let wozekNaDrzwi = 2 // 2 wózki na drzwi (standardowo)
        elementy.append(ElementSzafyPrzesuwanej(
            typ: .wozekJezdny,
            ilosc: definicja.liczbaDrzwi * wozekNaDrzwi,
            opis: "Wózki jezdne \(definicja.systemProfili.nazwa)",
            uwagi: nil
        ))

        // --- Ograniczniki ---
        elementy.append(ElementSzafyPrzesuwanej(
            typ: .stopperGorny,
            ilosc: definicja.liczbaDrzwi * 2,
            opis: "Ograniczniki górne",
            uwagi: nil
        ))

        if definicja.systemToru != .gorny {
            elementy.append(ElementSzafyPrzesuwanej(
                typ: .stopperDolny,
                ilosc: definicja.liczbaDrzwi * 2,
                opis: "Ograniczniki dolne (anty-wypadnięcie)",
                uwagi: nil
            ))
        }

        // --- Listwy przymykowe (tryb dostawiony do szafki) ---
        for listwa in definicja.listwPrzymykowe {
            elementy.append(ElementSzafyPrzesuwanej(
                typ: .listwaPrzymykowa,
                ilosc: 1,
                szerokoscMM: listwa.szerokoscMM,
                wysokoscMM:  listwa.wysokoscMM,
                opis: listwa.opisBOM,
                uwagi: listwa.mocowanieDoSciany
                    ? "Mocowanie: do ściany"
                    : "Mocowanie: do boku szafy"
            ))
        }

        // --- Soft-close ---
        if definicja.systemSoftClose {
            elementy.append(ElementSzafyPrzesuwanej(
                typ: .zaworSoftClose,
                ilosc: definicja.liczbaDrzwi * 2,
                opis: "Zawory soft-close",
                uwagi: nil
            ))
        }

        // --- Uchwyty ---
        if definicja.uchwytTyp != .bezUchwytu {
            elementy.append(ElementSzafyPrzesuwanej(
                typ: .uchwyt,
                ilosc: definicja.liczbaDrzwi,
                opis: "Uchwyty — \(definicja.uchwytTyp.nazwa)",
                uwagi: nil
            ))
        }

        // MARK: Walidacja / ostrzeżenia

        let wagaJednego = definicja.wagaDrzwiKg
        if wagaJednego > 75 {
            ostrzezenia.append(
                "Waga skrzydła wynosi \(String(format: "%.1f", wagaJednego)) kg — sprawdź nośność systemu \(definicja.systemProfili.nazwa)."
            )
        }

        if definicja.szerokoscSkrzydlaMM > 1200 {
            ostrzezenia.append(
                "Skrzydło \(Int(definicja.szerokoscSkrzydlaMM)) mm jest ponadstandardowej szerokości. Zweryfikuj ugięcie prowadnicy."
            )
        }

        if definicja.szerokoscSkrzydlaMM < 400 {
            ostrzezenia.append(
                "Skrzydło \(Int(definicja.szerokoscSkrzydlaMM)) mm jest wąskie — sprawdź minimalną szerokość systemu."
            )
        }

        if definicja.zachodMM < 50
            || definicja.zachodMM > 80 {
            ostrzezenia.append(
                "Zakładka skrzydeł \(Int(definicja.zachodMM)) mm jest poza typowym zakresem 50–80 mm. Sprawdź system profili i uchwyty."
            )
        }

        if definicja
            .swiatloDostepuPoOdsunieciuSkrzydlaMM < 450 {
            ostrzezenia.append(
                "Światło dostępu po odsunięciu skrzydła wynosi \(Int(definicja.swiatloDostepuPoOdsunieciuSkrzydlaMM)) mm — może blokować wygodne korzystanie z półek i szuflad."
            )
        }

        if definicja
            .glebokoscUzytkowaPoTorachMM < 500 {
            ostrzezenia.append(
                "Głębokość użytkowa po torach wynosi \(Int(definicja.glebokoscUzytkowaPoTorachMM)) mm. Dla wieszania i szuflad wewnętrznych zwykle trzeba zwiększyć głębokość albo zmienić układ."
            )
        }

        if definicja.wysokoscSkrzydlaMM > 2800 {
            ostrzezenia.append(
                "Skrzydło \(Int(definicja.wysokoscSkrzydlaMM)) mm przekracza typową maksymalną wysokość. Wymagane prowadnice wzmocnione."
            )
        }

        if definicja.liczbaDrzwi == 3 && definicja.liczbaTorów == 2 {
            ostrzezenia.append(
                "Przy 3 drzwiach na 2 torach środkowe skrzydło zachodzi na oba. Upewnij się że system to obsługuje."
            )
        }

        // Ostrzeżenia dla trybu dostawionego do szafki
        if definicja.trybMontazu != .wolnostojacaSzafa {
            if definicja.listwPrzymykowe.isEmpty {
                ostrzezenia.append(
                    "Tryb \"\(definicja.trybMontazu.nazwa)\": brak zdefiniowanych listw przymykowych. Dodaj co najmniej jedna listwe po stronie sciany."
                )
            } else {
                let minMM = definicja.sugerowanaListwaMM
                for listwa in definicja.listwPrzymykowe {
                    if listwa.szerokoscMM < minMM {
                        ostrzezenia.append(
                            "Listwa przymykowa (\(listwa.strona.nazwa)) ma \(Int(listwa.szerokoscMM)) mm — zalecane minimum to \(Int(minMM)) mm dla tej konfiguracji."
                        )
                    }
                }
            }

            if definicja.trybMontazu == .dostawionyDoSzafki
                && !definicja.listwPrzymykowe.contains(where: { $0.strona == .prawa }) {
                ostrzezenia.append(
                    "Brak listwy przymykowej po stronie ściany (prawa). Otwarte skrzydło nie będzie zamknięte od strony ściany."
                )
            }
        }

        return RaportSzafyPrzesuwanejV075(
            definicja:    definicja,
            elementy:     elementy,
            ostrzezenia:  ostrzezenia,
            wygenerowano: date
        )
    }

    // MARK: Bonari — raport z auto-doborem serii

    /// Generuje raport dla systemu Bonari z automatycznym doborem serii BL.
    /// Używa `BonariKatalog.autoDoborDrzwi()` do wyznaczenia optymalnej
    /// liczby drzwi, serii BL oraz waliduje wymiary skrzydła.
    static func raportBonari(
        dla def: SzafaPrzesuwnaDefinicjaV075,
        at date: Date = Date()
    ) -> (raport: RaportSzafyPrzesuwanejV075, autoWybor: BonariKatalog.WynikAutoDoboruDrzwi) {
        // Auto-dobór liczby drzwi i serii
        let autoWybor = BonariKatalog.autoDoborDrzwi(
            szerokoscCalkowitaMM: def.szerokoscCalkowitaMM,
            wysokoscCalkowitaMM:  def.wysokoscCalkowitaMM,
            konstrukcja:          def.konstrukjaDrzwi
        )

        // Buduj definicję z wybraną serią i dobranymi parametrami
        var definicjaZ = def
        definicjaZ.liczbaDrzwi = autoWybor.liczbaDrzwi
        definicjaZ.zachodMM    = autoWybor.zachodMM

        // Mapuj serię Bonari na SystemProfilu
        let systemProfilu: SystemProfiluSzafyPrzesuwanej
        switch autoWybor.seria {
        case .bl40:         systemProfilu = .bonariBL40
        case .bl60:         systemProfilu = .bonariBL60
        case .bl80:         systemProfilu = .bonariBL80
        case .bl100:        systemProfilu = .bonariBL100
        case .partition40:  systemProfilu = .bonariPartition40
        case .partition80:  systemProfilu = .bonariPartition80
        }
        definicjaZ.systemProfili = systemProfilu
        definicjaZ.normalize()

        var raportPodstawowy = raport(dla: definicjaZ, at: date)

        // Dodaj ostrzeżenia Bonari
        let profil = autoWybor.seria.profil
        let wynikWalidacji = profil.waliduj(
            szerokoscSkrzydlaMM: definicjaZ.szerokoscSkrzydlaMM,
            wysokoscSkrzydlaMM:  definicjaZ.wysokoscSkrzydlaMM,
            wagaKg: definicjaZ.wagaDrzwiKg
        )

        var ostrzezenia = raportPodstawowy.ostrzezenia
        ostrzezenia.append(contentsOf: wynikWalidacji.ostrzezenia)

        if autoWybor.ocena == "warning" {
            ostrzezenia.insert(autoWybor.komunikat, at: 0)
        }

        raportPodstawowy = RaportSzafyPrzesuwanejV075(
            id:           raportPodstawowy.id,
            definicja:    definicjaZ,
            elementy:     raportPodstawowy.elementy,
            ostrzezenia:  ostrzezenia,
            wygenerowano: date
        )

        return (raportPodstawowy, autoWybor)
    }

    // MARK: Helpers

    /// Minimalna szerokość szafy dla danej liczby drzwi i zachodu
    static func minSzerokoscMM(
        liczbaDrzwi: Int,
        zachodMM: Double,
        minSzerSkrzydla: Double = 400
    ) -> Double {
        Double(liczbaDrzwi) * minSzerSkrzydla
            - Double(liczbaDrzwi - 1) * zachodMM
    }

    /// Optymalna liczba drzwi dla danej szerokości (cel: 700–900 mm/skrzydło)
    static func optymalnaLiczbaDrzwi(
        szerokoscMM: Double,
        zachodMM: Double = 60,
        targetSzerMM: Double = 800
    ) -> Int {
        let n = (szerokoscMM + zachodMM) / (targetSzerMM + zachodMM)
        let rounded = Int(n.rounded())
        return min(max(rounded, 2), 4)
    }
}
