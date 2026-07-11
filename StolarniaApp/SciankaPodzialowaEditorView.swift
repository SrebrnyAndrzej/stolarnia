import DomainCore
import SwiftUI

/// Sheet do konfiguracji ścianki dzielącej z drzwiami przesuwnymi Bonari.
///
/// Pozwala:
/// - wybrać ścianę referencyjną i odległość od niej
/// - podać szerokość i wysokość ścianki
/// - zobaczyć auto-dobór liczby drzwi i serii Bonari
/// - skonfigurować wypełnienie drzwi (płyta/lustro/szkło/lacobel)
/// - wybrać kolor profilu
/// - podejrzeć BOM i ostrzeżenia systemowe
struct SciankaPodzialowaEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let room: RoomDefinition
    @ObservedObject var repository: SciankaPodzialowaRepository

    // Edytowany draft
    @State private var draft: SciankaPodzialowaDefinicjaV075
    @State private var editingExisting: Bool

    // UI state
    @State private var aktywnaSekcja: SekcjaEdytora = .polozenie
    @State private var pokazBOM = false
    @State private var autoWybor: BonariKatalog.WynikAutoDoboruDrzwi?
    @State private var raportBonari: RaportSzafyPrzesuwanejV075?

    private enum SekcjaEdytora: String, CaseIterable, Identifiable {
        case polozenie = "Położenie"
        case system    = "System"
        case drzwi     = "Drzwi"
        case bom       = "BOM"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .polozenie: return "mappin.and.ellipse"
            case .system:    return "slider.horizontal.3"
            case .drzwi:     return "door.sliding.left.hand.open"
            case .bom:       return "list.bullet.rectangle"
            }
        }
    }

    // MARK: Init

    init(
        room: RoomDefinition,
        repository: SciankaPodzialowaRepository,
        editing existing: SciankaPodzialowaDefinicjaV075? = nil
    ) {
        self.room = room
        self.repository = repository
        if let ex = existing {
            _draft = State(initialValue: ex)
            _editingExisting = State(initialValue: true)
        } else {
            var nowa = SciankaPodzialowaDefinicjaV075()
            // Pre-fill height from first wall if available
            let maxH = room.geometry.walls.map {
                max($0.startHeight.rawValue, $0.endHeight.rawValue)
            }.max() ?? 2500
            nowa.wysokoscCalkowitaMM = maxH
            nowa.systemPrzesuwny.wysokoscCalkowitaMM = maxH
            _draft = State(initialValue: nowa)
            _editingExisting = State(initialValue: false)
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pasek skrzydło-preview
                skrzydloPreviewBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)

                Divider()

                Picker("Sekcja", selection: $aktywnaSekcja) {
                    ForEach(SekcjaEdytora.allCases) { s in
                        Label(s.rawValue, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Form {
                    switch aktywnaSekcja {
                    case .polozenie: polozenieSections
                    case .system:    systemSections
                    case .drzwi:     drzwiSections
                    case .bom:       bomSections
                    }
                }
            }
            .navigationTitle(
                editingExisting
                    ? "Edytuj ściankę dzielącą"
                    : "Nowa ścianka dzieląca"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingExisting ? "Zapisz" : "Dodaj") {
                        zapisz()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onChange(of: draft.szerokoscCalkowitaMM) { _, _ in przelicz() }
            .onChange(of: draft.wysokoscCalkowitaMM)  { _, _ in przelicz() }
            .onChange(of: draft.systemPrzesuwny.konstrukjaDrzwi) { _, _ in przelicz() }
            .onAppear { przelicz() }
        }
    }

    // MARK: - Pasek podglądu

    @ViewBuilder
    private var skrzydloPreviewBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skrzydło")
                    .font(.caption2).foregroundStyle(.secondary)
                if let auto = autoWybor {
                    Text("\(auto.liczbaDrzwi) × \(Int(auto.szerokoscSkrzydlaMM.rounded())) mm")
                        .font(.subheadline.bold())
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Seria").font(.caption2).foregroundStyle(.secondary)
                Text(autoWybor?.seria.nazwa ?? "—")
                    .font(.caption.weight(.medium))
            }

            Divider().frame(height: 28)

            if let auto = autoWybor {
                ocenaBadge(ocena: auto.ocena)
            }

            Spacer()

            if let raport = raportBonari, !raport.ostrzezenia.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .onTapGesture { aktywnaSekcja = .bom }
            }
        }
    }

    @ViewBuilder
    private func ocenaBadge(ocena: String) -> some View {
        let (etykieta, kolor): (String, Color) = switch ocena {
        case "optimal":    ("Optymalne", .green)
        case "acceptable": ("Akceptowalne", .orange)
        default:           ("Uwaga", .red)
        }
        Text(etykieta)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(kolor.opacity(0.15), in: Capsule())
            .foregroundStyle(kolor)
    }

    // MARK: - Sekcja: Położenie

    @ViewBuilder
    private var polozenieSections: some View {
        Section("Nazwa i lokalizacja") {
            TextField("Nazwa ścianki", text: $draft.nazwa)

            if !room.geometry.walls.isEmpty {
                Picker("Ściana referencyjna", selection: Binding(
                    get: { draft.wallAnchorRawID ?? "" },
                    set: { draft.wallAnchorRawID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Nieokreślona").tag("")
                    ForEach(room.geometry.walls) { wall in
                        Text(wall.name).tag(wall.id.description)
                    }
                }
            }

            HStack {
                Text("Odległość od ściany")
                Spacer()
                TextField("mm", value: $draft.offsetOdScianyMM,
                          format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("mm").foregroundStyle(.secondary)
            }
        }

        Section("Gabaryty ścianki") {
            HStack {
                Text("Szerokość (rozpiętość)")
                Spacer()
                TextField("mm", value: $draft.szerokoscCalkowitaMM,
                          format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("mm").foregroundStyle(.secondary)
            }

            HStack {
                Text("Wysokość")
                Spacer()
                TextField("mm", value: $draft.wysokoscCalkowitaMM,
                          format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("mm").foregroundStyle(.secondary)
            }
        }

        Section {
            ForEach([2, 3, 4], id: \.self) { n in
                autoDoborRow(liczbaDrzwi: n)
            }
        } header: {
            Text("Auto-dobór drzwi")
        } footer: {
            Text("Strefa optymalna skrzydła Bonari: 700–950 mm. Trafienie w strefę optymalną jest oznaczone ★.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private func autoDoborRow(liczbaDrzwi n: Int) -> some View {
        let zachod = autoWybor?.zachodMM ?? 60
        let szerokosc = (draft.szerokoscCalkowitaMM + Double(n - 1) * zachod) / Double(n)
        let wStrefie = BonariKatalog.strefaOptymalnaMM.contains(szerokosc)
        let isSelected = draft.systemPrzesuwny.liczbaDrzwi == n

        Button {
            draft.systemPrzesuwny.liczbaDrzwi = n
            przelicz()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(n) drzwi")
                            .font(.body.weight(isSelected ? .semibold : .regular))
                        if wStrefie {
                            Text("★")
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("\(Int(szerokosc.rounded())) mm / skrzydło")
                        .font(.caption)
                        .foregroundStyle(
                            wStrefie ? .green :
                            BonariKatalog.strefaAkceptowalnaMM.contains(szerokosc) ? .primary : .red
                        )
                }

                Spacer()

                let seria = BonariKatalog.rekomendowanaSeria(
                    szerokoscSkrzydlaMM: szerokosc,
                    wysokoscSkrzydlaMM: draft.wysokoscCalkowitaMM - 47,
                    konstrukcja: draft.systemPrzesuwny.konstrukjaDrzwi
                )
                Text(seria.nazwa)
                    .font(.caption2)
                    .padding(5)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sekcja: System

    @ViewBuilder
    private var systemSections: some View {
        Section {
            ForEach(SeriaBonari.allCases.filter { $0.jestSciankaPodziałowa }) { seria in
                seriaRow(seria: seria)
            }
        } header: {
            Label("Ścianki dzielące", systemImage: "door.sliding.left.hand.open")
        }

        Section {
            ForEach(SeriaBonari.allCases.filter { !$0.jestSciankaPodziałowa }) { seria in
                seriaRow(seria: seria)
            }
        } header: {
            Label("Szafy (jeśli ścianka nie do sufitu)", systemImage: "shippingbox")
        }

        Section("Opcje montażu") {
            Toggle("Prowadnica górna do sufitu", isOn: $draft.montazDoSufitu)
            Toggle("Deska nośna pod prowadnicę", isOn: $draft.montazPrzybijany)
            Toggle("Miękkie zamykanie", isOn: $draft.systemPrzesuwny.miekkieZamykanie)
            Toggle("Soft-close", isOn: $draft.systemPrzesuwny.systemSoftClose)
        }

        Section("Profil — kolor") {
            if let seria = aktualnaSeriaBonari {
                ForEach(seria.profil.materialyProfilu) { mat in
                    Button {
                        draft.materialProfiluID = mat.id
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(stolarniaHEX: mat.kolorHEX))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(.secondary.opacity(0.25))
                                }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mat.nazwa).foregroundStyle(.primary)
                                Text(mat.opis).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if draft.materialProfiluID == mat.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func seriaRow(seria: SeriaBonari) -> some View {
        let profil = seria.profil
        let isSelected = aktualnaSeriaBonari == seria

        Button {
            let system: SystemProfiluSzafyPrzesuwanej = switch seria {
            case .bl40:        .bonariBL40
            case .bl60:        .bonariBL60
            case .bl80:        .bonariBL80
            case .bl100:       .bonariBL100
            case .partition40: .bonariPartition40
            case .partition80: .bonariPartition80
            }
            draft.systemPrzesuwny.systemProfili = system
            przelicz()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(seria.nazwa)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                    Text(seria.opis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("Max: \(Int(profil.maxNosnosc_kg)) kg")
                        Text("·")
                        Text("\(Int(profil.minSzerokoscSkrzydlaMM))–\(Int(profil.maxSzerokoscSkrzydlaMM)) mm")
                        Text("·")
                        Text("H max \(Int(profil.maxWysokoscSkrzydlaMM)) mm")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sekcja: Drzwi (wypełnienie)

    @ViewBuilder
    private var drzwiSections: some View {
        Section("Konstrukcja drzwi") {
            Picker("Typ", selection: $draft.systemPrzesuwny.konstrukjaDrzwi) {
                ForEach(KonstrukcjaDrzwiPrzesuwnychV075.allCases) { k in
                    Text(k.nazwa).tag(k)
                }
            }

            HStack {
                Text("Grubość drzwi")
                Spacer()
                Picker("", selection: $draft.systemPrzesuwny.gruboscDrzwiMM) {
                    let grubosci = aktualnaSeriaBonari?.profil.gruboscDrzwiDostepne
                        ?? [16, 18, 20, 22, 25]
                    ForEach(grubosci, id: \.self) { g in
                        Text("\(Int(g)) mm").tag(g)
                    }
                }
                .pickerStyle(.menu)
            }
        }

        Section("Wypełnienie z katalogu Bonari") {
            let lista = BonariKatalog.wypelnienia(
                dla: draft.systemPrzesuwny.konstrukjaDrzwi
            )

            if lista.isEmpty {
                Label(
                    "Brak pozycji katalogu dla wybranej konstrukcji.",
                    systemImage: "tray"
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(lista) { wypelnienie in
                    Button {
                        draft.wypelnienieDrzwiID = wypelnienie.id
                        draft.systemPrzesuwny.gruboscDrzwiMM = wypelnienie.gruboscMM
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(stolarniaHEX: wypelnienie.kolorHEX))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.secondary.opacity(0.25))
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wypelnienie.nazwa)
                                    .foregroundStyle(.primary)
                                Text("\(wypelnienie.opis) · \(Int(wypelnienie.gruboscMM)) mm · \(String(format: "%.0f", wypelnienie.wagaKgM2)) kg/m²")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if wypelnienie.maxSzerokoscMM < draft.systemPrzesuwny.szerokoscSkrzydlaMM {
                                    Label(
                                        "Max tafla \(Int(wypelnienie.maxSzerokoscMM)) mm — skrzydło może wymagać podziału",
                                        systemImage: "exclamationmark.triangle"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            if draft.wypelnienieDrzwiID == wypelnienie.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Section("Uchwyt") {
            Picker("Typ uchwytu", selection: $draft.systemPrzesuwny.uchwytTyp) {
                ForEach(TypUchwytuwProjekcie.allCases) { t in
                    Label(t.nazwa, systemImage: t.systemImage).tag(t)
                }
            }
        }
    }

    // MARK: - Sekcja: BOM

    @ViewBuilder
    private var bomSections: some View {
        if let auto = autoWybor {
            Section("Wynik auto-doboru") {
                LabeledContent("Liczba drzwi", value: "\(auto.liczbaDrzwi) szt.")
                LabeledContent("Szerokość skrzydła", value: "\(Int(auto.szerokoscSkrzydlaMM.rounded())) mm")
                LabeledContent("Zachód", value: "\(Int(auto.zachodMM)) mm")
                LabeledContent("Seria", value: auto.seria.nazwa)
                LabeledContent("Ocena", value: auto.komunikat)
            }
        }

        if let raport = raportBonari {
            Section("Obliczone skrzydło") {
                LabeledContent(
                    "Szerokość",
                    value: "\(Int(raport.definicja.szerokoscSkrzydlaMM.rounded())) mm"
                )
                LabeledContent(
                    "Wysokość",
                    value: "\(Int(raport.definicja.wysokoscSkrzydlaMM.rounded())) mm"
                )
                LabeledContent(
                    "Powierzchnia drzwi łącznie",
                    value: String(format: "%.2f m²", raport.sumaLisciM2)
                )
                LabeledContent(
                    "Szacunkowa waga drzwi",
                    value: String(format: "%.1f kg", raport.sumaWagaKg)
                )
            }

            Section("Lista elementów") {
                ForEach(raport.elementy) { el in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(el.opis)
                                .font(.callout)
                            if !el.wymiarOpis.isEmpty {
                                Text(el.wymiarOpis)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(el.ilosc) \(el.typ.jednostka)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !raport.ostrzezenia.isEmpty {
                Section("Ostrzeżenia") {
                    ForEach(raport.ostrzezenia, id: \.self) { uwaga in
                        Label(uwaga, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
        }

        Section {
            TextField("Uwagi montażowe", text: $draft.uwagi, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("Uwagi")
        }
    }

    // MARK: - Helpers

    private var aktualnaSeriaBonari: SeriaBonari? {
        draft.systemPrzesuwny.systemProfili.seriaBonari
    }

    private func przelicz() {
        draft.synchronizujZSystemem()
        let (raport, auto) = SilnikSzafyPrzesuwanejV075.raportBonari(dla: draft.systemPrzesuwny)
        self.raportBonari = raport
        self.autoWybor    = auto
    }

    private func zapisz() {
        draft.synchronizujZSystemem()
        if editingExisting {
            repository.zaktualizuj(draft)
        } else {
            repository.dodaj(draft)
        }
    }
}
