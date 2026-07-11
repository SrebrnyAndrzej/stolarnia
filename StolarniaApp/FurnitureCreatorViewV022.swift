import SwiftUI

struct FurnitureCreatorViewV022: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var draft =
        FurnitureCreatorDraftV018()

    @State private var ksztaltMebla = KsztaltMeblaV080()

    @State private var wardrobeLayout =
        WardrobeCompartmentLayoutV022.defaultLayout(
            draftID: UUID(),
            widthMM: 1_200,
            bayCount: 2
        )

    @State private var step:
        StepV021 = .type

    @State private var message: String?
    @State private var isSavingTemplate = false

    @State private var technicalCard:
        KartaTechnicznaSzafki?

    @StateObject private var bazaMaterialowV022 =
        BazaMaterialowRepository()

    let onSaveTemplate:
        (FurnitureCreatorDraftV018) async -> Bool

    init(
        onSaveTemplate:
            @escaping (
                FurnitureCreatorDraftV018
            ) async -> Bool
    ) {
        self.onSaveTemplate = onSaveTemplate
    }

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(
                    StepV021.allCases
                ) { item in
                    Button {
                        step = item
                    } label: {
                        HStack {
                            Label(
                                item.title,
                                systemImage:
                                    item.icon
                            )

                            Spacer()

                            if step == item {
                                Image(
                                    systemName:
                                        "checkmark.circle.fill"
                                )
                                .foregroundStyle(
                                    .tint
                                )
                            }
                        }
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(
                "Kreator mebla"
            )
        } detail: {
            VStack(spacing: 0) {
                if step == .ksztalt {
                    KsztaltMeblaCanvasV080(ksztalt: $ksztaltMebla)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        technicalPreview
                            .frame(minWidth: 360)

                        Divider()

                        Form {
                            editor
                        }
                        .frame(minWidth: 420)
                    }
                }

                Divider()
                validationBar
            }
            .navigationTitle(draft.name)
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(
                    placement:
                        .primaryAction
                ) {
                    Button {
                        draft.normalize()

                        let card =
                            KartaTechnicznaSzafkiBuilder
                                .build(
                                    from: draft
                                )

                        technicalCard =
                            KartaTechnicznaSzafkiStore
                                .card(
                                    for: draft.id
                                )
                            ?? card
                    } label: {
                        Label(
                            "Karta techniczna",
                            systemImage:
                                "doc.text.magnifyingglass"
                        )
                    }

                    Button {
                        Task {
                            draft.normalize()

                            guard draft
                                .validationMessages
                                .isEmpty
                            else {
                                message =
                                    "Popraw błędy przed zapisaniem."
                                return
                            }

                            isSavingTemplate = true
                            defer {
                                isSavingTemplate = false
                            }

                            FurnitureCreatorLocalStoreV018
                                .save(draft)

                            let generatedCard =
                                KartaTechnicznaSzafkiBuilder
                                    .build(
                                        from: draft
                                    )

                            KartaTechnicznaSzafkiStore
                                .save(
                                    generatedCard
                                )

                            wardrobeLayout.draftID =
                                draft.id
                            wardrobeLayout.cabinetWidthMM =
                                draft.widthMM
                            wardrobeLayout.normalizeOrders()
                            WardrobeCompartmentStoreV022.save(
                                wardrobeLayout
                            )

                            let didSave =
                                await onSaveTemplate(
                                    draft
                                )

                            message = didSave
                                ? "Szablon zapisano w bibliotece."
                                : "Nie udało się zapisać szablonu."
                        }
                    } label: {
                        if isSavingTemplate {
                            ProgressView()
                        } else {
                            Text(
                                "Zapisz w bibliotece"
                            )
                        }
                    }
                    .disabled(
                        isSavingTemplate
                    )
                }
            }
            .alert(
                "Kreator mebla",
                isPresented: Binding(
                    get: {
                        message != nil
                    },
                    set: {
                        if !$0 {
                            message = nil
                        }
                    }
                )
            ) {
                Button(
                    "OK",
                    role: .cancel
                ) {}
            } message: {
                Text(message ?? "")
            }
        }
        .sheet(
            item: $technicalCard
        ) { card in
            KartaTechnicznaSzafkiView(
                card: card
            )
        }
        .onAppear {
            draft.normalize()

            if let saved =
                WardrobeCompartmentStoreV022.load(
                    draftID: draft.id
                ) {
                wardrobeLayout = saved
            } else {
                wardrobeLayout =
                    WardrobeCompartmentLayoutV022.defaultLayout(
                        draftID: draft.id,
                        widthMM: draft.widthMM,
                        bayCount:
                            draft.wardrobeV021?
                                .bayCount
                            ?? 2
                    )
            }
        }
        .onChange(
            of: draft.widthMM
        ) {
            draft.normalize()
            wardrobeLayout.resizeToCabinet(
                widthMM: draft.widthMM
            )
        }
        .onChange(
            of: draft.heightMM
        ) {
            draft.normalize()
        }
        .onChange(
            of: draft.segmentCount
        ) {
            draft.normalize()
        }
        .onChange(
            of: draft.spaceTower.frontCount
        ) {
            draft.normalize()
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch step {
        case .type:
            typeSection

        case .ksztalt:
            ksztaltSection

        case .dimensions:
            dimensionsSection

        case .structure:
            structureSection

        case .compartments:
            compartmentSection

        case .fronts:
            frontSection

        case .materials:
            materialSection

        case .summary:
            summarySection
        }
    }

    private var ksztaltSection: some View {
        Section("Kształt niestandardowy") {
            if ksztaltMebla.punkty.isEmpty {
                Label("Rysuj kształt mebla na canvasie po lewej", systemImage: "pencil.tip")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Label("\(ksztaltMebla.punkty.count) punktów", systemImage: "point.3.connected.trianglepath.dotted")
                if ksztaltMebla.zamkniety {
                    Label(String(format: "Powierzchnia: %.3f m²", ksztaltMebla.powierzchniaM2), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                ForEach(ksztaltMebla.odcinki) { o in
                    HStack {
                        Text("Odcinek")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(o.dlugoscMM.rounded())) mm @ \(Int(o.katStopnie.rounded()))°")
                            .font(.caption.monospaced())
                    }
                }
            }
        }
    }

    private var typeSection:
        some View
    {
        Section("Rodzaj konstrukcji") {
            TextField(
                "Nazwa",
                text: $draft.name
            )

            Picker(
                "Konstrukcja",
                selection:
                    constructionBinding
            ) {
                ForEach(
                    FurnitureConstructionKindV021
                        .allCases
                ) {
                    Text($0.title)
                        .tag($0)
                }
            }
        }
    }

    private var dimensionsSection:
        some View
    {
        Section("Gabaryty") {
            numberField(
                "Szerokość [mm]",
                value: $draft.widthMM
            )

            numberField(
                "Wysokość [mm]",
                value: $draft.heightMM
            )

            numberField(
                "Głębokość [mm]",
                value: $draft.depthMM
            )
        }
    }

    @ViewBuilder
    private var structureSection:
        some View
    {
        switch draft
            .effectiveConstructionKind {
        case .spaceTower:
            spaceTowerSection

        case .hingedWardrobe,
             .slidingWardrobe,
             .dressingRoomOpen:
            wardrobeSection

        case .kitchenCabinet:
            kitchenBaseSection

        case .customCarcass:
            customStructureSection
        }
    }

    private var kitchenBaseSection:
        some View
    {
        Section("Ciąg dolny") {
            Picker(
                "Podstawa",
                selection:
                    $draft.baseHeightSystem
                        .supportKind
            ) {
                ForEach(
                    CabinetBaseSupportKindV018
                        .allCases
                ) {
                    Text($0.title)
                        .tag($0)
                }
            }
            .onChange(
                of: draft
                    .baseHeightSystem
                    .supportKind
            ) {
                recalculateBase()
            }

            numberField(
                "Docelowa wysokość blatu [mm]",
                value:
                    $draft.baseHeightSystem
                        .targetWorktopHeightMM
            )
            .onChange(
                of: draft
                    .baseHeightSystem
                    .targetWorktopHeightMM
            ) {
                recalculateBase()
            }

            numberField(
                "Wysokość nóżek [mm]",
                value:
                    $draft.baseHeightSystem
                        .legHeightMM
            )
            .disabled(
                draft.baseHeightSystem
                    .supportKind
                    == .floorStanding
            )
            .onChange(
                of: draft
                    .baseHeightSystem
                    .legHeightMM
            ) {
                recalculateBase()
            }

            numberField(
                "Grubość blatu [mm]",
                value:
                    $draft.baseHeightSystem
                        .countertopThicknessMM
            )
            .onChange(
                of: draft
                    .baseHeightSystem
                    .countertopThicknessMM
            ) {
                recalculateBase()
            }

            LabeledContent(
                "Wyliczony korpus",
                value:
                    "\(Int(draft.baseHeightSystem.carcassHeightMM.rounded())) mm"
            )
        }
    }

    private var spaceTowerSection:
        some View
    {
        Section(
            "SPACE TOWER — 3 strefy pionowe"
        ) {
            Text(
                "Strefy są ustawiane jedna nad drugą: dolna, środkowa i górna."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Stepper(
                "Szuflady łącznie: \(draft.spaceTower.totalDrawerCount)",
                value:
                    $draft.spaceTower
                        .totalDrawerCount,
                in: 5...7
            )
            .onChange(
                of: draft.spaceTower
                    .totalDrawerCount
            ) {
                draft.spaceTower
                    .normalize(
                        totalHeightMM:
                            draft.heightMM
                    )
            }

            Stepper(
                "Szuflady dolne: \(draft.spaceTower.lowerZoneDrawerCount)",
                value:
                    $draft.spaceTower
                        .lowerZoneDrawerCount,
                in: 2...5
            )
            .onChange(
                of: draft.spaceTower
                    .lowerZoneDrawerCount
            ) {
                draft.spaceTower
                    .normalize(
                        totalHeightMM:
                            draft.heightMM
                    )
            }

            LabeledContent(
                "Szuflady środkowe",
                value:
                    "\(draft.spaceTower.middleZoneDrawerCount)"
            )

            Picker(
                "Górna strefa",
                selection:
                    $draft.spaceTower
                        .upperZone
            ) {
                ForEach(
                    SpaceTowerUpperZoneV018
                        .allCases
                ) {
                    Text($0.title)
                        .tag($0)
                }
            }

            if draft.spaceTower
                .upperZone == .shelves {
                Stepper(
                    "Półki górne: \(draft.spaceTower.upperShelfCount)",
                    value:
                        $draft.spaceTower
                            .upperShelfCount,
                    in: 1...5
                )
            }

            Divider()

            zoneHeightField(
                "Wysokość strefy dolnej [mm]",
                value:
                    zoneBinding(
                        \.lowerZoneHeightMM
                    )
            )

            zoneHeightField(
                "Wysokość strefy środkowej [mm]",
                value:
                    zoneBinding(
                        \.middleZoneHeightMM
                    )
            )

            zoneHeightField(
                "Wysokość strefy górnej [mm]",
                value:
                    zoneBinding(
                        \.upperZoneHeightMM
                    )
            )

            LabeledContent(
                "Suma stref",
                value:
                    "\(Int(draft.spaceTower.zoneHeightSumMM.rounded())) mm"
            )

            Button(
                "Dopasuj strefy do korpusu"
            ) {
                draft.spaceTower
                    .normalizeZoneHeights(
                        totalHeightMM:
                            draft.heightMM
                    )
            }

            Picker(
                "Liczba frontów",
                selection:
                    $draft.spaceTower
                        .frontCount
            ) {
                Text("2 fronty")
                    .tag(2)
                Text("3 fronty")
                    .tag(3)
            }
        }
    }

    @ViewBuilder
    private var wardrobeSection:
        some View
    {
        Section(
            draft.effectiveConstructionKind
                == .dressingRoomOpen
            ? "Garderoba"
            : "Szafa"
        ) {
            Stepper(
                "Przegrody pionowe: \(wardrobeBinding.bayCount.wrappedValue)",
                value:
                    wardrobeBinding
                        .bayCount,
                in: 1...4
            )

            Stepper(
                "Półki w przegrodzie: \(wardrobeBinding.shelfCountPerBay.wrappedValue)",
                value:
                    wardrobeBinding
                        .shelfCountPerBay,
                in: 0...8
            )

            Stepper(
                "Szuflady: \(wardrobeBinding.drawerCount.wrappedValue)",
                value:
                    wardrobeBinding
                        .drawerCount,
                in: 0...8
            )

            Toggle(
                "Drążek ubraniowy",
                isOn:
                    wardrobeBinding
                        .hangingRailEnabled
            )

            if draft
                .effectiveConstructionKind
                == .slidingWardrobe {
                Stepper(
                    "Skrzydła przesuwne: \(wardrobeBinding.slidingDoorCount.wrappedValue)",
                    value:
                        wardrobeBinding
                            .slidingDoorCount,
                    in: 2...4
                )
            }

            Text(
                draft.effectiveConstructionKind
                    == .slidingWardrobe
                ? "Skrzydła są rysowane na dwóch torach i częściowo na siebie zachodzą."
                : "Przegrody dzielą korpus na pionowe komory."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // Dedykowana sekcja konfiguracji systemu przesuwnego
        if draft.effectiveConstructionKind == .slidingWardrobe {
            slidingSystemSection
        }
    }

    @ViewBuilder
    private var slidingSystemSection: some View {
        let binding = Binding(
            get: { draft.systemPrzesuwnV075 ?? SzafaPrzesuwnaDefinicjaV075() },
            set: { draft.systemPrzesuwnV075 = $0 }
        )

        Section("System drzwi przesuwnych") {
            Picker("System profili", selection: binding.systemProfili) {
                ForEach(SystemProfiluSzafyPrzesuwanej.allCases) { s in
                    Text(s.nazwa).tag(s)
                }
            }

            Picker("Konstrukcja drzwi", selection: binding.konstrukjaDrzwi) {
                ForEach(KonstrukcjaDrzwiPrzesuwnychV075.allCases) { k in
                    Text(k.nazwa).tag(k)
                }
            }

            Picker("System toru", selection: binding.systemToru) {
                ForEach(TorSzafyPrzesuwanej.allCases) { t in
                    Text(t.nazwa).tag(t)
                }
            }

            HStack {
                Text("Zachód skrzydeł [mm]")
                Spacer()
                TextField("mm", value: binding.zachodMM, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Grubość drzwi [mm]")
                Spacer()
                TextField("mm", value: binding.gruboscDrzwiMM, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            Toggle("Miękkie zamykanie", isOn: binding.miekkieZamykanie)
            Toggle("Soft-close", isOn: binding.systemSoftClose)

            Picker("Typ uchwytu", selection: binding.uchwytTyp) {
                ForEach(TypUchwytuwProjekcie.allCases) { t in
                    Label(t.nazwa, systemImage: t.systemImage).tag(t)
                }
            }
        }

        // Wypełnienie drzwi (płyta / lustro / szkło z katalogu Bonari)
        Section {
            let lista = BonariKatalog.wypelnienia(dla: binding.konstrukjaDrzwi.wrappedValue)

            if lista.isEmpty {
                Picker("Wypełnienie", selection: binding.wypelnienieDrzwiID) {
                    Text("Według konstrukcji drzwi").tag("")
                }
                .disabled(true)
                Text("Katalog Bonari nie ma pozycji dla tej konstrukcji. Waga liczona wg typu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Wypełnienie drzwi", selection: binding.wypelnienieDrzwiID) {
                    Text("Według konstrukcji (uproszczone)").tag("")
                    ForEach(lista) { w in
                        HStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(stolarniaHEX: w.kolorHEX))
                                .frame(width: 14, height: 14)
                            Text("\(w.nazwa) \(Int(w.gruboscMM)) mm — \(String(format: "%.0f", w.wagaKgM2)) kg/m²")
                        }
                        .tag(w.id)
                    }
                }
                if !binding.wypelnienieDrzwiID.wrappedValue.isEmpty,
                   let w = lista.first(where: { $0.id == binding.wypelnienieDrzwiID.wrappedValue }) {
                    Label(
                        "Max tafla: \(Int(w.maxSzerokoscMM)) × \(Int(w.maxWysokoscMM)) mm",
                        systemImage: "ruler"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Wypełnienie drzwi", systemImage: "square.fill")
        } footer: {
            Text("Wybierz konkretne wypełnienie aby uzyskać precyzyjną wagę i ostrzeżenia o max. tafli.")
                .font(.caption2)
        }

        // Tryb montażu
        Section {
            Picker("Tryb montażu", selection: binding.trybMontazu) {
                ForEach(TrybMontazuSzafyPrzesuwanej.allCases) { tryb in
                    Text(tryb.nazwa).tag(tryb)
                }
            }
            if binding.trybMontazu.wrappedValue != .wolnostojacaSzafa {
                Text(binding.trybMontazu.wrappedValue.opis)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Montaż", systemImage: "arrow.left.to.line.compact")
        }

        // Listwy przymykowe — widoczne tylko w trybie dostawionym
        if binding.trybMontazu.wrappedValue != .wolnostojacaSzafa {
            listwaPrzymykowaSection(binding: binding)
        }

        // Podgląd obliczonych wymiarów skrzydła
        if let sys = draft.systemPrzesuwnV075 {
            let raport = SilnikSzafyPrzesuwanejV075.raport(dla: sys)

            Section("Obliczone wymiary skrzydła") {
                LabeledContent(
                    "Szerokość skrzydła",
                    value: "\(Int(sys.szerokoscSkrzydlaMM)) mm"
                )
                LabeledContent(
                    "Wysokość skrzydła",
                    value: "\(Int(sys.wysokoscSkrzydlaMM)) mm"
                )
                LabeledContent(
                    "Powierzchnia drzwi łącznie",
                    value: String(format: "%.2f m²", raport.sumaLisciM2)
                )
                LabeledContent(
                    "Szacunkowa waga drzwi",
                    value: String(format: "%.1f kg", raport.sumaWagaKg)
                )

                if !raport.ostrzezenia.isEmpty {
                    ForEach(raport.ostrzezenia, id: \.self) { uwaga in
                        Label(uwaga, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("BOM systemu drzwi") {
                ForEach(raport.elementy) { el in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(el.opis)
                                .font(.caption.weight(.medium))
                            if !el.wymiarOpis.isEmpty {
                                Text(el.wymiarOpis)
                                    .font(.caption2)
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
        }
    }

    @ViewBuilder
    private func listwaPrzymykowaSection(
        binding: Binding<SzafaPrzesuwnaDefinicjaV075>
    ) -> some View {
        Section {
            let sys = binding.wrappedValue
            let minMM = sys.sugerowanaListwaMM

            // Info o zalecanej szerokości
            Label(
                "Zalecana min. szerokość listwy: \(Int(minMM)) mm (skrzydło \(Int(sys.szerokoscSkrzydlaMM)) mm − zachód \(Int(sys.zachodMM)) mm + 20 mm)",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            // Listwa prawa (strona ściany)
            let maLewą  = sys.listwPrzymykowe.contains { $0.strona == .lewa }
            let maPrawą = sys.listwPrzymykowe.contains { $0.strona == .prawa }

            // Toggle prawa
            Toggle("Listwa przymykowa — prawa (ściana)", isOn: Binding(
                get: { maPrawą },
                set: { on in
                    if on {
                        binding.wrappedValue.dodajDomyslnaListwePrzymykowaPrawą()
                    } else {
                        binding.wrappedValue.usunListwePrzymykowa(strona: .prawa)
                    }
                }
            ))

            if maPrawą, let idx = sys.listwPrzymykowe.firstIndex(where: { $0.strona == .prawa }) {
                listwaSzerokoscRow(
                    label: "Szerokość (prawa)",
                    binding: Binding(
                        get: { binding.wrappedValue.listwPrzymykowe[idx].szerokoscMM },
                        set: { binding.wrappedValue.listwPrzymykowe[idx].szerokoscMM = $0 }
                    ),
                    minMM: minMM
                )
                Toggle(
                    "Mocowanie do ściany",
                    isOn: Binding(
                        get: { binding.wrappedValue.listwPrzymykowe[idx].mocowanieDoSciany },
                        set: { binding.wrappedValue.listwPrzymykowe[idx].mocowanieDoSciany = $0 }
                    )
                )
            }

            // Toggle lewa (strona szafy / drugi mebel)
            if binding.trybMontazu.wrappedValue == .miedzyDwamiSzafkami {
                Toggle("Listwa przymykowa — lewa (2. szafka)", isOn: Binding(
                    get: { maLewą },
                    set: { on in
                        if on {
                            binding.wrappedValue.dodajDomyslnaListwePrzymykowaLewa()
                        } else {
                            binding.wrappedValue.usunListwePrzymykowa(strona: .lewa)
                        }
                    }
                ))

                if maLewą, let idx = sys.listwPrzymykowe.firstIndex(where: { $0.strona == .lewa }) {
                    listwaSzerokoscRow(
                        label: "Szerokość (lewa)",
                        binding: Binding(
                            get: { binding.wrappedValue.listwPrzymykowe[idx].szerokoscMM },
                            set: { binding.wrappedValue.listwPrzymykowe[idx].szerokoscMM = $0 }
                        ),
                        minMM: minMM
                    )
                }
            }
        } header: {
            Label("Listwa przymykowa", systemImage: "rectangle.portrait.lefthalf.inset.filled")
        } footer: {
            Text("Listwa przymykowa zakrywa otwarte skrzydło od strony ściany lub boku sąsiedniego mebla.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private func listwaSzerokoscRow(
        label: String,
        binding: Binding<Double>,
        minMM: Double
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("mm", value: binding, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .foregroundStyle(binding.wrappedValue < minMM ? .orange : .primary)
            Text("mm")
                .foregroundStyle(.secondary)
        }
        if binding.wrappedValue < minMM {
            Label(
                "Poniżej zalecanych \(Int(minMM)) mm",
                systemImage: "exclamationmark.triangle"
            )
            .font(.caption2)
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var customStructureSection:
        some View
    {
        Section("Korpus własny") {
            Stepper(
                "Przegrody pionowe: \(draft.segmentCount)",
                value:
                    $draft.segmentCount,
                in: 1...8
            )

            Text(
                "Przegrody dzielą szerokość korpusu na komory. Użyj wnęk poniżej, aby zarezerwować przestrzeń na urządzenia lub specjalne wyposażenie."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section {
            if draft.wneki.isEmpty {
                Label(
                    "Brak wnęk specjalnych. Dodaj wnękę, aby zarezerwować przestrzeń np. na odkurzacz, stację ładowania lub buty.",
                    systemImage: "square.dashed"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    $draft.wneki
                ) { $wneka in
                    wnekaRow($wneka)
                }
                .onDelete { offsets in
                    draft.wneki.remove(atOffsets: offsets)
                }
            }

            Menu {
                Button {
                    draft.wneki.append(WnekaSpecjalnaV080())
                } label: {
                    Label("Pusta wnęka", systemImage: "plus")
                }

                Divider()
                Text("Gotowe szablony")

                ForEach(WnekaSpecjalnaV080.szablony, id: \.etykieta) { szablon in
                    Button {
                        draft.wneki.append(szablon)
                    } label: {
                        Label(szablon.etykieta, systemImage: "sparkles")
                    }
                }
            } label: {
                Label("Dodaj wnękę specjalną", systemImage: "plus.rectangle.on.folder")
            }
        } header: {
            Label("Wnęki specjalne", systemImage: "square.split.bottomrightquarter")
        } footer: {
            if !draft.wneki.isEmpty {
                Text("Wymiary wnęk pojawiają się na karcie technicznej i w notatkach produkcyjnych. Nie zmieniają automatycznie rozkroju płyt.")
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private func wnekaRow(
        _ wneka: Binding<WnekaSpecjalnaV080>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                "Etykieta, np. iRobot j7+",
                text: wneka.etykieta
            )
            .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Szer.").font(.caption2).foregroundStyle(.secondary)
                    TextField(
                        "mm",
                        value: wneka.szerokoscMM,
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wys.").font(.caption2).foregroundStyle(.secondary)
                    TextField(
                        "mm",
                        value: wneka.wysokoscMM,
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Głęb.").font(.caption2).foregroundStyle(.secondary)
                    TextField(
                        "mm",
                        value: wneka.glebokoscMM,
                        format: .number.precision(.fractionLength(0))
                    )
                    .keyboardType(.numberPad)
                    .frame(maxWidth: .infinity)
                }
            }

            numberField(
                "Od podłogi mebla [mm]",
                value: wneka.odPodlogiMM
            )

            Toggle(
                "Otwarta z przodu (bez drzwiczek)",
                isOn: wneka.otwartaZPrzodu
            )

            TextField(
                "Uwagi dla stolarza",
                text: wneka.uwagi,
                axis: .vertical
            )
            .font(.caption)

            if !wneka.wrappedValue.bladyWalidacji.isEmpty {
                ForEach(
                    wneka.wrappedValue.bladyWalidacji,
                    id: \.self
                ) { blad in
                    Label(blad, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var compartmentSection:
        some View
    {
        Section(
            "Komory szafy i garderoby"
        ) {
            if !isWardrobeLike {
                Text(
                    "Edytor komór jest dostępny dla szafy uchylnej, przesuwnej i garderoby."
                )
                .foregroundStyle(.secondary)
            } else {
                Stepper(
                    "Liczba komór: \(wardrobeLayout.compartments.count)",
                    value:
                        Binding(
                            get: {
                                wardrobeLayout
                                    .compartments
                                    .count
                            },
                            set: {
                                wardrobeLayout
                                    .setCompartmentCount(
                                        $0
                                    )
                                syncWardrobeBayCount()
                            }
                        ),
                    in: 1...4
                )

                numberField(
                    "Grubość przegrody [mm]",
                    value:
                        $wardrobeLayout
                            .dividerThicknessMM
                )
                .onChange(
                    of: wardrobeLayout
                        .dividerThicknessMM
                ) {
                    wardrobeLayout
                        .distributeEvenly()
                }

                Button(
                    "Rozdziel szerokość równomiernie"
                ) {
                    wardrobeLayout
                        .distributeEvenly()
                }

                LabeledContent(
                    "Dostępna szerokość komór",
                    value:
                        "\(Int(wardrobeLayout.availableCompartmentWidthMM.rounded())) mm"
                )

                LabeledContent(
                    "Suma szerokości komór",
                    value:
                        "\(Int(wardrobeLayout.totalCompartmentWidthMM.rounded())) mm"
                )

                ForEach(
                    $wardrobeLayout.compartments
                ) { $compartment in
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Text(
                            "Komora \(compartment.order + 1)"
                        )
                        .font(.headline)

                        numberField(
                            "Szerokość [mm]",
                            value:
                                $compartment
                                    .widthMM
                        )

                        Stepper(
                            "Półki: \(compartment.shelfCount)",
                            value:
                                $compartment
                                    .shelfCount,
                            in: 0...10
                        )

                        Toggle(
                            "Górna półka",
                            isOn:
                                $compartment
                                    .topShelfEnabled
                        )

                        Toggle(
                            "Drążek ubraniowy",
                            isOn:
                                $compartment
                                    .hangingRailEnabled
                        )

                        Stepper(
                            "Szuflady: \(compartment.drawerCount)",
                            value:
                                $compartment
                                    .drawerCount,
                            in: 0...8
                        )

                        if compartment.drawerCount > 0 {
                            numberField(
                                "Wysokość strefy szuflad [mm]",
                                value:
                                    $compartment
                                        .drawerZoneHeightMM
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var frontSection:
        some View
    {
        Section(
            "Fronty i kierunek otwierania"
        ) {
            if draft.effectiveConstructionKind
                == .dressingRoomOpen {
                Text(
                    "Garderoba otwarta nie wymaga frontów."
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    $draft.fronts
                ) { $front in
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Text(
                            "Front \(front.segmentIndex + 1)"
                        )
                        .font(.headline)

                        Picker(
                            "Otwieranie",
                            selection:
                                $front.openingKind
                        ) {
                            ForEach(
                                FurnitureFrontOpeningKindV018
                                    .allCases
                            ) {
                                Text($0.title)
                                    .tag($0)
                            }
                        }

                        if front.openingKind
                            == .leftHinged
                            || front.openingKind
                                == .rightHinged {
                            Slider(
                                value:
                                    $front.openingAngleDegrees,
                                in: 80...120,
                                step: 5
                            )

                            Text(
                                "Kąt: \(Int(front.openingAngleDegrees))°"
                            )
                            .font(.caption)
                        }

                        Picker(
                            "Kolor frontu",
                            selection:
                                $front.material
                        ) {
                            ForEach(
                                FurnitureFinishPresetV018
                                    .allCases
                            ) {
                                Text($0.title)
                                    .tag($0)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    @ViewBuilder
    private var materialSection:
        some View
    {
        // Wybór koloru z presetów (zachowany dla kompatybilności)
        Section("Kolor (wzornik uproszczony)") {
            finishPicker(
                "Korpus",
                selection:
                    $draft.carcassFinish
            )

            finishPicker(
                "Front",
                selection:
                    $draft.frontFinish
            )

            Label(
                "Materiał z bazy można wybrać w sekcji poniżej.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // Powiązanie z BazaMaterialow
        materialZBazySection
    }

    @ViewBuilder
    private var materialZBazySection: some View {
        Section {
            materialPickerRow(
                label: "Korpus z bazy",
                systemImage: "shippingbox",
                selectedID: $draft.korpusMaterialID,
                types: [.plytaLaminowana, .mdf, .hdf, .sklejka]
            )

            materialPickerRow(
                label: "Front z bazy",
                systemImage: "door.left.hand.closed",
                selectedID: $draft.frontMaterialID,
                types: [.front, .mdf, .plytaLaminowana]
            )
        } header: {
            Text("Materiał z bazy (opcjonalnie)")
        } footer: {
            Text("Materiał z bazy zastępuje wzornik uproszczony w wycenie i karcie technicznej.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private func materialPickerRow(
        label: String,
        systemImage: String,
        selectedID: Binding<UUID?>,
        types: [TypMaterialuStolarskiego]
    ) -> some View {
        let materialy = bazaMaterialowV022.materialy.filter {
            $0.aktywny && types.contains($0.typ)
        }
        let wybrany = selectedID.wrappedValue.flatMap { id in
            materialy.first { $0.id == id }
        }

        HStack(spacing: 10) {
            if let mat = wybrany {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(stolarniaHEX: mat.kolorHEX))
                    .frame(width: 28, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.secondary.opacity(0.25))
                    }
            } else {
                Image(systemName: systemImage)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }

            Picker(label, selection: selectedID) {
                Text("Nie wybrano").tag(Optional<UUID>.none)
                ForEach(materialy) { mat in
                    Text("\(mat.producent) \(mat.nazwa)")
                        .tag(Optional(mat.id))
                }
            }
        }
    }

    private var summarySection:
        some View
    {
        Section("Podsumowanie") {
            LabeledContent(
                "Konstrukcja",
                value:
                    draft.effectiveConstructionKind
                        .title
            )

            LabeledContent(
                "Gabaryty",
                value:
                    "\(Int(draft.widthMM)) × \(Int(draft.heightMM)) × \(Int(draft.depthMM)) mm"
            )

            LabeledContent(
                "Fronty",
                value:
                    "\(draft.fronts.count)"
            )

            if draft
                .effectiveConstructionKind
                == .spaceTower {
                LabeledContent(
                    "SPACE TOWER",
                    value:
                        "\(draft.spaceTower.totalDrawerCount) szuflad / \(draft.spaceTower.frontCount) fronty"
                )
            }

            if draft
                .effectiveConstructionKind
                == .slidingWardrobe {
                LabeledContent(
                    "Skrzydła przesuwne",
                    value:
                        "\(wardrobeBinding.slidingDoorCount.wrappedValue)"
                )
            }
        }
    }

    private var technicalPreview:
        some View
    {
        GeometryReader { proxy in
            let rect = previewRect(
                in: proxy.size
            )

            ZStack {
                RoundedRectangle(
                    cornerRadius: 8
                )
                .fill(
                    draft.carcassFinish
                        .color
                        .opacity(0.24)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 8
                    )
                    .stroke(
                        .primary,
                        lineWidth: 2
                    )
                )
                .frame(
                    width: rect.width,
                    height: rect.height
                )
                .position(
                    x: rect.midX,
                    y: rect.midY
                )

                technicalGeometry(
                    in: rect
                )

                VStack {
                    Text(draft.name)
                        .font(.headline)

                    Text(
                        "\(Int(draft.widthMM)) × \(Int(draft.heightMM)) × \(Int(draft.depthMM)) mm"
                    )
                    .font(
                        .caption
                            .monospacedDigit()
                    )
                }
                .position(
                    x: rect.midX,
                    y: rect.maxY + 38
                )
            }
        }
        .padding()
        .background(
            Color(
                uiColor:
                    .secondarySystemBackground
            )
        )
    }

    @ViewBuilder
    private func technicalGeometry(
        in rect: CGRect
    ) -> some View {
        switch draft
            .effectiveConstructionKind {
        case .spaceTower:
            spaceTowerPreview(
                in: rect
            )

        case .hingedWardrobe:
            wardrobePreview(
                in: rect,
                sliding: false,
                open: false
            )

        case .slidingWardrobe:
            wardrobePreview(
                in: rect,
                sliding: true,
                open: false
            )

        case .dressingRoomOpen:
            wardrobePreview(
                in: rect,
                sliding: false,
                open: true
            )

        default:
            standardPreview(
                in: rect
            )
        }
    }

    @ViewBuilder
    private func spaceTowerPreview(
        in rect: CGRect
    ) -> some View {
        let usable =
            max(
                draft.spaceTower
                    .zoneHeightSumMM,
                1
            )

        let upperHeight =
            rect.height
            * CGFloat(
                (draft.spaceTower
                    .upperZoneHeightMM
                    ?? 0)
                / usable
            )

        let middleHeight =
            rect.height
            * CGFloat(
                (draft.spaceTower
                    .middleZoneHeightMM
                    ?? 0)
                / usable
            )

        let upperBottom =
            rect.minY + upperHeight

        let middleBottom =
            upperBottom + middleHeight

        Path { path in
            path.move(
                to: CGPoint(
                    x: rect.minX,
                    y: upperBottom
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX,
                    y: upperBottom
                )
            )

            path.move(
                to: CGPoint(
                    x: rect.minX,
                    y: middleBottom
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX,
                    y: middleBottom
                )
            )
        }
        .stroke(
            .blue,
            style: StrokeStyle(
                lineWidth: 2,
                dash: [6, 4]
            )
        )

        drawerLines(
            count:
                draft.spaceTower
                    .middleZoneDrawerCount,
            minY: upperBottom,
            maxY: middleBottom,
            rect: rect
        )

        drawerLines(
            count:
                draft.spaceTower
                    .lowerZoneDrawerCount,
            minY: middleBottom,
            maxY: rect.maxY,
            rect: rect
        )

        if draft.spaceTower
            .upperZone == .shelves {
            drawerLines(
                count:
                    draft.spaceTower
                        .upperShelfCount + 1,
                minY: rect.minY,
                maxY: upperBottom,
                rect: rect
            )
        }

        Text(
            "\(Int(draft.spaceTower.upperZoneHeightMM ?? 0)) mm"
        )
        .font(.caption2)
        .position(
            x: rect.maxX + 34,
            y:
                rect.minY
                + upperHeight / 2
        )

        Text(
            "\(Int(draft.spaceTower.middleZoneHeightMM ?? 0)) mm"
        )
        .font(.caption2)
        .position(
            x: rect.maxX + 34,
            y:
                upperBottom
                + middleHeight / 2
        )

        Text(
            "\(Int(draft.spaceTower.lowerZoneHeightMM ?? 0)) mm"
        )
        .font(.caption2)
        .position(
            x: rect.maxX + 34,
            y:
                middleBottom
                + (
                    rect.maxY
                    - middleBottom
                ) / 2
        )

        frontSymbols(
            in: rect
        )
    }

    @ViewBuilder
    private func wardrobePreview(
        in rect: CGRect,
        sliding: Bool,
        open: Bool
    ) -> some View {
        let compartments =
            wardrobeLayout.compartments
        let totalWidth = max(
            wardrobeLayout.totalCompartmentWidthMM,
            1
        )

        ForEach(
            Array(compartments.dropLast()),
            id: \.id
        ) { compartment in
            let previousWidth =
                compartments
                    .filter {
                        $0.order
                        <= compartment.order
                    }
                    .reduce(0) {
                        $0 + $1.widthMM
                    }

            let x =
                rect.minX
                + rect.width
                * CGFloat(
                    previousWidth
                    / totalWidth
                )

            Path { path in
                path.move(
                    to: CGPoint(
                        x: x,
                        y: rect.minY
                    )
                )
                path.addLine(
                    to: CGPoint(
                        x: x,
                        y: rect.maxY
                    )
                )
            }
            .stroke(
                .secondary,
                lineWidth: 1
            )
        }

        ForEach(
            Array(compartments.enumerated()),
            id: \.element.id
        ) { index, compartment in
            let preceding =
                compartments
                    .prefix(index)
                    .reduce(0) {
                        $0 + $1.widthMM
                    }

            let compartmentMinX =
                rect.minX
                + rect.width
                * CGFloat(
                    preceding
                    / totalWidth
                )

            let compartmentWidth =
                rect.width
                * CGFloat(
                    compartment.widthMM
                    / totalWidth
                )

            if compartment.topShelfEnabled {
                Path { path in
                    let y =
                        rect.minY
                        + rect.height * 0.16

                    path.move(
                        to: CGPoint(
                            x: compartmentMinX,
                            y: y
                        )
                    )
                    path.addLine(
                        to: CGPoint(
                            x:
                                compartmentMinX
                                + compartmentWidth,
                            y: y
                        )
                    )
                }
                .stroke(
                    .secondary,
                    lineWidth: 1
                )
            }

            if compartment.shelfCount > 0 {
                ForEach(
                    1...compartment.shelfCount,
                    id: \.self
                ) { shelfIndex in
                    let y =
                        rect.minY
                        + rect.height
                        * (
                            0.22
                            + 0.62
                            * CGFloat(shelfIndex)
                            / CGFloat(
                                compartment.shelfCount
                                + 1
                            )
                        )

                    Path { path in
                        path.move(
                            to: CGPoint(
                                x:
                                    compartmentMinX,
                                y: y
                            )
                        )
                        path.addLine(
                            to: CGPoint(
                                x:
                                    compartmentMinX
                                    + compartmentWidth,
                                y: y
                            )
                        )
                    }
                    .stroke(
                        .secondary
                            .opacity(0.55),
                        lineWidth: 1
                    )
                }
            }

            if compartment.hangingRailEnabled {
                Path { path in
                    let y =
                        rect.minY
                        + rect.height * 0.34

                    path.move(
                        to: CGPoint(
                            x:
                                compartmentMinX
                                + 10,
                            y: y
                        )
                    )
                    path.addLine(
                        to: CGPoint(
                            x:
                                compartmentMinX
                                + compartmentWidth
                                - 10,
                            y: y
                        )
                    )
                }
                .stroke(
                    .primary,
                    lineWidth: 3
                )
            }

            if compartment.drawerCount > 0 {
                let drawerZoneHeight =
                    rect.height
                    * CGFloat(
                        min(
                            compartment
                                .drawerZoneHeightMM
                            / max(
                                draft.heightMM,
                                1
                            ),
                            0.45
                        )
                    )

                ForEach(
                    1...compartment.drawerCount,
                    id: \.self
                ) { drawerIndex in
                    let y =
                        rect.maxY
                        - drawerZoneHeight
                        + drawerZoneHeight
                        * CGFloat(drawerIndex)
                        / CGFloat(
                            compartment.drawerCount
                        )

                    Path { path in
                        path.move(
                            to: CGPoint(
                                x:
                                    compartmentMinX,
                                y: y
                            )
                        )
                        path.addLine(
                            to: CGPoint(
                                x:
                                    compartmentMinX
                                    + compartmentWidth,
                                y: y
                            )
                        )
                    }
                    .stroke(
                        .secondary,
                        lineWidth: 1
                    )
                }
            }
        }

        if sliding && !open {
            let doors = max(
                wardrobeBinding
                    .slidingDoorCount
                    .wrappedValue,
                2
            )

            ForEach(
                0..<doors,
                id: \.self
            ) { index in
                let doorWidth =
                    rect.width
                    / CGFloat(doors - 1)
                    * 0.72

                let x =
                    rect.minX
                    + CGFloat(index)
                    * (
                        rect.width
                        - doorWidth
                    )
                    / CGFloat(
                        max(doors - 1, 1)
                    )

                RoundedRectangle(
                    cornerRadius: 3
                )
                .fill(
                    draft.frontFinish
                        .color
                        .opacity(
                            index.isMultiple(of: 2)
                            ? 0.82
                            : 0.68
                        )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 3
                    )
                    .stroke(
                        .primary,
                        lineWidth: 1
                    )
                )
                .frame(
                    width: doorWidth,
                    height:
                        rect.height - 8
                )
                .position(
                    x:
                        x
                        + doorWidth / 2,
                    y: rect.midY
                )
            }
        } else if !open {
            frontSymbols(
                in: rect
            )
        }
    }

    @ViewBuilder
    private func standardPreview(
        in rect: CGRect
    ) -> some View {
        let count = max(
            draft.segmentCount,
            1
        )

        ForEach(
            1..<count,
            id: \.self
        ) { index in
            let x =
                rect.minX
                + rect.width
                * CGFloat(index)
                / CGFloat(count)

            Path { path in
                path.move(
                    to: CGPoint(
                        x: x,
                        y: rect.minY
                    )
                )
                path.addLine(
                    to: CGPoint(
                        x: x,
                        y: rect.maxY
                    )
                )
            }
            .stroke(
                .secondary,
                lineWidth: 1
            )
        }

        frontSymbols(
            in: rect
        )
    }

    @ViewBuilder
    private func frontSymbols(
        in rect: CGRect
    ) -> some View {
        ForEach(
            Array(
                draft.fronts
                    .enumerated()
            ),
            id: \.element.id
        ) {
            index,
            front in

            let count = max(
                draft.fronts.count,
                1
            )

            let width =
                rect.width
                / CGFloat(count)

            Text(
                front.openingKind
                    .technicalSymbol
            )
            .font(
                .system(
                    size:
                        min(
                            width,
                            rect.height
                        ) * 0.32
                )
            )
            .foregroundStyle(
                front.material.color
            )
            .position(
                x:
                    rect.minX
                    + width
                    * (
                        CGFloat(index)
                        + 0.5
                    ),
                y: rect.midY
            )
        }
    }

    @ViewBuilder
    private func drawerLines(
        count: Int,
        minY: CGFloat,
        maxY: CGFloat,
        rect: CGRect
    ) -> some View {
        ForEach(
            1..<max(count, 1),
            id: \.self
        ) { index in
            let y =
                minY
                + (
                    maxY - minY
                )
                * CGFloat(index)
                / CGFloat(count)

            Path { path in
                path.move(
                    to: CGPoint(
                        x: rect.minX,
                        y: y
                    )
                )
                path.addLine(
                    to: CGPoint(
                        x: rect.maxX,
                        y: y
                    )
                )
            }
            .stroke(
                .secondary,
                lineWidth: 1
            )
        }
    }

    private var validationBar:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            let combinedMessages =
                draft.validationMessages
                + (
                    isWardrobeLike
                    ? wardrobeLayout
                        .validationMessages
                    : []
                )

            if combinedMessages.isEmpty {
                Label(
                    "Projekt poprawny",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            } else {
                ForEach(
                    combinedMessages,
                    id: \.self
                ) { text in
                    Label(
                        text,
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(.regularMaterial)
    }

    private var isWardrobeLike: Bool {
        switch draft.effectiveConstructionKind {
        case .hingedWardrobe,
             .slidingWardrobe,
             .dressingRoomOpen:
            return true
        default:
            return false
        }
    }

    private func syncWardrobeBayCount() {
        if draft.wardrobeV021 == nil {
            draft.wardrobeV021 =
                WardrobeDefinitionV021()
        }

        draft.wardrobeV021?.bayCount =
            wardrobeLayout.compartments.count
        draft.normalize()
    }

    private var constructionBinding:
        Binding<
            FurnitureConstructionKindV021
        >
    {
        Binding(
            get: {
                draft
                    .effectiveConstructionKind
            },
            set: {
                draft
                    .setConstructionKind($0)
            }
        )
    }

    private var wardrobeBinding:
        Binding<WardrobeDefinitionV021>
    {
        Binding(
            get: {
                draft.wardrobeV021
                    ?? WardrobeDefinitionV021()
            },
            set: {
                draft.wardrobeV021 = $0
                draft.normalize()
            }
        )
    }

    private func zoneBinding(
        _ keyPath:
            WritableKeyPath<
                SpaceTowerDefinitionV018,
                Double?
            >
    ) -> Binding<Double> {
        Binding(
            get: {
                draft.spaceTower[
                    keyPath: keyPath
                ] ?? 0
            },
            set: { newValue in
                draft.spaceTower[
                    keyPath: keyPath
                ] = max(
                    newValue,
                    100
                )
            }
        )
    }

    private func zoneHeightField(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        numberField(
            title,
            value: value
        )
    }

    private func recalculateBase() {
        draft.baseHeightSystem
            .recalculate()

        draft.heightMM =
            draft.baseHeightSystem
                .carcassHeightMM
    }

    private func numberField(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        TextField(
            title,
            value: value,
            format:
                .number
                .grouping(.never)
        )
        .keyboardType(.decimalPad)
    }

    private func finishPicker(
        _ title: String,
        selection:
            Binding<
                FurnitureFinishPresetV018
            >
    ) -> some View {
        Picker(
            title,
            selection: selection
        ) {
            ForEach(
                FurnitureFinishPresetV018
                    .allCases
            ) {
                Text($0.title)
                    .tag($0)
            }
        }
    }

    private func previewRect(
        in size: CGSize
    ) -> CGRect {
        let maxWidth = max(
            size.width - 110,
            240
        )

        let maxHeight = max(
            size.height - 130,
            280
        )

        let ratio = CGFloat(
            max(draft.widthMM, 1)
            / max(draft.heightMM, 1)
        )

        let width = min(
            maxWidth,
            maxHeight * ratio
        )

        let height = min(
            maxHeight,
            maxWidth / ratio
        )

        return CGRect(
            x:
                (
                    size.width
                    - width
                ) / 2,
            y:
                (
                    size.height
                    - height
                ) / 2
                - 20,
            width: width,
            height: height
        )
    }
}

private enum StepV021:
    String,
    CaseIterable,
    Identifiable
{
    case type
    case ksztalt
    case dimensions
    case structure
    case compartments
    case fronts
    case materials
    case summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .type:
            return "Typ"
        case .ksztalt:
            return "Kształt"
        case .dimensions:
            return "Wymiary"
        case .structure:
            return "Konstrukcja"
        case .compartments:
            return "Komory"
        case .fronts:
            return "Fronty"
        case .materials:
            return "Materiały"
        case .summary:
            return "Podsumowanie"
        }
    }

    var icon: String {
        switch self {
        case .type:
            return "square.grid.2x2"
        case .ksztalt:
            return "pencil.and.ruler"
        case .dimensions:
            return "ruler"
        case .structure:
            return "square.split.2x2"
        case .compartments:
            return "rectangle.split.3x1"
        case .fronts:
            return "door.left.hand.open"
        case .materials:
            return "paintpalette"
        case .summary:
            return "checklist"
        }
    }
}
