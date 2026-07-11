import DomainCore
import SwiftUI

struct ProductionExportViewV027:
    View
{
    let projectName: String
    let assemblies:
        [FurnitureAssembly]
    let definitions:
        [CornerCabinetDefinitionV025]

    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedFormat:
        ProductionExportFormatV027 = .pdf
    @State private var result:
        ProductionExportResultV027?
    @State private var errorMessage: String?
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker(
                        "Format eksportu",
                        selection:
                            $selectedFormat
                    ) {
                        ForEach(
                            ProductionExportFormatV027
                                .allCases
                        ) { format in
                            Label(
                                format.title,
                                systemImage:
                                    format.systemImage
                            )
                            .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Zakres") {
                    LabeledContent(
                        "Projekt",
                        value: projectName
                    )

                    LabeledContent(
                        "Narożniki",
                        value:
                            "\(packages.count)"
                    )

                    LabeledContent(
                        "Elementy",
                        value:
                            "\(totalPartCount)"
                    )

                    LabeledContent(
                        "Powierzchnia płyt",
                        value:
                            totalArea.formatted(
                                .number.precision(
                                    .fractionLength(2)
                                )
                            )
                            + " m²"
                    )
                }

                Section("Eksport") {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            Label(
                                "Generuj \(selectedFormat.title)",
                                systemImage:
                                    selectedFormat
                                        .systemImage
                            )

                            Spacer()

                            if isGenerating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(
                        packages.isEmpty
                        || isGenerating
                    )

                    if let result {
                        ShareLink(
                            item: result.url
                        ) {
                            Label(
                                "Udostępnij \(result.format.title)",
                                systemImage:
                                    "square.and.arrow.up"
                            )
                        }

                        LabeledContent(
                            "Plik",
                            value:
                                result.url
                                    .lastPathComponent
                        )
                    }
                }

                if let errorMessage {
                    Section("Błąd") {
                        Label(
                            errorMessage,
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(
                "Eksport produkcji"
            )
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
        }
    }

    private var packages:
        [CornerProductionPackageV026]
    {
        definitions.compactMap {
            definition in

            guard let assembly =
                assemblies.first(
                    where: {
                        $0.id
                        == definition
                            .assemblyID
                    }
                )
            else {
                return nil
            }

            return CornerCabinetProductionBuilderV026
                .build(
                    definition:
                        definition,
                    assembly:
                        assembly
                )
        }
    }

    private var totalPartCount: Int {
        packages.reduce(0) {
            $0 + $1.totalPartCount
        }
    }

    private var totalArea: Double {
        packages.reduce(0) {
            $0
            + $1.totalBoardAreaSquareMeters
        }
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        result = nil

        do {
            result =
                try ProductionExportServiceV027
                    .export(
                        packages: packages,
                        format:
                            selectedFormat,
                        projectName:
                            projectName
                    )
        } catch {
            errorMessage =
                error.localizedDescription
        }

        isGenerating = false
    }
}
