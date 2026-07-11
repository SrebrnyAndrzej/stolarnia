import Foundation

enum WariantWyceny:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case eco
    case standard
    case premium
    case vip

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .eco:
            return "Eco"
        case .standard:
            return "Standard"
        case .premium:
            return "Premium"
        case .vip:
            return "VIP"
        }
    }

    var opis: String {
        switch self {
        case .eco:
            return "Najtańsze sprawdzone rozwiązania bez systemów premium."
        case .standard:
            return "Zbalansowany wariant do większości realizacji."
        case .premium:
            return "Lepsze okucia, fronty i blaty o podwyższonym standardzie."
        case .vip:
            return "Najwyższa półka materiałowa i systemowa."
        }
    }

    var mnoznikRobocizny: Double {
        switch self {
        case .eco:
            return 0.90
        case .standard:
            return 1.00
        case .premium:
            return 1.18
        case .vip:
            return 1.35
        }
    }

    var mnoznikOkuc: Double {
        switch self {
        case .eco:
            return 0.85
        case .standard:
            return 1.00
        case .premium:
            return 1.35
        case .vip:
            return 1.75
        }
    }

    var mnoznikBlatu: Double {
        switch self {
        case .eco:
            return 0.80
        case .standard:
            return 1.00
        case .premium:
            return 1.55
        case .vip:
            return 2.40
        }
    }
}

enum KategoriaKosztuWyceny:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case plyty
    case fronty
    case blaty
    case okucia
    case akcesoria
    case robocizna
    case montaz
    case transport
    case pozostale

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .plyty:
            return "Płyty"
        case .fronty:
            return "Fronty"
        case .blaty:
            return "Blaty"
        case .okucia:
            return "Okucia"
        case .akcesoria:
            return "Akcesoria"
        case .robocizna:
            return "Robocizna"
        case .montaz:
            return "Montaż"
        case .transport:
            return "Transport"
        case .pozostale:
            return "Pozostałe"
        }
    }
}

struct PozycjaKosztowaWyceny:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var nazwa: String
    var kategoria:
        KategoriaKosztuWyceny
    var ilosc: Double
    var jednostka: String
    var cenaJednostkowaNetto: Double
    var uwagi: String
    /// true gdy pozycja powstała z błędu (brak ceny, nieaktywny materiał itp.).
    /// Nie może trafić do dokumentu klienta — wyłącznie do wewnętrznego widoku wyceny.
    var jestBledemWyceny: Bool = false

    var kosztNetto: Double {
        max(ilosc, 0)
        * max(cenaJednostkowaNetto, 0)
    }
}

struct PodsumowanieWariantuWyceny:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var wariant:
        WariantWyceny
    var pozycje:
        [PozycjaKosztowaWyceny]
    var kosztBazowyNetto: Double
    var narzutKwota: Double
    var marzaKwota: Double
    var zapasKosztowyKwota: Double
    var cenaNetto: Double
    var vatKwota: Double
    var cenaBrutto: Double

    var kosztMaterialowNetto: Double {
        pozycje
            .filter {
                $0.kategoria
                    != .robocizna
                && $0.kategoria
                    != .montaz
                && $0.kategoria
                    != .transport
            }
            .reduce(0) {
                $0 + $1.kosztNetto
            }
    }
}

enum RolaMaterialuWycenyV068:
    String,
    Codable,
    Hashable
{
    case korpus
    case front
}

struct UzycieMaterialuWycenyV068:
    Codable,
    Hashable
{
    var roomID: String
    var rola:
        RolaMaterialuWycenyV068
    var materialID: UUID
    var iloscM2: Double
}

struct PozycjaOkuciaProjektuV068:
    Codable,
    Hashable
{
    var profilID: String
    var producent: String
    var rodzina: String
    var model: String
    var kategoria:
        KategoriaAkcesoriumMeblowego
    var ilosc: Double
    var jednostka: String
    var cenaJednostkowaNetto: Double
    var zrodlo: String
}

struct ProjektWyceny:
    Codable,
    Hashable
{
    var nazwaProjektu: String
    var liczbaModulow: Int
    var metryBiezaceZabudowy: Double
    var powierzchniaFrontowM2: Double
    var powierzchniaPlytM2: Double
    var metryBiezaceBlatu: Double
    var liczbaSzuflad: Int
    var liczbaZawiasow: Int
    var liczbaCargo: Int
    var liczbaGodzinProdukcji: Double
    var liczbaGodzinMontazu: Double
    var liczbaTransportow: Int

    // v0.69.0: dodatkowe liczniki do kompletnego BOM hardware
    var liczbaModulowDolnych: Int = 0
    var liczbaModulowWiszacych: Int = 0
    var liczbaPólekWewnetrznych: Int = 0
    var dlugoscCokuluM: Double = 0

    // v0.70.0: obrzeże i uchwyty
    var metryKrawedziBanding: Double = 0
    var liczbaFrontow: Int = 0

    // v0.68.0: dokładne powiązanie powierzchni z materiałem wybranym
    // w konkretnym pomieszczeniu. Pusta tablica oznacza projekt legacy.
    var uzyciaMaterialowV068:
        [UzycieMaterialuWycenyV068] = []
    var ostrzezeniaV068:
        [String] = []
    var okuciaV068:
        [PozycjaOkuciaProjektuV068] = []

    static let przyklad =
        ProjektWyceny(
            nazwaProjektu:
                "Kuchnia pokazowa",
            liczbaModulow: 10,
            metryBiezaceZabudowy: 5.4,
            powierzchniaFrontowM2: 8.8,
            powierzchniaPlytM2: 24,
            metryBiezaceBlatu: 4.2,
            liczbaSzuflad: 6,
            liczbaZawiasow: 18,
            liczbaCargo: 1,
            liczbaGodzinProdukcji: 42,
            liczbaGodzinMontazu: 16,
            liczbaTransportow: 1
        )
}

