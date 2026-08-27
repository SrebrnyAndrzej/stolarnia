import DomainCore
import SwiftUI

/// Wewnętrzny typ cache'ujący template + placement w jednym miejscu.
private struct BibRecommendedItem: Identifiable {
    let template: FurnitureTemplate
    let placement: SugerowanePolozenieModulu
    var id: FurnitureTemplateID { template.id }
}

/// Wewnętrzny typ cache'ujący template + skategoryzowanie.
private struct BibFilteredItem: Identifiable {
    let template: FurnitureTemplate
    let category: FurnitureLibraryCategoryV016
    /// Typowe podziałki dla normy tego modułu — pokazywane wprost na kaflu.
    ///
    /// Liczone w `buildFiltered`, a nie w `body`. Wyszukanie normy to
    /// przeszukanie katalogu i składanie stringów; przy siatce kilkudziesięciu
    /// kafli i przewijaniu robiłoby się to dziesiątki razy na sekundę.
    let szerokosciMM: [Double]
    let domyslnaSzerokoscMM: Double?

    /// Sugerowane położenie policzone **raz**, w tle.
    ///
    /// Wcześniej liczyła je dopiero sekcja rekomendacji, więc katalog nie
    /// wiedział nic o wolnym miejscu i szedł alfabetycznie. `suggestedPlacement`
    /// przegląda meble na ścianie, więc nie może wracać do `body`.
    let polozenieV0107: SugerowanePolozenieModulu?

    /// Ile milimetrów zostanie na ścianie po wstawieniu tego modułu.
    ///
    /// `nil`, gdy moduł się nie mieści albo nie znamy jego domyślnej
    /// szerokości. Mniejszy zapas znaczy ciaśniejsze wypełnienie ściany —
    /// czyli mniej blend i mniej korpusów na tę samą długość.
    let zapasNaScianieMM: Double?

    var mieściSieV0107: Bool { zapasNaScianieMM != nil }

    var id: FurnitureTemplateID { template.id }
}

private struct BibQuickTask: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let group: FurnitureLibraryGroupV016
    let category: FurnitureLibraryCategoryV016?
}

