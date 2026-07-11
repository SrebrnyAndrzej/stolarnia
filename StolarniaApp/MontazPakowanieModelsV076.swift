import Foundation

enum EtapMontazuV076:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable
{
    case przygotowanie
    case korpus
    case plecy
    case wyposazenie
    case fronty
    case wykonczenie
    case kontrola

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .przygotowanie:
            return "Przygotowanie"
        case .korpus:
            return "Korpus"
        case .plecy:
            return "Plecy"
        case .wyposazenie:
            return "Wyposażenie"
        case .fronty:
            return "Fronty"
        case .wykonczenie:
            return "Wykończenie"
        case .kontrola:
            return "Kontrola"
        }
    }

    var symbol: String {
        switch self {
        case .przygotowanie:
            return "checklist"
        case .korpus:
            return "cabinet"
        case .plecy:
            return "rectangle.portrait"
        case .wyposazenie:
            return "wrench.and.screwdriver"
        case .fronty:
            return "rectangle.split.2x1"
        case .wykonczenie:
            return "sparkles"
        case .kontrola:
            return "checkmark.seal"
        }
    }

    var kolejnosc: Int {
        switch self {
        case .przygotowanie:
            return 0
        case .korpus:
            return 1
        case .plecy:
            return 2
        case .wyposazenie:
            return 3
        case .fronty:
            return 4
        case .wykonczenie:
            return 5
        case .kontrola:
            return 6
        }
    }
}

enum TypPaczkiV076:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable
{
    case korpus
    case fronty
    case plecy
    case blaty
    case maskownice
    case pozostale

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .korpus:
            return "Korpus"
        case .fronty:
            return "Fronty"
        case .plecy:
            return "Plecy"
        case .blaty:
            return "Blaty"
        case .maskownice:
            return "Maskownice"
        case .pozostale:
            return "Pozostałe"
        }
    }

    var skrot: String {
        switch self {
        case .korpus:
            return "KOR"
        case .fronty:
            return "FRO"
        case .plecy:
            return "PLE"
        case .blaty:
            return "BLA"
        case .maskownice:
            return "MAS"
        case .pozostale:
            return "POZ"
        }
    }

    var symbol: String {
        switch self {
        case .korpus:
            return "square.stack.3d.up"
        case .fronty:
            return "rectangle.split.2x1"
        case .plecy:
            return "rectangle.portrait"
        case .blaty:
            return "rectangle"
        case .maskownice:
            return "rectangle.compress.vertical"
        case .pozostale:
            return "shippingbox"
        }
    }
}

enum SposobPrzenoszeniaV076:
    String,
    Codable,
    Hashable
{
    case jednaOsoba
    case dwieOsoby
    case dlugiElement

    var nazwa: String {
        switch self {
        case .jednaOsoba:
            return "1 osoba"
        case .dwieOsoby:
            return "2 osoby"
        case .dlugiElement:
            return "Długi element"
        }
    }

    var symbol: String {
        switch self {
        case .jednaOsoba:
            return "person"
        case .dwieOsoby:
            return "person.2"
        case .dlugiElement:
            return "arrow.left.and.right"
        }
    }
}

struct UstawieniaMontazuIPakowaniaV076:
    Hashable
{
    var maksymalnaMasaPaczkiKG: Double
    var maksymalnaLiczbaElementow: Int
    var progDwochOsobKG: Double
    var progDlugiegoElementuMM: Double
    var gestoscPlytyKGNaM3: Double
    var gestoscPlecowKGNaM3: Double
    var gestoscBlatuKGNaM3: Double
    var zapasMasyProcent: Double
    var osobnoFronty: Bool
    var osobnoBlaty: Bool

    static let standard =
        UstawieniaMontazuIPakowaniaV076(
            maksymalnaMasaPaczkiKG: 25,
            maksymalnaLiczbaElementow: 12,
            progDwochOsobKG: 20,
            progDlugiegoElementuMM: 2_000,
            gestoscPlytyKGNaM3: 680,
            gestoscPlecowKGNaM3: 850,
            gestoscBlatuKGNaM3: 700,
            zapasMasyProcent: 5,
            osobnoFronty: true,
            osobnoBlaty: true
        )

    var poprawne: Bool {
        maksymalnaMasaPaczkiKG > 0
            && maksymalnaMasaPaczkiKG.isFinite
            && maksymalnaLiczbaElementow > 0
            && progDwochOsobKG > 0
            && progDwochOsobKG.isFinite
            && progDlugiegoElementuMM > 0
            && progDlugiegoElementuMM.isFinite
            && gestoscPlytyKGNaM3 > 0
            && gestoscPlytyKGNaM3.isFinite
            && gestoscPlecowKGNaM3 > 0
            && gestoscPlecowKGNaM3.isFinite
            && gestoscBlatuKGNaM3 > 0
            && gestoscBlatuKGNaM3.isFinite
            && zapasMasyProcent >= 0
            && zapasMasyProcent <= 100
            && zapasMasyProcent.isFinite
    }
}

