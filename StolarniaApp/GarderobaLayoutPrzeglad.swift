import DomainCore
import Persistence
import SwiftUI

// MARK: - FurnitureAssemblyKind display helper

private extension FurnitureAssemblyKind {
    var displayTitle: String {
        switch self {
        case .cabinet:       return "Szafka"
        case .wardrobe:      return "Szafa"
        case .desk:          return "Biurko"
        case .shelving:      return "Regał"
        case .table:         return "Stół"
        case .recessBuiltIn: return "Zabudowa wnękowa"
        case .slidingWardrobe: return "Szafa przesuwna"
        case .custom:        return "Niestandardowy"
        }
    }
}

// MARK: - Typ układu garderoba

enum TypUkladuGarderobyV081: String {
    case brak           = "Brak mebli"
    case prosty         = "Układ prosty"
    case L              = "Układ L"
    case U              = "Układ U"
    case wieloScianowy  = "Układ wielościenny"

    var systemImage: String {
        switch self {
        case .brak:         return "square.dashed"
        case .prosty:       return "rectangle"
        case .L:            return "arrow.turn.down.right"
        case .U:            return "arrow.uturn.right"
        case .wieloScianowy: return "square.grid.3x3"
        }
    }

    var color: Color {
        switch self {
        case .brak:         return .secondary
        case .prosty:       return .blue
        case .L:            return .green
        case .U:            return .orange
        case .wieloScianowy: return .purple
        }
    }
}

// MARK: - Widok przeglądu układu garderoba

/// Widok prezentacyjny układu L/U garderoba — rzut z góry plus
/// lista modułów per ściana. Przeznaczony do pokazania klientowi.
struct GarderobaLayoutPrzeglad: View {

    let room: RoomDefinition
    let assemblies: [StoredFurnitureAssembly]

    // Paleta kolorów — jedna per ściana, cyklicznie
    private let wallPalette: [Color] = [
        .blue, .green, .orange, .purple,
        .red, .teal, .indigo, .mint
    ]

    // MARK: - Computed

    private var furnitureAssemblies: [FurnitureAssembly] {
        assemblies.map(\.assembly)
    }

    private var footprints: [MebelPlan2DFootprint] {
        MebelPlan2DGeometry.footprints(for: furnitureAssemblies, in: room)
    }

    private var orderedWallIDs: [WallID] {
        room.geometry.walls.map(\.id)
    }

    private var wallsWithFurnitureIDs: Set<WallID> {
        Set(furnitureAssemblies.compactMap { $0.placement?.wallID })
    }

    private var wallsWithFurniture: [WallSegment] {
        room.geometry.walls.filter { wallsWithFurnitureIDs.contains($0.id) }
    }

    private var layoutType: TypUkladuGarderobyV081 {
        switch wallsWithFurnitureIDs.count {
        case 0:         return .brak
        case 1:         return .prosty
        case 2:         return .L
        case 3:         return .U
        default:        return .wieloScianowy
        }
    }

    private var totalFurnitureCount: Int { assemblies.count }

    private var totalWidthMM: Double {
        furnitureAssemblies.reduce(0) { $0 + $1.size.width.rawValue }
    }

    private func furniture(onWall wallID: WallID) -> [FurnitureAssembly] {
        furnitureAssemblies
            .filter { $0.placement?.wallID == wallID }
            .sorted {
                ($0.placement?.offsetAlongWall.rawValue ?? 0)
                    < ($1.placement?.offsetAlongWall.rawValue ?? 0)
            }
    }

    private func wallColor(for wallID: WallID) -> Color {
        let idx = orderedWallIDs.firstIndex(of: wallID) ?? 0
        return wallPalette[idx % wallPalette.count]
    }

