import DomainCore
import Persistence
import SwiftUI

enum TrybWorkspaceProjektowegoV063: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case elewacja = "Elewacja"
    case widok3D = "3D"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .plan: return "square.grid.2x2"
        case .elewacja: return "rectangle.portrait"
        case .widok3D: return "cube"
        }
    }
}

private enum WorkspaceProjektowySheetV063:
    Identifiable
{
    case furnitureLibrary(WallID)
    case sciankaPodziałowa(SciankaPodzialowaDefinicjaV075?)
    case furnitureCreator
    case layoutPrzeglad
    case wykonczeniaKuchni

    var id: String {
        switch self {
        case .furnitureLibrary(let wallID):
            return "furniture-library.\(wallID.description)"
        case .sciankaPodziałowa(let s):
            return "scianka-\(s?.id.uuidString ?? "nowa")"
        case .furnitureCreator:
            return "furniture-creator"
        case .layoutPrzeglad:
            return "layout-przeglad"
        case .wykonczeniaKuchni:
            return "wykończenia-kuchni"
        }
    }
}

struct WorkspaceProjektowyViewV063: View {
    @Environment(\.dismiss) private var dismiss

    let room: RoomDefinition
    @ObservedObject var mebleViewModel: MeblePomieszczeniaViewModel
    @ObservedObject var globalneMaterialyRepository:
        GlobalneMaterialyPomieszczeniaRepository
    @Binding var selectedWallID: WallID?
    @Binding var selectedFurnitureID: FurnitureAssemblyID?
    let onUpdateWall: (WallMeasurementUpdate) async -> Bool
    let onEditSlope: (WallSegment) -> Void

    @State private var destinationV074:
        WorkspaceDestinationV074 = .plan
    @State private var kolumnyV074:
        NavigationSplitViewVisibility = .all
    @State private var pokazInspektorV074 = false
    @ObservedObject var sciankaRepo: SciankaPodzialowaRepository
    @StateObject private var historiaV065 = HistoriaEdycjiModulowV065()
    @StateObject private var bazaMaterialowRepository = BazaMaterialowRepository()
    @State private var presentation3D = Furniture3DPresentationStateV017()
    @State private var activeSheetV063:
        WorkspaceProjektowySheetV063?
    @State private var pokazKreatorElewacjiV090 = false
    @State private var pokazPotwierdzenieUsunieciaV065 = false
    @StateObject private var wykonczeniaRepo = WykonczeniaKuchenneRepositoryV082()
    @State private var dxfExportURL: URL?
    @State private var idsDoUsunieciaV066: Set<FurnitureAssemblyID> = []
    @State private var zaznaczoneFurnitureIDsV066:
        Set<FurnitureAssemblyID> = []
    @State private var trybWielokrotnegoZaznaczaniaV066 = false

    // MARK: - Performance caches (Task #91)
    // listaFormatekV074 i reportGotowosciV078 były drogie computed vars
    // przeliczane przy KAŻDYM render (tab switch, tap modułu, itp.).
    // Teraz aktualizowane wyłącznie gdy zmieni się mebleViewModel.renderRevision.
    @State private var cachedListaFormatekV074: ListaFormatekProjektuV070 =
        .init(nazwaProjektu: "", dataUtworzenia: .distantPast, formatki: [])
    @State private var cachedReportGotowosciV074: ProjectReadinessReportV078 =
        .init(issues: [])
    @State private var cachedNumberedItemsV074: [FurnitureCanvasItemV016] = []

    @AppStorage(
        Wymiarowanie2DUstawienia.poziomAppStorageKey
    ) private var poziomWymiarowaniaRaw =
        PoziomWymiarowania2D.podstawowe.rawValue

    var body: some View {
        NavigationSplitView(
            columnVisibility:
                $kolumnyV074
        ) {
            WorkspaceNawigacjaV074(
                wybor:
                    $destinationV074,
                nazwaProjektu:
                    room.name,
                liczbaModulow:
                    mebleViewModel
                        .storedAssemblies
                        .count,
                liczbaFormatek:
                    listaFormatekV074
                        .liczbaFormatek,
                liczbaBlokadGotowosci:
                    reportGotowosciV078
                        .blockingCount,
                liczbaOstrzezenGotowosci:
                    reportGotowosciV078
                        .warningCount
            )
            .navigationSplitViewColumnWidth(
                min: 238,
                ideal: 278,
                max: 330
            )
        } detail: {
            NavigationStack {
                workspaceDetailV074
                    .navigationTitle(
                        destinationV074
                            .tytul
                    )
                    .navigationBarTitleDisplayMode(
                        .inline
                    )
                    .toolbar {
                        toolbarWorkspaceV074
                    }
                    .confirmationDialog(
                        tytulPotwierdzeniaUsunieciaV066,
                        isPresented:
                            $pokazPotwierdzenieUsunieciaV065,
                        titleVisibility:
                            .visible
                    ) {
                        Button(
                            etykietaPrzyciskuUsunieciaV066,
                            role: .destructive
                        ) {
                            usunWskazaneModulyV066()
                        }

                        Button(
                            "Anuluj",
                            role: .cancel
                        ) {
                            idsDoUsunieciaV066
                                .removeAll()
                        }
                    } message: {
                        Text(
                            opisPotwierdzeniaUsunieciaV066
                        )
                    }
                    .fullScreenCover(
                        isPresented: $pokazKreatorElewacjiV090
                    ) {
                        ModulEdytorElewacjiView()
                    }
                    .sheet(item: $activeSheetV063) {
                        sheet in

                        activeSheetViewV063(sheet)
                    }
                    .onChange(of: selectedFurnitureID) { _, newValue in
                        zsynchronizujGlowneZaznaczenieV066(newValue)
                    }
                    .onChange(of: mebleViewModel.renderRevision) { _, _ in
                        usunNieistniejaceZaznaczeniaV066()
                        refreshWorkspaceCachesV091()
                    }
            }
        }
        .navigationSplitViewStyle(
            .balanced
        )
        .onAppear {
            wykonczeniaRepo.setup(roomID: String(describing: room.id))
            refreshWorkspaceCachesV091()
        }
    }

    @ViewBuilder
    private var workspaceDetailV074:
        some View
    {
        if destinationV074
            .jestProjektem {
            projektContentV074
        } else {
            produkcjaContentV074
        }
    }

