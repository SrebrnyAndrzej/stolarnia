import Foundation

/// Wspólny, wersjonowany zapis JSON z jedną kopią bezpieczeństwa.
///
/// Repozytoria nadal korzystają z `UserDefaults`, aby zachować zgodność
/// z obecną architekturą aplikacji. Ten magazyn zapobiega jednak cichej
/// utracie całej bazy, gdy bieżący zapis jest uszkodzony lub niekompletny.
struct WynikBezpiecznegoOdczytuJSON<Value> {
    var wartosc: Value
    var odzyskanoZKopii: Bool
    var uzytoWartosciDomyslnej: Bool
    var komunikat: String?
}

enum BezpiecznyMagazynJSON {
    static func wczytaj<Value: Decodable>(
        _ type: Value.Type,
        defaults: UserDefaults,
        key: String,
        backupKey: String,
        wartoscDomyslna: @autoclosure () -> Value,
        decoder: JSONDecoder = JSONDecoder()
    ) -> WynikBezpiecznegoOdczytuJSON<Value> {
        var bladBiezacegoZapisu: Error?

        if let data = defaults.data(forKey: key) {
            do {
                return WynikBezpiecznegoOdczytuJSON(
                    wartosc: try decoder.decode(type, from: data),
                    odzyskanoZKopii: false,
                    uzytoWartosciDomyslnej: false,
                    komunikat: nil
                )
            } catch {
                bladBiezacegoZapisu = error
            }
        }

        if let backupData = defaults.data(forKey: backupKey) {
            do {
                let recovered = try decoder.decode(type, from: backupData)
                defaults.set(backupData, forKey: key)

                return WynikBezpiecznegoOdczytuJSON(
                    wartosc: recovered,
                    odzyskanoZKopii: true,
                    uzytoWartosciDomyslnej: false,
                    komunikat:
                        "Bieżący zapis był uszkodzony. Przywrócono ostatnią poprawną kopię bezpieczeństwa."
                )
            } catch {
                let details = bladBiezacegoZapisu?.localizedDescription
                    ?? error.localizedDescription

                return WynikBezpiecznegoOdczytuJSON(
                    wartosc: wartoscDomyslna(),
                    odzyskanoZKopii: false,
                    uzytoWartosciDomyslnej: true,
                    komunikat:
                        "Nie udało się odczytać bieżącego zapisu ani kopii bezpieczeństwa: \(details)"
                )
            }
        }

        if let bladBiezacegoZapisu {
            return WynikBezpiecznegoOdczytuJSON(
                wartosc: wartoscDomyslna(),
                odzyskanoZKopii: false,
                uzytoWartosciDomyslnej: true,
                komunikat:
                    "Nie udało się odczytać zapisu danych: \(bladBiezacegoZapisu.localizedDescription)"
            )
        }

        return WynikBezpiecznegoOdczytuJSON(
            wartosc: wartoscDomyslna(),
            odzyskanoZKopii: false,
            uzytoWartosciDomyslnej: true,
            komunikat: nil
        )
    }

    static func zapisz<Value: Codable>(
        _ value: Value,
        defaults: UserDefaults,
        key: String,
        backupKey: String,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) throws {
        let data = try encoder.encode(value)

        if let previous = defaults.data(forKey: key),
           previous != data,
           (try? decoder.decode(
               Value.self,
               from: previous
           )) != nil
        {
            defaults.set(previous, forKey: backupKey)
        }

        defaults.set(data, forKey: key)
    }
}
