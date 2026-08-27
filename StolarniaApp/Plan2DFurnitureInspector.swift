import DomainCore
import Persistence
import SwiftUI

struct Plan2DFurnitureInspector: View {
    let storedAssembly: StoredFurnitureAssembly
    let showsActions: Bool
    let onAddAdjacent: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onClose: () -> Void

    init(
        storedAssembly: StoredFurnitureAssembly,
        showsActions: Bool = true,
        onAddAdjacent: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.storedAssembly = storedAssembly
        self.showsActions = showsActions
        self.onAddAdjacent = onAddAdjacent
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    titleBlock
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    headerButtons
                        .fixedSize()
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleBlock
                    headerButtons
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    measurements
                }

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 94
                            ),
                            alignment: .leading
                        )
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    measurements
                }
            }

            if showsActions {
                HStack {
                    if let onEdit {
                        Button("Edytuj", systemImage: "slider.horizontal.3") {
                            onEdit()
                        }
                        .buttonStyle(
                            StolarniaPrimaryButtonStyle(
                                minHeight: 40,
                                horizontalPadding: 12,
                                cornerRadius: 10
                            )
                        )
                    }

                    if let onDelete {
                        Button(
                            "Usuń",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            onDelete()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .stolarniaMaterial(.regularMaterial)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(storedAssembly.assembly.name)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Text(storedAssembly.assembly.id.description)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private var headerButtons: some View {
        HStack(spacing: 8) {
            if let onAddAdjacent, showsActions {
                Button {
                    onAddAdjacent()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(
                    StolarniaPrimaryIconButtonStyle(
                        size: 40
                    )
                )
                .accessibilityLabel("Dodaj moduł obok")
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var measurements: some View {
        measurement("Szerokość", storedAssembly.assembly.size.width)
        measurement("Wysokość", storedAssembly.assembly.size.height)
        measurement("Głębokość", storedAssembly.assembly.size.depth)

        if let placement = storedAssembly.assembly.placement {
            measurement("Pozycja", placement.offsetAlongWall)
            measurement("Od podłogi", placement.bottomOffset)
        }
    }

    private func measurement(
        _ title: String,
        _ value: Millimeters
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(MebelWymiarFormatterV0143.millimeters(value))
                .font(.body.monospacedDigit())
        }
    }

}
