import Foundation

enum RozkrojPlytCSVV071 {
    static func makeFile(
        for report: RaportRozkrojuPlytV071
    ) throws -> URL {
        let separator = ";"
        var rows: [String] = []

        rows.append(
            [
                "ZAPOTRZEBOWANIE NA PŁYTY",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                ""
            ]
            .joined(separator: separator)
        )
        rows.append(
            [
                "Materiał",
                "Producent",
                "Kod",
                "Grubość [mm]",
                "Format arkusza",
                "Arkusze [szt.]",
                "Powierzchnia formatek [m²]",
                "Powierzchnia zakupu [m²]",
                "Odpad [m²]",
                "Wykorzystanie [%]"
            ]
            .joined(separator: separator)
        )

        for item in report.zapotrzebowanie {
            rows.append(
                [
                    escape(item.grupa.material.nazwa),
                    escape(item.grupa.material.producent),
                    escape(item.grupa.material.kod),
                    decimal(item.grupa.gruboscMM),
                    escape(item.formatArkusza),
                    String(item.liczbaArkuszy),
                    decimal(
                        item.powierzchniaFormatekM2,
                        digits: 4
                    ),
                    decimal(
                        item.powierzchniaZakupuM2,
                        digits: 4
                    ),
                    decimal(
                        item.odpadM2,
                        digits: 4
                    ),
                    decimal(
                        item.wykorzystanieProcent,
                        digits: 2
                    )
                ]
                .joined(separator: separator)
            )
        }

        rows.append("")
        rows.append(
            [
                "ROZMIESZCZENIE FORMATEK",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                ""
            ]
            .joined(separator: separator)
        )
        rows.append(
            [
                "Arkusz",
                "Dekor",
                "Producent",
                "Kod dekoru",
                "Grubość [mm]",
                "Etykieta",
                "ID produkcyjne",
                "Moduł",
                "Kod komponentu",
                "X [mm]",
                "Y [mm]",
                "Szerokość na arkuszu [mm]",
                "Długość na arkuszu [mm]",
                "Obrót",
                "QR payload"
            ]
            .joined(separator: separator)
        )

        for sheet in report.arkusze {
            for placement in sheet.polozenia {
                rows.append(
                    [
                        String(sheet.numer),
                        escape(sheet.grupa.material.nazwa),
                        escape(sheet.grupa.material.producent),
                        escape(sheet.grupa.material.kod),
                        decimal(sheet.grupa.gruboscMM),
                        escape(placement.formatka.etykieta),
                        escape(
                            placement
                                .formatka
                                .identyfikatorProdukcyjnyV078
                        ),
                        escape(placement.formatka.nazwaModulu),
                        escape(placement.formatka.kodKomponentu),
                        decimal(placement.xMM),
                        decimal(placement.yMM),
                        decimal(
                            placement.szerokoscNaArkuszuMM
                        ),
                        decimal(
                            placement.dlugoscNaArkuszuMM
                        ),
                        placement.obrocona
                            ? "90°"
                            : "0°",
                        escape(
                            placement
                                .formatka
                                .qrPayloadV078
                        )
                    ]
                    .joined(separator: separator)
                )
            }
        }

        if !report.nierozmieszczone.isEmpty {
            rows.append("")
            rows.append(
                [
                    "NIEROZMIESZCZONE",
                    "",
                    "",
                    "",
                    ""
                ]
                .joined(separator: separator)
            )
            rows.append(
                [
                    "Etykieta",
                    "ID produkcyjne",
                    "Moduł",
                    "Kod",
                    "Wymiar",
                    "Powód",
                    "QR payload"
                ]
                .joined(separator: separator)
            )

            for item in report.nierozmieszczone {
                rows.append(
                    [
                        escape(item.formatka.etykieta),
                        escape(
                            item
                                .formatka
                                .identyfikatorProdukcyjnyV078
                        ),
                        escape(item.formatka.nazwaModulu),
                        escape(item.formatka.kodKomponentu),
                        escape(item.formatka.opisWymiaru),
                        escape(item.powod),
                        escape(
                            item
                                .formatka
                                .qrPayloadV078
                        )
                    ]
                    .joined(separator: separator)
                )
            }
        }

        let content =
            "\u{FEFF}"
            + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "Rozkroj-\(safe(report.nazwaProjektu)).csv"
            )

        guard let data = content.data(using: .utf8) else {
            throw RozkrojPlytCSVErrorV071.encodingFailed
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

    private static func escape(
        _ value: String
    ) -> String {
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

    private static func safe(
        _ value: String
    ) -> String {
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

enum RozkrojPlytCSVErrorV071:
    LocalizedError
{
    case encodingFailed

    var errorDescription: String? {
        "Nie udało się zakodować raportu rozkroju do UTF-8."
    }
}
