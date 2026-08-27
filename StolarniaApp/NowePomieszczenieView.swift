import DomainCore
import SwiftUI

struct NowePomieszczenieView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var width = 4_000.0
    @State private var depth = 3_000.0
    @State private var wallHeight = 2_600.0
    @State private var wallThickness = 120.0
    @State private var constructionType: ConstructionType = .masonry
    @State private var isSaving = false

    let onCreate: (
        _ name: String,
        _ width: Double,
        _ depth: Double,
        _ wallHeight: Double,
        _ wallThickness: Double,
        _ constructionType: ConstructionType
    ) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Pomieszczenie") {
                    TextField("Nazwa, np. Kuchnia", text: $name)

                    Picker("Konstrukcja ścian", selection: $constructionType) {
                        ForEach(ConstructionType.allCases, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                }

                Section("Wymiary wewnętrzne") {
                    dimensionField(
                        title: "Szerokość",
                        value: $width
                    )

                    dimensionField(
                        title: "Głębokość",
                        value: $depth
                    )

                    dimensionField(
                        title: "Wysokość ścian",
                        value: $wallHeight
                    )

                    dimensionField(
                        title: "Grubość ścian",
                        value: $wallThickness
                    )
                }

                Section {
                    Text(
                        "Ten tryb tworzy tylko szybki prostokąt. "
                        + "Dla wnęk, wykuszy, uskoków i nieregularnych kształtów wróć do wyboru trybu i użyj pomiaru prowadzonego po obrysie."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nowe pomieszczenie")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Utwórz") {
                        isSaving = true

                        Task {
                            let didCreate = await onCreate(
                                name,
                                width,
                                depth,
                                wallHeight,
                                wallThickness,
                                constructionType
                            )

                            isSaving = false

                            if didCreate {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .help("Utwórz pomieszczenie (⌘Return)")
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Zapisywanie…")
                        .padding()
                        .stolarniaMaterial(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
            }
        }
    }

    private func dimensionField(
        title: String,
        value: Binding<Double>
    ) -> some View {
        HStack {
            Text(title)

            Spacer()

            TextField(
                title,
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 140)

            Text("mm")
                .foregroundStyle(.secondary)
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && width > 0
            && depth > 0
            && wallHeight > 0
            && wallThickness > 0
    }
}
