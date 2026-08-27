import DomainCore
import Persistence
import SwiftUI

private enum ElewacjaScianySheet:
    String,
    Identifiable
{
    case globalMaterials
    case projectCard
    case creator
    case furnitureLibrary
    case kitchenProposal
    case underStairsProposal

    var id: String { rawValue }
}

private enum ElewacjaScianyFullScreen:
    String,
    Identifiable
{
    case technicalDocumentation
    case preview3D

    var id: String { rawValue }
}

struct WidokElewacjiSciany: View {
    @Environment(\.dismiss) private var dismiss

    let room: RoomDefinition
    let wall: WallSegment
    @ObservedObject var mebleViewModel: MeblePomieszczeniaViewModel
    @ObservedObject var globalneMaterialyRepository:
        GlobalneMaterialyPomieszczeniaRepository
    @Binding var selectedFurnitureID: FurnitureAssemblyID?
    let onUpdateWall: (WallMeasurementUpdate) async -> Bool
    var zaznaczoneFurnitureIDsV066: Set<FurnitureAssemblyID> = []
    var trybWielokrotnegoZaznaczaniaV066 = false
    var onToggleFurnitureSelectionV066:
        ((FurnitureAssemblyID) -> Void)? = nil
    var onClearFurnitureSelectionV066: (() -> Void)? = nil
    var onReplaceFurnitureSelectionV067:
        ((ZaznaczenieRamkaV067) -> Void)? = nil
    var onMoveFurnitureV065:
        ((KontekstPrzesunieciaModulu2D) -> Void)? = nil
    var onDeleteFurnitureV065:
        ((FurnitureAssemblyID) -> Void)? = nil

    @State private var directionalAddition: KitchenDirectionalAdditionV015?
    @State private var editedFurnitureID: FurnitureAssemblyID?
    @State private var cornerDefinitionsV084: [CornerCabinetDefinitionV025] =
        []
    @State private var selectedSlidingDoorFillV093:
        SlidingWardrobeDoorFillV093 = .solid
    @State private var selectedSlidingDoorCountV094:
        Int = 0
    @State private var activeSheet: ElewacjaScianySheet?
    @State private var activeFullScreen: ElewacjaScianyFullScreen?
    @State private var edytowanyWymiar:
        KontekstEdycjiWymiaru2D?
    @AppStorage(
        Wymiarowanie2DUstawienia.poziomAppStorageKey
    ) private var poziomWymiarowaniaRaw =
        PoziomWymiarowania2D.podstawowe.rawValue

    // MARK: - Performance: cached render data
    // Poprzednio computed vars przeliczały kolizje O(N²) + numerowanie + runs
    // przy KAŻDYM renderze (np. tap na moduł). Teraz aktualizowane tylko gdy
    // zmieni się mebleViewModel.renderRevision (faktyczny zapis modułu).
    @State private var cachedAssembliesOnWall: [FurnitureAssembly] = []
    @State private var cachedCollidingIDsV083: Set<FurnitureAssemblyID> = []
    @State private var cachedNumberedItemsOnWall: [FurnitureCanvasItemV016] = []
    @State private var cachedRunsOnWall: [KitchenRunV015] = []
    // Task #92: sugestie i wolne kierunki były przeliczane co render
    @State private var cachedAllFinishingSuggestionsV092:
        [KitchenFinishingSuggestionV015] = []
    @State private var cachedAvailableDirectionsV092:
        Set<KitchenAddDirectionV015> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                elevationActionBar

                Divider()

                runSummaryBarV082

