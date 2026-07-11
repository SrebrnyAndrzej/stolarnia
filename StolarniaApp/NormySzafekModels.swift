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

    var luzFrontuBocznyMM = 2.0
    var szczelinaMiedzyFrontamiMM =
        ZakresNormyMM(
            minimum: 2.5,
            maximum: 3.0
        )
    var szczelinaDolnaFrontuMM = 3.0

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
