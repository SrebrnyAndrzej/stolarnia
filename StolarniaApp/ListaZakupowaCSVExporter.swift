import Foundation

enum ListaZakupowaCSVExporter {
    static func export(
        _ list:
            ListaZakupowaProjektu
    ) throws -> URL {
        let separator = ";"

        var rows: [String] = [
            [
                "Projekt",
                "Wariant",
                "Kategoria",
                "Pozycja",
                "Ilość",
                "Jednostka",
                "Cena netto",
                "Koszt netto",
                "Uwagi"
            ]
            .joined(
                separator: separator
            )
        ]

        for item in list.aktywnePozycje {
            rows.append(
                [
                    escaped(
                        list.nazwaProjektu
                    ),
                    escaped(
                        list.wariant.nazwa
                    ),
                    escaped(
                        item.kategoria.nazwa
                    ),
                    escaped(
                        item.nazwa
                    ),
                    decimal(
                        item.ilosc
                    ),
                    escaped(
                        item.jednostka
                    ),
                    decimal(
                        item
                            .cenaJednostkowaNetto
                    ),
                    decimal(
                        item.kosztNetto
                    ),
                    escaped(
                        item.uwagi
                    )
                ]
                .joined(
                    separator: separator
                )
            )
        }

        rows.append(
            [
                "",
                "",
                "",
                "SUMA NETTO",
                "",
                "",
                "",
                decimal(
                    list.sumaNetto
                ),
                ""
            ]
            .joined(
                separator: separator
            )
        )

        let content =
            "\u{FEFF}"
            + rows.joined(
                separator: "\n"
            )

        let url =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName(list)
                )

        guard let data =
            content.data(
                using: .utf8
            )
        else {
            throw ListaZakupowaExportError
                .encodingFailed
        }

        try data.write(
            to: url,
            options: .atomic
        )

        return url
    }

    private static func fileName(
        _ list:
            ListaZakupowaProjektu
    ) -> String {
        let project =
            sanitize(
                list.nazwaProjektu
            )

        let variant =
            sanitize(
                list.wariant.nazwa
            )

        let date =
            Date().formatted(
                .dateTime
                    .year()
                    .month()
                    .day()
            )
            .replacingOccurrences(
                of: " ",
                with: "-"
            )

        return "Lista-zakupowa-\(project)-\(variant)-\(date).csv"
    }

    private static func escaped(
        _ value: String
    ) -> String {
        let replaced =
            value.replacingOccurrences(
                of: "\"",
                with: "\"\""
            )

        if replaced.contains(";")
            || replaced.contains("\"")
            || replaced.contains("\n") {
            return "\"\(replaced)\""
        }

        return replaced
    }

    private static func decimal(
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
                    .fractionLength(
                        0...2
                    )
                )
        )
    }

    private static func sanitize(
        _ value: String
    ) -> String {
        value
            .folding(
                options:
                    .diacriticInsensitive,
                locale: .current
            )
            .components(
                separatedBy:
                    CharacterSet
                        .alphanumerics
                        .union(
                            CharacterSet(
                                charactersIn:
                                    "-_"
                            )
                        )
                        .inverted
            )
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "-"
            )
    }
}

enum ListaZakupowaExportError:
    LocalizedError
{
    case encodingFailed

    var errorDescription: String? {
        "Nie udało się przygotować pliku CSV."
    }
}
