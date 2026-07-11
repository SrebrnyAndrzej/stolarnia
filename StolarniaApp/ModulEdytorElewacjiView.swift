import DomainCore
import SwiftUI

/// Kreator rysunkowy modułu (beta): jedna powierzchnia do tworzenia i edycji.
/// Elewacja mebla rysowana na płótnie — przeciąganie krawędzi zmienia gabaryt,
/// narzędzie „Podziel" tnie moduł na strefy, dotknięcie strefy otwiera jej
/// konfigurację w inspektorze. Karta techniczna (formatki) przelicza się na żywo.
struct ModulEdytorElewacjiView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var modul: ElevationModule
    @State private var zaznaczonaStrefa: Int?
    @State private var narzedzie: NarzedzieElewacji = .wybierz
    @State private var kartaRozwinieta = false
    @State private var celGestu: CelGestuElewacji?
    @State private var fitStartuGestu: FitElewacji?
    @State private var zapisywanie = false

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
                        drawerProfileName: "H116"
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
                    plotno
                    Divider()
                    inspektor
                        .frame(width: 312)
                }
                Divider()
                kartaTechniczna
                Divider()
                pasekStatusu
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
                    &context, zone: zone, fit: fit,
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

            case .appliance:
                break
            }
        }
    }

    private func rysujSzuflady(
        _ context: inout GraphicsContext,
        zone: ElevationZone,
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
        let fh = layout.frontHeight.rawValue

        for i in 0..<zone.drawerCount {
            let fy0 = y0 + mb + (fh + gap) * Double(i)
            let front = fit.rect(x0: x0 + 2, y0: fy0, x1: x1 - 2, y1: fy0 + fh)
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
                    modul.width = Millimeters(mm)
                case .wysokosc:
                    let mm = przytnij(zaokraglij10(f.mmY(gest.location.y)), 300...2600)
                    modul.setHeightClamped(Millimeters(mm))
                case .podzial(let index):
                    let mm = zaokraglij10(f.mmY(gest.location.y))
                    modul.moveSplit(at: index, to: Millimeters(mm))
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
            if let nowyIndeks = modul.splitZone(at: Millimeters(zaokraglij10(mmY))) {
                zaznaczonaStrefa = nowyIndeks
                narzedzie = .wybierz
            }
            return
        }

        guard mmX >= -20, mmX <= modul.width.rawValue + 20 else {
            zaznaczonaStrefa = nil
            return
        }
        if let segment = modul.segments.first(where: {
            mmY >= $0.lower.rawValue && mmY <= $0.upper.rawValue
        }) {
            zaznaczonaStrefa = zaznaczonaStrefa == segment.index ? nil : segment.index
        } else {
            zaznaczonaStrefa = nil
        }
    }

    // MARK: - Inspektor

    private var inspektor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sekcjaNarzedzia
                sekcjaGabarytu
                if let index = zaznaczonaStrefa, modul.zones.indices.contains(index) {
                    sekcjaStrefy(index)
                } else {
                    Text("Dotknij strefy na rysunku, aby ją skonfigurować.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                sekcjaPodsumowania
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
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
                if wartosc == .podziel { zaznaczonaStrefa = nil }
            } label: {
                Label(tytul, systemImage: ikona).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var sekcjaGabarytu: some View {
        VStack(alignment: .leading, spacing: 10) {
            naglowek("Gabaryt korpusu")
            PoleWymiaruMM(
                tytul: "Szerokość",
                wartosc: Binding(
                    get: { modul.width.rawValue },
                    set: { modul.width = Millimeters(przytnij(zaokraglij10($0), 200...1500)) }
                ),
                zakres: 200...1500
            )
            PoleWymiaruMM(
                tytul: "Wysokość",
                wartosc: Binding(
                    get: { modul.height.rawValue },
                    set: { modul.setHeightClamped(Millimeters(przytnij(zaokraglij10($0), 300...2600))) }
                ),
                zakres: 300...2600
            )
            PoleWymiaruMM(
                tytul: "Głębokość",
                wartosc: Binding(
                    get: { modul.depth.rawValue },
                    set: { modul.depth = Millimeters(przytnij(zaokraglij10($0), 200...900)) }
                ),
                zakres: 200...900
            )
        }
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
                        modul.updateZone(at: index) { $0.kind = kind }
                    }
                }
            }

            PoleWymiaruMM(
                tytul: "Wysokość strefy",
                wartosc: Binding(
                    get: { segment.zoneHeight.rawValue },
                    set: { modul.setZoneHeight(Millimeters(zaokraglij10($0)), forZoneAt: index) }
                ),
                zakres: 100...2600
            )

            if zone.kind != .appliance {
                LicznikView(
                    tytul: "Przegrody pionowe",
                    wartosc: Binding(
                        get: { modul.zones[index].columns - 1 },
                        set: { nowe in modul.updateZone(at: index) { $0.columns = nowe + 1 } }
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
                        set: { nowe in modul.updateZone(at: index) { $0.shelfCount = nowe } }
                    ),
                    zakres: 0...8
                )
            }

            if zone.kind == .drawers {
                sekcjaSzuflad(index)
            }

            if index > 0 {
                Button(role: .destructive) {
                    if modul.removeSplitBelow(zoneIndex: index) {
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
                    set: { nowe in modul.updateZone(at: index) { $0.drawerCount = nowe } }
                ),
                zakres: 1...6
            )

            naglowek("System szuflad")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(DrawerSystem.allCases) { system in
                    chip(system.displayName, aktywny: zone.drawerSystem == system) {
                        modul.updateZone(at: index) {
                            $0.drawerSystem = system
                            $0.drawerProfileName = system.defaultProfileName
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
                        modul.updateZone(at: index) { $0.drawerProfileName = profil.name }
                    }
                }
            }

            if let layout = modul.drawerLayout(forZoneAt: index) {
                widokWalidacji(layout, zone: zone)
            }
        }
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
            wierszPodsumowania("Fronty", "\(liczbaFrontow)")
            wierszPodsumowania("Półki", "\(liczbaPolek)")
            wierszPodsumowania("Przegrody", "\(liczbaPrzegrod)")
            wierszPodsumowania("Formatki", "\(modul.totalCutPieces) szt.")
        }
    }

    private func wierszPodsumowania(_ tytul: String, _ wartosc: String) -> some View {
        HStack {
            Text(tytul).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(wartosc).font(.caption.monospacedDigit().weight(.semibold))
        }
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
        .background(Color(.secondarySystemGroupedBackground))
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(aktywny
                        ? Color.accentColor.opacity(0.9)
                        : Color(.tertiarySystemFill))
                )
                .foregroundStyle(aktywny ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var liczbaFrontow: Int {
        modul.zones.reduce(0) { acc, zone in
            switch zone.kind {
            case .drawers: return acc + zone.drawerCount * zone.columns
            case .doors: return acc + zone.columns
            default: return acc
            }
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
    @FocusState private var aktywne: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tytul).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Button { zmien(o: -10) } label: { Image(systemName: "minus") }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                TextField("mm", text: $tekst)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .focused($aktywne)
                    .onSubmit(zatwierdz)
                    .frame(minWidth: 60)
                Button { zmien(o: 10) } label: { Image(systemName: "plus") }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Text("mm").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onAppear { tekst = etykieta(wartosc) }
        .onChange(of: wartosc) { _, nowa in
            if !aktywne { tekst = etykieta(nowa) }
        }
        .onChange(of: aktywne) { _, jestAktywne in
            if !jestAktywne { zatwierdz() }
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
    }

    private func zmien(o delta: Double) {
        let nowa = min(max(wartosc + delta, zakres.lowerBound), zakres.upperBound)
        wartosc = nowa
        tekst = etykieta(nowa)
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
                .controlSize(.small)

                Text("\(wartosc)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 30)

                Button {
                    if wartosc < zakres.upperBound { wartosc += 1 }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

#Preview("Kreator rysunkowy") {
    ModulEdytorElewacjiView()
}
