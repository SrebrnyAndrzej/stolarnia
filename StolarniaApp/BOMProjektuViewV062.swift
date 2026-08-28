import SwiftUI

struct BOMProjektuViewV062: View {
    @Environment(\.dismiss) private var dismiss

    let bom: BOMProjektuV062
    var onPrzejdzDoPlanuV0108: (() -> Void)?

    @State private var exportURL: URL?
    @State private var exportError: String?

    private let categoryOrder: [KategoriaKosztuWyceny] = [
        .plyty, .fronty, .blaty, .okucia, .akcesoria,
        .oswietlenie, .robocizna, .montaz, .transport, .pozostale
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Projekt", value: bom.nazwaProjektu)
                    LabeledContent("Wariant", value: bom.wariant.nazwa)
                    LabeledContent(
                        "Koszt bazowy netto",
                        value: money(bom.kosztNetto)
                    )
                } header: {
                    Text("Podsumowanie")
                }

                if bom.grupy.values.allSatisfy(\.isEmpty) {
                    Section {
                        StolarniaEmptyState(
                            title: "Pusty BOM",
                            description: "Bill of Materials generowany jest z modułów i wybranego wariantu wyceny. Dodaj moduły w Planie 2D i uzupełnij wycenę, żeby zobaczyć szczegółowe zestawienie płyt, frontów, okuć i akcesoriów.",
                            systemImage: "list.bullet.clipboard",
                            actionTitle: "Przejdź do Planu 2D",
                            actionSystemImage: "square.grid.2x2",
                            action: onPrzejdzDoPlanuV0108
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                ForEach(categoryOrder, id: \.self) { category in
                    if let items = bom.grupy[category], !items.isEmpty {
                        Section {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.nazwa)
                                            .font(.headline)
                                        Spacer()
                                        Text(money(item.kosztNetto))
                                            .font(.headline.monospacedDigit())
                                    }

                                    Text(
                                        "\(item.ilosc.formatted()) \(item.jednostka) × \(money(item.cenaJednostkowaNetto))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    if !item.zrodlo.isEmpty {
                                        Text(item.zrodlo)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                        } header: {
                            HStack {
                                Text(category.nazwa)
                                Spacer()
                                Text(money(items.reduce(0) { $0 + $1.kosztNetto }))
                            }
                        }
                    }
                }
            }
            .navigationTitle("BOM projektu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Eksport CSV", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            prepareExport()
                        } label: {
                            Label("Przygotuj CSV", systemImage: "tablecells")
                        }
                    }
                }
            }
            .alert(
                "Nie udało się przygotować CSV",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .task {
                prepareExport()
            }
        }
    }

    private func prepareExport() {
        do {
            exportURL = try BOMProjektuCSVV062.makeFile(for: bom)
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "PLN"))
    }
}
