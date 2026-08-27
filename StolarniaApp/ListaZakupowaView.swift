import SwiftUI

struct ListaZakupowaView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var list:
        ListaZakupowaProjektu

    @State private var exportedFile:
        ExportedPurchaseList?

    @State private var errorMessage:
        String?

    init(
        list:
            ListaZakupowaProjektu
    ) {
        _list = State(
            initialValue: list
        )
    }

    private var categories:
        [KategoriaKosztuWyceny]
    {
        KategoriaKosztuWyceny
            .allCases
            .filter {
                category in

                list.pozycje.contains {
                    $0.kategoria
                        == category
                }
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StolarniaSectionIntro(
                        title:
                            "Lista zakupowa",
                        description:
                            "\(list.nazwaProjektu) • \(list.wariant.nazwa). Odznacz pozycje, których nie chcesz umieszczać w eksporcie.",
                        systemImage:
                            "cart.fill"
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                }

                if list.pozycje.isEmpty {
                    Section {
                        StolarniaEmptyState(
                            title: "Brak pozycji do zakupu",
                            description: "Lista zakupowa generowana jest z materiałów, okuć i akcesoriów użytych w projekcie. Dodaj moduły w Planie 2D i wybierz wariant wyceny, żeby zobaczyć tutaj skonsolidowaną listę do zakupu.",
                            systemImage: "cart.badge.plus"
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                ForEach(
                    categories
                ) { category in
                    Section(
                        category.nazwa
                    ) {
                        ForEach(
                            indices(
                                for: category
                            ),
                            id: \.self
                        ) { index in
                            itemRow(
                                index: index
                            )
                        }
                    }
                }

                Section("Podsumowanie") {
                    LabeledContent(
                        "Pozycje w eksporcie",
                        value:
                            String(
                                list
                                    .aktywnePozycje
                                    .count
                            )
                    )

                    LabeledContent(
                        "Suma netto",
                        value:
                            list.sumaNetto
                                .formatted(
                                    .currency(
                                        code: "PLN"
                                    )
                                )
                    )
                }
            }
            .navigationTitle(
                "Lista zakupowa"
            )
            .stolarniaScreenSurface(
                .detail
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

                ToolbarItem(
                    placement:
                        .primaryAction
                ) {
                    Button {
                        export()
                    } label: {
                        Label(
                            "Eksportuj CSV",
                            systemImage:
                                "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        list
                            .aktywnePozycje
                            .isEmpty
                    )
                }
            }
            .sheet(
                item: $exportedFile
            ) { file in
                exportSheet(file)
            }
            .alert(
                "Nie udało się wyeksportować listy",
                isPresented:
                    Binding(
                        get: {
                            errorMessage != nil
                        },
                        set: { visible in
                            if !visible {
                                errorMessage = nil
                            }
                        }
                    )
            ) {
                Button(
                    "OK",
                    role: .cancel
                ) {
                    errorMessage = nil
                }
            } message: {
                Text(
                    errorMessage
                    ?? "Nieznany błąd"
                )
            }
        }
    }

    private func indices(
        for category:
            KategoriaKosztuWyceny
    ) -> [Int] {
        list.pozycje.indices.filter {
            list.pozycje[$0]
                .kategoria
                == category
        }
    }

    private func itemRow(
        index: Int
    ) -> some View {
        Toggle(
            isOn:
                $list.pozycje[index]
                    .uwzgledniona
        ) {
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                Image(
                    systemName:
                        icon(
                            for:
                                list
                                    .pozycje[index]
                                    .kategoria
                        )
                )
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(
                    width: 30,
                    height: 30
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        list
                            .pozycje[index]
                            .nazwa
                    )
                    .font(.headline)

                    Text(
                        quantityText(
                            list.pozycje[index]
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )

                    if !list
                        .pozycje[index]
                        .uwagi
                        .isEmpty {
                        Text(
                            list
                                .pozycje[index]
                                .uwagi
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Spacer()

                Text(
                    list
                        .pozycje[index]
                        .kosztNetto
                        .formatted(
                            .currency(
                                code: "PLN"
                            )
                        )
                )
                .font(
                    .headline
                        .monospacedDigit()
                )
            }
            .padding(
                .vertical,
                5
            )
        }
        .toggleStyle(.switch)
    }

    private func export() {
        do {
            let url =
                try ListaZakupowaCSVExporter
                    .export(list)

            exportedFile =
                ExportedPurchaseList(
                    url: url
                )
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func exportSheet(
        _ file:
            ExportedPurchaseList
    ) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(
                    systemName:
                        "tablecells.fill"
                )
                .font(
                    .system(
                        size: 68
                    )
                )
                .foregroundStyle(.tint)

                Text(
                    "Lista zakupowa jest gotowa"
                )
                .font(.title.bold())

                Text(
                    file.url
                        .lastPathComponent
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )

                ShareLink(
                    item: file.url,
                    preview:
                        SharePreview(
                            "Lista zakupowa",
                            image:
                                Image(
                                    systemName:
                                        "cart"
                                )
                        )
                ) {
                    Label(
                        "Udostępnij lub zapisz CSV",
                        systemImage:
                            "square.and.arrow.up"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)

                Spacer()
            }
            .padding(28)
            .navigationTitle(
                "Eksport CSV"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        exportedFile = nil
                    }
                }
            }
        }
    }

    private func quantityText(
        _ item:
            PozycjaListyZakupowej
    ) -> String {
        "\(item.ilosc.formatted(.number.precision(.fractionLength(0...2)))) \(item.jednostka) × \(item.cenaJednostkowaNetto.formatted(.currency(code: "PLN")))"
    }

    private func icon(
        for category:
            KategoriaKosztuWyceny
    ) -> String {
        switch category {
        case .plyty:
            return "square.stack.3d.up"
        case .fronty:
            return "rectangle.split.2x1"
        case .blaty:
            return "rectangle"
        case .okucia:
            return "shippingbox"
        case .akcesoria:
            return "wrench.and.screwdriver"
        case .oswietlenie:
            return "lightbulb"
        case .pozostale:
            return "ellipsis.circle"
        case .robocizna:
            return "hammer"
        case .montaz:
            return "person.2"
        case .transport:
            return "truck.box"
        }
    }
}

private struct ExportedPurchaseList:
    Identifiable
{
    let id = UUID()
    let url: URL
}
