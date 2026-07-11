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
    var id: FurnitureTemplateID { template.id }
}

struct BibliotekaModulowMeblowychView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [FurnitureTemplate]
    let suggestedPlacement: (FurnitureTemplate) -> SugerowanePolozenieModulu
    let onCreate: (
        FurnitureTemplate,
        KonfiguracjaModuluMeblowegoDane
    ) async -> Bool

    @State private var selectedGroup: FurnitureLibraryGroupV016 = .kitchen
    @State private var selectedCategory: FurnitureLibraryCategoryV016?
    @State private var searchText = ""

    // Cache — aktualizowane asynchronicznie gdy zmienią się filtry
    @State private var cachedFiltered: [BibFilteredItem] = []
    @State private var cachedRecommended: [BibRecommendedItem] = []
    @State private var cacheReady = false

    /// Klucz do task(id:) — zmiana powoduje rekomputację
    private var filterKey: String {
        "\(selectedGroup.rawValue)|\(selectedCategory?.rawValue ?? "all")|\(searchText)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                groupPicker
                Divider()
                categoryPicker
                Divider()
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
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty,
                   !template.name.localizedCaseInsensitiveContains(q),
                   !template.code.localizedCaseInsensitiveContains(q) {
                    return nil
                }
                return BibFilteredItem(template: template, category: cat)
            }
            .sorted { $0.template.name.localizedCompare($1.template.name) == .orderedAscending }
    }

    private func buildRecommended(from filtered: [BibFilteredItem]) -> [BibRecommendedItem] {
        Array(
            filtered
                .compactMap { item -> BibRecommendedItem? in
                    guard let width = defaultWidth(item.template) else { return nil }
                    let placement = suggestedPlacement(item.template)
                    guard placement.maximumWidth >= width else { return nil }
                    return BibRecommendedItem(template: item.template, placement: placement)
                }
                .sorted { recommendationScore($0.template) < recommendationScore($1.template) }
                .prefix(8)
        )
    }

    private var groupPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(FurnitureLibraryGroupV016.allCases) { group in
                    Button {
                        selectedGroup = group
                    } label: {
                        Label(
                            group.title,
                            systemImage: group.systemImage
                        )
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(
                                selectedGroup == group
                                    ? Color.accentColor
                                    : Color(uiColor: .secondarySystemBackground)
                            )
                        )
                        .foregroundStyle(
                            selectedGroup == group
                                ? StolarniaPalette.anthracite
                                : Color.primary
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
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
            .padding(.horizontal)
            .padding(.vertical, 9)
        }
        .scrollIndicators(.hidden)
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
            }
        } else {
            List {
                if !cachedRecommended.isEmpty {
                    recommendedSection
                }

                Section {
                    ForEach(cachedFiltered) { item in
                        NavigationLink {
                            configurationView(for: item.template)
                        } label: {
                            templateRow(item)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var recommendedSection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(cachedRecommended) { item in
                        NavigationLink {
                            configurationView(for: item.template)
                        } label: {
                            recommendedCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 8,
                    leading: 16,
                    bottom: 8,
                    trailing: 16
                )
            )
        } header: {
            Label(
                "Pasujące do wolnego miejsca",
                systemImage: "wand.and.stars"
            )
            .font(.caption.weight(.semibold))
        }
    }

    private func categoryButton(
        title: String,
        systemImage: String,
        category: FurnitureLibraryCategoryV016?
    ) -> some View {
        let selected = selectedCategory == category

        return Button {
            selectedCategory = category
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        selected
                            ? Color.accentColor.opacity(0.16)
                            : Color.clear
                    )
                )
                .overlay {
                    Capsule().stroke(
                        selected
                            ? Color.accentColor
                            : Color.secondary.opacity(0.25),
                        lineWidth: 1
                    )
                }
        }
        .buttonStyle(.plain)
    }

    private func templateRow(
        _ item: BibFilteredItem
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.category.systemImage)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.template.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(item.category.title)
                    Text("•")
                    Text(item.template.code)
                        .font(.caption.monospaced())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let dimensions = defaultDimensions(item.template) {
                Text(dimensions)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
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
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(0.16))
                    )

                Text(category.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text(item.template.name)
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
        }
        .frame(width: 198, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    Color.accentColor.opacity(0.22),
                    lineWidth: 1
                )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    private func configurationView(
        for template: FurnitureTemplate
    ) -> some View {
        KonfiguracjaModuluMeblowegoView(
            template: template,
            suggestedPlacement:
                suggestedPlacement(template),
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
        FurnitureLibraryClassificationV016.categories(
            in: selectedGroup
        )
    }

    private func recommendationScore(
        _ template: FurnitureTemplate
    ) -> Int {
        let category =
            FurnitureLibraryClassificationV016.category(
                for: template
            )

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
