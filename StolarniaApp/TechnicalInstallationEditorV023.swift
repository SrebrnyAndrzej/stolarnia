import DomainCore
import SwiftUI

struct TechnicalInstallationEditorV023:
    View
{
    let wallID: WallID

    @Binding var points:
        [TechnicalInstallationPointV023]

    @Environment(\.dismiss)
    private var dismiss

    @State private var kind:
        TechnicalInstallationKindV023 =
            .electricalSocket
    @State private var offsetMM = 600.0
    @State private var heightMM = 1_100.0
    @State private var widthMM = 0.0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nowy punkt") {
                    Picker(
                        "Rodzaj",
                        selection: $kind
                    ) {
                        ForEach(
                            TechnicalInstallationKindV023
                                .allCases
                        ) {
                            Text($0.title)
                                .tag($0)
                        }
                    }

                    numberField(
                        "Odległość od początku ściany [mm]",
                        value: $offsetMM
                    )

                    numberField(
                        "Wysokość od posadzki [mm]",
                        value: $heightMM
                    )

                    numberField(
                        "Szerokość strefy [mm]",
                        value: $widthMM
                    )

                    TextField(
                        "Opis",
                        text: $note,
                        axis: .vertical
                    )

                    Button {
                        addPoint()
                    } label: {
                        Label(
                            "Dodaj punkt",
                            systemImage:
                                "plus.circle.fill"
                        )
                    }
                }

                Section("Punkty na ścianie") {
                    if points.isEmpty {
                        Text(
                            "Brak punktów instalacyjnych."
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    ForEach(points) {
                        point in

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(
                                point.kind.title
                            )
                            .font(.headline)

                            Text(
                                "\(Int(point.offsetAlongWallMM.rounded())) mm od początku • \(Int(point.heightFromFloorMM.rounded())) mm nad posadzką"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )

                            if !point.note.isEmpty {
                                Text(point.note)
                            }
                        }
                    }
                    .onDelete {
                        indexes in
                        points.remove(
                            atOffsets: indexes
                        )
                    }
                }
            }
            .navigationTitle(
                "Punkty instalacyjne"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Zapisz") {
                        TechnicalInstallationRepositoryV023
                            .save(
                                points,
                                wallID: wallID
                            )
                        dismiss()
                    }
                }
            }
        }
    }

    private func addPoint() {
        points.append(
            TechnicalInstallationPointV023(
                wallID: wallID,
                kind: kind,
                offsetAlongWallMM:
                    offsetMM,
                heightFromFloorMM:
                    heightMM,
                widthMM: widthMM,
                note: note
            )
        )

        note = ""
    }

    private func numberField(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        TextField(
            title,
            value: value,
            format:
                .number.grouping(.never)
        )
        .keyboardType(.decimalPad)
    }
}