struct OperacjaMontazowaV076:
    Identifiable,
    Hashable
{
    var id: String
    var indeksModulu: Int
    var nazwaModulu: String
    var etap: EtapMontazuV076
    var kolejnosc: Int
    var tytul: String
    var opis: String
    var formatkaIDs: [String]
    var etykietyFormatek: [String]
    var wymagaWeryfikacji: Bool

    var tekstWyszukiwania: String {
        [
            nazwaModulu,
            etap.nazwa,
            tytul,
            opis,
            formatkaIDs.joined(separator: " "),
            etykietyFormatek.joined(separator: " ")
        ]
        .joined(separator: " ")
    }
}

struct PozycjaPaczkiV076:
    Identifiable,
    Hashable
{
    var id: String
    var etykieta: String
    var nazwaModulu: String
    var kodKomponentu: String
    var kategoria: KategoriaFormatkiV070
    var material: MaterialFormatkiV070
    var dlugoscMM: Double
    var szerokoscMM: Double
    var gruboscMM: Double
    var szacowanaMasaKG: Double

    var najdluzszyWymiarMM: Double {
        max(dlugoscMM, szerokoscMM)
    }

    var opisWymiaru: String {
        "\(formatMMV076(dlugoscMM)) × \(formatMMV076(szerokoscMM)) × \(formatMMV076(gruboscMM)) mm"
    }
}

struct PaczkaProdukcyjnaV076:
    Identifiable,
    Hashable
{
    var id: String
    var kod: String
    var indeksModulu: Int
    var nazwaModulu: String
    var typ: TypPaczkiV076
    var numerWTymTypie: Int
    var pozycje: [PozycjaPaczkiV076]
    var szacowanaMasaKG: Double
    var najdluzszyWymiarMM: Double
    var sposobPrzenoszenia:
        SposobPrzenoszeniaV076
    var przekraczaLimitMasy: Bool

    var liczbaElementow: Int {
        pozycje.count
    }

    var tekstWyszukiwania: String {
        [
            kod,
            nazwaModulu,
            typ.nazwa,
            pozycje
                .map {
                    [
                        $0.etykieta,
                        $0.kodKomponentu,
                        $0.material.opis
                    ]
                    .joined(separator: " ")
                }
                .joined(separator: " ")
        ]
        .joined(separator: " ")
    }
}

struct ModulMontazowyV076:
    Identifiable,
    Hashable
{
    var id: String
    var indeks: Int
    var nazwa: String
    var operacje: [OperacjaMontazowaV076]
    var kodyPaczek: [String]

    var liczbaOperacji: Int {
        operacje.count
    }
}

enum PoziomOstrzezeniaPakowaniaV076:
    String,
    Codable,
    Hashable
{
    case informacja
    case uwaga
    case blad

    var symbol: String {
        switch self {
        case .informacja:
            return "info.circle"
        case .uwaga:
            return "exclamationmark.triangle"
        case .blad:
            return "xmark.octagon"
        }
    }
}

struct OstrzezeniePakowaniaV076:
    Identifiable,
    Hashable
{
    var id: String
    var poziom:
        PoziomOstrzezeniaPakowaniaV076
    var tytul: String
    var opis: String
    var kodPaczki: String?
}

struct RaportMontazuIPakowaniaV076:
    Hashable
{
    var nazwaProjektu: String
    var dataUtworzenia: Date
    var moduly: [ModulMontazowyV076]
    var operacje: [OperacjaMontazowaV076]
    var paczki: [PaczkaProdukcyjnaV076]
    var ostrzezenia:
        [OstrzezeniePakowaniaV076]

    var liczbaOperacjiDoWeryfikacji: Int {
        operacje.filter(\.wymagaWeryfikacji).count
    }

    var lacznaSzacowanaMasaKG: Double {
        paczki.reduce(0) {
            $0 + $1.szacowanaMasaKG
        }
    }

    var paczkiDoDwochOsob: Int {
        paczki.filter {
            $0.sposobPrzenoszenia
                != .jednaOsoba
        }
        .count
    }
}

func formatMMV076(
    _ value: Double
) -> String {
    value.formatted(
        .number
            .locale(
                Locale(
                    identifier:
                        "pl_PL"
                )
            )
            .grouping(.never)
            .precision(
                .fractionLength(0...1)
            )
    )
}

func formatKGV076(
    _ value: Double
) -> String {
    value.formatted(
        .number
            .locale(
                Locale(
                    identifier:
                        "pl_PL"
                )
            )
            .precision(
                .fractionLength(0...2)
            )
    )
}
