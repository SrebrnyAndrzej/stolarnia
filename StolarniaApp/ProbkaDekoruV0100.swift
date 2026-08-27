import SwiftUI
import DomainCore

/// Próbka dekoru rysowana z parametrów struktury, nie z jednego koloru.
///
/// Powód wzięty z planera ABRYS: ich próbki materiałów to zdjęcia tekstur,
/// więc na liście od razu widać różnicę między jednolitym frontem a dębem.
/// U nas każdy dekor był tym samym prostokątem wypełnionym `kolorHEX` —
/// „Dąb Halifax", „Biały Premium" i „Beton Chicago" różniły się wyłącznie
/// odcieniem, choć w rzeczywistości różnią się przede wszystkim rysunkiem.
///
/// Zdjęć nie mamy i nie chcemy ich trzymać w repo dla setek dekorów, więc
/// wzór jest **proceduralny** — liczony z `DecorSurface`, tej samej struktury,
/// która steruje wizualizacją 3D. Dzięki temu próbka w bazie materiałów
/// i front na wizualizacji nie mogą się rozjechać: obie biorą `glossLevel`,
/// `embossDepth`, `grainContrast` i `synchronisedPore` z jednego miejsca.
///
/// Rysunek jest **deterministyczny** — ziarno pochodzi z kodu dekoru, więc
/// ten sam dekor wygląda tak samo przy każdym przewinięciu listy.
struct ProbkaDekoruV0100: View {

