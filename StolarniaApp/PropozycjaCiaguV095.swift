import SwiftUI
import DomainCore

/// Dobiera moduł z katalogu kuchennego dla slotu z `KitchenLayoutProposer`.
///
/// Planer domenowy nie zna katalogu — mówi tylko „tu zlew 800, tu szuflady 600".
/// Tłumaczenie na konkretny preset musi żyć w warstwie aplikacji, bo to tutaj
/// jest `StandardKitchenModuleCatalogV0143`.
enum MapperPropozycjiCiaguV095 {

    /// Konstrukcja katalogowa odpowiadająca rodzajowi slotu.
    private static func konstrukcja(
        dla rodzaj: KitchenLayoutProposer.SlotKind
    ) -> KitchenModuleConstructionV0143? {
        switch rodzaj {
        case .sink:       return .sink
        case .dishwasher: return .dishwasherFront
        case .oven:       return .oven
        case .hob:        return .cooktop
        case .fridge:     return .refrigerator
        case .drawers:    return .drawers
        case .doors:      return .shelves
        case .cargo:      return .cargo
        case .filler:     return nil     // blenda ma osobny szablon wykończeniowy
        }
    }

    /// Szablon dla slotu — preset o właściwej konstrukcji i najbliższej szerokości.
    ///
    /// Szerokość slotu bierze się z reguł warsztatowych, a nie z katalogu, więc
    /// nie zawsze istnieje preset dokładnie tej szerokości (np. korpus 605 mm po
    /// wchłonięciu blendy). Wybieramy najbliższy preset, a **realną szerokość
    /// i tak nadpisujemy parametrem** przy tworzeniu modułu.
    static func szablon(
        dla slot: KitchenLayoutProposer.Slot,
        wSzablonach szablony: [FurnitureTemplate]
    ) -> FurnitureTemplate? {
        // Blenda nie jest modułem katalogowym, tylko elementem wykończeniowym.
        // Wcześniej była po prostu pomijana i na ścianie zostawała luka —
        // przy ciągu 3600 mm było to 100 mm dziury. Blenda dolna 60–120 mm jest
        // w stolarce normalna i wręcz pożądana: pozwala dopasować ciąg do
        // nierównej ściany.
        if slot.kind == .filler {
            return StandardKitchenFinishingTemplatesV015.template(
                for: .baseFiller, in: szablony)
        }
        guard let szukana = konstrukcja(dla: slot.kind) else { return nil }

        // Lodówka do zabudowy jest w katalogu **słupkiem** (`tall-refrigerator-*`),
        // nie szafką dolną — i słusznie, bo kolumna lodówki ma pełną wysokość.
        // Dla pozostałych slotów bierzemy tylko korpusy ciągu dolnego, żeby
        // planer nie wstawił słupka tam, gdzie ma stać blat.
        let dopuszczaSlupek = slot.kind == .fridge
        let kandydaci = szablony.compactMap { szablon -> (FurnitureTemplate, KitchenModulePresetV0143)? in
            guard let preset = StandardKitchenTemplatesV0143.preset(for: szablon.id),
                  preset.construction == szukana,
                  preset.anchoring != .wallMounted,
                  dopuszczaSlupek || preset.heightMM < 1_600
            else { return nil }
            return (szablon, preset)
        }
        guard !kandydaci.isEmpty else { return nil }

        let cel = slot.width.rawValue
        return kandydaci.min {
            abs(Double($0.1.widthMM) - cel) < abs(Double($1.1.widthMM) - cel)
        }?.0
    }

    /// Dane modułu gotowe do `createModule`, z realną szerokością i pozycją.
    static func dane(
        dla slot: KitchenLayoutProposer.Slot,
        szablon: FurnitureTemplate,
        offsetWzdluzSciany: Millimeters
    ) -> KonfiguracjaModuluMeblowegoDane {
        let domyslne = szablon.defaultParameters
        let wysokosc = (try? domyslne.millimeters(for: .height)) ?? 720
        let glebokosc = (try? domyslne.millimeters(for: .depth)) ?? 560
        let polki = (try? domyslne.integer(for: .shelfCount)) ?? 0

        return KonfiguracjaModuluMeblowegoDane(
            name: nazwa(dla: slot),
            width: slot.width,
            height: wysokosc,
            depth: glebokosc,
            shelfCount: polki,
            drawerCount: slot.kind == .drawers ? 3 : 0,
            offsetAlongWall: offsetWzdluzSciany,
            offsetFromWall: .zero,
            bottomOffset: .zero
        )
    }

    private static func nazwa(dla slot: KitchenLayoutProposer.Slot) -> String {
        "\(slot.kind.displayName) \(Int(slot.width.rawValue))"
    }
}

// MARK: - Ekran propozycji

/// Pokazuje gotowy ciąg dolny dla ściany i pozwala wstawić go jednym ruchem.
///
/// To jest krok, którego aplikacji brakowało: planer IKEA po kilku pytaniach
/// **sam pokazuje gotowe kuchnie**, a użytkownik wybiera i dopiero potem
/// poprawia. Wcześniej po podaniu wymiarów pomieszczenia projektant dostawał
/// pusty plan i katalog stu kilkudziesięciu modułów.
struct PropozycjaCiaguView: View {

    let dlugoscSciany: Millimeters
    let szablony: [FurnitureTemplate]
    /// Wstawia moduł; zwraca `false`, gdy zapis się nie powiódł.
    let onWstaw: (KitchenLayoutProposer.Slot, FurnitureTemplate, Millimeters) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var agd = KitchenLayoutProposer.Appliances()
    @State private var wstawianie = false
    @State private var postep = 0
    @State private var blad: String?

