import SwiftUI

// MARK: - Models

struct PunktKonturu: Identifiable, Equatable {
    let id = UUID()
    var x: Double  // mm
    var y: Double  // mm
}

struct OdcinekKonturu: Identifiable {
    let id = UUID()
    let start: PunktKonturu
    let end: PunktKonturu

    var dlugoscMM: Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }

    var katStopnie: Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return atan2(dy, dx) * 180 / .pi
    }

    var srodek: PunktKonturu {
        PunktKonturu(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }
}

struct KsztaltMeblaV080: Equatable {
    var punkty: [PunktKonturu] = []
    var zamkniety: Bool = false

    var odcinki: [OdcinekKonturu] {
        guard punkty.count >= 2 else { return [] }
        var result: [OdcinekKonturu] = []
        for i in 0..<(zamkniety ? punkty.count : punkty.count - 1) {
            result.append(OdcinekKonturu(
                start: punkty[i],
                end: punkty[(i + 1) % punkty.count]
            ))
        }
        return result
    }

    var powierzchniaM2: Double {
        guard zamkniety, punkty.count >= 3 else { return 0 }
        var area = 0.0
        let n = punkty.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += punkty[i].x * punkty[j].y
            area -= punkty[j].x * punkty[i].y
        }
        return abs(area) / 2.0 / 1_000_000  // mm² → m²
    }

    var boundingBox: CGRect {
        guard !punkty.isEmpty else { return .zero }
        let xs = punkty.map { $0.x }
        let ys = punkty.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Canvas View

struct KsztaltMeblaCanvasV080: View {
    @Binding var ksztalt: KsztaltMeblaV080

    @State private var skala: Double = 1.0          // px per mm
    @State private var przesuniecie: CGSize = .zero
    @State private var kursor: CGPoint? = nil
    @State private var editujePunkt: UUID? = nil
    @State private var showGrid = true
    @State private var snapKat = true
    @State private var snapOdleglosc = true
    @State private var edytowanyWymiar: UUID? = nil
    @State private var wpisanyWymiar: String = ""
    @GestureState private var pinchScale: Double = 1.0

    private let siatkaMM: Double = 50
    private let snapProgiMM: [Double] = [5, 10, 50, 100, 200, 300, 400, 500, 600, 800, 1000, 1200, 1500, 1800, 2000, 2400]
    private let snapKaty: [Double] = [0, 45, 90, 135, 180, 225, 270, 315, 360]

    var body: some View {
        ZStack {
            Color(.systemBackground)

            GeometryReader { geo in
                ZStack {
                    if showGrid {
                        gridLayer(in: geo.size)
                    }
                    konturLayer(in: geo.size)
                    wymiarowanieLablels(in: geo.size)
                    if !ksztalt.zamkniety {
                        podgladLayer(in: geo.size)
                    }
                    punktyLayer(in: geo.size)
                }
                .contentShape(Rectangle())
                .gesture(tapGesture(in: geo.size))
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            skala = max(0.1, min(5.0, skala * val / pinchScale))
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc): kursor = loc
                    case .ended: kursor = nil
                    }
                }
            }

            // Toolbar
            VStack {
                HStack {
                    toolbarButtons
                    Spacer()
                    infoPanel
                }
                .padding(12)
                Spacer()
                HStack {
                    Spacer()
                    zoomButtons
                }
                .padding(12)
            }
        }
        .onAppear { setupInitialView() }
    }

    // MARK: - Layers

    private func gridLayer(in size: CGSize) -> some View {
        Canvas { ctx, _ in
            let stepPx = siatkaMM * skala
            guard stepPx > 8 else { return }
            let offsetX = przesuniecie.width.truncatingRemainder(dividingBy: stepPx)
            let offsetY = przesuniecie.height.truncatingRemainder(dividingBy: stepPx)
            var x = offsetX
            while x < size.width {
                ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) },
                           with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                x += stepPx
            }
            var y = offsetY
            while y < size.height {
                ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) },
                           with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                y += stepPx
            }
            // Axes
            let ox = przesuniecie.width
            let oy = przesuniecie.height
            ctx.stroke(Path { p in p.move(to: CGPoint(x: ox, y: 0)); p.addLine(to: CGPoint(x: ox, y: size.height)) },
                       with: .color(.blue.opacity(0.2)), lineWidth: 1)
            ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: oy)); p.addLine(to: CGPoint(x: size.width, y: oy)) },
                       with: .color(.blue.opacity(0.2)), lineWidth: 1)
        }
    }

    private func konturLayer(in size: CGSize) -> some View {
        Canvas { ctx, _ in
            guard ksztalt.punkty.count >= 2 else { return }
            var path = Path()
            let first = toScreen(ksztalt.punkty[0], in: size)
            path.move(to: first)
            for punkt in ksztalt.punkty.dropFirst() {
                path.addLine(to: toScreen(punkt, in: size))
            }
            if ksztalt.zamkniety { path.closeSubpath() }

            if ksztalt.zamkniety {
                ctx.fill(path, with: .color(.blue.opacity(0.08)))
            }
            ctx.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private func podgladLayer(in size: CGSize) -> some View {
        Canvas { ctx, _ in
            guard let last = ksztalt.punkty.last, let cur = kursor else { return }
            let snapped = snapPoint(cur, in: size, from: last)
            let s = toScreen(last, in: size)
            let e = snapped
            ctx.stroke(
                Path { p in p.move(to: s); p.addLine(to: e) },
                with: .color(.orange.opacity(0.7)),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            // Snap marker
            ctx.fill(Path(ellipseIn: CGRect(x: e.x - 4, y: e.y - 4, width: 8, height: 8)), with: .color(.orange))
        }
    }

    private func punktyLayer(in size: CGSize) -> some View {
        ForEach(ksztalt.punkty) { punkt in
            let pos = toScreen(punkt, in: size)
            let isFirst = punkt.id == ksztalt.punkty.first?.id
            Circle()
                .fill(isFirst ? Color.green : Color.blue)
                .frame(width: isFirst ? 14 : 10, height: isFirst ? 14 : 10)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .position(pos)
                .onTapGesture {
                    if isFirst && ksztalt.punkty.count >= 3 && !ksztalt.zamkniety {
                        ksztalt.zamkniety = true
                    }
                }
        }
    }

    @ViewBuilder
    private func wymiarowanieLablels(in size: CGSize) -> some View {
        ForEach(ksztalt.odcinki) { odcinek in
            let s = toScreen(odcinek.start, in: size)
            let e = toScreen(odcinek.end, in: size)
            let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
            let dx = e.x - s.x
            let dy = e.y - s.y
            let angle = Angle(radians: atan2(Double(dy), Double(dx)))
            let dlugoscMM = odcinek.dlugoscMM
            let isEditing = edytowanyWymiar == odcinek.id

            ZStack {
                if isEditing {
                    TextField("mm", text: $wpisanyWymiar)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange))
                        .frame(width: 90)
                        .onSubmit { zastosujWymiar(odcinek: odcinek) }
                } else {
                    Text(formatMM(dlugoscMM))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.85)))
                        .onTapGesture {
                            edytowanyWymiar = odcinek.id
                            wpisanyWymiar = String(Int(dlugoscMM.rounded()))
                        }
                }
            }
            .rotationEffect(normalizedAngle(angle))
            .position(mid)
        }
    }

    // MARK: - Gesture

    private func tapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { val in
                guard !ksztalt.zamkniety else { return }
                let loc = val.location

                // Snap do pierwszego punktu jeśli blisko
                if let first = ksztalt.punkty.first, ksztalt.punkty.count >= 3 {
                    let firstScreen = toScreen(first, in: size)
                    if distance(loc, firstScreen) < 20 {
                        ksztalt.zamkniety = true
                        return
                    }
                }

                let snapped = snapPoint(loc, in: size, from: ksztalt.punkty.last)
                let mmPoint = toMM(snapped, in: size)
                ksztalt.punkty.append(mmPoint)
            }
    }

    // MARK: - Snap Logic

    private func snapPoint(_ screen: CGPoint, in size: CGSize, from lastPunkt: PunktKonturu?) -> CGPoint {
        var candidate = toMM(screen, in: size)

        // Snap do kąta od ostatniego punktu
        if snapKat, let last = lastPunkt {
            let dx = candidate.x - last.x
            let dy = candidate.y - last.y
            let dist = sqrt(dx * dx + dy * dy)
            let rawKat = atan2(dy, dx) * 180 / .pi
            let snapKat = snapKaty.min(by: { abs($0 - rawKat) < abs($1 - rawKat) })!
            if abs(rawKat - snapKat) < 8 {
                let rad = snapKat * .pi / 180
                candidate = PunktKonturu(x: last.x + dist * cos(rad), y: last.y + dist * sin(rad))
            }
        }

        // Snap do odległości
        if snapOdleglosc, let last = lastPunkt {
            let dx = candidate.x - last.x
            let dy = candidate.y - last.y
            let dist = sqrt(dx * dx + dy * dy)
            let snapDist = snapProgiMM.min(by: { abs($0 - dist) < abs($1 - dist) })!
            if abs(dist - snapDist) < 20 / skala {
                let angle = atan2(dy, dx)
                candidate = PunktKonturu(x: last.x + snapDist * cos(angle), y: last.y + snapDist * sin(angle))
            }
        }

        return toScreen(candidate, in: size)
    }

    // MARK: - Wymiar edit

    private func zastosujWymiar(odcinek: OdcinekKonturu) {
        guard let mm = Double(wpisanyWymiar), mm > 0 else {
            edytowanyWymiar = nil; return
        }
        guard let idx = ksztalt.punkty.firstIndex(where: { $0.id == odcinek.end.id }) else {
            edytowanyWymiar = nil; return
        }
        let start = odcinek.start
        let dx = odcinek.end.x - start.x
        let dy = odcinek.end.y - start.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }
        let scale = mm / dist
        ksztalt.punkty[idx] = PunktKonturu(
            x: start.x + dx * scale,
            y: start.y + dy * scale
        )
        edytowanyWymiar = nil
        wpisanyWymiar = ""
    }

    // MARK: - Coordinate transforms

    private func toScreen(_ punkt: PunktKonturu, in size: CGSize) -> CGPoint {
        CGPoint(
            x: przesuniecie.width + punkt.x * skala,
            y: przesuniecie.height - punkt.y * skala + size.height / 2
        )
    }

    private func toMM(_ screen: CGPoint, in size: CGSize) -> PunktKonturu {
        PunktKonturu(
            x: (screen.x - przesuniecie.width) / skala,
            y: (przesuniecie.height - screen.y + size.height / 2) / skala
        )
    }

    // MARK: - Toolbar

    private var toolbarButtons: some View {
        HStack(spacing: 8) {
            Button {
                if !ksztalt.punkty.isEmpty {
                    if ksztalt.zamkniety { ksztalt.zamkniety = false }
                    else { ksztalt.punkty.removeLast() }
                }
            } label: {
                Label("Cofnij", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(ksztalt.punkty.isEmpty)

            Button {
                ksztalt = KsztaltMeblaV080()
            } label: {
                Label("Wyczyść", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(ksztalt.punkty.isEmpty)

            Divider().frame(height: 24)

            Toggle("Siatka", isOn: $showGrid)
                .toggleStyle(.button)

            Toggle(isOn: $snapKat) {
                Label("Snap kąt", systemImage: "angle")
            }
            .toggleStyle(.button)

            Toggle(isOn: $snapOdleglosc) {
                Label("Snap mm", systemImage: "ruler")
            }
            .toggleStyle(.button)

            if ksztalt.zamkniety {
                Label("Zamknięty", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var infoPanel: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if ksztalt.zamkniety {
                Text("Powierzchnia: \(String(format: "%.3f", ksztalt.powierzchniaM2)) m²")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            Text("Punkty: \(ksztalt.punkty.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "Skala: %.0f%%", skala * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var zoomButtons: some View {
        VStack(spacing: 4) {
            Button { skala = min(5, skala * 1.3) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            Button { skala = max(0.1, skala / 1.3) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            Button { fitToScreen() } label: {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private func setupInitialView() {
        skala = 0.25  // 1mm = 0.25px (widok 2400mm = 600px)
        przesuniecie = CGSize(width: 60, height: 0)
    }

    private func fitToScreen() {
        guard !ksztalt.punkty.isEmpty else { setupInitialView(); return }
        skala = 0.25
        przesuniecie = CGSize(width: 60, height: 0)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = a.x - b.x; let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func formatMM(_ mm: Double) -> String {
        mm >= 10 ? "\(Int(mm.rounded())) mm" : String(format: "%.1f mm", mm)
    }

    private func normalizedAngle(_ angle: Angle) -> Angle {
        var deg = angle.degrees
        if deg > 90 { deg -= 180 }
        if deg < -90 { deg += 180 }
        return .degrees(deg)
    }
}

// MARK: - Preview wrapper

struct KsztaltMeblaCanvasPreviewV080: View {
    @State private var ksztalt = KsztaltMeblaV080()

    var body: some View {
        VStack(spacing: 0) {
            KsztaltMeblaCanvasV080(ksztalt: $ksztalt)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kliknij aby dodawać punkty konturu mebla.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Kliknij zielony punkt startowy aby zamknąć kształt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Kliknij wymiar na odcinku aby wpisać dokładną wartość.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !ksztalt.odcinki.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(ksztalt.odcinki) { o in
                            Text("\(Int(o.dlugoscMM.rounded())) mm @ \(Int(o.katStopnie.rounded()))°")
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("Kształt mebla")
        .navigationBarTitleDisplayMode(.inline)
    }
}
