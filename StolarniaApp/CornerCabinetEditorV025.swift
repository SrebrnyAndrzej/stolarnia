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
    @State private var accessTechnology:
        CornerCabinetAccessTechnologyV085 =
            .shelves
    @State private var fillerKind:
        CornerCabinetFillerKindV086 =
            .cornerPost90
    @State private var fillerWidthMM = 30.0
    @State private var clearHeightMM = 720.0
    @State private var handleProjectionMM = 0.0

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

                Section("Mechanika i blendy") {
                    Picker(
                        "Mechanizm",
                        selection:
                            $accessTechnology
                    ) {
                        ForEach(
                            CornerCabinetAccessTechnologyV085
                                .allCases
                        ) {
                            Text($0.title)
                                .tag($0)
                        }
                    }

                    Picker(
                        "Blenda / luz",
                        selection:
                            $fillerKind
                    ) {
                        ForEach(
                            CornerCabinetFillerKindV086
                                .allCases
                        ) {
                            Text($0.title)
                                .tag($0)
                        }
                    }

                    Button(
                        "Ustaw zalecany mechanizm i blendę"
                    ) {
                        applyRecommendedTechnology()
                    }

                    Button(
                        "Dopasuj blendę do mechanizmu"
                    ) {
                        applyRecommendedFiller()
                    }

                    if fillerKind != .none {
                        numberField(
                            "Szerokość blendy [mm]",
                            value:
                                $fillerWidthMM
                        )
                    }

                    numberField(
                        "Światło wysokości [mm]",
                        value:
                            $clearHeightMM
                    )

                    numberField(
                        "Wystawanie uchwytu [mm]",
                        value:
                            $handleProjectionMM
                    )

                    ruleSummary
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
                shelfCount,
            accessTechnologyOverride:
                accessTechnology,
            fillerKindOverride:
                fillerKind,
            fillerWidthMM:
                fillerKind == .none
                    ? 0
                    : fillerWidthMM,
            clearHeightMM:
                clearHeightMM,
            handleProjectionMM:
                handleProjectionMM
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
            let assembly =
                assemblies[
                    selectedIndex
                ]
            let draft =
                CornerCabinetDefinitionV025(
                    assemblyID: id,
                    leftArmMM:
                        max(
                            assembly.size.width.rawValue,
                            900
                        ),
                    rightArmMM:
                        max(
                            assembly.size.depth.rawValue,
                            900
                        ),
                    depthMM:
                        max(
                            assembly.size.depth.rawValue,
                            560
                        ),
                    clearHeightMM:
                        assembly.size.height.rawValue
                )
            apply(
                definition: draft,
                assemblyHeight:
                    assembly.size.height.rawValue
            )
            return
        }

        apply(
            definition: value,
            assemblyHeight:
                assemblies[
                    selectedIndex
                ].size.height.rawValue
        )
    }

    private func apply(
        definition value:
            CornerCabinetDefinitionV025,
        assemblyHeight:
            Double
    ) {
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
        accessTechnology =
            value.effectiveAccessTechnology
        fillerKind =
            value.effectiveFillerKind
        fillerWidthMM =
            value.effectiveFillerWidthMM
        clearHeightMM =
            value.clearHeightMM
                ?? assemblyHeight
        handleProjectionMM =
            value.handleProjectionMM
                ?? 0
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

    private var currentRule:
        CornerCabinetTechnologyRuleV086
    {
        CornerCabinetRuleBookV086
            .technologyRule(
                for: accessTechnology
            )
    }

    private var ruleSummary:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            LabeledContent(
                "Min. front",
                value:
                    "\(Int(currentRule.minimumFrontOpeningMM)) mm"
            )
            LabeledContent(
                "Min. głębokość",
                value:
                    "\(Int(currentRule.minimumInternalDepthMM)) mm"
            )
            LabeledContent(
                "Min. ramiona",
                value:
                    "\(Int(currentRule.minimumPrimarySpanMM)) / \(Int(currentRule.minimumSecondarySpanMM)) mm"
            )

            if currentRule
                .requiresMotionEnvelopeCheck {
                Label(
                    "Wymagana koperta ruchu w 2D / elewacji / 3D",
                    systemImage:
                        "scope"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if currentRule
                .requiresOpeningAngleLimiter {
                Label(
                    "Wymagany ogranicznik kąta otwarcia frontu",
                    systemImage:
                        "angle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text(
                fillerKind.productionDescription
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func applyRecommendedTechnology() {
        accessTechnology =
            CornerCabinetRuleBookV086
                .defaultAccessTechnology(
                    for: kind
                )
        applyRecommendedFiller()
    }

    private func applyRecommendedFiller() {
        let recommendedKind =
            CornerCabinetRuleBookV086
                .recommendedFillerKind(
                    kind: kind,
                    technology:
                        accessTechnology
                )
        fillerKind =
            recommendedKind
        fillerWidthMM =
            CornerCabinetRuleBookV086
                .technologyRule(
                    for: accessTechnology
                )
                .recommendedFillerWidthMM
    }
}
