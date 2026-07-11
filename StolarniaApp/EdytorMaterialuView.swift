import SwiftUI

struct EdytorMaterialuView:
    View
{
    let materialPoczatkowy:
        MaterialStolarski?
    let onSave:
        (MaterialStolarski) -> Void

    private let poczatkowyDraft:
        MaterialStolarski

    @Environment(\.dismiss)
    private var dismiss

    @State private var draft:
        MaterialStolarski
    @State private var pokazOdrzucenieZmian =
        false

    init(
        material:
            MaterialStolarski?,
        onSave:
            @escaping (
                MaterialStolarski
            ) -> Void
    ) {
        let initial =
            material
            ?? MaterialStolarski(
                kod: "",
                nazwa: "",
                producent: "",
                dostawca: "",
                typ:
                    .plytaLaminowana,
                dekor: "",
                gruboscMM: 18,
                szerokoscArkuszaMM: 2800,
                wysokoscArkuszaMM: 2070,
                jednostka: .sztuka,
                cenaNetto: 0,
                vatProcent: 23,
                rabatProcent: 0,
                kierunekDekoru: false,
                kolorHEX: "#CCCCCC",
                notatki: ""
            )

        self.materialPoczatkowy =
            material
        self.onSave = onSave
        self.poczatkowyDraft =
            initial
        _draft = State(
            initialValue: initial
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identyfikacja") {
                    TextField(
                        "Kod / SKU",
                        text: $draft.kod
                    )

                    TextField(
                        "Nazwa",
                        text: $draft.nazwa
                    )

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

                    Picker(
                        "Typ",
                        selection:
                            $draft.typ
                    ) {
                        ForEach(
                            TypMaterialuStolarskiego
                                .allCases
                        ) {
                            Text($0.nazwa)
                                .tag($0)
                        }
                    }
                }

                Section("Katalog producenta") {
                    TextField(
                        "Kolekcja",
                        text:
                            opcjonalnyTekst(
                                \.kolekcja
                            )
                    )

                    TextField(
                        "Kod producenta",
                        text:
                            opcjonalnyTekst(
                                \.kodProducenta
                            )
                    )

                    TextField(
                        "Struktura",
                        text:
                            opcjonalnyTekst(
                                \.struktura
                            )
                    )

                    TextField(
                        "Grupa dekoru",
                        text:
                            opcjonalnyTekst(
                                \.grupaDekoru
                            )
                    )

                    if let priceID =
                        draft
                            .cenaReferencyjnaPlytyID {
                        LabeledContent(
                            "Grupa cennika płyt",
                            value: priceID
                        )
                    }

                    if let profileID =
                        draft.profilAkcesoriumID {
                        LabeledContent(
                            "Profil okuć",
                            value: profileID
                        )
                    }
                }

                Section("Parametry") {
                    TextField(
                        "Dekor",
                        text: $draft.dekor
                    )

                    poleLiczbowe(
                        "Grubość",
                        value:
                            $draft.gruboscMM,
                        suffix: "mm"
                    )

                    poleLiczbowe(
                        "Szerokość arkusza",
                        value:
                            $draft
                                .szerokoscArkuszaMM,
                        suffix: "mm"
                    )

                    poleLiczbowe(
                        "Wysokość arkusza",
                        value:
                            $draft
                                .wysokoscArkuszaMM,
                        suffix: "mm"
                    )

                    Toggle(
                        "Kierunek dekoru",
                        isOn:
                            $draft
                                .kierunekDekoru
                    )

                    TextField(
                        "Kolor HEX",
                        text:
                            $draft.kolorHEX
                    )
                    .textInputAutocapitalization(
                        .characters
                    )
                }

                Section("Cena") {
                    Picker(
                        "Jednostka",
                        selection:
                            $draft.jednostka
                    ) {
                        ForEach(
                            JednostkaCenyMaterialu
                                .allCases
                        ) {
                            Text($0.skrot)
                                .tag($0)
                        }
                    }

                    poleLiczbowe(
                        "Cena netto",
                        value:
                            $draft
                                .cenaNetto,
                        suffix: "zł"
                    )

                    poleLiczbowe(
                        "VAT",
                        value:
                            $draft
                                .vatProcent,
                        suffix: "%"
                    )

                    poleLiczbowe(
                        "Rabat",
                        value:
                            $draft
                                .rabatProcent,
                        suffix: "%"
                    )

                    LabeledContent(
                        "Cena po rabacie",
                        value:
                            draft
                                .cenaPoRabacieNetto
                                .formatted(
                                    .currency(
                                        code: "PLN"
                                    )
                                )
                    )

                    if let cenaM2 =
                        draft.cenaZaM2Netto {
                        LabeledContent(
                            "Cena netto za m²",
                            value:
                                cenaM2.formatted(
                                    .currency(
                                        code: "PLN"
                                    )
                                )
                        )
                    }

                    if let reference =
                        draft
                            .cenaRynkowaPlyty {
                        Divider()

                        LabeledContent(
                            "Średnia rynkowa brutto",
                            value:
                                reference
                                    .cenaSredniaBruttoPLN
                                    .formatted(
                                        .currency(
                                            code: "PLN"
                                        )
                                    )
                        )

                        LabeledContent(
                            "Zakres brutto",
                            value:
                                "\(reference.cenaMinimalnaBruttoPLN.formatted(.currency(code: "PLN"))) – \(reference.cenaMaksymalnaBruttoPLN.formatted(.currency(code: "PLN")))"
                        )

                        LabeledContent(
                            "Reprezentant",
                            value:
                                "\(reference.kodProducenta) \(reference.struktura)"
                        )

                        Button {
                            draft.cenaNetto =
                                reference
                                    .cenaSredniaNettoPLN
                            draft.vatProcent = 23
                            draft.jednostka =
                                .sztuka
                        } label: {
                            Label(
                                "Ustaw średnią jako cenę netto",
                                systemImage:
                                    "arrow.down.to.line"
                            )
                        }

                        Text(
                            draft
                                .cenaRynkowaPlytyJestDokladna
                            ? "Cena referencyjna dotyczy tego samego kodu i struktury."
                            : "Cena pochodzi z reprezentanta grupy dekorów. Zawsze sprawdź cenę konkretnej płyty u dostawcy."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Section("Status") {
                    Toggle(
                        "Aktywny",
                        isOn:
                            $draft.aktywny
                    )

                    TextField(
                        "Notatki",
                        text:
                            $draft.notatki,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }
            }
            .stolarniaFormSurface()
            .navigationTitle(
                materialPoczatkowy == nil
                ? "Nowy materiał"
                : "Edytuj materiał"
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
                    .buttonStyle(
                        .borderedProminent
                    )
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

    private func opcjonalnyTekst(
        _ keyPath:
            WritableKeyPath<
                MaterialStolarski,
                String?
            >
    ) -> Binding<String> {
        Binding(
            get: {
                draft[keyPath: keyPath]
                ?? ""
            },
            set: { value in
                let trimmed =
                    value.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                draft[keyPath: keyPath] =
                    trimmed.isEmpty
                    ? nil
                    : value
            }
        )
    }

    private func poleLiczbowe(
        _ title: String,
        value:
            Binding<Double>,
        suffix: String
    ) -> some View {
        StolarniaNumberField(
            title: title,
            value: value,
            suffix: suffix,
            width: 132
        )
    }
}
