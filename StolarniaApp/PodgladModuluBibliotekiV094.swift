import SwiftUI
import DomainCore

/// Podgląd modułu rysowany z jego prawdziwej geometrii.
///
/// Poprzedni podgląd w bibliotece rysował dekorację **na podstawie kategorii**:
/// każdy moduł „kuchenny dolny” dostawał ten sam obrazek trzech pasków,
/// niezależnie od tego, czy miał trzy szuflady 140/140/280, jedne drzwi i dwie
/// półki, czy 400 mm szerokości zamiast 1200. Projektant wybierał więc moduł
/// z nazwy i wymiarów, a obrazek nic nie wnosił — a przy 95 presetach w
/// katalogu to jest różnica między szukaniem a przeglądaniem.
///
/// Tutaj rysunek jest w skali i pokazuje to, co faktycznie zostanie zbudowane:
/// proporcje korpusu, realne wysokości frontów szuflad, podział na komory,
/// półki i fugi 4 mm. Dwa moduły różniące się budową wyglądają różnie.

/// Neutralny opis modułu do narysowania.
///
/// Biblioteka miesza dwa katalogi: ogólny `StandardFurnitureModuleCatalogV077`
/// (68 presetów, połowa z jawnym setupem) i kuchenny
/// `StandardKitchenModuleCatalogV0143` (95 modułów, bez danych o układzie
/// szuflad). Podgląd nie może zależeć od jednego z nich, bo wtedy druga połowa
/// biblioteki wygląda jak puste pudełka.
struct PodgladModuluOpisV094: Hashable {
    var szerokoscMM: Int
    var wysokoscMM: Int
    var liczbaPolek: Int
    var maFront: Bool
    var wysokosciSzuflad: [Int]
    var szerokosciKomor: [Int]
    var szufladyWewnetrzne: Bool
    var rodzaj: Rodzaj

    enum Rodzaj: Hashable {
        case drzwi
        case szuflady
        case cargo
        case zlew
        case agd
        case otwarty
        case uchylny
    }

    init(preset: StandardFurniturePresetV077) {
        szerokoscMM = preset.widthMM
        wysokoscMM = preset.heightMM
        liczbaPolek = preset.shelfCount
        maFront = preset.frontEnabled
        wysokosciSzuflad = preset.setup.drawerFrontHeightsMM.filter { $0 > 0 }
        szerokosciKomor = preset.setup.bayWidthsMM.filter { $0 > 0 }
        szufladyWewnetrzne = preset.setup.internalDrawers
        if !wysokosciSzuflad.isEmpty {
            rodzaj = .szuflady
        } else if !preset.frontEnabled {
            rodzaj = .otwarty
        } else {
            rodzaj = .drzwi
        }
    }

    /// Katalog kuchenny nie przechowuje układu szuflad per moduł — niesie tylko
    /// rodzaj konstrukcji. Podgląd używa więc **typowego** układu dla rodziny
    /// (720 mm z szufladami to w tym warsztacie 140/140/280). To jest rysunek
    /// poglądowy, a nie dane produkcyjne: realny układ ustala konfigurator
    /// i to on trafia na kartę.
    init(kitchen preset: KitchenModulePresetV0143) {
        szerokoscMM = preset.widthMM
        wysokoscMM = preset.heightMM
        liczbaPolek = 0
        maFront = true
        wysokosciSzuflad = []
        szerokosciKomor = []
        szufladyWewnetrzne = false

        switch preset.construction {
        case .drawers:
            rodzaj = .szuflady
            wysokosciSzuflad = Self.typoweSzuflady(wysokoscKorpusu: preset.heightMM)
        case .cargo:
            rodzaj = .cargo
        case .sink, .dishwasherFront:
            rodzaj = .zlew
        case .oven, .cooktop, .hood, .refrigerator,
             .ovenTower, .ovenMicrowaveTower:
            rodzaj = .agd
        case .openShelf:
            rodzaj = .otwarty
            maFront = false
            liczbaPolek = 3
        case .liftUp, .topBox:
            rodzaj = .uchylny
        case .shelves, .utility, .blindCorner, .lCorner,
             .wallCorner, .island:
            rodzaj = .drzwi
            liczbaPolek = preset.heightMM >= 1600 ? 4 : 2
        }
    }

    /// Typowy podział frontów szuflad dla wysokości korpusu.
    ///
    /// Listy idą **od dołu do góry**, zgodnie z `ElevationZone.drawerFrontHeights`.
    /// Wysoka szuflada jest na dole — to układ „wysoka na dole, dwie niskie”,
    /// czyli garnki nisko, sztućce wysoko. Odwrotna kolejność też jest w
    /// katalogu jako osobny preset, ale nie jest domyślna.
    private static func typoweSzuflady(wysokoscKorpusu: Int) -> [Int] {
        switch wysokoscKorpusu {
        case ..<400:  return [140, 140]
        case ..<600:  return [180, 140, 140]
        case ..<900:  return [280, 140, 140]          // klasyk 720 mm
        default:      return [280, 280, 140, 140]
        }
    }
}

