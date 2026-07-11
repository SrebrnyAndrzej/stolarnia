import Foundation

enum OkleinowanieCSVV072 {
    static func makeFile(for raport: RaportOkleinowaniaV072) throws -> URL {
        let separator = ";"
        var rows: [String] = []

        rows.append([
            "ZAPOTRZEBOWANIE NA OBRZEŻA", "", "", "", "", "", "", "", ""
        ].joined(separator: separator))
        rows.append([
            "Rodzaj", "Producent", "Kod", "Nazwa", "Kolor HEX",
            "Krawędzie [szt.]", "Długość netto [m]",
            "Długość technologiczna [m]", "Do zakupu [m]"
        ].joined(separator: separator))

        for item in raport.zapotrzebowanie {
            rows.append([
                escape(item.specyfikacja.rodzaj.nazwa),
                escape(item.specyfikacja.producent),
                escape(item.specyfikacja.kod),
                escape(item.specyfikacja.nazwa),
                escape(item.specyfikacja.kolorHEX),
                String(item.liczbaKrawedzi),
                decimal(item.dlugoscNettoM, digits: 3),
                decimal(item.dlugoscTechnologicznaM, digits: 3),
                decimal(item.dlugoscZakupuM, digits: 3)
            ].joined(separator: separator))
        }

        rows.append("")
        rows.append([
            "SZCZEGÓŁOWA LISTA OKLEINOWANIA", "", "", "", "", "",
            "", "", "", "", "", ""
        ].joined(separator: separator))
        rows.append([
            "Etykieta", "Moduł", "Kod komponentu", "Rola", "Kategoria",
            "Materiał", "Krawędź", "Długość netto [mm]", "Rodzaj obrzeża",
            "Kod obrzeża", "Naddatek [mm]", "Długość technologiczna [mm]"
        ].joined(separator: separator))

        for item in raport.pozycje {
            for operation in item.obrobki {
                guard let edgeBand = operation.obrzeze else { continue }
                let net = operation.krawedz.dlugoscMM(dla: item.formatka)
                let tech = net + raport.ustawienia.naddatekNaKrawedzMM

                rows.append([
                    escape(item.formatka.etykieta),
                    escape(item.formatka.nazwaModulu),
                    escape(item.formatka.kodKomponentu),
                    escape(item.formatka.rolaKomponentu.nazwaProdukcyjnaV072),
                    escape(item.formatka.kategoria.nazwa),
                    escape(item.formatka.material.opis),
                    escape(operation.krawedz.nazwa),
                    decimal(net, digits: 1),
                    escape(edgeBand.rodzaj.nazwa),
                    escape(edgeBand.kod),
                    decimal(raport.ustawienia.naddatekNaKrawedzMM, digits: 1),
                    decimal(tech, digits: 1)
                ].joined(separator: separator))
            }
        }

        rows.append("")
        rows.append("USTAWIENIA")
        rows.append([
            "Naddatek na krawędź [mm]",
            decimal(raport.ustawienia.naddatekNaKrawedzMM, digits: 1)
        ].joined(separator: separator))
        rows.append([
            "Zapas [%]",
            decimal(raport.ustawienia.zapasProcent, digits: 1)
        ].joined(separator: separator))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Okleinowanie_\(safeFileName(raport.nazwaProjektu)).csv"
        )
        guard let data = ("\u{FEFF}" + rows.joined(separator: "\n"))
            .data(using: .utf8) else {
            throw OkleinowanieCSVErrorV072.encodingFailed
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: "\"\"")
        return normalized.contains(";") || normalized.contains("\"")
            ? "\"\(normalized)\""
            : normalized
    }

    private static func decimal(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "0" }
        return value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...digits))
        )
    }

    private static func safeFileName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let result = value.components(separatedBy: forbidden)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Projekt" : result
    }
}

enum OkleinowanieCSVErrorV072: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "Nie udało się zakodować raportu CSV."
    }
}
