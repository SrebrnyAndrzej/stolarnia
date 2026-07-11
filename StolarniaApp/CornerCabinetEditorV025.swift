import DomainCore
import SwiftUI

struct CornerCabinetEditorV025:
    View
{
    let assemblies:
        [FurnitureAssembly]

    @Binding var definitions:
        [CornerCabinetDefinitionV025]

    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedIndex = 0
    @State private var kind:
        CornerCabinetKindV025 =
            .lShaped
    @State private var handedness:
        CornerCabinetHandednessV025 =
            .left
    @State private var leftArmMM = 900.0
    @State private var rightArmMM = 900.0
    @State private var depthMM = 560.0
    @State private var frontWidthMM = 450.0
    @State private var deadSpaceMM = 300.0
    @State private var frontAngleDegrees = 45.0
    @State private var shelfCount = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Moduł") {
                    Picker(
                        "Moduł narożny",
                        selection:
                            $selectedIndex
                    ) {
                        ForEach(
                            assemblies.indices,
                            id: \.self
                        ) { index in
                            Text(
                                "M\(String(format: "%02d", index + 1))"
                            )
                            .tag(index)
                        }
                    }
                    .onChange(
                        of: selectedIndex
                    ) {
                        loadSelected()
                    }
                }

                Section("Konstrukcja") {
                    Picker(
                        "Typ",
                        selection: $kind
                    ) {
                        ForEach(
                            CornerCabinetKindV025
                                .allCases
                        ) {
                            Text($0.title)
                                .tag($0)
                        }
                    }

                    Picker(
                        "Wariant",
                        selection:
                            $handedness
                    ) {
                        ForEach(
                            CornerCabinetHandednessV025
                                .allCases
                        ) {
                            Text($0.title)
                                .tag($0)
                        }
                    }

                    numberField(
                        "Lewe ramię [mm]",
                        value: $leftArmMM
                    )

                    numberField(
                        "Prawe ramię [mm]",
                        value: $rightArmMM
                    )

                    numberField(
                        "Głębokość [mm]",
                        value: $depthMM
                    )

                    numberField(
                        "Szerokość frontu [mm]",
                        value: $frontWidthMM
                    )

                    if kind == .blindCorner || kind == .halfBlind {
                        numberField(
                            kind == .halfBlind
                                ? "Wysuniecie [mm]"
                                : "Martwa przestrzeń [mm]",
                            value:
                                $deadSpaceMM
                        )
                    }

                    if kind == .halfBlind {
                        Text("Półnarożnik: front tylko na widocznej stronie. Głębokość martwej przestrzeni = wysuniecie modułu poza linię ciągu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if kind == .diagonalFront {
                        numberField(
                            "Kąt frontu [°]",
                            value:
                                $frontAngleDegrees
                        )
                    }

                    Stepper(
                        "Półki: \(shelfCount)",
                        value: $shelfCount,
                        in: 0...8
                    )
                }

                if let draft =
                    currentDefinition {
                    Section("Walidacja") {
                        if draft
                            .validationMessages
                            .isEmpty {
                            Label(
                                "Konstrukcja poprawna",
                                systemImage:
                                    "checkmark.circle.fill"
                            )
                            .foregroundStyle(
                                .green
                            )
                        } else {
                            ForEach(
                                draft
                                    .validationMessages,
                                id: \.self
                            ) {
                                Label(
                                    $0,
                                    systemImage:
                                        "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(
                                    .orange
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(
                "Szafka narożna"
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
                        save()
                    }
                    .disabled(
                        assemblies.isEmpty
                    )
                }
            }
            .onAppear {
                loadSelected()
            }
        }
    }

    private var currentDefinition:
        CornerCabinetDefinitionV025?
    {
        guard
            assemblies.indices.contains(
                selectedIndex
            )
        else {
            return nil
        }

        return CornerCabinetDefinitionV025(
            assemblyID:
                assemblies[
                    selectedIndex
                ].id,
            kind: kind,
            handedness:
                handedness,
            leftArmMM:
                leftArmMM,
            rightArmMM:
                rightArmMM,
            depthMM:
                depthMM,
            frontWidthMM:
                frontWidthMM,
            deadSpaceMM:
                deadSpaceMM,
            frontAngleDegrees:
                frontAngleDegrees,
            shelfCount:
                shelfCount
        )
    }

    private func loadSelected() {
        guard
            assemblies.indices.contains(
                selectedIndex
            )
        else {
            return
        }

        let id =
            assemblies[
                selectedIndex
            ].id

        guard let value =
            definitions.first(
                where: {
                    $0.assemblyID == id
                }
            )
        else {
            return
        }

        kind = value.kind
        handedness =
            value.handedness
        leftArmMM =
            value.leftArmMM
        rightArmMM =
            value.rightArmMM
        depthMM =
            value.depthMM
        frontWidthMM =
            value.frontWidthMM
        deadSpaceMM =
            value.deadSpaceMM
        frontAngleDegrees =
            value.frontAngleDegrees
        shelfCount =
            value.shelfCount
    }

    private func save() {
        guard let value =
            currentDefinition
        else {
            return
        }

        definitions.removeAll {
            $0.assemblyID
                == value.assemblyID
        }
        definitions.append(value)
        CornerCabinetRepositoryV025
            .save(value)
        dismiss()
    }

    private func numberField(
        _ title: String,
        value:
            Binding<Double>
    ) -> some View {
        TextField(
            title,
            value: value,
            format:
                .number.grouping(
                    .never
                )
        )
        .keyboardType(.decimalPad)
    }
}
