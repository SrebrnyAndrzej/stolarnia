import DomainCore
import SwiftUI

/// Wspólny panel danych zaznaczonej ściany.
struct Plan2DWallInspector: View {
    let room: RoomDefinition
    let wall: WallSegment
    let onClose: () -> Void
    let onEdit: (() -> Void)?
    let onAddFeature: (() -> Void)?
    let showsStableID: Bool

    init(
        room: RoomDefinition,
        wall: WallSegment,
        showsStableID: Bool = true,
        onEdit: (() -> Void)? = nil,
        onAddFeature: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.room = room
        self.wall = wall
        self.showsStableID = showsStableID
        self.onEdit = onEdit
        self.onAddFeature = onAddFeature
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    wallTitle
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    headerButtons
                        .fixedSize()
                }

                VStack(alignment: .leading, spacing: 10) {
                    wallTitle
                    headerButtons
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 8) {
                GridRow {
                    Text("Długość")
                        .foregroundStyle(.secondary)
                    Text(formattedWallLength)
                }

                GridRow {
                    Text("Wysokość")
                        .foregroundStyle(.secondary)
                    Text(formattedWallHeight)
                }

                GridRow {
                    Text("Grubość")
                        .foregroundStyle(.secondary)
                    Text(formattedMillimeters(wall.thickness))
                }

                GridRow {
                    Text("Konstrukcja")
                        .foregroundStyle(.secondary)
                    Text(wall.constructionType.displayName)
                }

                GridRow {
                    Text("Elementy")
                        .foregroundStyle(.secondary)
                    Text("\(wallFeatureCount)")
                }

                if let profile =
                        MebelElewacjaScianyGeometry
                            .slopeProfile(
                                on: wall,
                                room: room
                            ),
                   let angle =
                        MebelElewacjaScianyGeometry
                            .katSkosuStopnie(
                                profil: profile
                            ) {
                    GridRow {
                        Text("Kąt skosu")
                            .foregroundStyle(
                                .purple
                            )
                        Text(
                            angle.formatted(
                                .number.precision(
                                    .fractionLength(1)
                                )
                            ) + "°"
                        )
                        .foregroundStyle(
                            .purple
                        )
                        .fontWeight(.semibold)
                    }
                }
            }
            .font(.subheadline)

            if !wall.notes.isEmpty {
                Text(wall.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsStableID {
                Text("WallID: \(wall.id.description)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private var wallTitle: some View {
        Label(wall.name, systemImage: "square.split.bottomrightquarter")
            .font(.headline)
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
    }

    private var headerButtons: some View {
        HStack(spacing: 8) {
            if let onAddFeature {
                Button {
                    onAddFeature()
                } label: {
                    Label(
                        "Element",
                        systemImage: "plus.rectangle.on.rectangle"
                    )
                }
                .buttonStyle(.bordered)
            }

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edytuj", systemImage: "pencil")
                }
                .buttonStyle(
                    StolarniaPrimaryButtonStyle(
                        minHeight: 40,
                        horizontalPadding: 12,
                        cornerRadius: 10
                    )
                )
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zamknij dane ściany")
        }
    }

    private var wallFeatureCount: Int {
        room.windows.filter {
            $0.placement.wallID == wall.id
        }.count
        + room.doors.filter {
            $0.placement.wallID == wall.id
        }.count
        + room.recesses.filter {
            $0.wallID == wall.id
        }.count
        + room.bayProjections.filter {
            $0.wallID == wall.id
        }.count
    }

    private var formattedWallLength: String {
        guard let segment = room.geometry.geometry(of: wall.id) else {
            return "Brak danych"
        }

        return formattedMillimeters(segment.length)
    }

    private var formattedWallHeight: String {
        if wall.startHeight == wall.endHeight {
            return formattedMillimeters(wall.startHeight)
        }

        return "\(formattedMillimeters(wall.startHeight)) → "
            + formattedMillimeters(wall.endHeight)
    }

    private func formattedMillimeters(
        _ value: Millimeters
    ) -> String {
        let formatted = value.rawValue.formatted(
            .number.precision(.fractionLength(0...1))
        )

        return "\(formatted) mm"
    }
}
