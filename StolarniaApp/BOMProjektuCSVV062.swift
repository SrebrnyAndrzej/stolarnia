import Foundation

enum BOMProjektuCSVV062 {
    static func makeFile(
        for bom: BOMProjektuV062
    ) throws -> URL {
        let header = [
            "Kategoria",
            "Nazwa",
            "Ilość",
            "Jednostka",
            "Cena netto",
            "Koszt netto",
            "Źródło"
        ].joined(separator: ";")

        let rows = bom.pozycje.map { item in
            let flagaBledu =
                item.jestBledemWyceny
                ? "⚠ WYMAGA KOREKTY"
                : ""
            return [
                item.kategoria.nazwa,
                item.nazwa,
                decimal(item.ilosc),
                item.jednostka,
                decimal(item.cenaJednostkowaNetto),
                decimal(item.kosztNetto),
                flagaBledu.isEmpty
                    ? item.zrodlo
                    : "\(flagaBledu) \(item.zrodlo)"
            ]
            .map(escape)
            .joined(separator: ";")
        }

        let content = ([header] + rows).joined(separator: "\n")
        let safeName = bom.nazwaProjektu
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BOM_\(safeName)_\(bom.wariant.rawValue).csv")

        try content.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        return url
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "pl_PL"), value)
    }

    private static func escape(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(normalized)\""
    }
}
