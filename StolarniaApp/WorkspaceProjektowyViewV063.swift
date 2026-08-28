import DomainCore
import Persistence
import SwiftUI

enum TrybWorkspaceProjektowegoV063: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case elewacja = "Elewacja"
    case elewacjaWyspy = "Elewacja wyspy"
    case widok3D = "3D"
    case garderobyDrzwi = "Garderoby"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .plan: return "square.grid.2x2"
        case .elewacja: return "rectangle.portrait"
        case .elewacjaWyspy: return "rectangle.center.inset.filled"
        case .widok3D: return "cube"
        case .garderobyDrzwi: return "rectangle.split.3x1"
        }
    }
}

private enum WorkspacePresentationStyleV084 {
    case sheet
    case fullScreen
}

private enum WorkspacePresentationV084: Identifiable {
    case furnitureLibrary(
        wallID: WallID,
        initialGroup: FurnitureLibraryGroupV016?,
        initialCategory: FurnitureLibraryCategoryV016?
    )
    case sciankaPodziałowa(SciankaPodzialowaDefinicjaV075?)
    case furnitureCreator
    case layoutPrzeglad
    case wykonczeniaKuchni
    case dwgImport
    // `elevationCreator` usunięty 2026-08-27 — patrz komentarz przy
    // `style`, ostatnia rzecz, która została po tej ścieżce.

    var id: String {
        switch self {
        case .furnitureLibrary(
            let wallID,
            let initialGroup,
            let initialCategory
        ):
            return [
                "furniture-library",
                wallID.description,
                initialGroup?.rawValue ?? "default",
                initialCategory?.rawValue ?? "all"
            ]
            .joined(separator: ".")
        case .sciankaPodziałowa(let s):
            return "scianka-\(s?.id.uuidString ?? "nowa")"
        case .furnitureCreator:
            return "furniture-creator"
        case .layoutPrzeglad:
            return "layout-przeglad"
        case .wykonczeniaKuchni:
            return "wykończenia-kuchni"
        case .dwgImport:
            return "dwg-import"
        }
    }

    /// **Usunięte 2026-08-27: `elevationCreator`.**
    ///
    /// Menu „Więcej" miało pozycję `Kreator rysunkowy`, która otwierała
    /// `ModulEdytorElewacjiView()` **bez argumentów**, czyli na pełny ekran
    /// i bez `onZapisz`. Edytor wchodził wtedy w tryb podglądu presetu:
    /// dawało się rysować moduł, którego **nie da się zapisać** i który nie
    /// należy do żadnej ściany. Wejście pochodziło sprzed `KartaModuluV097`,
    /// gdzie ten sam edytor stoi w sekcji „Rysunek", związany z konkretnym
    /// modułem i z zapisem.
    ///
    /// Deska kreślarska gubiąca pracę jest gorsza niż jej brak, dlatego
    /// pozycja znika, a nie zostaje wyszarzona.
    ///
    /// Po tej zmianie wszystkie prezentacje są arkuszami, więc `style`
    /// przestał być potrzebny — pełny ekran miał tylko ten jeden przypadek.
    var style: WorkspacePresentationStyleV084 { .sheet }
}

private enum WorkspaceNextStepActionV084 {
    case addModule
    case showInspector
    case showElevation
    case show3D
    case showProductionReadiness
    case returnToMeasurement
}

private struct WorkspaceNextStepV084 {
    let title: String
    let description: String
    let status: StolarniaReadinessStatus
    let actionTitle: String
    let actionSystemImage: String
    let action: WorkspaceNextStepActionV084
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
    /// Potrzebne do policzenia ceny pokazywanej w pasku bocznym —
    /// `SilnikWycenyWariantowej` liczy okucia razem z płytą.
    @StateObject private var bazaOkucRepositoryV0103 = BazaOkucRepository()
    @State private var presentation3D = Furniture3DPresentationStateV017()
    @State private var activePresentationV084:
        WorkspacePresentationV084?
    @State private var pokazPotwierdzenieUsunieciaV065 = false
    @StateObject private var wykonczeniaRepo = WykonczeniaKuchenneRepositoryV082()
    @State private var dxfExportURL: URL?
    @State private var idsDoUsunieciaV066: Set<FurnitureAssemblyID> = []
    @State private var zaznaczoneFurnitureIDsV066:
        Set<FurnitureAssemblyID> = []
    @State private var trybWielokrotnegoZaznaczaniaV066 = false
    @State private var manualSlidingPartitionCandidateV092:
        SlidingRoomPartitionCandidateV092?

