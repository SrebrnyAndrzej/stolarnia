import DomainCore
import SwiftUI
import UniformTypeIdentifiers

private enum BazaMaterialowSheet:
    Identifiable
{
    case newMaterial
    case editMaterial(MaterialStolarski)

    var id: String {
        switch self {
        case .newMaterial:
            return "new-material"

        case .editMaterial(let material):
            return "edit-material-\(material.id)"
        }
    }
}

struct BazaMaterialowView: View {
    @StateObject private var repository =
        BazaMaterialowRepository()

    @State private var wyszukiwanie = ""
    @State private var filtrTypu:
        TypMaterialuStolarskiego?
    @State private var filtrProducenta:
        String?
    @State private var filtrKolekcji:
        String?
    @State private var tylkoAktywne = false
    @State private var tylkoPlytyZCennika =
        false

    @State private var activeSheet:
        BazaMaterialowSheet?
    @State private var pokazImporter =
        false
    @State private var raportImportu:
        ImportMaterialowRaport?
    @State private var komunikatBledu:
        String?
    @State private var potwierdzUsuniecie:
        MaterialStolarski?

    // Import cennika hurtowni
    @State private var pokazImporterCennika =
        false
    @State private var raportCennika:
        RaportImportuCennika?

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

            filtry
            catalogContext
            listaMaterialow
        }
        .navigationTitle(
            "Baza materiałów i cennik płyt"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .searchable(
            text: $wyszukiwanie,
            placement:
                .navigationBarDrawer(
                    displayMode: .always
                ),
            prompt:
                "Kod, nazwa, dekor, producent lub kolekcja"
        )
        .stolarniaScreenSurface(.detail)
        .stolarniaReadableInterface()
        .toolbar {
            toolbarContent
        }
        .fileImporter(
            isPresented:
                $pokazImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                .tabSeparatedText
            ],
            allowsMultipleSelection:
                false
        ) { result in
            importuj(result)
        }
        .sheet(
            item: $activeSheet
        ) {
            sheet in

            activeSheetView(sheet)
        }
        .confirmationDialog(
            "Usunąć materiał \"\(potwierdzUsuniecie?.nazwa ?? "")\"?",
            isPresented: bindingUsuniecia,
            titleVisibility: .visible,
            presenting: potwierdzUsuniecie
        ) { material in
            Button("Usuń materiał", role: .destructive) {
                repository.usun(id: material.id)
                potwierdzUsuniecie = nil
            }
            Button("Anuluj", role: .cancel) {
                potwierdzUsuniecie = nil
            }
        } message: { _ in
            Text("Materiał zostanie trwale usunięty z bazy. Projekty które go używały zachowają zapisane dane, ale nie znajdą już tego materiału na liście.")
        }
        .alert(
            "Synchronizacja zakończona",
            isPresented:
                bindingRaportu
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                raportImportu = nil
            }
        } message: {
            Text(
                raportImportu?
                    .komunikat
                ?? ""
            )
        }
        .alert(
            "Błąd importu",
            isPresented:
                bindingBledu
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                komunikatBledu = nil
            }
        } message: {
            Text(
                komunikatBledu
                ?? "Nieznany błąd"
            )
        }
        .fileImporter(
            isPresented:
                $pokazImporterCennika,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                .tabSeparatedText
            ],
            allowsMultipleSelection:
                false
        ) { result in
            importujCennik(result)
        }
        .sheet(
            item: $raportCennika
        ) { raport in
            PodgladImportuCennikuView(
                raport: raport,
                repository: repository
            )
        }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: BazaMaterialowSheet
    ) -> some View {
        switch sheet {
        case .newMaterial:
            EdytorMaterialuView(
                material: nil
            ) {
                repository.dodaj($0)
            }

        case .editMaterial(let material):
            EdytorMaterialuView(
                material: material
            ) {
                repository
                    .aktualizuj($0)
            }
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
                Section("Katalogi") {
                    Button {
                        raportImportu =
                            repository
                                .synchronizujWzornikiPlyt()
                    } label: {
                        Label(
                            "Wzorniki EGGER i Kronospan",
                            systemImage:
                                "paintpalette"
                        )
                    }

                    Button {
                        raportImportu =
                            repository
                                .synchronizujCennikPlyt()
                    } label: {
                        Label(
                            "Cennik płyt EGGER i Kronospan",
                            systemImage:
                                "banknote"
                        )
                    }

                    Button {
                        raportImportu =
                            repository
                                .synchronizujCennikAkcesoriow()
                    } label: {
                        Label(
                            "Systemy okuć",
                            systemImage:
                                "shippingbox"
                        )
                    }
                }

                Divider()

                Button {
                    pokazImporter = true
                } label: {
                    Label(
                        "Importuj materiały z CSV",
                        systemImage:
                            "square.and.arrow.down"
                    )
                }

                Button {
                    pokazImporterCennika = true
                } label: {
                    Label(
                        "Importuj cennik hurtowni (CSV)",
                        systemImage:
                            "banknote.fill"
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
                activeSheet =
                    .newMaterial
            } label: {
                Label(
                    "Dodaj materiał",
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

    private var listaMaterialow:
        some View
    {
        List {
            if filtrowaneMaterialy
                .isEmpty
            {
                StolarniaEmptyState(
                    title:
                        "Brak pasujących materiałów",
                    description:
                        maAktywneFiltry
                        || !wyszukiwanie.isEmpty
                        ? "Zmień kryteria wyszukiwania lub wyczyść filtry."
                        : "Dodaj pierwszy materiał albo zsynchronizuj wzorniki producentów.",
                    systemImage:
                        "square.grid.2x2",
                    actionTitle:
                        maAktywneFiltry
                        || !wyszukiwanie.isEmpty
                        ? "Wyczyść filtry"
                        : "Dodaj materiał",
                    actionSystemImage:
                        maAktywneFiltry
                        || !wyszukiwanie.isEmpty
                        ? "line.3.horizontal.decrease.circle"
                        : "plus",
                    action: {
                        if maAktywneFiltry
                            || !wyszukiwanie
                                .isEmpty
                        {
                            wyczyscZawezenie()
                        } else {
                            activeSheet =
                                .newMaterial
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(
                    Color.clear
                )
            } else {
                ForEach(
                    filtrowaneMaterialy
                ) { material in
                    Button {
                        activeSheet =
                            .editMaterial(material)
                    } label: {
                        materialRow(
                            material
                        )
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
                            potwierdzUsuniecie =
                                material
                        }

                        Button {
                            ustawAktywnosc(
                                material
                            )
                        } label: {
                            Label(
                                material.aktywny
                                ? "Wyłącz"
                                : "Włącz",
                                systemImage:
                                    material.aktywny
                                    ? "pause.circle"
                                    : "checkmark.circle"
                            )
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            activeSheet =
                                .editMaterial(material)
                        } label: {
                            Label(
                                "Edytuj",
                                systemImage:
                                    "pencil"
                            )
                        }

                        Button {
                            ustawAktywnosc(
                                material
                            )
                        } label: {
                            Label(
                                material.aktywny
                                ? "Wyłącz materiał"
                                : "Włącz materiał",
                                systemImage:
                                    material.aktywny
                                    ? "pause.circle"
                                    : "checkmark.circle"
                            )
                        }

                        Divider()

                        Button(
                            role: .destructive
                        ) {
                            potwierdzUsuniecie =
                                material
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
                filtrowaneMaterialy
                    .map(\.id)
        )
    }

    private var filtry:
        some View
    {
        StolarniaFilterShelf {
            Menu {
                Button(
                    "Wszystkie typy"
                ) {
                    filtrTypu = nil
                    filtrProducenta = nil
                    filtrKolekcji = nil
                }

                Divider()

                ForEach(
                    TypMaterialuStolarskiego
                        .allCases
                ) { typ in
                    Button(typ.nazwa) {
                        filtrTypu = typ
                        filtrProducenta = nil
                        filtrKolekcji = nil
                    }
                }
            } label: {
                Label(
                    filtrTypu?.nazwa
                    ?? "Wszystkie typy",
                    systemImage:
                        "line.3.horizontal.decrease.circle"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    filtrTypu != nil
            )

            Menu {
                Button(
                    "Wszyscy producenci"
                ) {
                    filtrProducenta = nil
                    filtrKolekcji = nil
                }

                if !producenci.isEmpty {
                    Divider()
                }

                ForEach(
                    producenci,
                    id: \.self
                ) { producent in
                    Button(producent) {
                        filtrProducenta =
                            producent
                        filtrKolekcji = nil
                    }
                }
            } label: {
                Label(
                    filtrProducenta
                    ?? "Wszyscy producenci",
                    systemImage:
                        "building.2"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    filtrProducenta != nil
            )

            Menu {
                Button(
                    "Wszystkie kolekcje"
                ) {
                    filtrKolekcji = nil
                }

                if !kolekcje.isEmpty {
                    Divider()
                }

                ForEach(
                    kolekcje,
                    id: \.self
                ) { kolekcja in
                    Button(kolekcja) {
                        filtrKolekcji =
                            kolekcja
                    }
                }
            } label: {
                Label(
                    filtrKolekcji
                    ?? "Wszystkie kolekcje",
                    systemImage:
                        "rectangle.stack"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    filtrKolekcji != nil
            )
            .disabled(kolekcje.isEmpty)

            Button {
                tylkoPlytyZCennika
                    .toggle()
            } label: {
                Label(
                    "Z cennikiem",
                    systemImage:
                        "banknote"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    tylkoPlytyZCennika
            )
            .accessibilityValue(
                tylkoPlytyZCennika
                ? "Włączony"
                : "Wyłączony"
            )

            Button {
                tylkoAktywne.toggle()
            } label: {
                Label(
                    "Tylko aktywne",
                    systemImage:
                        "checkmark.circle"
                )
            }
            .stolarniaFilterControl(
                isActive:
                    tylkoAktywne
            )
            .accessibilityValue(
                tylkoAktywne
                ? "Włączony"
                : "Wyłączony"
            )

            if maAktywneFiltry {
                Button {
                    wyczyscFiltry()
                } label: {
                    Label(
                        "Wyczyść",
                        systemImage:
                            "xmark.circle"
                    )
                }
                .stolarniaFilterControl()
            }

        }
    }

    private var catalogContext:
        some View
    {
        StolarniaCatalogContextBar(
            title:
                filtrTypu?.nazwa
                ?? "Materiały",
            subtitle:
                opisAktywnegoWidoku,
            systemImage:
                filtrTypu == nil
                ? "square.grid.2x2"
                : "line.3.horizontal.decrease.circle",
            count:
                filtrowaneMaterialy.count,
            noun:
                "materiałów",
            showsClearAction:
                maAktywneZawezenie,
            clearAction: {
                wyczyscZawezenie()
            }
        )
    }

    private var maAktywneZawezenie:
        Bool
    {
        maAktywneFiltry
        || !wyszukiwanie
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }

    private var opisAktywnegoWidoku:
        String
    {
        var parts: [String] = []

        if let filtrProducenta {
            parts.append(filtrProducenta)
        }

        if let filtrKolekcji {
            parts.append(filtrKolekcji)
        }

        if tylkoPlytyZCennika {
            parts.append("z cennikiem")
        }

        if tylkoAktywne {
            parts.append("tylko aktywne")
        }

        let query =
            wyszukiwanie
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !query.isEmpty {
            parts.append("„\(query)”")
        }

        return parts.isEmpty
            ? "Wszystkie pozycje katalogu"
            : parts.joined(separator: " / ")
    }

    private var producenci:
        [String]
    {
        unikalneWartosci(
            repository.materialy
                .filter {
                    filtrTypu == nil
                    || $0.typ == filtrTypu
                }
                .map(\.producent)
        )
    }

    private var kolekcje:
        [String]
    {
        unikalneWartosci(
            repository.materialy
                .filter {
                    material in

                    let pasujeTyp =
                        filtrTypu == nil
                        || material.typ
                            == filtrTypu

                    let pasujeProducent =
                        filtrProducenta
                        == nil
                        || material.producent
                            .caseInsensitiveCompare(
                                filtrProducenta
                                ?? ""
                            )
                            == .orderedSame

                    return pasujeTyp
                    && pasujeProducent
                }
                .compactMap(\.kolekcja)
        )
    }

    private var maAktywneFiltry:
        Bool
    {
        filtrTypu != nil
        || filtrProducenta != nil
        || filtrKolekcji != nil
        || tylkoAktywne
        || tylkoPlytyZCennika
    }

    private var filtrowaneMaterialy:
        [MaterialStolarski]
    {
        let query =
            wyszukiwanie
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return repository.materialy
            .filter {
                material in

                if tylkoAktywne
                    && !material.aktywny
                {
                    return false
                }

                if tylkoPlytyZCennika
                    && material
                        .cenaRynkowaPlyty
                        == nil
                {
                    return false
                }

                if let filtrTypu,
                   material.typ != filtrTypu
                {
                    return false
                }

                if let filtrProducenta,
                   material.producent
                    .caseInsensitiveCompare(
                        filtrProducenta
                    )
                    != .orderedSame
                {
                    return false
                }

                if let filtrKolekcji,
                   (
                       material.kolekcja
                       ?? ""
                   )
                   .caseInsensitiveCompare(
                       filtrKolekcji
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
                        material.kod,
                        material.nazwa,
                        material.dekor,
                        material.producent,
                        material.dostawca,
                        material.kolekcja
                            ?? "",
                        material.kodProducenta
                            ?? "",
                        material.struktura
                            ?? "",
                        material.grupaDekoru
                            ?? "",
                        material.typ.nazwa
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

    private func materialRow(
        _ material:
            MaterialStolarski
    ) -> some View {
        StolarniaCatalogRow(
            title: material.nazwa,
            subtitle:
                [
                    material.kod,
                    material.producent,
                    material.kolekcja
                        ?? "",
                    material.typ.nazwa
                ]
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: " • "
                ),
            tertiaryText:
                [
                    material.dekor,
                    material.struktura
                        ?? ""
                ]
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: " • "
                ),
            badges:
                materialBadges(
                    material
                ),
            trailingPrimary:
                material.cenaBrutto
                    .formatted(
                        .currency(
                            code: "PLN"
                        )
                    ),
            trailingSecondary:
                materialPriceDetails(
                    material
                ),
            isEnabled:
                material.aktywny
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

                ProbkaDekoruV0100(
                    kolor:
                        Color(
                            stolarniaHEX:
                                material
                                    .kolorHEX
                        ),
                    powierzchnia:
                        DecorSurfaceCatalog.resolve(
                            structureCode:
                                material.struktura,
                            group:
                                material.grupaDekoru
                        ),
                    pionowoUslojenie:
                        material.kierunekDekoru,
                    ziarno:
                        material.kod
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                )
                .padding(8)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                    .stroke(
                        Color.secondary
                            .opacity(0.28),
                        lineWidth: 1
                    )
                    .padding(8)
                }
            }
        }
    }

    private func materialBadges(
        _ material:
            MaterialStolarski
    ) -> [StolarniaCatalogBadge] {
        var badges:
            [StolarniaCatalogBadge] = []

        if material
            .jestPozycjaKatalogowa
        {
            badges.append(
                StolarniaCatalogBadge(
                    "Wzornik"
                )
            )
        }

        if material
            .cenaRynkowaPlyty
            != nil
        {
            badges.append(
                StolarniaCatalogBadge(
                    "Cennik",
                    tone: .success
                )
            )
        }

        if !material.aktywny {
            badges.append(
                StolarniaCatalogBadge(
                    "Nieaktywne",
                    tone: .neutral
                )
            )
        }

        return badges
    }

    private func materialPriceDetails(
        _ material:
            MaterialStolarski
    ) -> String {
        var lines = [
            "\(material.jednostka.skrot) • netto \(material.cenaPoRabacieNetto.formatted(.currency(code: "PLN")))"
        ]

        if let cenaZaM2 =
            material.cenaZaM2Netto
        {
            lines.append(
                "\(cenaZaM2.formatted(.currency(code: "PLN"))) / m² netto"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }

    private func ustawAktywnosc(
        _ material:
            MaterialStolarski
    ) {
        repository.ustawAktywnosc(
            id: material.id,
            aktywny:
                !material.aktywny
        )
    }

    private func unikalneWartosci(
        _ wartosci:
            [String]
    ) -> [String] {
        Array(
            Set(
                wartosci
                    .map {
                        $0.trimmingCharacters(
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

    private func wyczyscFiltry() {
        filtrTypu = nil
        filtrProducenta = nil
        filtrKolekcji = nil
        tylkoAktywne = false
        tylkoPlytyZCennika = false
    }

    private func wyczyscZawezenie() {
        wyczyscFiltry()
        wyszukiwanie = ""
    }

    private func importuj(
        _ result:
            Result<[URL], Error>
    ) {
        do {
            let urls =
                try result.get()

            guard let url =
                urls.first
            else {
                return
            }

            let materialy =
                try ImportMaterialowCSV
                    .wczytaj(
                        z: url
                    )

            raportImportu =
                repository.scal(
                    materialy
                )
        } catch {
            komunikatBledu =
                error.localizedDescription
        }
    }

    private func importujCennik(
        _ result:
            Result<[URL], Error>
    ) {
        do {
            let urls =
                try result.get()

            guard let url =
                urls.first
            else {
                return
            }

            let raport =
                try ImportCennikuCSV
                    .wczytaj(
                        z: url,
                        materialy:
                            repository.materialy
                    )

            raportCennika = raport
        } catch {
            komunikatBledu =
                error.localizedDescription
        }
    }

    private var bindingUsuniecia:
        Binding<Bool>
    {
        Binding(
            get: {
                potwierdzUsuniecie
                    != nil
            },
            set: { visible in
                if !visible {
                    potwierdzUsuniecie =
                        nil
                }
            }
        )
    }

    private var bindingRaportu:
        Binding<Bool>
    {
        Binding(
            get: {
                raportImportu != nil
            },
            set: { visible in
                if !visible {
                    raportImportu = nil
                }
            }
        )
    }

    private var bindingBledu:
        Binding<Bool>
    {
        Binding(
            get: {
                komunikatBledu != nil
            },
            set: { visible in
                if !visible {
                    komunikatBledu = nil
                }
            }
        )
    }
}