    private var projektContentV074:
        some View
    {
        centralContent
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .inspector(
                isPresented:
                    $pokazInspektorV074
            ) {
                InspektorWorkspaceV063(
                    room: room,
                    storedAssembly:
                        selectedFurniture,
                    selectedAssembliesV066:
                        selectedAssembliesV066,
                    selectionSummaryV066:
                        selectionSummaryV066,
                    trybWielokrotnegoZaznaczaniaV066:
                        trybWielokrotnegoZaznaczaniaV066,
                    selectedWall:
                        selectedWall,
                    onClearSelection: {
                        wyczyscZaznaczenieV066()
                    },
                    onToggleMultiSelectionV066: {
                        ustawTrybWielokrotnegoZaznaczaniaV066(
                            !trybWielokrotnegoZaznaczaniaV066
                        )
                    },
                    onSelectAllOnWallV066: {
                        zaznaczWszystkieNaAktywnejScianieV066()
                    },
                    onGroupOperationV066: {
                        operation in

                        wykonajOperacjeGrupowaV066(
                            operation
                        )
                    },
                    onNudge: {
                        dx,
                        dy in

                        przesunZaznaczonyV064(
                            dx: dx,
                            dy: dy
                        )
                    },
                    onDuplicate: {
                        duplikujAktywneZaznaczenieV067()
                    },
                    onDelete: {
                        poprosOUsuniecieZaznaczonegoV065()
                    },
                    onAddModuleToWall: {
                        wall in

                        rozpocznijDodawanieModuluV063(
                            na: wall
                        )
                    },
                    onEditSlope: { wall in
                        onEditSlope(wall)
                    },
                    onOpenCreator: {
                        activeSheetV063 = .furnitureCreator
                    }
                )
                .inspectorColumnWidth(
                    min: 280,
                    ideal: 320,
                    max: 390
                )
            }
    }

