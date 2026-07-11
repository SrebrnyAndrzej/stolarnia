import Foundation

struct PozycjaBOMProjektuV062: Identifiable, Hashable {
    var id = UUID()
    var kategoria: KategoriaKosztuWyceny
    var nazwa: String
    var ilosc: Double
    var jednostka: String
    var cenaJednostkowaNetto: Double
    var kosztNetto: Double
    var zrodlo: String
    /// Flaga wskazująca że pozycja wymaga korekty (brak ceny / nieaktywny materiał).
    /// Przy eksporcie CSV oznaczana jako "⚠ WYMAGA KOREKTY".
    var jestBledemWyceny: Bool = false
}

struct BOMProjektuV062: Hashable {
    var nazwaProjektu: String
    var wariant: WariantWyceny
    var pozycje: [PozycjaBOMProjektuV062]
    var utworzono: Date

    var kosztNetto: Double {
        pozycje.reduce(0) { $0 + $1.kosztNetto }
    }

    var grupy: [KategoriaKosztuWyceny: [PozycjaBOMProjektuV062]] {
        Dictionary(grouping: pozycje, by: \.kategoria)
    }
}

enum BOMProjektuBuilderV062 {
    static func build(
        projectName: String,
        summary: PodsumowanieWariantuWyceny
    ) -> BOMProjektuV062 {
        let items = summary.pozycje.map { source in
            PozycjaBOMProjektuV062(
                kategoria: source.kategoria,
                nazwa: source.nazwa,
                ilosc: source.ilosc,
                jednostka: source.jednostka,
                cenaJednostkowaNetto: source.cenaJednostkowaNetto,
                kosztNetto: source.kosztNetto,
                zrodlo: source.uwagi,
                jestBledemWyceny: source.jestBledemWyceny
            )
        }

        return BOMProjektuV062(
            nazwaProjektu: projectName,
            wariant: summary.wariant,
            pozycje: items,
            utworzono: Date()
        )
    }
}
