import Foundation

enum MontazPakowanieCSVV076 {
    static func text(
        report:
            RaportMontazuIPakowaniaV076,
        completedOperationIDs:
            Set<String>,
        packedPackageIDs:
            Set<String>,
        travellerProvider:
            ((String) -> TravellerFormatkiV078?)?
            = nil
    ) -> String {
        var rows: [[String]] = []

        rows.append([
            "Typ rekordu",
            "Projekt",
            "Moduł",
            "Etap / typ paczki",
            "Kod / operacja",
            "Status",
            "Etykieta elementu",
            "ID formatki",
            "ID produkcyjne",
            "Kod komponentu",
            "Wymiar",
            "Materiał",
            "Status formatki",
            "Blokada statusu",
            "Recut",
            "Problem formatki",
            "Notatka formatki",
            "Aktualizacja statusu",
            "Masa szacowana [kg]",
            "Obsługa",
            "Informacja"
        ])

        for operation in report.operacje {
            let operationTravellers =
                operation.formatkaIDs
                    .compactMap {
                        travellerProvider?($0)
                    }
            let statusSummary =
                statusSummary(
                    travellers:
                        operationTravellers
                )
            let blockers =
                operationTravellers
                    .filter {
                        !$0.status
                            .gotowaDoPakowaniaV078
                    }

            rows.append([
                "MONTAŻ",
                report.nazwaProjektu,
                operation.nazwaModulu,
                operation.etap.nazwa,
                operation.tytul,
                completedOperationIDs
                    .contains(operation.id)
                    ? "WYKONANO"
                    : "DO WYKONANIA",
                operation
                    .etykietyFormatek
                    .joined(separator: ", "),
                operation
                    .formatkaIDs
                    .joined(separator: ", "),
                operationTravellers
                    .map(\.identyfikatorProdukcyjny)
                    .joined(separator: ", "),
                "",
                "",
                "",
                statusSummary,
                blockers
                    .isEmpty
                    ? ""
                    : blockers
                        .map {
                            "\($0.etykieta): \($0.status.nazwa)"
                        }
                        .joined(separator: ", "),
                recutSummary(
                    travellers:
                        operationTravellers
                ),
                problemSummary(
                    travellers:
                        operationTravellers
                ),
                noteSummary(
                    travellers:
                        operationTravellers
                ),
                dateSummary(
                    travellers:
                        operationTravellers
                ),
                "",
                operation
                    .wymagaWeryfikacji
                    ? "Weryfikacja"
                    : "",
                operation.opis
            ])
        }

        for package in report.paczki {
            for item in package.pozycje {
                let traveller =
                    travellerProvider?(item.id)
                let blokada =
                    statusBlockerText(
                        traveller
                    )

                rows.append([
                    "PACZKA",
                    report.nazwaProjektu,
                    package.nazwaModulu,
                    package.typ.nazwa,
                    package.kod,
                    packedPackageIDs
                        .contains(package.id)
                        ? "SPAKOWANO"
                        : "DO SPAKOWANIA",
                    item.etykieta,
                    item.id,
                    traveller?
                        .identyfikatorProdukcyjny
                        ?? "",
                    item.kodKomponentu,
                    item.opisWymiaru,
                    item.material.opis,
                    traveller?
                        .status
                        .nazwa
                        ?? "",
                    blokada,
                    traveller
                        .map {
                            String(
                                $0.liczbaRecut
                            )
                        }
                        ?? "",
                    traveller?
                        .opisProblemu
                        ?? "",
                    traveller?
                        .notatka
                        ?? "",
                    traveller
                        .map {
                            formatDate(
                                $0.dataAktualizacji
                            )
                        }
                        ?? "",
                    formatDecimal(
                        item.szacowanaMasaKG
                    ),
                    package
                        .sposobPrzenoszenia
                        .nazwa,
                    package
                        .przekraczaLimitMasy
                        ? "Przekroczony limit masy"
                        : ""
                ])
            }
        }

        for warning in report.ostrzezenia {
            rows.append([
                "OSTRZEŻENIE",
                report.nazwaProjektu,
                "",
                warning.poziom.rawValue,
                warning.kodPaczki ?? "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "\(warning.tytul): \(warning.opis)"
            ])
        }

        return rows
            .map {
                $0
                    .map(escape)
                    .joined(separator: ";")
            }
            .joined(separator: "\r\n")
            + "\r\n"
    }

