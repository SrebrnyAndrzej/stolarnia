import DomainCore
import Foundation

enum KategoriaNormySzafki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case dolnaUniwersalna
    case dolnaCargo
    case wiszaca
    case naroznaL
    case naroznaSlepa
    case slupek
    case niestandardowa

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .dolnaUniwersalna:
            return "Dolna uniwersalna"
        case .dolnaCargo:
            return "Dolna cargo"
        case .wiszaca:
            return "Wisząca"
        case .naroznaL:
            return "Narożna L"
        case .naroznaSlepa:
            return "Narożna ślepa"
        case .slupek:
            return "Słupek"
        case .niestandardowa:
            return "Niestandardowa"
        }
    }
}

struct ZakresNormyMM:
    Codable,
    Hashable
{
    var minimum: Double
    var maximum: Double

    func contains(
        _ value: Double
    ) -> Bool {
        value >= minimum
        && value <= maximum
    }
}

struct NormaSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var kategoria:
        KategoriaNormySzafki
    var nazwa = ""
    var typoweSzerokosciMM:
        [Double] = []
    var szerokoscZakresMM:
        ZakresNormyMM?
    var glebokoscMM:
        ZakresNormyMM
    var wysokoscKorpusuMM:
        ZakresNormyMM

    var wysokoscCokoluMM:
        ZakresNormyMM?
    var gruboscBlatuMM:
        ZakresNormyMM?
    var typowaGruboscBlatuMM:
        Double?
    var typowaGlebokoscBlatuMM:
        Double?
    var odsunPlecyOdTyluMM:
        ZakresNormyMM?

    /// Luz frontu na jedno lico — z `ProductionRules`, nie z literału.
    ///
    /// Norma opisuje to samo, co konwencja warsztatu, tylko z perspektywy
    /// kategorii szafki. Dwie niezależne kopie tej liczby to konfiguracja,
    /// która wcześniej dała front 561 mm w module 600: kontrola i generator
    /// mówiły różnymi językami i nikt tego nie widział, dopóki nie wypisano
    /// całej szafki.
    ///
    /// Pole zostaje `var` i jest `Codable` — norma bywa strojona per warsztat,
    /// ale **startuje z tej samej wartości co reszta aplikacji**.
    var luzFrontuBocznyMM =
        ProductionRules.frontClearancePerEdge.rawValue
    var szczelinaMiedzyFrontamiMM =
        ZakresNormyMM(
            minimum: ProductionRules.frontToFrontGap.rawValue,
            maximum: ProductionRules.frontToFrontGap.rawValue
        )
    // 2 mm u dołu tak samo jak u góry — front niższy o 4 mm od korpusu,
    // co przy frontach jeden nad drugim daje znów 4 mm w fudze.
    var szczelinaDolnaFrontuMM =
        ProductionRules.frontClearancePerEdge.rawValue

    var uwagi = ""

    func szerokoscFrontuJednoskrzydlowego(
        korpusMM: Double
    ) -> Double {
        max(
            korpusMM
            - luzFrontuBocznyMM * 2,
            0
        )
    }

    func wysokoscFrontu(
        korpusMM: Double,
        szczelinaGornaMM: Double = 2.0
    ) -> Double {
        max(
            korpusMM
            - szczelinaGornaMM
            - szczelinaDolnaFrontuMM,
            0
        )
    }
}

enum PoziomWalidacjiNormySzafki:
    Hashable
{
    case informacja
    case ostrzezenie
    case blad
}

struct WynikWalidacjiNormySzafki:
    Identifiable,
    Hashable
{
    let id = UUID()
    var poziom:
        PoziomWalidacjiNormySzafki
    var komunikat = ""
}
