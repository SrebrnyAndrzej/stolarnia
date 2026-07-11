import Foundation

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
    var pokazWszystkieWarianty = true
    var pokazCenyNetto = true
    var pokazVAT = true

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
