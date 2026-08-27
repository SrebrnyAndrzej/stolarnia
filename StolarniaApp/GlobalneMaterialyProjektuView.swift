import SwiftUI

/// Sheet edycji globalnych materiałów projektu.
///
/// Pozwala wybrać domyślny kolor korpusu, kolor frontu i system szuflad
/// dla całego projektu. Wybrane ustawienia służą jako domyślne przy
/// dodawaniu nowych mebli — nie nadpisują istniejących modułów.
struct GlobalneMaterialyProjektuView: View {
    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var repository:
        GlobalneMaterialyProjektuRepository

    @StateObject private var bazaMaterialow =
        BazaMaterialowRepository()

    @State private var korpusID: UUID?
    @State private var frontID: UUID?
    @State private var szufladyID: UUID?
    @State private var wyszukiwanie = ""
    @State private var filtrProducenta: String?
    @State private var aktywnaSekcja: AktywnaSekcja = .korpus

    private enum AktywnaSekcja: String, CaseIterable, Identifiable {
        case korpus
        case front
        case szuflady
        case opcje

        var id: String { rawValue }

        var tytul: String {
            switch self {
            case .korpus:   return "Korpusy"
            case .front:    return "Fronty"
            case .szuflady: return "System szuflad"
            case .opcje:    return "Opcje projektu"
            }
        }

        var systemImage: String {
            switch self {
            case .korpus:   return "shippingbox"
            case .front:    return "door.left.hand.closed"
            case .szuflady: return "tray.2"
            case .opcje:    return "slider.horizontal.3"
            }
        }
    }

