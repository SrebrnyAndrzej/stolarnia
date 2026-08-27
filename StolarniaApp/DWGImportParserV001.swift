import Foundation

/// Parser neutralnego JSON-a importu DWG.
/// Nie zajmuje się dopasowaniem do biblioteki — to zadanie matchera.
enum DWGImportParserV001 {
    /// Wczytuje dokument z URL zwróconego przez `DocumentPicker`
    /// z poszanowaniem security-scoped access (analogicznie jak `ImportMaterialowCSV`).
    static func wczytaj(z url: URL) throws -> DWGImportDocumentV001 {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BladImportuDWGV001.brakDostepuDoPliku(error.localizedDescription)
        }

        guard !data.isEmpty else {
            throw BladImportuDWGV001.pustyPlik
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let document: DWGImportDocumentV001
        do {
            document = try decoder.decode(DWGImportDocumentV001.self, from: data)
        } catch let decodingError {
            throw BladImportuDWGV001.blednyJSON(
                decodingError.localizedDescription
            )
        }

        guard !document.detectedItems.isEmpty else {
            throw BladImportuDWGV001.brakObiektow
        }

        return document
    }

    /// Ścieżka fixture-owa — wczytuje z bundle-owego zasobu (do testów manualnych).
    static func wczytajZBundle(
        nazwa: String,
        bundle: Bundle = .main
    ) throws -> DWGImportDocumentV001 {
        guard let url = bundle.url(forResource: nazwa, withExtension: "json") else {
            throw BladImportuDWGV001.brakDostepuDoPliku(
                "Zasób \(nazwa).json nie istnieje w bundle."
            )
        }
        return try wczytaj(z: url)
    }
}

/// Błędy importu z lokalizowanymi opisami dla UI.
enum BladImportuDWGV001: LocalizedError {
    case pustyPlik
    case brakObiektow
    case blednyJSON(String)
    case brakDostepuDoPliku(String)

    var errorDescription: String? {
        switch self {
        case .pustyPlik:
            return "Wybrany plik importu jest pusty."
        case .brakObiektow:
            return "Plik nie zawiera żadnych wykrytych mebli. Sprawdź czy konwerter DWG → JSON zakończył się sukcesem."
        case .blednyJSON(let detail):
            return "Nieprawidłowy JSON importu: \(detail)"
        case .brakDostepuDoPliku(let detail):
            return "Nie udało się otworzyć pliku: \(detail)"
        }
    }
}