    private func wallLengthMM(for wall: WallSegment) -> Double {
        room.geometry.geometry(of: wall.id)?.length.rawValue ?? 0
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                canvasCard
                wallPanelsSection
                summaryCard
            }
            .padding()
        }
        .navigationTitle("Podgląd układu")
        .navigationBarTitleDisplayMode(.inline)
        .background(StolarniaPalette.canvas)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.title2.bold())

                Group {
                    if totalFurnitureCount == 0 {
                        Text("Brak modułów meblowych")
                    } else {
                        Text(
                            "\(totalFurnitureCount) moduł\(totalFurnitureCount == 1 ? "" : "ów")"
                            + " · łącznie \(String(format: "%.1f", totalWidthMM / 1000)) m frontów"
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Label(layoutType.rawValue, systemImage: layoutType.systemImage)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(layoutType.color.opacity(0.15))
                .foregroundStyle(layoutType.color)
                .clipShape(Capsule())
        }
    }

    // MARK: - Canvas (rzut z góry)

    private var canvasCard: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                Canvas { ctx, size in
                    drawFloorPlan(ctx: ctx, size: size)
                }

                Text("Rzut z góry — nie w skali")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .frame(height: 300)
        .background(StolarniaPalette.canvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }

    private func drawFloorPlan(ctx: GraphicsContext, size: CGSize) {
        // Zbieramy wszystkie punkty do obliczenia skali projekcji
        let boundaryPoints = room.geometry.boundary.segments
            .flatMap { Plan2DGeometryAdapter.sampledPoints(for: $0) }
        let furniturePoints = footprints.flatMap(\.points)
        let allPoints = boundaryPoints + furniturePoints

        guard !allPoints.isEmpty else { return }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: 32
        )

        // 1. Obrys pomieszczenia — wypełnienie i krawędź
        var roomPath = Path()
        var isFirstSegment = true
        for segment in room.geometry.boundary.segments {
            let pts = Plan2DGeometryAdapter.sampledPoints(for: segment)
                .map(projection.screenPoint)
            if isFirstSegment, let first = pts.first {
                roomPath.move(to: first)
                for pt in pts.dropFirst() { roomPath.addLine(to: pt) }
                isFirstSegment = false
            } else {
                for pt in pts { roomPath.addLine(to: pt) }
            }
        }
        roomPath.closeSubpath()

        ctx.fill(
            roomPath,
            with: .color(Color(.systemBackground).opacity(0.7))
        )
        ctx.stroke(
            roomPath,
            with: .color(Color(.label).opacity(0.6)),
            style: StrokeStyle(lineWidth: 2, lineJoin: .round)
        )

        // 2. Footprinty mebli — kolorowane per ściana
        let fpByWall = Dictionary(grouping: footprints, by: \.wallID)
        for (wallID, wfps) in fpByWall {
            let col = wallID.map {
                wallColor(for: $0)
            } ?? Color.accentColor
            for fp in wfps {
                var path = Path()
                let pts = fp.points.map(projection.screenPoint)
                if let first = pts.first {
                    path.move(to: first)
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                    path.closeSubpath()
                }
                ctx.fill(path, with: .color(col.opacity(0.45)))
                ctx.stroke(
                    path,
                    with: .color(col.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 1.5)
                )
            }
        }

        // 3. Wymiary ścian — etykiety przy środku każdej ściany
        for wall in room.geometry.walls {
            guard let segment = room.geometry.geometry(of: wall.id) else { continue }
            let pts = Plan2DGeometryAdapter.sampledPoints(for: segment)
            guard let first = pts.first, let last = pts.last else { continue }

            let midPt = Point2MM(
                x: Millimeters((first.x.rawValue + last.x.rawValue) / 2),
                y: Millimeters((first.y.rawValue + last.y.rawValue) / 2)
            )
            let screen = projection.screenPoint(midPt)
            let lengthCM = Int((segment.length.rawValue / 10).rounded())
            let label = "\(lengthCM) cm"

            ctx.draw(
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(.label).opacity(0.7)),
                at: screen
            )
        }

        // 4. Legenda kolorów ścian (lewy górny róg)
        let legendWalls = wallsWithFurniture.prefix(4)
        var legendY: CGFloat = 10
        for wall in legendWalls {
            let col = wallColor(for: wall.id)
            let dotRect = CGRect(x: 12, y: legendY, width: 9, height: 9)
            ctx.fill(Path(ellipseIn: dotRect), with: .color(col))
            let name = wall.name.isEmpty ? "Ściana" : wall.name
            ctx.draw(
                Text(name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(.label).opacity(0.85)),
                at: CGPoint(x: 36, y: legendY + 4.5)
            )
            legendY += 18
        }
    }

    // MARK: - Panele ścian

    @ViewBuilder
    private var wallPanelsSection: some View {
        if wallsWithFurniture.isEmpty {
            ContentUnavailableView(
                "Brak modułów",
                systemImage: "square.dashed",
                description: Text(
                    "Dodaj moduły meblowe do ścian w Planie 2D lub Elewacji."
                )
            )
        } else {
            VStack(spacing: 10) {
                ForEach(wallsWithFurniture) { wall in
                    wallPanel(for: wall)
                }
            }
        }
    }

    private func wallPanel(for wall: WallSegment) -> some View {
        let col = wallColor(for: wall.id)
        let modules = furniture(onWall: wall.id)
        let lengthMM = wallLengthMM(for: wall)
        let totalModuleWidthMM = modules.reduce(0.0) { $0 + $1.size.width.rawValue }
        let fillPct = lengthMM > 0 ? min(totalModuleWidthMM / lengthMM, 1.0) : 0.0

        return VStack(alignment: .leading, spacing: 0) {
            // --- Nagłówek ściany ---
            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(col)
                    .frame(width: 5, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(wall.name.isEmpty ? "Ściana" : wall.name)
                        .font(.headline)

                    Text(
                        String(format: "%.0f cm dł. · %d modułów",
                               lengthMM / 10,
                               modules.count)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(fillPct * 100))% zajęte")
                        .font(.caption.bold())
                        .foregroundStyle(fillPct > 0.95 ? .orange : col)

                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(col.opacity(0.15))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(fillPct > 0.95 ? Color.orange : col)
                                .frame(
                                    width: g.size.width * fillPct,
                                    height: 4
                                )
                        }
                    }
                    .frame(width: 72, height: 4)
                }
            }
            .padding()
            .background(col.opacity(0.07))

            Divider().padding(.leading, 30)

            // --- Lista modułów ---
            ForEach(Array(modules.enumerated()), id: \.element.id) { idx, assembly in
                HStack(spacing: 10) {
                    Text("\(idx + 1)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(assembly.name)
                            .font(.subheadline)

                        Text(assembly.kind.displayTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(
                            "\(Int(assembly.size.width.rawValue))×"
                            + "\(Int(assembly.size.height.rawValue)) mm"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                        Text("gł. \(Int(assembly.size.depth.rawValue)) mm")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 7)

                if idx < modules.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(StolarniaPalette.canvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Podsumowanie

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Podsumowanie")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                summaryCell(
                    value: "\(wallsWithFurniture.count)",
                    label: "Ściany z\nmeblami"
                )

                Divider().frame(height: 44)

                summaryCell(
                    value: "\(totalFurnitureCount)",
                    label: "Modułów\nłącznie"
                )

                Divider().frame(height: 44)

                summaryCell(
                    value: String(format: "%.1f m", totalWidthMM / 1_000),
                    label: "Fronty\nłącznie"
                )

                if !wallsWithFurniture.isEmpty {
                    Divider().frame(height: 44)

                    summaryCell(
                        value: String(
                            format: "%.1f m²",
                            wallsWithFurniture.reduce(0.0) { sum, wall in
                                let l = wallLengthMM(for: wall) / 1_000
                                let h = max(wall.startHeight.rawValue, wall.endHeight.rawValue) / 1_000
                                return sum + l * h
                            }
                        ),
                        label: "Pow. ścian\nz meblami"
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(StolarniaPalette.canvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
