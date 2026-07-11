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
    case productionAssistant
    case furnitureLibrary

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
    @State private var activeSheet: ElewacjaScianySheet?
    @State private var activeFullScreen: ElewacjaScianyFullScreen?
    @State private var edytowanyWymiar:
        KontekstEdycjiWymiaru2D?
    @State private var poczatkowePoleEdycji:
        PoleWymiaruModulu2D?
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

                ElewacjaScianyCanvasView(
                    room: room,
                    wall: wall,
                    assemblies: mebleViewModel.assemblies,
                    numberedItems: numberedItemsOnWall,
                    runs: detectedRuns,
                    availableDirections: availableDirections,
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
                            poczatkowePoleEdycji =
                                context.cel.poleModulu
                            editedFurnitureID = furnitureID
                        } else {
                            edytowanyWymiar = context
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
                // Nie używamy .id(renderRevision) — canvas sam
                // obsługuje refresh przez cachedFurniture + onChange.
                // .id() niszczyłoby @State dragu przy każdym zapisie.

                Divider()

                finishingSuggestionsStripV082

                FurnitureLegendV016(
                    title: "Legenda elewacji",
                    items: numberedItemsOnWall,
                    selectedFurnitureID: $selectedFurnitureID,
                    maximumHeight: 108
                )

                if let selectedFurniture {
                    VStack(spacing: 0) {
                        Divider()

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
                                poczatkowePoleEdycji = nil
                                editedFurnitureID = selectedFurniture.id
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

                        // Quick-edit strip — szuflady/półki jednym tapem przy kliencie
                        if mebleViewModel.template(for: selectedFurniture) != nil {
                            SzybkiEdytorModuluV083(
                                storedAssembly: selectedFurniture,
                                mebleViewModel: mebleViewModel,
                                wall: wall,
                                room: room,
                                onFullEdit: {
                                    poczatkowePoleEdycji = nil
                                    editedFurnitureID = selectedFurniture.id
                                }
                            )
                        }
                    }
                }
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
                        activeSheet = .globalMaterials
                    } label: {
                        Label(
                            "Materiały globalne",
                            systemImage: "paintpalette"
                        )
                    }

                    runAssistantMenu

                    Menu {
                        Button {
                            activeSheet = .projectCard
                        } label: {
                            Label(
                                "Karta projektu",
                                systemImage: "doc.richtext"
                            )
                        }
                        .disabled(assembliesOnWall.isEmpty)

                        Button {
                            activeSheet = .creator
                        } label: {
                            Label(
                                "Kreator mebla",
                                systemImage: "square.grid.3x3.square"
                            )
                        }

                        Button {
                            activeSheet = .productionAssistant
                        } label: {
                            Label(
                                "Asystent zabudowy",
                                systemImage: "wand.and.rays"
                            )
                        }
                    } label: {
                        Label("Więcej", systemImage: "ellipsis.circle")
                    }
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
            // Edycja modułu tym samym mechanizmem co kreator rysunkowy —
            // pełny ekran dla czytelności; moduł odtwarzany z komponentów,
            // więc działa też dla zespołów bez szablonu.
            .fullScreenCover(isPresented: Binding(
                get: {
                    editedFurniture != nil
                },
                set: { isPresented in
                    if !isPresented {
                        editedFurnitureID = nil
                        poczatkowePoleEdycji = nil
                    }
                }
            )) {
                if let editedFurniture {
                    ModulEdytorElewacjiView(
                        modul: .reconstructed(
                            from: editedFurniture.assembly
                        ),
                        onZapisz: { modul in
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

    private func elevationActionBarContent(
        showsHint: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                directionalAddition = nil
                activeSheet = .furnitureLibrary
            } label: {
                Label(
                    "Dodaj moduł",
                    systemImage: "plus.square.on.square"
                )
            }
            .buttonStyle(
                StolarniaPrimaryButtonStyle(
                    minHeight: 44,
                    horizontalPadding: 14,
                    cornerRadius: 12
                )
            )
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(3)
            .accessibilityIdentifier(
                "addFurnitureModuleButtonV024"
            )

            Button {
                activeSheet = .creator
            } label: {
                if showsHint {
                    Label(
                        "Kreator mebla",
                        systemImage: "square.grid.3x3.square"
                    )
                } else {
                    Label(
                        "Kreator mebla",
                        systemImage: "square.grid.3x3.square"
                    )
                    .labelStyle(.iconOnly)
                    .frame(width: 28)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(StolarniaPalette.accent)
            .help("Kreator mebla")
            .accessibilityLabel("Kreator mebla")

            Button {
                activeFullScreen = .preview3D
            } label: {
                Label(
                    "Podgląd 3D",
                    systemImage: "cube.transparent"
                )
                .labelStyle(.iconOnly)
                .frame(width: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(StolarniaPalette.accent)
            .disabled(assembliesOnWall.isEmpty)
            .help("Podgląd 3D")
            .accessibilityLabel("Podgląd 3D")

            Button {
                activeFullScreen = .technicalDocumentation
            } label: {
                Label(
                    "Dokumentacja techniczna",
                    systemImage: "doc.text.magnifyingglass"
                )
                .labelStyle(.iconOnly)
                .frame(width: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(StolarniaPalette.accent)
            .disabled(assembliesOnWall.isEmpty)
            .help("Dokumentacja techniczna")
            .accessibilityIdentifier(
                "technicalDocumentationButtonV023"
            )
            .accessibilityLabel("Dokumentacja techniczna")

            KontrolkaPoziomuWymiarowania2D(
                poziom: poziomWymiarowaniaBinding
            )
            .layoutPriority(2)

            if showsHint {
                Spacer(minLength: 8)

                Label(
                    trybWielokrotnegoZaznaczaniaV066
                        ? "Przeciągnij ramkę po pustym obszarze"
                        : "Przeciągnij moduł lub dotknij wymiaru",
                    systemImage:
                        trybWielokrotnegoZaznaczaniaV066
                        ? "rectangle.dashed"
                        : "hand.tap"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: 260, alignment: .leading)
                .layoutPriority(0)
            }
        }
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

        case .productionAssistant:
            KitchenProductionAssistantViewV019(
                wall: wall,
                room: room,
                assemblies: assembliesOnWall
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
            TechnicalDocumentationViewV023(
                room: room,
                wall: wall,
                assemblies: assembliesOnWall,
                allAssemblies:
                    mebleViewModel.assemblies
            )

        case .preview3D:
            Furniture3DPreviewViewV017(
                title: "3D: \(wall.name)",
                assemblies: assembliesOnWall,
                globalneMaterialy:
                    globalneMaterialyRepository
                        .ustawienia,
                room: room,
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
        activeSheet = .furnitureLibrary
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