    // MARK: - Performance caches (Task #91)
    // listaFormatekV074 i reportGotowosciV078 były drogie computed vars
    // przeliczane przy KAŻDYM render (tab switch, tap modułu, itp.).
    // Teraz aktualizowane wyłącznie gdy zmieni się mebleViewModel.renderRevision.
    @State private var cachedListaFormatekV074: ListaFormatekProjektuV070 =
        .init(nazwaProjektu: "", dataUtworzenia: .distantPast, formatki: [])
    @State private var cachedReportGotowosciV074: ProjectReadinessReportV078 =
        .init(issues: [])
    @State private var cachedNumberedItemsV074: [FurnitureCanvasItemV016] = []
    /// Wycena pomieszczenia trzymana w tym samym cache co reszta.
    ///
    /// Liczona **raz na zmianę modułów**, nie w `body`.
    /// `ProjektWycenyBuilder.zbuduj` przechodzi po wszystkich zespołach
    /// i ich komponentach; w ciele widoku oznaczałoby to pełne przeliczenie
    /// przy każdym dotknięciu modułu, a cena wisi w pasku bocznym, czyli
    /// jest na ekranie cały czas.
    @State private var cachedWycenaV0103: ProjektWyceny?
    /// Podsumowanie wariantu standardowego — źródło ceny w pasku bocznym.
    @State private var cachedPodsumowanieWycenyV0103: PodsumowanieWariantuWyceny?
    /// Raport rozkroju liczony i tak w `refreshWorkspaceCachesV091` na potrzeby
    /// gotowości — zapamiętany, żeby zamówienie nie liczyło go drugi raz.
    @State private var cachedRozkrojV0103: RaportRozkrojuPlytV071?

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
                        .warningCount,
                cenaBruttoPomieszczenia:
                    cachedPodsumowanieWycenyV0103?
                        .cenaBrutto,
                brakiCennika:
                    cachedPodsumowanieWycenyV0103?
                        .pozycje
                        .filter(\.jestBledemWyceny)
                        .count
                    ?? 0
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
                        item:
                            activeFullScreenPresentationBindingV084
                    ) {
                        presentation in

                        activePresentationViewV084(
                            presentation
                        )
                    }
                    .sheet(
                        item:
                            activeSheetPresentationBindingV084
                    ) {
                        presentation in

                        activePresentationViewV084(
                            presentation
                        )
                    }
                    .onChange(of: selectedFurnitureID) { _, newValue in
                        zsynchronizujGlowneZaznaczenieV066(newValue)
                        manualSlidingPartitionCandidateV092 = nil
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

    private var activeSheetPresentationBindingV084:
        Binding<WorkspacePresentationV084?>
    {
        Binding(
            get: {
                activePresentationV084?.style == .sheet
                    ? activePresentationV084
                    : nil
            },
            set: { newValue in
                if let newValue {
                    activePresentationV084 = newValue
                } else if activePresentationV084?.style == .sheet {
                    activePresentationV084 = nil
                }
            }
        )
    }

    private var activeFullScreenPresentationBindingV084:
        Binding<WorkspacePresentationV084?>
    {
        Binding(
            get: {
                activePresentationV084?.style == .fullScreen
                    ? activePresentationV084
                    : nil
            },
            set: { newValue in
                if let newValue {
                    activePresentationV084 = newValue
                } else if activePresentationV084?.style == .fullScreen {
                    activePresentationV084 = nil
                }
            }
        )
    }

    @ViewBuilder
    private var workspaceDetailV074:
        some View
    {
        if destinationV074 == .wycena {
            wycenaContentV0103
        } else if destinationV074 == .zakupPlyt {
            zamowienieContentV0103
        } else if destinationV074
            .jestProjektem {
            projektContentV074
        } else {
            produkcjaContentV074
        }
    }

    /// Wycena pomieszczenia **w warsztacie**, nie w osobnym oknie.
    ///
    /// Dotąd, żeby wycenić to, co się właśnie narysowało, trzeba było zamknąć
    /// cały warsztat (`fullScreenCover`) i otworzyć wycenę jako `sheet` na
    /// ekranie projektu — czyli na warstwie *pod* warsztatem. Droga
    /// „projektuję → wyceniam → rozkrój" oznaczała trzykrotną utratę
    /// kontekstu, mimo że to jedna linia pracy.
    ///
    /// **To jest wycena tego pomieszczenia, nie całego projektu.** Oferta
    /// projektowa obejmująca wszystkie pomieszczenia zostaje tam, gdzie była
    /// — jest dokumentem dla klienta. Tutaj odpowiadamy na inne pytanie:
    /// „ile kosztuje to, co mam przed sobą".
    ///
    /// Liczona przy każdym wejściu z aktualnych modułów, bo w trakcie
    /// projektowania nieaktualna cena jest gorsza niż jej brak.
    /// Widoki etapu „Projekt" — plan, elewacja, 3D.
    ///
    /// Były osobnymi pozycjami paska bocznego, co sugerowało trzy różne
    /// miejsca w aplikacji. To są trzy spojrzenia na ten sam mebel, więc
    /// przełącznik stoi nad rysunkiem, przy treści, której dotyczy.
    ///
    /// Elewacja wyspy i garderoby są tu wyszarzone, gdy w pomieszczeniu nie
    /// ma czego pokazać — zostają widoczne, żeby było wiadomo, że istnieją.
    private func przelacznikWidokuProjektuV0103(
        wlasneTlo: Bool = true
    ) -> some View {
        PrzelacznikWidokuV0103(
            widoki: WorkspaceDestinationV074
                .cele(etapu: .projekt)
                .map { cel in
                    PrzelacznikWidokuV0103.Widok(
                        id: cel.rawValue,
                        tytul: cel.tytulSkrocony,
                        ikona: cel.symbol,
                        wylaczony: !celDostepnyV0103(cel)
                    )
                },
            wybrany: Binding(
                get: { destinationV074.rawValue },
                set: { nowy in
                    if let cel = WorkspaceDestinationV074(rawValue: nowy) {
                        destinationV074 = cel
                    }
                }
            ),
            wlasneTlo: wlasneTlo
        )
    }

    /// Czy w tym pomieszczeniu ten widok ma co pokazać.
    private func celDostepnyV0103(
        _ cel: WorkspaceDestinationV074
    ) -> Bool {
        switch cel {
        case .elewacjaWyspy:
            return mebleViewModel.storedAssemblies.contains {
                $0.assembly.placement?.wallID == nil
            }
        case .garderobyDrzwi:
            return !mebleViewModel.storedAssemblies.isEmpty
        default:
            return true
        }
    }

    /// Etap „Zamówienie" — płyty i okucia jako jedna lista.
    ///
    /// Zakładka `Zakup płyt` pokazuje, zgodnie z nazwą, **same arkusze**.
    /// Okucia szły osobną drogą przez wycenę i listę zakupową, więc komplet
    /// do hurtowni trzeba było zszywać z dwóch miejsc.
    ///
    /// Stara zakładka **nie znika** — nadal jest w pasku zakładek produkcji,
    /// razem z rozkrojem, obrzeżami i CNC. Tu jest widok zamówienia.
    private var zamowienieContentV0103: some View {
        ZamowienieDoHurtowniV0103(
            nazwaPomieszczenia: room.name,
            zapotrzebowaniePlyt:
                cachedRozkrojV0103?.zapotrzebowanie ?? [],
            podsumowanieWyceny: cachedPodsumowanieWycenyV0103
        )
        .id(mebleViewModel.renderRevision)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wycenaContentV0103: some View {
        WycenaWariantowaView(
            projekt: cachedWycenaV0103,
            osadzona: true
        )
        .id(mebleViewModel.renderRevision)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func przeliczWycenePomieszczeniaV0103() -> ProjektWyceny? {
        let assemblies = mebleViewModel.storedAssemblies.map(\.assembly)
        guard !assemblies.isEmpty else { return nil }

        return ProjektWycenyBuilder.zbuduj(
            nazwaProjektu: room.name,
            assemblies: assemblies,
            materialyPomieszczen: [
                room.id.description:
                    globalneMaterialyRepository.ustawienia
            ]
        )
    }

    private var projektContentV074:
        some View
    {
        centralContent
            .safeAreaInset(edge: .top, spacing: 0) {
                paskiNadRysunkiemV0108
            }
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
                        activePresentationV084 = .furnitureCreator
                    }
                )
                .inspectorColumnWidth(
                    min: 280,
                    ideal: 320,
                    max: 390
                )
            }
    }

    /// Jeden pasek nad rysunkiem zamiast dwóch.
    ///
    /// Przełącznik widoków i pasek następnego kroku stały jeden pod drugim
    /// i zabierały razem ok. 110 pt. Przy elewacji dochodzi jeszcze pasek
    /// akcji, więc **rysunek — czyli to, po co się tu przyszło — dostawał
    /// niecałe cztery piąte ekranu**.
    ///
    /// Obie rzeczy są krótkie: przełącznik to rząd kafli, pasek to zdanie
    /// z przyciskiem. Na iPadzie w poziomie mieszczą się obok siebie.
    /// `ViewThatFits` wraca do dwóch wierszy, gdy nie ma miejsca — nic nie
    /// znika i nic się nie ściska poniżej celu dotyku.
    private var paskiNadRysunkiemV0108: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                // `fixedSize` jest tu konieczne: przełącznik ma w środku
                // poziomy `ScrollView`, który bez tego zgłasza dowolnie małą
                // szerokość — `ViewThatFits` uznałby, że wiersz zawsze się
                // mieści, i ścisnąłby pasek następnego kroku.
                przelacznikWidokuProjektuV0103(wlasneTlo: false)
                    .fixedSize(horizontal: true, vertical: false)

                Divider()
                    .frame(height: 30)

                workspaceNextStepStripV084
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                przelacznikWidokuProjektuV0103(wlasneTlo: false)

                Divider()

                workspaceNextStepStripV084
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            }
        }
        // `stolarniaMaterial`, nie surowy `Rectangle().fill(.ultraThinMaterial)`
        // — respektuje Reduce Transparency, zamieniając materiał na kolor.
        .stolarniaMaterial(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    StolarniaPalette
                        .frostStroke
                )
                .frame(height: 1)
        }
    }

    private var workspaceNextStepStripV084:
        some View
    {
        let guidance = workspaceNextStepV084

        return StolarniaNextStepStrip(
            title: guidance.title,
            description: guidance.description,
            status: guidance.status,
            actionTitle: guidance.actionTitle,
            actionSystemImage: guidance.actionSystemImage
        ) {
            wykonajNextStepV084(
                guidance.action
            )
        }
    }

    private var workspaceNextStepV084:
        WorkspaceNextStepV084
    {
        if room.geometry.walls.isEmpty {
            return WorkspaceNextStepV084(
                title: "Brakuje geometrii pomieszczenia",
                description: "Uzupełnij pomiar ścian, zanim dodasz pierwszy moduł.",
                status: .blocked,
                actionTitle: "Wróć do pomiaru",
                actionSystemImage: "arrow.left",
                action: .returnToMeasurement
            )
        }

        if mebleViewModel.storedAssemblies.isEmpty {
            return WorkspaceNextStepV084(
                title: "Zacznij od pierwszego ciągu",
                description: "Wybierz ścianę i dodaj moduły z biblioteki setupów.",
                status: .neutral,
                actionTitle: "Dodaj moduł",
                actionSystemImage: "plus.square.on.square",
                action: .addModule
            )
        }

        if reportGotowosciV078.blockingCount > 0 {
            return WorkspaceNextStepV084(
                title: reportGotowosciV078.title,
                description: reportGotowosciV078.message,
                status: .blocked,
                actionTitle: "Sprawdź status",
                actionSystemImage: "shippingbox",
                action: .showProductionReadiness
            )
        }

        if aktywnieZaznaczoneIDsV066.count > 1 {
            return WorkspaceNextStepV084(
                title: "Zaznaczono \(aktywnieZaznaczoneIDsV066.count) modułów",
                description: "Możesz wyrównać, przesunąć, skopiować albo sprawdzić wspólną ścianę w inspektorze.",
                status: .neutral,
                actionTitle: "Pokaż inspektor",
                actionSystemImage: "sidebar.trailing",
                action: .showInspector
            )
        }

        if selectedFurniture != nil {
            return WorkspaceNextStepV084(
                title: "Moduł gotowy do dopracowania",
                description: "Sprawdź parametry, komory, fronty i konsekwencje zmiany w inspektorze lub elewacji.",
                status: .neutral,
                actionTitle:
                    pokazInspektorV074
                    ? "Elewacja"
                    : "Pokaż inspektor",
                actionSystemImage:
                    pokazInspektorV074
                    ? "rectangle.portrait"
                    : "sidebar.trailing",
                action:
                    pokazInspektorV074
                    ? .showElevation
                    : .showInspector
            )
        }

        if reportGotowosciV078.warningCount > 0 {
            return WorkspaceNextStepV084(
                title: reportGotowosciV078.title,
                description: reportGotowosciV078.message,
                status: .warning,
                actionTitle: "Sprawdź status",
                actionSystemImage: "shippingbox",
                action: .showProductionReadiness
            )
        }

        if aktywnyTrybProjektowyV074 != .widok3D {
            return WorkspaceNextStepV084(
                title: "Projekt gotowy do kontroli",
                description: "Sprawdź bryłę w 3D albo przejdź do produkcji, jeśli układ jest zaakceptowany.",
                status: .ready,
                actionTitle: "Widok 3D",
                actionSystemImage: "cube",
                action: .show3D
            )
        }

        return WorkspaceNextStepV084(
            title: "Można przejść do produkcji",
            description: reportGotowosciV078.message,
            status: .ready,
            actionTitle: "Produkcja",
            actionSystemImage: "shippingbox",
            action: .showProductionReadiness
        )
    }

    private func wykonajNextStepV084(
        _ action:
            WorkspaceNextStepActionV084
    ) {
        switch action {
        case .addModule:
            destinationV074 = .plan
            rozpocznijDodawanieModuluZPlanuV077()

        case .showInspector:
            pokazInspektorV074 = true

        case .showElevation:
            destinationV074 = .elewacja

        case .show3D:
            destinationV074 = .widok3D

        case .showProductionReadiness:
            destinationV074 = .produkcjaStart

        case .returnToMeasurement:
            dismiss()
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
                    destinationV074 = .plan
                    rozpocznijDodawanieModuluZPlanuV077()
                } label: {
                    Label(
                        "Dodaj",
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
                    "Dodaj moduł do aktywnej ściany"
                )

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

                Menu {
                    workspaceMoreMenuV084
                } label: {
                    Label(
                        "Więcej",
                        systemImage:
                            "ellipsis.circle"
                    )
                }
                .help("Pozostałe narzędzia projektu")
            }
        }
    }

    @ViewBuilder
    private var workspaceMoreMenuV084:
        some View
    {
        Button {
            cofnijOstatniaOperacjeV084()
        } label: {
            Label(
                "Cofnij",
                systemImage: "arrow.uturn.backward"
            )
        }
        .disabled(!historiaV065.moznaCofnac)
        .keyboardShortcut("z", modifiers: .command)

        Button {
            ponowOstatniaOperacjeV084()
        } label: {
            Label(
                "Ponów",
                systemImage: "arrow.uturn.forward"
            )
        }
        .disabled(!historiaV065.moznaPonowic)
        .keyboardShortcut("z", modifiers: [.command, .shift])

        Divider()

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
                systemImage: "checkmark.circle"
            )
        }
        .disabled(mebleNaAktywnejScianieV066.isEmpty)

        Button {
            duplikujAktywneZaznaczenieV067()
        } label: {
            Label(
                "Duplikuj zaznaczone",
                systemImage: "plus.square.on.square"
            )
        }
        .disabled(
            aktywnieZaznaczoneIDsV066.isEmpty
            || mebleViewModel.isSaving
            || (
                aktywnieZaznaczoneIDsV066.count > 1
                && !selectionSummaryV066.maWspolnaSciane
            )
        )

        Button(role: .destructive) {
            poprosOUsuniecieZaznaczonegoV065()
        } label: {
            Label(
                "Usuń zaznaczone",
                systemImage: "trash"
            )
        }
        .disabled(
            aktywnieZaznaczoneIDsV066.isEmpty
            || mebleViewModel.isSaving
        )

        Divider()

        Button {
            activePresentationV084 = .wykonczeniaKuchni
        } label: {
            Label(
                "Wykończenia kuchni",
                systemImage: "rectangle.portrait.topleft.inset.filled"
            )
            .symbolVariant(
                wykonczeniaRepo.maPozycje
                ? .fill
                : .none
            )
        }

        Menu {
            workspacePartitionMenuV084
        } label: {
            Label(
                "Ścianki dzielące",
                systemImage: "door.sliding.left.hand.open"
            )
        }

        Button {
            activePresentationV084 = .layoutPrzeglad
        } label: {
            Label(
                "Podgląd układu",
                systemImage: "rectangle.3.group"
            )
        }

        Divider()

        Button {
            activePresentationV084 = .dwgImport
        } label: {
            Label(
                "Import DWG architekta",
                systemImage: "square.and.arrow.down.on.square"
            )
        }

        if let url = dxfExportURL {
            ShareLink(
                item: url,
                subject: Text("\(room.name) — rzut 2D"),
                message: Text(
                    "Rzut 2D pomieszczenia z meblami. Format DXF — kompatybilny z AutoCAD, ArchiCAD, Revit."
                )
            ) {
                Label(
                    "Udostępnij DXF",
                    systemImage: "arrow.up.doc"
                )
            }
        } else {
            Button {
                przygotujEksportDXF()
            } label: {
                Label(
                    "Eksportuj DXF",
                    systemImage: "arrow.up.doc"
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
        }

        Divider()

        Picker(
            "Zakres wymiarów",
            selection: poziomWymiarowaniaBinding
        ) {
            ForEach(PoziomWymiarowania2D.allCases) {
                item in

                Label(
                    item.title,
                    systemImage: item.systemImage
                )
                .tag(item)
            }
        }
    }

    @ViewBuilder
    private var workspacePartitionMenuV084:
        some View
    {
        if let candidate =
            activeSlidingPartitionCandidateV092 {
            Button {
                utworzPrzegrodePrzesuwnaZCanvasV092(
                    candidate:
                        candidate
                )
            } label: {
                Label(
                    "Dodaj przegrodę z zaznaczonego modułu",
                    systemImage:
                        "door.sliding.left.hand.open"
                )
            }
            .disabled(mebleViewModel.isSaving)

            Divider()
        }

        if sciankaRepo.sciankiDzielace.isEmpty {
            Button {
                activePresentationV084 = .sciankaPodziałowa(nil)
            } label: {
                Label(
                    "Dodaj ściankę dzielącą",
                    systemImage: "plus"
                )
            }
        } else {
            ForEach(sciankaRepo.sciankiDzielace) {
                scianka in

                Button {
                    activePresentationV084 = .sciankaPodziałowa(scianka)
                } label: {
                    Label(
                        scianka.nazwa,
                        systemImage: "door.sliding.left.hand.open"
                    )
                }
            }

            Divider()

            Button {
                activePresentationV084 = .sciankaPodziałowa(nil)
            } label: {
                Label(
                    "Dodaj ściankę dzielącą",
                    systemImage: "plus"
                )
            }
        }
    }

    private func cofnijOstatniaOperacjeV084() {
        Task {
            let result =
                await historiaV065.cofnij(
                    viewModel:
                        mebleViewModel
                )

            if result.powodzenie {
                zastosujZaznaczeniePoHistoriiV066(
                    result
                )
            }
        }
    }

    private func ponowOstatniaOperacjeV084() {
        Task {
            let result =
                await historiaV065.ponow(
                    viewModel:
                        mebleViewModel
                )

            if result.powodzenie {
                zastosujZaznaczeniePoHistoriiV066(
                    result
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
    private func activePresentationViewV084(
        _ presentation:
            WorkspacePresentationV084
    ) -> some View {
        switch presentation {
        case .furnitureLibrary(
            let wallID,
            let initialGroup,
            let initialCategory
        ):
            if let wall =
                room.geometry.wall(id: wallID)
            {
                BibliotekaModulowMeblowychView(
                    templates:
                        availableModuleTemplatesV063,
                    initialGroup:
                        initialGroup
                        ?? .kitchen,
                    initialCategory:
                        initialCategory,
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
                            activePresentationV084 = nil
                        }
                    }
                }
            }

        case .wykonczeniaKuchni:
            WykonczeniaKuchenneEditorV082(
                repo: wykonczeniaRepo,
                bazowaDlugoscCiaguMM: bazowaDlugoscCiaguV082,
                ciagiDolneV087:
                    ciagiDolneWykonczenV087
            )

        case .dwgImport:
            DWGImportKontenerV001(
                mebleViewModel: mebleViewModel,
                room: room,
                walls: room.geometry.walls
            )

        }
    }

    /// Suma długości modułów stojących na podłodze (ciąg dolny) — używana
    /// do automatycznego przeliczania długości fartucha i listew.
    private var bazowaDlugoscCiaguV082: Double {
        ciagiDolneWykonczenV087
            .reduce(0.0) {
                $0 + $1.dlugoscMM
            }
    }

    private var ciagiDolneWykonczenV087:
        [KitchenRunFinishingSegmentV087]
    {
        mebleViewModel
            .kitchenBaseFinishingSegmentsV087(
                room:
                    room
            )
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
                slidingPartitionDraftV092:
                    manualSlidingPartitionCandidateV092,
                onChangeSlidingPartitionDraftEndV092: {
                    point in

                    zaktualizujKoniecPrzegrodyV092(
                        point
                    )
                },
                renderRevision: mebleViewModel.renderRevision
            )
            .overlay(alignment: .top) {
                if let candidate =
                    activeSlidingPartitionCandidateV092 {
                    SlidingPartitionCanvasActionV092(
                        candidate:
                            candidate,
                        isManualEditing:
                            manualSlidingPartitionCandidateV092
                            != nil,
                        isSaving:
                            mebleViewModel.isSaving
                    ) {
                        rozpocznijReczneUstawianiePrzegrodyV092(
                            candidate
                        )
                    } cancelManualAction: {
                        manualSlidingPartitionCandidateV092 =
                            nil
                    } commitAction: {
                        utworzPrzegrodePrzesuwnaZCanvasV092(
                            candidate:
                                candidate
                        )
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .layoutPriority(1)

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
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .layoutPriority(1)
            } else {
                ContentUnavailableView(
                    "Brak ściany",
                    systemImage: "rectangle.slash",
                    description: Text("Dodaj ścianę, aby otworzyć elewację.")
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }

        case .elewacjaWyspy:
            WidokElewacjiWyspyV083(
                storedAssemblies:
                    mebleViewModel.storedAssemblies,
                selectedFurnitureID:
                    $selectedFurnitureID
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .layoutPriority(1)

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
                .stolarniaMaterial(
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
            .overlay(alignment: .topTrailing) {
                Furniture3DMaterialLegendV017(
                    materialy:
                        globalneMaterialyRepository
                            .ustawienia
                )
                .padding()
            }
            .overlay(alignment: .bottom) {
                Furniture3DControlsV017(
                    presentationState: $presentation3D,
                    isEnabled: !mebleViewModel.assemblies.isEmpty
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                // `stolarniaMaterial`, nie surowy `Rectangle().fill(...)` —
                // respektuje Reduce Transparency.
                .stolarniaMaterial(.ultraThinMaterial)
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
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(StolarniaPalette.frostStroke)
                        .frame(height: 1)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .layoutPriority(1)

        case .garderobyDrzwi:
            GarderobyDrzwiWorkspaceV086(
                room: room,
                assemblies:
                    mebleViewModel
                        .storedAssemblies,
                selectedFurnitureID:
                    $selectedFurnitureID,
                onAddSlidingWardrobe: {
                    rozpocznijDodawanieModulowPodPrzesuwneV092()
                },
                onAddSlidingSystem: {
                    run,
                    doorFill in

                    Task {
                        guard let wall =
                            room.geometry.wall(
                                id:
                                    run.wallID
                            )
                        else {
                            return
                        }

                        let didCreate =
                            await mebleViewModel
                            .createSlidingWardrobeSystemV087(
                                for:
                                    run,
                                wall:
                                    wall,
                                room:
                                    room,
                                doorFill:
                                    doorFill
                            )

                        if didCreate {
                            await MainActor.run {
                                selectedWallID =
                                    run.wallID
                            }
                        }
                    }
                }
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .layoutPriority(1)
        }
    }

    private func utworzPrzegrodePrzesuwnaZCanvasV092(
        candidate:
            SlidingRoomPartitionCandidateV092
    ) {
        guard !mebleViewModel.isSaving else {
            return
        }

        Task {
            let didCreate =
                await mebleViewModel
                .createSlidingRoomPartitionV092(
                    candidate:
                        candidate,
                    room:
                        room
                )

            if didCreate {
                await MainActor.run {
                    manualSlidingPartitionCandidateV092 =
                        nil
                    if let createdID =
                        mebleViewModel
                            .lastCreatedAssemblyID {
                        selectedFurnitureID =
                            createdID
                        zaznaczoneFurnitureIDsV066 =
                            [createdID]
                    }
                    destinationV074 =
                        .plan
                }
            }
        }
    }

    private func rozpocznijReczneUstawianiePrzegrodyV092(
        _ candidate:
            SlidingRoomPartitionCandidateV092
    ) {
        manualSlidingPartitionCandidateV092 =
            candidate
    }

    private func zaktualizujKoniecPrzegrodyV092(
        _ end:
            Point2MM
    ) {
        guard let current =
            manualSlidingPartitionCandidateV092
        else {
            return
        }

        manualSlidingPartitionCandidateV092 =
            kandydatPrzegrodyV092(
                from:
                    current,
                end:
                    ograniczonyPunktPrzegrodyV092(
                        end
                    )
            )
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
        activePresentationV084 =
            .furnitureLibrary(
                wallID:
                    wall.id,
                initialGroup:
                    nil,
                initialCategory:
                    nil
            )
    }

    private func rozpocznijDodawanieModulowPodPrzesuwneV092() {
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

        selectedWallID = wall.id
        selectedFurnitureID = nil
        zaznaczoneFurnitureIDsV066.removeAll()
        activePresentationV084 =
            .furnitureLibrary(
                wallID:
                    wall.id,
                initialGroup:
                    .wardrobes,
                initialCategory:
                    .builtInWardrobe
            )
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
              let placement = stored.assembly.placement else {
            return
        }

        let context: KontekstPrzesunieciaModulu2D
        if placement.anchoringMode == .freestanding
            || placement.wallID == nil {
            context = KontekstPrzesunieciaModulu2D(
                furnitureID: stored.id,
                wallID: nil,
                proponowaneOdsuniecie: Millimeters(
                    max(
                        0,
                        placement.offsetAlongWall.rawValue
                            + dx
                    )
                ),
                proponowaneOdsuniecieOdSciany: Millimeters(
                    max(
                        0,
                        placement.offsetFromWall.rawValue
                            + dy
                    )
                ),
                celZamianyID: nil
            )
        } else {
            guard let wallID = placement.wallID else {
                return
            }

            context = KontekstPrzesunieciaModulu2D(
                furnitureID: stored.id,
                wallID: wallID,
                proponowaneOdsuniecie: Millimeters(
                    max(
                        0,
                        placement.offsetAlongWall.rawValue
                            + dx
                    )
                ),
                celZamianyID: nil,
                proponowaneOdsuniecieOdDolu: Millimeters(
                    max(
                        0,
                        placement.bottomOffset.rawValue
                            + dy
                    )
                )
            )
        }

        let before = mebleViewModel.migawkiPolozenV064(ids: [stored.id])

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

    private var slidingPartitionCandidateV092:
        SlidingRoomPartitionCandidateV092?
    {
        guard aktywnyTrybProjektowyV074 == .plan else {
            return nil
        }

        return mebleViewModel
            .slidingRoomPartitionCandidateV092(
                from:
                    selectedFurnitureID,
                room:
                    room
            )
    }

    private var activeSlidingPartitionCandidateV092:
        SlidingRoomPartitionCandidateV092?
    {
        manualSlidingPartitionCandidateV092
        ?? slidingPartitionCandidateV092
    }

    private func kandydatPrzegrodyV092(
        from base:
            SlidingRoomPartitionCandidateV092,
        end:
            Point2MM
    ) -> SlidingRoomPartitionCandidateV092 {
        let dx =
            end.x.rawValue - base.start.x.rawValue
        let dy =
            end.y.rawValue - base.start.y.rawValue
        let length =
            max(
                hypot(dx, dy),
                1
            )
        let id =
            [
                base.anchorAssemblyID.description,
                "manual",
                Int(base.start.x.rawValue.rounded()).description,
                Int(base.start.y.rawValue.rounded()).description,
                Int(end.x.rawValue.rounded()).description,
                Int(end.y.rawValue.rounded()).description
            ]
            .joined(separator: "-")

        return SlidingRoomPartitionCandidateV092(
            id:
                id,
            anchorAssemblyID:
                base.anchorAssemblyID,
            anchorName:
                base.anchorName,
            start:
                base.start,
            end:
                end,
            length:
                Millimeters(length),
            height:
                base.height,
            rotationDegrees:
                atan2(dy, dx) * 180 / .pi,
            sideLabel:
                "ręczny koniec toru"
        )
    }

    private func ograniczonyPunktPrzegrodyV092(
        _ point:
            Point2MM
    ) -> Point2MM {
        let points =
            room.geometry.boundary.segments.flatMap {
                Plan2DGeometryAdapter
                    .sampledPoints(
                        for:
                            $0
                    )
            }
        guard !points.isEmpty else {
            return point
        }

        let minX =
            points.map(\.x.rawValue).min() ?? point.x.rawValue
        let maxX =
            points.map(\.x.rawValue).max() ?? point.x.rawValue
        let minY =
            points.map(\.y.rawValue).min() ?? point.y.rawValue
        let maxY =
            points.map(\.y.rawValue).max() ?? point.y.rawValue

        return Point2MM(
            x:
                Millimeters(
                    min(
                        max(
                            point.x.rawValue,
                            minX
                        ),
                        maxX
                    )
                ),
            y:
                Millimeters(
                    min(
                        max(
                            point.y.rawValue,
                            minY
                        ),
                        maxY
                    )
                )
        )
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
            room: room,
            globalneMaterialy: globalneMaterialyRepository.ustawienia
        )
        cachedListaFormatekV074 = lista

        let rozkroj = RozkrojPlytEngineV071.build(
            list: lista,
            settings: .standard
        )
        cachedRozkrojV0103 = rozkroj

        cachedReportGotowosciV074 = ProjectReadinessEngineV078.build(
            room: room,
            assemblies: mebleViewModel.storedAssemblies,
            materialy: globalneMaterialyRepository.ustawienia,
            lista: lista,
            raport: rozkroj
        )

        cachedWycenaV0103 = przeliczWycenePomieszczeniaV0103()
        cachedPodsumowanieWycenyV0103 = cachedWycenaV0103.flatMap { wycena in
            SilnikWycenyWariantowej
                .oblicz(
                    projekt: wycena,
                    ustawienia: UstawieniaStolarniRepository.aktualne(),
                    materialy: bazaMaterialowRepository.materialy,
                    okucia: bazaOkucRepositoryV0103.okucia
                )
                .first { $0.wariant == .standard }
        }

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

private struct SlidingPartitionCanvasActionV092: View {
    let candidate:
        SlidingRoomPartitionCandidateV092
    let isManualEditing:
        Bool
    let isSaving:
        Bool
    let startManualAction:
        () -> Void
    let cancelManualAction:
        () -> Void
    let commitAction:
        () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(
                "Przegroda przesuwna",
                systemImage:
                    "door.sliding.left.hand.open"
            )
            .font(.subheadline.weight(.semibold))

            Divider()
                .frame(height: 26)

            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {
                Text(candidate.anchorName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(
                    isManualEditing
                    ? "Przeciągnij końcówkę toru, \(candidate.lengthLabel)"
                    : "\(candidate.lengthLabel), \(candidate.doorCount) skrzydła, \(candidate.sideLabel)"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isManualEditing {
                Button(
                    "Anuluj",
                    action:
                        cancelManualAction
                )
                .buttonStyle(.bordered)

                Button(
                    action:
                        commitAction
                ) {
                    Label(
                        "Zapisz",
                        systemImage:
                            "checkmark"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isSaving
                    || candidate.length.rawValue < 600
                )
            } else {
                Button(
                    action:
                        startManualAction
                ) {
                    Label(
                        "Ustaw ręcznie",
                        systemImage:
                            "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)

                Button(
                    action:
                        commitAction
                ) {
                    Label(
                        "Dodaj",
                        systemImage:
                            "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 720)
        .stolarniaMaterial(
            .ultraThinMaterial,
            in: RoundedRectangle(
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
            color:
                Color.black.opacity(0.12),
            radius:
                12,
            y:
                6
        )
    }
}

private struct WidokElewacjiWyspyV083: View {
    let storedAssemblies: [StoredFurnitureAssembly]
    @Binding var selectedFurnitureID: FurnitureAssemblyID?

    private var islands: [StoredFurnitureAssembly] {
        storedAssemblies
            .filter {
                guard let placement = $0.assembly.placement else {
                    return false
                }
                return placement.anchoringMode == .freestanding
                    || placement.wallID == nil
            }
            .sorted {
                ($0.assembly.placement?.offsetAlongWall ?? .zero)
                    <
                ($1.assembly.placement?.offsetAlongWall ?? .zero)
            }
    }

    private var activeIsland: StoredFurnitureAssembly? {
        if let selectedFurnitureID,
           let selected = islands.first(where: {
               $0.id == selectedFurnitureID
           }) {
            return selected
        }

        return islands.first
    }

    var body: some View {
        Group {
            if islands.isEmpty {
                ContentUnavailableView(
                    "Brak wyspy",
                    systemImage: "rectangle.dashed",
                    description: Text(
                        "Dodaj moduł wolnostojący z biblioteki, aby zobaczyć jego elewację."
                    )
                )
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let activeIsland {
                        GeometryReader { proxy in
                            elevationCanvas(
                                for: activeIsland,
                                size: proxy.size
                            )
                        }
                        .frame(minHeight: 420)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(StolarniaPalette.paper.opacity(0.22))
            }
        }
        .onAppear {
            ensureIslandSelection()
        }
        .onChange(of: islands.map(\.id)) { _, _ in
            ensureIslandSelection()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "Elewacja wyspy",
                systemImage: "rectangle.center.inset.filled"
            )
            .font(.title2.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(islands) { stored in
                        Button {
                            selectedFurnitureID = stored.id
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stored.assembly.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(sizeText(for: stored))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minWidth: 160, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(
                            stored.id == activeIsland?.id
                                ? Color.accentColor
                                : Color.secondary
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func elevationCanvas(
        for stored: StoredFurnitureAssembly,
        size: CGSize
    ) -> some View {
        let assembly = stored.assembly
        let width = max(assembly.size.width.rawValue, 1)
        let height = max(assembly.size.height.rawValue, 1)
        let scale = min(
            max(size.width - 96, 1) / CGFloat(width),
            max(size.height - 150, 1) / CGFloat(height)
        )
        let drawingSize = CGSize(
            width: CGFloat(width) * scale,
            height: CGFloat(height) * scale
        )

        return ZStack(alignment: .bottom) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                StolarniaPalette.frostStroke,
                                lineWidth: 1
                            )
                    }

                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    StolarniaPalette.paper,
                                    StolarniaPalette.paper.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Rectangle()
                                .stroke(
                                    Color.primary.opacity(0.28),
                                    lineWidth: 2
                                )
                        }

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.16))
                            .frame(height: 2)
                        Spacer()
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 2)
                        Spacer()
                        Rectangle()
                            .fill(Color.primary.opacity(0.16))
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 10)

                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 2)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .frame(
                    width: drawingSize.width,
                    height: drawingSize.height
                )
                .shadow(
                    color: Color.black.opacity(0.14),
                    radius: 18,
                    y: 10
                )
            }
            .padding(.bottom, 116)

            VStack(alignment: .leading, spacing: 10) {
                Text(assembly.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    metric(
                        "Szerokość",
                        assembly.size.width
                    )
                    metric(
                        "Wysokość",
                        assembly.size.height
                    )
                    metric(
                        "Głębokość",
                        assembly.size.depth
                    )
                }

                if let placement = assembly.placement {
                    HStack(spacing: 12) {
                        metric("X", placement.offsetAlongWall)
                        metric("Y", placement.offsetFromWall)
                    }
                }
            }
            .padding(14)
            .frame(
                maxWidth: 680,
                alignment: .leading
            )
            .stolarniaMaterial(
                .ultraThinMaterial,
                in: RoundedRectangle(
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
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metric(
        _ title: String,
        _ value: Millimeters
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MebelWymiarFormatterV0143.millimeters(value))
                .font(.body.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private func sizeText(
        for stored: StoredFurnitureAssembly
    ) -> String {
        let size = stored.assembly.size
        return "\(Self.integer(size.width)) x \(Self.integer(size.height)) x \(Self.integer(size.depth)) mm"
    }

    private static func integer(
        _ value: Millimeters
    ) -> String {
        value.rawValue.formatted(
            .number.precision(.fractionLength(0))
        )
    }

    private func ensureIslandSelection() {
        guard let firstID = islands.first?.id else {
            return
        }

        if selectedFurnitureID == nil
            || !islands.contains(where: {
                $0.id == selectedFurnitureID
            }) {
            selectedFurnitureID = firstID
        }
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
        Button {
            onNudge(dx, dy)
        } label: {
            // Cel dotyku podany wprost, nie wynikający z długości napisu.
            // Tymi przyciskami poprawia się położenie mebla o milimetr,
            // czyli używa się ich seriami — `controlSize(.small)` dawało
            // 28 pt, czyli 5,4 mm, przy progu komfortu 9,2 mm.
            // Wysokość jest twarda, szerokość ustępliwa: cztery przyciski
            // („← 10 / ← 1 / → 1 / → 10") muszą zmieścić się w inspektorze
            // szerokości ok. 270 pt, więc rośnie ten wymiar, który decyduje
            // o trafianiu palcem, a nie ten, który rozsadza wiersz.
            Text(title)
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: 34, minHeight: 44)
        }
        .buttonStyle(.bordered)
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
