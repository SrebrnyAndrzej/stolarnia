import Foundation

// MARK: - Error

enum ImportCennikuCSVError: LocalizedError {
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

// MARK: - Models

struct AktualizacjaCeny: Identifiable {
    let id = UUID()
    let material: MaterialStolarski
    let nowaCenaNetto: Double
    let nowyRabatProcent: Double?
    let nowyVatProcent: Double?
    /// "kod" lub "nazwa" — sposób dopasowania do bazy
    let zrodloMappingu: String

    var staraCenaNetto: Double { material.cenaNetto }

    var deltaZnakString: String {
        let delta = nowaCenaNetto - staraCenaNetto
        if abs(delta) < 0.005 { return "=" }
        return delta > 0 ? "↑" : "↓"
    }

    var zmianaProcent: Double {
        guard staraCenaNetto > 0 else { return 0 }
        return (nowaCenaNetto - staraCenaNetto) / staraCenaNetto * 100
    }
}

struct RaportImportuCennika: Identifiable {
    let id = UUID()
    let dopasowane: [AktualizacjaCeny]
    let niedopasowane: [String]

    var isEmpty: Bool { dopasowane.isEmpty }

    var komunikat: String {
        if dopasowane.isEmpty {
            return "Żaden materiał z pliku nie pasuje do bazy. Sprawdź nagłówki kolumn."
        }
        var msg = "Dopasowano \(dopasowane.count) materiałów do aktualizacji cen."
        if !niedopasowane.isEmpty {
            msg += "\n\(niedopasowane.count) pozycji z pliku nie pasuje do żadnego rekordu w bazie."
        }
        return msg
    }
}

// MARK: - Parser

enum ImportCennikuCSV {

    // MARK: Public API

    static func wczytaj(
        z url: URL,
        materialy: [MaterialStolarski]
    ) throws -> RaportImportuCennika {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw ImportCennikuCSVError.pustyPlik }

        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1250)
        guard let text else { throw ImportCennikuCSVError.nieprawidlowyFormat }

