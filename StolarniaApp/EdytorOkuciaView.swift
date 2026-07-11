import SwiftUI

struct EdytorOkuciaView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var draft:
        OkucieMeblowe
    @State private var pokazOdrzucenieZmian =
        false

    private let poczatkowyDraft:
        OkucieMeblowe

    let onSave:
        (OkucieMeblowe) -> Void

    init(
        item: OkucieMeblowe,
        onSave:
            @escaping
            (OkucieMeblowe) -> Void
    ) {
        _draft = State(
            initialValue: item
        )
        self.poczatkowyDraft =
            item
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Podstawowe dane") {
                    TextField(
                        "Kod / SKU",
                        text: $draft.kod
                    )

                    TextField(
                        "Nazwa",
                        text: $draft.nazwa
                    )

                    Picker(
                        "Typ",
                        selection:
                            $draft.typ
                    ) {
                        ForEach(
                            TypOkuciaMeblowego
                                .allCases
                        ) { type in
                            Label(
                                type.nazwa,
                                systemImage:
                                    type.systemImage
                            )
                            .tag(type)
                        }
                    }

                    TextField(
                        "Producent",
                        text:
                            $draft.producent
                    )

                    TextField(
                        "Dostawca",
                        text:
                            $draft.dostawca
                    )

                    TextField(
                        "System",
                        text:
                            $draft.system
                    )

                    if let profileID =
                        draft.profilAkcesoriumID {
                        LabeledContent(
                            "Profil katalogowy",
                            value: profileID
                        )
                    }
                }

                Section("Cena") {
                    Picker(
                        "Jednostka",
                        selection:
                            $draft.jednostka
                    ) {
                        ForEach(
                            JednostkaOkucia
                                .allCases
                        ) { unit in
                            Text(unit.nazwa)
                                .tag(unit)
                        }
                    }

                    numberField(
                        "Cena netto",
                        value:
                            $draft.cenaNetto,
                        suffix: "zł"
                    )

                    numberField(
                        "VAT",
                        value:
                            $draft.vatProcent,
                        suffix: "%"
                    )

                    numberField(
                        "Rabat",
                        value:
                            $draft.rabatProcent,
                        suffix: "%"
                    )

                    LabeledContent(
                        "Netto po rabacie",
                        value:
                            currency(
                                draft
                                    .cenaNettoPoRabacie
                            )
                    )

                    LabeledContent(
                        "Brutto",
                        value:
                            currency(
                                draft.cenaBrutto
                            )
                    )
                }

                Section("Parametry techniczne") {
                    numberField(
                        "Długość",
                        value:
                            $draft.dlugoscMM,
                        suffix: "mm"
                    )

                    numberField(
                        "Szerokość",
                        value:
                            $draft.szerokoscMM,
                        suffix: "mm"
                    )

                    numberField(
                        "Wysokość",
                        value:
                            $draft.wysokoscMM,
                        suffix: "mm"
                    )

                    numberField(
                        "Kąt otwarcia",
                        value:
                            $draft
                                .katOtwarciaStopnie,
                        suffix: "°"
                    )

                    numberField(
                        "Nośność",
                        value:
                            $draft.nosnoscKG,
                        suffix: "kg"
                    )

                    numberField(
                        "Płyta od",
                        value:
                            $draft
                                .gruboscPlytyOdMM,
                        suffix: "mm"
                    )

                    numberField(
                        "Płyta do",
                        value:
                            $draft
                                .gruboscPlytyDoMM,
                        suffix: "mm"
                    )
                }

                Section("Wycena i dostępność") {
                    Picker(
                        "Poziom wyceny",
                        selection:
                            $draft.poziomWyceny
                    ) {
                        ForEach(
                            PoziomWycenyOkucia
                                .allCases
                        ) { tier in
                            Text(tier.nazwa)
                                .tag(tier)
                        }
                    }

                    Toggle(
                        "Aktywne",
                        isOn:
                            $draft.aktywne
                    )
                }

                Section("Notatki") {
                    TextEditor(
                        text:
                            $draft.notatki
                    )
                    .frame(
                        minHeight: 130
                    )
                }
            }
            .stolarniaFormSurface()
            .navigationTitle(
                draft.kod
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                ? "Nowe okucie"
                : "Edytuj okucie"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button {
                        anuluj()
                    } label: {
                        Label(
                            "Anuluj",
                            systemImage:
                                "xmark"
                        )
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button {
                        draft.dataAktualizacji =
                            Date()
                        onSave(draft)
                        dismiss()
                    } label: {
                        Label(
                            "Zapisz",
                            systemImage:
                                "checkmark"
                        )
                    }
                    .disabled(
                        draft.kod
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        || draft.nazwa
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .interactiveDismissDisabled(
            maNiezapisaneZmiany
        )
        .alert(
            "Odrzucić niezapisane zmiany?",
            isPresented:
                $pokazOdrzucenieZmian
        ) {
            Button(
                "Kontynuuj edycję",
                role: .cancel
            ) {}

            Button(
                "Odrzuć zmiany",
                role: .destructive
            ) {
                dismiss()
            }
        } message: {
            Text(
                "Wprowadzone zmiany nie zostaną zapisane."
            )
        }
    }

    private var maNiezapisaneZmiany:
        Bool
    {
        draft != poczatkowyDraft
    }

    private func anuluj() {
        if maNiezapisaneZmiany {
            pokazOdrzucenieZmian =
                true
        } else {
            dismiss()
        }
    }

    private func numberField(
        _ title: String,
        value:
            Binding<Double>,
        suffix: String
    ) -> some View {
        StolarniaNumberField(
            title: title,
            value: value,
            suffix: suffix,
            width: 118
        )
    }

    private func currency(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }
}
