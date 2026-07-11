import Foundation

enum ListaFormatekCSVV070 {
    static func makeFile(
        for list: ListaFormatekProjektuV070,
        travellerProvider:
            ((FormatkaProjektuV070) -> TravellerFormatkiV078)?
            = nil
    ) throws -> URL {
        let separator = ";"

        var rows = [
            [
                "Etykieta",
                "ID produkcyjne",
                "Moduł",
                "Kod",
                "Kategoria",
                "Materiał",
                "Producent",
                "Kod materiału",
                "Długość [mm]",
                "Szerokość [mm]",
                "Grubość [mm]",
                "Powierzchnia [m²]",
                "Kierunek dekoru",
                "Współdzielona",
                "Status produkcji",
                "Recut",
                "Problem",
                "Notatka",
                "Aktualizacja statusu",
                "QR payload"
            ]
            .joined(separator: separator)
        ]

        for item in list.formatki {
            let traveller =
                travellerProvider?(item)

            rows.append(
                [
                    escape(item.etykieta),
                    escape(item.identyfikatorProdukcyjnyV078),
                    escape(item.nazwaModulu),
                    escape(item.kodKomponentu),
                    escape(item.kategoria.nazwa),
                    escape(item.material.nazwa),
                    escape(item.material.producent),
                    escape(item.material.kod),
                    decimal(item.dlugoscMM),
                    decimal(item.szerokoscMM),
                    decimal(item.gruboscMM),
                    decimal(item.powierzchniaM2, digits: 4),
                    escape(item.kierunekDekoru.nazwa),
                    item.wspoldzielona ? "tak" : "nie",
                    escape(
                        traveller?
                            .status
                            .nazwa
                        ?? ""
                    ),
                    traveller
                        .map {
                            String(
                                $0.liczbaRecut
                            )
                        }
                    ?? "",
                    escape(
                        traveller?
                            .opisProblemu
                        ?? ""
                    ),
                    escape(
                        traveller?
                            .notatka
                        ?? ""
                    ),
                    traveller
                        .map {
                            date(
                                $0.dataAktualizacji
                            )
                        }
                    ?? "",
                    escape(item.qrPayloadV078)
                ]
                .joined(separator: separator)
            )
        }

        let content =
            "\u{FEFF}"
            + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "Formatki-\(safe(list.nazwaProjektu)).csv"
            )

        guard let data = content.data(using: .utf8) else {
            throw ListaFormatekCSVErrorV070.encodingFailed
        }

        try data.write(to: url, options: .atomic)
        return url
    }

    private static func decimal(
        _ value: Double,
        digits: Int = 1
    ) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...digits))
        )
    }

    private static func date(
        _ value: Date
    ) -> String {
        value.formatted(
            .dateTime
                .locale(
                    Locale(
                        identifier:
                            "pl_PL"
                    )
                )
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(
            of: "\"",
            with: "\"\""
        )

        if escaped.contains(";")
            || escaped.contains("\"")
            || escaped.contains("\n") {
            return "\"\(escaped)\""
        }

        return escaped
    }

    private static func safe(_ value: String) -> String {
        value
            .folding(
                options: .diacriticInsensitive,
                locale: .current
            )
            .components(
                separatedBy:
                    CharacterSet.alphanumerics
                    .union(
                        CharacterSet(
                            charactersIn: "-_"
                        )
                    )
                    .inverted
            )
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

enum ListaFormatekCSVErrorV070:
    LocalizedError
{
    case encodingFailed

    var errorDescription: String? {
        "Nie udało się zakodować listy formatek do UTF-8."
    }
}
