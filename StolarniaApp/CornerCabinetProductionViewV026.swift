import DomainCore
import SwiftUI

struct CornerCabinetProductionViewV026:
    View
{
    let assemblies:
        [FurnitureAssembly]
    let definitions:
        [CornerCabinetDefinitionV025]

    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedAssemblyID:
        FurnitureAssemblyID?

    var body: some View {
        NavigationSplitView {
            List(
                selectableDefinitions,
                selection:
                    $selectedAssemblyID
            ) { item in
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(item.label)
                        .font(.headline)

                    Text(
                        item.definition
                            .kind.title
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .tag(
                    item.definition
                        .assemblyID
                )
            }
            .navigationTitle(
                "Narożniki"
            )
        } detail: {
            if let selectedPackage {
                productionDetail(
                    selectedPackage
                )
            } else {
                ContentUnavailableView(
                    "Brak wybranego narożnika",
                    systemImage:
                        "square.split.diagonal.2x2",
                    description:
                        Text(
                            "Wybierz narożnik z listy."
                        )
                )
            }
        }
        .stolarniaReadableInterface()
            .toolbar {
            ToolbarItem(
                placement:
                    .cancellationAction
            ) {
                Button("Zamknij") {
                    dismiss()
                }
            }
        }
        .onAppear {
            if selectedAssemblyID == nil {
                selectedAssemblyID =
                    selectableDefinitions
                        .first?
                        .definition
                        .assemblyID
            }
        }
    }

    private var selectableDefinitions:
        [SelectableCornerV026]
    {
        definitions.compactMap {
            definition in

            guard let index =
                assemblies.firstIndex(
                    where: {
                        $0.id
                            == definition
                                .assemblyID
                    }
                )
            else {
                return nil
            }

            return SelectableCornerV026(
                label:
                    "M\(String(format: "%02d", index + 1))",
                definition:
                    definition,
                assembly:
                    assemblies[index]
            )
        }
    }

    private var selectedPackage:
        CornerProductionPackageV026?
    {
        guard
            let selectedAssemblyID,
            let item =
                selectableDefinitions
                    .first(
                        where: {
                            $0.definition
                                .assemblyID
                            == selectedAssemblyID
                        }
                    )
        else {
            return nil
        }

        return CornerCabinetProductionBuilderV026
            .build(
                definition:
                    item.definition,
                assembly:
                    item.assembly
            )
    }

    private func productionDetail(
        _ package:
            CornerProductionPackageV026
    ) -> some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                summaryCards(
                    package
                )

                sectionCard(
                    title:
                        "Lista elementów",
                    systemImage:
                        "list.bullet.rectangle"
                ) {
                    ForEach(
                        package.parts
                    ) { part in
                        partRow(part)
                        Divider()
                    }
                }

                sectionCard(
                    title: "Okucia",
                    systemImage:
                        "wrench.and.screwdriver"
                ) {
                    ForEach(
                        package.hardware
                    ) { item in
                        HStack {
                            VStack(
                                alignment:
                                    .leading,
                                spacing: 3
                            ) {
                                Text(
                                    item.name
                                )
                                .font(
                                    .headline
                                )

                                if !item.note
                                    .isEmpty {
                                    Text(
                                        item.note
                                    )
                                    .font(
                                        .caption
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }
                            }

                            Spacer()

                            Text(
                                "\(item.quantity) szt."
                            )
                            .font(
                                .headline
                                    .monospacedDigit()
                            )
                        }
                        .padding(
                            .vertical,
                            4
                        )

                        Divider()
                    }
                }

                if !package.notes.isEmpty {
                    sectionCard(
                        title: "Uwagi",
                        systemImage:
                            "exclamationmark.bubble"
                    ) {
                        ForEach(
                            package.notes,
                            id: \.self
                        ) {
                            Label(
                                $0,
                                systemImage:
                                    "info.circle"
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(
            "Dokumentacja produkcyjna"
        )
    }

    private func summaryCards(
        _ package:
            CornerProductionPackageV026
    ) -> some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Elementy",
                value:
                    "\(package.totalPartCount)",
                systemImage:
                    "square.stack.3d.up"
            )

            summaryCard(
                title: "Powierzchnia płyt",
                value:
                    package
                        .totalBoardAreaSquareMeters
                        .formatted(
                            .number
                                .precision(
                                    .fractionLength(
                                        2
                                    )
                                )
                        )
                    + " m²",
                systemImage:
                    "rectangle.3.group"
            )

            summaryCard(
                title: "Pozycje okuć",
                value:
                    "\(package.hardware.count)",
                systemImage:
                    "wrench.and.screwdriver"
            )
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Label(
                title,
                systemImage:
                    systemImage
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            Text(value)
                .font(
                    .title2
                        .bold()
                )
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemBackground
                )
            )
        )
    }

    private func sectionCard<
        Content: View
    >(
        title: String,
        systemImage: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Label(
                title,
                systemImage:
                    systemImage
            )
            .font(.title3.bold())

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemBackground
                )
            )
        )
    }

    private func partRow(
        _ part:
            CornerProductionPartV026
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(part.name)
                    .font(.headline)

                Text(
                    "\(Int(part.lengthMM.rounded())) × \(Int(part.widthMM.rounded())) × \(Int(part.thicknessMM.rounded())) mm"
                )
                .font(
                    .callout
                        .monospacedDigit()
                )

                Text(
                    part.material.title
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                if !part.edgeBanding
                    .isEmpty {
                    Text(
                        "Obrzeże: "
                        + part.edgeBanding
                            .map(\.title)
                            .sorted()
                            .joined(
                                separator: ", "
                            )
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                if !part.note.isEmpty {
                    Text(part.note)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Spacer()

            Text(
                "\(part.quantity) szt."
            )
            .font(
                .headline
                    .monospacedDigit()
            )
        }
        .padding(.vertical, 4)
    }
}

private struct SelectableCornerV026:
    Identifiable
{
    let label: String
    let definition:
        CornerCabinetDefinitionV025
    let assembly:
        FurnitureAssembly

    var id:
        FurnitureAssemblyID
    {
        definition.assemblyID
    }
}
