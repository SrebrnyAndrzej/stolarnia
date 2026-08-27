import Foundation

enum KategoriaAkcesoriumMeblowego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case systemSzuflady
    case prowadnica
    case zawias
    case podnosnikFrontu
    case zlaczeKonstrukcyjne
    case nozkaIPodpora
    case systemNarozny
    case cargoIOrganizer
    case wentylacjaAGD
    case mechanizmBezuchwytowy
    case zawieszkaSzafki
    case oswietlenie
    case inne

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .systemSzuflady:
            return "System szuflady"
        case .prowadnica:
            return "Prowadnica"
        case .zawias:
            return "Zawias"
        case .podnosnikFrontu:
            return "Podnośnik frontu"
        case .zlaczeKonstrukcyjne:
            return "Złącze konstrukcyjne"
        case .nozkaIPodpora:
            return "Nóżka / podpora"
        case .systemNarozny:
            return "System narożny"
        case .cargoIOrganizer:
            return "Cargo / organizer"
        case .wentylacjaAGD:
            return "Wentylacja AGD"
        case .mechanizmBezuchwytowy:
            return "Mechanizm bezuchwytowy"
        case .zawieszkaSzafki:
            return "Zawieszka szafki"
        case .oswietlenie:
            return "Oświetlenie"
        case .inne:
            return "Inne"
        }
    }

    var symbol: String {
        switch self {
        case .systemSzuflady:
            return "shippingbox"
        case .prowadnica:
            return "line.3.horizontal"
        case .zawias:
            return "door.left.hand.open"
        case .podnosnikFrontu:
            return "arrow.up.to.line"
        case .zlaczeKonstrukcyjne:
            return "link"
        case .nozkaIPodpora:
            return "square.bottomhalf.filled"
        case .systemNarozny:
            return "arrow.triangle.turn.up.right.diamond"
        case .cargoIOrganizer:
            return "square.grid.2x2"
        case .wentylacjaAGD:
            return "wind"
        case .mechanizmBezuchwytowy:
            return "hand.tap"
        case .zawieszkaSzafki:
            return "wallplug"
        case .oswietlenie:
            return "lightbulb"
        case .inne:
            return "wrench.and.screwdriver"
        }
    }
}

enum StatusWeryfikacjiAkcesorium:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case oficjalnaDokumentacja
    case dokumentBranzowy
    case wymagaPotwierdzenia

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .oficjalnaDokumentacja:
            return "Oficjalna dokumentacja"
        case .dokumentBranzowy:
            return "Dokument branżowy"
        case .wymagaPotwierdzenia:
            return "Wymaga potwierdzenia"
        }
    }
}

enum TrybRegulyGrubosciPlyty:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case brak
    case stala
    case zakres
    case wybor
    case wymagaPotwierdzenia

    var id: String { rawValue }
}

struct RegulaGrubosciPlyty:
    Codable,
    Hashable
{
    var tryb:
        TrybRegulyGrubosciPlyty = .brak
    var stalaMM:
        Double?
    var minimumMM:
        Double?
    var maksimumMM:
        Double?
    var dozwoloneMM:
        [Double] = []
    var opis = ""

    static func brak(
        _ opis: String = ""
    ) -> Self {
        Self(
            tryb: .brak,
            opis: opis
        )
    }

    static func stala(
        _ value: Double,
        opis: String = ""
    ) -> Self {
        Self(
            tryb: .stala,
            stalaMM: value,
            opis: opis
        )
    }

    static func zakres(
        _ minimum: Double,
        _ maximum: Double,
        opis: String = ""
    ) -> Self {
        Self(
            tryb: .zakres,
            minimumMM: minimum,
            maksimumMM: maximum,
            opis: opis
        )
    }

    static func wybor(
        _ values: [Double],
        opis: String = ""
    ) -> Self {
        Self(
            tryb: .wybor,
            dozwoloneMM: values,
            opis: opis
        )
    }

    static func potwierdzenie(
        _ opis: String
    ) -> Self {
        Self(
            tryb:
                .wymagaPotwierdzenia,
            opis: opis
        )
    }

    func accepts(
        _ value: Double
    ) -> Bool {
        switch tryb {
        case .brak:
            return true
        case .stala:
            guard let stalaMM else {
                return true
            }
            return abs(value - stalaMM) < 0.01
        case .zakres:
            guard let minimumMM,
                  let maksimumMM
            else {
                return true
            }
            return value >= minimumMM
                && value <= maksimumMM
        case .wybor:
            return dozwoloneMM.contains {
                abs($0 - value) < 0.01
            }
        case .wymagaPotwierdzenia:
            return true
        }
    }

    var opisSkrocony: String {
        switch tryb {
        case .brak:
            return opis.isEmpty
                ? "Brak ograniczenia"
                : opis
        case .stala:
            return "\(format(stalaMM ?? 0)) mm"
        case .zakres:
            return "\(format(minimumMM ?? 0))–\(format(maksimumMM ?? 0)) mm"
        case .wybor:
            return dozwoloneMM
                .map(format)
                .joined(separator: " / ")
                + " mm"
        case .wymagaPotwierdzenia:
            return opis.isEmpty
                ? "Wymaga potwierdzenia"
                : opis
        }
    }

    private func format(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }
}