    private var produkcjaContentV074:
        some View
    {
        RozkrojPlytViewV071(
            projectName:
                room.name,
            room:
                room,
            assemblies:
                mebleViewModel
                    .storedAssemblies,
            materialy:
                globalneMaterialyRepository
                    .ustawienia,
            zakladkaV074:
                produkcjaZakladkaBindingV074,
            prezentacjaV074:
                .osadzona
        )
        .id(
            mebleViewModel
                .renderRevision
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private var produkcjaZakladkaBindingV074:
        Binding<ZakladkaProdukcjiV071>
    {
        Binding(
            get: {
                destinationV074
                    .zakladkaProdukcji
                ?? .pulpit
            },
            set: {
                destinationV074 =
                    WorkspaceDestinationV074(
                        zakladkaProdukcji:
                            $0
                    )
            }
        )
    }

    private var aktywnyTrybProjektowyV074:
        TrybWorkspaceProjektowegoV063
    {
        destinationV074
            .trybProjektowy
        ?? .plan
    }

    // PERF: Te vars zwracają teraz wartości z cache (@State).
    // Faktyczne obliczenia są w refreshWorkspaceCachesV091().
    private var listaFormatekV074: ListaFormatekProjektuV070 {
        cachedListaFormatekV074
    }

    private var reportGotowosciV078: ProjectReadinessReportV078 {
        cachedReportGotowosciV074
    }

    @ToolbarContentBuilder
    private var toolbarWorkspaceV074:
        some ToolbarContent
    {
        ToolbarItem(
            placement:
                .cancellationAction
        ) {
            Button("Zamknij") {
                dismiss()
            }
        }

        if destinationV074
            .jestProjektem {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    Task {
                        let result =
                            await historiaV065
                                .cofnij(
                                    viewModel:
                                        mebleViewModel
                                )

                        if result.powodzenie {
                            zastosujZaznaczeniePoHistoriiV066(
                                result
                            )
                        }
                    }
                } label: {
                    Label(
                        "Cofnij",
                        systemImage:
                            "arrow.uturn.backward"
                    )
                }
                .disabled(
                    !historiaV065
                        .moznaCofnac
                )
                .keyboardShortcut(
                    "z",
                    modifiers: .command
                )
                .help(
                    historiaV065
                        .nazwaCofniecia
                        .map {
                            "Cofnij: \($0)"
                        }
                    ?? "Brak operacji do cofnięcia"
                )

                Button {
                    Task {
                        let result =
                            await historiaV065
                                .ponow(
                                    viewModel:
                                        mebleViewModel
                                )

                        if result.powodzenie {
                            zastosujZaznaczeniePoHistoriiV066(
                                result
                            )
                        }
                    }
                } label: {
                    Label(
                        "Ponów",
                        systemImage:
                            "arrow.uturn.forward"
                    )
                }
                .disabled(
                    !historiaV065
                        .moznaPonowic
                )
                .keyboardShortcut(
                    "z",
                    modifiers:
                        [
                            .command,
                            .shift
                        ]
                )
                .help(
                    historiaV065
                        .nazwaPonowienia
                        .map {
                            "Ponów: \($0)"
                        }
                    ?? "Brak operacji do ponowienia"
                )
            }

            if aktywnyTrybProjektowyV074 == .plan {
                ToolbarItem(
                    placement:
                        .primaryAction
                ) {
                    Button {
                        rozpocznijDodawanieModuluZPlanuV077()
                    } label: {
                        Label(
                            "Dodaj moduł",
                            systemImage:
                                "plus.square.on.square"
                        )
                    }
                    .disabled(
                        room
                            .geometry
                            .walls
                            .isEmpty
                    )
                    .keyboardShortcut(
                        "n",
                        modifiers: .command
                    )
                    .help(
                        "Dodaj mebel do aktywnej ściany w Planie 2D"
                    )
                }
            }

            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Menu {
                    Button {
                        ustawTrybWielokrotnegoZaznaczaniaV066(
                            !trybWielokrotnegoZaznaczaniaV066
                        )
                    } label: {
                        Label(
                            trybWielokrotnegoZaznaczaniaV066
                                ? "Zakończ wybór wielu"
                                : "Wybierz wiele modułów",
                            systemImage:
                                trybWielokrotnegoZaznaczaniaV066
                                ? "checkmark.circle.fill"
                                : "checkmark.circle"
                        )
                    }

                    Button {
                        zaznaczWszystkieNaAktywnejScianieV066()
                    } label: {
                        Label(
                            "Zaznacz całą ścianę",
                            systemImage:
                                "checkmark.circle"
                        )
                    }
                    .disabled(
                        mebleNaAktywnejScianieV066
                            .isEmpty
                    )

                    Divider()

                    Button {
                        duplikujAktywneZaznaczenieV067()
                    } label: {
                        Label(
                            "Duplikuj",
                            systemImage:
                                "plus.square.on.square"
                        )
                    }
                    .disabled(
                        aktywnieZaznaczoneIDsV066
                            .isEmpty
                        || mebleViewModel
                            .isSaving
                        || (
                            aktywnieZaznaczoneIDsV066
                                .count > 1
                            && !selectionSummaryV066
                                .maWspolnaSciane
                        )
                    )

                    Button(
                        role: .destructive
                    ) {
                        poprosOUsuniecieZaznaczonegoV065()
                    } label: {
                        Label(
                            "Usuń",
                            systemImage:
                                "trash"
                        )
                    }
                    .disabled(
                        aktywnieZaznaczoneIDsV066
                            .isEmpty
                        || mebleViewModel
                            .isSaving
                    )

                } label: {
                    Label(
                        "Edycja",
                        systemImage:
                            "ellipsis.circle"
                    )
                }
                .help(
                    "Zaznaczanie, duplikowanie i usuwanie modułów"
                )
            }

            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Button {
                    pokazInspektorV074
                        .toggle()
                } label: {
                    Label(
                        pokazInspektorV074
                            ? "Ukryj inspektor"
                            : "Pokaż inspektor",
                        systemImage:
                            "sidebar.trailing"
                    )
                }
                .help(
                    pokazInspektorV074
                        ? "Ukryj panel właściwości"
                        : "Pokaż panel właściwości"
                )
            }

            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Menu {
                    if sciankaRepo.sciankiDzielace.isEmpty {
                        Button {
                            activeSheetV063 = .sciankaPodziałowa(nil)
                        } label: {
                            Label("Dodaj ściankę dzielącą", systemImage: "door.sliding.left.hand.open")
                        }
                    } else {
                        ForEach(sciankaRepo.sciankiDzielace) { scianka in
                            Button {
                                activeSheetV063 = .sciankaPodziałowa(scianka)
                            } label: {
                                Label(scianka.nazwa, systemImage: "door.sliding.left.hand.open")
                            }
                        }
                        Divider()
                        Button {
                            activeSheetV063 = .sciankaPodziałowa(nil)
                        } label: {
                            Label("Dodaj nową ściankę", systemImage: "plus")
                        }
                    }
                } label: {
                    Label("Ścianki dzielące", systemImage: "door.sliding.left.hand.open")
                }
                .help("Zarządzaj ściankami dzielącymi (drzwi przesuwne Bonari)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    activeSheetV063 = .wykonczeniaKuchni
                } label: {
                    Label(
                        "Wykończenia",
                        systemImage: "rectangle.portrait.topleft.inset.filled"
                    )
                    .symbolVariant(wykonczeniaRepo.maPozycje ? .fill : .none)
                }
                .help("Blaty, fartuch, listwy i wieńce wykończeniowe")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    pokazKreatorElewacjiV090 = true
                } label: {
                    Label(
                        "Kreator rysunkowy",
                        systemImage: "pencil.and.ruler"
                    )
                }
                .help("Rysunkowy kreator modułu (beta): elewacja, strefy, systemy szuflad")
            }

            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Button {
                    activeSheetV063 = .layoutPrzeglad
                } label: {
                    Label(
                        "Podgląd układu",
                        systemImage: "rectangle.3.group"
                    )
                }
                .help("Podgląd układu L/U garderoba — rzut z góry dla klienta")
            }

            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                if let url = dxfExportURL {
                    ShareLink(
                        item: url,
                        subject: Text(
                            "\(room.name) — rzut 2D"
                        ),
                        message: Text(
                            "Rzut 2D pomieszczenia z meblami. Format DXF — kompatybilny z AutoCAD, ArchiCAD, Revit."
                        )
                    ) {
                        Label(
                            "Udostępnij DXF",
                            systemImage:
                                "arrow.up.doc"
                        )
                    }
                    .help("Udostępnij plik DXF dla architekta")
                } else {
                    Button {
                        przygotujEksportDXF()
                    } label: {
                        Label(
                            "Eksportuj DXF",
                            systemImage:
                                "arrow.up.doc"
                        )
                    }
                    .disabled(
                        mebleViewModel
                            .assemblies
                            .filter {
                                $0.placement?.wallID != nil
                            }
                            .isEmpty
                    )
                    .help(
                        "Generuj rzut 2D (DXF) z meblami dla architekta"
                    )
                }
            }

            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                KontrolkaPoziomuWymiarowania2D(
                    poziom:
                        poziomWymiarowaniaBinding
                )
                .opacity(
                    aktywnyTrybProjektowyV074
                        == .widok3D
                    ? 0
                    : 1
                )
                .disabled(
                    aktywnyTrybProjektowyV074
                        == .widok3D
                )
                }
            }
    }

    private var availableModuleTemplatesV063:
        [FurnitureTemplate]
    {
        mebleViewModel.templates.filter {
            !StandardKitchenFinishingTemplatesV015
                .isFinishingTemplate($0)
        }
    }

    @ViewBuilder
    private func activeSheetViewV063(
        _ sheet:
            WorkspaceProjektowySheetV063
    ) -> some View {
        switch sheet {
        case .furnitureLibrary(let wallID):
            if let wall =
                room.geometry.wall(id: wallID)
            {
                BibliotekaModulowMeblowychView(
                    templates:
                        availableModuleTemplatesV063,
                    suggestedPlacement: {
                        template in

                        mebleViewModel
                            .suggestedPlacement(
                                for: template,
                                wall: wall,
                                room: room
                            )
                    },
                    onCreate: {
                        template,
                        data in

                        let didCreate =
                            await mebleViewModel.createModule(
                                template: template,
                                data: data,
                                wall: wall,
                                room: room
                            )

                        if didCreate {
                            await MainActor.run {
                                selectedWallID = wall.id
                                if let id =
                                    mebleViewModel
                                        .lastCreatedAssemblyID {
                                    selectedFurnitureID = id
                                    zaznaczoneFurnitureIDsV066 = [id]
                                }
                            }

                            mebleViewModel
                                .zastosujGlobalneMaterialy(
                                    globalneMaterialyRepository
                                        .ustawienia
                                )
                        }

                        return didCreate
                    }
                )
            } else {
                ContentUnavailableView(
                    "Brak ściany",
                    systemImage: "rectangle.slash",
                    description: Text(
                        "Nie można dodać modułu bez aktywnej ściany."
                    )
                )
            }

        case .sciankaPodziałowa(let existing):
            SciankaPodzialowaEditorView(
                room: room,
                repository: sciankaRepo,
                editing: existing
            )

        case .furnitureCreator:
            FurnitureCreatorViewV022 { draft in
                await mebleViewModel
                    .saveCustomTemplateV020(draft: draft)
            }

        case .layoutPrzeglad:
            NavigationStack {
                GarderobaLayoutPrzeglad(
                    room: room,
                    assemblies: mebleViewModel.storedAssemblies
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zamknij") {
                            activeSheetV063 = nil
                        }
                    }
                }
            }

        case .wykonczeniaKuchni:
            WykonczeniaKuchenneEditorV082(
                repo: wykonczeniaRepo,
                bazowaDlugoscCiaguMM: bazowaDlugoscCiaguV082
            )
        }
    }

    /// Suma długości modułów stojących na podłodze (ciąg dolny) — używana
    /// do automatycznego przeliczania długości fartucha i listew.
    private var bazowaDlugoscCiaguV082: Double {
        mebleViewModel.assemblies
            .filter { assembly in
                guard let p = assembly.placement else { return false }
                return p.bottomOffset <= 150
            }
            .reduce(0.0) { $0 + $1.size.width.rawValue }
    }

    @ViewBuilder
    private var centralContent: some View {
        switch aktywnyTrybProjektowyV074 {
        case .plan:
            Plan2DCanvasView(
                room: room,
                assemblies: mebleViewModel.assemblies,
                numberedItems: numberedItems,
                globalneMaterialy: globalneMaterialyRepository.ustawienia,
                poziomWymiarowania: poziomWymiarowania,
                selectedWallID: $selectedWallID,
                selectedFurnitureID: $selectedFurnitureID,
                zaznaczoneFurnitureIDsV066:
                    aktywnieZaznaczoneIDsV066,
                trybWielokrotnegoZaznaczaniaV066:
                    trybWielokrotnegoZaznaczaniaV066,
                onToggleFurnitureSelectionV066: { furnitureID in
                    przelaczZaznaczenieV066(furnitureID)
                },
                onClearFurnitureSelectionV066: {
                    wyczyscZaznaczenieV066(
                        zachowajSciane: true
                    )
                },
                onReplaceFurnitureSelectionV067: { selection in
                    ustawZaznaczenieRamkaV067(selection)
                },
                onEditDimension: { context in
                    if let id = context.cel.furnitureID {
                        selectedFurnitureID = id
                    }
                },
                onMoveFurniture: { movement in
                    wykonajPrzesuniecieV065(movement)
                },
                renderRevision: mebleViewModel.renderRevision
            )

        case .elewacja:
            if let wall = selectedWall ?? room.geometry.walls.first {
                WidokElewacjiSciany(
                    room: room,
                    wall: wall,
                    mebleViewModel: mebleViewModel,
                    globalneMaterialyRepository: globalneMaterialyRepository,
                    selectedFurnitureID: $selectedFurnitureID,
                    onUpdateWall: onUpdateWall,
                    zaznaczoneFurnitureIDsV066:
                        aktywnieZaznaczoneIDsV066,
                    trybWielokrotnegoZaznaczaniaV066:
                        trybWielokrotnegoZaznaczaniaV066,
                    onToggleFurnitureSelectionV066: { furnitureID in
                        przelaczZaznaczenieV066(furnitureID)
                    },
                    onClearFurnitureSelectionV066: {
                        wyczyscZaznaczenieV066(
                            zachowajSciane: true
                        )
                    },
                    onReplaceFurnitureSelectionV067: { selection in
                        ustawZaznaczenieRamkaV067(selection)
                    },
                    onMoveFurnitureV065: { movement in
                        wykonajPrzesuniecieV065(movement)
                    },
                    onDeleteFurnitureV065: { furnitureID in
                        selectedFurnitureID = furnitureID
                        zaznaczoneFurnitureIDsV066 = [furnitureID]
                        poprosOUsuniecieModuluV065(id: furnitureID)
                    }
                )
            } else {
                ContentUnavailableView(
                    "Brak ściany",
                    systemImage: "rectangle.slash",
                    description: Text("Dodaj ścianę, aby otworzyć elewację.")
                )
            }

        case .widok3D:
            Furniture3DSceneViewV017(
                assemblies: mebleViewModel.assemblies,
                state: presentation3D,
                globalneMaterialy: globalneMaterialyRepository.ustawienia,
                room: room,
                materialy: bazaMaterialowRepository.materialy
            )
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "Widok 3D pokoju",
                        systemImage: "cube"
                    )
                    .font(.caption.weight(.semibold))

                    Text(
                        "Przeciągnij, aby obrócić • uszczypnij zoom"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .stroke(
                        StolarniaPalette.frostStroke,
                        lineWidth: 1
                    )
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Furniture3DControlsV017(
                    presentationState: $presentation3D,
                    isEnabled: !mebleViewModel.assemblies.isEmpty
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
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
                        .fill(StolarniaPalette.frostStroke)
                        .frame(height: 1)
                }
            }
        }
    }

    private func wykonajPrzesuniecieV065(
        _ movement: KontekstPrzesunieciaModulu2D
    ) {
        guard !mebleViewModel.isSaving else { return }

        let groupIDs = aktywnieZaznaczoneIDsV066
        if groupIDs.count > 1,
           groupIDs.contains(movement.furnitureID) {
            guard movement.celZamianyID == nil,
                  let stored = mebleViewModel.storedAssembly(
                      id: movement.furnitureID
                  ),
                  let placement = stored.assembly.placement else {
                return
            }

            let dx =
                movement.proponowaneOdsuniecie.rawValue
                - placement.offsetAlongWall.rawValue
            let proposedBottom =
                movement.proponowaneOdsuniecieOdDolu
                ?? placement.bottomOffset
            let dy =
                proposedBottom.rawValue
                - placement.bottomOffset.rawValue

            Task {
                guard let result =
                    await mebleViewModel.przesunGrupeModulowV066(
                        ids: groupIDs,
                        dx: dx,
                        dy: dy,
                        room: room,
                        glowneID: movement.furnitureID
                    ) else {
                    return
                }

                historiaV065.zarejestruj(result.operacja)
                zaznaczoneFurnitureIDsV066 =
                    result.zaznaczoneID
                selectedFurnitureID = result.glowneID
            }
            return
        }

        Task {
            let ids = [movement.furnitureID, movement.celZamianyID]
                .compactMap { $0 }
            let before = mebleViewModel.migawkiPolozenV064(ids: ids)
            let didMove = await mebleViewModel.przesunLubZamienModul(
                movement,
                room: room
            )
            guard didMove else { return }

            let after = mebleViewModel.migawkiPolozenV064(ids: ids)
            historiaV065.zarejestruj(
                OperacjaPolozeniaModulowV064(
                    nazwa: movement.jestZamiana
                        ? "Zamiana modułów"
                        : "Przesunięcie modułu",
                    przed: before,
                    po: after
                )
            )
            selectedFurnitureID = movement.furnitureID
            zaznaczoneFurnitureIDsV066 = [
                movement.furnitureID
            ]
        }
    }

    private func rozpocznijDodawanieModuluV063(
        na wall: WallSegment
    ) {
        selectedWallID = wall.id
        selectedFurnitureID = nil
        zaznaczoneFurnitureIDsV066.removeAll()
        activeSheetV063 =
            .furnitureLibrary(wall.id)
    }

    private func rozpocznijDodawanieModuluZPlanuV077() {
        guard
            let wall =
                selectedWall
                ?? room
                    .geometry
                    .walls
                    .first
        else {
            return
        }

        rozpocznijDodawanieModuluV063(
            na: wall
        )
    }

    private func przesunZaznaczonyV064(
        dx: Double,
        dy: Double
    ) {
        let groupIDs = aktywnieZaznaczoneIDsV066
        if groupIDs.count > 1 {
            Task {
                guard let result =
                    await mebleViewModel.przesunGrupeModulowV066(
                        ids: groupIDs,
                        dx: dx,
                        dy: dy,
                        room: room,
                        glowneID: selectedFurnitureID
                    ) else {
                    return
                }

                historiaV065.zarejestruj(result.operacja)
                zaznaczoneFurnitureIDsV066 =
                    result.zaznaczoneID
                selectedFurnitureID = result.glowneID
            }
            return
        }

        guard let stored = selectedFurniture,
              let placement = stored.assembly.placement,
              let wallID = placement.wallID else {
            return
        }

        let before = mebleViewModel.migawkiPolozenV064(ids: [stored.id])
        let context = KontekstPrzesunieciaModulu2D(
            furnitureID: stored.id,
            wallID: wallID,
            proponowaneOdsuniecie: Millimeters(
                max(0, placement.offsetAlongWall.rawValue + dx)
            ),
            celZamianyID: nil,
            proponowaneOdsuniecieOdDolu: Millimeters(
                max(0, placement.bottomOffset.rawValue + dy)
            )
        )

        Task {
            let didMove = await mebleViewModel.przesunLubZamienModul(
                context,
                room: room
            )
            guard didMove else { return }
            let after = mebleViewModel.migawkiPolozenV064(ids: [stored.id])
            historiaV065.zarejestruj(
                OperacjaPolozeniaModulowV064(
                    nazwa: "Precyzyjne przesunięcie",
                    przed: before,
                    po: after
                )
            )
            zaznaczoneFurnitureIDsV066 = [stored.id]
        }
    }

    private func duplikujAktywneZaznaczenieV067() {
        let ids = aktywnieZaznaczoneIDsV066
        guard !ids.isEmpty else { return }

        if ids.count > 1 {
            Task {
                guard let result =
                    await mebleViewModel.duplikujGrupeModulowV067(
                        ids: ids,
                        glowneID: selectedFurnitureID,
                        room: room
                    ) else {
                    return
                }

                historiaV065.zarejestruj(result.operacja)
                zaznaczoneFurnitureIDsV066 = result.noweID
                selectedFurnitureID = result.glowneID
                trybWielokrotnegoZaznaczaniaV066 = true

                if let wallID =
                    mebleViewModel
                    .storedAssembly(id: result.glowneID)?
                    .assembly
                    .placement?
                    .wallID {
                    selectedWallID = wallID
                }
            }
            return
        }

        guard let selectedID =
            selectedFurnitureID ?? ids.first else {
            return
        }

        Task {
            guard let result = await mebleViewModel.duplikujModulV065(
                id: selectedID,
                room: room
            ) else {
                return
            }

            historiaV065.zarejestruj(result.operacja)
            selectedFurnitureID = result.nowyID
            zaznaczoneFurnitureIDsV066 = [result.nowyID]
            selectedWallID =
                mebleViewModel
                    .storedAssembly(id: result.nowyID)?
                    .assembly
                    .placement?
                    .wallID
        }
    }

    private func poprosOUsuniecieZaznaczonegoV065() {
        let ids = aktywnieZaznaczoneIDsV066
        guard !ids.isEmpty else { return }
        idsDoUsunieciaV066 = ids
        pokazPotwierdzenieUsunieciaV065 = true
    }

    private func przygotujEksportDXF() {
        let zestawy = mebleViewModel.assemblies
        dxfExportURL = EksportDXF.generujURL(
            room: room,
            zestawy: zestawy
        )
    }

    private func poprosOUsuniecieModuluV065(
        id: FurnitureAssemblyID
    ) {
        idsDoUsunieciaV066 = [id]
        pokazPotwierdzenieUsunieciaV065 = true
    }

    private func usunWskazaneModulyV066() {
        let ids = idsDoUsunieciaV066
        idsDoUsunieciaV066.removeAll()
        guard !ids.isEmpty else { return }

        Task {
            let operation: OperacjaStanuModulowV065?
            if ids.count == 1, let id = ids.first {
                operation = await mebleViewModel.usunModulV065(
                    id: id
                )
            } else {
                operation = await mebleViewModel.usunModulyV066(
                    ids: ids,
                    glowneID: selectedFurnitureID
                )
            }

            guard let operation else {
                return
            }

            historiaV065.zarejestruj(operation)
            selectedFurnitureID = nil
            zaznaczoneFurnitureIDsV066.removeAll()
        }
    }

    private var tytulPotwierdzeniaUsunieciaV066: String {
        idsDoUsunieciaV066.count > 1
            ? "Usunąć zaznaczone moduły?"
            : "Usunąć zaznaczony moduł?"
    }

    private var etykietaPrzyciskuUsunieciaV066: String {
        idsDoUsunieciaV066.count > 1
            ? "Usuń \(idsDoUsunieciaV066.count) moduły"
            : "Usuń moduł"
    }

    private var opisPotwierdzeniaUsunieciaV066: String {
        if idsDoUsunieciaV066.count > 1 {
            return "Z projektu zostanie usuniętych \(idsDoUsunieciaV066.count) modułów wraz z ich kartami technicznymi. Całą operację można cofnąć."
        }

        guard let id = idsDoUsunieciaV066.first,
              let stored = mebleViewModel.storedAssembly(
                  id: id
              ) else {
            return "Tej operacji można później użyć z funkcją Cofnij."
        }

        return "„\(stored.assembly.name)” zostanie usunięty z projektu. Operację można cofnąć."
    }

    private func wykonajOperacjeGrupowaV066(
        _ operation: RodzajOperacjiGrupowejV066
    ) {
        let ids = aktywnieZaznaczoneIDsV066
        guard ids.count >= operation.minimalnaLiczbaModulow else {
            return
        }

        // Operacje przebudowujące moduły (np. równa szerokość) idą osobną ścieżką
        // z cofaniem na poziomie stanu V065, a nie samych pozycji V064.
        if operation.przebudowujeModuly {
            Task {
                guard let operacja =
                    await mebleViewModel.rozlozRownaSzerokoscV081(
                        ids: ids,
                        glowneID: selectedFurnitureID,
                        room: room
                    ) else {
                    return
                }

                historiaV065.zarejestruj(operacja)
                zaznaczoneFurnitureIDsV066 = ids
            }
            return
        }

        Task {
            guard let result =
                await mebleViewModel.wykonajOperacjeGrupowaV066(
                    operation,
                    ids: ids,
                    glowneID: selectedFurnitureID,
                    room: room
                ) else {
                return
            }

            historiaV065.zarejestruj(result.operacja)
            zaznaczoneFurnitureIDsV066 =
                result.zaznaczoneID
            selectedFurnitureID = result.glowneID
        }
    }

    private func ustawZaznaczenieRamkaV067(
        _ selection: ZaznaczenieRamkaV067
    ) {
        let existingIDs = Set(
            mebleViewModel.storedAssemblies.map(\.id)
        )
        let validIDs = selection.ids.intersection(existingIDs)

        trybWielokrotnegoZaznaczaniaV066 = true
        zaznaczoneFurnitureIDsV066 = validIDs

        if let preferred = selection.preferowaneGlowneID,
           validIDs.contains(preferred) {
            selectedFurnitureID = preferred
        } else {
            selectedFurnitureID =
                mebleViewModel.storedAssemblies
                    .first(where: {
                        validIDs.contains($0.id)
                    })?
                    .id
        }

        if let wallID =
            mebleViewModel
                .storedAssembly(id: selectedFurnitureID)?
                .assembly
                .placement?
                .wallID {
            selectedWallID = wallID
        }
    }

    private func ustawTrybWielokrotnegoZaznaczaniaV066(
        _ enabled: Bool
    ) {
        trybWielokrotnegoZaznaczaniaV066 = enabled

        if enabled {
            if let selectedFurnitureID {
                zaznaczoneFurnitureIDsV066.insert(
                    selectedFurnitureID
                )
            }
        } else {
            zaznaczoneFurnitureIDsV066 =
                Set(selectedFurnitureID.map { [$0] } ?? [])
        }
    }

    private func przelaczZaznaczenieV066(
        _ furnitureID: FurnitureAssemblyID
    ) {
        guard trybWielokrotnegoZaznaczaniaV066 else {
            selectedFurnitureID = furnitureID
            zaznaczoneFurnitureIDsV066 = [furnitureID]
            return
        }

        if zaznaczoneFurnitureIDsV066.contains(furnitureID) {
            zaznaczoneFurnitureIDsV066.remove(furnitureID)

            if selectedFurnitureID == furnitureID {
                selectedFurnitureID =
                    mebleViewModel.storedAssemblies
                    .first(where: {
                        zaznaczoneFurnitureIDsV066.contains(
                            $0.id
                        )
                    })?
                    .id
            }
        } else {
            zaznaczoneFurnitureIDsV066.insert(furnitureID)
            selectedFurnitureID = furnitureID
        }

        if let wallID =
            mebleViewModel
                .storedAssembly(id: selectedFurnitureID)?
                .assembly
                .placement?
                .wallID {
            selectedWallID = wallID
        }
    }

    private func wyczyscZaznaczenieV066(
        zachowajSciane: Bool = false
    ) {
        selectedFurnitureID = nil
        zaznaczoneFurnitureIDsV066.removeAll()
        if !zachowajSciane {
            selectedWallID = nil
        }
    }

    private func zaznaczWszystkieNaAktywnejScianieV066() {
        let items = mebleNaAktywnejScianieV066
        guard !items.isEmpty else { return }

        trybWielokrotnegoZaznaczaniaV066 = true
        zaznaczoneFurnitureIDsV066 =
            Set(items.map(\.id))

        if let selectedFurnitureID,
           zaznaczoneFurnitureIDsV066.contains(
               selectedFurnitureID
           ) {
            return
        }

        selectedFurnitureID = items.first?.id
    }

    private func zsynchronizujGlowneZaznaczenieV066(
        _ newValue: FurnitureAssemblyID?
    ) {
        guard let newValue else {
            if !trybWielokrotnegoZaznaczaniaV066 {
                zaznaczoneFurnitureIDsV066.removeAll()
            }
            return
        }

        if trybWielokrotnegoZaznaczaniaV066 {
            zaznaczoneFurnitureIDsV066.insert(newValue)
        } else {
            zaznaczoneFurnitureIDsV066 = [newValue]
        }
    }

    private func usunNieistniejaceZaznaczeniaV066() {
        let existing = Set(
            mebleViewModel.storedAssemblies.map(\.id)
        )
        zaznaczoneFurnitureIDsV066 =
            zaznaczoneFurnitureIDsV066
            .intersection(existing)

        if let selectedFurnitureID,
           !existing.contains(selectedFurnitureID) {
            self.selectedFurnitureID =
                zaznaczoneFurnitureIDsV066.first
        }
    }

    private func zastosujZaznaczeniePoHistoriiV066(
        _ result: WynikHistoriiModulowV065
    ) {
        zaznaczoneFurnitureIDsV066 =
            result.zaznaczeniaV066
        selectedFurnitureID = result.zaznaczenie
        trybWielokrotnegoZaznaczaniaV066 =
            result.zaznaczeniaV066.count > 1

        if let wallID =
            mebleViewModel
                .storedAssembly(id: result.zaznaczenie)?
                .assembly
                .placement?
                .wallID {
            selectedWallID = wallID
        }
    }

    private var selectedFurniture: StoredFurnitureAssembly? {
        mebleViewModel.storedAssembly(id: selectedFurnitureID)
    }

    private var aktywnieZaznaczoneIDsV066:
        Set<FurnitureAssemblyID> {
        if !zaznaczoneFurnitureIDsV066.isEmpty {
            return zaznaczoneFurnitureIDsV066
        }
        return Set(selectedFurnitureID.map { [$0] } ?? [])
    }

    private var selectedAssembliesV066:
        [StoredFurnitureAssembly] {
        mebleViewModel.storedAssemblies.filter {
            aktywnieZaznaczoneIDsV066.contains($0.id)
        }
    }

    private var selectionSummaryV066:
        PodsumowanieZaznaczeniaV066 {
        PodsumowanieZaznaczeniaV066.utworz(
            ids: aktywnieZaznaczoneIDsV066,
            storedAssemblies:
                mebleViewModel.storedAssemblies
        )
    }

    private var mebleNaAktywnejScianieV066:
        [StoredFurnitureAssembly] {
        let wallID =
            selectedWallID
            ?? selectedFurniture?
                .assembly
                .placement?
                .wallID
            ?? room.geometry.walls.first?.id

        guard let wallID else { return [] }

        return mebleViewModel.storedAssemblies
            .filter {
                $0.assembly.placement?.wallID == wallID
            }
            .sorted {
                ($0.assembly.placement?.offsetAlongWall ?? .zero)
                    <
                ($1.assembly.placement?.offsetAlongWall ?? .zero)
            }
    }

    private var selectedWall: WallSegment? {
        if let selectedWallID {
            return room.geometry.wall(id: selectedWallID)
        }
        if let wallID = selectedFurniture?.assembly.placement?.wallID {
            return room.geometry.wall(id: wallID)
        }
        return nil
    }

    private var numberedItems: [FurnitureCanvasItemV016] {
        cachedNumberedItemsV074
    }

    // MARK: - Workspace cache refresh (Task #91)

    /// Przelicza formatki, raport gotowości i numerowanie.
    /// Wywoływana tylko przy faktycznych zmianach modelu (onAppear + onChange renderRevision).
    private func refreshWorkspaceCachesV091() {
        let lista = ListaFormatekProjektuBuilderV070.build(
            projectName: room.name,
            assemblies: mebleViewModel.storedAssemblies,
            globalneMaterialy: globalneMaterialyRepository.ustawienia
        )
        cachedListaFormatekV074 = lista

        let rozkroj = RozkrojPlytEngineV071.build(
            list: lista,
            settings: .standard
        )
        cachedReportGotowosciV074 = ProjectReadinessEngineV078.build(
            room: room,
            assemblies: mebleViewModel.storedAssemblies,
            materialy: globalneMaterialyRepository.ustawienia,
            lista: lista,
            raport: rozkroj
        )

        cachedNumberedItemsV074 = FurnitureCanvasNumberingV016.make(
            room: room,
            storedAssemblies: mebleViewModel.storedAssemblies
        )
    }

    private var poziomWymiarowania: PoziomWymiarowania2D {
        PoziomWymiarowania2D(rawValue: poziomWymiarowaniaRaw)
            ?? .podstawowe
    }

    private var poziomWymiarowaniaBinding:
        Binding<PoziomWymiarowania2D> {
        Binding(
            get: { poziomWymiarowania },
            set: { poziomWymiarowaniaRaw = $0.rawValue }
        )
    }
}

