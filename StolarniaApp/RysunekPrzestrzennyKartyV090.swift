import CoreGraphics
import DomainCore
import Foundation

// MARK: - Rozmieszczenie elementów karty w bryle

/// Buduje schematyczny układ przestrzenny szafki z listy elementów karty.
///
/// `ElementTechnicznySzafki` niesie wymiary, ale nie niesie pozycji — rysunek
/// przestrzenny powstaje więc z reguł rozmieszczenia opartych na typie elementu
/// i gabarytach szafki. To rysunek poglądowy do dokumentacji, nie model CAD:
/// pokazuje, który element gdzie siedzi, a nie milimetrową geometrię montażu.
enum RysunekPrzestrzennyKartyV090 {

    /// Odsunięcie półek od lica, żeby na rzucie było widać, że nie dochodzą do przodu.
    private static let cofniecieFrontowePolkiMM = 20.0

    /// Szczelina między frontami.
    /// Zgodnie z UstawieniaKonstrukcyjneStolarni.szczelinaFrontowMM.
    /// Fuga między frontami — z konwencji warsztatu, nie z literału.
    private static let szczelinaFrontuMM =
        ProductionRules.frontToFrontGap.rawValue
    /// Luz frontu od krawędzi korpusu — połowa fugi, bo fuga to dwa luzy.
    private static let luzFrontuMM =
        ProductionRules.frontClearancePerEdge.rawValue

    struct Wejscie {
        /// Fronty rysowane konturem zamiast wypełnienia. Domyślnie tak,
        /// bo wypełniony front zasłania wnętrze i rysunek traci sens.
        var frontyKonturem: Bool = true
        var szerokoscMM: Double
        var wysokoscMM: Double
        var glebokoscMM: Double
        /// (etykieta, typ, grubość, ilość) — kolejność jak na karcie.
        var elementy: [(etykieta: String, typ: TypElementuSzafki,
                        gruboscMM: Double, ilosc: Int)]
    }

