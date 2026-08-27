import DomainCore
import Foundation
import Persistence
import SwiftUI

nonisolated enum FurnitureLegendKindV016: String, Hashable, Sendable {
    case base
    case wall
    case tall
    case other

    var title: String {
        switch self {
        case .base: return "Dolny"
        case .wall: return "Wiszący"
        case .tall: return "Wysoki"
        case .other: return "Inny"
        }
    }

    var systemImage: String {
        switch self {
        case .base: return "cabinet"
        case .wall: return "square.topthird.inset.filled"
        case .tall: return "rectangle.portrait"
        case .other: return "square.3.layers.3d"
        }
    }
}

nonisolated struct FurnitureCanvasItemV016: Identifiable, Hashable, Sendable {
    let id: FurnitureAssemblyID
    let number: Int
    let label: String
    let name: String
    let kind: FurnitureLegendKindV016
    let wallID: WallID?
    let wallName: String
    let width: Millimeters
    let height: Millimeters
    let depth: Millimeters
    let offsetAlongWall: Millimeters
    let bottomOffset: Millimeters
}

nonisolated enum FurnitureCanvasNumberingV016 {
    static func make(
        room: RoomDefinition,
        storedAssemblies: [StoredFurnitureAssembly]
    ) -> [FurnitureCanvasItemV016] {
        let wallOrder = Dictionary(
            uniqueKeysWithValues: room.geometry.walls.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )
        let wallNames = Dictionary(
            uniqueKeysWithValues: room.geometry.walls.map {
                ($0.id, $0.name)
            }
        )

        let sorted = storedAssemblies.sorted { lhs, rhs in
            let lhsPlacement = lhs.assembly.placement
            let rhsPlacement = rhs.assembly.placement
            let lhsWall = lhsPlacement?.wallID.flatMap {
                wallOrder[$0]
            } ?? Int.max
            let rhsWall = rhsPlacement?.wallID.flatMap {
                wallOrder[$0]
            } ?? Int.max

            if lhsWall != rhsWall {
                return lhsWall < rhsWall
            }

            let lhsX = lhsPlacement?.offsetAlongWall ?? .zero
            let rhsX = rhsPlacement?.offsetAlongWall ?? .zero
            if lhsX != rhsX {
                return lhsX < rhsX
            }

            let lhsY = lhsPlacement?.bottomOffset ?? .zero
            let rhsY = rhsPlacement?.bottomOffset ?? .zero
            if lhsY != rhsY {
                return lhsY < rhsY
            }

            return lhs.id.description < rhs.id.description
        }

        return sorted.enumerated().map { index, stored in
            let placement = stored.assembly.placement
            let number = index + 1
            let wallID = placement?.wallID

            return FurnitureCanvasItemV016(
                id: stored.id,
                number: number,
                label: String(format: "M%02d", number),
                name: stored.assembly.name,
                kind: kind(for: stored.assembly),
                wallID: wallID,
                wallName: wallID.flatMap { wallNames[$0] }
                    ?? "Bez ściany",
                width: stored.assembly.size.width,
                height: stored.assembly.size.height,
                depth: stored.assembly.size.depth,
                offsetAlongWall:
                    placement?.offsetAlongWall ?? .zero,
                bottomOffset:
                    placement?.bottomOffset ?? .zero
            )
        }
    }

    static func items(
        on wallID: WallID,
        from items: [FurnitureCanvasItemV016]
    ) -> [FurnitureCanvasItemV016] {
        items.filter { $0.wallID == wallID }
    }

    static func labelMap(
        from items: [FurnitureCanvasItemV016]
    ) -> [FurnitureAssemblyID: String] {
        Dictionary(
            uniqueKeysWithValues: items.map {
                ($0.id, $0.label)
            }
        )
    }

    private static func kind(
        for assembly: FurnitureAssembly
    ) -> FurnitureLegendKindV016 {
        if assembly.placement?.anchoringMode == .wallMounted {
            return .wall
        }

        switch assembly.kind {
        case .wardrobe, .recessBuiltIn, .slidingWardrobe:
            return .tall
        default:
            break
        }

        if assembly.placement?.anchoringMode == .builtIn
            || assembly.size.height >= 1_600 {
            return .tall
        }

        return .base
    }
}

struct FurnitureLegendV016: View {
    let title: String
    let items: [FurnitureCanvasItemV016]
    @Binding var selectedFurnitureID: FurnitureAssemblyID?
    var maximumHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: "list.number")
                    .font(.headline)

                Spacer()

                Text("\(items.count) modułów")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 5) {
                    header

                    ScrollView(.vertical) {
                        LazyVStack(spacing: 5) {
                            ForEach(items) { item in
                                Button {
                                    selectedFurnitureID = item.id
                                } label: {
                                    row(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: maximumHeight)
                }
                .frame(minWidth: 760, alignment: .leading)
            }
        }
        .padding(12)
        .background(StolarniaPalette.canvasRaised)
    }

    private var header: some View {
        HStack(spacing: 8) {
            cell("Nr", width: 58, alignment: .center)
            cell("Nazwa", width: 250, alignment: .leading)
            cell("Typ", width: 100, alignment: .leading)
            cell("Wymiary S×W×G", width: 170, alignment: .leading)
            cell("Ściana", width: 110, alignment: .leading)
            cell("Pozycja", width: 130, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
    }

    private func row(
        _ item: FurnitureCanvasItemV016
    ) -> some View {
        let isSelected = selectedFurnitureID == item.id

        return HStack(spacing: 8) {
            Text(item.label)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(
                    isSelected ? Color.white : Color.primary
                )
                .frame(width: 48, height: 28)
                .background(
                    Capsule().fill(
                        isSelected
                            ? Color.accentColor
                            : Color(uiColor: .systemGray5)
                    )
                )
                .frame(width: 58)

            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 250, alignment: .leading)

            Label(
                item.kind.title,
                systemImage: item.kind.systemImage
            )
            .font(.caption)
            .lineLimit(1)
            .frame(width: 100, alignment: .leading)

            Text(
                "\(formatted(item.width)) × "
                + "\(formatted(item.height)) × "
                + formatted(item.depth)
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 170, alignment: .leading)

            Text(item.wallName)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)

            Text(
                "x \(formatted(item.offsetAlongWall)), "
                + "y \(formatted(item.bottomOffset))"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: 130, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.11)
                        : StolarniaPalette.canvasInset
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    isSelected
                        ? Color.accentColor.opacity(0.45)
                        : Color.clear,
                    lineWidth: 1
                )
        }
    }

    private func cell(
        _ value: String,
        width: CGFloat,
        alignment: Alignment
    ) -> some View {
        Text(value)
            .frame(width: width, alignment: alignment)
    }

    private func formatted(
        _ value: Millimeters
    ) -> String {
        value.rawValue.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }
}
