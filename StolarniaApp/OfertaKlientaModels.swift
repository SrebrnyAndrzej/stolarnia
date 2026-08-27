import Foundation

enum TrybDokumentuOfertyKlienta:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case handlowy
    case wariantowy

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .handlowy:
            return "Handlowa"
        case .wariantowy:
            return "Wariantowa"
        }
    }

    var opis: String {
        switch self {
        case .handlowy:
            return "Dwustronicowa oferta dla klienta, bez kosztów wewnętrznych."
        case .wariantowy:
            return "Techniczne porównanie wariantów z większą liczbą danych."
        }
    }
}

struct WarunkiOfertyKlienta:
    Codable,
    Hashable
{
    var numerOferty = ""
    var klient = ""
    var tytulOferty = "Oferta wykonania zabudowy meblowej"
    var zakresPrac =
        "Projekt, wykonanie, dostawa oraz montaż zabudowy meblowej zgodnie z ustalonym zakresem."
    var terminRealizacjiDni = 45
    var waznoscOfertyDni = 14
    var zaliczkaProcent = 40.0
    var platnoscPrzedMontazemProcent = 50.0
    var platnoscPoMontazuProcent = 10.0
    var uwagi =
        "Oferta nie obejmuje prac elektrycznych, hydraulicznych ani budowlanych, chyba że wskazano inaczej."
    var trybDokumentu:
        TrybDokumentuOfertyKlienta = .handlowy
    var pokazWszystkieWarianty = true
    var pokazCenyNetto = true
    var pokazVAT = true
    var doliczVAT = true
    var vatProcent = 23.0
    var uzyjMarzyOferty = false
    var marzaOfertyProcent = 15.0
    var uzyjCenyRecznej = false
    var cenaRecznaNetto = 0.0

    /// Gwarancja na wady wykonania — domyślnie 24 miesiące (wymagane prawnie)
    var gwarancjaMiesiecy = 24
    var opisGwarancji =
        "Gwarancja na wady wykonania i materiałowe przez 24 miesiące od daty montażu. Gwarancja nie obejmuje normalnego zużycia oraz uszkodzeń mechanicznych."

    var sumaPlatnosciProcent: Double {
        zaliczkaProcent
        + platnoscPrzedMontazemProcent
        + platnoscPoMontazuProcent
    }

    var jestPoprawnyPodzialPlatnosci:
        Bool
    {
        abs(
            sumaPlatnosciProcent
            - 100
        ) < 0.01
    }

    func podsumowanieHandlowe(
        dla summary:
            PodsumowanieWariantuWyceny,
        ustawienia:
            UstawieniaStolarni
    ) -> PodsumowanieWariantuWyceny {
        var result = summary

        let cenaNetto: Double
        let marzaKwota: Double

        if uzyjCenyRecznej,
           cenaRecznaNetto > 0 {
            cenaNetto = cenaRecznaNetto
            marzaKwota =
                cenaRecznaNetto
                - summary.kosztBazowyNetto
                - summary.zapasKosztowyKwota
                - summary.narzutKwota
        } else if uzyjMarzyOferty {
            let bazaPoNarzucie =
                summary.kosztBazowyNetto
                + summary.zapasKosztowyKwota
                + summary.narzutKwota
            marzaKwota =
                bazaPoNarzucie
                * max(marzaOfertyProcent, 0)
                / 100
            cenaNetto =
                max(
                    bazaPoNarzucie
                    + marzaKwota,
                    ustawienia
                        .finanse
                        .minimalnaWartoscZlecenia
                )
        } else {
            cenaNetto = summary.cenaNetto
            marzaKwota = summary.marzaKwota
        }

        let vat =
            doliczVAT
            ? cenaNetto
                * max(vatProcent, 0)
                / 100
            : 0

        result.marzaKwota =
            marzaKwota
        result.cenaNetto =
            cenaNetto
        result.vatKwota =
            vat
        result.cenaBrutto =
            cenaNetto + vat

        return result
    }

    /// Generuje numer oferty w formacie RRRR/NNN na podstawie bieżącego roku.
    /// Numer sekwencji jest licznikiem w UserDefaults aby był unikalny w obrębie urządzenia.
    static func generujNumer() -> String {
        let rok = Calendar.current.component(
            .year, from: Date()
        )
        let klucz = "OfertaKlienta.licznik.\(rok)"
        let licznik =
            (UserDefaults.standard.integer(forKey: klucz)) + 1
        UserDefaults.standard.set(licznik, forKey: klucz)
        return String(format: "%d/%03d", rok, licznik)
    }
}

struct WygenerowanaOfertaKlienta:
    Identifiable
{
    let id = UUID()
    let fileURL: URL
}
