import DomainCore
import Foundation
import SwiftUI

enum PoleWymiaruModulu2D {
    case szerokosc
    case wysokosc
    case glebokosc
}

/// Cel szybkiej edycji uruchamianej bezpośrednio z etykiety wymiarowej.
///
/// Wartość jest identyfikowana przez stabilny identyfikator ściany albo modułu.
/// Dzięki temu etykieta nie przechowuje kopii modelu i zawsze zapisuje zmianę
/// przez istniejące repozytoria aplikacji.
enum CelEdycjiWymiaru2D {
    case dlugoscSciany(WallID)
    case wysokoscSciany(WallID)
    case szerokoscModulu(FurnitureAssemblyID)
    case wysokoscModulu(FurnitureAssemblyID)
    case glebokoscModulu(FurnitureAssemblyID)

    var furnitureID: FurnitureAssemblyID? {
        switch self {
        case .szerokoscModulu(let id),
             .wysokoscModulu(let id),
             .glebokoscModulu(let id):
            return id
        case .dlugoscSciany,
             .wysokoscSciany:
            return nil
        }
    }

    var wallID: WallID? {
        switch self {
        case .dlugoscSciany(let id),
             .wysokoscSciany(let id):
            return id
        case .szerokoscModulu,
             .wysokoscModulu,
             .glebokoscModulu:
            return nil
        }
    }

    var poleModulu: PoleWymiaruModulu2D? {
        switch self {
        case .szerokoscModulu:
            return .szerokosc
        case .wysokoscModulu:
            return .wysokosc
        case .glebokoscModulu:
            return .glebokosc
        case .dlugoscSciany,
             .wysokoscSciany:
            return nil
        }
    }
}

/// Komplet informacji potrzebny do pokazania lekkiego edytora wymiaru.
struct KontekstEdycjiWymiaru2D: Identifiable {
    let id = UUID()
    let cel: CelEdycjiWymiaru2D
    let tytul: String
    let opis: String
    let wartosc: Millimeters
    let minimalnaWartosc: Double
    let maksymalnaWartosc: Double
    let wartosciSzybkie: [Double]

    static func dlugoscSciany(
        wallID: WallID,
        nazwa: String,
        wartosc: Millimeters
    ) -> Self {
        Self(
            cel: .dlugoscSciany(wallID),
            tytul: "Długość ściany",
            opis: nazwa,
            wartosc: wartosc,
            minimalnaWartosc: 100,
            maksymalnaWartosc: 50_000,
            wartosciSzybkie: []
        )
    }

    static func wysokoscSciany(
        wallID: WallID,
        nazwa: String,
        wartosc: Millimeters
    ) -> Self {
        Self(
            cel: .wysokoscSciany(wallID),
            tytul: "Wysokość ściany",
            opis: "\(nazwa) • zmiana ustawi jednakową wysokość na obu końcach",
            wartosc: wartosc,
            minimalnaWartosc: 300,
            maksymalnaWartosc: 10_000,
            wartosciSzybkie: [2_400, 2_500, 2_600, 2_700, 2_800]
        )
    }

    static func szerokoscModulu(
        furnitureID: FurnitureAssemblyID,
        nazwa: String,
        wartosc: Millimeters
    ) -> Self {
        Self(
            cel: .szerokoscModulu(furnitureID),
            tytul: "Szerokość modułu",
            opis: nazwa,
            wartosc: wartosc,
            minimalnaWartosc: 50,
            maksymalnaWartosc: 5_000,
            wartosciSzybkie: [300, 400, 450, 500, 600, 800, 900, 1_200]
        )
    }

    static func wysokoscModulu(
        furnitureID: FurnitureAssemblyID,
        nazwa: String,
        wartosc: Millimeters
    ) -> Self {
        Self(
            cel: .wysokoscModulu(furnitureID),
            tytul: "Wysokość modułu",
            opis: nazwa,
            wartosc: wartosc,
            minimalnaWartosc: 50,
            maksymalnaWartosc: 5_000,
            wartosciSzybkie: [300, 450, 720, 768, 800, 2_100, 2_300]
        )
    }