struct BibliotekaModulowMeblowychView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [FurnitureTemplate]
    let initialGroup: FurnitureLibraryGroupV016
    let initialCategory: FurnitureLibraryCategoryV016?
    let suggestedPlacement: (FurnitureTemplate) -> SugerowanePolozenieModulu
    let onCreate: (
        FurnitureTemplate,
        KonfiguracjaModuluMeblowegoDane
    ) async -> Bool

    @State private var selectedGroup: FurnitureLibraryGroupV016
    @State private var selectedCategory: FurnitureLibraryCategoryV016?
    @State private var searchText = ""

    // Cache — aktualizowane asynchronicznie gdy zmienią się filtry
    @State private var cachedFiltered: [BibFilteredItem] = []
    @State private var cachedRecommended: [BibRecommendedItem] = []
    @State private var cacheReady = false

    init(
        templates: [FurnitureTemplate],
        initialGroup:
            FurnitureLibraryGroupV016 = .kitchen,
        initialCategory:
            FurnitureLibraryCategoryV016? = nil,
        suggestedPlacement:
            @escaping (FurnitureTemplate) -> SugerowanePolozenieModulu,
        onCreate:
            @escaping (
                FurnitureTemplate,
                KonfiguracjaModuluMeblowegoDane
            ) async -> Bool
    ) {
        self.templates = templates
        self.initialGroup = initialGroup
        self.initialCategory = initialCategory
        self.suggestedPlacement = suggestedPlacement
        self.onCreate = onCreate
        _selectedGroup =
            State(
                initialValue:
                    initialGroup
            )
        _selectedCategory =
            State(
                initialValue:
                    initialCategory
            )
    }

    /// Klucz do task(id:) — zmiana powoduje rekomputację
    private var filterKey: String {
        "\(selectedGroup.rawValue)|\(selectedCategory?.rawValue ?? "all")|\(searchText)"
    }

    private var trimmedSearchText: String {
        searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    private var hasActiveNarrowing: Bool {
        selectedCategory != nil
            || !trimmedSearchText.isEmpty
    }

    private var activeFilterDescription: String {
        var parts: [String] = [
            selectedGroup.title
        ]

        if let selectedCategory {
            parts.append(
                selectedCategory.title
            )
        }

        if !trimmedSearchText.isEmpty {
            parts.append(
                "„\(trimmedSearchText)”"
            )
        }

        return parts.joined(separator: " / ")
    }

    /// Czy w ogóle wiemy, ile jest wolnego miejsca.
    ///
    /// Biblioteka bywa otwierana bez wskazanej ściany — wtedy `maximumWidth`
    /// jest zerowe i **nic** się nie mieści. Rysowanie wtedy znacznika przy
    /// każdym kaflu mówiłoby o luce, o której nic nie wiemy; jeden moduł
    /// mieszczący się wystarczy, żeby uznać kontekst ściany za znany.
    private var znanaScianaV0107: Bool {
        cachedFiltered.contains(where: \.mieściSieV0107)
    }

    /// Podpis katalogu mówiący, **dlaczego kafle leżą w tej kolejności**.
    ///
    /// Kolejność inna niż alfabetyczna bez wyjaśnienia czyta się jak przypadek.
    /// Liczba „ile z ilu" mówi przy okazji, jak ciasno jest na ścianie — przy
    /// „3 z 61" wiadomo, że luka jest mała, zanim przewinie się siatkę.
    private var podpisKatalogoowyV0107: String {
        let mieszczace = cachedFiltered.filter(\.mieściSieV0107).count
        guard mieszczace > 0, mieszczace < cachedFiltered.count else {
            return activeFilterDescription
        }

        return activeFilterDescription
            + " · najpierw mieszczące się w wolnym miejscu"
            + " (\(mieszczace) z \(cachedFiltered.count))"
    }

    private var setupGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: 248,
                    maximum: 380
                ),
                spacing: 12,
                alignment: .top
            )
        ]
    }

    private var quickTasks: [BibQuickTask] {
        [
            BibQuickTask(
                id: "kitchen-base-run",
                title: "Ciąg dolny",
                subtitle: "szafki stojące, zlew, cargo",
                systemImage: "cabinet",
                group: .kitchen,
                category: .kitchenBase
            ),
            BibQuickTask(
                id: "kitchen-drawers",
                title: "Szuflady",
                subtitle: "gotowe układy 2/3/4 fronty",
                systemImage: "rectangle.split.3x1",
                group: .kitchen,
                category: .kitchenDrawers
            ),
            BibQuickTask(
                id: "kitchen-cargo-gap",
                title: "Cargo do luki",
                subtitle: "150, 200, 300 i 400 mm",
                systemImage: "rectangle.stack",
                group: .kitchen,
                category: .cargo
            ),
            BibQuickTask(
                id: "kitchen-wall",
                title: "Wiszące",
                subtitle: "fronty, półki, podchwyt",
                systemImage: "square.topthird.inset.filled",
                group: .kitchen,
                category: .kitchenWall
            ),
            BibQuickTask(
                id: "kitchen-tall",
                title: "Słupki i nadstawki",
                subtitle: "wysoka zabudowa i góra ciągu",
                systemImage: "rectangle.portrait",
                group: .kitchen,
                category: .kitchenTall
            ),
            BibQuickTask(
                id: "kitchen-island",
                title: "Wyspa",
                subtitle: "moduły wolnostojące",
                systemImage: "rectangle.center.inset.filled",
                group: .kitchen,
                category: .kitchenIsland
            ),
            BibQuickTask(
                id: "sliding-wardrobe",
                title: "Moduły pod przesuwne",
                subtitle: "korpusy + system w kolejnym kroku",
                systemImage: "door.sliding.left.hand.closed",
                group: .wardrobes,
                category: .builtInWardrobe
            ),
            BibQuickTask(
                id: "dressing-room",
                title: "Garderoba",
                subtitle: "korpusy, półki, drążki",
                systemImage: "hanger",
                group: .dressingRoom,
                category: .dressingCarcass
            ),
            BibQuickTask(
                id: "bookcase",
                title: "Regał",
                subtitle: "półki, komory, zabudowy",
                systemImage: "books.vertical",
                group: .livingAndWork,
                category: .bookcase
            )
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                groupPicker
                categoryPicker
                templateContent
            }
            .navigationTitle("Biblioteka modułów")
            .searchable(
                text: $searchText,
                prompt: "Szukaj po nazwie lub kodzie"
            )
            .stolarniaReadableInterface()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedGroup) {
                selectedCategory = nil
            }
            // Przelicz cache gdy zmienią się filtry LUB lista templates
            .task(id: filterKey) {
                await rebuildCache()
            }
        }
    }

    // MARK: - Cache

    private func rebuildCache() async {
        let filtered = buildFiltered()
        let recommended = buildRecommended(from: filtered)
        await MainActor.run {
            cachedFiltered = filtered
            cachedRecommended = recommended
            cacheReady = true
        }
    }

    private func buildFiltered() -> [BibFilteredItem] {
        templates
            .filter(FurnitureLibraryClassificationV016.supportedByCurrentBuilder)
            .compactMap { template -> BibFilteredItem? in
                let cat = FurnitureLibraryClassificationV016.category(for: template)
                guard cat.group == selectedGroup else { return nil }
                if let sel = selectedCategory, cat != sel { return nil }
                let q = trimmedSearchText
                if !q.isEmpty,
                   !template.name.localizedCaseInsensitiveContains(q),
                   !template.code.localizedCaseInsensitiveContains(q) {
                    return nil
                }
                let norma = NormySzafekCatalog.norma(
                    dla: template.name,
                    code: template.code,
                    categoryName: template.category.rawValue
                )
                let szerokosc =
                    (try? template.defaultParameters
                        .millimeters(for: .width))?.rawValue
                let polozenie = suggestedPlacement(template)
                let zapas = szerokosc.flatMap { w -> Double? in
                    let wolne = polozenie.maximumWidth.rawValue
                    return wolne >= w ? wolne - w : nil
                }

                return BibFilteredItem(
                    template: template,
                    category: cat,
                    szerokosciMM: norma.typoweSzerokosciMM,
                    domyslnaSzerokoscMM: szerokosc,
                    polozenieV0107: polozenie,
                    zapasNaScianieMM: zapas
                )
            }
            .sorted(by: kolejnoscKatalogowaV0107)
    }

    /// Kolejność katalogu: **najpierw to, co wejdzie w wolne miejsce**.
    ///
    /// Alfabet nie niósł tu informacji — w katalogu 160 modułów prawie każda
    /// nazwa zaczyna się od „Szafka", więc sortowanie po nazwie układało kafle
    /// w kolejności, która nie odpowiadała żadnej decyzji projektanta.
    /// Pytanie przy bibliotece brzmi „co zmieści się w tej luce", a odpowiedź
    /// aplikacja zna: `suggestedPlacement` liczy wolne miejsce przy ścianie.
    ///
    /// W grupie mieszczących się idziemy od **najciaśniejszego dopasowania**:
    /// moduł zostawiający 20 mm domyka ścianę, moduł zostawiający 900 mm
    /// zostawia miejsce na kolejną szafkę i decyzję, co z nim zrobić.
    /// Niemieszczące się nie znikają — schodzą na koniec, bo ta sama luka
    /// bywa poszerzana o kilka minut później.
    private func kolejnoscKatalogowaV0107(
        _ lewy: BibFilteredItem,
        _ prawy: BibFilteredItem
    ) -> Bool {
        switch (lewy.zapasNaScianieMM, prawy.zapasNaScianieMM) {
        case let (l?, p?):
            if l != p { return l < p }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lewy.template.name
            .localizedCompare(prawy.template.name) == .orderedAscending
    }

    private func buildRecommended(from filtered: [BibFilteredItem]) -> [BibRecommendedItem] {
        Array(
            filtered
                .compactMap { item -> BibRecommendedItem? in
                    // Położenie jest już policzone w `buildFiltered` — drugie
                    // wywołanie `suggestedPlacement` dawało ten sam przegląd
                    // mebli na ścianie po raz drugi, dla każdego szablonu.
                    guard item.mieściSieV0107,
                          let placement = item.polozenieV0107
                    else { return nil }
                    return BibRecommendedItem(
                        template: item.template,
                        placement: placement
                    )
                }
                .sorted {
                    recommendationScore($0)
                    < recommendationScore($1)
                }
                .prefix(8)
        )
    }

    private var groupPicker: some View {
        StolarniaFilterShelf {
            ForEach(FurnitureLibraryGroupV016.allCases) { group in
                Button {
                    selectedGroup = group
                } label: {
                    Label(
                        group.title,
                        systemImage: group.systemImage
                    )
                }
                .stolarniaFilterControl(
                    isActive:
                        selectedGroup == group
                )
            }
        }
    }

    private var categoryPicker: some View {
        StolarniaFilterShelf {
            categoryButton(
                title: "Wszystkie",
                systemImage: "square.grid.2x2",
                category: nil
            )

            ForEach(categoriesForSelectedGroup) { category in
                categoryButton(
                    title: category.title,
                    systemImage: category.systemImage,
                    category: category
                )
            }
        }
    }

    @ViewBuilder
    private var templateContent: some View {
        if !cacheReady {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if cachedFiltered.isEmpty {
            ContentUnavailableView {
                Label(
                    emptyTitle,
                    systemImage: selectedGroup.systemImage
                )
            } description: {
                Text(emptyDescription)
            } actions: {
                if hasActiveNarrowing {
                    Button {
                        clearNarrowing()
                    } label: {
                        Label(
                            "Wyczyść filtr",
                            systemImage:
                                "line.3.horizontal.decrease.circle"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    StolarniaCatalogContextBar(
                        title:
                            selectedCategory?.title
                            ?? selectedGroup.title,
                        subtitle:
                            activeFilterDescription,
                        systemImage:
                            selectedCategory?.systemImage
                            ?? selectedGroup.systemImage,
                        count:
                            cachedFiltered.count,
                        noun:
                            "modułów",
                        showsClearAction:
                            hasActiveNarrowing,
                        clearAction: {
                            clearNarrowing()
                        }
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 18
                    ) {
                        if trimmedSearchText.isEmpty {
                            quickTaskSection
                        }

                        if !cachedRecommended.isEmpty {
                            recommendedSection
                        }

                        StolarniaCatalogSectionHeader(
                            title: "Katalog modułów",
                            systemImage: "list.bullet.rectangle",
                            subtitle: podpisKatalogoowyV0107
                        )

                        LazyVGrid(
                            columns: setupGridColumns,
                            alignment: .leading,
                            spacing: 12
                        ) {
                            ForEach(cachedFiltered) { item in
                                kafelModulu(item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
            .background(
                StolarniaPalette.canvas
            )
        }
    }

    private var quickTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            StolarniaCatalogSectionHeader(
                title: "Co chcesz dodać?",
                systemImage: "hand.tap",
                subtitle: "Najczęstsze wybory"
            )

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(quickTasks) { task in
                        StolarniaTaskActionButton(
                            title: task.title,
                            subtitle: task.subtitle,
                            systemImage: task.systemImage,
                            status:
                                isSelectedQuickTask(task)
                                ? .ready
                                : .neutral
                        ) {
                            applyQuickTask(task)
                        }
                        .frame(width: 286)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            StolarniaCatalogSectionHeader(
                title: "Pasujące do wolnego miejsca",
                systemImage: "wand.and.stars",
                subtitle: "Według aktualnej ściany i szerokości"
            )

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(cachedRecommended) { item in
                        NavigationLink {
                            configurationView(for: item.template)
                        } label: {
                            recommendedCard(item)
                        }
                        .stolarniaPressable(skala: 0.985)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Filtr kategorii.
    ///
    /// Dla kategorii kuchennych ikoną jest **schemat pozycji w ciągu**
    /// (`SchematPozycjiWCiaguV099`) zamiast symbolu SF: z podświetlonego pasa
    /// od razu widać, czy chodzi o dolne, wiszące czy słupek. Poza kuchnią
    /// schemat nie ma sensu — szafa nie jest pozycją w ciągu z blatem —
    /// więc zostaje symbol.
    private func categoryButton(
        title: String,
        systemImage: String,
        category: FurnitureLibraryCategoryV016?
    ) -> some View {
        let selected = selectedCategory == category
        let schemat = category?.schematPozycjiV099

        return Button {
            selectedCategory = category
        } label: {
            Label {
                Text(title)
            } icon: {
                if let schemat {
                    SchematPozycjiWCiaguV099(
                        pozycja: schemat,
                        aktywny: selected
                    )
                } else {
                    Image(systemName: systemImage)
                }
            }
        }
        .stolarniaFilterControl(
            isActive: selected
        )
    }

    private func isSelectedQuickTask(
        _ task: BibQuickTask
    ) -> Bool {
        selectedGroup == task.group
            && selectedCategory == task.category
    }

    private func applyQuickTask(
        _ task: BibQuickTask
    ) {
        selectedGroup = task.group
        selectedCategory = task.category
    }

    private func clearNarrowing() {
        selectedCategory = nil
        searchText = ""
    }

    private func templateCard(
        _ item: BibFilteredItem
    ) -> some View {
        let preset =
            StandardFurnitureModuleCatalogV077
            .preset(for: item.template.id)
        let setup = preset?.setup
        let opisPodgladu = opisModulu(for: item.template, preset: preset)
        let badges =
            Array(
                (setup?.badges ?? ["Setup"])
                    .prefix(3)
            )

        return VStack(
            alignment: .leading,
            spacing: 12
        ) {
            modulePreview(for: item.category, opis: opisPodgladu)

            HStack(alignment: .top, spacing: 8) {
                Label(
                    item.category.title,
                    systemImage:
                        item.category.systemImage
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Spacer(minLength: 8)

                if let dimensions =
                    defaultDimensions(item.template) {
                    Text("\(dimensions) mm")
                        .font(
                            .caption2
                                .monospacedDigit()
                        )
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(item.template.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if let summary = setup?.summary,
               !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                ForEach(badges, id: \.self) {
                    badge in
                    StolarniaBadgeView(
                        text: badge,
                        tone: .accent
                    )
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(item.template.code)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Label(
                    "Konfiguruj",
                    systemImage: "slider.horizontal.3"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    StolarniaPalette.accentStrong
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 242,
            alignment: .topLeading
        )
        .padding(12)
        .contentShape(Rectangle())
    }

    /// Kafel katalogu: rysunek modułu + **rząd dostępnych szerokości**.
    ///
    /// Wzorzec z planera ABRYS — przy każdej pozycji katalogu stoją podziałki,
    /// w jakich moduł się robi. U nas dochodzi to, czego oni nie mają: podziałka
    /// jest **klikalna** i otwiera konfigurator już na tej szerokości. Wcześniej
    /// każdy moduł otwierał się na swojej jednej domyślnej szerokości i dopiero
    /// w formularzu wychodziło, że 450 nie jest typowe.
    ///
    /// Tło i obrys wędrują tutaj, żeby rysunek i pasek podziałek czytały się
    /// jako jedna karta, a nie dwa luźne prostokąty.
    private func kafelModulu(
        _ item: BibFilteredItem
    ) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                configurationView(
                    for: item.template,
                    szerokoscMM: nil
                )
            } label: {
                templateCard(item)
            }
            // Kafel katalogu to główna akcja tego ekranu — dotknięcie
            // wstawia moduł do projektu. Karta wielkości połowy dłoni
            // bez reakcji na dotyk wygląda jak obrazek, nie jak przycisk,
            // dlatego skala jest łagodniejsza niż przy małych kaflach.
            .stolarniaPressable(skala: 0.985)

            if !item.szerokosciMM.isEmpty {
                Divider()
                pasekSzerokosci(item)
            }

            if znanaScianaV0107,
               !item.mieściSieV0107,
               let wolne = item.polozenieV0107?.maximumWidth {
                Divider()
                znacznikBrakuMiejscaV0107(wolne)
            }
        }
        .background(
            StolarniaPalette.canvasRaised
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .stroke(
                Color.secondary.opacity(0.18),
                lineWidth: 1
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }

    /// Moduł szerszy niż wolne miejsce — z konkretną liczbą, nie samym kolorem.
    ///
    /// Kafel **zostaje klikalny**: podziałki niżej mogą zawierać węższy wariant,
    /// a ścianę da się przeprojektować. Ukrycie takiego modułu wyglądałoby jak
    /// brak w katalogu, a to nieprawda — brakuje miejsca, nie szafki.
    private func znacznikBrakuMiejscaV0107(
        _ wolne: Millimeters
    ) -> some View {
        Label(
            "Wolne miejsce \(formatted(wolne))",
            systemImage: "arrow.left.and.right"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    /// Podziałki jako osobne cele dotyku.
    ///
    /// Wyróżniona jest szerokość domyślna szablonu — to ta, którą dostaniesz,
    /// stukając w sam rysunek. Bez tego wyróżnienia rząd liczb nie mówi, od
    /// czego moduł startuje.
    private func pasekSzerokosci(
        _ item: BibFilteredItem
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Text("mm")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                ForEach(item.szerokosciMM, id: \.self) { szerokosc in
                    let domyslna =
                        item.domyslnaSzerokoscMM
                            .map { abs($0 - szerokosc) < 0.5 }
                        ?? false

                    NavigationLink {
                        configurationView(
                            for: item.template,
                            szerokoscMM: szerokosc
                        )
                    } label: {
                        Text(
                            szerokosc.formatted(
                                .number
                                    .grouping(.never)
                                    .precision(.fractionLength(0...1))
                            )
                        )
                        .font(
                            .caption
                                .monospacedDigit()
                                .weight(domyslna ? .bold : .regular)
                        )
                        .foregroundStyle(
                            domyslna
                                ? StolarniaPalette.accentStrong
                                : Color.primary
                        )
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 7,
                                style: .continuous
                            )
                            .fill(
                                domyslna
                                    ? StolarniaPalette
                                        .accentStrong
                                        .opacity(0.16)
                                    : StolarniaPalette.canvasInset
                            )
                        )
                    }
                    .stolarniaPressable()
                    .accessibilityLabel(
                        "\(item.template.name), szerokość "
                        + "\(Int(szerokosc)) mm"
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    /// Podgląd modułu.
    ///
    /// Gdy moduł pochodzi z katalogu, rysunek powstaje z jego prawdziwej
    /// geometrii (`PodgladModuluBibliotekiV094`) — proporcje, fronty, komory,
    /// półki. Dekoracja kategorii została jako fallback dla modułów spoza
    /// katalogu (własne szablony użytkownika), bo dla nich nie mamy setupu
    /// i pusty prostokąt byłby gorszy niż symbol rodziny.
    /// Opis do rysunku — z katalogu ogólnego albo kuchennego.
    ///
    /// Biblioteka miesza oba katalogi w jednej siatce, więc podgląd musi umieć
    /// wziąć geometrię z każdego z nich. Bez tego moduły kuchenne, czyli
    /// większość tego, co się tu przegląda, zostałyby przy dekoracji kategorii.
    private func opisModulu(
        for template: FurnitureTemplate,
        preset: StandardFurniturePresetV077?
    ) -> PodgladModuluOpisV094? {
        if let preset {
            return PodgladModuluOpisV094(preset: preset)
        }
        if let kuchenny = StandardKitchenTemplatesV0143.preset(for: template.id) {
            return PodgladModuluOpisV094(kitchen: kuchenny)
        }
        return nil
    }

    private func modulePreview(
        for category:
            FurnitureLibraryCategoryV016,
        opis: PodgladModuluOpisV094? = nil
    ) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .fill(
                StolarniaPalette.canvasInset
            )

            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .stroke(
                Color.secondary.opacity(0.18),
                lineWidth: 1
            )

            if let opis {
                PodgladModuluBibliotekiV094(opis: opis)
                    .padding(10)
            } else {
                previewContent(for: category)
                    .padding(14)
            }
        }
        .frame(height: 88)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func previewContent(
        for category:
            FurnitureLibraryCategoryV016
    ) -> some View {
        switch category {
        case .kitchenDrawers, .sinkCabinet,
             .kitchenBase:
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) {
                    index in
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                    .fill(
                        index == 2
                            ? Color.accentColor
                                .opacity(0.26)
                            : Color.primary
                                .opacity(0.10)
                    )
                    .frame(height: index == 2 ? 26 : 16)
                }
            }

        case .slidingWardrobe,
             .hingedWardrobe,
             .builtInWardrobe:
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) {
                    _ in
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                    .fill(
                        Color.primary
                            .opacity(0.10)
                    )
                    .overlay(alignment: .center) {
                        Rectangle()
                            .fill(
                                Color.secondary
                                    .opacity(0.28)
                            )
                            .frame(width: 1)
                    }
                }
            }

        case .dressingCarcass,
             .dressingShelf,
             .bookcase,
             .storage:
            VStack(spacing: 7) {
                ForEach(0..<5, id: \.self) {
                    index in
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                    .fill(
                        index.isMultiple(of: 2)
                            ? Color.primary
                                .opacity(0.10)
                            : Color.accentColor
                                .opacity(0.20)
                    )
                    .frame(height: 8)
                }
            }

        case .kitchenWall,
             .bathroomTall,
             .kitchenTall,
             .applianceHousing,
             .pantryStorage:
            HStack(spacing: 8) {
                RoundedRectangle(
                    cornerRadius: 6,
                    style: .continuous
                )
                .fill(
                    Color.primary.opacity(0.10)
                )

                VStack(spacing: 6) {
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                    .fill(
                        Color.accentColor
                            .opacity(0.22)
                    )
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                    .fill(
                        Color.primary.opacity(0.10)
                    )
                }
            }

        case .kitchenIsland, .tvUnit:
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) {
                    _ in
                    RoundedRectangle(
                        cornerRadius: 6,
                        style: .continuous
                    )
                    .fill(
                        Color.accentColor
                            .opacity(0.22)
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44)

        default:
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        StolarniaPalette.accentStrong
                    )

                VStack(spacing: 6) {
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                    .fill(
                        Color.primary.opacity(0.10)
                    )
                    .frame(height: 10)

                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                    .fill(
                        Color.accentColor
                            .opacity(0.18)
                    )
                    .frame(height: 10)
                }
            }
        }
    }

    private func recommendedCard(
        _ item: BibRecommendedItem
    ) -> some View {
        let category =
            FurnitureLibraryClassificationV016.category(
                for: item.template
            )
        let placement = item.placement   // ← już przeliczone w cache
        let width = defaultWidth(item.template)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.headline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.16))
                    )

                Text(category.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text(
                placement.suggestionTitle
                ?? item.template.name
            )
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            HStack(spacing: 8) {
                if let width {
                    Text(formatted(width))
                }

                Text("max \(formatted(placement.maximumWidth))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Label(
                placement.bottomOffset > .zero
                    ? "Wiszący"
                    : "Stojący",
                systemImage:
                    placement.bottomOffset > .zero
                    ? "rectangle.topthird.inset.filled"
                    : "rectangle.bottomthird.inset.filled"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(StolarniaPalette.anthracite)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.18))
            )

            if let reason =
                placement.suggestionReason {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
        .frame(width: 198, alignment: .leading)
        .padding(12)
        .background(
            StolarniaPalette.canvasRaised
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.accentColor.opacity(0.22),
                    lineWidth: 1
                )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }

    private func configurationView(
        for template: FurnitureTemplate,
        szerokoscMM: Double? = nil
    ) -> some View {
        KonfiguracjaModuluMeblowegoView(
            template: template,
            suggestedPlacement:
                suggestedPlacement(template),
            poczatkowaSzerokoscMM: szerokoscMM,
            onSave: { data in
                let saved = await onCreate(
                    template,
                    data
                )
                if saved {
                    await MainActor.run {
                        dismiss()
                    }
                }
                return saved
            }
        )
    }

    private var categoriesForSelectedGroup: [FurnitureLibraryCategoryV016] {
        let availableCategories =
            Set(
                templates
                    .filter(
                        FurnitureLibraryClassificationV016
                            .supportedByCurrentBuilder
                    )
                    .map {
                        FurnitureLibraryClassificationV016
                            .category(for: $0)
                    }
            )

        return FurnitureLibraryClassificationV016
            .categories(
                in:
                    selectedGroup
            )
            .filter {
                availableCategories.contains($0)
            }
    }

    private func recommendationScore(
        _ item: BibRecommendedItem
    ) -> Int {
        let category =
            FurnitureLibraryClassificationV016.category(
                for: item.template
            )

        let semanticPriority =
            item.placement.suggestionPriority
        if semanticPriority < 1_000 {
            return semanticPriority
        }

        switch category {
        case .kitchenBase: return 0
        case .kitchenDrawers: return 1
        case .sinkCabinet: return 2
        case .kitchenCorner: return 3
        case .cargo: return 4
        case .kitchenWall: return 5
        case .kitchenTall: return 6
        case .applianceHousing: return 7
        default:
            return 20
        }
    }

    private var emptyTitle: String {
        searchText.isEmpty
            ? "Brak modułów w tej kategorii"
            : "Nie znaleziono modułu"
    }

    private var emptyDescription: String {
        switch selectedGroup {
        case .kitchen:
            return "Zmień podkategorię lub wyszukiwanie."
        case .wardrobes:
            return "Przygotowano miejsce na szafy przesuwne, uchylne i wnękowe."
        case .dressingRoom:
            return "Przygotowano miejsce na moduły garderoby."
        case .bathroomUtility:
            return "Dodaj szafki łazienkowe, pralniane i gospodarcze."
        case .hallway:
            return "Dodaj moduły na buty, siedziska i szafy wejściowe."
        case .livingAndWork:
            return "Dodaj biurka, regały, stoły robocze i komody."
        case .livingRoom:
            return "Dodaj moduły RTV, panele ścienne i niskie zabudowy."
        case .specialBuiltIns:
            return "Dodaj zabudowy pod schodami, pod skosem i wnękowe."
        case .custom:
            return "Tutaj pojawią się meble zapisane w kreatorze."
        }
    }

    private func defaultDimensions(
        _ template: FurnitureTemplate
    ) -> String? {
        guard let width = defaultWidth(template),
              let height = try? template.defaultParameters
            .millimeters(for: .height),
              let depth = try? template.defaultParameters
            .millimeters(for: .depth) else {
            return nil
        }

        return "\(formatted(width))×\(formatted(height))×\(formatted(depth))"
    }

    private func defaultWidth(
        _ template: FurnitureTemplate
    ) -> Millimeters? {
        try? template.defaultParameters
            .millimeters(for: .width)
    }

    private func formatted(
        _ value: Millimeters
    ) -> String {
        value.rawValue.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }
}
