import SwiftUI

struct GlobalnaZmianaMaterialowView: View {
    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var repository:
        GlobalneMaterialyPomieszczeniaRepository

    @StateObject private var bazaMaterialow =
        BazaMaterialowRepository()

    @State private var korpusID: UUID?
    @State private var frontID: UUID?
    @State private var wyszukiwanie = ""
    @State private var filtrProducenta: String?

    let onApply:
        (GlobalneMaterialyPomieszczenia) -> Void

    init(
        repository:
            GlobalneMaterialyPomieszczeniaRepository,
        onApply:
            @escaping
            (GlobalneMaterialyPomieszczenia) -> Void
    ) {
        self.repository = repository
        self.onApply = onApply
        _korpusID = State(
            initialValue:
                repository.ustawienia.korpus.id
        )
        _frontID = State(
            initialValue:
                repository.ustawienia.front.id
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(
                        "Producent",
                        selection: $filtrProducenta
                    ) {
                        Text("Wszyscy producenci")
                            .tag(Optional<String>.none)

                        ForEach(producenci, id: \.self) {
                            Text($0)
                                .tag(Optional($0))
                        }
                    }
                } header: {
                    Text("Wzornik")
                } footer: {
                    Text(
                        "Kolor na ekranie jest podglądem. Do zatwierdzenia zamówienia użyj fizycznego wzornika producenta."
                    )
                }

                wyborMaterialu(
                    title: "Korpusy",
                    systemImage: "shippingbox",
                    selection: $korpusID,
                    current: repository.ustawienia.korpus
                )

                wyborMaterialu(
                    title: "Fronty",
                    systemImage: "door.left.hand.closed",
                    selection: $frontID,
                    current: repository.ustawienia.front
                )

                Section("Zakres zmiany") {
                    Label(
                        "Wszystkie moduły w bieżącym pomieszczeniu",
                        systemImage: "square.grid.3x3"
                    )
                    Label(
                        "Plan 2D, elewacje, podgląd 3D i karty techniczne",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            }
            .searchable(
                text: $wyszukiwanie,
                prompt: "Kod, dekor, kolekcja lub producent"
            )
            .navigationTitle(
                "Globalne materiały"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Zastosuj") {
                        zastosuj()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func wyborMaterialu(
        title: String,
        systemImage: String,
        selection: Binding<UUID?>,
        current: MigawkaMaterialuGlobalnego
    ) -> some View {
        Section {
            ForEach(filtrowaneMaterialy) {
                material in

                Button {
                    selection.wrappedValue =
                        material.id
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(
                            cornerRadius: 8
                        )
                        .fill(
                            Color(
                                stolarniaHEX:
                                    material.kolorHEX
                            )
                        )
                        .frame(
                            width: 42,
                            height: 42
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 8
                            )
                            .stroke(
                                .secondary.opacity(
                                    0.25
                                )
                            )
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text(material.nazwa)
                                .foregroundStyle(
                                    .primary
                                )

                            Text(
                                [
                                    material.producent,
                                    material.kodProducenta
                                        ?? material.kod,
                                    material.struktura
                                        ?? ""
                                ]
                                .filter {
                                    !$0.isEmpty
                                }
                                .joined(
                                    separator: " • "
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Spacer()

                        if czyWybrany(
                            material,
                            selectionID:
                                selection
                                .wrappedValue,
                            current:
                                current
                        ) {
                            Image(
                                systemName:
                                    "checkmark.circle.fill"
                            )
                            .foregroundStyle(
                                .tint
                            )
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if filtrowaneMaterialy.isEmpty {
                ContentUnavailableView(
                    "Brak materiałów",
                    systemImage:
                        "square.grid.2x2",
                    description:
                        Text(
                            "Zmień filtr lub uzupełnij Bazę materiałów w Panelu firmy."
                        )
                )
            }
        } header: {
            Label(
                title,
                systemImage:
                    systemImage
            )
        } footer: {
            let selected =
                materialDlaWyboru(
                    for:
                        selection
                        .wrappedValue,
                    current:
                        current
                )

            Text(
                selected.map {
                    "Wybrano: \($0.producent) \($0.nazwa)"
                }
                ?? "Bieżące ustawienie: \(current.producent) \(current.nazwa)"
            )
        }
    }

    private var materialyPlytowe:
        [MaterialStolarski]
    {
        bazaMaterialow.materialy.filter {
            $0.aktywny
            && (
                $0.typ
                    == .plytaLaminowana
                || $0.typ == .mdf
                || $0.typ == .front
            )
        }
    }

    private var producenci: [String] {
        Array(
            Set(
                materialyPlytowe
                    .map(\.producent)
                    .filter {
                        !$0.isEmpty
                    }
            )
        )
        .sorted {
            $0.localizedCaseInsensitiveCompare(
                $1
            )
            == .orderedAscending
        }
    }

    private var filtrowaneMaterialy:
        [MaterialStolarski]
    {
        materialyPlytowe.filter {
            material in

            if let filtrProducenta,
               material.producent
                .caseInsensitiveCompare(
                    filtrProducenta
                )
                != .orderedSame {
                return false
            }

            let query =
                wyszukiwanie
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard !query.isEmpty else {
                return true
            }

            return [
                material.kod,
                material.kodProducenta ?? "",
                material.nazwa,
                material.dekor,
                material.producent,
                material.kolekcja ?? "",
                material.struktura ?? ""
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(
                query
            )
        }
        .sorted {
            if $0.producent != $1.producent {
                return $0.producent
                    .localizedCaseInsensitiveCompare(
                        $1.producent
                    )
                    == .orderedAscending
            }
            return $0.nazwa
                .localizedCaseInsensitiveCompare(
                    $1.nazwa
                )
                == .orderedAscending
        }
    }

    private var wybranyKorpus:
        MaterialStolarski?
    {
        materialDlaWyboru(
            for: korpusID,
            current:
                repository
                .ustawienia
                .korpus
        )
    }

    private var wybranyFront:
        MaterialStolarski?
    {
        materialDlaWyboru(
            for: frontID,
            current:
                repository
                .ustawienia
                .front
        )
    }

    private func zastosuj() {
        let korpus =
            wybranyKorpus
                .map {
                    MigawkaMaterialuGlobalnego(
                        material: $0
                    )
                }
            ?? repository
                .ustawienia
                .korpus
        let front =
            wybranyFront
                .map {
                    MigawkaMaterialuGlobalnego(
                        material: $0
                    )
                }
            ?? repository
                .ustawienia
                .front

        repository.zapisz(
            korpus: korpus,
            front: front
        )
        onApply(repository.ustawienia)
        dismiss()
    }

    private func materialDlaWyboru(
        for id: UUID?,
        current:
            MigawkaMaterialuGlobalnego
    ) -> MaterialStolarski? {
        if let id,
           let byID =
            bazaMaterialow
                .materialy
                .first(where: {
                    $0.id == id
                }) {
            return byID
        }

        return bazaMaterialow
            .materialy
            .first {
                pasuje(
                    $0,
                    do:
                        current
                )
            }
    }

    private func czyWybrany(
        _ material:
            MaterialStolarski,
        selectionID: UUID?,
        current:
            MigawkaMaterialuGlobalnego
    ) -> Bool {
        if selectionID == material.id {
            return true
        }

        guard selectionID == nil
                || materialDlaWyboru(
                    for: selectionID,
                    current:
                        current
                ) == nil
        else {
            return false
        }

        return pasuje(
            material,
            do: current
        )
    }

    private func pasuje(
        _ material:
            MaterialStolarski,
        do snapshot:
            MigawkaMaterialuGlobalnego
    ) -> Bool {
        let kod =
            material
                .kodProducenta
            ?? material.kod

        return znormalizowany(kod)
            == znormalizowany(snapshot.kod)
            && znormalizowany(material.nazwa)
                == znormalizowany(snapshot.nazwa)
            && znormalizowany(material.producent)
                == znormalizowany(snapshot.producent)
    }

    private func znormalizowany(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .lowercased()
    }
}