    static func glebokoscModulu(
        furnitureID: FurnitureAssemblyID,
        nazwa: String,
        wartosc: Millimeters
    ) -> Self {
        Self(
            cel: .glebokoscModulu(furnitureID),
            tytul: "Głębokość modułu",
            opis: nazwa,
            wartosc: wartosc,
            minimalnaWartosc: 50,
            maksymalnaWartosc: 2_000,
            wartosciSzybkie: [300, 350, 500, 560, 600, 620]
        )
    }
}

/// Lekki edytor wyświetlany po dotknięciu kapsuły wymiarowej.
///
/// Zapis przechodzi przez ten sam silnik walidacji co pełny formularz modułu,
/// dlatego zmiana nie omija kontroli kolizji, zakresów ani repozytoriów.
struct SzybkaEdycjaWymiaru2DView: View {
    @Environment(\.dismiss) private var dismiss

    let kontekst: KontekstEdycjiWymiaru2D
    let onSave: @MainActor (Millimeters) async -> Bool

    @State private var wartoscText: String
    @State private var isSaving = false
    @State private var validationMessage: String?

    init(
        kontekst: KontekstEdycjiWymiaru2D,
        onSave: @escaping @MainActor (Millimeters) async -> Bool
    ) {
        self.kontekst = kontekst
        self.onSave = onSave
        _wartoscText = State(
            initialValue: Self.editableText(
                kontekst.wartosc.rawValue
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Aktualnie") {
                        Text(formatted(kontekst.wartosc.rawValue))
                            .font(.body.monospacedDigit().weight(.semibold))
                    }

                    HStack(spacing: 12) {
                        TextField(
                            "Wartość",
                            text: $wartoscText
                        )
                        .keyboardType(.decimalPad)
                        .font(.title3.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(kontekst.tytul)

                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(kontekst.tytul)
                } footer: {
                    Text(kontekst.opis)
                }

                Section("Korekta") {
                    HStack {
                        stepButton(-10)
                        stepButton(-1)

                        Spacer()

                        stepButton(1)
                        stepButton(10)
                    }
                }

                if !kontekst.wartosciSzybkie.isEmpty {
                    Section("Typowe wartości") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(
                                    kontekst.wartosciSzybkie,
                                    id: \.self
                                ) { value in
                                    Button {
                                        wartoscText =
                                            Self.editableText(value)
                                    } label: {
                                        Text(formatted(value))
                                            .monospacedDigit()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                Section {
                    Label(
                        "Po zapisie aplikacja ponownie zbuduje moduł, sprawdzi jego położenie i odświeży dokumentację.",
                        systemImage: "checkmark.shield"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Section {
                        Label(
                            validationMessage,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edytuj wymiar")
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
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Zapisz")
                        }
                    }
                    .disabled(isSaving)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stepButton(
        _ delta: Double
    ) -> some View {
        Button {
            let current =
                parsedValue(wartoscText)
                ?? kontekst.wartosc.rawValue
            let changed = min(
                max(
                    current + delta,
                    kontekst.minimalnaWartosc
                ),
                kontekst.maksymalnaWartosc
            )
            wartoscText = Self.editableText(changed)
        } label: {
            Text(delta > 0 ? "+\(Int(delta)) mm" : "\(Int(delta)) mm")
                .frame(minWidth: 68)
        }
        .buttonStyle(.bordered)
    }

    private func save() {
        validationMessage = nil

        guard let value = parsedValue(wartoscText) else {
            validationMessage = "Podaj prawidłową wartość liczbową."
            return
        }

        guard value >= kontekst.minimalnaWartosc,
              value <= kontekst.maksymalnaWartosc else {
            validationMessage =
                "Dozwolony zakres: \(formatted(kontekst.minimalnaWartosc)) – \(formatted(kontekst.maksymalnaWartosc))."
            return
        }

        isSaving = true

        Task { @MainActor in
            let didSave = await onSave(Millimeters(value))
            isSaving = false

            if didSave {
                dismiss()
            } else {
                validationMessage =
                    "Nie udało się zapisać wymiaru. Sprawdź komunikat walidacji projektu."
            }
        }
    }

    private func parsedValue(
        _ text: String
    ) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized),
              value.isFinite,
              value > 0 else {
            return nil
        }

        return value
    }

    private func formatted(
        _ value: Double
    ) -> String {
        "\(Self.editableText(value)) mm"
    }

    private static func editableText(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }
}