struct FormulaWymiarowaniaSzuflady:
    Codable,
    Hashable
{
    var redukcjaSzerokosciDnaMM:
        Double?
    var redukcjaDlugosciDnaMM:
        Double?
    var redukcjaSzerokosciTyluMM:
        Double?
    var redukcjaSynchronizatoraMM:
        Double?
    var zapasGlebokosciKorpusuMM:
        Double = 0
    var minimalneOdsuniecieOdScianBocznychMM:
        Double?
    var opis = ""
}

struct RegulaSzufladyZaFrontem:
    Codable,
    Hashable
{
    var zeroProtrusion = false
    var dopuszczaSzufladyWewnetrzne = false
    var dopuszczaRollOut = false
    var minimalnyKatOtwarciaStopnie:
        Double = 155
    var zalecaneOdsuniecieOdZawiasuMM:
        Double = 50
    var zalecaneOdsuniecieOdStronyWolnejMM:
        Double = 0
    var dodatkowyLuzBezpieczenstwaMM:
        Double = 0
    var wymagaPotwierdzeniaSKU = true
    var opis = ""

    var wymaganySymetrycznyDystansMM: Double {
        max(
            zalecaneOdsuniecieOdZawiasuMM,
            zalecaneOdsuniecieOdStronyWolnejMM
        )
        + dodatkowyLuzBezpieczenstwaMM
    }

    static let standard110 =
        RegulaSzufladyZaFrontem(
            zeroProtrusion: false,
            dopuszczaSzufladyWewnetrzne: false,
            dopuszczaRollOut: false,
            minimalnyKatOtwarciaStopnie: 155,
            zalecaneOdsuniecieOdZawiasuMM: 50,
            zalecaneOdsuniecieOdStronyWolnejMM: 0,
            dodatkowyLuzBezpieczenstwaMM: 0,
            wymagaPotwierdzeniaSKU: true,
            opis:
                "Standardowy zawias 95-110° nie jest regułą bezpieczną dla szuflad za frontem. Wymaga potwierdzenia toru drzwi albo dystansu/fillera po stronie zawiasu."
        )

    static let zeroProtrusion155 =
        RegulaSzufladyZaFrontem(
            zeroProtrusion: true,
            dopuszczaSzufladyWewnetrzne: true,
            dopuszczaRollOut: true,
            minimalnyKatOtwarciaStopnie: 155,
            zalecaneOdsuniecieOdZawiasuMM: 0,
            zalecaneOdsuniecieOdStronyWolnejMM: 0,
            dodatkowyLuzBezpieczenstwaMM: 3,
            wymagaPotwierdzeniaSKU: false,
            opis:
                "Zawias zero-protrusion 155° odsuwa skrzydło z toru wysuwu. System nadal zostawia 3 mm luzu bezpieczeństwa dla tolerancji montażu."
        )

    static let zeroProtrusion125RollOut =
        RegulaSzufladyZaFrontem(
            zeroProtrusion: true,
            dopuszczaSzufladyWewnetrzne: false,
            dopuszczaRollOut: true,
            minimalnyKatOtwarciaStopnie: 125,
            zalecaneOdsuniecieOdZawiasuMM: 8,
            zalecaneOdsuniecieOdStronyWolnejMM: 0,
            dodatkowyLuzBezpieczenstwaMM: 2,
            wymagaPotwierdzeniaSKU: true,
            opis:
                "Zawias zero-protrusion 125° traktujemy jako regułę dla wewnętrznych roll-outów/cargo, nie dla pełnych szuflad bez potwierdzenia konkretnego SKU."
        )
}

