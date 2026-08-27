import CoreGraphics
import Foundation

// MARK: - Bryła wejściowa

/// Pojedynczy prostopadłościan do rzutowania. Celowo niezależny od DomainCore,
/// żeby renderer dał się użyć także dla brył pomocniczych (AGD, wnęki, cokoły).
struct BrylaAksonometrycznaV090: Hashable {
    /// Lewy–dolny–tylny narożnik bryły w milimetrach, w układzie mebla.
    var x: Double
    var y: Double
    var z: Double
    var szerokosc: Double
    var wysokosc: Double
    var glebokosc: Double

    var etykieta: String
    var rola: RolaBrylyV090

    var srodek: (x: Double, y: Double, z: Double) {
        (x + szerokosc / 2, y + wysokosc / 2, z + glebokosc / 2)
    }
}

/// Rola steruje wyłącznie wypełnieniem — kreska pozostaje jednolita,
/// żeby rysunek czytał się jak dokumentacja, a nie wizualizacja.
enum RolaBrylyV090: String, Hashable, CaseIterable {
    case korpus
    case polka
    case front
    case szuflada
    case akcesorium
    case wnekaAGD
    /// Front rysowany samym konturem — dokumentacja musi pokazywać wnętrze,
    /// a wypełniony front zasłania cały korpus.
    case frontKonturowy

    /// Jasność wypełnienia ściany górnej. Boczne i przednie są przyciemniane
    /// stałym współczynnikiem, żeby bryły czytały się przestrzennie.
    var jasnosc: CGFloat {
        switch self {
        case .korpus:     return 0.94
        case .polka:      return 0.88
        case .front:      return 0.78
        case .szuflada:   return 0.83
        case .akcesorium: return 0.55
        case .wnekaAGD:   return 0.66
        case .frontKonturowy: return 1.0
        }
    }

    var wypelniona: Bool {
        self != .wnekaAGD && self != .frontKonturowy
    }
}

// MARK: - Renderer

/// Rzut aksonometryczny (izometria 30°) rysowany w CoreGraphics.
/// Używany zarówno na stronie PDF karty technicznej, jak i w podglądzie SwiftUI.
enum RysunekAksonometrycznyV090 {

    /// Kąt rzutowania. 30° daje klasyczną izometrię meblarską —
    /// wszystkie trzy kierunki w tej samej skali, wymiary czytelne z rysunku.
    private static let kat = 30.0 * Double.pi / 180.0

    private struct Punkt2D {
        var x: Double
        var y: Double
    }

    /// Rzutuje punkt 3D na płaszczyznę rysunku.
    /// Oś X biegnie w prawo–w dół, Z w lewo–w dół, Y pionowo w górę.
    private static func rzutuj(
        _ x: Double,
        _ y: Double,
        _ z: Double
    ) -> Punkt2D {
        Punkt2D(
            x: (x - z) * cos(kat),
            y: -y + (x + z) * sin(kat)
        )
    }

    /// Prostokąt obejmujący rzut wszystkich brył — potrzebny do wpisania
    /// rysunku w zadaną ramkę bez zniekształceń.
    private static func obwiednia(
        _ bryly: [BrylaAksonometrycznaV090]
    ) -> (minX: Double, maxX: Double, minY: Double, maxY: Double)? {
        var minX = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        var pusty = true

        for b in bryly {
            for (dx, dy, dz) in narozniki(b) {
                let p = rzutuj(dx, dy, dz)
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
                pusty = false
            }
        }
        return pusty ? nil : (minX, maxX, minY, maxY)
    }

    private static func narozniki(
        _ b: BrylaAksonometrycznaV090
    ) -> [(Double, Double, Double)] {
        let x1 = b.x + b.szerokosc
        let y1 = b.y + b.wysokosc
        let z1 = b.z + b.glebokosc
        return [
            (b.x, b.y, b.z), (x1, b.y, b.z), (x1, y1, b.z), (b.x, y1, b.z),
            (b.x, b.y, z1), (x1, b.y, z1), (x1, y1, z1), (b.x, y1, z1),
        ]
    }

    /// Klucz malarza: im dalej od obserwatora, tym wcześniej rysujemy.
    /// Obserwator stoi od strony rosnących X i Z, więc bryły o mniejszej
    /// sumie współrzędnych są z tyłu.
    private static func klucz(
        _ b: BrylaAksonometrycznaV090
    ) -> Double {
        let s = b.srodek
        return s.x + s.z + s.y * 0.15
    }

    // MARK: Rysowanie

    /// Rysuje rzut w podanej ramce, zachowując proporcje i centrując zawartość.
    /// - Parameters:
    ///   - wyroznione: kody brył rysowanych akcentem (np. element z bieżącej strony).
    static func rysuj(
        bryly: [BrylaAksonometrycznaV090],
        w context: CGContext,
        ramka: CGRect,
        kolorKreski: CGColor,
        kolorAkcentu: CGColor,
        wyroznione: Set<String> = [],
        gruboscKreski: CGFloat = 0.6,
        rozstrzelenieMM: Double = 0
    ) {
        // Widok rozstrzelony wymagany przez `Axonometry3D.explode_distance_mm`
        // w specyfikacji parametrycznej projektu.
        let bryly = rozstrzelenieMM > 0
            ? rozstrzel(bryly, oMM: rozstrzelenieMM)
            : bryly
        guard !bryly.isEmpty, let ob = obwiednia(bryly) else { return }

        let szer = ob.maxX - ob.minX
        let wys = ob.maxY - ob.minY
        guard szer > 0, wys > 0 else { return }

        let margines: CGFloat = 8
        let dostepnaSzer = ramka.width - margines * 2
        let dostepnaWys = ramka.height - margines * 2
        let skala = min(dostepnaSzer / szer, dostepnaWys / wys)

        // Wyśrodkowanie rzutu w ramce.
        let offsetX = ramka.minX + margines
            + (dostepnaSzer - CGFloat(szer) * skala) / 2
        let offsetY = ramka.minY + margines
            + (dostepnaWys - CGFloat(wys) * skala) / 2

        func naEkran(_ p: Punkt2D) -> CGPoint {
            CGPoint(
                x: offsetX + CGFloat(p.x - ob.minX) * skala,
                y: offsetY + CGFloat(p.y - ob.minY) * skala
            )
        }

        context.saveGState()
        context.setLineWidth(gruboscKreski)
        context.setLineJoin(.round)

        for b in bryly.sorted(by: { klucz($0) < klucz($1) }) {
            rysujBryle(
                b,
                w: context,
                naEkran: naEkran,
                kolorKreski: kolorKreski,
                kolorAkcentu: kolorAkcentu,
                wyrozniona: wyroznione.contains(b.etykieta)
            )
        }

        context.restoreGState()
    }

