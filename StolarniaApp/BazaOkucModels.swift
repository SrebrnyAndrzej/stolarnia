import Foundation

enum TypOkuciaMeblowego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case zawias
    case prowadnica
    case systemSzuflad
    case podnosnik
    case cargo
    case noga
    case cokół
    case zawieszka
    case uchwyt
    case profil
    case oswietlenieLED
    case lacznik
    case wkręt
    case klej
    case inne

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .zawias:
            return "Zawias"
        case .prowadnica:
            return "Prowadnica"
        case .systemSzuflad:
            return "System szuflad"
        case .podnosnik:
            return "Podnośnik"
        case .cargo:
            return "Cargo"
        case .noga:
            return "Noga"
        case .cokół:
            return "Cokół i mocowanie"
        case .zawieszka:
            return "Zawieszka"
        case .uchwyt:
            return "Uchwyt"
        case .profil:
            return "Profil"
        case .oswietlenieLED:
            return "Oświetlenie LED"
        case .lacznik:
            return "Łącznik"
        case .wkręt:
            return "Wkręt i element złączny"
        case .klej:
            return "Klej i chemia"
        case .inne:
            return "Inne"
        }
    }

    var systemImage: String {
        switch self {
        case .zawias:
            return "circle.grid.cross"
        case .prowadnica:
            return "line.3.horizontal"
        case .systemSzuflad:
            return "archivebox"
        case .podnosnik:
            return "arrow.up.forward"
        case .cargo:
            return "cabinet"
        case .noga:
            return "table.furniture"
        case .cokół:
            return "rectangle.bottomhalf.filled"
        case .zawieszka:
            return "link"
        case .uchwyt:
            return "minus"
        case .profil:
            return "ruler"
        case .oswietlenieLED:
            return "lightbulb"
        case .lacznik:
            return "point.3.connected.trianglepath.dotted"
        case .wkręt:
            return "screwdriver"
        case .klej:
            return "drop"
        case .inne:
            return "shippingbox"
        }
    }
}

enum JednostkaOkucia:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case sztuka
    case komplet
    case para
    case metr
    case opakowanie

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .sztuka:
            return "szt."
        case .komplet:
            return "kpl."
        case .para:
            return "para"
        case .metr:
            return "mb"
        case .opakowanie:
            return "opak."
        }
    }
}

enum PoziomWycenyOkucia:
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
}

struct OkucieMeblowe:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var kod = ""
    var nazwa = ""
    var producent = ""
    var dostawca = ""
    var typ:
        TypOkuciaMeblowego = .zawias
    var jednostka:
        JednostkaOkucia = .sztuka

    var cenaNetto = 0.0
    var vatProcent = 23.0
    var rabatProcent = 0.0
    var iloscWOakowaniu = 1.0

    var system = ""
    var katOtwarciaStopnie = 0.0
    var dlugoscMM = 0.0
    var szerokoscMM = 0.0
    var wysokoscMM = 0.0
    var nosnoscKG = 0.0
    var gruboscPlytyOdMM = 0.0
    var gruboscPlytyDoMM = 0.0

    var poziomWyceny:
        PoziomWycenyOkucia = .standard
    var aktywne = true
    var notatki = ""
    var dataAktualizacji = Date()

    // Łącze do KatalogRegulAkcesoriow. Opcjonalne dla zgodności ze starszą bazą.
    var profilAkcesoriumID: String?

    var jestSystememKatalogowym: Bool {
        profilAkcesoriumID != nil
    }

    var cenaNettoPoRabacie: Double {
        cenaNetto
        * (
            1
            - rabatProcent / 100
        )
    }

    var cenaBrutto: Double {
        cenaNettoPoRabacie
        * (
            1
            + vatProcent / 100
        )
    }

    var unikalnyKlucz: String {
        [
            kod
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased(),
            dostawca
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
        ]
        .joined(separator: "|")
    }
}