struct ProfilAkcesoriumMeblowego:
    Identifiable,
    Codable,
    Hashable
{
    var id: String
    var producent: String
    var rodzina: String
    var model: String
    var kategoria:
        KategoriaAkcesoriumMeblowego
    var status:
        StatusWeryfikacjiAkcesorium
    var indeksyPrzykladowe:
        [String] = []

    var dozwoloneDlugosciMM:
        [Double] = []
    var dozwoloneWysokosciMM:
        [Double] = []

    var regulaGrubosciDna:
        RegulaGrubosciPlyty =
            .brak()
    var regulaGrubosciTylu:
        RegulaGrubosciPlyty =
            .brak()
    var regulaGrubosciBoku:
        RegulaGrubosciPlyty =
            .brak()

    var maksymalneObciazenieKG:
        Double?
    var trwaloscCykle:
        Int?
    var minimalnaWysokoscKorpusuMM:
        Double?
    var minimalnaPowierzchniaWentylacjiCM2:
        Double?
    var minimalnaGlebokoscSwiatlaMM:
        Double?
    var katOtwarciaStopnie:
        Double?
    var srednicaPuszkiMM:
        Double?
    var glebokoscPuszkiMM:
        Double?
    var formulaSzuflady:
        FormulaWymiarowaniaSzuflady?

    var wymagaSynchronizatoraGdySzerokoscPrzekraczaDlugosc =
        false
    var progRelinguDlaFrontuMM:
        Double?

    var funkcje:
        [String] = []
    var elementyDocelowe:
        [TypElementuSzafki] = []
    var uwagi:
        [String] = []
    var regulaSzufladyZaFrontem:
        RegulaSzufladyZaFrontem?
    var zrodlo = ""
}

struct InstancjaAkcesoriumSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var profilID = ""
    var producent = ""
    var rodzina = ""
    var model = ""
    var kategoria:
        KategoriaAkcesoriumMeblowego =
            .inne

    var ilosc = 1
    var docelowaEtykietaElementu = ""

    var nominalnaDlugoscMM:
        Double?
    var wariantWysokosciMM:
        Double?
    var gruboscDnaMM:
        Double?
    var gruboscTyluMM:
        Double?
    var gruboscBokuMM:
        Double?
    var gruboscKorpusuMM = 18.0
    var masaObciazeniaKG:
        Double?
    var powierzchniaWentylacjiCM2:
        Double?
    var wysokoscFrontuMM:
        Double?

    // v0.105: wynik obliczeń geometrycznych, niezależny od profilu/SKU.
    // Pola opcjonalne zachowują odczyt starszych kart technicznych.
    var masaFrontuKG: Double? = nil
    var wspolczynnikMocy: Double? = nil
    var niewykorzystanaGlebokoscMM: Double? = nil
    var wymagaPotwierdzeniaSKU: Bool? = nil

    // Snapshot ceny zachowuje wycenę nawet po późniejszej aktualizacji cennika.
    var cenaJednostkowaNettoPLN:
        Double?
    var cenaJednostkowaBruttoPLN:
        Double?
    var jednostkaCeny:
        String?
    var dataCeny:
        Date?
    var liczbaProbekCeny:
        Int?

    var uwagi = ""
    var dataDodania = Date()

    var wartoscBruttoPLN:
        Double?
    {
        cenaJednostkowaBruttoPLN
            .map {
                $0
                * Double(
                    max(
                        ilosc,
                        0
                    )
                )
            }
    }
}

enum PoziomWalidacjiAkcesorium:
    String,
    Codable,
    Hashable
{
    case informacja
    case ostrzezenie
    case blad
}

struct WynikWalidacjiAkcesorium:
    Identifiable,
    Hashable
{
    let id = UUID()
    var poziom:
        PoziomWalidacjiAkcesorium
    var komunikat = ""
}

struct WynikWymiarowaniaSzuflady:
    Hashable
{
    var szerokoscWewnetrznaKorpusuMM:
        Double
    var szerokoscDnaMM:
        Double?
    var dlugoscDnaMM:
        Double?
    var szerokoscTyluMM:
        Double?
    var dlugoscSynchronizatoraMM:
        Double?
    var minimalnaGlebokoscKorpusuMM:
        Double?
}