    /// Odsuwa każdą bryłę od środka zespołu, żeby montażysta widział warstwy.
    /// Kierunek odsunięcia bierze się z położenia bryły względem środka —
    /// półki jadą w górę/dół, boki na zewnątrz, fronty do przodu.
    private static func rozstrzel(
        _ bryly: [BrylaAksonometrycznaV090],
        oMM dystans: Double
    ) -> [BrylaAksonometrycznaV090] {
        let srodki = bryly.map(\.srodek)
        let cx = srodki.map(\.x).reduce(0, +) / Double(srodki.count)
        let cy = srodki.map(\.y).reduce(0, +) / Double(srodki.count)
        let cz = srodki.map(\.z).reduce(0, +) / Double(srodki.count)

        return bryly.map { b in
            let s = b.srodek
            let dx = s.x - cx, dy = s.y - cy, dz = s.z - cz
            let dlugosc = max(sqrt(dx * dx + dy * dy + dz * dz), 1)
            var kopia = b
            kopia.x += dx / dlugosc * dystans
            kopia.y += dy / dlugosc * dystans
            kopia.z += dz / dlugosc * dystans
            return kopia
        }
    }

    private static func rysujBryle(
        _ b: BrylaAksonometrycznaV090,
        w context: CGContext,
        naEkran: (Punkt2D) -> CGPoint,
        kolorKreski: CGColor,
        kolorAkcentu: CGColor,
        wyrozniona: Bool
    ) {
        let x1 = b.x + b.szerokosc
        let y1 = b.y + b.wysokosc
        let z1 = b.z + b.glebokosc

        // Trzy ściany widoczne z tego kierunku patrzenia: górna, przednia, prawa.
        let gorna = [
            rzutuj(b.x, y1, b.z), rzutuj(x1, y1, b.z),
            rzutuj(x1, y1, z1), rzutuj(b.x, y1, z1),
        ]
        let przednia = [
            rzutuj(b.x, b.y, z1), rzutuj(x1, b.y, z1),
            rzutuj(x1, y1, z1), rzutuj(b.x, y1, z1),
        ]
        let prawa = [
            rzutuj(x1, b.y, z1), rzutuj(x1, b.y, b.z),
            rzutuj(x1, y1, b.z), rzutuj(x1, y1, z1),
        ]

        let bazowa = b.rola.jasnosc
        let sciany: [(punkty: [Punkt2D], jasnosc: CGFloat)] = [
            (gorna, bazowa),
            (przednia, bazowa * 0.90),
            (prawa, bazowa * 0.78),
        ]

        for (punkty, jasnosc) in sciany {
            let sciezka = CGMutablePath()
            sciezka.move(to: naEkran(punkty[0]))
            for p in punkty.dropFirst() { sciezka.addLine(to: naEkran(p)) }
            sciezka.closeSubpath()

            context.addPath(sciezka)
            if b.rola.wypelniona {
                let szary = CGColor(
                    colorSpace: CGColorSpaceCreateDeviceGray(),
                    components: [jasnosc, 1]
                )
                context.setFillColor(szary ?? kolorKreski)
                context.setStrokeColor(wyrozniona ? kolorAkcentu : kolorKreski)
                context.setLineWidth(wyrozniona ? 1.4 : 0.6)
                context.drawPath(using: .fillStroke)
            } else {
                // Wnęka AGD rysowana samą kreską przerywaną — to nie jest mebel.
                context.setStrokeColor(kolorKreski)
                context.setLineWidth(0.5)
                context.setLineDash(phase: 0, lengths: [3, 2])
                context.strokePath()
                context.setLineDash(phase: 0, lengths: [])
            }
        }
    }

    // MARK: Adapter z modelu domenowego

    /// Buduje bryły z komponentów zespołu meblowego.
    /// Wnęki AGD i inne bryły pomocnicze dołóż osobno przez `dodatkowe`.
    static func bryly(
        zKomponentow komponenty: [(kod: String, rola: RolaBrylyV090,
                                   x: Double, y: Double, z: Double,
                                   szerokosc: Double, wysokosc: Double, glebokosc: Double)],
        dodatkowe: [BrylaAksonometrycznaV090] = []
    ) -> [BrylaAksonometrycznaV090] {
        komponenty.map {
            BrylaAksonometrycznaV090(
                x: $0.x, y: $0.y, z: $0.z,
                szerokosc: $0.szerokosc,
                wysokosc: $0.wysokosc,
                glebokosc: $0.glebokosc,
                etykieta: $0.kod,
                rola: $0.rola
            )
        } + dodatkowe
    }
}
