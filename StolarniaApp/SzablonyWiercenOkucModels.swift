import Foundation

enum OrientacjaSzablonuWiercenia:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case pozioma
    case pionowa

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .pozioma:
            return "Pozioma"
        case .pionowa:
            return "Pionowa"
        }
    }
}

struct PunktSzablonuWiercenia:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var odsunXMM = 0.0
    var odsunYMM = 0.0
    var srednicaMM = 5.0
    var glebokoscMM = 12.0
    var opis = ""
}

struct SzablonWierceniaOkucia:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var kodOkucia = ""
    var nazwa = ""
    var producent = ""
    var typ:
        TypPunktuWiercenia = .inny
    var elementDocelowy = ""
    var strona:
        StronaElementuTechnicznego =
            .wewnetrzna
    var orientacja:
        OrientacjaSzablonuWiercenia =
            .pozioma
    var punktBazowyXMM = 37.0
    var punktBazowyYMM = 0.0
    var punkty:
        [PunktSzablonuWiercenia] = []
    var aktywny = true
    var uwagi = ""
}