    let kolor: Color
    let powierzchnia: DecorSurface
    /// Usłojenie pionowe — `kierunekDekoru` z bazy materiałów.
    var pionowoUslojenie: Bool = false
    /// Ziarno wzoru; przekazuj kod dekoru, żeby rysunek był powtarzalny.
    var ziarno: String = ""

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(kolor))

            switch powierzchnia.family {
            case .wood:              rysujDrewno(&context, size)
            case .stone:             rysujKamien(&context, size)
            case .concrete:          rysujBeton(&context, size)
            case .fabric:            rysujTkanine(&context, size)
            case .uni:               break
            }

            rysujPolysk(&context, size)
        }
        .drawingGroup()
        .accessibilityLabel("Próbka dekoru, \(powierzchnia.displayName)")
    }

    // MARK: - Rodziny

    /// Słoje: kilka podłużnych linii o nierównym rozstawie.
    ///
    /// `grainContrast` steruje tym, jak mocno odcinają się od tła — struktury
    /// łączące mat i połysk (ST19, ST38) mają je wyraźnie wyższe, i tak samo
    /// zachowuje się prawdziwa płyta w świetle.
    private func rysujDrewno(_ context: inout GraphicsContext, _ size: CGSize) {
        let dlugosc = pionowoUslojenie ? size.height : size.width
        let poprzek = pionowoUslojenie ? size.width : size.height
        let liczba = max(Int(poprzek / 3.2), 3)
        var los = GeneratorSzumuV0100(ziarno: ziarno)

        for i in 0..<liczba {
            let baza = poprzek * (Double(i) + 0.5) / Double(liczba)
            let odchylka = (los.nastepna() - 0.5) * poprzek / Double(liczba) * 0.7
            let pozycja = baza + odchylka
            // Podniesienie do kwadratu spycha większość linii w słabe wartości
            // i zostawia kilka mocnych. Równomierne rozłożenie dawało pasiaka,
            // a nie usłojenie — w prawdziwej płycie kilka słojów jest wyraźnych,
            // a reszta ledwie widoczna.
            let moc = 0.05 + powierzchnia.grainContrast * pow(los.nastepna(), 2) * 0.95

            var sciezka = Path()
            let kroki = 6
            for k in 0...kroki {
                let t = Double(k) / Double(kroki)
                // Lekkie falowanie — prosta linia czyta się jak nadruk paskowy,
                // a nie jak słój.
                let faluj = sin(t * .pi * 2 + Double(i)) * poprzek * 0.012
                let punkt = pionowoUslojenie
                    ? CGPoint(x: pozycja + faluj, y: dlugosc * t)
                    : CGPoint(x: dlugosc * t, y: pozycja + faluj)
                if k == 0 { sciezka.move(to: punkt) } else { sciezka.addLine(to: punkt) }
            }

            context.stroke(
                sciezka,
                with: .color(kolorRysunku(moc)),
                lineWidth: 0.6 + powierzchnia.embossDepth * (los.nastepna() * 1.4))
        }

        // Por zsynchronizowany: wytłoczenie pokrywa się ze słojem, więc obok
        // ciemnej linii biegnie jasny grzbiet. To jest ta cecha, za którą
        // dopłaca się w płytach Feelwood / Pure Wood, i jedyna rzecz na próbce,
        // po której da się je odróżnić od zwykłego nadruku drewnopodobnego.
        if powierzchnia.synchronisedPore {
            for i in 0..<liczba where i % 2 == 0 {
                let pozycja = poprzek * (Double(i) + 0.9) / Double(liczba)
                var sciezka = Path()
                if pionowoUslojenie {
                    sciezka.move(to: CGPoint(x: pozycja, y: 0))
                    sciezka.addLine(to: CGPoint(x: pozycja, y: dlugosc))
                } else {
                    sciezka.move(to: CGPoint(x: 0, y: pozycja))
                    sciezka.addLine(to: CGPoint(x: dlugosc, y: pozycja))
                }
                context.stroke(
                    sciezka,
                    with: .color(.white.opacity(0.10 + powierzchnia.embossDepth * 0.18)),
                    lineWidth: 0.5)
            }
        }
    }

    /// Kamień: żyłki biegnące ukośnie, rzadsze i dłuższe niż słoje.
    private func rysujKamien(_ context: inout GraphicsContext, _ size: CGSize) {
        var los = GeneratorSzumuV0100(ziarno: ziarno)
        for _ in 0..<4 {
            var sciezka = Path()
            var punkt = CGPoint(x: -2, y: size.height * los.nastepna())
            sciezka.move(to: punkt)
            while punkt.x < size.width + 2 {
                punkt = CGPoint(
                    x: punkt.x + size.width * (0.16 + los.nastepna() * 0.16),
                    y: punkt.y + size.height * (los.nastepna() - 0.5) * 0.5)
                sciezka.addLine(to: punkt)
            }
            context.stroke(
                sciezka,
                with: .color(kolorRysunku(0.12 + powierzchnia.grainContrast * 0.3)),
                lineWidth: 0.5 + los.nastepna() * 0.7)
        }
    }

    /// Beton: nieregularne plamy, bez kierunku.
    private func rysujBeton(_ context: inout GraphicsContext, _ size: CGSize) {
        var los = GeneratorSzumuV0100(ziarno: ziarno)
        let plamy = Int(size.width * size.height / 26) + 6
        for _ in 0..<plamy {
            let r = 0.6 + los.nastepna() * 2.2
            let rect = CGRect(
                x: size.width * los.nastepna(),
                y: size.height * los.nastepna(),
                width: r, height: r)
            let jasna = los.nastepna() > 0.5
            context.fill(
                Path(ellipseIn: rect),
                with: .color(jasna
                    ? .white.opacity(0.06 + powierzchnia.grainContrast * 0.10)
                    : kolorRysunku(0.06 + powierzchnia.grainContrast * 0.12)))
        }
    }

    /// Tkanina: regularny splot — krzyżująca się siatka.
    private func rysujTkanine(_ context: inout GraphicsContext, _ size: CGSize) {
        let krok = 2.6
        let moc = kolorRysunku(0.07 + powierzchnia.grainContrast * 0.10)
        var x = 0.0
        while x < size.width {
            var s = Path()
            s.move(to: CGPoint(x: x, y: 0))
            s.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(s, with: .color(moc), lineWidth: 0.4)
            x += krok
        }
        var y = 0.0
        while y < size.height {
            var s = Path()
            s.move(to: CGPoint(x: 0, y: y))
            s.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(s, with: .color(.white.opacity(0.05)), lineWidth: 0.4)
            y += krok
        }
    }

    /// Połysk jako rozjaśnienie od góry.
    ///
    /// Przy `glossLevel` bliskim zera nie rysuje się nic — płyta głęboko matowa
    /// nie ma refleksu, a udawany połysk na macie to najczęstszy błąd
    /// wizualizacji, po którym klient spodziewa się innej płyty niż zamówiona.
    private func rysujPolysk(_ context: inout GraphicsContext, _ size: CGSize) {
        guard powierzchnia.glossLevel > 0.12 else { return }
        let sila = (powierzchnia.glossLevel - 0.12) / 0.88
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    .white.opacity(0.05 + sila * 0.40),
                    .clear,
                    .black.opacity(sila * 0.10)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width * 0.35, y: size.height)))
    }

    /// Rysunek zawsze przyciemnia — na jasnym dekorze usłojenie jest ciemniejsze
    /// od tła, na ciemnym też. Rozjaśnienia dokłada osobno por i połysk.
    private func kolorRysunku(_ moc: Double) -> Color {
        .black.opacity(min(max(moc, 0), 0.55))
    }
}

/// Powtarzalny generator pseudolosowy.
///
/// `Double.random` dałoby inny rysunek przy każdym przerysowaniu widoku,
/// czyli migotanie próbek podczas przewijania listy materiałów. Ziarno
/// pochodzi z kodu dekoru, więc dana płyta wygląda zawsze tak samo.
struct GeneratorSzumuV0100 {
    private var stan: UInt64

    init(ziarno: String) {
        // FNV-1a — krótki, deterministyczny i niezależny od `hashValue`,
        // który w Swift jest solony i zmienia się między uruchomieniami.
        var hash: UInt64 = 0xcbf29ce484222325
        for bajt in ziarno.utf8 {
            hash ^= UInt64(bajt)
            hash = hash &* 0x100000001b3
        }
        stan = hash == 0 ? 0x9E3779B97F4A7C15 : hash
    }

    mutating func nastepna() -> Double {
        stan ^= stan << 13
        stan ^= stan >> 7
        stan ^= stan << 17
        return Double(stan % 10_000) / 10_000
    }
}
