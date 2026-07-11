import Foundation

enum ImportMaterialowCSVError:
    LocalizedError
{
    case pustyPlik
    case brakNaglowka
    case nieprawidlowyFormat

    var errorDescription: String? {
        switch self {
        case .pustyPlik:
            return "Plik CSV jest pusty."
        case .brakNaglowka:
            return "Nie znaleziono nagłówka CSV."
        case .nieprawidlowyFormat:
            return "Nie udało się odczytać danych CSV."
        }
    }
}

enum ImportMaterialowCSV {
    static func wczytaj(
        z url: URL
    ) throws -> [MaterialStolarski] {
        let access =
            url.startAccessingSecurityScopedResource()

        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data =
            try Data(contentsOf: url)

        guard !data.isEmpty else {
            throw ImportMaterialowCSVError.pustyPlik
        }

        let text =
            String(
                data: data,
                encoding: .utf8
            )
            ?? String(
                data: data,
                encoding:
                    .windowsCP1250
            )

        guard let text else {
            throw ImportMaterialowCSVError.nieprawidlowyFormat
        }

        return try parsuj(text)
    }

    static func parsuj(
        _ text: String
    ) throws -> [MaterialStolarski] {
        let cleaned =
            text.replacingOccurrences(
                of: "\u{FEFF}",
                with: ""
            )

        let lines =
            cleaned
                .components(
                    separatedBy:
                        .newlines
                )
                .filter {
                    !$0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ).isEmpty
                }

        guard let first =
            lines.first
        else {
            throw ImportMaterialowCSVError.pustyPlik
        }

        let separator =
            wykryjSeparator(
                first
            )
        let header =
            splitCSVLine(
                first,
                separator: separator
            )
            .map(normalizujNaglowek)

        guard !header.isEmpty else {
            throw ImportMaterialowCSVError.brakNaglowka
        }

        var result:
            [MaterialStolarski] = []

        for line in lines.dropFirst() {
            let values =
                splitCSVLine(
                    line,
                    separator: separator
                )

            guard !values.isEmpty else {
                continue
            }

            var row:
                [String: String] = [:]

            for index in header.indices {
                row[header[index]] =
                    index < values.count
                    ? values[index]
                    : ""
            }

            guard
                let kod =
                    value(
                        row,
                        keys: [
                            "kod",
                            "symbol",
                            "sku",
                            "indeks"
                        ]
                    ),
                let nazwa =
                    value(
                        row,
                        keys: [
                            "nazwa",
                            "produkt",
                            "opis"
                        ]
                    ),
                !kod.isEmpty,
                !nazwa.isEmpty
            else {
                continue
            }

            result.append(
                MaterialStolarski(
                    kod: kod,
                    nazwa: nazwa,
                    producent:
                        value(
                            row,
                            keys: [
                                "producent",
                                "marka"
                            ]
                        ) ?? "",
                    dostawca:
                        value(
                            row,
                            keys: [
                                "dostawca",
                                "hurtownia"
                            ]
                        ) ?? "",
                    typ:
                        typMaterialu(
                            value(
                                row,
                                keys: [
                                    "typ",
                                    "kategoria"
                                ]
                            )
                        ),
                    dekor:
                        value(
                            row,
                            keys: [
                                "dekor",
                                "kolor"
                            ]
                        ) ?? "",
                    gruboscMM:
                        number(
                            value(
                                row,
                                keys: [
                                    "grubosc",
                                    "gruboscmm",
                                    "thickness"
                                ]
                            )
                        ),
                    szerokoscArkuszaMM:
                        number(
                            value(
                                row,
                                keys: [
                                    "szerokosc",
                                    "szerokoscarkusza",
                                    "width"
                                ]
                            )
                        ),
                    wysokoscArkuszaMM:
                        number(
                            value(
                                row,
                                keys: [
                                    "wysokosc",
                                    "wysokoscarkusza",
                                    "height"
                                ]
                            )
                        ),
                    jednostka:
                        jednostka(
                            value(
                                row,
                                keys: [
                                    "jednostka",
                                    "jm"
                                ]
                            )
                        ),
                    cenaNetto:
                        number(
                            value(
                                row,
                                keys: [
                                    "cenanetto",
                                    "cena",
                                    "netto"
                                ]
                            )
                        ),
                    vatProcent:
                        number(
                            value(
                                row,
                                keys: [
                                    "vat",
                                    "vatprocent"
                                ]
                            ),
                            defaultValue: 23
                        ),
                    rabatProcent:
                        number(
                            value(
                                row,
                                keys: [
                                    "rabat",
                                    "rabatprocent"
                                ]
                            )
                        ),
                    aktywny:
                        boolValue(
                            value(
                                row,
                                keys: [
                                    "aktywny",
                                    "active"
                                ]
                            ),
                            defaultValue: true
                        ),
                    kierunekDekoru:
                        boolValue(
                            value(
                                row,
                                keys: [
                                    "kierunekdekoru",
                                    "kierunek",
                                    "grain"
                                ]
                            )
                        ),
                    kolorHEX:
                        value(
                            row,
                            keys: [
                                "kolorhex",
                                "hex"
                            ]
                        ) ?? "#CCCCCC",
                    notatki:
                        value(
                            row,
                            keys: [
                                "notatki",
                                "uwagi"
                            ]
                        ) ?? ""
                )
            )
        }

