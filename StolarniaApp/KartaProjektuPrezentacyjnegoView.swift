import DomainCore
import SwiftUI
import UIKit

struct KartaProjektuPrezentacyjnegoViewV061: View {
    let room: RoomDefinition
    let wall: WallSegment
    let assemblies: [FurnitureAssembly]
    let globalneMaterialy: GlobalneMaterialyPomieszczenia

    @Environment(\.dismiss) private var dismiss
    @State private var udostepnianyPDF: URL?
    @State private var bladEksportu: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                KartaProjektuPrezentacyjnegoPlanszaV061(
                    room: room,
                    wall: wall,
                    assemblies: assemblies,
                    globalneMaterialy: globalneMaterialy
                )
                .padding(20)
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("Karta projektu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: pdfURL,
                        preview: SharePreview(
                            "Karta projektu — \(room.name)",
                            image: Image(systemName: "doc.richtext")
                        )
                    ) {
                        Label("Eksportuj PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .alert(
                "Nie udało się utworzyć PDF",
                isPresented: Binding(
                    get: { bladEksportu != nil },
                    set: { if !$0 { bladEksportu = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(bladEksportu ?? "")
            }
        }
    }

    private var pdfURL: URL {
        do {
            return try KartaProjektuPrezentacyjnegoPDFV061.generuj(
                room: room,
                wall: wall,
                assemblies: assemblies,
                globalneMaterialy: globalneMaterialy
            )
        } catch {
            DispatchQueue.main.async {
                bladEksportu = error.localizedDescription
            }
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("Karta-projektu.pdf")
        }
    }
}

struct KartaProjektuPrezentacyjnegoPlanszaV061: View {
    let room: RoomDefinition
    let wall: WallSegment
    let assemblies: [FurnitureAssembly]
    let globalneMaterialy: GlobalneMaterialyPomieszczenia

    private var assembliesOnWall: [FurnitureAssembly] {
        assemblies
            .filter { $0.placement?.wallID == wall.id }
            .sorted {
                ($0.placement?.offsetAlongWall.rawValue ?? 0)
                    < ($1.placement?.offsetAlongWall.rawValue ?? 0)
            }
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            KartaProjektuElewacjaV061(
                room: room,
                wall: wall,
                assemblies: assembliesOnWall,
                globalneMaterialy: globalneMaterialy
            )
            .frame(height: 390)

            HStack(alignment: .top, spacing: 18) {
                KartaProjektuElewacjaV061(
                    room: room,
                    wall: wall,
                    assemblies: assembliesOnWall,
                    globalneMaterialy: globalneMaterialy,
                    uproszczona: true
                )
                .frame(maxWidth: .infinity)
                .frame(height: 250)

                KartaProjektuPlanV061(
                    room: room,
                    assemblies: assemblies,
                    globalneMaterialy: globalneMaterialy
                )
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            }

            HStack(alignment: .top, spacing: 18) {
                detailsSection
                materialsSection
                notesSection
            }
        }
        .padding(24)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.22))
        }
        .frame(maxWidth: 1180)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.title.bold())
                Text("Elewacja: \(wall.name)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("KARTA PROJEKTU")
                    .font(.headline.weight(.bold))
                Text("Wymiary w milimetrach")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Date.now, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailsSection: some View {
        KartaProjektuSekcjaV061(title: "WYMIARY") {
            KartaProjektuWierszV061("Ściana", "\(Int(wallLength)) mm")
            KartaProjektuWierszV061("Wysokość", "\(Int(max(wall.startHeight.rawValue, wall.endHeight.rawValue))) mm")
            KartaProjektuWierszV061("Liczba modułów", "\(assembliesOnWall.count)")
            KartaProjektuWierszV061("Suma szerokości", "\(Int(assembliesOnWall.reduce(0) { $0 + $1.size.width.rawValue })) mm")
            if let maxDepth = assembliesOnWall.map({ $0.size.depth.rawValue }).max() {
                KartaProjektuWierszV061("Maks. głębokość", "\(Int(maxDepth)) mm")
            }
        }
    }

    private var materialsSection: some View {
        KartaProjektuSekcjaV061(title: "MATERIAŁY") {
            KartaProjektuWierszV061(
                "Korpus",
                "\(globalneMaterialy.korpus.producent) \(globalneMaterialy.korpus.kod)"
            )
            KartaProjektuWierszV061(
                "Front",
                "\(globalneMaterialy.front.producent) \(globalneMaterialy.front.kod)"
            )
            KartaProjektuWierszV061("Korpus — dekor", globalneMaterialy.korpus.nazwa)
            KartaProjektuWierszV061("Front — dekor", globalneMaterialy.front.nazwa)
        }
    }

    private var notesSection: some View {
        KartaProjektuSekcjaV061(title: "UWAGI") {
            Text("• Przed realizacją zweryfikować wymiary na miejscu.")
            Text("• Dokument prezentacyjny nie zastępuje dokumentacji produkcyjnej.")
            Text("• Wymiary AGD zależą od konkretnych modeli urządzeń.")
            Text("• Kolory ekranu mogą różnić się od fizycznych wzorników.")
        }
        .font(.caption)
    }

    private var wallLength: Double {
        room.geometry.geometry(of: wall.id)?.length.rawValue ?? 0
    }
}

