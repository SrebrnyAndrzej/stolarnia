import Foundation

enum BazaMaterialowWzornikiSeeder {
    static let migrationVersion = 2026062003

    private struct Wzornik {
        let producent: String
        let kolekcja: String
        let kod: String
        let nazwa: String
        let struktura: String
        let grupa: String
        let kolorHEX: String
    }

    static var materialy:
        [MaterialStolarski]
    {
        wzorniki.map {
            wzornik in

            let price =
                CennikRynkowyPlyt
                    .cenaReferencyjna(
                        producent:
                            wzornik.producent,
                        grupaDekoru:
                            wzornik.grupa
                    )

            var material =
                MaterialStolarski(
                    kod:
                        "\(wzornik.producent.uppercased())-\(wzornik.kod)-\(wzornik.struktura)",
                    nazwa:
                        "\(wzornik.kod) \(wzornik.nazwa)",
                    producent:
                        wzornik.producent,
                    dostawca:
                        price == nil
                        ? "Katalog producenta — cena do uzupełnienia"
                        : "Rynek PL — cena referencyjna",
                    typ:
                        .plytaLaminowana,
                    dekor:
                        wzornik.nazwa,
                    gruboscMM: 18,
                    szerokoscArkuszaMM:
                        2800,
                    wysokoscArkuszaMM:
                        2070,
                    jednostka:
                        .sztuka,
                    cenaNetto:
                        price?
                            .cenaSredniaNettoPLN
                        ?? 0,
                    vatProcent: 23,
                    rabatProcent: 0,
                    aktywny: true,
                    kierunekDekoru:
                        wzornik.grupa
                        == "Drewno",
                    kolorHEX:
                        wzornik.kolorHEX,
                    notatki:
                        notatki(
                            wzornik:
                                wzornik,
                            cena: price
                        )
                )

            material.kolekcja =
                wzornik.kolekcja
            material.kodProducenta =
                wzornik.kod
            material.struktura =
                wzornik.struktura
            material.grupaDekoru =
                wzornik.grupa
            material
                .cenaReferencyjnaPlytyID =
                price?.id

            return material
        }
    }

    private static func notatki(
        wzornik: Wzornik,
        cena:
            CenaRynkowaPlyty?
    ) -> String {
        var lines = [
            "Wzornik startowy \(wzornik.producent), kolekcja \(wzornik.kolekcja).",
            "Kolor HEX służy wyłącznie do wizualizacji w aplikacji. Przy doborze materiału wiążący jest fizyczny wzornik producenta."
        ]

        if let cena {
            let sources =
                cena.zrodla
                    .joined(
                        separator: " | "
                    )

            lines.append(
                "Cena startowa jest średnią netto wyliczoną z reprezentanta grupy: \(cena.kodProducenta) \(cena.struktura)."
            )
            lines.append(
                "Zakres brutto reprezentanta: \(currency(cena.cenaMinimalnaBruttoPLN))–\(currency(cena.cenaMaksymalnaBruttoPLN)); próbek: \(cena.liczbaProbek)."
            )
            lines.append(
                "Research: \(cena.dataResearchu.formatted(date: .numeric, time: .omitted)). Źródła: \(sources)."
            )
        }

        lines.append(
            "Cena firmy pozostaje edytowalna w Panel firmy → Baza materiałów i nie jest nadpisywana przy kolejnej synchronizacji."
        )

        return lines.joined(
            separator: "\n"
        )
    }

    private static func currency(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }

    private static let wzorniki: [Wzornik] = [
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "W1100", nazwa: "Alpine White", struktura: "ST9", grupa: "Uni", kolorHEX: "#F4F3ED"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "W1000", nazwa: "Premium White", struktura: "ST9", grupa: "Uni", kolorHEX: "#F8F7F0"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U104", nazwa: "Alabaster White", struktura: "ST9", grupa: "Uni", kolorHEX: "#EDE7D7"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U201", nazwa: "Pebble Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#B9B2A8"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U702", nazwa: "Cashmere Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#B9AFA2"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U705", nazwa: "Angora Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#C6BCAD"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U708", nazwa: "Light Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#C8C8C3"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U727", nazwa: "Stone Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#9B958D"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U732", nazwa: "Dust Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#787A77"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U750", nazwa: "Taupe Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#867D72"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U960", nazwa: "Onyx Grey", struktura: "ST9", grupa: "Uni", kolorHEX: "#4D5150"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U961", nazwa: "Graphite Grey", struktura: "ST7", grupa: "Uni", kolorHEX: "#3F4444"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "U999", nazwa: "Black", struktura: "ST7", grupa: "Uni", kolorHEX: "#1F2020"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "H1180", nazwa: "Natural Halifax Oak", struktura: "ST37", grupa: "Drewno", kolorHEX: "#B58B5D"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "H1385", nazwa: "Natural Casella Oak", struktura: "ST40", grupa: "Drewno", kolorHEX: "#B99A70"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "H1714", nazwa: "Lincoln Walnut", struktura: "ST19", grupa: "Drewno", kolorHEX: "#72513B"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "H3303", nazwa: "Natural Hamilton Oak", struktura: "ST10", grupa: "Drewno", kolorHEX: "#A77D4E"),
        .init(producent: "EGGER", kolekcja: "Decorative Collection 26+", kod: "F206", nazwa: "Black Pietra Grigia", struktura: "ST9", grupa: "Kamień", kolorHEX: "#3A3A38"),

        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "0101", nazwa: "Front White", struktura: "PE", grupa: "Uni", kolorHEX: "#F3F3EE"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "0110", nazwa: "White", struktura: "SM", grupa: "Uni", kolorHEX: "#F8F8F4"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "0190", nazwa: "Black", struktura: "PE", grupa: "Uni", kolorHEX: "#202121"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "5981", nazwa: "Cashmere", struktura: "BS", grupa: "Uni", kolorHEX: "#B8AA9C"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "7045", nazwa: "Satin", struktura: "SU", grupa: "Uni", kolorHEX: "#D8D0C4"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "7181", nazwa: "Dark Chocolate", struktura: "BS", grupa: "Uni", kolorHEX: "#493A34"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K096", nazwa: "Clay Grey", struktura: "SU", grupa: "Uni", kolorHEX: "#9E968B"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K003", nazwa: "Gold Craft Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#B9834F"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K005", nazwa: "Oyster Urban Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#B6A185"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K006", nazwa: "Amber Urban Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#9C6E43"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K086", nazwa: "Natural Rockford Hickory", struktura: "PW", grupa: "Drewno", kolorHEX: "#B48C62"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K105", nazwa: "Raw Endgrain Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#A6845E"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K358", nazwa: "Honey Castello Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#B78048"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K359", nazwa: "Brandy Castello Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#83583B"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K365", nazwa: "Coast Evoke Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#BEA27C"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K366", nazwa: "Fossil Evoke Oak", struktura: "PW", grupa: "Drewno", kolorHEX: "#7F7365"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K349", nazwa: "Silk Flow", struktura: "RT", grupa: "Materiał", kolorHEX: "#BEB7AD"),
        .init(producent: "Kronospan", kolekcja: "Global Collection 3.0", kod: "K350", nazwa: "Concrete Flow", struktura: "RT", grupa: "Materiał", kolorHEX: "#8E8D88")
    ]
}