        return try parsuj(text, materialy: materialy)
    }

    static func parsuj(
        _ text: String,
        materialy: [MaterialStolarski]
    ) throws -> RaportImportuCennika {
        let cleaned = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        let lines = cleaned
            .components(separatedBy: .newlines)
            .filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

        guard let first = lines.first else {
            throw ImportCennikuCSVError.pustyPlik
        }

        let sep = wykryjSeparator(first)
        let header = splitCSVLine(first, separator: sep).map(normalizujNaglowek)
        guard !header.isEmpty else {
            throw ImportCennikuCSVError.brakNaglowka
        }

        // Buduj mapy do szybkiego wyszukiwania
        var byKod: [String: [MaterialStolarski]] = [:]
        var byNazwa: [String: [MaterialStolarski]] = [:]
        for m in materialy {
            let k = m.kod.trimmingCharacters(in: .whitespaces).lowercased()
            let n = m.nazwa.trimmingCharacters(in: .whitespaces).lowercased()
            if !k.isEmpty { byKod[k, default: []].append(m) }
            if !n.isEmpty { byNazwa[n, default: []].append(m) }
        }

        var dopasowane: [AktualizacjaCeny] = []
        var niedopasowane: [String] = []
        var seenMaterialIDs = Set<UUID>()

        for line in lines.dropFirst() {
            let values = splitCSVLine(line, separator: sep)
            guard !values.isEmpty else { continue }

            var row: [String: String] = [:]
            for i in header.indices {
                let v = i < values.count ? values[i] : ""
                row[header[i]] = v.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Identyfikator pozycji
            let kodCSV = value(
                row,
                keys: [
                    "kod", "symbol", "sku", "indeks",
                    "nr", "nrkatalogowy", "kodproducenta",
                    "index", "artykul", "id"
                ]
            ) ?? ""
            let nazwaCSV = value(
                row,
                keys: [
                    "nazwa", "opis", "produkt", "opistowarou",
                    "name", "description", "towar", "artykul2"
                ]
            ) ?? ""

            guard !kodCSV.isEmpty || !nazwaCSV.isEmpty else { continue }

            // Dopasowanie — kod ma pierwszeństwo przed nazwą
            let candidates: [MaterialStolarski]
            let zrodlo: String
            if !kodCSV.isEmpty,
               let matched = byKod[kodCSV.lowercased()]
            {
                candidates = matched
                zrodlo = "kod"
            } else if !nazwaCSV.isEmpty,
                      let matched = byNazwa[nazwaCSV.lowercased()]
            {
                candidates = matched
                zrodlo = "nazwa"
            } else {
                let label = kodCSV.isEmpty ? nazwaCSV : kodCSV
                if !label.isEmpty { niedopasowane.append(label) }
                continue
            }

            // Wyciągnij cenę — netto ma pierwszeństwo, brutto jako fallback
            let cenaNetto = cena(
                row,
                keys: [
                    "cenanetto", "netto", "cena",
                    "price", "cenazakupu", "cenakupna",
                    "cenabazowanetto", "netprice"
                ]
            )
            let cenaBrutto = cena(
                row,
                keys: [
                    "cenabrutto", "brutto", "gross",
                    "cenadetaliczna", "cenasugerowana",
                    "grossPrice", "retailprice"
                ]
            )
            let vat = procent(
                row,
                keys: ["vat", "stawkavat", "podatek", "taxrate", "vatrate"]
            )
            let rabat = procent(
                row,
                keys: ["rabat", "rabatprocent", "discount", "znizka", "upust"]
            )

            let finalNetto: Double?
            if let n = cenaNetto, n > 0 {
                finalNetto = n
            } else if let b = cenaBrutto, b > 0 {
                let vatRate = vat ?? 23.0
                finalNetto = b / (1 + vatRate / 100)
            } else {
                finalNetto = nil
            }

            guard let finalNetto, finalNetto > 0 else {
                let label = kodCSV.isEmpty ? nazwaCSV : kodCSV
                if !label.isEmpty { niedopasowane.append(label) }
                continue
            }

            for material in candidates {
                // Jeden materiał może trafić tylko raz
                guard !seenMaterialIDs.contains(material.id) else { continue }
                seenMaterialIDs.insert(material.id)

                let cenaBezZmiany = abs(material.cenaNetto - finalNetto) < 0.005
                let rabatBezZmiany = rabat == nil || abs(material.rabatProcent - (rabat ?? 0)) < 0.005
                let vatBezZmiany = vat == nil || abs(material.vatProcent - (vat ?? 0)) < 0.005

                // Pomijaj jeśli nic się nie zmienia
                if cenaBezZmiany && rabatBezZmiany && vatBezZmiany { continue }

                dopasowane.append(
                    AktualizacjaCeny(
                        material: material,
                        nowaCenaNetto: finalNetto,
                        nowyRabatProcent: rabat,
                        nowyVatProcent: vat,
                        zrodloMappingu: zrodlo
                    )
                )
            }
        }

        // Sortuj: największe zmiany procentowe na górze
        dopasowane.sort {
            abs($0.zmianaProcent) > abs($1.zmianaProcent)
        }

        return RaportImportuCennika(
            dopasowane: dopasowane,
            niedopasowane: niedopasowane
        )
    }

    // MARK: - CSV Helpers (niezależna kopia — nie miesza się z ImportMaterialowCSV)

    private static func wykryjSeparator(_ line: String) -> Character {
        let semicolons = line.filter { $0 == ";" }.count
        let commas = line.filter { $0 == "," }.count
        let tabs = line.filter { $0 == "\t" }.count
        if tabs >= semicolons && tabs >= commas { return "\t" }
        return semicolons >= commas ? ";" : ","
    }

    private static func splitCSVLine(
        _ line: String,
        separator: Character
    ) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if ch == "\"" {
                if inQuotes {
                    var copy = iterator
                    if let next = copy.next(), next == "\"" {
                        current.append("\"")
                        _ = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if ch == separator, !inQuotes {
                values.append(
                    current.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                current = ""
            } else {
                current.append(ch)
            }
        }
        values.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return values
    }

    private static func normalizujNaglowek(_ value: String) -> String {
        value
            .lowercased()
            .folding(
                options: .diacriticInsensitive,
                locale: Locale(identifier: "pl_PL")
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private static func value(
        _ row: [String: String],
        keys: [String]
    ) -> String? {
        for key in keys {
            let norm = normalizujNaglowek(key)
            if let v = row[norm], !v.isEmpty { return v }
        }
        return nil
    }

    private static func cena(
        _ row: [String: String],
        keys: [String]
    ) -> Double? {
        guard let raw = value(row, keys: keys) else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "\u{00A0}", with: "") // non-breaking space
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "PLN", with: "")
            .replacingOccurrences(of: "zł", with: "")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(cleaned).flatMap { $0 > 0 ? $0 : nil }
    }

    private static func procent(
        _ row: [String: String],
        keys: [String]
    ) -> Double? {
        guard let raw = value(row, keys: keys) else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(cleaned)
    }
}