        return result
    }

    private static func wykryjSeparator(
        _ line: String
    ) -> Character {
        let semicolons =
            line.filter {
                $0 == ";"
            }.count
        let commas =
            line.filter {
                $0 == ","
            }.count
        let tabs =
            line.filter {
                $0 == "\t"
            }.count

        if tabs >= semicolons
            && tabs >= commas {
            return "\t"
        }

        return semicolons >= commas
            ? ";"
            : ","
    }

    private static func splitCSVLine(
        _ line: String,
        separator: Character
    ) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        var iterator =
            line.makeIterator()

        while let character =
            iterator.next() {
            if character == "\"" {
                if inQuotes {
                    var copy = iterator
                    if let next =
                        copy.next(),
                       next == "\"" {
                        current.append("\"")
                        _ = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if character
                == separator,
                !inQuotes {
                values.append(
                    current.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                )
                current = ""
            } else {
                current.append(character)
            }
        }

        values.append(
            current.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
        )

        return values
    }

    private static func normalizujNaglowek(
        _ value: String
    ) -> String {
        value
            .lowercased()
            .folding(
                options:
                    .diacriticInsensitive,
                locale:
                    Locale(
                        identifier: "pl_PL"
                    )
            )
            .replacingOccurrences(
                of: " ",
                with: ""
            )
            .replacingOccurrences(
                of: "_",
                with: ""
            )
            .replacingOccurrences(
                of: "-",
                with: ""
            )
    }

    private static func value(
        _ row:
            [String: String],
        keys: [String]
    ) -> String? {
        for key in keys {
            let normalized =
                normalizujNaglowek(
                    key
                )

            if let value =
                row[normalized],
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private static func number(
        _ value: String?,
        defaultValue: Double = 0
    ) -> Double {
        guard let value else {
            return defaultValue
        }

        let cleaned =
            value
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
                .filter {
                    $0.isNumber
                    || $0 == "."
                    || $0 == "-"
                }

        return Double(cleaned)
            ?? defaultValue
    }

    private static func boolValue(
        _ value: String?,
        defaultValue: Bool = false
    ) -> Bool {
        guard let value else {
            return defaultValue
        }

        switch value
            .lowercased()
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            ) {
        case "1",
             "true",
             "tak",
             "yes",
             "y":
            return true
        case "0",
             "false",
             "nie",
             "no",
             "n":
            return false
        default:
            return defaultValue
        }
    }

    private static func typMaterialu(
        _ value: String?
    ) -> TypMaterialuStolarskiego {
        let text =
            value?
                .lowercased()
                .folding(
                    options:
                        .diacriticInsensitive,
                    locale:
                        Locale(
                            identifier: "pl_PL"
                        )
                )
            ?? ""

        if text.contains("hdf") {
            return .hdf
        }
        if text.contains("mdf") {
            return .mdf
        }
        if text.contains("sklej") {
            return .sklejka
        }
        if text.contains("front") {
            return .front
        }
        if text.contains("kompakt") {
            return .blatKompaktowy
        }
        if text.contains("kamien")
            || text.contains("spiek") {
            return .blatKamienny
        }
        if text.contains("blat") {
            return .blatLaminowany
        }
        if text.contains("obrzez") {
            return .obrzeze
        }
        if text.contains("szkl") {
            return .szklo
        }
        if text.contains("profil") {
            return .profil
        }
        if text.contains("plyt")
            || text.contains("lamin") {
            return .plytaLaminowana
        }

        return .inne
    }

    private static func jednostka(
        _ value: String?
    ) -> JednostkaCenyMaterialu {
        let text =
            value?
                .lowercased()
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )
            ?? ""

        if text.contains("m2")
            || text.contains("m²") {
            return .metrKwadratowy
        }
        if text.contains("mb")
            || text.contains("metr") {
            return .metrBiezacy
        }
        if text.contains("kg") {
            return .kilogram
        }

        return .sztuka
    }
}