    init(repository: GlobalneMaterialyProjektuRepository) {
        self.repository = repository
        _korpusID = State(initialValue: repository.ustawienia.korpus.id)
        _frontID  = State(initialValue: repository.ustawienia.front.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pasek podsumowania wybranych materiałów
                materialSummaryBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .stolarniaMaterial(.ultraThinMaterial)

                Divider()

                // Segmented picker sekcji
                Picker("Sekcja", selection: $aktywnaSekcja) {
                    ForEach(AktywnaSekcja.allCases) { s in
                        Label(s.tytul, systemImage: s.systemImage)
                            .tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                // Główna zawartość
                Form {
                    switch aktywnaSekcja {
                    case .korpus:
                        filtrProducentaSection
                        wyborMaterialu(
                            title: "Wybierz płytę korpusową",
                            systemImage: "shippingbox",
                            filter: [.plytaLaminowana, .mdf, .hdf, .sklejka],
                            selection: $korpusID,
                            current: repository.ustawienia.korpus
                        )

                    case .front:
                        filtrProducentaSection
                        wyborMaterialu(
                            title: "Wybierz materiał frontu",
                            systemImage: "door.left.hand.closed",
                            filter: [.front, .mdf, .plytaLaminowana],
                            selection: $frontID,
                            current: repository.ustawienia.front
                        )

                    case .szuflady:
                        wyborSystemuSzuflad

                    case .opcje:
                        opcjeProiektu
                    }
                }
                .searchable(
                    text: $wyszukiwanie,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Kod, dekor, kolekcja, producent"
                )
            }
            .navigationTitle("Globalne materiały projektu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zastosuj") {
                        zastosuj()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Pasek podsumowania

    @ViewBuilder
    private var materialSummaryBar: some View {
        HStack(spacing: 16) {
            materialChip(
                label: "Korpus",
                material: repository.ustawienia.korpus,
                selectedID: korpusID
            )

            Divider().frame(height: 36)

            materialChip(
                label: "Front",
                material: repository.ustawienia.front,
                selectedID: frontID
            )

            Spacer()

            if repository.ustawienia.systemSzuflad.jestWybrany {
                Label(
                    repository.ustawienia.systemSzuflad.seria.isEmpty
                        ? repository.ustawienia.systemSzuflad.nazwa
                        : repository.ustawienia.systemSzuflad.seria,
                    systemImage: "tray.2"
                )
                .font(.caption2)
                .padding(6)
                .background(.secondary.opacity(0.15), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func materialChip(
        label: String,
        material: MigawkaMaterialuGlobalnego,
        selectedID: UUID?
    ) -> some View {
        let effective = selectedID.flatMap { id in
            bazaMaterialow.materialy.first { $0.id == id }
        }

        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(stolarniaHEX: effective?.kolorHEX ?? material.kolorHEX))
                .frame(width: 28, height: 28)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(effective?.nazwa ?? material.nazwa)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Filtr producenta

    @ViewBuilder
    private var filtrProducentaSection: some View {
        Section {
            Picker("Producent", selection: $filtrProducenta) {
                Text("Wszyscy").tag(Optional<String>.none)
                ForEach(producenci, id: \.self) {
                    Text($0).tag(Optional($0))
                }
            }
        } footer: {
            Text("Kolor na ekranie to podgląd. Do zatwierdzenia zamówienia zawsze używaj fizycznego wzornika.")
                .font(.caption2)
        }
    }

    // MARK: - Wybór materiału płytowego

    @ViewBuilder
    private func wyborMaterialu(
        title: String,
        systemImage: String,
        filter: [TypMaterialuStolarskiego],
        selection: Binding<UUID?>,
        current: MigawkaMaterialuGlobalnego
    ) -> some View {
        let lista = filtruj(
            bazaMaterialow.materialy,
            types: filter
        )

        Section {
            ForEach(lista) { material in
                Button {
                    selection.wrappedValue = material.id
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(stolarniaHEX: material.kolorHEX))
                            .frame(width: 44, height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(material.nazwa)
                                .foregroundStyle(.primary)
                                .font(.body)

                            Text(
                                [
                                    material.producent,
                                    material.kodProducenta ?? material.kod,
                                    material.struktura ?? ""
                                ]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selection.wrappedValue == material.id
                            || (selection.wrappedValue == nil && material.id == current.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if lista.isEmpty {
                ContentUnavailableView(
                    "Brak materiałów",
                    systemImage: "square.grid.2x2",
                    description: Text("Uzupełnij Bazę materiałów lub zmień filtr producenta.")
                )
            }
        } header: {
            Label(title, systemImage: systemImage)
        } footer: {
            if let id = selection.wrappedValue,
               let mat = bazaMaterialow.materialy.first(where: { $0.id == id }) {
                Text("Wybrano: \(mat.producent) \(mat.nazwa)")
            } else {
                Text("Bieżący: \(current.producent) \(current.nazwa)")
            }
        }
    }

    // MARK: - Wybór systemu szuflad

    @ViewBuilder
    private var wyborSystemuSzuflad: some View {
        Section {
            Button {
                szufladyID = nil
                var updated = repository.ustawienia
                updated.systemSzuflad = .brakSystemu
                repository.zaktualizuj(updated)
            } label: {
                HStack {
                    Label("Brak systemu szuflad", systemImage: "nosign")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !repository.ustawienia.systemSzuflad.jestWybrany {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Brak")
        }

        let systemy = bazaMaterialow.materialy.filter {
            $0.aktywny && $0.typ == .systemSzuflady
        }

        Section {
            ForEach(systemy) { material in
                Button {
                    szufladyID = material.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.2.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(material.nazwa)
                                .foregroundStyle(.primary)
                            Text(
                                [material.producent, material.kod]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · ")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if szufladyID == material.id
                            || (szufladyID == nil && repository.ustawienia.systemSzuflad.kod == (material.kodProducenta ?? material.kod)) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if systemy.isEmpty {
                ContentUnavailableView(
                    "Brak systemów szuflad w bazie",
                    systemImage: "tray.2",
                    description: Text("Dodaj systemy szuflad w Bazie materiałów (typ: System szuflady).")
                )
            }
        } header: {
            Label("Systemy szuflad", systemImage: "tray.2")
        } footer: {
            if repository.ustawienia.systemSzuflad.jestWybrany {
                Text("Wybrany: \(repository.ustawienia.systemSzuflad.producent) \(repository.ustawienia.systemSzuflad.nazwa)")
            }
        }
    }

    // MARK: - Opcje projektu

    @ViewBuilder
    private var opcjeProiektu: some View {
        Section("Grubości materiałów") {
            gruboscRow("Płyta korpusowa", value: Binding(
                get: { repository.ustawienia.gruboscKorpusuMM },
                set: { v in var u = repository.ustawienia; u.gruboscKorpusuMM = v; repository.zaktualizuj(u) }
            ))
            gruboscRow("Płyta frontowa / drzwi", value: Binding(
                get: { repository.ustawienia.gruboscFrontuMM },
                set: { v in var u = repository.ustawienia; u.gruboscFrontuMM = v; repository.zaktualizuj(u) }
            ))
        }

        Section("Okucia standardowe") {
            Picker("System zawiasów", selection: Binding(
                get: { repository.ustawienia.systemZawiasow },
                set: { v in var u = repository.ustawienia; u.systemZawiasow = v; repository.zaktualizuj(u) }
            )) {
                ForEach(SystemZawiasow.allCases) { s in
                    Text(s.nazwa).tag(s)
                }
            }

            Picker("Typ uchwytu", selection: Binding(
                get: { repository.ustawienia.typUchwytu },
                set: { v in var u = repository.ustawienia; u.typUchwytu = v; repository.zaktualizuj(u) }
            )) {
                ForEach(TypUchwytuwProjekcie.allCases) { t in
                    Label(t.nazwa, systemImage: t.systemImage).tag(t)
                }
            }
        }

        Section {
            Button(role: .destructive) {
                repository.przywrocDomyslne()
            } label: {
                Label("Przywróć ustawienia domyślne", systemImage: "arrow.counterclockwise")
            }
        }

        if let komunikat = repository.komunikatIntegralnosci {
            Section {
                Label(komunikat, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func gruboscRow(
        _ label: String,
        value: Binding<Double>
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("mm", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("mm")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var producenci: [String] {
        Array(
            Set(
                bazaMaterialow.materialy
                    .filter { $0.aktywny }
                    .map(\.producent)
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    private func filtruj(
        _ lista: [MaterialStolarski],
        types: [TypMaterialuStolarskiego]
    ) -> [MaterialStolarski] {
        lista.filter { mat in
            guard mat.aktywny,
                  types.contains(mat.typ) else { return false }

            if let prod = filtrProducenta {
                guard mat.producent == prod else { return false }
            }

            guard !wyszukiwanie.isEmpty else { return true }
            let q = wyszukiwanie.lowercased()
            return mat.nazwa.lowercased().contains(q)
                || mat.kod.lowercased().contains(q)
                || mat.producent.lowercased().contains(q)
                || (mat.kodProducenta?.lowercased().contains(q) == true)
                || (mat.struktura?.lowercased().contains(q) == true)
        }
    }

    private func zastosuj() {
        var updated = repository.ustawienia

        if let id = korpusID,
           let mat = bazaMaterialow.materialy.first(where: { $0.id == id }) {
            updated.korpus = MigawkaMaterialuGlobalnego(material: mat)
        }

        if let id = frontID,
           let mat = bazaMaterialow.materialy.first(where: { $0.id == id }) {
            updated.front = MigawkaMaterialuGlobalnego(material: mat)
        }

        if let id = szufladyID,
           let mat = bazaMaterialow.materialy.first(where: { $0.id == id }) {
            updated.systemSzuflad = SystemSzufladMigawka(material: mat)
        }

        repository.zaktualizuj(updated)
    }
}
