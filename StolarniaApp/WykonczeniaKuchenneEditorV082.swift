import SwiftUI

// MARK: - Główny widok edytora wykończeń

struct WykonczeniaKuchenneEditorV082: View {
    @ObservedObject var repo: WykonczeniaKuchenneRepositoryV082
    /// Suma długości ciągów dolnych w mm (do auto-przeliczania fartucha/listew).
    let bazowaDlugoscCiaguMM: Double
    let ciagiDolneV087:
        [KitchenRunFinishingSegmentV087]

    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                blatyTab
                    .tabItem {
                        Label("Blaty", systemImage: "rectangle.portrait.topleft.inset.filled")
                    }
                    .tag(0)

                fartuchyTab
                    .tabItem {
                        Label("Fartuch", systemImage: "square.grid.2x2")
                    }
                    .tag(1)

                wienceTab
                    .tabItem {
                        Label("Listwy", systemImage: "align.horizontal.top.fill")
                    }
                    .tag(2)
            }
            .navigationTitle("Wykończenia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
    }

    // MARK: - Podsumowanie wyceny

    private var summarySection: some View {
        Section("Podsumowanie") {
            LabeledContent(
                "Blaty łącznie",
                value: String(format: "%.2f m", repo.sumaBlatomMB())
            )
            LabeledContent(
                "Fartuch łącznie",
                value: String(format: "%.2f m²", repo.sumaFartuchowM2(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM))
            )
            LabeledContent(
                "Listwy łącznie",
                value: String(format: "%.2f m", repo.sumaWiencowMB(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM))
            )
        }
    }

    // MARK: - Blaty

    private var blatyTab: some View {
        List {
            summarySection
            ciagiDolneAutoSectionV087

            if repo.blaty.isEmpty {
                Section {
                    StolarniaEmptyState(
                        title: "Brak blatów",
                        description: "Blat kuchenny jest elementem wykończeniowym — łączy szafki dolne i chroni je przed wilgocią. Dodaj pierwszy blat i wybierz kształt (prosty, L, U), materiał oraz wycięcia pod zlew i płytę.",
                        systemImage: "rectangle.grid.1x2",
                        actionTitle: "Dodaj blat",
                        actionSystemImage: "plus.circle.fill",
                        action: { repo.dodajBlat() }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach($repo.blaty) { $blat in
                    NavigationLink {
                        BlatKuchennyDetailV082(
                            blat: $blat,
                            onSave: { repo.zaktualizujBlat($blat.wrappedValue) }
                        )
                    } label: {
                        blatRow(blat)
                    }
                }
                .onDelete { idxSet in
                    idxSet.map { repo.blaty[$0].id }.forEach { repo.usunBlat(id: $0) }
                }

                Button {
                    repo.dodajBlat()
                } label: {
                    Label("Dodaj blat", systemImage: "plus.circle.fill")
                }
                .foregroundStyle(.blue)
            } header: {
                Text("Blaty (\(repo.blaty.count))")
            } footer: {
                Text("Blat jest wyceniany na podstawie mb × cena materiału (z wariantu wyceny).")
                    .font(.caption2)
            }
        }
    }

    private func blatRow(_ blat: BlatKuchennyV082) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: blat.ksztalt.systemImage)
                    .foregroundStyle(.blue)
                    .frame(width: 18)
                Text(blat.nazwa)
                    .font(.headline)
            }
            Text(
                "\(blat.ksztalt.rawValue) · \(blat.grubosc.label)"
                + " · \(Int(blat.calkowitaDlugoscMM)) mm"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if !blat.wycięcia.isEmpty {
                Text("Wycięcia: " + blat.wycięcia.map(\.rawValue).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Fartuchy

    private var fartuchyTab: some View {
        List {
            summarySection
            ciagiDolneAutoSectionV087

            Section {
                ForEach($repo.fartuchy) { $fartuch in
                    NavigationLink {
                        FartuchDetailV082(
                            fartuch: $fartuch,
                            bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM,
                            onSave: { repo.zaktualizujFartuch($fartuch.wrappedValue) }
                        )
                    } label: {
                        fartuchRow(fartuch)
                    }
                }
                .onDelete { idxSet in
                    idxSet.map { repo.fartuchy[$0].id }.forEach { repo.usunFartuch(id: $0) }
                }

                Button {
                    repo.dodajFartuch()
                } label: {
                    Label("Dodaj fartuch", systemImage: "plus.circle.fill")
                }
                .foregroundStyle(.blue)
            } header: {
                Text("Fartuchy (\(repo.fartuchy.count))")
            } footer: {
                Text("Fartuch to wykończenie ściany między blatem a szafkami. Standardowa wysokość 600 mm. Długość pobierana automatycznie z sumy ciągów dolnych projektu.")
                    .font(.caption2)
            }
        }
    }

    private var ciagiDolneAutoSectionV087:
        some View
    {
        Section {
            Button {
                repo.synchronizujZCiagamiDolnymiV087(
                    ciagiDolneV087
                )
            } label: {
                Label(
                    "Zbuduj blaty i fartuchy z ciągów",
                    systemImage:
                        "wand.and.stars"
                )
            }
            .disabled(
                ciagiDolneV087.isEmpty
            )

            if ciagiDolneV087.isEmpty {
                Text(
                    "Brak wykrytych ciągów dolnych w tym pomieszczeniu."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(ciagiDolneV087) { segment in
                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            3
                    ) {
                        Text(segment.label)
                            .font(
                                .subheadline
                                    .weight(
                                        .semibold
                                    )
                            )
                        Text(
                            "\(Int(segment.dlugoscMM.rounded())) mm · blat \(Int(max(segment.glebokoscMM + 40, 600).rounded())) mm · od \(Int(segment.startOffsetMM.rounded())) do \(Int(segment.koniecOffsetMM.rounded())) mm"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text(
                "Automatycznie z ciągów dolnych"
            )
        } footer: {
            Text(
                "Synchronizacja usuwa tylko poprzednie automatyczne pozycje. Ręcznie dodane blaty i fartuchy zostają bez zmian."
            )
            .font(.caption2)
        }
    }

    private func fartuchRow(_ f: FartuchPomieszczeniaV082) -> some View {
        let dl = f.liczyAutoZ ? bazowaDlugoscCiaguMM : f.dlugoscMM
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: f.materialTyp.systemImage)
                    .foregroundStyle(.orange)
                    .frame(width: 18)
                Text(f.nazwa)
                    .font(.headline)
            }
            Text(
                "\(f.materialTyp.rawValue)"
                + " · \(String(format: "%.0f", dl)) × \(String(format: "%.0f", f.wysokoscMM)) mm"
                + " = \(String(format: "%.2f m²", f.powierzchniaM2(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM)))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Wieńce

    private var wienceTab: some View {
        List {
            Section {
                ForEach($repo.wienceDekory) { $w in
                    NavigationLink {
                        WieniecDetailV082(
                            wieniec: $w,
                            bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM,
                            onSave: { repo.zaktualizujWieniec($w.wrappedValue) }
                        )
                    } label: {
                        wieniecRow(w)
                    }
                }
                .onDelete { idxSet in
                    idxSet.map { repo.wienceDekory[$0].id }.forEach { repo.usunWieniec(id: $0) }
                }
            } header: {
                Text("Listwy i wieńce (\(repo.wienceDekory.count))")
            }

            Section("Szybkie dodanie") {
                ForEach(WieniecTypV082.allCases) { typ in
                    Button {
                        repo.dodajWieniec(typ: typ)
                    } label: {
                        Label(typ.rawValue, systemImage: typ.systemImage)
                    }
                }
            }
        }
    }

    private func wieniecRow(_ w: WieniecDekoracyjnyV082) -> some View {
        let dl = w.dlugoscM(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: w.typ.systemImage)
                    .foregroundStyle(.purple)
                    .frame(width: 18)
                Text(w.nazwa.isEmpty ? w.typ.rawValue : w.nazwa)
                    .font(.headline)
            }
            Text("\(w.typ.rawValue) · \(String(format: "%.2f m", dl))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Blat detail

struct BlatKuchennyDetailV082: View {
    @Binding var blat: BlatKuchennyV082
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("Podstawowe") {
                TextField("Nazwa", text: $blat.nazwa)

                Picker("Kształt", selection: $blat.ksztalt) {
                    ForEach(BlatKuchennyKsztaltV082.allCases) { k in
                        Label(k.rawValue, systemImage: k.systemImage).tag(k)
                    }
                }

                Picker("Grubość", selection: $blat.grubosc) {
                    ForEach(BlatKuchennyGruboscV082.allCases) { g in
                        Text(g.label).tag(g)
                    }
                }
            }

            Section("Wymiary [mm]") {
                LabeledContent("Odcinek 1") {
                    TextField("mm", value: $blat.dlugoscCiagu1MM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                if blat.ksztalt == .L || blat.ksztalt == .U {
                    LabeledContent("Odcinek 2") {
                        TextField("mm", value: $blat.dlugoscCiagu2MM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if blat.ksztalt == .U {
                    LabeledContent("Odcinek 3") {
                        TextField("mm", value: $blat.dlugoscCiagu3MM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                LabeledContent("Szerokość (głębokość)") {
                    TextField("mm", value: $blat.szerokoscMM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent(
                    "Łącznie",
                    value: String(format: "%.0f mm = %.2f m", blat.calkowitaDlugoscMM, blat.calkowitaDlugoscM)
                )
                .foregroundStyle(.blue)
            }

            Section("Materiał") {
                TextField("Nazwa / dekor / producent", text: $blat.materialNazwa)
                    .autocorrectionDisabled()
            }

            Section("Wycięcia") {
                ForEach(BlatWyciecieV082.allCases) { w in
                    Toggle(isOn: Binding(
                        get: { blat.wycięcia.contains(w) },
                        set: { on in
                            if on {
                                blat.wycięcia.append(w)
                            } else {
                                blat.wycięcia.removeAll { $0 == w }
                            }
                        }
                    )) {
                        Label(w.rawValue, systemImage: w.systemImage)
                    }
                }
            }

            Section("Uwagi") {
                TextEditor(text: $blat.uwagi)
                    .frame(minHeight: 70)
            }
        }
        .navigationTitle(blat.nazwa.isEmpty ? "Blat" : blat.nazwa)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: blat) { _, _ in onSave() }
    }
}

// MARK: - Fartuch detail

struct FartuchDetailV082: View {
    @Binding var fartuch: FartuchPomieszczeniaV082
    let bazowaDlugoscCiaguMM: Double
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("Podstawowe") {
                TextField("Nazwa", text: $fartuch.nazwa)

                Picker("Materiał", selection: $fartuch.materialTyp) {
                    ForEach(FartuchMaterialTypV082.allCases) { m in
                        Label(m.rawValue, systemImage: m.systemImage).tag(m)
                    }
                }

                TextField("Dekor / kolor / producent", text: $fartuch.materialNazwa)
                    .autocorrectionDisabled()
            }

            Section("Geometria") {
                Toggle("Długość auto z ciągów dolnych", isOn: $fartuch.liczyAutoZ)

                if fartuch.liczyAutoZ {
                    LabeledContent("Długość (auto)", value: String(format: "%.0f mm", bazowaDlugoscCiaguMM))
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Długość [mm]") {
                        TextField("mm", value: $fartuch.dlugoscMM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                LabeledContent("Wysokość [mm]") {
                    TextField("mm", value: $fartuch.wysokoscMM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Wynik") {
                LabeledContent(
                    "Powierzchnia",
                    value: String(format: "%.2f m²", fartuch.powierzchniaM2(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM))
                )
                .foregroundStyle(.blue)
            }

            Section("Uwagi") {
                TextEditor(text: $fartuch.uwagi)
                    .frame(minHeight: 70)
            }
        }
        .navigationTitle(fartuch.nazwa)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: fartuch) { _, _ in onSave() }
    }
}

// MARK: - Wieniec detail

struct WieniecDetailV082: View {
    @Binding var wieniec: WieniecDekoracyjnyV082
    let bazowaDlugoscCiaguMM: Double
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("Podstawowe") {
                TextField("Nazwa", text: $wieniec.nazwa)

                Picker("Typ", selection: $wieniec.typ) {
                    ForEach(WieniecTypV082.allCases) { t in
                        Label(t.rawValue, systemImage: t.systemImage).tag(t)
                    }
                }
            }

            Section("Długość") {
                Toggle("Długość auto z ciągów", isOn: $wieniec.liczyAutoZ)

                if wieniec.liczyAutoZ {
                    LabeledContent("Długość (auto)", value: String(format: "%.0f mm", bazowaDlugoscCiaguMM))
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Długość [mm]") {
                        TextField("mm", value: $wieniec.dlugoscMM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                LabeledContent(
                    "Łącznie",
                    value: String(format: "%.2f m", wieniec.dlugoscM(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM))
                )
                .foregroundStyle(.blue)
            }

            Section("Materiał") {
                TextField("Profil / dekor / producent", text: $wieniec.materialNazwa)
                    .autocorrectionDisabled()
            }

            if wieniec.typ == .kanalLED {
                Section {
                    Label(
                        "Wieniec z kanałem LED wymaga frezowania. Podaj w uwagach wymiary kanału, np. 12 × 8 mm.",
                        systemImage: "lightbulb.led.wide.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("LED")
                }
            }

            Section("Uwagi") {
                TextEditor(text: $wieniec.uwagi)
                    .frame(minHeight: 70)
            }
        }
        .navigationTitle(wieniec.nazwa.isEmpty ? wieniec.typ.rawValue : wieniec.nazwa)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: wieniec) { _, _ in onSave() }
    }
}