    private var propozycja: KitchenLayoutProposer.Proposal {
        KitchenLayoutProposer.proposeBaseRun(
            wallLength: dlugoscSciany, appliances: agd)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sekcjaSprzetu
                    if propozycja.slots.isEmpty {
                        pustaPropozycja
                    } else {
                        pasekCiagu
                        listaModulow
                    }
                    if !propozycja.warnings.isEmpty {
                        sekcjaOstrzezen
                    }
                }
                .padding(16)
            }
            .navigationTitle("Propozycja ciągu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .disabled(wstawianie)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(wstawianie ? "Wstawianie…" : "Wstaw ten układ") {
                        Task { await wstaw() }
                    }
                    .disabled(wstawianie || wstawialne.isEmpty)
                }
            }
            .alert("Nie udało się wstawić",
                   isPresented: Binding(get: { blad != nil },
                                        set: { if !$0 { blad = nil } })) {
                Button("OK", role: .cancel) { blad = nil }
            } message: {
                Text(blad ?? "")
            }
        }
    }

    // MARK: Sprzęt

    /// Pytania o AGD — odpowiednik pierwszego kroku planera IKEA.
    /// Zmiana przełącznika od razu przelicza propozycję.
    private var sekcjaSprzetu: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("Co ma być w tym ciągu")
            VStack(spacing: 0) {
                przelacznik("Zlewozmywak", "drop", $agd.hasSink)
                Divider()
                przelacznik("Zmywarka", "dishwasher", $agd.hasDishwasher)
                Divider()
                przelacznik("Piekarnik", "oven", $agd.hasOven)
                Divider()
                przelacznik("Płyta grzewcza", "flame", $agd.hasHob)
                Divider()
                przelacznik("Lodówka w zabudowie", "refrigerator",
                            $agd.hasIntegratedFridge)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(StolarniaPalette.canvasRaised)
            )
        }
    }

    private func przelacznik(
        _ tytul: String, _ ikona: String, _ wartosc: Binding<Bool>
    ) -> some View {
        Toggle(isOn: wartosc) {
            Label(tytul, systemImage: ikona)
        }
        .padding(.horizontal, 14)
        // Reguła projektu: ważny wiersz 52–62 pt. Badania dla 60+ dają próg
        // komfortu ok. 9,2 mm, czyli ok. 48 pt — 52 pt jest powyżej optimum.
        .frame(minHeight: 52)
    }

    // MARK: Ciąg

    private var pasekCiagu: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("Propozycja")
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(propozycja.slots) { slot in
                        let udzial = slot.width.rawValue / max(dlugoscSciany.rawValue, 1)
                        kafelekModulu(slot)
                            .frame(width: max(geo.size.width * udzial - 2, 22))
                    }
                }
            }
            .frame(height: 74)
            Text(propozycja.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func kafelekModulu(_ slot: KitchenLayoutProposer.Slot) -> some View {
        let sprzet: Set<KitchenLayoutProposer.SlotKind> =
            [.sink, .dishwasher, .oven, .hob, .fridge]
        let jestSprzet = sprzet.contains(slot.kind)
        let jestBlenda = slot.kind == .filler
        return RoundedRectangle(cornerRadius: 5)
            .fill(jestSprzet
                  ? StolarniaPalette.accentStrong.opacity(0.18)
                  : (jestBlenda ? Color.clear : Color.primary.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        jestSprzet
                            ? StolarniaPalette.accentStrong.opacity(0.7)
                            : Color.secondary.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1,
                                           dash: jestBlenda ? [3, 3] : [])
                    )
            )
            .overlay(
                Text("\(Int(slot.width.rawValue))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .minimumScaleFactor(0.6)
            )
    }

    private var listaModulow: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("Moduły od lewej")
            ForEach(propozycja.slots) { slot in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(Int(slot.width.rawValue))")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .frame(width: 52, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(slot.kind.displayName)
                            .font(.subheadline.weight(.medium))
                        if !slot.note.isEmpty {
                            Text(slot.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if MapperPropozycjiCiaguV095.szablon(
                            dla: slot, wSzablonach: szablony) == nil {
                            Label("brak modułu w katalogu — pominięty",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 52)
            }
        }
    }

    private var sekcjaOstrzezen: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(propozycja.warnings.enumerated()), id: \.offset) { _, w in
                Label(w, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.10))
        )
    }

    private var pustaPropozycja: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Brak propozycji", systemImage: "questionmark.square.dashed")
                .font(.headline)
            Text(propozycja.reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(StolarniaPalette.canvasRaised)
        )
    }

    private func naglowek(_ tekst: String) -> some View {
        Text(tekst.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: Wstawianie

    /// Sloty, które mają odpowiednik w katalogu albo w szablonach wykończeniowych.
    /// Cokolwiek nie ma, jest oznaczone na liście — nic nie znika po cichu.
    private var wstawialne: [(KitchenLayoutProposer.Slot, FurnitureTemplate, Millimeters)] {
        var wynik: [(KitchenLayoutProposer.Slot, FurnitureTemplate, Millimeters)] = []
        var offset = Millimeters.zero
        for slot in propozycja.slots {
            if let szablon = MapperPropozycjiCiaguV095.szablon(
                dla: slot, wSzablonach: szablony) {
                wynik.append((slot, szablon, offset))
            }
            offset = offset + slot.width
        }
        return wynik
    }

    private func wstaw() async {
        wstawianie = true
        defer { wstawianie = false }
        postep = 0
        for (slot, szablon, offset) in wstawialne {
            let ok = await onWstaw(slot, szablon, offset)
            guard ok else {
                blad = "Moduł „\(slot.kind.displayName) "
                    + "\(Int(slot.width.rawValue))” nie został zapisany. "
                    + "Wstawiono \(postep) z \(wstawialne.count)."
                return
            }
            postep += 1
        }
        dismiss()
    }
}