struct PodgladModuluBibliotekiV094: View {

    let opis: PodgladModuluOpisV094

    /// Fuga rysowana w skali rysunku — ta sama reguła co na warsztacie.
    private var szczelina: Double { ProductionRules.frontToFrontGap.rawValue }
    private var grubosc: Double { ProductionRules.carcassThickness.rawValue }

    var body: some View {
        GeometryReader { geo in
            let szer = Double(opis.szerokoscMM)
            let wys = Double(opis.wysokoscMM)
            // Rysunek trzyma proporcje modułu: szeroka szafka dolna nie może
            // wyglądać jak wysoki słupek tylko dlatego, że kafel jest kwadratowy.
            let skala = min(geo.size.width / szer, geo.size.height / wys)
            let w = szer * skala
            let h = wys * skala
            let x0 = (geo.size.width - w) / 2
            let y0 = (geo.size.height - h) / 2

            ZStack(alignment: .topLeading) {
                korpus(w: w, h: h)
                wnetrze(w: w, h: h, skala: skala)
                if opis.maFront {
                    fronty(w: w, h: h, skala: skala)
                }
            }
            .frame(width: w, height: h)
            .offset(x: x0, y: y0)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Korpus

    private func korpus(w: Double, h: Double) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(width: w, height: h)
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.35), lineWidth: 1)
            )
    }

    // MARK: - Wnętrze

    /// Półki i przegrody komór. Rysowane pod frontami, żeby moduł z frontem
    /// i bez frontu różniły się tylko warstwą lica.
    @ViewBuilder
    private func wnetrze(w: Double, h: Double, skala: Double) -> some View {
        let t = max(grubosc * skala, 1)
        let swiatloW = w - 2 * t
        let swiatloH = h - 2 * t

        ZStack(alignment: .topLeading) {
            ForEach(Array(przegrody(swiatloW: swiatloW).enumerated()), id: \.offset) { _, x in
                Rectangle()
                    .fill(Color.primary.opacity(0.28))
                    .frame(width: max(t, 1), height: swiatloH)
                    .offset(x: t + x, y: t)
            }

            if opis.liczbaPolek > 0 {
                let n = opis.liczbaPolek
                ForEach(0..<n, id: \.self) { i in
                    let y = swiatloH * Double(i + 1) / Double(n + 1)
                    Rectangle()
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: swiatloW, height: max(t * 0.8, 1))
                        .offset(x: t, y: t + y)
                }
            }
        }
    }

    /// Pozycje przegród liczone z realnych szerokości komór, nie z równego
    /// podziału — komory 300/600/300 mają wyglądać jak 300/600/300.
    private func przegrody(swiatloW: Double) -> [Double] {
        let komory = opis.szerokosciKomor
        guard komory.count > 1 else { return [] }
        let suma = Double(komory.reduce(0, +))
        guard suma > 0 else { return [] }

        var pozycje: [Double] = []
        var biezaca = 0.0
        for komora in komory.dropLast() {
            biezaca += Double(komora)
            pozycje.append(swiatloW * biezaca / suma)
        }
        return pozycje
    }

    // MARK: - Fronty

    @ViewBuilder
    private func fronty(w: Double, h: Double, skala: Double) -> some View {
        let f = szczelina * skala / 2      // połowa fugi na licach skrajnych
        let wysokosci = opis.wysokosciSzuflad

        switch opis.rodzaj {
        case .szuflady where !opis.szufladyWewnetrzne && !wysokosci.isEmpty:
            frontySzuflad(wysokosci, w: w, h: h, fuga: f)

        case .szuflady:
            // Jedno lico, a za nim szuflady — to jest właśnie ta różnica,
            // której stary podgląd nie pokazywał wcale.
            lico(x: f, y: f, w: w - 2 * f, h: h - 2 * f)
                .overlay(alignment: .topLeading) {
                    szufladyWewnetrzne(wysokosci, w: w - 2 * f, h: h - 2 * f)
                }

        case .cargo:
            // Cargo to jeden wysoki front na całą wysokość korpusu.
            lico(x: f, y: f, w: w - 2 * f, h: h - 2 * f)
                .overlay(alignment: .center) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: min(w, h) * 0.22))
                        .foregroundStyle(StolarniaPalette.accentStrong.opacity(0.7))
                }

        case .zlew:
            // Pod zlewem/zmywarką górny pas to front pozorny — nie otwiera się
            // i nie ma za nim szuflady. Rysowany kreską, żeby było widać, że to
            // nie jest kolejna szuflada.
            let pas = min(h * 0.18, 140 * skala)
            ZStack(alignment: .topLeading) {
                lico(x: f, y: f, w: w - 2 * f, h: max(pas - f, 1))
                    .overlay(alignment: .center) {
                        Rectangle()
                            .fill(StolarniaPalette.accentStrong.opacity(0.5))
                            .frame(width: (w - 4 * f) * 0.5, height: 1)
                            .offset(y: pas / 2 - f)
                    }
                frontyDrzwi(w: w, h: h - pas, fuga: f)
                    .offset(y: pas)
            }

        case .agd:
            // Otwór na sprzęt: pusty, z obrysem światła zabudowy.
            Rectangle()
                .stroke(
                    StolarniaPalette.accentStrong.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .frame(width: w - 4 * f, height: h - 4 * f)
                .offset(x: 2 * f, y: 2 * f)
                .overlay(alignment: .center) {
                    Image(systemName: "oven")
                        .font(.system(size: min(w, h) * 0.24))
                        .foregroundStyle(StolarniaPalette.accentStrong.opacity(0.6))
                        .offset(x: 2 * f, y: 2 * f)
                }

        case .uchylny:
            // Front uchylny — jedno lico przez całą szerokość, ze strzałką
            // pokazującą kierunek otwierania do góry.
            lico(x: f, y: f, w: w - 2 * f, h: h - 2 * f)
                .overlay(alignment: .center) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: min(w, h) * 0.24))
                        .foregroundStyle(StolarniaPalette.accentStrong.opacity(0.7))
                }

        case .otwarty:
            EmptyView()

        case .drzwi:
            frontyDrzwi(w: w, h: h, fuga: f)
        }
    }

    private func frontySzuflad(
        _ wysokosci: [Int], w: Double, h: Double, fuga: Double
    ) -> some View {
        let suma = Double(wysokosci.reduce(0, +))
        let dostepne = h - 2 * fuga
        // Wysokości frontów są realne, więc 140/140/280 rysuje się jako 1:1:2.
        return ZStack(alignment: .topLeading) {
            ForEach(Array(wysokosci.enumerated()), id: \.offset) { i, wysokosc in
                let ponizej = Double(wysokosci.prefix(i).reduce(0, +))
                let hf = dostepne * Double(wysokosc) / suma
                let yOdDolu = dostepne * ponizej / suma
                lico(
                    x: fuga,
                    y: h - fuga - yOdDolu - hf + fuga / 2,
                    w: w - 2 * fuga,
                    h: max(hf - fuga, 1)
                )
            }
        }
    }

    private func frontyDrzwi(w: Double, h: Double, fuga: Double) -> some View {
        let komory = opis.szerokosciKomor
        // Bez zdefiniowanych komór: szeroka szafka dostaje dwoje drzwi, bo
        // pojedyncze skrzydło ponad 600 mm wypacza się i obciąża zawiasy.
        let udzialy: [Double] = komory.isEmpty
            ? (opis.szerokoscMM > 600 ? [1, 1] : [1])
            : komory.map(Double.init)
        let suma = udzialy.reduce(0, +)
        let dostepne = w - 2 * fuga

        return ZStack(alignment: .topLeading) {
            ForEach(Array(udzialy.enumerated()), id: \.offset) { i, udzial in
                let przed = udzialy.prefix(i).reduce(0, +)
                let wf = dostepne * udzial / suma
                lico(
                    x: fuga + dostepne * przed / suma + fuga / 2,
                    y: fuga,
                    w: max(wf - fuga, 1),
                    h: h - 2 * fuga
                )
            }
        }
    }

    private func szufladyWewnetrzne(
        _ wysokosci: [Int], w: Double, h: Double
    ) -> some View {
        let lista = wysokosci.isEmpty ? [1, 1, 1] : wysokosci
        let suma = Double(lista.reduce(0, +))
        return ZStack(alignment: .topLeading) {
            ForEach(Array(lista.dropLast().enumerated()), id: \.offset) { i, _ in
                let ponizej = Double(lista.prefix(i + 1).reduce(0, +))
                Rectangle()
                    .fill(StolarniaPalette.accentStrong.opacity(0.45))
                    .frame(width: w * 0.62, height: 1)
                    .offset(x: w * 0.19, y: h - h * ponizej / suma)
            }
        }
    }

    private func lico(x: Double, y: Double, w: Double, h: Double) -> some View {
        Rectangle()
            .fill(StolarniaPalette.accentStrong.opacity(0.20))
            .frame(width: max(w, 1), height: max(h, 1))
            .overlay(
                Rectangle()
                    .stroke(StolarniaPalette.accentStrong.opacity(0.55), lineWidth: 1)
            )
            .offset(x: x, y: y)
    }
}
