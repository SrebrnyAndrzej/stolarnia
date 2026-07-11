import Foundation

/// Przestrzeń dedykowana wewnątrz mebla typu `customCarcass` —
/// np. wnęka na odkurzacz iRobot, stację ładowania, buty lub inne urządzenie.
///
/// Wymiary odnoszą się do OTWORU (wewnętrzna wolna przestrzeń), nie do
/// elementów konstrukcyjnych. Silnik produkcyjny traktuje wnękę jako
/// informację dla stolarza (notatka na karcie technicznej + BOM).
struct WnekaSpecjalnaV080:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()

    /// Etykieta opisująca zawartość wnęki, np. „iRobot j7+", „Stacja ładowania".
    var etykieta: String = ""

    /// Szerokość otworu wnęki [mm].
    var szerokoscMM: Double = 350

    /// Wysokość otworu wnęki [mm].
    var wysokoscMM: Double = 100

    /// Głębokość otworu wnęki [mm].
    var glebokoscMM: Double = 350

    /// Odległość dolnej krawędzi otworu od podłogi mebla [mm].
    /// Gdy 0 — wnęka zaczyna się przy podłodze.
    var odPodlogiMM: Double = 0

    /// Czy otwór jest z przodu (domyślnie) czy wymaga dedykowanych drzwiczek.
    var otwartaZPrzodu: Bool = true

    /// Notatka dla stolarza — widoczna na karcie technicznej.
    var uwagi: String = ""

    // MARK: - Walidacja

    var opisWymiaru: String {
        "\(Int(szerokoscMM)) × \(Int(wysokoscMM)) × \(Int(glebokoscMM)) mm"
    }

    var bladyWalidacji: [String] {
        var result: [String] = []
        if szerokoscMM <= 0 { result.append("Szerokość musi być dodatnia.") }
        if wysokoscMM <= 0  { result.append("Wysokość musi być dodatnia.") }
        if glebokoscMM <= 0 { result.append("Głębokość musi być dodatnia.") }
        if odPodlogiMM < 0  { result.append("Odległość od podłogi nie może być ujemna.") }
        return result
    }

    var jestPoprawna: Bool { bladyWalidacji.isEmpty }

    // MARK: - Gotowe szablony

    static let iRobotJ7Plus = WnekaSpecjalnaV080(
        etykieta: "iRobot j7+ (stacja automatyczna)",
        szerokoscMM: 395,
        wysokoscMM: 90,
        glebokoscMM: 370,
        odPodlogiMM: 0,
        otwartaZPrzodu: true,
        uwagi: "Wymiary stacji bazowej iRobot j7+. Upewnij się o dostępie do gniazdka 230V od tyłu."
    )

    static let iRobotRoomba = WnekaSpecjalnaV080(
        etykieta: "iRobot Roomba (stacja standardowa)",
        szerokoscMM: 310,
        wysokoscMM: 90,
        glebokoscMM: 310,
        odPodlogiMM: 0,
        otwartaZPrzodu: true,
        uwagi: "Standardowa stacja bazowa Roomba. Sprawdź model — niektóre wymagają większej głębokości."
    )

    static let szablony: [WnekaSpecjalnaV080] = [
        iRobotJ7Plus,
        iRobotRoomba,
        WnekaSpecjalnaV080(
            etykieta: "Stacja ładowania odkurzacza pionowego",
            szerokoscMM: 200,
            wysokoscMM: 500,
            glebokoscMM: 150,
            odPodlogiMM: 0,
            otwartaZPrzodu: true,
            uwagi: "Odkurzacz pionowy stoi opierając się o tylną ścianę. Uwzględnij gniazdo 230V."
        ),
        WnekaSpecjalnaV080(
            etykieta: "Miejsce na buty (jedno piętro)",
            szerokoscMM: 350,
            wysokoscMM: 150,
            glebokoscMM: 300,
            odPodlogiMM: 0,
            otwartaZPrzodu: true,
            uwagi: ""
        ),
    ]
}
