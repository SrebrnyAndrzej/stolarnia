import SwiftUI

/// Tło pulpitu: antracyt, poświata limonki i ziarno.
///
/// Trzy warstwy, każda z powodem:
///
/// 1. **Antracyt** — ciemna baza z palety projektu, nie czarny. Czysta czerń
///    na OLED wygląda jak dziura; antracyt ma temperaturę.
/// 2. **Poświata limonki** — miękka plama akcentu poza środkiem kadru. Daje
///    głębię bez ciężaru: interfejs wygląda na oświetlony, a nie pomalowany.
/// 3. **Ziarno** — delikatny szum na wierzchu. To jest ten element, który
///    najbardziej odróżnia „drogie" od „zrobione w kreatorze": czysty gradient
///    czyta się jako plastik, ziarno nadaje mu fizyczność. Kosztuje jedną
///    teksturę, nie WebGL.
///
/// **Rozmycia tu nie ma i to jest decyzja wydajnościowa.** Mrożone szkło
/// robimy półprzezroczystym wypełnieniem i wewnętrznym rozświetleniem na
/// kaflach, a nie żywym `backdrop-blur` — kilkanaście przewijanych kafli
/// z rozmyciem to kilkanaście przebiegów GPU na klatkę i zauważalne gubienie
/// płynności na iPadzie. Rozmycie zostaje dla warstw **nieruchomych**.
struct PulpitTloV0106: View {

    /// Ziarno rysowane raz i cache'owane jako bitmapa.
    ///
    /// Bez `drawingGroup()` szum przeliczałby się przy każdej klatce
    /// przewijania. Deterministyczne ziarno, więc tekstura nie „pływa".
    private static let gestoscZiarna = 2600

    var body: some View {
        ZStack {
            StolarniaPalette.canvas

            // Poświata poza środkiem — symetryczna wyglądałaby jak winieta,
            // przesunięta wygląda jak światło padające z boku.
            RadialGradient(
                colors: [
                    StolarniaPalette.lime.opacity(0.16),
                    StolarniaPalette.lime.opacity(0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.14, y: 0.02),
                startRadius: 0,
                endRadius: 760
            )

            RadialGradient(
                colors: [
                    StolarniaPalette.graphite.opacity(0.5),
                    .clear
                ],
                center: UnitPoint(x: 0.92, y: 0.85),
                startRadius: 0,
                endRadius: 620
            )

            ziarno
        }
        .ignoresSafeArea()
    }

    private var ziarno: some View {
        Canvas { context, size in
            var los = GeneratorSzumuV0100(ziarno: "pulpit-stolarni")
            for _ in 0..<Self.gestoscZiarna {
                let x = size.width * los.nastepna()
                let y = size.height * los.nastepna()
                let jasnosc = los.nastepna()
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                    with: .color(.white.opacity(0.012 + jasnosc * 0.026))
                )
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

// MARK: - Podwójna ramka

/// Kafel w podwójnej ramce — zewnętrzna taca i wewnętrzny rdzeń.
///
/// Pojedynczy prostokąt z obrysem czyta się jako element formularza. Element,
/// który ma wyglądać na przedmiot, potrzebuje **dwóch zamknięć**: zewnętrznej
/// obudowy z własnym tłem i włoskową krawędzią, a w niej rdzenia z osobnym
/// wypełnieniem i rozświetleniem górnej krawędzi.
///
/// To ten sam zabieg, którym szkło osadza się w aluminiowej ramce — i jest
/// najsilniejszym pojedynczym sygnałem „drogiego" interfejsu.
///
/// **Promienie muszą być współśrodkowe.** Wewnętrzny = zewnętrzny minus
/// grubość obudowy. Przy równych promieniach narożniki się rozjeżdżają
/// i całość wygląda na sklejoną z dwóch elementów, bo tak jest.
struct PodwojnaRamkaV0106<Content: View>: View {
    var promien: CGFloat = 24
    var obudowa: CGFloat = 6
    var wyrozniony: Bool = false
    @ViewBuilder var zawartosc: Content

    @Environment(\.accessibilityReduceTransparency) private var ograniczPrzezroczystosc

    private var promienWewnetrzny: CGFloat { max(promien - obudowa, 4) }

    var body: some View {
        zawartosc
            .background(rdzen)
            .padding(obudowa)
            .background(taca)
    }

    private var rdzen: some View {
        ZStack {
            RoundedRectangle(cornerRadius: promienWewnetrzny, style: .continuous)
                .fill(
                    ograniczPrzezroczystosc
                    ? StolarniaPalette.anthraciteRaised
                    : StolarniaPalette.canvasRaised.opacity(0.86)
                )

            // Rozświetlenie górnej krawędzi — światło pada z góry, więc górna
            // krawędź jest jaśniejsza. Bez tego rdzeń jest płaską plamą.
            RoundedRectangle(cornerRadius: promienWewnetrzny, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(wyrozniony ? 0.22 : 0.14),
                            .white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }

    private var taca: some View {
        ZStack {
            RoundedRectangle(cornerRadius: promien, style: .continuous)
                .fill(
                    wyrozniony
                    ? StolarniaPalette.lime.opacity(0.10)
                    : .white.opacity(0.045)
                )

            RoundedRectangle(cornerRadius: promien, style: .continuous)
                .strokeBorder(
                    wyrozniony
                    ? StolarniaPalette.lime.opacity(0.34)
                    : .white.opacity(0.08),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Etykieta nadrzędna

/// Mikroskopijna pigułka nad nagłówkiem sekcji.
///
/// Sam nagłówek mówi, co to jest. Etykieta nad nim mówi, **czym to jest
/// w całości** — i robi to na tyle małym stopniem pisma, że nie konkuruje.
/// Duża rozstrzelona spacja jest tu konieczna: bez niej wersaliki w tym
/// rozmiarze zlewają się w plamę.
struct EtykietaNadrzednaV0106: View {
    let tekst: String

    var body: some View {
        Text(tekst.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(2.2)
            .foregroundStyle(StolarniaPalette.lime.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(StolarniaPalette.lime.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(StolarniaPalette.lime.opacity(0.24), lineWidth: 1)
            )
    }
}
