import SwiftUI

struct System32EditorView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    let element:
        ElementTechnicznySzafki

    @State private var parameters:
        ParametrySystemu32

    let onApply:
        (
            ParametrySystemu32,
            [PunktWierceniaSzafki]
        ) -> Void

    init(
        element:
            ElementTechnicznySzafki,
        parameters:
            ParametrySystemu32,
        onApply:
            @escaping
            (
                ParametrySystemu32,
                [PunktWierceniaSzafki]
            ) -> Void
    ) {
        self.element = element
        _parameters = State(
            initialValue:
                parameters
        )
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StolarniaSectionIntro(
                        title:
                            "Parametryczny System 32",
                        description:
                            "Generowanie przedniego i tylnego rzędu otworów na elemencie bocznym.",
                        systemImage:
                            "circle.grid.cross"
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                }

                Section("Zakres") {
                    Toggle(
                        "System aktywny",
                        isOn:
                            $parameters.aktywny
                    )

                    Toggle(
                        "Rząd przedni",
                        isOn:
                            $parameters
                                .generujRzadPrzedni
                    )

                    Toggle(
                        "Rząd tylny",
                        isOn:
                            $parameters
                                .generujRzadTylny
                    )

                    numberField(
                        "Początek od dołu",
                        value:
                            $parameters
                                .poczatekYMM
                    )

                    numberField(
                        "Koniec od góry",
                        value:
                            $parameters
                                .koniecOdGoryMM
                    )
                }

                Section("Siatka") {
                    numberField(
                        "Odsunięcie przód",
                        value:
                            $parameters
                                .odsunOdPrzoduMM
                    )

                    numberField(
                        "Odsunięcie tył",
                        value:
                            $parameters
                                .odsunOdTyluMM
                    )

                    numberField(
                        "Skok",
                        value:
                            $parameters.skokMM
                    )

                    numberField(
                        "Średnica",
                        value:
                            $parameters
                                .srednicaMM
                    )

                    numberField(
                        "Głębokość",
                        value:
                            $parameters
                                .glebokoscMM
                    )

                    Toggle(
                        "Lustrzany prawy bok",
                        isOn:
                            $parameters
                                .lustrzaneOdbiciePrawegoBoku
                    )
                }

                Section("Obrzeża") {
                    Picker(
                        "Kompensacja",
                        selection:
                            $parameters
                                .kompensacjaObrzeza
                    ) {
                        ForEach(
                            TrybKompensacjiObrzezaSystemu32
                                .allCases
                        ) { mode in
                            Text(mode.nazwa)
                                .tag(mode)
                        }
                    }

                    numberField(
                        "Obrzeże przód",
                        value:
                            $parameters
                                .gruboscObrzezaPrzodMM
                    )

                    numberField(
                        "Obrzeże tył",
                        value:
                            $parameters
                                .gruboscObrzezaTylMM
                    )

                    LabeledContent(
                        "Efektywny przód",
                        value:
                            "\(formatted(parameters.efektywnyOdsunPrzodMM)) mm"
                    )

                    LabeledContent(
                        "Efektywny tył",
                        value:
                            "\(formatted(parameters.efektywnyOdsunTylMM)) mm"
                    )
                }

                Section("Pomijane otwory") {
                    TextField(
                        "Przedni, np. 0, 3, 7",
                        text:
                            omittedBinding(
                                front: true
                            )
                    )
                    .keyboardType(
                        .numbersAndPunctuation
                    )

                    TextField(
                        "Tylny, np. 1, 2",
                        text:
                            omittedBinding(
                                front: false
                            )
                    )
                    .keyboardType(
                        .numbersAndPunctuation
                    )

                    Text(
                        "Indeksy liczone są od zera osobno dla każdego rzędu."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Section("Podgląd walidacji") {
                    ForEach(validation) {
                        result in

                        Label(
                            result.komunikat,
                            systemImage:
                                symbol(
                                    for:
                                        result.poziom
                                )
                        )
                        .foregroundStyle(
                            color(
                                for:
                                    result.poziom
                            )
                        )
                    }

                    LabeledContent(
                        "Liczba punktów",
                        value:
                            "\(generatedPoints.count)"
                    )
                }
            }
            .navigationTitle(
                element.etykieta
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
                    Button(
                        "Generuj"
                    ) {
                        onApply(
                            parameters,
                            generatedPoints
                        )
                        dismiss()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        validation.contains {
                            $0.poziom
                                == .blad
                        }
                    )
                }
            }
        }
    }

    private var validation:
        [WynikWalidacjiSystemu32]
    {
        System32Generator.validate(
            element: element,
            parameters: parameters
        )
    }

    private var generatedPoints:
        [PunktWierceniaSzafki]
    {
        System32Generator.generate(
            for: element,
            parameters: parameters
        )
    }

    private func omittedBinding(
        front: Bool
    ) -> Binding<String> {
        Binding(
            get: {
                let values =
                    front
                    ? parameters
                        .pominieteIndeksyPrzednie
                    : parameters
                        .pominieteIndeksyTylne

                return values
                    .sorted()
                    .map(String.init)
                    .joined(
                        separator: ", "
                    )
            },
            set: { text in
                let values =
                    Set(
                        text
                            .split(
                                separator: ","
                            )
                            .compactMap {
                                Int(
                                    $0.trimmingCharacters(
                                        in:
                                            .whitespacesAndNewlines
                                    )
                                )
                            }
                            .filter {
                                $0 >= 0
                            }
                    )

                if front {
                    parameters
                        .pominieteIndeksyPrzednie =
                            values
                } else {
                    parameters
                        .pominieteIndeksyTylne =
                            values
                }
            }
        )
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
            .frame(width: 90)

            Text("mm")
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private func formatted(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }

    private func symbol(
        for level:
            WynikWalidacjiSystemu32
                .Poziom
    ) -> String {
        switch level {
        case .informacja:
            return "info.circle"
        case .ostrzezenie:
            return "exclamationmark.triangle"
        case .blad:
            return "xmark.octagon"
        }
    }

    private func color(
        for level:
            WynikWalidacjiSystemu32
                .Poziom
    ) -> Color {
        switch level {
        case .informacja:
            return .secondary
        case .ostrzezenie:
            return .orange
        case .blad:
            return .red
        }
    }
}
