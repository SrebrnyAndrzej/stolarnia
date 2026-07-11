import Foundation

enum ObrobkiCNCCSVV073 {
    static func text(report: RaportObrobekCNCV073) -> String {
        var rows: [String] = [
            row(["PROJEKT", report.nazwaProjektu]),
            row(["DATA", report.dataUtworzenia.formatted(date: .numeric, time: .shortened)]),
            row(["FORMATKI Z OBRÓBKĄ", "\(report.liczbaFormatekZObrobka)"]),
            row(["LICZBA OPERACJI", "\(report.liczbaOperacji)"]),
            row(["DO WERYFIKACJI", "\(report.liczbaDoWeryfikacji)"]),
            row(["BŁĘDY", "\(report.liczbaBledow)"]),
            "",
            row([
                "Etykieta", "Moduł", "Kod komponentu", "Rola", "Kategoria", "Materiał",
                "Długość [mm]", "Szerokość [mm]", "Grubość [mm]",
                "ID operacji", "Typ", "Powierzchnia", "Nr powtórzenia",
                "X [mm]", "Y [mm]", "Średnica [mm]", "Głębokość [mm]",
                "Długość obróbki [mm]", "Szerokość obróbki [mm]",
                "Rozstaw [mm]", "Kierunek", "Status", "Automatyczna", "Uwagi"
            ])
        ]

        for position in report.pozycje {
            for operation in position.operacje {
                for (index, point) in expandedPoints(operation).enumerated() {
                    rows.append(row([
                        position.formatka.etykieta,
                        position.formatka.nazwaModulu,
                        position.formatka.kodKomponentu,
                        position.formatka.rolaKomponentu.nazwaProdukcyjnaV072,
                        position.formatka.kategoria.nazwa,
                        position.formatka.material.opis,
                        number(position.formatka.dlugoscMM),
                        number(position.formatka.szerokoscMM),
                        number(position.formatka.gruboscMM),
                        operation.id,
                        operation.typ.nazwa,
                        operation.powierzchnia.nazwa,
                        "\(index + 1)",
                        number(point.x),
                        number(point.y),
                        optionalNumber(operation.srednicaMM),
                        number(operation.glebokoscMM),
                        optionalNumber(operation.dlugoscMM),
                        optionalNumber(operation.szerokoscMM),
                        optionalNumber(operation.rozstawMM),
                        operation.kierunekPowtorzen.nazwa,
                        operation.status.nazwa,
                        operation.automatyczna ? "TAK" : "NIE",
                        operation.uwagi
                    ]))
                }
            }
        }

        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    static func data(report: RaportObrobekCNCV073) -> Data {
        Data(text(report: report).utf8)
    }

    static func writeTemporary(report: RaportObrobekCNCV073) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StolarniaAppExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "Obrobki_CNC_\(sanitized(report.nazwaProjektu))_\(formatter.string(from: report.dataUtworzenia)).csv"
        let url = directory.appendingPathComponent(fileName)
        try data(report: report).write(to: url, options: .atomic)
        return url
    }

    private static func expandedPoints(_ operation: OperacjaCNCV073) -> [(x: Double, y: Double)] {
        let count = max(1, operation.liczbaPowtorzen)
        let pitch = operation.rozstawMM ?? 0
        return (0..<count).map { index in
            let distance = Double(index) * pitch
            return operation.kierunekPowtorzen == .wzdluzX
                ? (operation.xMM + distance, operation.yMM)
                : (operation.xMM, operation.yMM + distance)
        }
    }

    private static func row(_ values: [String]) -> String {
        values.map(escaped).joined(separator: ";")
    }

    private static func escaped(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard normalized.contains(";") || normalized.contains("\"") else { return normalized }
        return "\"\(normalized.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return value.formatted(
            .number.locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...2))
        )
    }

    private static func optionalNumber(_ value: Double?) -> String {
        value.map(number) ?? ""
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let result = value.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
            .unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
        return result.isEmpty ? "Projekt" : result
    }
}