struct InspektorWorkspaceV063: View {
    let room: RoomDefinition
    let storedAssembly: StoredFurnitureAssembly?
    let selectedAssembliesV066: [StoredFurnitureAssembly]
    let selectionSummaryV066: PodsumowanieZaznaczeniaV066
    let trybWielokrotnegoZaznaczaniaV066: Bool
    let selectedWall: WallSegment?
    let onClearSelection: () -> Void
    let onToggleMultiSelectionV066: () -> Void
    let onSelectAllOnWallV066: () -> Void
    let onGroupOperationV066: (RodzajOperacjiGrupowejV066) -> Void
    let onNudge: (_ dx: Double, _ dy: Double) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onAddModuleToWall: (WallSegment) -> Void
    let onEditSlope: (WallSegment) -> Void
    var onOpenCreator: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Inspektor", systemImage: "sidebar.right")
                        .font(.headline)
                    Spacer()
                    Button {
                        onToggleMultiSelectionV066()
                    } label: {
                        Image(
                            systemName:
                                trybWielokrotnegoZaznaczaniaV066
                                ? "checkmark.circle.fill"
                                : "checkmark.circle"
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        trybWielokrotnegoZaznaczaniaV066
                            ? Color.accentColor
                            : Color.secondary
                    )
                    .accessibilityLabel(
                        trybWielokrotnegoZaznaczaniaV066
                            ? "Zakończ wybór wielu modułów"
                            : "Wybierz wiele modułów"
                    )

                    if !selectedAssembliesV066.isEmpty
                        || selectedWall != nil {
                        Button {
                            onClearSelection()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                if selectedAssembliesV066.count > 1 {
                    groupSectionV066(selectedAssembliesV066)
                } else if let storedAssembly {
                    moduleSection(storedAssembly)
                } else if let selectedWall {
                    wallSection(selectedWall)
                } else {
                    ContentUnavailableView(
                        "Brak zaznaczenia",
                        systemImage: "cursorarrow.click",
                        description: Text(
                            "Wybierz moduł albo ścianę na planie lub elewacji."
                        )
                    )
                }
            }
            .padding(18)
        }
    }

