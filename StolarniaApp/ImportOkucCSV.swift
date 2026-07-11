import Foundation

enum ImportOkucCSV {
    static func parse(
        data: Data
    ) throws -> [OkucieMeblowe] {
        guard let text =
            decode(data)
        else {
            throw ImportOkucCSVError.invalidEncoding
        }

        let lines =
            text
                .components(
                    separatedBy:
                        .newlines
                )
                .filter {
                    !$0
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                }

        guard let headerLine =
            lines.first
        else {
            throw ImportOkucCSVError.emptyFile
        }

        let separator =
            detectSeparator(
                in: headerLine
            )

        let headers =
            split(
                headerLine,
                separator:
                    separator
            )
            .map(normalize)

        var result:
            [OkucieMeblowe] = []

        for line in lines.dropFirst() {
            let columns =
                split(
                    line,
                    separator:
                        separator
                )

            var values:
                [String: String] = [:]

            for (
                index,
                header
            ) in headers.enumerated() {
                guard index
                    < columns.count
                else {
                    continue
                }

                values[header] =
                    columns[index]
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
            }

            let code =
                value(
                    values,
                    keys: [
                        "kod",
                        "sku",
                        "symbol",
                        "indeks"
                    ]
                )

            let name =
                value(
                    values,
                    keys: [
                        "nazwa",
                        "produkt",
                        "opis"
                    ]
                )

            guard !code.isEmpty,
                  !name.isEmpty
            else {
                continue
            }

            var item =
                OkucieMeblowe()

            item.kod = code
            item.nazwa = name
            item.producent =
                value(
                    values,
                    keys: [
                        "producent",
                        "marka"
                    ]
                )

            item.dostawca =
                value(
                    values,
                    keys: [
                        "dostawca",
                        "hurtownia"
                    ]
                )

            item.typ =
                parseType(
                    value(
                        values,
                        keys: [
                            "typ",
                            "kategoria"
                        ]
                    )
                )

            item.jednostka =
                parseUnit(
                    value(
                        values,
                        keys: [
                            "jednostka",
                            "jm"
                        ]
                    )
                )

            item.cenaNetto =
                number(
                    value(
                        values,
                        keys: [
                            "cenanetto",
                            "cena",
                            "netto"
                        ]
                    )
                )

            item.vatProcent =
                number(
                    value(
                        values,
                        keys: ["vat"]
                    ),
                    fallback: 23
                )

            item.rabatProcent =
                number(
                    value(
                        values,
                        keys: ["rabat"]
                    )
                )

            item.system =
                value(
                    values,
                    keys: ["system"]
                )

            item.dlugoscMM =
                number(
                    value(
                        values,
                        keys: [
                            "dlugosc",
                            "dlugoscmm"
                        ]
                    )
                )

            item.nosnoscKG =
                number(
                    value(
                        values,
                        keys: [
                            "nosnosc",
                            "nosnosckg"
                        ]
                    )
                )

            item.katOtwarciaStopnie =
                number(
                    value(
                        values,
                        keys: [
                            "kat",
                            "katotwarcia"
                        ]
                    )
                )

            item.poziomWyceny =
                parseTier(
                    value(
                        values,
                        keys: [
                            "poziom",
                            "wariant"
                        ]
                    )
                )

            result.append(item)
        }

        return result
    }

    private static func decode(
        _ data: Data
    ) -> String? {
        String(
            data: data,
            encoding: .utf8
        )
        ?? String(
            data: data,
            encoding:
                .windowsCP1250
        )
    }

    private static func detectSeparator(
        in line: String
    ) -> Character {
        let candidates:
            [Character] = [
                ";",
                ",",
                "\t"
            ]

        return candidates.max {
            left,
            right in

            line.filter {
                $0 == left
            }.count
            <
            line.filter {
                $0 == right
            }.count
        }
        ?? ";"
    }

    private static func split(
        _ line: String,
        separator: Character
    ) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character
                == separator
                && !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        result.append(current)
        return result
    }

    private static func normalize(
        _ value: String
    ) -> String {
        value
            .lowercased()
            .folding(
                options:
                    .diacriticInsensitive,
                locale: .current
            )
            .replacingOccurrences(
                of: " ",
                with: ""
            )
            .replacingOccurrences(
                of: "_",
                with: ""
            )
    }

    private static func value(
        _ values:
            [String: String],
        keys: [String]
    ) -> String {
        for key in keys {
            if let result =
                values[
                    normalize(key)
                ],
               !result.isEmpty {
                return result
            }
        }

        return ""
    }

    private static func number(
        _ value: String,
        fallback: Double = 0
    ) -> Double {
        let normalized =
            value
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        return Double(normalized)
        ?? fallback
    }

    private static func parseType(
        _ value: String
    ) -> TypOkuciaMeblowego {
        let normalized =
            normalize(value)

        return TypOkuciaMeblowego
            .allCases
            .first {
                normalize($0.nazwa)
                    == normalized
                || normalize($0.rawValue)
                    == normalized
            }
        ?? .inne
    }

    private static func parseUnit(
        _ value: String
    ) -> JednostkaOkucia {
        let normalized =
            normalize(value)

        if normalized.contains("para") {
            return .para
        }

        if normalized.contains("kpl") {
            return .komplet
        }

        if normalized.contains("mb")
            || normalized.contains("metr") {
            return .metr
        }

        if normalized.contains("opak") {
            return .opakowanie
        }

        return .sztuka
    }

    private static func parseTier(
        _ value: String
    ) -> PoziomWycenyOkucia {
        let normalized =
            normalize(value)

        return PoziomWycenyOkucia
            .allCases
            .first {
                normalize($0.nazwa)
                    == normalized
                || normalize($0.rawValue)
                    == normalized
            }
        ?? .standard
    }
}

enum ImportOkucCSVError:
    LocalizedError
{
    case invalidEncoding
    case emptyFile

    var errorDescription:
        String?
    {
        switch self {
        case .invalidEncoding:
            return "Nie udało się odczytać kodowania pliku CSV."
        case .emptyFile:
            return "Plik CSV jest pusty."
        }
    }
}
