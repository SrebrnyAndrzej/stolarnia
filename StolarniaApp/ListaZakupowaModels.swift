import Foundation

struct PozycjaListyZakupowej:
    Identifiable,
    Hashable
{
    var id = UUID()
    var nazwa: String
    var kategoria:
        KategoriaKosztuWyceny
    var ilosc: Double
    var jednostka: String
    var cenaJednostkowaNetto:
        Double
    var kosztNetto: Double
    var uwagi: String
    var uwzgledniona = true
}

struct ListaZakupowaProjektu:
    Identifiable,
    Hashable
{
    var id = UUID()
    var nazwaProjektu: String
    var wariant:
        WariantWyceny
    var dataUtworzenia = Date()
    var pozycje:
        [PozycjaListyZakupowej]

    var aktywnePozycje:
        [PozycjaListyZakupowej]
    {
        pozycje.filter(
            \.uwzgledniona
        )
    }

    var sumaNetto: Double {
        aktywnePozycje.reduce(0) {
            $0 + $1.kosztNetto
        }
    }
}

enum ListaZakupowaBuilder {
    static func build(
        projectName: String,
        summary:
            PodsumowanieWariantuWyceny
    ) -> ListaZakupowaProjektu {
        let allowed:
            Set<KategoriaKosztuWyceny> = [
                .plyty,
                .fronty,
                .blaty,
                .okucia,
                .akcesoria,
                .oswietlenie,
                .pozostale
            ]

        let items =
            summary.pozycje
                .filter {
                    allowed.contains(
                        $0.kategoria
                    )
                    && $0.ilosc > 0
                }
                .map {
                    PozycjaListyZakupowej(
                        nazwa: $0.nazwa,
                        kategoria:
                            $0.kategoria,
                        ilosc:
                            $0.ilosc,
                        jednostka:
                            $0.jednostka,
                        cenaJednostkowaNetto:
                            $0.cenaJednostkowaNetto,
                        kosztNetto:
                            $0.kosztNetto,
                        uwagi:
                            $0.uwagi
                    )
                }
                .sorted {
                    lhs,
                    rhs in

                    if lhs.kategoria.rawValue
                        == rhs.kategoria.rawValue {
                        return lhs.nazwa
                            .localizedCaseInsensitiveCompare(
                                rhs.nazwa
                            )
                            == .orderedAscending
                    }

                    return lhs.kategoria.rawValue
                        < rhs.kategoria.rawValue
                }

        return ListaZakupowaProjektu(
            nazwaProjektu:
                projectName,
            wariant:
                summary.wariant,
            pozycje: items
        )
    }
}
