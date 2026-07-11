import SwiftUI

struct SzablonyWiercenOkucView:
    View
{
    @StateObject private var repository =
        SzablonyWiercenOkucRepository()

    @State private var editedTemplate:
        SzablonWierceniaOkucia?

    @State private var pendingDelete:
        SzablonWierceniaOkucia?

    @State private var showingDeleteAlert =
        false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StolarniaSectionIntro(
                        title:
                            "Szablony wierceń okuć",
                        description:
                            "Zapisuj rozstawy otworów dla prowadnic, zawiasów i podpór półek.",
                        systemImage:
                            "scope"
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                }

                ForEach(
                    repository.templates
                ) { template in
                    Button {
                        editedTemplate =
                            template
                    } label: {
                        VStack(
                            alignment: .leading,
                            spacing: 5
                        ) {
                            HStack {
                                Text(
                                    template.nazwa
                                )
                                .font(.headline)

                                Spacer()

                                Text(
                                    template.kodOkucia
                                )
                                .font(
                                    .caption
                                        .monospaced()
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                            Text(
                                "\(template.typ.nazwa) • \(template.punkty.count) punktów"
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(
                            "Usuń",
                            role: .destructive
                        ) {
                            pendingDelete =
                                template
                            showingDeleteAlert =
                                true
                        }
                    }
                }
            }
            .navigationTitle(
                "Szablony wierceń"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .primaryAction
                ) {
                    Button {
                        editedTemplate =
                            SzablonWierceniaOkucia(
                                nazwa:
                                    "Nowy szablon"
                            )
                    } label: {
                        Label(
                            "Dodaj szablon",
                            systemImage: "plus"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
            .sheet(
                item:
                    $editedTemplate
            ) { template in
                SzablonWierceniaOkuciaEditorView(
                    template:
                        template
                ) {
                    repository.upsert($0)
                }
            }
            .alert(
                "Usunąć szablon?",
                isPresented:
                    $showingDeleteAlert
            ) {
                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    if let pendingDelete {
                        repository.delete(
                            id:
                                pendingDelete.id
                        )
                    }

                    pendingDelete = nil
                }

                Button(
                    "Anuluj",
                    role: .cancel
                ) {
                    pendingDelete = nil
                }
            }
        }
    }
}

private struct SzablonWierceniaOkuciaEditorView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var draft:
        SzablonWierceniaOkucia

    let onSave:
        (SzablonWierceniaOkucia)
        -> Void

    init(
        template:
            SzablonWierceniaOkucia,
        onSave:
            @escaping
            (SzablonWierceniaOkucia)
            -> Void
    ) {
        _draft = State(
            initialValue: template
        )

        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Okucie") {
                    TextField(
                        "Kod okucia",
                        text:
                            $draft.kodOkucia
                    )

                    TextField(
                        "Nazwa",
                        text:
                            $draft.nazwa
                    )

                    TextField(
                        "Producent",
                        text:
                            $draft.producent
                    )

                    Picker(
                        "Typ",
                        selection:
                            $draft.typ
                    ) {
                        ForEach(
                            TypPunktuWiercenia
                                .allCases
                        ) { type in
                            Text(type.nazwa)
                                .tag(type)
                        }
                    }

                    TextField(
                        "Element docelowy",
                        text:
                            $draft
                                .elementDocelowy
                    )
                }

                Section("Punkt bazowy") {
                    numberField(
                        "X",
                        value:
                            $draft
                                .punktBazowyXMM
                    )

                    numberField(
                        "Y",
                        value:
                            $draft
                                .punktBazowyYMM
                    )

                    Picker(
                        "Orientacja",
                        selection:
                            $draft.orientacja
                    ) {
                        ForEach(
                            OrientacjaSzablonuWiercenia
                                .allCases
                        ) { orientation in
                            Text(
                                orientation.nazwa
                            )
                            .tag(orientation)
                        }
                    }

                    Picker(
                        "Strona",
                        selection:
                            $draft.strona
                    ) {
                        ForEach(
                            StronaElementuTechnicznego
                                .allCases
                        ) { side in
                            Text(side.nazwa)
                                .tag(side)
                        }
                    }
                }

                Section("Punkty") {
                    ForEach(
                        $draft.punkty
                    ) { $point in
                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            HStack {
                                numberField(
                                    "ΔX",
                                    value:
                                        $point
                                            .odsunXMM
                                )

                                numberField(
                                    "ΔY",
                                    value:
                                        $point
                                            .odsunYMM
                                )
                            }

                            HStack {
                                numberField(
                                    "Ø",
                                    value:
                                        $point
                                            .srednicaMM
                                )

                                numberField(
                                    "Gł.",
                                    value:
                                        $point
                                            .glebokoscMM
                                )
                            }

                            TextField(
                                "Opis",
                                text:
                                    $point.opis,
                                axis: .vertical
                            )
                        }
                    }
                    .onDelete {
                        draft.punkty
                            .remove(
                                atOffsets: $0
                            )
                    }

                    Button {
                        draft.punkty
                            .append(
                                PunktSzablonuWiercenia()
                            )
                    } label: {
                        Label(
                            "Dodaj punkt",
                            systemImage: "plus"
                        )
                    }
                }

                Section("Uwagi") {
                    Toggle(
                        "Aktywny",
                        isOn:
                            $draft.aktywny
                    )

                    TextEditor(
                        text:
                            $draft.uwagi
                    )
                    .frame(
                        minHeight: 100
                    )
                }
            }
            .navigationTitle(
                draft.nazwa
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
                    Button("Zapisz") {
                        onSave(draft)
                        dismiss()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
    }

    private func numberField(
        _ title: String,
        value:
            Binding<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value: value,
                format:
                    .number.precision(
                        .fractionLength(
                            0...1
                        )
                    )
            )
            .keyboardType(
                .decimalPad
            )
            .multilineTextAlignment(
                .trailing
            )
            .frame(width: 80)

            Text("mm")
                .foregroundStyle(
                    .secondary
                )
        }
    }
}
