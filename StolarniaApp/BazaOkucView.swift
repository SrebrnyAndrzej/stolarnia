import SwiftUI
import UniformTypeIdentifiers

struct BazaOkucView: View {
    @StateObject private var repository =
        BazaOkucRepository()

    @State private var searchText = ""
    @State private var selectedType:
        TypOkuciaMeblowego?
    @State private var selectedManufacturer:
        String?
    @State private var selectedTier:
        PoziomWycenyOkucia?
    @State private var onlyActive = false
    @State private var onlyCatalogSystems =
        false

    @State private var editedItem:
        OkucieMeblowe?
    @State private var showingImporter =
        false
    @State private var importMessage:
        String?
    @State private var pendingDelete:
        OkucieMeblowe?

    var body: some View {
        VStack(spacing: 0) {
            if let message =
                repository
                    .komunikatIntegralnosci
            {
                StolarniaStatusBanner(
                    message: message,
                    systemImage:
                        "externaldrive.badge.checkmark",
                    tone: .success
                )
            }

            filters
            hardwareList
        }
        .navigationTitle(
            "Baza okuć i systemów"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .searchable(
            text: $searchText,
            placement:
                .navigationBarDrawer(
                    displayMode: .always
                ),
            prompt:
                "Kod, nazwa, producent, system lub dostawca"
        )
        .stolarniaScreenSurface(.detail)
        .stolarniaReadableInterface()
        .toolbar {
            toolbarContent
        }
        .sheet(
            item: $editedItem
        ) { item in
            EdytorOkuciaView(
                item: item
            ) {
                repository.upsert($0)
            }
        }
        .fileImporter(
            isPresented:
                $showingImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                .tabSeparatedText
            ],
            allowsMultipleSelection:
                false
        ) { result in
            importCSV(result)
        }
        .alert(
            "Operacja zakończona",
            isPresented:
                bindingImportMessage
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                importMessage = nil
            }
        } message: {
            Text(
                importMessage
                ?? ""
            )
        }
        .alert(
            "Usunąć okucie?",
            isPresented:
                bindingPendingDelete,
            presenting:
                pendingDelete
        ) { item in
            Button(
                "Anuluj",
                role: .cancel
            ) {
                pendingDelete = nil
            }

            Button(
                "Usuń",
                role: .destructive
            ) {
                repository.delete(
                    id: item.id
                )
                pendingDelete = nil
            }
        } message: { item in
            Text(item.nazwa)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent:
        some ToolbarContent
    {
        ToolbarItemGroup(
            placement:
                .primaryAction
        ) {
            Menu {
                Button {
                    let result =
                        repository
                            .synchronizujKatalogSystemow()

                    importMessage =
                        "Synchronizacja systemów zakończona. Dodane: \(result.added), zaktualizowane: \(result.updated). Ręczne ceny nie zostały nadpisane."
                } label: {
                    Label(
                        "Synchronizuj systemy",
                        systemImage:
                            "arrow.triangle.2.circlepath"
                    )
                }

                Divider()

                Button {
                    showingImporter = true
                } label: {
                    Label(
                        "Importuj CSV",
                        systemImage:
                            "square.and.arrow.down"
                    )
                }
            } label: {
                Label(
                    "Zarządzaj katalogiem",
                    systemImage:
                        "ellipsis.circle"
                )
            }

            Button {
                editedItem =
                    newHardwareDraft()
            } label: {
                Label(
                    "Dodaj okucie",
                    systemImage: "plus"
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .keyboardShortcut(
                "n",
                modifiers: [.command]
            )
        }
    }

    private var hardwareList:
        some View
    {
        List {
            if filteredItems.isEmpty {
                StolarniaEmptyState(
                    title:
                        "Brak pasujących okuć",
                    description:
                        hasActiveFilters
                        || !searchText.isEmpty
                        ? "Zmień kryteria wyszukiwania lub wyczyść filtry."
                        : "Dodaj pierwsze okucie albo zsynchronizuj katalog systemów.",
                    systemImage:
                        "shippingbox",
                    actionTitle:
                        hasActiveFilters
                        || !searchText.isEmpty
                        ? "Wyczyść filtry"
                        : "Dodaj okucie",
                    actionSystemImage:
                        hasActiveFilters
                        || !searchText.isEmpty
                        ? "line.3.horizontal.decrease.circle"
                        : "plus",
                    action: {
                        if hasActiveFilters
                            || !searchText.isEmpty
                        {
                            clearFilters()
                            searchText = ""
                        } else {
                            editedItem =
                                newHardwareDraft()
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(
                    Color.clear
                )
            } else {
                ForEach(
                    filteredItems
                ) { item in
                    Button {
                        editedItem = item
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        Color.clear
                    )
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe:
                            false
                    ) {
                        Button(
                            "Usuń",
                            role:
                                .destructive
                        ) {
                            pendingDelete =
                                item
                        }

                        Button {
                            toggleActive(item)
                        } label: {
                            Label(
                                item.aktywne
                                ? "Wyłącz"
                                : "Włącz",
                                systemImage:
                                    item.aktywne
                                    ? "pause.circle"
                                    : "checkmark.circle"
                            )
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            editedItem = item
                        } label: {
                            Label(
                                "Edytuj",
                                systemImage:
                                    "pencil"
                            )
                        }

                        Button {
                            toggleActive(item)
                        } label: {
                            Label(
                                item.aktywne
                                ? "Wyłącz okucie"
                                : "Włącz okucie",
                                systemImage:
                                    item.aktywne
                                    ? "pause.circle"
                                    : "checkmark.circle"
                            )
                        }

                        Divider()

                        Button(
                            role: .destructive
                        ) {
                            pendingDelete =
                                item
                        } label: {
                            Label(
                                "Usuń",
                                systemImage:
                                    "trash"
                            )
                        }
                    }
                }
            }
        }
        .stolarniaCatalogList()
        .animation(
            StolarniaAnimation.standard,
            value:
                filteredItems
                    .map(\.id)
        )
    }

    private var filters:
        some View
    {
        StolarniaFilterShelf {
            Menu {
                Button(
                    "Wszystkie typy"
                ) {
                    selectedType = nil
                }

                Divider()

                ForEach(
                    TypOkuciaMeblowego
                        .allCases
                ) { type in
                    Button(type.nazwa) {
                        selectedType = type
                    }
                }
            } label: {
                Label(
                    selectedType?.nazwa
                    ?? "Wszystkie typy",
                    systemImage:
                        "line.3.horizontal.decrease.circle"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    selectedType != nil
            )

            Menu {
                Button(
                    "Wszyscy producenci"
                ) {
                    selectedManufacturer =
                        nil
                }

                if !manufacturers.isEmpty {
                    Divider()
                }

                ForEach(
                    manufacturers,
                    id: \.self
                ) { manufacturer in
                    Button(manufacturer) {
                        selectedManufacturer =
                            manufacturer
                    }
                }
            } label: {
                Label(
                    selectedManufacturer
                    ?? "Wszyscy producenci",
                    systemImage:
                        "building.2"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    selectedManufacturer
                    != nil
            )

            Menu {
                Button(
                    "Wszystkie poziomy"
                ) {
                    selectedTier = nil
                }

                Divider()

                ForEach(
                    PoziomWycenyOkucia
                        .allCases
                ) { tier in
                    Button(tier.nazwa) {
                        selectedTier = tier
                    }
                }
            } label: {
                Label(
                    selectedTier?.nazwa
                    ?? "Wszystkie poziomy",
                    systemImage:
                        "slider.horizontal.3"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    selectedTier != nil
            )

            Button {
                onlyCatalogSystems
                    .toggle()
            } label: {
                Label(
                    "Systemy katalogowe",
                    systemImage:
                        "books.vertical"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    onlyCatalogSystems
            )
            .accessibilityValue(
                onlyCatalogSystems
                ? "Włączony"
                : "Wyłączony"
            )

            Button {
                onlyActive.toggle()
            } label: {
                Label(
                    "Tylko aktywne",
                    systemImage:
                        "checkmark.circle"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    onlyActive
            )
            .accessibilityValue(
                onlyActive
                ? "Włączony"
                : "Wyłączony"
            )

            if hasActiveFilters {
                Button {
                    clearFilters()
                } label: {
                    Label(
                        "Wyczyść",
                        systemImage:
                            "xmark.circle"
                    )
                }
                .stolarniaFilterControl()
            }

            StolarniaResultCount(
                count:
                    filteredItems.count
            )
        }
    }

    private var filteredItems:
        [OkucieMeblowe]
    {
        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return repository.okucia
            .filter {
                item in

                if onlyActive
                    && !item.aktywne
                {
                    return false
                }

                if onlyCatalogSystems
                    && !item
                        .jestSystememKatalogowym
                {
                    return false
                }

                if let selectedType,
                   item.typ != selectedType
                {
                    return false
                }

                if let selectedTier,
                   item.poziomWyceny
                    != selectedTier
                {
                    return false
                }

                if let selectedManufacturer,
                   item.producent
                    .caseInsensitiveCompare(
                        selectedManufacturer
                    )
                    != .orderedSame
                {
                    return false
                }

                guard !query.isEmpty
                else {
                    return true
                }

                let haystack =
                    [
                        item.kod,
                        item.nazwa,
                        item.producent,
                        item.dostawca,
                        item.system,
                        item.typ.nazwa,
                        item.poziomWyceny
                            .nazwa
                    ]
                    .joined(separator: " ")

                return haystack
                    .localizedCaseInsensitiveContains(
                        query
                    )
            }
            .sorted {
                $0.nazwa
                    .localizedCaseInsensitiveCompare(
                        $1.nazwa
                    )
                == .orderedAscending
            }
    }

    private var manufacturers:
        [String]
    {
        Array(
            Set(
                repository.okucia
                    .filter {
                        selectedType == nil
                        || $0.typ
                            == selectedType
                    }
                    .map {
                        $0.producent
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                    }
                    .filter {
                        !$0.isEmpty
                    }
            )
        )
        .sorted {
            $0.localizedCaseInsensitiveCompare(
                $1
            )
            == .orderedAscending
        }
    }

    private var hasActiveFilters:
        Bool
    {
        selectedType != nil
        || selectedManufacturer != nil
        || selectedTier != nil
        || onlyActive
        || onlyCatalogSystems
    }

    private func row(
        _ item:
            OkucieMeblowe
    ) -> some View {
        StolarniaCatalogRow(
            title: item.nazwa,
            subtitle:
                [
                    item.kod,
                    item.producent,
                    item.system
                ]
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: " • "
                ),
            tertiaryText:
                [
                    item.typ.nazwa,
                    item.dostawca
                ]
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: " • "
                ),
            badges:
                hardwareBadges(item),
            trailingPrimary:
                item.cenaBrutto
                    .formatted(
                        .currency(
                            code: "PLN"
                        )
                    ),
            trailingSecondary:
                "\(item.poziomWyceny.nazwa) • \(item.jednostka.nazwa)\nnetto \(item.cenaNettoPoRabacie.formatted(.currency(code: "PLN")))",
            isEnabled:
                item.aktywne
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 11,
                    style: .continuous
                )
                .fill(
                    StolarniaPalette
                        .accent
                        .opacity(0.11)
                )

                Image(
                    systemName:
                        item.typ
                            .systemImage
                )
                .font(
                    .title3
                        .weight(.semibold)
                )
                .foregroundStyle(
                    StolarniaPalette
                        .accentStrong
                )
            }
        }
    }

    private func hardwareBadges(
        _ item:
            OkucieMeblowe
    ) -> [StolarniaCatalogBadge] {
        var badges:
            [StolarniaCatalogBadge] = []

        if item
            .jestSystememKatalogowym
        {
            badges.append(
                StolarniaCatalogBadge(
                    "Katalog"
                )
            )
        }

        if !item.aktywne {
            badges.append(
                StolarniaCatalogBadge(
                    "Nieaktywne",
                    tone: .neutral
                )
            )
        }

        return badges
    }

    private func newHardwareDraft()
        -> OkucieMeblowe
    {
        var item = OkucieMeblowe()
        item.nazwa = item.typ.nazwa
        item.dataAktualizacji =
            Date()
        return item
    }

    private func clearFilters() {
        selectedType = nil
        selectedManufacturer = nil
        selectedTier = nil
        onlyActive = false
        onlyCatalogSystems = false
    }

    private func toggleActive(
        _ item:
            OkucieMeblowe
    ) {
        var updated = item
        updated.aktywne.toggle()
        updated.dataAktualizacji =
            Date()
        repository.upsert(updated)
    }

    private func importCSV(
        _ result:
            Result<[URL], Error>
    ) {
        do {
            guard let url =
                try result.get().first
            else {
                return
            }

            let didAccess =
                url.startAccessingSecurityScopedResource()

            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data =
                try Data(
                    contentsOf: url
                )

            let items =
                try ImportOkucCSV.parse(
                    data: data
                )

            let importResult =
                repository.merge(items)

            importMessage =
                "Dodano: \(importResult.added)\nZaktualizowano: \(importResult.updated)"
        } catch {
            importMessage =
                error.localizedDescription
        }
    }

    private var bindingImportMessage:
        Binding<Bool>
    {
        Binding(
            get: {
                importMessage != nil
            },
            set: { visible in
                if !visible {
                    importMessage = nil
                }
            }
        )
    }

    private var bindingPendingDelete:
        Binding<Bool>
    {
        Binding(
            get: {
                pendingDelete != nil
            },
            set: { visible in
                if !visible {
                    pendingDelete = nil
                }
            }
        )
    }
}
