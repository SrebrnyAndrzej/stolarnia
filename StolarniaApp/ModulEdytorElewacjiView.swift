import DomainCore

/// Panele inspektora kreatora rysunkowego.
///
/// Pięć pozycji — poniżej progu siedmiu elementów, powyżej którego sekcja
/// wymaga podgrupowania, a nie mniejszej czcionki.
enum PanelIdV0107: String, Hashable {
    case zaznaczenie
    case gabaryt
    case akcje
    case konsekwencje
    case podsumowanie
}
import SwiftUI

/// Kreator rysunkowy modułu (beta): jedna powierzchnia do tworzenia i edycji.
/// Elewacja mebla rysowana na płótnie — przeciąganie krawędzi zmienia gabaryt,
/// narzędzie „Podziel" tnie moduł na strefy, dotknięcie strefy otwiera jej
/// konfigurację w inspektorze. Karta techniczna (formatki) przelicza się na żywo.
struct ModulEdytorElewacjiView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var modul: ElevationModule
    @State private var zaznaczonaStrefa: Int?
    @State private var zaznaczonaKomoraID: String?
    /// Który panel inspektora jest rozwinięty — najwyżej jeden naraz.
    ///
    /// Startujemy na zaznaczeniu, bo to jest odpowiedź na ostatni gest
    /// projektanta; gabaryt i akcje ustawia się raz na moduł.
    @State private var otwartyPanelV0107: PanelIdV0107? = .zaznaczenie
    @State private var zaznaczonyFrontID: UUID?
    @State private var narzedzie: NarzedzieElewacji = .wybierz
    @State private var kartaRozwinieta = false
    @State private var celGestu: CelGestuElewacji?
    @State private var fitStartuGestu: FitElewacji?
    @State private var zapisywanie = false
    @State private var ostatniaZmianaProdukcji:
        OstatniaZmianaProdukcji?

    /// Tryb edycji istniejącego modułu: zapis wraca do wołającego.
    /// `nil` = tryb kreatora (presety, bez przycisku Zapisz).
    private let onZapisz: ((ElevationModule) async -> Bool)?

    init(
        modul: ElevationModule = ModulEdytorElewacjiView.presety[0].modul,
        onZapisz: ((ElevationModule) async -> Bool)? = nil
    ) {
        _modul = State(initialValue: modul)
        self.onZapisz = onZapisz
    }

    private var trybEdycji: Bool { onZapisz != nil }

    // MARK: - Presety (edycja gotowego modułu = to samo płótno)

    struct PresetElewacji {
        let nazwa: String
        let modul: ElevationModule
    }

    private struct OstatniaZmianaProdukcji: Identifiable {
        let id = UUID()
        let opis: String
        let snapshot:
            ElevationProductionSnapshot
        let delta:
            ElevationProductionDelta
        /// Wynik `AssemblyInspector` po zmianie. Celowo NIE blokuje edycji:
        /// projekty w toku mają formatki zamówione i kreator nie może odmówić
        /// ich otwarcia. Ma pokazać problem w chwili rysowania, a nie przy pile.
        let zastrzezenia: [ProductionIssue]
    }

    static let presety: [PresetElewacji] = [
        PresetElewacji(
            nazwa: "Nowy moduł",
            modul: ElevationModule(name: "Nowy moduł")
        ),
        PresetElewacji(
            nazwa: "Dolna 60 · 3 szuflady",
            modul: ElevationModule(
                name: "Dolna 60 · 3 szuflady",
                zones: [ElevationZone(kind: .drawers, drawerCount: 3)]
            )
        ),
        PresetElewacji(
            nazwa: "Szafka 80 · szuflady + drzwi",
            modul: ElevationModule(
                name: "Szafka 80 · szuflady + drzwi",
                width: 800,
                splits: [300],
                zones: [
                    ElevationZone(
                        kind: .drawers,
                        drawerCount: 2,
                        drawerSystem: .blumLegrabox,
                        drawerProfileName: "C"
                    ),
                    ElevationZone(kind: .doors)
                ]
            )
        ),
        PresetElewacji(
            nazwa: "Szafka 90 · dwoje drzwi",
            modul: ElevationModule(
                name: "Szafka 90 · dwoje drzwi",
                width: 900,
                zones: [ElevationZone(kind: .doors, columns: 2)]
            )
        ),
        PresetElewacji(
            nazwa: "Słupek 60 · AGD",
            modul: ElevationModule(
                name: "Słupek 60 · AGD",
                height: 2100,
                splits: [700, 1300],
                zones: [
                    ElevationZone(
                        kind: .drawers,
                        drawerCount: 3,
                        drawerSystem: .gtvAxisPro,
                        drawerProfileName: "H120"
                    ),
                    ElevationZone(kind: .appliance),
                    ElevationZone(kind: .shelves, shelfCount: 3)
                ]
            )
        )
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !trybEdycji {
                    pasekPresetow
                    Divider()
                }
                HStack(spacing: 0) {
                    obszarRoboczy
                    Divider()
                    inspektor
                        .frame(width: 312)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .layoutPriority(1)
            }
            .navigationTitle(trybEdycji ? modul.name : "Kreator rysunkowy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(trybEdycji ? "Anuluj" : "Zamknij") { dismiss() }
                        .disabled(zapisywanie)
                }
                if let onZapisz {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                zapisywanie = true
                                let zapisano = await onZapisz(modul)
                                zapisywanie = false
                                if zapisano { dismiss() }
                            }
                        } label: {
                            if zapisywanie {
                                ProgressView()
                            } else {
                                Text("Zapisz")
                            }
                        }
                        .disabled(zapisywanie)
                    }
                }
            }
        }
    }

    private var obszarRoboczy: some View {
        ZStack(alignment: .bottom) {
            plotno
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .layoutPriority(1)

            VStack(spacing: 8) {
                kartaTechniczna
                pasekStatusu
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Pasek presetów

    private var pasekPresetow: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Otwórz moduł")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(Self.presety, id: \.nazwa) { preset in
                        chip(
                            preset.nazwa,
                            aktywny: modul.name == preset.modul.name
                        ) {
                            modul = preset.modul
                            zaznaczonaStrefa = nil
                            zaznaczonaKomoraID = nil
                            zaznaczonyFrontID = nil
                            ostatniaZmianaProdukcji = nil
                            narzedzie = .wybierz
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            Text("Edytujesz: \(modul.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Płótno

    private var plotno: some View {
        GeometryReader { geo in
            let fit = dopasowanie(w: geo.size)
            Canvas { context, size in
                rysujSiatke(&context, size: size, fit: fit)
                rysujModul(&context, fit: fit)
            }
            .contentShape(Rectangle())
            .gesture(gestPlotna(fit: fit))
        }
        .background(Color(.systemGroupedBackground))
        .frame(minWidth: 360, minHeight: 360)
    }

    private func dopasowanie(w size: CGSize) -> FitElewacji {
        let marginesL: CGFloat = 68
        let marginesP: CGFloat = 48
        let marginesG: CGFloat = 26
        let marginesD: CGFloat = 46
        let w = CGFloat(modul.width.rawValue)
        let h = CGFloat(modul.height.rawValue)
        let dostepnaW = max(size.width - marginesL - marginesP, 60)
        let dostepnaH = max(size.height - marginesG - marginesD, 60)
        let skala = min(dostepnaW / w, dostepnaH / h)
        return FitElewacji(
            skala: skala,
            ox: marginesL + (dostepnaW - w * skala) / 2,
            oy: marginesG + (dostepnaH - h * skala) / 2,
            wysokoscMM: Double(h)
        )
    }

    // MARK: Rysowanie

    private func rysujSiatke(
        _ context: inout GraphicsContext,
        size: CGSize,
        fit: FitElewacji
    ) {
        let krok = 100.0 * fit.skala
        guard krok >= 9 else { return }
        var path = Path()
        var x = fit.x(0).truncatingRemainder(dividingBy: krok)
        if x < 0 { x += krok }
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += krok
        }
        var y = fit.y(0).truncatingRemainder(dividingBy: krok)
        if y < 0 { y += krok }
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += krok
        }
        context.stroke(path, with: .color(.secondary.opacity(0.14)), lineWidth: 1)
    }

    private func rysujModul(_ context: inout GraphicsContext, fit: FitElewacji) {
        let w = modul.width.rawValue
        let h = modul.height.rawValue
        let t = modul.carcassThickness.rawValue

        // Korpus
        let korpus = fit.rect(x0: 0, y0: 0, x1: w, y1: h)
        context.fill(Path(korpus), with: .color(Color(.systemBackground)))
        context.stroke(Path(korpus), with: .color(.primary.opacity(0.85)), lineWidth: 2)
        let wewnetrzny = fit.rect(x0: t, y0: t, x1: w - t, y1: h - t)
        context.stroke(Path(wewnetrzny), with: .color(.primary.opacity(0.2)), lineWidth: 1)

        // Strefy
        for segment in modul.segments {
            rysujStrefe(&context, segment: segment, fit: fit)
        }
        rysujFrontyWarstwowe(&context, fit: fit)

        // Zaznaczenie strefy
        if let index = zaznaczonaStrefa, modul.zones.indices.contains(index) {
            let segment = modul.segments[index]
            let ramka = fit.rect(
                x0: 2 / fit.skalaDouble, y0: segment.lower.rawValue,
                x1: w - 2 / fit.skalaDouble, y1: segment.upper.rawValue
            )
            context.stroke(
                Path(roundedRect: ramka.insetBy(dx: 2, dy: 2), cornerRadius: 3),
                with: .color(.accentColor),
                lineWidth: 2.5
            )
        }

        // Zaznaczenie komory
        if let cell = zaznaczonaKomora {
            let ramka = fit.rect(
                x0: cell.left.rawValue,
                y0: cell.lower.rawValue,
                x1: cell.right.rawValue,
                y1: cell.upper.rawValue
            )
            context.stroke(
                Path(roundedRect: ramka.insetBy(dx: 3, dy: 3), cornerRadius: 4),
                with: .color(.orange),
                lineWidth: 3
            )
            context.fill(
                Path(roundedRect: ramka.insetBy(dx: 4, dy: 4), cornerRadius: 4),
                with: .color(.orange.opacity(0.08))
            )
            context.draw(
                Text(cell.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange),
                at: CGPoint(x: ramka.midX, y: ramka.minY + 14)
            )
        }

        // Linie podziału z uchwytami
        for (index, split) in modul.splits.enumerated() {
            let y = fit.y(split.rawValue)
            var linia = Path()
            linia.move(to: CGPoint(x: fit.x(0), y: y))
            linia.addLine(to: CGPoint(x: fit.x(w), y: y))
            context.stroke(linia, with: .color(.accentColor), lineWidth: 2)

            let uchwyt = CGRect(x: fit.x(w / 2) - 7, y: y - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: uchwyt), with: .color(.accentColor))
            context.stroke(
                Path(ellipseIn: uchwyt),
                with: .color(Color(.systemBackground)),
                lineWidth: 2
            )
            _ = index
        }

        // Uchwyty krawędzi (prawa i górna)
        for punkt in [CGPoint(x: fit.x(w), y: fit.y(h / 2)),
                      CGPoint(x: fit.x(w / 2), y: fit.y(h))] {
            let r = CGRect(x: punkt.x - 6, y: punkt.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: r), with: .color(.accentColor))
            context.stroke(
                Path(ellipseIn: r),
                with: .color(Color(.systemBackground)),
                lineWidth: 2
            )
        }

        // Wymiary gabarytu
        context.draw(
            Text("\(Int(w)) mm").font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary),
            at: CGPoint(x: fit.x(w / 2), y: fit.y(0) + 24)
        )
        context.draw(
            Text("\(Int(h)) mm").font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary),
            at: CGPoint(x: fit.x(0) - 36, y: fit.y(h / 2))
        )

        // Wysokości stref przy prawej krawędzi
        if modul.zones.count > 1 {
            for segment in modul.segments {
                let srodek = (segment.lower.rawValue + segment.upper.rawValue) / 2
                context.draw(
                    Text("\(Int(segment.zoneHeight.rawValue))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary),
                    at: CGPoint(x: fit.x(w) + 22, y: fit.y(srodek))
                )
            }
        }
    }

    private func rysujFrontyWarstwowe(
        _ context: inout GraphicsContext,
        fit: FitElewacji
    ) {
        for span in modul.frontSpans {
            guard let bounds = modul.frontSpanBounds(span) else { continue }
            let selected = span.id == zaznaczonyFrontID
            let front = fit.rect(
                x0: bounds.left.rawValue + span.sideGap.rawValue / 2,
                y0: bounds.lower.rawValue + span.verticalGap.rawValue / 2,
                x1: bounds.right.rawValue - span.sideGap.rawValue / 2,
                y1: bounds.upper.rawValue - span.verticalGap.rawValue / 2
            )
            context.fill(
                Path(roundedRect: front, cornerRadius: 3),
                with: .color((selected ? Color.accentColor : .green).opacity(0.12))
            )
            context.stroke(
                Path(roundedRect: front, cornerRadius: 3),
                with: .color((selected ? Color.accentColor : .green).opacity(0.9)),
                style: StrokeStyle(lineWidth: selected ? 3 : 2, dash: [7, 4])
            )
            context.draw(
                Text(span.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(selected ? Color.accentColor : .green),
                at: CGPoint(x: front.midX, y: front.minY + 13)
            )
        }
    }

    private func rysujStrefe(
        _ context: inout GraphicsContext,
        segment: ElevationModule.ZoneSegment,
        fit: FitElewacji
    ) {
        let zone = segment.zone
        let t = modul.carcassThickness.rawValue
        let w = modul.width.rawValue
        let y0 = segment.lower.rawValue
        let y1 = segment.upper.rawValue

        if zone.kind == .appliance {
            let ramka = fit.rect(x0: t + 4 / fit.skalaDouble, y0: y0 + 3, x1: w - t - 4 / fit.skalaDouble, y1: y1 - 3)
            var dash = Path(roundedRect: ramka, cornerRadius: 2)
            context.stroke(
                dash.strokedPath(StrokeStyle(lineWidth: 1.4, dash: [6, 4])),
                with: .color(.blue.opacity(0.7)),
                lineWidth: 1
            )
            context.draw(
                Text("AGD").font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue.opacity(0.8)),
                at: CGPoint(x: ramka.midX, y: ramka.midY)
            )
            dash = Path()
            return
        }

        let cols = max(1, zone.columns)
        let colW = modul.columnInnerWidth(columns: cols).rawValue

        // Przegrody pionowe
        for j in 1..<max(cols, 1) where cols > 1 {
            let x = t + (colW + t) * Double(j - 1) + colW
            let przegroda = fit.rect(x0: x, y0: y0, x1: x + t, y1: y1)
            context.fill(Path(przegroda), with: .color(.primary.opacity(0.28)))
        }

        for column in 0..<cols {
            let x0 = t + (colW + t) * Double(column)
            let x1 = x0 + colW

            switch zone.kind {
            case .drawers:
                rysujSzuflady(
                    &context, zone: zone, zoneIndex: segment.index, fit: fit,
                    x0: x0, x1: x1, y0: y0, y1: y1,
                    zoneHeight: segment.zoneHeight
                )

            case .doors:
                let front = fit.rect(x0: x0 + 2, y0: y0 + 2, x1: x1 - 2, y1: y1 - 2)
                context.fill(
                    Path(roundedRect: front, cornerRadius: 2),
                    with: .color(.brown.opacity(0.22))
                )
                context.stroke(
                    Path(roundedRect: front, cornerRadius: 2),
                    with: .color(.brown.opacity(0.8)),
                    lineWidth: 1.2
                )
                for frac in [0.28, 0.72] {
                    let zawias = CGRect(
                        x: front.minX + 5,
                        y: front.minY + front.height * frac - 2.5,
                        width: 5, height: 5
                    )
                    context.fill(Path(ellipseIn: zawias), with: .color(.brown.opacity(0.8)))
                }
                var uchwyt = Path()
                uchwyt.move(to: CGPoint(x: front.maxX - 9, y: front.minY + front.height * 0.42))
                uchwyt.addLine(to: CGPoint(x: front.maxX - 9, y: front.minY + front.height * 0.58))
                context.stroke(
                    uchwyt,
                    with: .color(.brown),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                )

            case .shelves:
                let pole = fit.rect(x0: x0, y0: y0, x1: x1, y1: y1)
                context.fill(Path(pole), with: .color(.accentColor.opacity(0.1)))
                guard zone.shelfCount > 0 else { break }
                for i in 1...zone.shelfCount {
                    let frac = Double(i) / Double(zone.shelfCount + 1)
                    let y = y0 + (y1 - y0) * frac
                    let polka = fit.rect(x0: x0, y0: y - 1.5, x1: x1, y1: y + 1.5)
                    context.fill(Path(polka), with: .color(.accentColor.opacity(0.75)))
                }

            case .hanging:
                let pole = fit.rect(x0: x0, y0: y0, x1: x1, y1: y1)
                context.fill(Path(pole), with: .color(.teal.opacity(0.09)))
                let railHeight =
                    modul.effectiveRailHeight(
                        forZoneAt:
                            segment.index
                    )?
                    .rawValue
                    ?? (y1 - y0) * 0.72
                let y =
                    y0 + railHeight
                let rail = fit.rect(
                    x0:
                        x0 + 10,
                    y0:
                        y - 5,
                    x1:
                        x1 - 10,
                    y1:
                        y + 5
                )
                context.fill(
                    Path(roundedRect: rail, cornerRadius: 5),
                    with: .color(.teal.opacity(0.82))
                )
                for x in [rail.minX + 8, rail.maxX - 8] {
                    var support = Path()
                    support.move(to: CGPoint(x: x, y: rail.midY))
                    support.addLine(to: CGPoint(x: x, y: rail.midY + 18))
                    context.stroke(
                        support,
                        with: .color(.teal.opacity(0.75)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }

            case .appliance:
                break
            }
        }
    }

    private func rysujSzuflady(
        _ context: inout GraphicsContext,
        zone: ElevationZone,
        zoneIndex: Int,
        fit: FitElewacji,
        x0: Double, x1: Double, y0: Double, y1: Double,
        zoneHeight: Millimeters
    ) {
        let layout = DrawerLayoutCalculator.layout(
            zoneHeight: zoneHeight,
            drawerCount: zone.drawerCount,
            columnInnerWidth: Millimeters(x1 - x0),
            profile: zone.drawerProfile
        )
        guard layout.frontHeight.rawValue > 4 else { return }

        let kolor: Color = layout.isValid ? .brown : .red
        let mb = DrawerLayoutCalculator.bottomMargin.rawValue
        let gap = DrawerLayoutCalculator.frontGap.rawValue
        let frontHeights =
            modul.drawerFrontHeights(
                forZoneAt: zoneIndex
            )
            .map(\.rawValue)

        var cursorY = y0 + mb
        for frontHeight in frontHeights {
            let front = fit.rect(x0: x0 + 2, y0: cursorY, x1: x1 - 2, y1: cursorY + frontHeight)
            context.fill(
                Path(roundedRect: front, cornerRadius: 2),
                with: .color(kolor.opacity(layout.isValid ? 0.22 : 0.16))
            )
            context.stroke(
                Path(roundedRect: front, cornerRadius: 2),
                with: .color(kolor.opacity(0.85)),
                lineWidth: 1.2
            )
            if front.height > 9 {
                var uchwyt = Path()
                uchwyt.move(to: CGPoint(x: front.midX - front.width * 0.17, y: front.midY))
                uchwyt.addLine(to: CGPoint(x: front.midX + front.width * 0.17, y: front.midY))
                context.stroke(
                    uchwyt,
                    with: .color(kolor),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
            }
            cursorY += frontHeight + gap
        }
    }

    // MARK: Gesty

    private func gestPlotna(fit: FitElewacji) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gest in
                if celGestu == nil {
                    fitStartuGestu = fit
                    celGestu = rozpoznajCel(gest.startLocation, fit: fit)
                }
                let f = fitStartuGestu ?? fit
                switch celGestu {
                case .szerokosc:
                    let mm = przytnij(zaokraglij10(f.mmX(gest.location.x)), 200...1500)
                    wykonajZmianeProdukcji(
                        "Zmieniono szerokość"
                    ) {
                        modul.width = Millimeters(mm)
                    }
                case .wysokosc:
                    let mm = przytnij(zaokraglij10(f.mmY(gest.location.y)), 300...2600)
                    wykonajZmianeProdukcji(
                        "Zmieniono wysokość"
                    ) {
                        modul.setHeightClamped(Millimeters(mm))
                    }
                case .podzial(let index):
                    let mm = zaokraglij10(f.mmY(gest.location.y))
                    wykonajZmianeProdukcji(
                        "Przesunięto podział strefy"
                    ) {
                        modul.moveSplit(at: index, to: Millimeters(mm))
                    }
                case .tlo, nil:
                    break
                }
            }
            .onEnded { gest in
                let f = fitStartuGestu ?? fit
                let przesuniecie = gest.translation
                celGestu = nil
                fitStartuGestu = nil
                let dystans2 = przesuniecie.width * przesuniecie.width
                    + przesuniecie.height * przesuniecie.height
                guard dystans2 < 36 else { return }
                obsluzTap(gest.location, fit: f)
            }
    }

    private func rozpoznajCel(_ punkt: CGPoint, fit: FitElewacji) -> CelGestuElewacji {
        let w = modul.width.rawValue
        let h = modul.height.rawValue

        let naPrawejKrawedzi = abs(punkt.x - fit.x(w)) < 18
            && punkt.y > fit.y(h) - 18 && punkt.y < fit.y(0) + 18
        if naPrawejKrawedzi { return .szerokosc }

        let naGornejKrawedzi = abs(punkt.y - fit.y(h)) < 18
            && punkt.x > fit.x(0) - 18 && punkt.x < fit.x(w) + 18
        if naGornejKrawedzi { return .wysokosc }

        for (index, split) in modul.splits.enumerated() {
            let naPodziale = abs(punkt.y - fit.y(split.rawValue)) < 14
                && punkt.x > fit.x(0) - 10 && punkt.x < fit.x(w) + 10
            if naPodziale { return .podzial(index) }
        }
        return .tlo
    }

    private func obsluzTap(_ punkt: CGPoint, fit: FitElewacji) {
        let mmX = fit.mmX(punkt.x)
        let mmY = fit.mmY(punkt.y)

        if narzedzie == .podziel {
            var nowyIndeks: Int?
            wykonajZmianeProdukcji(
                "Podzielono moduł"
            ) {
                nowyIndeks =
                    modul.splitZone(
                        at: Millimeters(zaokraglij10(mmY))
                    )
            }
            if let nowyIndeks {
                zaznaczonaStrefa = nowyIndeks
                zaznaczonaKomoraID = nil
                zaznaczonyFrontID = nil
                narzedzie = .wybierz
            }
            return
        }

        guard mmX >= -20, mmX <= modul.width.rawValue + 20 else {
            zaznaczonaStrefa = nil
            zaznaczonaKomoraID = nil
            zaznaczonyFrontID = nil
            return
        }

        if let span = front(wPunkcieMMX: mmX, mmY: mmY) {
            if zaznaczonyFrontID == span.id {
                zaznaczonyFrontID = nil
            } else {
                zaznaczonyFrontID = span.id
                zaznaczonaKomoraID = nil
                zaznaczonaStrefa = span.lowerZoneIndex
            }
        } else if let cell = komora(wPunkcieMMX: mmX, mmY: mmY) {
            if zaznaczonaKomoraID == cell.id {
                zaznaczonaKomoraID = nil
                zaznaczonaStrefa = nil
            } else {
                zaznaczonyFrontID = nil
                zaznaczonaKomoraID = cell.id
                zaznaczonaStrefa = cell.zoneIndex
            }
        } else {
            zaznaczonaStrefa = nil
            zaznaczonaKomoraID = nil
            zaznaczonyFrontID = nil
        }
    }

    // MARK: - Inspektor

    /// Kolejność sekcji jest celowa: **to, co zaznaczone, jest tuż pod paskiem
    /// narzędzi**, a nie pod gabarytem i szybkimi akcjami.
    ///
    /// Wcześniej sekcja zaznaczonego elementu była trzecia od góry, pod
    /// `sekcjaGabarytu` i `sekcjaSzybkichAkcjiSzafy` — razem ok. 140 linii
    /// układu. Na iPadzie znaczyło to, że projektant dotykał komory na rysunku,
    /// a jej ustawienia lądowały pod zgięciem i trzeba było scrollować do
    /// rzeczy, którą się właśnie wskazało. `sekcjaNarzedzia` została na górze,
    /// bo to dwa przyciski i stała kotwica trybu pracy.
    private var inspektor: some View {
        VStack(spacing: 0) {
            // Kontekst i narzędzie **nad przewijaniem** — to są rzeczy,
            // które muszą być widoczne niezależnie od tego, gdzie się jest
            // w panelach. Wcześniej pasek narzędzia był pierwszą pozycją
            // listy i znikał po przewinięciu do prowadnic.
            VStack(alignment: .leading, spacing: 10) {
                pasekKontekstuV0107
                sekcjaNarzedzia
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    panelZaznaczeniaV0107
                    panelGabarytuV0107
                    panelAkcjiV0107
                    panelKonsekwencjiV0107
                    panelPodsumowaniaV0107
                }
                .padding(14)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Inspektor w panelach (V0107)

    /// Który panel jest otwarty. **Najwyżej jeden.**
    ///
    /// Zwijane sekcje, które można otworzyć wszystkie, po tygodniu są otwarte
    /// wszystkie — i wracamy do przewijania, tylko z dodatkowymi kliknięciami.
    /// Przy jednym otwartym wysokość inspektora jest z grubsza stała.
    private func wiazaniePaneluV0107(
        _ panel: PanelIdV0107
    ) -> Binding<Bool> {
        Binding(
            get: { otwartyPanelV0107 == panel },
            set: { otwiera in
                otwartyPanelV0107 = otwiera ? panel : nil
            }
        )
    }

    private var pasekKontekstuV0107: some View {
        let kontekst = kontekstZaznaczeniaV0107
        return PasekKontekstuInspektoraV0107(
            tytul: kontekst.tytul,
            opis: kontekst.opis,
            wyroznienie: kontekst.wyroznienie
        )
    }

    /// Co jest zaznaczone, opisane tak, żeby dało się to sprawdzić bez
    /// patrzenia na rysunek.
    private var kontekstZaznaczeniaV0107:
        (tytul: String, opis: String, wyroznienie: String?)
    {
        if let span = zaznaczonyFront {
            let wymiar = modul.frontSpanFaceV0104(span).map {
                "\(Int($0.width.rawValue)) × \(Int($0.height.rawValue)) mm"
            }
            return (
                span.displayName,
                "Front · \(nazwaOtwarcia(span.opening))",
                wymiar
            )
        }

        if let cell = zaznaczonaKomora {
            let strefa = modul.zones.indices.contains(cell.zoneIndex)
                ? modul.zones[cell.zoneIndex] : nil
            return (
                cell.displayName,
                strefa.map { "Strefa \(cell.zoneIndex + 1) · \($0.kind.displayName)" }
                    ?? "Komora",
                "\(Int(cell.width.rawValue)) × \(Int(cell.height.rawValue)) mm"
            )
        }

        if let index = zaznaczonaStrefa, modul.zones.indices.contains(index) {
            let strefa = modul.zones[index]
            return (
                "Strefa \(index + 1)",
                strefa.kind.displayName,
                "\(strefa.columns) kol."
            )
        }

        return (
            "Nic nie jest zaznaczone",
            "Dotknij komory albo frontu na rysunku — jego ustawienia pojawią się poniżej.",
            nil
        )
    }

    /// Panel zaznaczenia jest **otwarty domyślnie**, bo dotyczy tego, co
    /// projektant właśnie wskazał palcem.
    @ViewBuilder
    private var panelZaznaczeniaV0107: some View {
        let maZaznaczenie =
            zaznaczonyFront != nil
            || zaznaczonaKomora != nil
            || zaznaczonaStrefa != nil

        PanelInspektoraV0107(
            tytul: zaznaczonyFront != nil ? "Front" : "Komora i strefa",
            ikona: zaznaczonyFront != nil ? "rectangle.portrait" : "square.split.1x2",
            wartosc: nil,
            wyrozniony: maZaznaczenie,
            otwarty: wiazaniePaneluV0107(.zaznaczenie)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let span = zaznaczonyFront {
                    sekcjaFrontu(span)
                } else if let cell = zaznaczonaKomora {
                    sekcjaKomory(cell)
                    sekcjaStrefy(cell.zoneIndex)
                } else if let index = zaznaczonaStrefa,
                          modul.zones.indices.contains(index) {
                    sekcjaStrefy(index)
                } else {
                    podpowiedzBrakuZaznaczenia
                }
            }
        }
    }

    private var panelGabarytuV0107: some View {
        PanelInspektoraV0107(
            tytul: "Gabaryt",
            ikona: "ruler",
            wartosc: "\(Int(modul.width.rawValue)) × \(Int(modul.height.rawValue)) × \(Int(modul.depth.rawValue))",
            otwarty: wiazaniePaneluV0107(.gabaryt)
        ) {
            sekcjaGabarytu
        }
    }

    private var panelAkcjiV0107: some View {
        PanelInspektoraV0107(
            tytul: "Szybkie akcje",
            ikona: "bolt",
            otwarty: wiazaniePaneluV0107(.akcje)
        ) {
            sekcjaSzybkichAkcjiSzafy
        }
    }

    /// Panel konsekwencji **wyróżnia się, gdy kontrola coś zgłasza**.
    ///
    /// To jedyne miejsce, gdzie wyróżnienie jest przyznawane automatycznie:
    /// problem produkcyjny ma być widoczny przy zwiniętym panelu, bo inaczej
    /// projektant dowie się o nim dopiero przy pile.
    private var panelKonsekwencjiV0107: some View {
        let zastrzezenia = ostatniaZmianaProdukcji?.zastrzezenia ?? []
        let bledy = zastrzezenia.filter { $0.severity == .error }

        return PanelInspektoraV0107(
            tytul: "Konsekwencje zmiany",
            ikona: bledy.isEmpty ? "arrow.triangle.branch" : "exclamationmark.triangle.fill",
            wartosc: zastrzezenia.isEmpty
                ? nil
                : "\(zastrzezenia.count) uwag",
            wyrozniony: !zastrzezenia.isEmpty,
            otwarty: wiazaniePaneluV0107(.konsekwencje)
        ) {
            sekcjaKonsekwencjiZmiany
        }
    }

    private var panelPodsumowaniaV0107: some View {
        PanelInspektoraV0107(
            tytul: "Podsumowanie",
            ikona: "list.bullet.rectangle",
            wartosc: "\(modul.totalCutPieces) formatek",
            otwarty: wiazaniePaneluV0107(.podsumowanie)
        ) {
            sekcjaPodsumowania
        }
    }

    /// Pusty stan mówi, co zrobić dalej — reguła UX projektu. Ikona plus tekst,
    /// bo sam szary napis w długiej liście sekcji ginie.
    private var podpowiedzBrakuZaznaczenia: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.title3)
                .foregroundStyle(StolarniaPalette.accentStrong)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nic nie jest zaznaczone")
                    .font(.caption.weight(.semibold))
                Text("Dotknij komory albo frontu na rysunku — jego ustawienia "
                     + "pojawią się tutaj.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(StolarniaPalette.accentStrong.opacity(0.08))
        )
    }

    private var sekcjaNarzedzia: some View {
        VStack(alignment: .leading, spacing: 6) {
            naglowek("Narzędzie")
            HStack(spacing: 8) {
                przyciskNarzedzia("Wybierz", ikona: "cursorarrow", wartosc: .wybierz)
                przyciskNarzedzia("Podziel", ikona: "scissors", wartosc: .podziel)
            }
            if narzedzie == .podziel {
                Text("Dotknij wnętrza modułu, aby przeciąć go poziomo.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func przyciskNarzedzia(
        _ tytul: String,
        ikona: String,
        wartosc: NarzedzieElewacji
    ) -> some View {
        if narzedzie == wartosc {
            Button {
                narzedzie = wartosc
            } label: {
                Label(tytul, systemImage: ikona).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button {
                narzedzie = wartosc
                if wartosc == .podziel {
                    zaznaczonaStrefa = nil
                    zaznaczonaKomoraID = nil
                    zaznaczonyFrontID = nil
                }
            } label: {
                Label(tytul, systemImage: ikona).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var sekcjaGabarytu: some View {
        VStack(alignment: .leading, spacing: 10) {
            naglowek("Gabaryt korpusu")
            PoleWymiaruMM(
                tytul: "Szerokość",
                wartosc: Binding(
                    get: { modul.width.rawValue },
                    set: { value in
                        wykonajZmianeProdukcji(
                            "Zmieniono szerokość"
                        ) {
                            modul.width =
                                Millimeters(
                                    przytnij(
                                        zaokraglij10(value),
                                        200...1500
                                    )
                                )
                        }
                    }
                ),
                zakres: 200...1500
            )
            PoleWymiaruMM(
                tytul: "Wysokość",
                wartosc: Binding(
                    get: { modul.height.rawValue },
                    set: { value in
                        wykonajZmianeProdukcji(
                            "Zmieniono wysokość"
                        ) {
                            modul.setHeightClamped(
                                Millimeters(
                                    przytnij(
                                        zaokraglij10(value),
                                        300...2600
                                    )
                                )
                            )
                        }
                    }
                ),
                zakres: 300...2600
            )
            PoleWymiaruMM(
                tytul: "Głębokość",
                wartosc: Binding(
                    get: { modul.depth.rawValue },
                    set: { value in
                        wykonajZmianeProdukcji(
                            "Zmieniono głębokość"
                        ) {
                            modul.depth =
                                Millimeters(
                                    przytnij(
                                        zaokraglij10(value),
                                        200...900
                                    )
                                )
                        }
                    }
                ),
                zakres: 200...900
            )
        }
    }

    private var sekcjaSzybkichAkcjiSzafy: some View {
        VStack(alignment: .leading, spacing: 10) {
            naglowek("Szybkie układy szafy")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 126), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button {
                    ustawWybranaLubNajwiekszaStrefe(
                        jako:
                            .hanging
                    )
                } label: {
                    Label("Drążek", systemImage: "figure.stand")
                }

                Button {
                    ustawWybranaLubNajwiekszaStrefe(
                        jako:
                            .shelves
                    )
                    if let index =
                        zaznaczonaStrefa {
                        ustawPolkiCo300MM(
                            wStrefie:
                                index
                        )
                    }
                } label: {
                    Label("Półki 300", systemImage: "books.vertical")
                }

                Button {
                    ustawKolumnyWStrefie(2)
                } label: {
                    Label("2 kolumny", systemImage: "rectangle.split.2x1")
                }

                Button {
                    ustawKolumnyWStrefie(3)
                } label: {
                    Label("3 kolumny", systemImage: "rectangle.split.3x1")
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)

            StolarniaWrapLayout() {
                Button {
                    dodajNadstawke(300)
                } label: {
                    Label("Nadstawka 300", systemImage: "square.split.1x2")
                }

                Button {
                    dodajNadstawke(400)
                } label: {
                    Label("400", systemImage: "square.split.1x2")
                }

                Button {
                    dodajNadstawke(600)
                } label: {
                    Label("600", systemImage: "square.split.1x2")
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.teal.opacity(0.08))
        )
    }

    @ViewBuilder
    private func sekcjaKomory(_ cell: ElevationModule.Cell) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                naglowek(cell.displayName)
                Spacer()
                Text(cell.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                wierszPodsumowania(
                    "Światło",
                    "\(Int(cell.width.rawValue)) × \(Int(cell.height.rawValue)) mm"
                )
                wierszPodsumowania(
                    "Typ",
                    cell.kind.displayName
                )
                if cell.shelfCount > 0 {
                    wierszPodsumowania(
                        "Półki",
                        "\(cell.shelfCount)"
                    )
                }
                if cell.drawerCount > 0 {
                    wierszPodsumowania(
                        "Szuflady",
                        "\(cell.drawerCount)"
                    )
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button {
                    podzielKomorePionowo(cell)
                } label: {
                    Label("Podziel pionowo", systemImage: "rectangle.split.2x1")
                }
                .disabled(!moznaPodzielicPionowo(cell))

                Button {
                    podzielKomorePoziomo(cell)
                } label: {
                    Label("Podziel poziomo", systemImage: "rectangle.split.1x2")
                }
                .disabled(!moznaPodzielicPoziomo(cell))

                Button {
                    ustawTypKomory(.doors, dla: cell)
                } label: {
                    Label("Drzwi", systemImage: "door.left.hand.open")
                }

                Button {
                    ustawTypKomory(.shelves, dla: cell)
                } label: {
                    Label("Półki", systemImage: "books.vertical")
                }

                Button {
                    ustawTypKomory(.hanging, dla: cell)
                } label: {
                    Label("Drążek", systemImage: "figure.stand")
                }

                Button {
                    ustawTypKomory(.drawers, dla: cell)
                } label: {
                    Label("Szuflady", systemImage: "shippingbox")
                }

                Button {
                    ustawTypKomory(.appliance, dla: cell)
                } label: {
                    Label("AGD", systemImage: "oven")
                }

                Button {
                    ustawFrontNaKomore(cell)
                } label: {
                    Label("Front komory", systemImage: "rectangle.front.leadinghalf.filled")
                }

                Button {
                    ustawFrontNaCalyModul(cell)
                } label: {
                    Label("Front modułu", systemImage: "rectangle.inset.filled")
                }

                Button(role: .destructive) {
                    wykonajZmianeProdukcji(
                        "Usunięto fronty"
                    ) {
                        modul.clearFrontSpans()
                    }
                    zaznaczonyFrontID = nil
                } label: {
                    Label("Usuń fronty", systemImage: "xmark.rectangle")
                }
                .disabled(modul.frontSpans.isEmpty)
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sekcjaFrontu(_ span: ElevationFrontSpan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                naglowek(span.displayName)
                Spacer()
                Text(String(span.id.uuidString.prefix(8)))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let bounds = modul.frontSpanBounds(span) {
                VStack(spacing: 6) {
                    wierszPodsumowania(
                        "Wymiar frontu",
                        "\(Int(max(bounds.height - span.verticalGap, .zero).rawValue)) × \(Int(max(bounds.width - span.sideGap, .zero).rawValue)) mm"
                    )
                    wierszPodsumowania(
                        "Zakres",
                        "S\(span.lowerZoneIndex + 1)-\(span.upperZoneIndex + 1), K\(span.leadingColumnIndex + 1)-\(span.trailingColumnIndex + 1)"
                    )
                }
            }

            naglowek("Otwieranie")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 116), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(FurnitureFrontOpeningV020.allCases, id: \.self) { opening in
                    chip(
                        nazwaOtwarcia(opening),
                        aktywny: span.opening == opening
                    ) {
                        aktualizujFront(span.id) {
                            $0.opening = opening
                        }
                    }
                }
            }

            sekcjaOkuciaFrontuV0103(span)

            Toggle(
                "Kryje szuflady wewnętrzne",
                isOn: Binding(
                    get: { span.coversInternalDrawers },
                    set: { value in
                        aktualizujFront(span.id) {
                            $0.coversInternalDrawers = value
                        }
                    }
                )
            )
            .font(.caption)

            naglowek("Zakres frontu")
            LicznikView(
                tytul: "Strefa od",
                wartosc: Binding(
                    get: { span.lowerZoneIndex + 1 },
                    set: { value in
                        aktualizujFront(span.id) {
                            $0.lowerZoneIndex = value - 1
                        }
                    }
                ),
                zakres: 1...max(modul.zones.count, 1)
            )
            LicznikView(
                tytul: "Strefa do",
                wartosc: Binding(
                    get: { span.upperZoneIndex + 1 },
                    set: { value in
                        aktualizujFront(span.id) {
                            $0.upperZoneIndex = value - 1
                        }
                    }
                ),
                zakres: 1...max(modul.zones.count, 1)
            )
            LicznikView(
                tytul: "Kolumna od",
                wartosc: Binding(
                    get: { span.leadingColumnIndex + 1 },
                    set: { value in
                        aktualizujFront(span.id) {
                            $0.leadingColumnIndex = value - 1
                        }
                    }
                ),
                zakres: 1...4
            )
            LicznikView(
                tytul: "Kolumna do",
                wartosc: Binding(
                    get: { span.trailingColumnIndex + 1 },
                    set: { value in
                        aktualizujFront(span.id) {
                            $0.trailingColumnIndex = value - 1
                        }
                    }
                ),
                zakres: 1...4
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button {
                    ustawFrontNaZakresStrefy(span)
                } label: {
                    Label("Cała strefa", systemImage: "rectangle.split.1x2")
                }

                Button {
                    ustawFrontNaZakresModulu(span)
                } label: {
                    Label("Cały moduł", systemImage: "rectangle.inset.filled")
                }

                Button(role: .destructive) {
                    wykonajZmianeProdukcji(
                        "Usunięto front"
                    ) {
                        modul.removeFrontSpan(id: span.id)
                    }
                    zaznaczonyFrontID = nil
                } label: {
                    Label("Usuń front", systemImage: "trash")
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sekcjaStrefy(_ index: Int) -> some View {
        let zone = modul.zones[index]
        let segment = modul.segments[index]

        VStack(alignment: .leading, spacing: 12) {
            naglowek("Strefa \(index + 1) — \(zone.kind.displayName)")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(ElevationZoneKind.allCases) { kind in
                    chip(kind.displayName, aktywny: zone.kind == kind) {
                        wykonajZmianeProdukcji(
                            "Zmieniono typ strefy na \(kind.displayName)"
                        ) {
                            modul.updateZone(at: index) {
                                $0.kind = kind
                            }
                        }
                    }
                }
            }

            PoleWymiaruMM(
                tytul: "Wysokość strefy",
                wartosc: Binding<Double>(
                    get: { segment.zoneHeight.rawValue },
                    set: { (value: Double) in
                        wykonajZmianeProdukcji(
                            "Zmieniono wysokość strefy"
                        ) {
                            modul.setZoneHeight(
                                Millimeters(zaokraglij10(value)),
                                forZoneAt: index
                            )
                        }
                    }
                ),
                zakres: 100...2600
            )

            if zone.kind != .appliance {
                LicznikView(
                    tytul: "Przegrody pionowe",
                    wartosc: Binding(
                        get: { modul.zones[index].columns - 1 },
                        set: { nowe in
                            wykonajZmianeProdukcji(
                                "Zmieniono liczbę przegród"
                            ) {
                                modul.updateZone(at: index) {
                                    $0.columns = nowe + 1
                                }
                            }
                        }
                    ),
                    zakres: 0...3
                )
                Text("Światło kolumny: \(Int(modul.columnInnerWidth(columns: zone.columns).rawValue)) mm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if zone.kind == .shelves {
                LicznikView(
                    tytul: "Liczba półek",
                    wartosc: Binding(
                        get: { modul.zones[index].shelfCount },
                        set: { nowe in
                            wykonajZmianeProdukcji(
                                "Zmieniono liczbę półek"
                            ) {
                                modul.updateZone(at: index) {
                                    $0.shelfCount = nowe
                                }
                            }
                        }
                    ),
                    zakres: 0...8
                )

                Button {
                    ustawPolkiCo300MM(
                        wStrefie:
                            index
                    )
                } label: {
                    Label(
                        "Półki co ok. 300 mm światła",
                        systemImage:
                            "ruler"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if zone.kind == .hanging {
                PoleWymiaruMM(
                    tytul: "Wysokość osi drążka od dna strefy",
                    wartosc: Binding(
                        get: {
                            (
                                modul.effectiveRailHeight(
                                    forZoneAt:
                                        index
                                )
                                ?? .zero
                            )
                            .rawValue
                        },
                        set: { value in
                            wykonajZmianeProdukcji(
                                "Zmieniono wysokość drążka"
                            ) {
                                modul.updateZone(at: index) {
                                    $0.railHeight =
                                        Millimeters(
                                            przytnij(
                                                zaokraglij10(value),
                                                60...2600
                                            )
                                        )
                                }
                            }
                        }
                    ),
                    zakres: 60...2600
                )
            }

            if zone.kind == .drawers {
                sekcjaSzuflad(index)
            }

            if index > 0 {
                Button(role: .destructive) {
                    var removed = false
                    wykonajZmianeProdukcji(
                        "Usunięto podział strefy"
                    ) {
                        removed =
                            modul.removeSplitBelow(
                                zoneIndex: index
                            )
                    }
                    if removed {
                        zaznaczonaStrefa = index - 1
                    }
                } label: {
                    Label("Usuń podział pod strefą", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func sekcjaSzuflad(_ index: Int) -> some View {
        let zone = modul.zones[index]

        VStack(alignment: .leading, spacing: 10) {
            LicznikView(
                tytul: "Szuflady (w kolumnie)",
                wartosc: Binding(
                    get: { modul.zones[index].drawerCount },
                    set: { nowe in
                        wykonajZmianeProdukcji(
                            "Zmieniono liczbę szuflad"
                        ) {
                            modul.updateZone(at: index) {
                                $0.drawerCount = nowe
                                if !$0.drawerFrontHeights.isEmpty {
                                    $0.drawerFrontHeights =
                                        dopasujWysokosciSzuflad(
                                            $0.drawerFrontHeights,
                                            doLiczby: nowe
                                        )
                                }
                            }
                        }
                    }
                ),
                // Zakres z domeny, nie wpisany liczbą — ta sama granica
                // obowiązuje `ElevationZone` przy dekodowaniu zapisanych
                // modułów, więc kontrolka nie może pozwolić na więcej,
                // niż model i tak przytnie.
                zakres: DrawerFrontStack.drawersPerZone
            )

            naglowek("Układ wysokości")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(ukladySzufladWKreatorze) { preset in
                    chip(
                        preset.etykieta,
                        aktywny:
                            aktywnyPresetSzuflad(
                                dla: zone
                            ) == preset
                    ) {
                        ustawPresetSzuflad(
                            preset,
                            wStrefie: index
                        )
                    }
                }
            }

            if !modul.zones[index].drawerFrontHeights.isEmpty {
                sekcjaTrybuUkladuV0103(index)
                edytorWysokosciSzufladWKreatorze(index)
                podgladWysokosciPoPrzeliczeniuV0103(index)
            } else if let layout = modul.drawerLayout(forZoneAt: index) {
                Text(
                    "Równy podział: front \(Int(layout.frontHeight.rawValue)) mm."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            naglowek("System szuflad")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(DrawerSystem.allCases) { system in
                    chip(system.displayName, aktywny: zone.drawerSystem == system) {
                        wykonajZmianeProdukcji(
                            "Zmieniono system szuflad na \(system.displayName)"
                        ) {
                            modul.updateZone(at: index) {
                                $0.drawerSystem = system
                                $0.drawerProfileName = system.defaultProfileName
                            }
                        }
                    }
                }
            }

            naglowek("Profil")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(zone.drawerSystem.profiles) { profil in
                    chip(
                        "\(profil.name) · \(Int(profil.profileHeight.rawValue))",
                        aktywny: zone.drawerProfileName == profil.name
                    ) {
                        wykonajZmianeProdukcji(
                            "Zmieniono profil szuflad na \(profil.name)"
                        ) {
                            modul.updateZone(at: index) {
                                $0.drawerProfileName = profil.name
                            }
                        }
                    }
                }
            }

            sekcjaProwadnicyV0103(zone)

            if let layout = modul.drawerLayout(forZoneAt: index) {
                widokWalidacji(layout, zone: zone)
            }
        }
    }

    /// Masa frontu i dobór podnośnika — dla frontów uchylnych i klapowych.
    ///
    /// `FrontHardwareCalculator` był napisany i otestowany, ale **żaden plik
    /// aplikacji go nie wołał**: liczby o masie i sile siłownika istniały
    /// wyłącznie w domenie.
    ///
    /// Pokazujemy je tam, gdzie zapada decyzja — przy wyborze sposobu
    /// otwierania. Front uchylny 900 × 400 waży inaczej z płyty wiórowej niż
    /// z MDF-u, a to realnie zmienia dobór mechanizmu.
    ///
    /// **Sam współczynnik nie wskazuje SKU.** Zakresy różnią się między
    /// producentami i seriami, więc kalkulator zwraca
    /// `requiresSKUConfirmation` i mówimy o tym wprost, zamiast podawać model,
    /// którego nie potwierdziliśmy w tabeli producenta.
    @ViewBuilder
    private func sekcjaOkuciaFrontuV0103(_ span: ElevationFrontSpan) -> some View {
        if span.opening == .liftUp || span.opening == .flapDown,
           let bounds = modul.frontSpanBounds(span) {

            let szerokosc = max(bounds.width - span.sideGap, .zero)
            let wysokosc = max(bounds.height - span.verticalGap, .zero)
            let dobor = FrontHardwareCalculator.selectLift(
                frontWidth: szerokosc,
                frontHeight: wysokosc
            )

            naglowek("Podnośnik")

            VStack(alignment: .leading, spacing: 3) {
                Label(
                    String(
                        format: "Masa frontu ≈ %.1f kg · współczynnik %.0f",
                        dobor.frontMass,
                        dobor.powerFactor
                    ),
                    systemImage: "scalemass"
                )
                .font(.callout.weight(.semibold))

                Text(
                    "Producenci dobierają siłownik po iloczynie wysokości "
                    + "frontu i masy, nie po samej masie."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(dobor.issues.enumerated()), id: \.offset) { _, uwaga in
                    Label {
                        Text(uwaga.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if dobor.requiresSKUConfirmation {
                    Text(
                        "Konkretny model potwierdź w tabeli producenta — "
                        + "zakresy różnią się między seriami."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.10))
            )
        }
    }

    /// Długość prowadnicy **związana z głębokością korpusu**.
    ///
    /// To jest ta pewność przy zamawianiu, o którą chodziło: projektant
    /// ustawia głębokość mebla i od razu widzi, jaką prowadnicę zamówić.
    /// Dotąd domena umiała to policzyć, ale liczba nie pokazywała się nigdzie —
    /// więc przy zamówieniu albo liczyło się od nowa, albo zgadywało.
    ///
    /// Reguła: prowadnica NL wymaga **głębokości wewnętrznej ≥ NL + 22 mm**
    /// (`DrawerProfile.requiredDepthMargin`). Korpus 560 mieści więc 500,
    /// nie 550. Każdy system ma własną drabinkę długości i dobieranie
    /// „najbliższej okrągłej" kończy się zamówieniem prowadnicy, której
    /// producent nie robi.
    @ViewBuilder
    private func sekcjaProwadnicyV0103(_ zone: ElevationZone) -> some View {
        let swiatlo = modul.depth - carcassThicknessV0103
        let dobrana = DrawerProfile.nominalLength(
            for: zone.drawerSystem,
            cabinetInnerDepth: swiatlo
        )

        naglowek("Prowadnica dla tej głębokości")

        if let dobrana {
            // Zmarnowana głębokość bywa całą warstwą przechowywania —
            // przy dużej wartości opłaca się zmienić głębokość korpusu
            // albo system, zanim płyta pojedzie na piłę.
            let strata = swiatlo - DrawerProfile.requiredDepthMargin - dobrana

            VStack(alignment: .leading, spacing: 3) {
                Label(
                    "\(zone.drawerSystem.displayName) NL \(Int(dobrana.rawValue)) mm",
                    systemImage: "ruler"
                )
                .font(.callout.weight(.semibold))

                Text(
                    "Korpus \(Int(modul.depth.rawValue)) mm → światło "
                    + "\(Int(swiatlo.rawValue)) mm. Prowadnica potrzebuje "
                    + "NL + \(Int(DrawerProfile.requiredDepthMargin.rawValue)) mm."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if strata >= Millimeters(50) {
                    Label(
                        "\(Int(strata.rawValue)) mm głębokości zostaje niewykorzystane",
                        systemImage: "arrow.left.and.right"
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.10))
            )
        } else {
            let najkrotsza = DrawerProfile
                .nominalLengths(for: zone.drawerSystem)
                .min()

            Label {
                Text(
                    "Korpus \(Int(modul.depth.rawValue)) mm jest za płytki dla systemu "
                    + "\(zone.drawerSystem.displayName)"
                    + (
                        najkrotsza.map {
                            " — najkrótsza prowadnica ma NL \(Int($0.rawValue)) mm, "
                            + "czyli wymaga \(Int($0.rawValue + DrawerProfile.requiredDepthMargin.rawValue)) mm światła."
                        } ?? "."
                    )
                )
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.12))
            )
        }
    }

    /// Grubość pleców odejmowana od głębokości korpusu przy doborze prowadnicy.
    ///
    /// Prowadnica nie sięga pleców — światło jest o nie krótsze.
    private var carcassThicknessV0103: Millimeters {
        ProductionRules.backPanelThickness
    }

    /// Co ma się stać z układem szuflad, gdy zmieni się wysokość mebla.
    ///
    /// To jest decyzja warsztatowa, nie techniczny szczegół. Szuflada na
    /// sztućce ma 140 mm i **ma zostać 140** po podwyższeniu korpusu — rośnie
    /// wtedy tylko ta głęboka na dole. Inaczej wygląda to przy trzech
    /// równych szufladach, gdzie chodzi o zachowanie proporcji.
    ///
    /// `DrawerLayoutMode` był w modelu i w zapisie od 2026-08-26, ale nie miał
    /// ekranu — silnik umiał trzymać wymiary, a projektant nie miał jak o to
    /// poprosić.
    @ViewBuilder
    private func sekcjaTrybuUkladuV0103(_ index: Int) -> some View {
        let zone = modul.zones[index]

        naglowek("Przy zmianie wysokości mebla")

        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(DrawerLayoutMode.allCases) { tryb in
                chip(tryb.displayName, aktywny: zone.drawerLayoutMode == tryb) {
                    wykonajZmianeProdukcji(
                        "Zmieniono zachowanie układu na „\(tryb.displayName)”"
                    ) {
                        modul.updateZone(at: index) {
                            $0.drawerLayoutMode = tryb
                        }
                    }
                }
            }
        }

        Text(zone.drawerLayoutMode.opis)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        // Wybór szuflady wchłaniającej różnicę ma sens tylko wtedy, gdy
        // pozostałe mają trzymać wymiar — i tylko wtedy, gdy jest ich więcej
        // niż jedna. Przy jednej „elastyczna" nie znaczy nic.
        if zone.drawerLayoutMode == .keepSizes, zone.drawerCount > 1 {
            naglowek("Różnicę wchłania")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(0..<zone.drawerCount, id: \.self) { i in
                    chip(
                        "Szuflada \(i + 1)",
                        aktywny: zone.flexibleDrawerIndex == i
                    ) {
                        wykonajZmianeProdukcji(
                            "Różnicę wchłania szuflada \(i + 1)"
                        ) {
                            modul.updateZone(at: index) {
                                $0.flexibleDrawerIndex = i
                            }
                        }
                    }
                }
            }
        }
    }

    /// Wysokości, które **naprawdę wyjdą** po przeliczeniu.
    ///
    /// Pola wyżej są wejściem — w trybie proporcjonalnym są stosunkami, a nie
    /// milimetrami. Bez tego wiersza projektant wpisuje 140/140/280 i nie wie,
    /// że dostanie 176/176/354. Suma jest dopisana, bo to ona jest regułą:
    /// fronty muszą domknąć strefę co do milimetra.
    @ViewBuilder
    private func podgladWysokosciPoPrzeliczeniuV0103(_ index: Int) -> some View {
        let wysokosci = modul.drawerFrontHeights(forZoneAt: index)

        if !wysokosci.isEmpty {
            let opis = wysokosci
                .map { "\(Int($0.rawValue.rounded()))" }
                .joined(separator: " · ")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Fronty po przeliczeniu: \(opis) mm")
                    .font(.caption.monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }

    private var ukladySzufladWKreatorze:
        [RodzajPresetuUkladuSzuflad]
    {
        [
            .rowne,
            .jednaWysokaDwieNiskie,
            .wysokaNaDoleDwieNiskie,
            .dwieWysokie,
            .wysokosciNiestandardowe
        ]
    }

    private func aktywnyPresetSzuflad(
        dla zone: ElevationZone
    ) -> RodzajPresetuUkladuSzuflad {
        let heights = zone.drawerFrontHeights.map {
            Int($0.rawValue.rounded())
        }

        guard !heights.isEmpty else {
            return .rowne
        }

        switch heights {
        case [140, 140, 280]:
            return .jednaWysokaDwieNiskie
        case [280, 140, 140]:
            return .wysokaNaDoleDwieNiskie
        case [280, 280]:
            return .dwieWysokie
        default:
            return .wysokosciNiestandardowe
        }
    }

    private func ustawPresetSzuflad(
        _ preset: RodzajPresetuUkladuSzuflad,
        wStrefie index: Int
    ) {
        guard modul.zones.indices.contains(index) else {
            return
        }

        let niska = Millimeters(
            StandardWysokoscSzuflady
                .niska
                .wysokoscFrontuMM
        )
        let wysoka = Millimeters(
            StandardWysokoscSzuflady
                .wysoka
                .wysokoscFrontuMM
        )
        let aktualneWysokosci =
            modul.drawerFrontHeights(
                forZoneAt: index
            )

        wykonajZmianeProdukcji(
            "Zmieniono układ szuflad"
        ) {
            modul.updateZone(at: index) { zone in
                switch preset {
                case .rowne:
                    zone.drawerFrontHeights = []
                case .jednaWysokaDwieNiskie:
                    zone.drawerCount = 3
                    zone.drawerFrontHeights = [
                        niska,
                        niska,
                        wysoka
                    ]
                case .wysokaNaDoleDwieNiskie:
                    zone.drawerCount = 3
                    zone.drawerFrontHeights = [
                        wysoka,
                        niska,
                        niska
                    ]
                case .dwieWysokie:
                    zone.drawerCount = 2
                    zone.drawerFrontHeights = [
                        wysoka,
                        wysoka
                    ]
                case .wysokosciNiestandardowe:
                    if zone.drawerFrontHeights.isEmpty {
                        zone.drawerFrontHeights =
                            dopasujWysokosciSzuflad(
                                aktualneWysokosci,
                                doLiczby: zone.drawerCount
                            )
                    }
                case .cargo:
                    zone.drawerCount = 1
                    zone.drawerFrontHeights = []
                }
            }
        }
    }

    private func edytorWysokosciSzufladWKreatorze(
        _ index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(
                Array(
                    modul.zones[index]
                        .drawerFrontHeights
                        .indices
                ),
                id: \.self
            ) { drawerIndex in
                HStack(spacing: 8) {
                    Picker(
                        "Szuflada \(drawerIndex + 1)",
                        selection: Binding(
                            get: {
                                najblizszyStandardSzuflady(
                                    modul.zones[index]
                                        .drawerFrontHeights[
                                            drawerIndex
                                        ]
                                        .rawValue
                                )
                            },
                            set: { standard in
                                ustawWysokoscSzuflady(
                                    standard.wysokoscFrontuMM,
                                    indeksSzuflady: drawerIndex,
                                    indeksStrefy: index
                                )
                            }
                        )
                    ) {
                        ForEach(
                            StandardWysokoscSzuflady.allCases
                        ) { standard in
                            Text(standard.opis)
                                .tag(standard)
                        }
                    }
                    .pickerStyle(.menu)

                    PoleWymiaruMM(
                        tytul:
                            "mm",
                        wartosc: Binding(
                            get: {
                                modul.zones[index]
                                    .drawerFrontHeights[
                                        drawerIndex
                                    ]
                                    .rawValue
                            },
                            set: { value in
                                ustawWysokoscSzuflady(
                                    value,
                                    indeksSzuflady: drawerIndex,
                                    indeksStrefy: index
                                )
                            }
                        ),
                        zakres: 60...600
                    )
                }
            }

            HStack {
                Button {
                    wykonajZmianeProdukcji(
                        "Dodano szufladę"
                    ) {
                        modul.updateZone(at: index) {
                            $0.drawerFrontHeights =
                                dopasujWysokosciSzuflad(
                                    $0.drawerFrontHeights + [140],
                                    doLiczby:
                                        min(
                                            $0.drawerCount + 1,
                                            6
                                        )
                                    )
                            $0.drawerCount =
                                min($0.drawerCount + 1, 6)
                        }
                    }
                } label: {
                    Label(
                        "Dodaj szufladę",
                        systemImage: "plus.circle"
                    )
                }
                .disabled(
                    modul.zones[index].drawerCount >= 6
                )

                Spacer()

                Button {
                    wykonajZmianeProdukcji(
                        "Wyrównano fronty szuflad"
                    ) {
                        modul.updateZone(at: index) {
                            $0.drawerFrontHeights = []
                        }
                    }
                } label: {
                    Label(
                        "Równe fronty",
                        systemImage: "equal"
                    )
                }
            }
            .font(.caption)

            Text(
                "Wysokości są liczone od dołu do góry i trafiają do rysunku, formatek oraz zapisu modułu."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func ustawWysokoscSzuflady(
        _ value: Double,
        indeksSzuflady: Int,
        indeksStrefy: Int
    ) {
        wykonajZmianeProdukcji(
            "Zmieniono wysokość frontu szuflady"
        ) {
            modul.updateZone(at: indeksStrefy) { zone in
                guard zone.drawerFrontHeights.indices
                    .contains(indeksSzuflady) else {
                    return
                }

                zone.drawerFrontHeights[indeksSzuflady] =
                    Millimeters(
                        przytnij(
                            zaokraglij10(value),
                            60...600
                        )
                    )
            }
        }
    }

    private func dopasujWysokosciSzuflad(
        _ heights: [Millimeters],
        doLiczby count: Int
    ) -> [Millimeters] {
        let safeCount = min(max(count, 1), 6)
        var result = Array(heights.prefix(safeCount))

        while result.count < safeCount {
            result.append(
                result.last
                ?? Millimeters(
                    StandardWysokoscSzuflady
                        .srednia
                        .wysokoscFrontuMM
                )
            )
        }

        return result
    }

    private func najblizszyStandardSzuflady(
        _ height: Double
    ) -> StandardWysokoscSzuflady {
        StandardWysokoscSzuflady
            .allCases
            .min {
                abs(
                    $0.wysokoscFrontuMM
                    - height
                )
                < abs(
                    $1.wysokoscFrontuMM
                    - height
                )
            }
        ?? .srednia
    }

    @ViewBuilder
    private func widokWalidacji(_ layout: DrawerLayout, zone: ElevationZone) -> some View {
        let kolor: Color = layout.isValid ? .green : .red
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: layout.isValid
                ? "checkmark.circle.fill"
                : "exclamationmark.triangle.fill")
            Text(layout.isValid
                ? "Front \(Int(layout.frontHeight.rawValue)) mm — mieści profil \(zone.drawerProfileName) (min. \(Int(layout.minimumOpening.rawValue)) mm)."
                : "Front \(Int(layout.frontHeight.rawValue)) mm < min. \(Int(layout.minimumOpening.rawValue)) mm dla \(zone.drawerProfileName). Maks. \(layout.maximumCount) szt. w tej strefie — zmniejsz liczbę, wybierz niższy profil albo powiększ strefę.")
        }
        .font(.caption)
        .foregroundStyle(kolor)
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(kolor.opacity(0.1)))

        Text("Skrzynka wewnętrzna ≈ \(Int(layout.boxWidth.rawValue)) mm")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var sekcjaPodsumowania: some View {
        VStack(alignment: .leading, spacing: 6) {
            naglowek("Podsumowanie")
            wierszPodsumowania("Strefy", "\(modul.zones.count)")
            wierszPodsumowania("Komory", "\(modul.cells.count)")
            wierszPodsumowania("Fronty warstwowe", "\(modul.frontSpans.count)")
            wierszPodsumowania("Fronty", "\(liczbaFrontow)")
            wierszPodsumowania("Półki", "\(liczbaPolek)")
            wierszPodsumowania("Drążki", "\(liczbaDrazkow)")
            wierszPodsumowania("Przegrody", "\(liczbaPrzegrod)")
            wierszPodsumowania("Formatki", "\(modul.totalCutPieces) szt.")
        }
    }

    /// Zastrzeżenia produkcyjne z `AssemblyInspector`.
    ///
    /// Kolor nie niesie tu znaczenia sam — każdy wiersz ma ikonę i słowo,
    /// zgodnie z regułą UX projektu, że kolor nie może być jedynym nośnikiem.
    @ViewBuilder
    private func sekcjaZastrzezen(
        _ zastrzezenia: [ProductionIssue]
    ) -> some View {
        let bledy = zastrzezenia.filter { $0.severity == .error }
        let ostrzezenia = zastrzezenia.filter { $0.severity == .warning }

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(
                    systemName: bledy.isEmpty
                        ? "exclamationmark.triangle"
                        : "xmark.octagon.fill"
                )
                Text(
                    bledy.isEmpty
                        ? "Do sprawdzenia"
                        : "Tego nie da się zbudować"
                )
                .font(.caption.weight(.semibold))
            }
            .foregroundStyle(bledy.isEmpty ? Color.orange : Color.red)

            ForEach(
                Array((bledy + ostrzezenia).prefix(4).enumerated()),
                id: \.offset
            ) { _, uwaga in
                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        uwaga.componentCode.map { "\($0): \(uwaga.message)" }
                            ?? uwaga.message
                    )
                    .font(.caption2)
                    if !uwaga.hint.isEmpty {
                        Text(uwaga.hint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if zastrzezenia.count > 4 {
                Text("…i jeszcze \(zastrzezenia.count - 4)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let plan = propozycjaPodzialu {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.split.2x1")
                        Text("Proponowany podział")
                            .font(.caption.weight(.semibold))
                    }
                    Text(plan.reason)
                        .font(.caption2)
                    Text(opisPodzialkiPlanu(plan))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    (bledy.isEmpty ? Color.orange : Color.red)
                        .opacity(0.12)
                )
        )
    }

    private var sekcjaKonsekwencjiZmiany: some View {
        let snapshot =
            modul.productionSnapshot()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                naglowek("Konsekwencje zmiany")
                Spacer()
                Text("live")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let ostatniaZmianaProdukcji {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ostatniaZmianaProdukcji.opis)
                        .font(.caption.weight(.semibold))

                    if !ostatniaZmianaProdukcji.zastrzezenia.isEmpty {
                        sekcjaZastrzezen(
                            ostatniaZmianaProdukcji.zastrzezenia
                        )
                    }

                    if ostatniaZmianaProdukcji.delta.hasChanges {
                        wierszDelta(
                            "Formatki",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .cutPieceCount,
                            suffix: " szt."
                        )
                        wierszDelta(
                            "Fronty",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .frontPieceCount,
                            suffix: " szt."
                        )
                        wierszDelta(
                            "Półki",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .shelfCount,
                            suffix: " szt."
                        )
                        wierszDelta(
                            "Szuflady",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .drawerBoxCount,
                            suffix: " dna"
                        )
                        wierszDelta(
                            "Okucia",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .hardwareItemCount,
                            suffix: " szt."
                        )
                        wierszDelta(
                            "Zawiasy",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .hingeCount,
                            suffix: " szt."
                        )
                        wierszDelta(
                            "Prowadnice",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .drawerRunnerPairCount,
                            suffix: " par"
                        )
                        wierszDeltaM2(
                            "Płyta",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .boardAreaM2
                        )
                        wierszDeltaM2(
                            "Fronty m²",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .frontAreaM2
                        )
                        wierszDeltaM(
                            "Okleina est.",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .estimatedBandingM
                        )
                        wierszDeltaCurrency(
                            "Okucia est.",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .estimatedHardwareCostNetto
                        )
                        wierszDeltaCurrency(
                            "Koszt bazowy est.",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .estimatedBaseCostNetto
                        )
                        wierszDeltaCurrency(
                            "Cena netto est.",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .estimatedRetailPriceNetto
                        )
                        wierszDeltaCurrency(
                            "Marża est.",
                            delta:
                                ostatniaZmianaProdukcji
                                    .delta
                                    .estimatedMarginNetto
                        )
                    } else {
                        Text("Bez zmiany w formatkach, frontach, okuciach ani estymacji okleiny.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.09))
                )
            } else {
                Text("Zmień wymiar, typ komory, front albo podział, żeby zobaczyć wpływ na produkcję.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Kwoty są roboczą estymacją na stałych założeniach, dopóki projekt nie ma pełnych cenników.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            wierszPodsumowania(
                "Aktualnie",
                "\(snapshot.cutPieceCount) formatek"
            )
            wierszPodsumowania(
                "Powierzchnia",
                "\(formatM2(snapshot.totalAreaM2)) m²"
            )
            wierszPodsumowania(
                "Okleina est.",
                "\(formatM(snapshot.estimatedBandingM)) mb"
            )
            wierszPodsumowania(
                "Okucia",
                "\(snapshot.hardwareItemCount) szt."
            )
            wierszPodsumowania(
                "Okucia est.",
                formatCurrency(snapshot.estimatedHardwareCostNetto)
            )
            wierszPodsumowania(
                "Koszt bazowy est.",
                formatCurrency(snapshot.estimatedBaseCostNetto)
            )
            wierszPodsumowania(
                "Cena netto est.",
                formatCurrency(snapshot.estimatedRetailPriceNetto)
            )
            wierszPodsumowania(
                "Marża est.",
                formatCurrency(snapshot.estimatedMarginNetto)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func wierszPodsumowania(_ tytul: String, _ wartosc: String) -> some View {
        HStack {
            Text(tytul).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(wartosc).font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    private func wierszDelta(
        _ tytul: String,
        delta: Int,
        suffix: String
    ) -> some View {
        HStack {
            Text(tytul)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatDelta(delta) + suffix)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(kolorDelty(delta))
        }
    }

    private func wierszDeltaM2(
        _ tytul: String,
        delta: Double
    ) -> some View {
        HStack {
            Text(tytul)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatDeltaM2(delta) + " m²")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(kolorDelty(delta))
        }
    }

    private func wierszDeltaM(
        _ tytul: String,
        delta: Double
    ) -> some View {
        HStack {
            Text(tytul)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatDeltaM(delta) + " mb")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(kolorDelty(delta))
        }
    }

    private func wierszDeltaCurrency(
        _ tytul: String,
        delta: Double
    ) -> some View {
        HStack {
            Text(tytul)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatDeltaCurrency(delta))
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(kolorDelty(delta))
        }
    }

    private func formatDelta(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func formatDeltaM2(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + formatM2(value)
    }

    private func formatDeltaM(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + formatM(value)
    }

    private func formatDeltaCurrency(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + formatCurrency(value)
    }

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(
            .currency(code: "PLN")
                .precision(.fractionLength(0))
        )
    }

    private func formatM2(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(2))
        )
    }

    private func formatM(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(1))
        )
    }

    private func kolorDelty(_ value: Int) -> Color {
        if value == 0 {
            return .secondary
        }
        return value > 0 ? .orange : .green
    }

    private func kolorDelty(_ value: Double) -> Color {
        if abs(value) < 0.0001 {
            return .secondary
        }
        return value > 0 ? .orange : .green
    }

    // MARK: - Karta techniczna (inline, bez drugiego sheeta)

    private var kartaTechniczna: some View {
        DisclosureGroup(isExpanded: $kartaRozwinieta) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(modul.cutList()) { pozycja in
                        HStack(spacing: 10) {
                            Text(pozycja.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(pozycja.length.rawValue)) × \(Int(pozycja.width.rawValue))")
                                .font(.caption.monospacedDigit())
                            Text("×\(pozycja.count)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 34, alignment: .trailing)
                            Text(pozycja.material.displayName)
                                .foregroundStyle(.secondary)
                                .frame(width: 92, alignment: .leading)
                        }
                        .font(.caption)
                        .padding(.vertical, 5)
                        .overlay(Divider(), alignment: .bottom)
                    }
                }
            }
            .frame(maxHeight: 230)
        } label: {
            HStack {
                Label("Karta techniczna — formatki", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(modul.totalCutPieces) szt.")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 760)
        .stolarniaMaterial(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .stroke(
                StolarniaPalette.frostStroke,
                lineWidth: 1
            )
        }
    }

    // MARK: - Pasek statusu

    private var pasekStatusu: some View {
        HStack(spacing: 14) {
            Text("\(Int(modul.width.rawValue)) × \(Int(modul.height.rawValue)) × \(Int(modul.depth.rawValue)) mm")
                .font(.caption.monospacedDigit())
            Text("płyta \(Int(modul.carcassThickness.rawValue)) mm · plecy HDF 3 mm")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if modul.invalidDrawerZoneCount > 0 {
                Label(
                    "\(modul.invalidDrawerZoneCount) strefa/-y nie mieści szuflad",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            } else {
                Label("Wymiary OK", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 760)
        .stolarniaMaterial(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .stroke(
                StolarniaPalette.frostStroke,
                lineWidth: 1
            )
        }
    }

    // MARK: - Drobne pomocnicze

    private func naglowek(_ tytul: String) -> some View {
        Text(tytul)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func chip(
        _ tytul: String,
        aktywny: Bool,
        akcja: @escaping () -> Void
    ) -> some View {
        Button(action: akcja) {
            Text(tytul)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 12)
                // Cel dotyku, nie sam tekst.
                //
                // Było `.padding(.vertical, 6)`, czyli ok. 28 pt wysokości —
                // połowa minimum Apple (44 pt) i grubo poniżej progu komfortu
                // dla odbiorcy 50+. Te kafle to nie ozdoba: wybiera się nimi
                // system szuflad, profil i zachowanie układu przy zmianie
                // gabarytu. Siatki są `adaptive`, więc wyższy kafel dokłada
                // tylko wysokości i nie rozsadza układu w poziomie.
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(aktywny
                        ? Color.accentColor.opacity(0.9)
                        : Color(.tertiarySystemFill))
                )
                .foregroundStyle(aktywny ? Color.white : Color.primary)
        }
        // Tymi kaflami wybiera się system szuflad, profil prowadnicy
        // i zachowanie układu — muszą potwierdzać dotyk.
        .stolarniaPressable()
    }

    private var zaznaczonaKomora: ElevationModule.Cell? {
        guard let zaznaczonaKomoraID else { return nil }
        return modul.cells.first { $0.id == zaznaczonaKomoraID }
    }

    private var zaznaczonyFront: ElevationFrontSpan? {
        guard let zaznaczonyFrontID else { return nil }
        return modul.frontSpans.first { $0.id == zaznaczonyFrontID }
    }

    private func komora(
        wPunkcieMMX mmX: Double,
        mmY: Double
    ) -> ElevationModule.Cell? {
        modul.cells.first {
            mmX >= $0.left.rawValue
            && mmX <= $0.right.rawValue
            && mmY >= $0.lower.rawValue
            && mmY <= $0.upper.rawValue
        }
    }

    private func front(
        wPunkcieMMX mmX: Double,
        mmY: Double
    ) -> ElevationFrontSpan? {
        modul.frontSpans.reversed().first { span in
            guard let bounds = modul.frontSpanBounds(span) else {
                return false
            }
            return mmX >= bounds.left.rawValue
                && mmX <= bounds.right.rawValue
                && mmY >= bounds.lower.rawValue
                && mmY <= bounds.upper.rawValue
        }
    }

    private func moznaPodzielicPionowo(
        _ cell: ElevationModule.Cell
    ) -> Bool {
        guard modul.zones.indices.contains(cell.zoneIndex) else {
            return false
        }
        let zone = modul.zones[cell.zoneIndex]
        return zone.kind != .appliance
            && zone.columns < 4
            && cell.width.rawValue >= 240
    }

    private func moznaPodzielicPoziomo(
        _ cell: ElevationModule.Cell
    ) -> Bool {
        cell.height >= ElevationModule.minimumZoneHeight * 2
    }

    private func wykonajZmianeProdukcji(
        _ opis: String,
        _ zmiana: () -> Void
    ) {
        let przed =
            modul.productionSnapshot()
        zmiana()
        let po =
            modul.productionSnapshot()
        ostatniaZmianaProdukcji =
            OstatniaZmianaProdukcji(
                opis: opis,
                snapshot: po,
                delta: ElevationProductionDelta(
                    before: przed,
                    after: po
                ),
                zastrzezenia: skontrolujWykonalnosc()
            )
    }

    /// Buduje zespół z bieżącego modułu i przepuszcza go przez kontrolę
    /// produkcyjną. Błąd budowy zespołu nie jest zastrzeżeniem produkcyjnym —
    /// przy niedokończonym podziale `makeAssembly` rzuca i to jest normalne
    /// w trakcie rysowania, więc zwracamy pustą listę zamiast straszyć.
    /// Propozycja rozbicia modułu na korpusy, gdy jest za szeroki na jeden.
    ///
    /// Kontrola mówi „nie mieści się w arkuszu”, ale sama informacja o problemie
    /// nie mówi projektantowi, co ma zrobić. Planer podaje konkretne podziałki.
    /// Świadomie **nie przepisuje** modułu za użytkownika: podział ciągu na
    /// korpusy to decyzja projektowa (gdzie wypadną boki, gdzie fugi), a nie
    /// operacja, którą wolno zrobić w tle.
    private var propozycjaPodzialu: RunSplitPlanner.Plan? {
        guard RunSplitPlanner.needsSplit(runWidth: modul.width) else { return nil }
        let plan = RunSplitPlanner.plan(runWidth: modul.width)
        return plan.count > 1 ? plan : nil
    }

    private func opisPodzialkiPlanu(_ plan: RunSplitPlanner.Plan) -> String {
        plan.widths
            .map { String(format: "%.0f", $0.rawValue) }
            .joined(separator: " + ") + " mm"
    }

    private func skontrolujWykonalnosc() -> [ProductionIssue] {
        guard let zespol = try? modul.makeAssembly(named: modul.name) else {
            return []
        }
        return AssemblyInspector.inspect(zespol)
    }

    private func podzielKomorePionowo(
        _ cell: ElevationModule.Cell
    ) {
        guard moznaPodzielicPionowo(cell) else { return }
        wykonajZmianeProdukcji(
            "Podzielono komorę pionowo"
        ) {
            modul.updateZone(at: cell.zoneIndex) {
                $0.columns += 1
            }
        }
        wybierzKomore(
            zoneIndex: cell.zoneIndex,
            columnIndex: min(
                cell.columnIndex,
                max(modul.zones[cell.zoneIndex].columns - 1, 0)
            )
        )
    }

    private func podzielKomorePoziomo(
        _ cell: ElevationModule.Cell
    ) {
        guard moznaPodzielicPoziomo(cell) else { return }
        let y =
            cell.lower
            + cell.height / 2
        var newZoneIndex: Int?
        wykonajZmianeProdukcji(
            "Podzielono komorę poziomo"
        ) {
            newZoneIndex =
                modul.splitZone(at: y)
        }
        if let newZoneIndex {
            wybierzKomore(
                zoneIndex: newZoneIndex,
                columnIndex: min(cell.columnIndex, 3)
            )
        }
    }

    private func ustawTypKomory(
        _ kind: ElevationZoneKind,
        dla cell: ElevationModule.Cell
    ) {
        guard modul.zones.indices.contains(cell.zoneIndex) else { return }
        wykonajZmianeProdukcji(
            "Zmieniono typ komory na \(kind.displayName)"
        ) {
            modul.updateZone(at: cell.zoneIndex) { zone in
                zone.kind = kind
                switch kind {
                case .drawers:
                    zone.drawerCount = max(zone.drawerCount, 3)
                    if zone.drawerFrontHeights.count != zone.drawerCount {
                        zone.drawerFrontHeights = []
                    }
                case .shelves:
                    zone.shelfCount = max(zone.shelfCount, 2)
                case .hanging:
                    zone.railHeight = .zero
                    zone.shelfCount = 0
                case .doors:
                    break
                case .appliance:
                    zone.columns = 1
                }
            }
        }
        wybierzKomore(
            zoneIndex: cell.zoneIndex,
            columnIndex: kind == .appliance ? 0 : cell.columnIndex
        )
    }

    private func ustawWybranaLubNajwiekszaStrefe(
        jako kind:
            ElevationZoneKind
    ) {
        guard let index =
            zaznaczonaStrefa
            ?? najwiekszaStrefaIndex
        else {
            return
        }

        wykonajZmianeProdukcji(
            "Ustawiono strefę: \(kind.displayName)"
        ) {
            modul.updateZone(at: index) { zone in
                zone.kind = kind
                switch kind {
                case .hanging:
                    zone.railHeight = .zero
                    zone.shelfCount = 0
                case .shelves:
                    zone.shelfCount =
                        liczbaPolekDlaSwiatla300(
                            strefa:
                                index
                        )
                case .drawers:
                    zone.drawerCount = max(zone.drawerCount, 3)
                case .doors:
                    break
                case .appliance:
                    zone.columns = 1
                }
            }
        }

        wybierzKomore(
            zoneIndex:
                index,
            columnIndex:
                0
        )
    }

    private func ustawKolumnyWStrefie(
        _ columns:
            Int
    ) {
        guard let index =
            zaznaczonaStrefa
            ?? najwiekszaStrefaIndex,
              modul.zones.indices.contains(index),
              modul.zones[index].kind != .appliance
        else {
            return
        }

        wykonajZmianeProdukcji(
            "Zmieniono liczbę kolumn"
        ) {
            modul.updateZone(at: index) {
                $0.columns =
                    min(max(columns, 1), 4)
            }
        }

        wybierzKomore(
            zoneIndex:
                index,
            columnIndex:
                0
        )
    }

    private func ustawPolkiCo300MM(
        wStrefie index:
            Int
    ) {
        guard modul.zones.indices.contains(index) else {
            return
        }

        wykonajZmianeProdukcji(
            "Ustawiono półki co około 300 mm"
        ) {
            modul.updateZone(at: index) {
                $0.kind = .shelves
                $0.shelfCount =
                    liczbaPolekDlaSwiatla300(
                        strefa:
                            index
                    )
            }
        }
    }

    private func dodajNadstawke(
        _ height:
            Double
    ) {
        wykonajZmianeProdukcji(
            "Dodano nadstawkę"
        ) {
            modul.addTopExtension(
                height:
                    Millimeters(height),
                kind:
                    .shelves
            )
        }

        let index =
            max(modul.zones.count - 1, 0)
        wybierzKomore(
            zoneIndex:
                index,
            columnIndex:
                0
        )
    }

    private var najwiekszaStrefaIndex:
        Int?
    {
        modul.segments.max {
            $0.zoneHeight < $1.zoneHeight
        }?.index
    }

    private func liczbaPolekDlaSwiatla300(
        strefa index:
            Int
    ) -> Int {
        guard modul.segments.indices.contains(index) else {
            return 2
        }

        let height =
            modul.segments[index]
                .zoneHeight
                .rawValue
        let count =
            Int((height / 300).rounded()) - 1
        return min(
            max(count, 0),
            8
        )
    }

    private func wybierzKomore(
        zoneIndex: Int,
        columnIndex: Int
    ) {
        let id = "z\(zoneIndex)-c\(max(columnIndex, 0))"
        zaznaczonaKomoraID =
            modul.cells.contains { $0.id == id }
            ? id
            : nil
        zaznaczonaStrefa =
            modul.zones.indices.contains(zoneIndex)
            ? zoneIndex
            : nil
    }

    private func aktualizujFront(
        _ id: UUID,
        opis:
            String = "Zmieniono front",
        _ mutate: (inout ElevationFrontSpan) -> Void
    ) {
        wykonajZmianeProdukcji(
            opis
        ) {
            modul.updateFrontSpan(id: id, mutate)
        }
        if modul.frontSpans.contains(where: { $0.id == id }) {
            zaznaczonyFrontID = id
        } else {
            zaznaczonyFrontID = nil
        }
    }

    private func ustawFrontNaKomore(
        _ cell: ElevationModule.Cell
    ) {
        let span = ElevationFrontSpan(
            lowerZoneIndex: cell.zoneIndex,
            upperZoneIndex: cell.zoneIndex,
            leadingColumnIndex: cell.columnIndex,
            trailingColumnIndex: cell.columnIndex,
            opening: domyslneOtwarcieFrontu(dla: cell),
            coversInternalDrawers: cell.drawerCount > 0
        )
        wykonajZmianeProdukcji(
            "Dodano front komory"
        ) {
            modul.setFrontSpans([
                span
            ])
        }
        zaznaczonyFrontID = span.id
        zaznaczonaKomoraID = nil
        zaznaczonaStrefa = cell.zoneIndex
    }

    private func ustawFrontNaCalyModul(
        _ cell: ElevationModule.Cell
    ) {
        let span = ElevationFrontSpan(
            lowerZoneIndex: 0,
            upperZoneIndex: max(modul.zones.count - 1, 0),
            leadingColumnIndex: 0,
            trailingColumnIndex: 3,
            opening: .leftHinged,
            coversInternalDrawers:
                modul.cells.contains { $0.drawerCount > 0 }
        )
        wykonajZmianeProdukcji(
            "Dodano front modułu"
        ) {
            modul.setFrontSpans([
                span
            ])
        }
        zaznaczonyFrontID = span.id
        zaznaczonaKomoraID = nil
        zaznaczonaStrefa = cell.zoneIndex
    }

    private func ustawFrontNaZakresStrefy(
        _ span: ElevationFrontSpan
    ) {
        aktualizujFront(
            span.id,
            opis: "Rozszerzono front na całą strefę"
        ) { draft in
            draft.leadingColumnIndex = 0
            draft.trailingColumnIndex = 3
        }
    }

    private func ustawFrontNaZakresModulu(
        _ span: ElevationFrontSpan
    ) {
        aktualizujFront(
            span.id,
            opis: "Rozszerzono front na cały moduł"
        ) { draft in
            draft.lowerZoneIndex = 0
            draft.upperZoneIndex = max(modul.zones.count - 1, 0)
            draft.leadingColumnIndex = 0
            draft.trailingColumnIndex = 3
            draft.coversInternalDrawers =
                modul.cells.contains { $0.drawerCount > 0 }
        }
    }

    private func domyslneOtwarcieFrontu(
        dla cell: ElevationModule.Cell
    ) -> FurnitureFrontOpeningV020 {
        switch cell.kind {
        case .drawers:
            return .drawer
        case .appliance:
            return .fixed
        case .doors, .shelves, .hanging:
            return .leftHinged
        }
    }

    private func nazwaOtwarcia(
        _ opening: FurnitureFrontOpeningV020
    ) -> String {
        switch opening {
        case .leftHinged:
            return "Lewe"
        case .rightHinged:
            return "Prawe"
        case .liftUp:
            return "Do góry"
        case .flapDown:
            return "W dół"
        case .drawer:
            return "Szuflada"
        case .sliding:
            return "Przesuwne"
        case .fixed:
            return "Stały"
        }
    }

    private var liczbaFrontow: Int {
        if !modul.frontSpans.isEmpty {
            return modul.frontSpans.count
        }
        return modul.zones.reduce(0) { acc, zone in
            switch zone.kind {
            case .drawers: return acc + zone.drawerCount * zone.columns
            case .doors: return acc + zone.columns
            default: return acc
            }
        }
    }

    private var liczbaDrazkow: Int {
        modul.zones.reduce(0) { acc, zone in
            zone.kind == .hanging
            ? acc + zone.columns
            : acc
        }
    }

    private var liczbaPolek: Int {
        modul.zones.reduce(0) { acc, zone in
            zone.kind == .shelves ? acc + zone.shelfCount * zone.columns : acc
        }
    }

    private var liczbaPrzegrod: Int {
        modul.zones.reduce(0) { acc, zone in
            zone.kind == .appliance ? acc : acc + (zone.columns - 1)
        }
    }
}

// MARK: - Typy pomocnicze pliku

private enum NarzedzieElewacji {
    case wybierz
    case podziel
}

private enum CelGestuElewacji {
    case szerokosc
    case wysokosc
    case podzial(Int)
    case tlo
}

/// Transformacja mm ↔ piksele. Oś Y w mm rośnie od dna modułu ku górze.
private struct FitElewacji {
    let skala: CGFloat
    let ox: CGFloat
    let oy: CGFloat
    let wysokoscMM: Double

    var skalaDouble: Double { Double(skala) }

    func x(_ mm: Double) -> CGFloat { ox + CGFloat(mm) * skala }
    func y(_ mm: Double) -> CGFloat { oy + CGFloat(wysokoscMM - mm) * skala }
    func mmX(_ px: CGFloat) -> Double { Double((px - ox) / skala) }
    func mmY(_ px: CGFloat) -> Double { wysokoscMM - Double((px - oy) / skala) }

    func rect(x0: Double, y0: Double, x1: Double, y1: Double) -> CGRect {
        CGRect(
            x: x(x0),
            y: y(y1),
            width: CGFloat(max(x1 - x0, 0)) * skala,
            height: CGFloat(max(y1 - y0, 0)) * skala
        )
    }
}

private func zaokraglij10(_ wartosc: Double) -> Double {
    (wartosc / 10).rounded() * 10
}

private func przytnij(_ wartosc: Double, _ zakres: ClosedRange<Double>) -> Double {
    min(max(wartosc, zakres.lowerBound), zakres.upperBound)
}

/// Pole liczbowe zatwierdzane Enterem lub utratą fokusu — celowo NIE aktualizuje
/// modelu przy każdym znaku, żeby przerysowanie płótna nie zamykało klawiatury
/// (znany problem TextField↔redraw na iPadzie).
private struct PoleWymiaruMM: View {
    let tytul: String
    @Binding var wartosc: Double
    let zakres: ClosedRange<Double>

    @State private var tekst = ""
    @State private var maNiezatwierdzonaZmiane = false
    @FocusState private var aktywne: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tytul).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Button { zmien(o: -10) } label: {
                    Image(systemName: "minus")
                        .frame(minWidth: 30, minHeight: 30)
                }
                    .buttonStyle(.bordered)
                TextField("mm", text: $tekst)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .focused($aktywne)
                    .onSubmit(zatwierdz)
                    .frame(minWidth: 60)
                    .onChange(of: tekst) { _, _ in
                        maNiezatwierdzonaZmiane = true
                    }
                    .toolbar {
                        ToolbarItemGroup(
                            placement:
                                .keyboard
                        ) {
                            Spacer()
                            Button("OK") {
                                zatwierdz()
                                aktywne = false
                            }
                        }
                    }
                Button {
                    zatwierdz()
                } label: {
                    Image(
                        systemName:
                            maNiezatwierdzonaZmiane
                            ? "checkmark.circle.fill"
                            : "checkmark.circle"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(!maNiezatwierdzonaZmiane)
                Button { zmien(o: 10) } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 30, minHeight: 30)
                }
                    .buttonStyle(.bordered)
                Text("mm").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onAppear { tekst = etykieta(wartosc) }
        .onChange(of: wartosc) { _, nowa in
            if !aktywne
                && !maNiezatwierdzonaZmiane {
                tekst = etykieta(nowa)
            }
        }
    }

    private func etykieta(_ v: Double) -> String { String(Int(v.rounded())) }

    private func zatwierdz() {
        let znormalizowany = tekst.replacingOccurrences(of: ",", with: ".")
        guard let liczba = Double(znormalizowany) else {
            tekst = etykieta(wartosc)
            return
        }
        let przycieta = min(max(liczba, zakres.lowerBound), zakres.upperBound)
        wartosc = przycieta
        tekst = etykieta(przycieta)
        maNiezatwierdzonaZmiane = false
    }

    private func zmien(o delta: Double) {
        let nowa = min(max(wartosc + delta, zakres.lowerBound), zakres.upperBound)
        wartosc = nowa
        tekst = etykieta(nowa)
        maNiezatwierdzonaZmiane = false
    }
}

private struct LicznikView: View {
    let tytul: String
    @Binding var wartosc: Int
    let zakres: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tytul).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    if wartosc > zakres.lowerBound { wartosc -= 1 }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)

                Text("\(wartosc)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 30)

                Button {
                    if wartosc < zakres.upperBound { wartosc += 1 }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview("Kreator rysunkowy") {
    ModulEdytorElewacjiView()
}