    private func groupSectionV066(
        _ stored: [StoredFurnitureAssembly]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(stored.count) zaznaczone moduły")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("grupa")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.secondary.opacity(0.1),
                        in: Capsule()
                    )
            }

            inspectorGroup(
                "Zaznaczenie",
                systemImage: "checkmark.circle"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        selectionSummaryV066.maWspolnaSciane
                            ? "Wspólna ściana"
                            : "Moduły z różnych ścian",
                        systemImage:
                            selectionSummaryV066.maWspolnaSciane
                            ? "rectangle.portrait"
                            : "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        selectionSummaryV066.maWspolnaSciane
                            ? Color.secondary
                            : Color.orange
                    )

                    Button {
                        onSelectAllOnWallV066()
                    } label: {
                        Label(
                            "Wszystkie na ścianie",
                            systemImage: "checkmark.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            inspectorGroup(
                "Wyrównanie i rozstaw",
                systemImage: "align.horizontal.left"
            ) {
                VStack(spacing: 8) {
                    HStack {
                        groupOperationButtonV066(.wyrownajDol)
                        groupOperationButtonV066(.wyrownajGore)
                    }
                    HStack {
                        groupOperationButtonV066(.domknijOdstepy)
                        groupOperationButtonV066(.rozlozRownomiernie)
                    }
                    HStack {
                        groupOperationButtonV066(.rozlozRownaSzerokosc)
                    }
                }

                if !selectionSummaryV066.maWspolnaSciane {
                    Text(
                        "Wyrównanie wymaga modułów na jednej ścianie."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if !selectionSummaryV066.maWspolnyPas {
                    Text(
                        "Domykanie i równy rozstaw wymagają jednego pasa zabudowy."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            inspectorGroup(
                "Przesunięcie grupy",
                systemImage: "move.3d"
            ) {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        nudgeButton(
                            "↑ 1",
                            dx: 0,
                            dy: 1,
                            key: .upArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "↑ 10",
                            dx: 0,
                            dy: 10,
                            key: .upArrow,
                            modifiers: [.shift]
                        )
                        Spacer()
                    }
                    HStack {
                        nudgeButton(
                            "← 10",
                            dx: -10,
                            dy: 0,
                            key: .leftArrow,
                            modifiers: [.shift]
                        )
                        nudgeButton(
                            "← 1",
                            dx: -1,
                            dy: 0,
                            key: .leftArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "→ 1",
                            dx: 1,
                            dy: 0,
                            key: .rightArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "→ 10",
                            dx: 10,
                            dy: 0,
                            key: .rightArrow,
                            modifiers: [.shift]
                        )
                    }
                    HStack {
                        Spacer()
                        nudgeButton(
                            "↓ 1",
                            dx: 0,
                            dy: -1,
                            key: .downArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "↓ 10",
                            dx: 0,
                            dy: -10,
                            key: .downArrow,
                            modifiers: [.shift]
                        )
                        Spacer()
                    }
                }
                .disabled(!selectionSummaryV066.maWspolnaSciane)
            }

            inspectorGroup(
                "Operacje",
                systemImage: "square.on.square"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        onDuplicate()
                    } label: {
                        Label(
                            "Duplikuj \(stored.count) moduły",
                            systemImage: "plus.square.on.square"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        !selectionSummaryV066.maWspolnaSciane
                    )

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(
                            "Usuń \(stored.count) moduły",
                            systemImage: "trash"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                if !selectionSummaryV066.maWspolnaSciane {
                    Text(
                        "Duplikowanie grupy wymaga modułów na jednej ścianie."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            inspectorGroup(
                "Kontekst",
                systemImage: "hand.tap"
            ) {
                Text(
                    "Dotykaj modułów albo przeciągnij ramkę po pustym obszarze. Ponowne dotknięcie usuwa moduł z zaznaczenia."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func groupOperationButtonV066(
        _ operation: RodzajOperacjiGrupowejV066
    ) -> some View {
        Button {
            onGroupOperationV066(operation)
        } label: {
            Label(
                operation.tytul,
                systemImage: operation.symbol
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(
            !selectionSummaryV066.moznaWykonac(operation)
        )
    }

    private func moduleSection(
        _ stored: StoredFurnitureAssembly
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(stored.assembly.name)
                .font(.title3.weight(.semibold))

            inspectorGroup("Wymiary", systemImage: "ruler") {
                valueRow("Szerokość", stored.assembly.size.width)
                valueRow("Wysokość", stored.assembly.size.height)
                valueRow("Głębokość", stored.assembly.size.depth)
            }

            if let placement = stored.assembly.placement {
                inspectorGroup("Położenie", systemImage: "move.3d") {
                    valueRow("Wzdłuż ściany", placement.offsetAlongWall)
                    valueRow("Od ściany", placement.offsetFromWall)
                    valueRow("Od podłogi", placement.bottomOffset)
                }
            }

            inspectorGroup("Precyzyjne przesunięcie", systemImage: "move.3d") {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        nudgeButton(
                            "↑ 1",
                            dx: 0,
                            dy: 1,
                            key: .upArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "↑ 10",
                            dx: 0,
                            dy: 10,
                            key: .upArrow,
                            modifiers: [.shift]
                        )
                        Spacer()
                    }
                    HStack {
                        nudgeButton(
                            "← 10",
                            dx: -10,
                            dy: 0,
                            key: .leftArrow,
                            modifiers: [.shift]
                        )
                        nudgeButton(
                            "← 1",
                            dx: -1,
                            dy: 0,
                            key: .leftArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "→ 1",
                            dx: 1,
                            dy: 0,
                            key: .rightArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "→ 10",
                            dx: 10,
                            dy: 0,
                            key: .rightArrow,
                            modifiers: [.shift]
                        )
                    }
                    HStack {
                        Spacer()
                        nudgeButton(
                            "↓ 1",
                            dx: 0,
                            dy: -1,
                            key: .downArrow,
                            modifiers: []
                        )
                        nudgeButton(
                            "↓ 10",
                            dx: 0,
                            dy: -10,
                            key: .downArrow,
                            modifiers: [.shift]
                        )
                        Spacer()
                    }
                }
            }

            inspectorGroup("Operacje", systemImage: "square.on.square") {
                HStack {
                    Button {
                        onDuplicate()
                    } label: {
                        Label("Duplikuj", systemImage: "plus.square.on.square")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Usuń", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            inspectorGroup("Kontekst", systemImage: "square.grid.3x3") {
                Text("Zmiana zaznaczenia jest zachowywana między planem, elewacją i widokiem 3D.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func nudgeButton(
        _ title: String,
        dx: Double,
        dy: Double,
        key: KeyEquivalent,
        modifiers: EventModifiers
    ) -> some View {
        Button(title) {
            onNudge(dx, dy)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .keyboardShortcut(key, modifiers: modifiers)
    }

    private func wallSection(_ wall: WallSegment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(wall.name)
                .font(.title3.weight(.semibold))

            inspectorGroup("Ściana", systemImage: "rectangle.portrait") {
                valueRow("Wysokość początku", wall.startHeight)
                valueRow("Wysokość końca", wall.endHeight)
                if let geometry = room.geometry.geometry(of: wall.id) {
                    valueRow("Długość", geometry.length)
                }
            }

            slopeGroup(for: wall)

            inspectorGroup("Moduły", systemImage: "square.grid.2x2") {
                Button {
                    onAddModuleToWall(wall)
                } label: {
                    Label(
                        "Dodaj moduł",
                        systemImage: "plus.square.on.square"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    StolarniaPrimaryButtonStyle(
                        minHeight: 42,
                        horizontalPadding: 12,
                        cornerRadius: 12
                    )
                )

                if let onOpenCreator {
                    Button {
                        onOpenCreator()
                    } label: {
                        Label(
                            "Kreator mebla",
                            systemImage: "square.grid.3x3.square"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    private func slopeGroup(for wall: WallSegment) -> some View {
        let profile = MebelElewacjaScianyGeometry.slopeProfile(
            on: wall, room: room
        )
        let angle = profile.flatMap {
            MebelElewacjaScianyGeometry.katSkosuStopnie(profil: $0)
        }

        return inspectorGroup(
            "Skos",
            systemImage: "triangle.righthalf.filled"
        ) {
            if let angle {
                HStack {
                    Text("Kąt skosu")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        angle.formatted(
                            .number.precision(.fractionLength(1))
                        ) + "°"
                    )
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.purple)
                    .fontWeight(.semibold)
                }
            } else {
                Text("Brak skosu dla tej ściany.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onEditSlope(wall)
            } label: {
                Label(
                    angle != nil ? "Edytuj skos" : "Przypisz skos",
                    systemImage: angle != nil
                        ? "pencil"
                        : "plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                StolarniaPrimaryButtonStyle(
                    minHeight: 42,
                    horizontalPadding: 12,
                    cornerRadius: 12
                )
            )
        }
    }

    private func inspectorGroup<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private func valueRow(
        _ title: String,
        _ value: Millimeters
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MebelWymiarFormatterV0143.millimeters(value))
                .font(.body.monospacedDigit())
        }
    }
}