    static func writeTemporary(
        report:
            RaportMontazuIPakowaniaV076,
        completedOperationIDs:
            Set<String>,
        packedPackageIDs:
            Set<String>,
        travellerProvider:
            ((String) -> TravellerFormatkiV078?)?
            = nil
    ) throws -> URL {
        let filename =
            safeFilename(
                report.nazwaProjektu
            )
            + "_montaz_i_pakowanie.csv"
        let url =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    filename,
                    isDirectory: false
                )

        let content =
            "\u{FEFF}"
            + text(
                report: report,
                completedOperationIDs:
                    completedOperationIDs,
                packedPackageIDs:
                    packedPackageIDs,
                travellerProvider:
                    travellerProvider
            )

        guard let data =
                content.data(
                    using: .utf8
                ) else {
            throw MontazPakowanieCSVErrorV076
                .encodingFailed
        }

        try data.write(
            to: url,
            options: .atomic
        )

        return url
    }

    private static func formatDecimal(
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
                        0...3
                    )
                )
        )
    }

    private static func statusSummary(
        travellers:
            [TravellerFormatkiV078]
    ) -> String {
        guard !travellers.isEmpty else {
            return ""
        }

        let grouped =
            Dictionary(
                grouping: travellers,
                by: \.status
            )

        return StatusFormatkiV078
            .allCases
            .compactMap {
                status in

                guard let count =
                        grouped[status]?
                        .count,
                      count > 0
                else {
                    return nil
                }

                return "\(status.nazwa): \(count)"
            }
            .joined(separator: ", ")
    }

    private static func recutSummary(
        travellers:
            [TravellerFormatkiV078]
    ) -> String {
        let total =
            travellers.reduce(0) {
                $0 + $1.liczbaRecut
            }

        return total > 0
            ? String(total)
            : ""
    }

    private static func problemSummary(
        travellers:
            [TravellerFormatkiV078]
    ) -> String {
        travellers
            .filter {
                !$0.opisProblemu
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            }
            .map {
                "\($0.etykieta): \($0.opisProblemu)"
            }
            .joined(separator: " | ")
    }

    private static func noteSummary(
        travellers:
            [TravellerFormatkiV078]
    ) -> String {
        travellers
            .filter {
                !$0.notatka
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            }
            .map {
                "\($0.etykieta): \($0.notatka)"
            }
            .joined(separator: " | ")
    }

    private static func dateSummary(
        travellers:
            [TravellerFormatkiV078]
    ) -> String {
        guard let latest =
                travellers
                .map(\.dataAktualizacji)
                .max()
        else {
            return ""
        }

        return formatDate(latest)
    }

    private static func statusBlockerText(
        _ traveller:
            TravellerFormatkiV078?
    ) -> String {
        guard let traveller else {
            return "Brak karty statusu"
        }

        guard !traveller.status
            .gotowaDoPakowaniaV078
        else {
            return ""
        }

        return traveller.status.nazwa
    }

    private static func formatDate(
        _ value:
            Date
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

    private static func safeFilename(
        _ value: String
    ) -> String {
        let allowed =
            CharacterSet
                .alphanumerics
                .union(
                    CharacterSet(
                        charactersIn:
                            "-_"
                    )
                )

        let scalars = value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .unicodeScalars
            .map {
                allowed.contains($0)
                    ? Character(
                        String($0)
                    )
                    : "_"
            }

        let result =
            String(scalars)
                .replacingOccurrences(
                    of: "__",
                    with: "_"
                )

        return result.isEmpty
            ? "projekt"
            : result
    }

    private static func escape(
        _ value: String
    ) -> String {
        let escaped =
            value.replacingOccurrences(
                of: "\"",
                with: "\"\""
            )

        if escaped.contains(";")
            || escaped.contains("\"")
            || escaped.contains("\n")
            || escaped.contains("\r") {
            return "\"\(escaped)\""
        }

        return escaped
    }
}

enum MontazPakowanieCSVErrorV076:
    LocalizedError
{
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Nie udało się zakodować raportu montażu i pakowania w UTF-8."
        }
    }
}