// MARK: - Zgodność archiwów sprzed v0.68.0

extension ProjektWyceny {
    private enum CodingKeys:
        String,
        CodingKey
    {
        case nazwaProjektu
        case liczbaModulow
        case metryBiezaceZabudowy
        case powierzchniaFrontowM2
        case powierzchniaPlytM2
        case metryBiezaceBlatu
        case liczbaSzuflad
        case liczbaZawiasow
        case liczbaCargo
        case liczbaGodzinProdukcji
        case liczbaGodzinMontazu
        case liczbaTransportow
        case uzyciaMaterialowV068
        case ostrzezeniaV068
        case okuciaV068
    }

    init(
        from decoder:
            Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        nazwaProjektu =
            try container.decode(
                String.self,
                forKey:
                    .nazwaProjektu
            )
        liczbaModulow =
            try container.decode(
                Int.self,
                forKey:
                    .liczbaModulow
            )
        metryBiezaceZabudowy =
            try container.decode(
                Double.self,
                forKey:
                    .metryBiezaceZabudowy
            )
        powierzchniaFrontowM2 =
            try container.decode(
                Double.self,
                forKey:
                    .powierzchniaFrontowM2
            )
        powierzchniaPlytM2 =
            try container.decode(
                Double.self,
                forKey:
                    .powierzchniaPlytM2
            )
        metryBiezaceBlatu =
            try container.decode(
                Double.self,
                forKey:
                    .metryBiezaceBlatu
            )
        liczbaSzuflad =
            try container.decode(
                Int.self,
                forKey:
                    .liczbaSzuflad
            )
        liczbaZawiasow =
            try container.decode(
                Int.self,
                forKey:
                    .liczbaZawiasow
            )
        liczbaCargo =
            try container.decode(
                Int.self,
                forKey:
                    .liczbaCargo
            )
        liczbaGodzinProdukcji =
            try container.decode(
                Double.self,
                forKey:
                    .liczbaGodzinProdukcji
            )
        liczbaGodzinMontazu =
            try container.decode(
                Double.self,
                forKey:
                    .liczbaGodzinMontazu
            )
        liczbaTransportow =
            try container.decode(
                Int.self,
                forKey:
                    .liczbaTransportow
            )

        uzyciaMaterialowV068 =
            try container.decodeIfPresent(
                [UzycieMaterialuWycenyV068].self,
                forKey:
                    .uzyciaMaterialowV068
            )
            ?? []
        ostrzezeniaV068 =
            try container.decodeIfPresent(
                [String].self,
                forKey:
                    .ostrzezeniaV068
            )
            ?? []
        okuciaV068 =
            try container.decodeIfPresent(
                [PozycjaOkuciaProjektuV068].self,
                forKey:
                    .okuciaV068
            )
            ?? []
    }

    func encode(
        to encoder:
            Encoder
    ) throws {
        var container =
            encoder.container(
                keyedBy:
                    CodingKeys.self
            )

        try container.encode(
            nazwaProjektu,
            forKey:
                .nazwaProjektu
        )
        try container.encode(
            liczbaModulow,
            forKey:
                .liczbaModulow
        )
        try container.encode(
            metryBiezaceZabudowy,
            forKey:
                .metryBiezaceZabudowy
        )
        try container.encode(
            powierzchniaFrontowM2,
            forKey:
                .powierzchniaFrontowM2
        )
        try container.encode(
            powierzchniaPlytM2,
            forKey:
                .powierzchniaPlytM2
        )
        try container.encode(
            metryBiezaceBlatu,
            forKey:
                .metryBiezaceBlatu
        )
        try container.encode(
            liczbaSzuflad,
            forKey:
                .liczbaSzuflad
        )
        try container.encode(
            liczbaZawiasow,
            forKey:
                .liczbaZawiasow
        )
        try container.encode(
            liczbaCargo,
            forKey:
                .liczbaCargo
        )
        try container.encode(
            liczbaGodzinProdukcji,
            forKey:
                .liczbaGodzinProdukcji
        )
        try container.encode(
            liczbaGodzinMontazu,
            forKey:
                .liczbaGodzinMontazu
        )
        try container.encode(
            liczbaTransportow,
            forKey:
                .liczbaTransportow
        )
        try container.encode(
            uzyciaMaterialowV068,
            forKey:
                .uzyciaMaterialowV068
        )
        try container.encode(
            ostrzezeniaV068,
            forKey:
                .ostrzezeniaV068
        )
        try container.encode(
            okuciaV068,
            forKey:
                .okuciaV068
        )
    }
}