private struct KartaProjektuSekcjaV061<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Divider()
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct KartaProjektuWierszV061: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.caption)
    }
}

private struct KartaProjektuElewacjaV061: View {
    let room: RoomDefinition
    let wall: WallSegment
    let assemblies: [FurnitureAssembly]
    let globalneMaterialy: GlobalneMaterialyPomieszczenia
    var uproszczona = false

    var body: some View {
        GeometryReader { proxy in
            let widthMM = max(
                room.geometry.geometry(of: wall.id)?.length.rawValue ?? 1,
                1
            )
            let heightMM = max(
                wall.startHeight.rawValue,
                wall.endHeight.rawValue,
                1
            )
            let topInset: CGFloat = uproszczona ? 36 : 48
            let sideInset: CGFloat = 48
            let drawing = CGRect(
                x: sideInset,
                y: topInset,
                width: max(proxy.size.width - sideInset * 2, 1),
                height: max(proxy.size.height - topInset - 38, 1)
            )
            let scaleX = drawing.width / widthMM
            let scaleY = drawing.height / heightMM

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.25))

                Path { path in
                    path.addRect(drawing)
                }
                .stroke(Color.primary.opacity(0.45), lineWidth: 1)

                ForEach(assemblies) { assembly in
                    if let placement = assembly.placement {
                        let rect = CGRect(
                            x: drawing.minX + placement.offsetAlongWall.rawValue * scaleX,
                            y: drawing.maxY
                                - (placement.bottomOffset.rawValue + assembly.size.height.rawValue) * scaleY,
                            width: max(assembly.size.width.rawValue * scaleX, 1),
                            height: max(assembly.size.height.rawValue * scaleY, 1)
                        )
                        Rectangle()
                            .fill(color(for: assembly).opacity(0.75))
                            .overlay(Rectangle().stroke(Color.primary.opacity(0.55)))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)

                        if !uproszczona, rect.width > 55 {
                            Text("\(Int(assembly.size.width.rawValue))")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .stolarniaMaterial(.regularMaterial, in: Capsule())
                                .position(x: rect.midX, y: rect.maxY + 13)
                        }
                    }
                }

                KartaProjektuLiniaWymiarowaV061(
                    value: "\(Int(widthMM)) mm",
                    start: CGPoint(x: drawing.minX, y: 23),
                    end: CGPoint(x: drawing.maxX, y: 23)
                )
            }
        }
    }

    private func color(for assembly: FurnitureAssembly) -> Color {
        let isUpper = (assembly.placement?.bottomOffset.rawValue ?? 0) > 1000
        return Color(
            hex: isUpper
                ? globalneMaterialy.front.kolorHEX
                : globalneMaterialy.korpus.kolorHEX
        )
    }
}

private struct KartaProjektuPlanV061: View {
    let room: RoomDefinition
    let assemblies: [FurnitureAssembly]
    let globalneMaterialy: GlobalneMaterialyPomieszczenia

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.25))
                Text("RZUT Z GÓRY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .position(x: proxy.size.width / 2, y: 16)

                let inset: CGFloat = 38
                let usable = CGRect(
                    x: inset,
                    y: 34,
                    width: max(proxy.size.width - 2 * inset, 1),
                    height: max(proxy.size.height - 58, 1)
                )
                Path { $0.addRect(usable) }
                    .stroke(Color.primary.opacity(0.35), lineWidth: 1)

                Text("\(assemblies.count) modułów")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .position(x: usable.midX, y: usable.midY)
            }
        }
    }
}

private struct KartaProjektuLiniaWymiarowaV061: View {
    let value: String
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        Canvas { context, _ in
            var line = Path()
            line.move(to: start)
            line.addLine(to: end)
            context.stroke(line, with: .color(.primary), lineWidth: 1)
            let text = Text(value).font(.caption.weight(.semibold))
            context.draw(
                text,
                at: CGPoint(x: (start.x + end.x) / 2, y: start.y),
                anchor: .center
            )
        }
    }
}

private extension Color {
    init(hex: String) {
        let normalized = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        let r, g, b: Double
        if normalized.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.78; g = 0.78; b = 0.78
        }
        self.init(red: r, green: g, blue: b)
    }
}