    static func bryly(dla wejscie: Wejscie) -> [BrylaAksonometrycznaV090] {
        let W = wejscie.szerokoscMM
        let H = wejscie.wysokoscMM
        let D = wejscie.glebokoscMM
        guard W > 0, H > 0, D > 0 else { return [] }

        let grubosc = wejscie.elementy
            .first { $0.typ == .scianaBoczna }?
            .gruboscMM ?? 18.0

        var out: [BrylaAksonometrycznaV090] = []

        // Ile półek i frontów — potrzebne do równomiernego rozłożenia.
        let liczbaPolek = wejscie.elementy
            .filter { $0.typ == .polka }
            .reduce(0) { $0 + max(1, $1.ilosc) }
        let liczbaFrontow = wejscie.elementy
            .filter { $0.typ == .front }
            .reduce(0) { $0 + max(1, $1.ilosc) }
        let liczbaSzuflad = wejscie.elementy
            .filter { $0.typ == .szuflada }
            .reduce(0) { $0 + max(1, $1.ilosc) }

        var indeksPolki = 0
        var indeksFrontu = 0
        var indeksSzuflady = 0
        var indeksBoku = 0

        for el in wejscie.elementy {
            let t = el.gruboscMM > 0 ? el.gruboscMM : grubosc
            for _ in 0..<max(1, el.ilosc) {
                switch el.typ {

                case .scianaBoczna:
                    let x = indeksBoku == 0 ? 0 : W - t
                    indeksBoku += 1
                    out.append(.init(x: x, y: 0, z: 0,
                                     szerokosc: t, wysokosc: H, glebokosc: D,
                                     etykieta: el.etykieta, rola: .korpus))

                case .dno, .wieniecDolny, .cokół:
                    out.append(.init(x: grubosc, y: 0, z: 0,
                                     szerokosc: max(W - 2 * grubosc, 1),
                                     wysokosc: t, glebokosc: D,
                                     etykieta: el.etykieta, rola: .korpus))

                case .wieniecGorny:
                    out.append(.init(x: grubosc, y: H - t, z: 0,
                                     szerokosc: max(W - 2 * grubosc, 1),
                                     wysokosc: t, glebokosc: D,
                                     etykieta: el.etykieta, rola: .korpus))

                case .polka:
                    indeksPolki += 1
                    let skok = H / Double(liczbaPolek + 1)
                    out.append(.init(x: grubosc,
                                     y: skok * Double(indeksPolki),
                                     z: 0,
                                     szerokosc: max(W - 2 * grubosc, 1),
                                     wysokosc: t,
                                     glebokosc: max(D - cofniecieFrontowePolkiMM, 1),
                                     etykieta: el.etykieta, rola: .polka))

                case .przegroda:
                    out.append(.init(x: W / 2 - t / 2, y: grubosc, z: 0,
                                     szerokosc: t,
                                     wysokosc: max(H - 2 * grubosc, 1),
                                     glebokosc: D,
                                     etykieta: el.etykieta, rola: .korpus))

                case .plecy:
                    out.append(.init(x: grubosc, y: grubosc, z: 0,
                                     szerokosc: max(W - 2 * grubosc, 1),
                                     wysokosc: max(H - 2 * grubosc, 1),
                                     glebokosc: max(t, 3),
                                     etykieta: el.etykieta, rola: .korpus))

                case .front:
                    indeksFrontu += 1
                    // **Ta sama arytmetyka co `ElevationModule.frontWidth`.**
                    //
                    // Było tu `(W − fuga × (n + 1)) / n`, czyli pełna fuga
                    // także na obu skrajach. Front nakładany jest cofnięty od
                    // krawędzi o **luz** (2 mm), a nie o fugę (4 mm), więc
                    // rysunek pokazywał fronty o 2 mm węższe niż te, które
                    // wychodzą z listy formatek. Podgląd musi rysować mebel,
                    // który faktycznie zostanie zrobiony.
                    // Wzór z `ProductionRules`, nie przepisany na miejscu —
                    // dokładnie ten sam, którym liczy się formatki frontów.
                    let szer = ProductionRules.frontWidth(
                        forModulePitch: Millimeters(W),
                        columns: liczbaFrontow
                    ).rawValue
                    let x = luzFrontuMM
                        + (szer + szczelinaFrontuMM) * Double(indeksFrontu - 1)
                    out.append(.init(x: max(x, 0), y: 0, z: D,
                                     szerokosc: max(szer, 1),
                                     wysokosc: H, glebokosc: t,
                                     etykieta: el.etykieta,
                                     rola: wejscie.frontyKonturem ? .frontKonturowy : .front))

                case .szuflada:
                    indeksSzuflady += 1
                    let wys = (H / Double(max(liczbaSzuflad, 1)))
                        - szczelinaFrontuMM
                    let y = (wys + szczelinaFrontuMM) * Double(indeksSzuflady - 1)
                    out.append(.init(x: luzFrontuMM, y: y, z: D,
                                     szerokosc: max(W - luzFrontuMM * 2, 1),
                                     wysokosc: max(wys, 1), glebokosc: t,
                                     etykieta: el.etykieta,
                                     rola: wejscie.frontyKonturem ? .frontKonturowy : .szuflada))

                case .blenda, .sciankaMaskujaca:
                    out.append(.init(x: W, y: 0, z: 0,
                                     szerokosc: t, wysokosc: H, glebokosc: D,
                                     etykieta: el.etykieta, rola: .front))

                case .listwa:
                    out.append(.init(x: 0, y: H, z: 0,
                                     szerokosc: W, wysokosc: t, glebokosc: D,
                                     etykieta: el.etykieta, rola: .akcesorium))

                case .inny:
                    continue
                }
            }
        }

        return out
    }

    /// Legenda ról użytych na rysunku — do podpisu pod aksonometrią.
    static func legenda(
        dla bryly: [BrylaAksonometrycznaV090]
    ) -> [(rola: RolaBrylyV090, opis: String, liczba: Int)] {
        let opisy: [RolaBrylyV090: String] = [
            .korpus: "Korpus, wieńce, przegrody",
            .polka: "Półki",
            .front: "Fronty i blendy",
            .szuflada: "Fronty szuflad",
            .akcesorium: "Listwy i akcesoria",
            .wnekaAGD: "Wnęka AGD (poglądowo)",
            .frontKonturowy: "Fronty — obrys, żeby odsłonić wnętrze",
        ]
        return RolaBrylyV090.allCases.compactMap { rola in
            let n = bryly.filter { $0.rola == rola }.count
            guard n > 0, let opis = opisy[rola] else { return nil }
            return (rola, opis, n)
        }
    }
}