                ZStack(alignment: .bottom) {
                    elevationCanvas

                    if let selectedFurniture {
                        selectedFurnitureOverlay(
                            selectedFurniture
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        // Wjazd wybrzmiewa, zniknięcie jest natychmiastowe —
                        // kto zamyka panel, już zdecydował.
                        .transition(.stolarniaPanelOdDolu)
                        .zIndex(1)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .layoutPriority(1)
                // Panel zaznaczenia wjeżdża od dołu — bez przejścia
                // wyskakiwałby, co czyta się jako usterka. Ale zaznaczanie
                // modułu to **czynność ciągła** przy projektowaniu, więc
                // przejście jest skrócone i przestawione na krzywą wyjścia:
                // `easeInOut` startuje wolno, czyli opóźnia ruch dokładnie
                // w chwili, w której użytkownik patrzy najuważniej.
                .stolarniaAnimation(
                    StolarniaMotion.pojawienie,
                    value: selectedFurnitureID
                )

                Divider()

                finishingSuggestionsStripV082

                FurnitureLegendV016(
                    title: "Legenda elewacji",
                    items: numberedItemsOnWall,
                    selectedFurnitureID: $selectedFurnitureID,
                    maximumHeight: 108
                )

            }
            .navigationTitle("Elewacja: \(wall.name)")
            .navigationBarTitleDisplayMode(.inline)
            .stolarniaReadableInterface()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        pokazSheetV084(.globalMaterials)
                    } label: {
                        Label(
                            "Materiały globalne",
                            systemImage: "paintpalette"
                        )
                    }

                    runAssistantMenu

                    // Karta projektu — pojedyncza akcja, wcześniej ukryta w menu
                    // "Więcej" razem z Kreatorem i Asystentem, które i tak są
                    // w pasku akcji canvasu. Wyciągnięcie na widok toolbara
                    // usuwa dublowanie i skraca ścieżkę użytkownika.
                    Button {
                        pokazSheetV084(.projectCard)
                    } label: {
                        Label(
                            "Karta projektu",
                            systemImage: "doc.richtext"
                        )
                    }
                    .disabled(assembliesOnWall.isEmpty)
                }
            }
            .sheet(item: $edytowanyWymiar) { context in
                SzybkaEdycjaWymiaru2DView(
                    kontekst: context
                ) { newValue in
                    await zapiszWymiar(
                        context,
                        nowaWartosc: newValue
                    )
                }
            }
            .sheet(
                item: $activeSheet,
                onDismiss: {
                    directionalAddition = nil
                }
            ) { sheet in
                activeSheetView(sheet)
            }
            .fullScreenCover(item: $activeFullScreen) { destination in
                activeFullScreenView(destination)
            }
            // **Jedno okno modułu zamiast łańcucha okien.**
            // Wcześniej `Edytuj` otwierał pełny ekran edytora, a dokumentacja
            // techniczna była z niego jeszcze jednym pełnym ekranem. Teraz
            // `KartaModuluV097` trzyma przegląd, rysunek i produkcję w jednym
            // oknie, w kolejności zgodnej z teczką dokumentacji technicznej.
            .fullScreenCover(isPresented: Binding(
                get: {
                    editedFurniture != nil
                },
                set: { isPresented in
                    if !isPresented {
                        zapiszNaroznikPoEdycjiV0101()
                        editedFurnitureID = nil
                    }
                }
            )) {
                if let editedFurniture {
                    KartaModuluV097(
                        stored: editedFurniture,
                        mebleViewModel: mebleViewModel,
                        wall: wall,
                        room: room,
                        cornerDefinitions: $cornerDefinitionsV084,
                        jestNaroznikiem:
                            czyModulNaroznyV084(editedFurniture),
                        onZamknij: {
                            zapiszNaroznikPoEdycjiV0101()
                            editedFurnitureID = nil
                        },
                        onZapiszModul: { modul in
                            let didSave =
                                await mebleViewModel
                                    .zapiszModulZKreatoraElewacji(
                                        stored: editedFurniture,
                                        modul: modul,
                                        wall: wall,
                                        room: room
                                    )

                            if didSave {
                                mebleViewModel
                                    .zastosujGlobalneMaterialy(
                                        globalneMaterialyRepository
                                            .ustawienia
                                    )
                            }
                            return didSave
                        }
                    )
                }
            }
            // PERF: odśwież cache danych rysunkowych przy pierwszym render
            // i przy każdym faktycznym zapisie modelu.
            .onAppear {
                refreshRenderCaches()
            }
            .onChange(of: mebleViewModel.renderRevision) { _, _ in
                refreshRenderCaches()
            }
            // Task #92: przelicz wolne kierunki gdy zmienia się zaznaczony moduł
            .onChange(of: selectedFurnitureID) { _, _ in
                refreshAvailableDirectionsV092()
            }
        }
    }

    private var elevationCanvas: some View {
        ElewacjaScianyCanvasView(
            room: room,
            wall: wall,
            assemblies: mebleViewModel.assemblies,
            numberedItems: numberedItemsOnWall,
            runs: detectedRuns,
            availableDirections: availableDirections,
            cornerDefinitions:
                cornerDefinitionsV084,
            globalneMaterialy:
                globalneMaterialyRepository
                    .ustawienia,
            poziomWymiarowania:
                poziomWymiarowania,
            renderRevision: mebleViewModel.renderRevision,
            selectedFurnitureID: $selectedFurnitureID,
            zaznaczoneFurnitureIDsV066:
                zaznaczoneFurnitureIDsV066,
            trybWielokrotnegoZaznaczaniaV066:
                trybWielokrotnegoZaznaczaniaV066,
            onToggleFurnitureSelectionV066:
                onToggleFurnitureSelectionV066,
            onClearFurnitureSelectionV066:
                onClearFurnitureSelectionV066,
            onReplaceFurnitureSelectionV067:
                onReplaceFurnitureSelectionV067,
            onAddDirection: beginDirectionalAddition,
            collidingFurnitureIDs: collidingFurnitureIDsV083,
            onEditDimension: { context in
                if let furnitureID =
                    context.cel.furnitureID {
                    selectedFurnitureID = furnitureID
                    return
                } else {
                    rozpocznijEdycjeWymiaruV084(
                        context
                    )
                }
            },
            onMoveFurniture: { movement in
                if let onMoveFurnitureV065 {
                    onMoveFurnitureV065(movement)
                    return
                }

                guard !mebleViewModel.isSaving else {
                    return
                }

                Task {
                    let didMove =
                        await mebleViewModel
                            .przesunLubZamienModul(
                                movement,
                                room: room
                            )

                    if didMove {
                        selectedFurnitureID =
                            movement.furnitureID
                    }
                }
            }
        )
        // Nie używamy .id(renderRevision) — canvas sam obsługuje refresh
        // przez cachedFurniture + onChange. .id() niszczyłoby @State dragu.
    }

    private func selectedFurnitureOverlay(
        _ selectedFurniture: StoredFurnitureAssembly
    ) -> some View {
        VStack(spacing: 0) {
            Plan2DFurnitureInspector(
                storedAssembly: selectedFurniture,
                onAddAdjacent: availableDirections.contains(.right)
                    ? {
                        beginDirectionalAddition(
                            selectedFurniture.id,
                            .right
                        )
                    }
                    : nil,
                onEdit: {
                    rozpocznijEdycjeModuluV084(
                        selectedFurniture.id
                    )
                },
                onDelete: {
                    if let onDeleteFurnitureV065 {
                        onDeleteFurnitureV065(
                            selectedFurniture.id
                        )
                    } else {
                        Task {
                            await mebleViewModel.deleteModule(
                                id: selectedFurniture.id
                            )
                            selectedFurnitureID = nil
                        }
                    }
                },
                onClose: {
                    selectedFurnitureID = nil
                }
            )

            // Szybki edytor mieszka teraz w `KartaModuluV097` (sekcja Przegląd).
            // Trzymanie go także tutaj oznaczało dwa panele jeden pod drugim nad
            // rysunkiem — dokładnie to nakładanie się okien, które usuwamy.

            if let slidingRun =
                slidingWardrobeRunV093(
                    containing:
                        selectedFurniture.id
                ) {
                SlidingWardrobeElevationSystemPanelV093(
                    run:
                        slidingRun,
                    doorFill:
                        $selectedSlidingDoorFillV093,
                    doorCount:
                        $selectedSlidingDoorCountV094,
                    isSaving:
                        mebleViewModel.isSaving
                ) {
                    dodajSystemPrzesuwnyDoCiaguV093(
                        slidingRun
                    )
                }
            }
        }
        .frame(maxWidth: 680)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .stroke(
                StolarniaPalette.frostStroke,
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(0.18),
            radius: 16,
            x: 0,
            y: 8
        )
    }

    private func slidingWardrobeRunV093(
        containing furnitureID:
            FurnitureAssemblyID
    ) -> SlidingWardrobeModuleRunV087? {
        var scopedIDs =
            zaznaczoneFurnitureIDsV066
        scopedIDs.insert(
            furnitureID
        )

        if scopedIDs.count > 1,
           let scopedRun =
            GarderobyDrzwiWorkspaceV086
            .moduleRun(
                from:
                    mebleViewModel.storedAssemblies,
                selectedIDs:
                    scopedIDs
            ),
           scopedRun.wallID == wall.id {
            return scopedRun
        }

        return GarderobyDrzwiWorkspaceV086
            .moduleRuns(
                from:
                    mebleViewModel.storedAssemblies
            )
            .first {
                $0.wallID == wall.id
                    && $0.assemblyIDs.contains(
                        furnitureID
                    )
            }
    }

    private func dodajSystemPrzesuwnyDoCiaguV093(
        _ run:
            SlidingWardrobeModuleRunV087
    ) {
        guard !mebleViewModel.isSaving else {
            return
        }

        Task {
            let didCreate =
                await mebleViewModel
                    .createSlidingWardrobeSystemV087(
                        for:
                            run.withDoorCountOverride(
                                selectedSlidingDoorCountV094 > 0
                                ? selectedSlidingDoorCountV094
                                : nil
                            ),
                        wall:
                            wall,
                        room:
                            room,
                        doorFill:
                            selectedSlidingDoorFillV093
                    )

            if didCreate {
                await MainActor.run {
                    selectedFurnitureID =
                        run.assemblyIDs.first
                        ?? selectedFurnitureID
                }
            }
        }
    }

    private func pokazSheetV084(
        _ sheet:
            ElewacjaScianySheet
    ) {
        activeFullScreen = nil
        editedFurnitureID = nil
        edytowanyWymiar = nil
        activeSheet = sheet
    }

    private func pokazFullScreenV084(
        _ destination:
            ElewacjaScianyFullScreen
    ) {
        activeSheet = nil
        editedFurnitureID = nil
        edytowanyWymiar = nil
        activeFullScreen = destination
    }

    private func rozpocznijEdycjeModuluV084(
        _ furnitureID:
            FurnitureAssemblyID
    ) {
        activeSheet = nil
        activeFullScreen = nil
        edytowanyWymiar = nil

        guard let stored =
            mebleViewModel.storedAssembly(id: furnitureID)
        else {
            editedFurnitureID = nil
            return
        }

        // Narożnik idzie **tą samą drogą co każdy inny moduł**.
        //
        // Wcześniej miał osobny sheet z `CornerCabinetEditorV025` i przez to
        // jedyny rodzaj szafki z martwą strefą i kopertą ruchu mechanizmu
        // nie widział ani rysunku, ani produkcji, ani kontroli produkcyjnej.
        // Teraz `KartaModuluV097` dokłada mu sekcję `Narożnik`, a reszta
        // karty jest ta sama.
        if czyModulNaroznyV084(stored) {
            cornerDefinitionsV084 =
                CornerCabinetRepositoryV025.loadAll()
        }
        editedFurnitureID = furnitureID
    }

    private func rozpocznijEdycjeWymiaruV084(
        _ context:
            KontekstEdycjiWymiaru2D
    ) {
        activeSheet = nil
        activeFullScreen = nil
        editedFurnitureID = nil
        edytowanyWymiar = context
    }

    private var elevationActionBar: some View {
        ViewThatFits(in: .horizontal) {
            elevationActionBarContent(
                showsHint: true
            )
            elevationActionBarContent(
                showsHint: false
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            StolarniaPalette.paper.opacity(0.06),
                            StolarniaPalette.accent.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StolarniaPalette.frostStroke)
                .frame(height: 1)
        }
    }

    /// Wszystkie akcje elewacji w jednym stałym pasku.
    ///
    /// Wcześniej cztery z siedmiu siedziały w menu „Więcej" — trzeba było
    /// wiedzieć, że tam są. Wzorzec z planera ABRYS: jeden rząd trybów zawsze
    /// na wierzchu. Ikony **z podpisami**, bo to reguła projektu i realna
    /// potrzeba odbiorcy 50+.
    private func elevationActionBarContent(
        showsHint: Bool
    ) -> some View {
        PasekAkcjiElewacjiV098(
            akcje: [
                .init(
                    tytul: "Dodaj moduł",
                    ikona: "plus.square.on.square",
                    wiodaca: true,
                    identyfikator: "addFurnitureModuleButtonV024",
                    dzialanie: {
                        directionalAddition = nil
                        pokazSheetV084(.furnitureLibrary)
                    }
                ),
                .init(
                    tytul: "Zaproponuj ciąg",
                    ikona: "wand.and.stars",
                    identyfikator: "proposeKitchenRunButtonV095",
                    dzialanie: { pokazSheetV084(.kitchenProposal) }
                ),
                .init(
                    tytul: "Pod schodami",
                    ikona: "stairs",
                    dzialanie: { pokazSheetV084(.underStairsProposal) }
                ),
                .init(
                    tytul: "Własny setup",
                    ikona: "square.grid.3x3.square",
                    dzialanie: { pokazSheetV084(.creator) }
                ),
                .init(
                    tytul: "Dokumentacja",
                    ikona: "doc.text",
                    // Pusta ściana nie ma dokumentacji — akcja zostaje widoczna,
                    // żeby było wiadomo, że istnieje, ale jest nieaktywna.
                    wylaczona: assembliesOnWall.isEmpty,
                    dzialanie: { pokazFullScreenV084(.technicalDocumentation) }
                ),
                .init(
                    tytul: "Podgląd 3D",
                    ikona: "cube.transparent",
                    wylaczona: assembliesOnWall.isEmpty,
                    dzialanie: { pokazFullScreenV084(.preview3D) }
                )
            ],
            trailing: {
                HStack(spacing: 10) {
                    KontrolkaPoziomuWymiarowania2D(
                        poziom: poziomWymiarowaniaBinding
                    )

                    if showsHint {
                        Label(
                            trybWielokrotnegoZaznaczaniaV066
                                ? "Przeciągnij ramkę po pustym obszarze"
                                : "Dotknij modułu, potem użyj panelu",
                            systemImage:
                                trybWielokrotnegoZaznaczaniaV066
                                ? "rectangle.dashed"
                                : "hand.tap"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: 240, alignment: .leading)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: ElewacjaScianySheet
    ) -> some View {
        switch sheet {
        case .globalMaterials:
            GlobalnaZmianaMaterialowView(
                repository:
                    globalneMaterialyRepository
            ) { ustawienia in
                mebleViewModel
                    .zastosujGlobalneMaterialy(
                        ustawienia
                    )
            }

        case .projectCard:
            KartaProjektuPrezentacyjnegoViewV061(
                room: room,
                wall: wall,
                assemblies: mebleViewModel.assemblies,
                globalneMaterialy:
                    globalneMaterialyRepository.ustawienia
            )

        case .creator:
            FurnitureCreatorViewV022 {
                draft in

                await mebleViewModel
                    .saveCustomTemplateV020(
                        draft: draft
                    )
            }

        case .underStairsProposal:
            PropozycjaPodSchodamiView(
                szablony: mebleViewModel.templates,
                onWstaw: { szafka, szablon in
                    var dane = MapperPropozycjiCiaguV095.dane(
                        dla: .init(id: szafka.id, kind: .doors,
                                   width: szafka.width, note: szafka.note),
                        szablon: szablon,
                        offsetWzdluzSciany: szafka.offset
                    )
                    // Wysokość jest tu kluczowa i różna dla każdej szafki —
                    // to ona wynika z obwiedni biegu.
                    dane.height = szafka.height
                    dane.name = "Pod schodami \(Int(szafka.width.rawValue))×"
                        + "\(Int(szafka.height.rawValue))"

                    let udalo = await mebleViewModel.createModule(
                        template: szablon,
                        data: dane,
                        wall: wall,
                        room: room
                    )
                    if udalo {
                        mebleViewModel.zastosujGlobalneMaterialy(
                            globalneMaterialyRepository.ustawienia
                        )
                    }
                    return udalo
                }
            )

        case .kitchenProposal:
            PropozycjaCiaguView(
                dlugoscSciany: dlugoscScianyDlaPropozycjiV095,
                szablony: mebleViewModel.templates,
                onWstaw: { slot, szablon, offset in
                    let dane = MapperPropozycjiCiaguV095.dane(
                        dla: slot,
                        szablon: szablon,
                        offsetWzdluzSciany: offset
                    )
                    let udalo = await mebleViewModel.createModule(
                        template: szablon,
                        data: dane,
                        wall: wall,
                        room: room
                    )
                    if udalo {
                        mebleViewModel.zastosujGlobalneMaterialy(
                            globalneMaterialyRepository.ustawienia
                        )
                    }
                    return udalo
                }
            )

        case .furnitureLibrary:
            BibliotekaModulowMeblowychView(
                templates: availableTemplates,
                suggestedPlacement: suggestedPlacement,
                onCreate: { template, data in
                    let didCreate =
                        await mebleViewModel.createModule(
                            template: template,
                            data: data,
                            wall: wall,
                            room: room
                        )

                    if didCreate {
                        selectedFurnitureID =
                            mebleViewModel.lastCreatedAssemblyID
                        mebleViewModel
                            .zastosujGlobalneMaterialy(
                                globalneMaterialyRepository
                                    .ustawienia
                            )
                    }

                    return didCreate
                }
            )
        }
    }

    @ViewBuilder
    private func activeFullScreenView(
        _ destination: ElewacjaScianyFullScreen
    ) -> some View {
        switch destination {
        case .technicalDocumentation:
            KartyTechniczneModulowV028(
                assemblies: assembliesOnWall,
                cornerDefinitions:
                    cornerDefinitionsV084,
                onClose: {
                    activeFullScreen = nil
                }
            )

        case .preview3D:
            Furniture3DPreviewViewV017(
                title: "3D: \(wall.name)",
                assemblies: assembliesOnWall,
                globalneMaterialy:
                    globalneMaterialyRepository
                        .ustawienia,
                room: room,
                cornerDefinitions:
                    cornerDefinitionsV084,
                allowsFullScreenPresentation: false
            )
        }
    }

    private func zapiszWymiar(
        _ context: KontekstEdycjiWymiaru2D,
        nowaWartosc: Millimeters
    ) async -> Bool {
        switch context.cel {
        case .dlugoscSciany:
            return await onUpdateWall(
                WallMeasurementUpdate(
                    wallID: wall.id,
                    name: wall.name,
                    length: nowaWartosc,
                    thickness: wall.thickness,
                    startHeight: wall.startHeight,
                    endHeight: wall.endHeight,
                    constructionType: wall.constructionType,
                    notes: wall.notes
                )
            )

        case .wysokoscSciany:
            guard let length = room.geometry.geometry(
                of: wall.id
            )?.length else {
                return false
            }

            return await onUpdateWall(
                WallMeasurementUpdate(
                    wallID: wall.id,
                    name: wall.name,
                    length: length,
                    thickness: wall.thickness,
                    startHeight: nowaWartosc,
                    endHeight: nowaWartosc,
                    constructionType: wall.constructionType,
                    notes: wall.notes
                )
            )

        case .szerokoscModulu,
             .wysokoscModulu,
             .glebokoscModulu:
            // Wymiary modułu są zapisywane przez pełny konfigurator,
            // aby zachować synchronizację karty technicznej i szuflad.
            return false
        }
    }

    @ViewBuilder
    private var runAssistantMenu: some View {
        Menu {
            Section("Wykryte ciągi") {
                if detectedRuns.isEmpty {
                    Button("Brak wykrytych ciągów") {}
                        .disabled(true)
                } else {
                    ForEach(detectedRuns) { run in
                        Button {
                            selectedFurnitureID =
                                run.assemblyIDs.first
                        } label: {
                            Label(
                                "\(run.kind.title) • \(formatted(run.width))",
                                systemImage: run.kind.systemImage
                            )
                        }
                    }
                }
            }

            if let selectedFurniture {
                Section("Uzupełnianie ciągu") {
                    ForEach(
                        KitchenAddDirectionV015.allCases,
                        id: \.self
                    ) { direction in
                        if availableDirections.contains(direction) {
                            Button {
                                beginDirectionalAddition(
                                    selectedFurniture.id,
                                    direction
                                )
                            } label: {
                                Label(
                                    direction.title,
                                    systemImage: direction.systemImage
                                )
                            }
                        }
                    }

                    if availableDirections.isEmpty {
                        Button("Brak miejsca na kolejny moduł") {}
                            .disabled(true)
                    }
                }

                Section("Sugerowane wykończenie") {
                    if finishingSuggestions.isEmpty {
                        Button("Brak wymaganych blend") {}
                            .disabled(true)
                    } else {
                        ForEach(finishingSuggestions) { suggestion in
                            Button {
                                addFinishing(suggestion)
                            } label: {
                                Label(
                                    suggestion.title,
                                    systemImage: suggestion.kind.systemImage
                                )
                            }
                        }
                    }
                }
            } else {
                Section {
                    Button("Zaznacz moduł na elewacji") {}
                        .disabled(true)
                }
            }
        } label: {
            Label(
                "Asystent ciągu",
                systemImage: "wand.and.stars"
            )
        }
    }

    private var poziomWymiarowania:
        PoziomWymiarowania2D {
        PoziomWymiarowania2D(
            rawValue: poziomWymiarowaniaRaw
        ) ?? .podstawowe
    }

    private var poziomWymiarowaniaBinding:
        Binding<PoziomWymiarowania2D> {
        Binding(
            get: {
                poziomWymiarowania
            },
            set: { newValue in
                poziomWymiarowaniaRaw = newValue.rawValue
            }
        )
    }

    private var assembliesOnWall: [FurnitureAssembly] {
        cachedAssembliesOnWall
    }

    private var selectedFurniture: StoredFurnitureAssembly? {
        mebleViewModel.storedAssembly(id: selectedFurnitureID)
    }

    private var editedFurniture: StoredFurnitureAssembly? {
        mebleViewModel.storedAssembly(id: editedFurnitureID)
    }

    private var numberedItemsOnWall: [FurnitureCanvasItemV016] {
        cachedNumberedItemsOnWall
    }

    private var detectedRuns: [KitchenRunV015] {
        cachedRunsOnWall
    }

    // PERF: availableDirections cached w @State, aktualizowane gdy
    // zmienia się selectedFurnitureID lub renderRevision (nie co render).
    private var availableDirections: Set<KitchenAddDirectionV015> {
        cachedAvailableDirectionsV092
    }

    private var finishingSuggestions: [KitchenFinishingSuggestionV015] {
        mebleViewModel.finishingSuggestions(
            for: selectedFurniture,
            wall: wall,
            room: room
        )
    }

    /// Długość ściany dla planera ciągu.
    ///
    /// Ta sama droga co reszta widoku: realna geometria obrysu, a nie pole
    /// segmentu — przy pomiarze prowadzonym te dwie wartości potrafią się różnić.
    private var dlugoscScianyDlaPropozycjiV095: Millimeters {
        room.geometry.geometry(of: wall.id)?.length ?? .zero
    }

    private var availableTemplates: [FurnitureTemplate] {
        guard let directionalAddition,
              let source = mebleViewModel.storedAssembly(
                  id: directionalAddition.sourceAssemblyID
              ) else {
            return mebleViewModel.templates.filter {
                !StandardKitchenFinishingTemplatesV015
                    .isFinishingTemplate($0)
            }
        }

        return mebleViewModel.directionalTemplates(
            relativeTo: source,
            direction: directionalAddition.direction,
            wall: wall,
            room: room
        )
    }

    private func suggestedPlacement(
        for template: FurnitureTemplate
    ) -> SugerowanePolozenieModulu {
        guard let directionalAddition,
              let source = mebleViewModel.storedAssembly(
                  id: directionalAddition.sourceAssemblyID
              ),
              let suggestion = mebleViewModel.directionalSuggestion(
                  for: template,
                  relativeTo: source,
                  direction: directionalAddition.direction,
                  wall: wall,
                  room: room
              ) else {
            return mebleViewModel.suggestedPlacement(
                for: template,
                wall: wall,
                room: room
            )
        }

        return suggestion
    }

    private func beginDirectionalAddition(
        _ assemblyID: FurnitureAssemblyID,
        _ direction: KitchenAddDirectionV015
    ) {
        directionalAddition = KitchenDirectionalAdditionV015(
            sourceAssemblyID: assemblyID,
            direction: direction
        )
        pokazSheetV084(.furnitureLibrary)
    }

    private func czyModulNaroznyV084(
        _ stored: StoredFurnitureAssembly
    ) -> Bool {
        let moduleName =
            stored.assembly.name.lowercased()
        let templateName =
            mebleViewModel.template(for: stored)?
                .name
                .lowercased() ?? ""
        let combined = moduleName + " " + templateName

        return combined.contains("narożn")
            || combined.contains("narozn")
            || combined.contains("corner")
            || combined.contains("ślep")
            || combined.contains("slep")
            || combined.contains("skośn")
            || combined.contains("skos")
    }

    /// Utrwala definicję narożnika ustawioną w karcie modułu.
    ///
    /// Robiło to dotąd zamknięcie osobnego sheeta narożnika. Po wciągnięciu
    /// narożnika do `KartaModuluV097` moment zapisu przenosi się na zamknięcie
    /// karty — bez tego mechanizm, blenda i światło wysokości przepadałyby
    /// przy wyjściu, a `AssemblyInspector` dostawałby stary stan.
    private func zapiszNaroznikPoEdycjiV0101() {
        guard let id = editedFurnitureID,
              let definition = cornerDefinitionsV084.first(
                  where: { $0.assemblyID == id }
              )
        else { return }

        CornerCabinetRepositoryV025.save(definition)
        mebleViewModel.forceRenderRefresh()
    }

    private func addFinishing(
        _ suggestion: KitchenFinishingSuggestionV015
    ) {
        Task {
            let didCreate = await mebleViewModel.createFinishing(
                from: suggestion,
                wall: wall,
                room: room
            )

            if didCreate {
                selectedFurnitureID =
                    mebleViewModel.lastCreatedAssemblyID
            }
        }
    }

    // MARK: - Run Summary Bar (Task 56)

    @ViewBuilder
    private var runSummaryBarV082: some View {
        let wallLengthMM = room.geometry.geometry(of: wall.id)?.length.rawValue ?? 0
        let totalModuleWidthMM = assembliesOnWall.reduce(0.0) { $0 + $1.size.width.rawValue }
        let fillRatio = wallLengthMM > 0 ? min(totalModuleWidthMM / wallLengthMM, 1.0) : 0

        if wallLengthMM > 0 {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    // Pasek postępu
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemFill))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(fillRatio > 0.99
                                      ? Color.orange
                                      : (fillRatio > 0.85 ? Color.yellow : Color.accentColor))
                                .frame(width: geo.size.width * fillRatio, height: 6)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 24)

                    // Etykieta
                    Text(
                        "\(Int(totalModuleWidthMM)) / \(Int(wallLengthMM)) mm"
                        + (wallLengthMM - totalModuleWidthMM > 0
                           ? " · wolne: \(Int(wallLengthMM - totalModuleWidthMM)) mm"
                           : "")
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(fillRatio > 0.99 ? .orange : .secondary)
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                Divider()
            }
            .background(Color(.systemBackground).opacity(0.6))
        }
    }

    // MARK: - Sugestie wykończeń strip (Task 53)

    @ViewBuilder
    private var finishingSuggestionsStripV082: some View {
        let suggestions = allFinishingSuggestionsV082
        if !suggestions.isEmpty {
            VStack(spacing: 0) {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Label("Sugestie", systemImage: "wand.and.stars")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)

                        ForEach(suggestions) { suggestion in
                            Button {
                                addFinishing(suggestion)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: suggestion.kind.systemImage)
                                        .font(.caption)
                                    Text(suggestion.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
                .frame(height: 44)
                .background(Color(.systemBackground).opacity(0.5))
                Divider()
            }
        }
    }

    /// Zwraca sugestie dla wszystkich modułów na ścianie (nie tylko zaznaczonego).
    /// PERF: wynik cachowany w cachedAllFinishingSuggestionsV092 — obliczany tylko
    /// gdy zmieni się renderRevision (nie co render).
    private var allFinishingSuggestionsV082: [KitchenFinishingSuggestionV015] {
        cachedAllFinishingSuggestionsV092
    }

    /// IDs modułów kolidujących — aktualizowane przez refreshRenderCaches(), nie per render.
    private var collidingFurnitureIDsV083: Set<FurnitureAssemblyID> {
        cachedCollidingIDsV083
    }

    // MARK: - Render cache refresh

    /// Przelicza dane kosztowne (kolizje O(N²), numerowanie, runs) i zapisuje w @State.
    /// Wywoływana tylko przy faktycznych zmianach modelu (onAppear + onChange renderRevision),
    /// NIE przy każdym render pass (tap, drag, selection change).
    private func refreshRenderCaches() {
        let onWall = mebleViewModel.assemblies.filter {
            $0.placement?.wallID == wall.id
        }
        cachedAssembliesOnWall = onWall
        cachedCollidingIDsV083 = MebelCollisionValidatorV0143.allCollidingIDs(
            among: onWall
        )
        let allNumbered = FurnitureCanvasNumberingV016.make(
            room: room,
            storedAssemblies: mebleViewModel.storedAssemblies
        )
        cachedNumberedItemsOnWall = FurnitureCanvasNumberingV016.items(
            on: wall.id,
            from: allNumbered
        )
        cachedRunsOnWall = mebleViewModel.kitchenRuns(on: wall)

        // Task #92: sugestie dla WSZYSTKICH modułów na ścianie — drogie,
        // cachowane razem z resztą render data.
        let storedOnWall = mebleViewModel.storedAssemblies.filter {
            $0.assembly.placement?.wallID == wall.id
        }
        var seen = Set<String>()
        cachedAllFinishingSuggestionsV092 = storedOnWall.flatMap {
            mebleViewModel.finishingSuggestions(for: $0, wall: wall, room: room)
        }.filter { seen.insert($0.id).inserted }

        // Task #92: kierunki dla aktualnie zaznaczonego mebla
        refreshAvailableDirectionsV092()
    }

    /// Przelicza wolne kierunki tylko gdy zmienia się zaznaczony moduł LUB model.
    private func refreshAvailableDirectionsV092() {
        guard let sf = selectedFurniture else {
            cachedAvailableDirectionsV092 = []
            return
        }
        cachedAvailableDirectionsV092 = mebleViewModel.availableDirections(
            for: sf,
            wall: wall,
            room: room
        )
    }

    private func formatted(
        _ value: Millimeters
    ) -> String {
        let number = value.rawValue.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
        return "\(number) mm"
    }
}

private struct SlidingWardrobeElevationSystemPanelV093:
    View
{
    let run:
        SlidingWardrobeModuleRunV087
    @Binding var doorFill:
        SlidingWardrobeDoorFillV093
    @Binding var doorCount:
        Int
    let isSaving:
        Bool
    let onAddSystem:
        () -> Void

    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing:
                    10
            ) {
                Label(
                    "System przesuwny",
                    systemImage:
                        "door.sliding.left.hand.closed"
                )
                .font(.subheadline.weight(.semibold))

                Spacer()

                Text(
                    run.isProductionReady
                    ? "gotowy"
                    : "\(resolvedDoorCount) skrzydła"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    run.isProductionReady
                    ? .green
                    : Color.accentColor
                )
            }

            HStack(spacing: 10) {
                Picker(
                    "Wypełnienie",
                    selection:
                        $doorFill
                ) {
                    ForEach(
                        SlidingWardrobeDoorFillV093
                            .allCases
                    ) {
                        fill in

                        Label(
                            fill.title,
                            systemImage:
                                fill.systemImage
                        )
                        .tag(fill)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(
                    run.isProductionReady
                    || isSaving
                )

                Picker(
                    "Skrzydła",
                    selection:
                        $doorCount
                ) {
                    Text(
                        "Auto \(run.doorCount)"
                    )
                    .tag(0)

                    ForEach(
                        2...4,
                        id:
                            \.self
                    ) {
                        count in

                        Text(
                            "\(count)"
                        )
                        .tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 184)
                .disabled(
                    run.isProductionReady
                    || isSaving
                )

                Button(
                    action:
                        onAddSystem
                ) {
                    Label(
                        run.actionTitle,
                        systemImage:
                            run.isProductionReady
                            ? "checkmark.circle"
                            : "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    run.isProductionReady
                    || isSaving
                )
            }

            VStack(
                alignment:
                    .leading,
                spacing:
                    6
            ) {
                HStack(spacing: 8) {
                    Label(
                        run.scopeLabel == nil
                        ? "Zakres: cały wykryty ciąg"
                        : "Zakres: \(run.scopeLabel ?? "zaznaczenie")",
                        systemImage:
                            run.scopeLabel == nil
                            ? "rectangle.3.group"
                            : "selection.pin.in.out"
                    )

                    Spacer(minLength: 0)

                    Text(
                        run.moduleDimensionLabel
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    run.scopeLabel == nil
                    ? .secondary
                    : Color.accentColor
                )

                if run.hasMixedDepths {
                    Label(
                        "Różne głębokości w zakresie. Sprawdź, czy pod drzwiami są tylko właściwe moduły.",
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                if run.hasLegacySystemWithoutBinding {
                    Label(
                        "Wykryto stary system bez przypięcia do modułów. Przepnij go przed dalszą edycją.",
                        systemImage:
                            "link.badge.plus"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }

                if run.systemNeedsRefresh {
                    Label(
                        "Moduły zmieniły wymiar albo położenie. Zaktualizuj tory i skrzydła.",
                        systemImage:
                            "arrow.triangle.2.circlepath"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                moduleRows
            }
            .padding(10)
            .background(
                StolarniaPalette.canvasInset,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            8,
                        style:
                            .continuous
                    )
            )

            HStack(spacing: 12) {
                metric(
                    "Front",
                    "\(Int(run.width.rawValue)) mm"
                )
                metric(
                    "Wys.",
                    "\(Int(run.height.rawValue)) mm"
                )
                metric(
                    "Status",
                    run.isProductionReady
                    ? "komplet"
                    : run.missingPartsLabel
                )
            }
        }
        .padding(12)
        .background(
            StolarniaPalette.canvasRaised,
            in: RoundedRectangle(
                cornerRadius:
                    8,
                style:
                    .continuous
            )
        )
    }

    private var resolvedDoorCount:
        Int
    {
        doorCount > 0
        ? doorCount
        : run.doorCount
    }

    private var moduleRows:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {
            if let module = modulePreview(at: 0) {
                moduleRow(module)
            }
            if let module = modulePreview(at: 1) {
                moduleRow(module)
            }
            if let module = modulePreview(at: 2) {
                moduleRow(module)
            }
            if let module = modulePreview(at: 3) {
                moduleRow(module)
            }
            if let module = modulePreview(at: 4) {
                moduleRow(module)
            }
            if let module = modulePreview(at: 5) {
                moduleRow(module)
            }
            if run.modulePreviews.count > 6 {
                Text(
                    "+\(run.modulePreviews.count - 6) modułów w zakresie"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func modulePreview(
        at index:
            Int
    ) -> SlidingWardrobeModulePreviewV093? {
        guard index >= 0,
              index < run.modulePreviews.count else {
            return nil
        }

        return run.modulePreviews[index]
    }

    private func moduleRow(
        _ module:
            SlidingWardrobeModulePreviewV093
    ) -> some View {
        HStack(spacing: 8) {
            Text(module.name)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(
                "\(Int(module.width.rawValue.rounded())) x \(Int(module.depth.rawValue.rounded())) mm"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(
                module.depth == run.depth
                ? Color.secondary
                : Color.orange
            )
        }
        .font(.caption)
    }

    private func metric(
        _ title:
            String,
        _ value:
            String
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                2
        ) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
