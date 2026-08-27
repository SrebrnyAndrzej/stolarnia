import DomainCore
import Persistence
import SwiftData
import SwiftUI

struct PanelGlownyView: View {
    @State private var selectedSection:
        PanelGlownySekcja? = .projekty

    @State private var selectedCompanySection:
        PanelFirmySekcja = .ustawienia

    @State private var columnVisibility:
        NavigationSplitViewVisibility = .detailOnly

    @State private var navigationGeneration =
        UUID()

    @StateObject private var projectViewModel:
        ProjektListaViewModel

    private let roomRepository:
        SwiftDataRoomRepository
    private let furnitureRepositories:
        MebleRepositoryContainer

    init(
        projectRepository:
            SwiftDataProjectRepository,
        roomRepository:
            SwiftDataRoomRepository,
        mebleRepositories:
            MebleRepositoryContainer
    ) {
        self.roomRepository = roomRepository
        self.furnitureRepositories =
            mebleRepositories

        _projectViewModel = StateObject(
            wrappedValue:
                ProjektListaViewModel(
                    projectRepository:
                        projectRepository
                )
        )
    }

    /// Czy pokazać pulpit kaflowy zamiast dawnego menu w menu.
    ///
    /// Pulpit jest **ekranem startowym**; wejście w projekt albo bazę otwiera
    /// dotychczasowy `NavigationSplitView`. Stara nawigacja nie znika —
    /// zmienia się tylko to, jak się do niej wchodzi.
    @State private var pokazPulpitV0105 = true
    @State private var nowyProjektZPulpituV0105 = false

    var body: some View {
        if pokazPulpitV0105 {
            pulpitV0105
        } else {
            splitViewV0105
        }
    }

    /// Pulpit warsztatu — kafle zamiast dwóch list jedna za drugą.
    ///
    /// Dawny ekran startowy trzymał w pasku o szerokości 290 pt **dwie
    /// pozycje**, a wybranie drugiej dawało listę czterech. Do bazy materiałów
    /// szło się przez dwa poziomy listy, choć w aplikacji jest sześć miejsc
    /// razem.
    private var pulpitV0105: some View {
        PulpitStolarniV0105(
            projekty: projectViewModel.projects,
            ladowanie: projectViewModel.isLoading,
            onOtworzProjekt: { projekt in
                projectViewModel.selectedProjectID = projekt.id
                selectedSection = .projekty
                otworzZeSplitViewV0105()
            },
            onNowyProjekt: {
                selectedSection = .projekty
                nowyProjektZPulpituV0105 = true
                // Lista musi być widoczna: to ona stawia arkusz nowego
                // projektu. Przy ukrytej kolumnie SwiftUI nie buduje jej
                // widoku, więc arkusz nie miałby się z czego pokazać.
                otworzZeSplitViewV0105(kolumny: .all)
            },
            onOtworzBaze: { kafel in
                selectedSection = .firma
                selectedCompanySection = kafel.dawnaSekcjaV0105
                otworzZeSplitViewV0105()
            }
        )
        .task {
            await projectViewModel.loadProjects()
        }
    }

    /// Wejście w dotychczasową nawigację z pulpitu.
    ///
    /// `navigationGeneration` odświeżamy tak samo jak przy zmianie sekcji —
    /// bez tego kolumny zachowują stan poprzedniego wyboru.
    /// Powrót na pulpit — dostępny **z każdego miejsca**, nie tylko z projektu.
    ///
    /// Bez tego wejście w bazę materiałów byłoby ślepą uliczką: pulpit jest
    /// ekranem startowym, więc musi być osiągalny tak samo jak przycisk domu
    /// w przeglądarce, a nie tylko przez cofanie się krok po kroku.
    private var przyciskPulpituV0105: some View {
        Button {
            pokazPulpitV0105 = true
        } label: {
            Label("Pulpit", systemImage: "square.grid.2x2")
        }
        .stolarniaPressable()
    }

    private func otworzZeSplitViewV0105(
        kolumny: NavigationSplitViewVisibility = .detailOnly
    ) {
        columnVisibility = kolumny
        navigationGeneration = UUID()
        pokazPulpitV0105 = false
    }

    /// Nawigacja po wejściu z pulpitu.
    ///
    /// **Trzy kolumny zeszły do dwóch — i tylko dla projektów.**
    ///
    /// Dawny pasek boczny („Klienci i projekty" / „Firma i bazy") oraz menu
    /// firmy (cztery pozycje) były **w całości zdublowane przez pulpit**.
    /// Zostawione jako trzecia kolumna dawały dwie równoległe drogi do tego
    /// samego ekranu, z których jedna była o dwa stuknięcia dłuższa —
    /// a przy otwartym pasku bocznym zabierały ćwierć szerokości iPada.
    ///
    /// Bazy nie mają listy do przeglądania, więc nie mają po co być w układzie
    /// kolumnowym: z pulpitu wchodzi się prosto w ekran. Projekty listę mają
    /// i ona jest przydatna (szukanie, długie zestawienia), więc tu układ
    /// dwukolumnowy zostaje.
    @ViewBuilder
    private var splitViewV0105: some View {
        Group {
            if selectedSection == .firma {
                bazaPelnoekranowaV0107
            } else {
                projektyDwukolumnowoV0107
            }
        }
        .tint(StolarniaPalette.accent)
        .environment(\.colorScheme, .dark)
        .background(
            StolarniaPalette.canvas
                .ignoresSafeArea()
        )
        .task {
            await projectViewModel
                .loadProjects()
        }
        .alert(
            "Nie udało się wykonać operacji",
            isPresented: errorBinding
        ) {
            Button(
                "Zamknij",
                role: .cancel
            ) {
                projectViewModel
                    .errorMessage = nil
            }
        } message: {
            Text(
                projectViewModel.errorMessage
                ?? "Nieznany błąd"
            )
        }
    }

    /// Baza wchodzi na pełny ekran — nie ma listy, którą trzeba przeglądać
    /// obok treści.
    private var bazaPelnoekranowaV0107: some View {
        NavigationStack {
            companyDetail
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        przyciskPulpituV0105
                    }
                }
        }
        .id(navigationGeneration)
        .stolarniaScreenSurface(.detail)
        .stolarniaReadableInterface()
    }

    private var projektyDwukolumnowoV0107: some View {
        NavigationSplitView(
            columnVisibility:
                $columnVisibility
        ) {
            ProjektListaView(
                viewModel:
                    projectViewModel,
                zadanieNowegoProjektuV0105:
                    $nowyProjektZPulpituV0105
            )
            // Bez przycisku pulpitu: przy otwartych obu kolumnach stałby
            // obok tego samego przycisku w karcie projektu, czyli dwa
            // różnie nazwane wejścia do jednego miejsca. Tytuł kolumny
            // ustawia sam `ProjektListaView`.
            .navigationSplitViewColumnWidth(
                min: 260,
                ideal: 300,
                max: 360
            )
            .id(navigationGeneration)
        } detail: {
            NavigationStack {
                projectDetail
            }
            .id(
                navigationGeneration
            )
            .stolarniaScreenSurface(
                .detail
            )
            .stolarniaReadableInterface()
        }
        .navigationSplitViewStyle(
            .balanced
        )
        .tint(StolarniaPalette.accent)
        .environment(\.colorScheme, .dark)
        .background(
            StolarniaPalette.canvas
                .ignoresSafeArea()
        )
        .task {
            await projectViewModel
                .loadProjects()
        }
        .alert(
            "Nie udało się wykonać operacji",
            isPresented: errorBinding
        ) {
            Button(
                "Zamknij",
                role: .cancel
            ) {
                projectViewModel
                    .errorMessage = nil
            }
        } message: {
            Text(
                projectViewModel.errorMessage
                ?? "Nieznany błąd"
            )
        }
    }

    @ViewBuilder
    private var projectDetail:
        some View
    {
        if let project =
            projectViewModel.project(
                id:
                    projectViewModel
                        .selectedProjectID
            ) {
            ProjektSzczegolyView(
                project: project,
                roomRepository:
                    roomRepository,
                mebleRepositories:
                    furnitureRepositories,
                onReturnToProjectList:
                    returnToProjectList
            )
            .id(project.id)
        } else {
            // Lista projektów bywa schowana — wchodząc w projekt z pulpitu
            // otwieramy od razu jego kartę, żeby nie oglądać listy, przez
            // którą się nie przyszło. Gdy zaznaczenie znika (usunięty
            // projekt, powrót), ten ekran musi mieć wyjście u siebie:
            // odesłanie do „środkowego panelu", którego nie widać, byłoby
            // ślepą uliczką.
            StolarniaEmptyState(
                title: "Wybierz projekt",
                description:
                    "Otwórz listę projektów albo wróć na pulpit.",
                systemImage:
                    "doc.text.magnifyingglass",
                actionTitle: "Pokaż listę projektów",
                actionSystemImage: "sidebar.left",
                action: {
                    withAnimation(
                        StolarniaMotion.panelBoczny
                    ) {
                        columnVisibility = .all
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var companyDetail:
        some View
    {
        switch selectedCompanySection {
        case .ustawienia:
            PanelUstawienStolarni(
                trybPrezentacji:
                    .osadzony
            )

        case .materialy:
            BazaMaterialowView()

        case .okucia:
            BazaOkucView()

        case .dalmierz:
            PanelDalmierzaGlownyView()
        }
    }

    private var errorBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                projectViewModel
                    .errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    projectViewModel
                        .errorMessage = nil
                }
            }
        )
    }

    /// Powrót z projektu — **na pulpit**, nie na listę.
    ///
    /// Pulpit jest teraz miejscem, z którego się startuje, więc jest też
    /// miejscem, do którego się wraca. Wyrzucenie użytkownika na środkową
    /// kolumnę oznaczałoby, że wyjście z projektu ląduje gdzie indziej niż
    /// wejście do niego.
    private func returnToProjectList() {
        pokazPulpitV0105 = true
        selectedSection = .projekty
        projectViewModel
            .selectedProjectID = nil
        columnVisibility = .detailOnly
    }
}

/// Sekcje działu „Firma".
///
/// Nie jest już `private`, bo pulpit kaflowy mapuje na nie swoje kafle —
/// kafel jest nowym wejściem do tych samych ekranów, nie ich kopią.
enum PanelFirmySekcja:
    String,
    CaseIterable,
    Identifiable
{
    case ustawienia
    case materialy
    case okucia
    case dalmierz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ustawienia:
            return "Dane firmy i ustawienia"
        case .materialy:
            return "Baza materiałów i cennik płyt"
        case .okucia:
            return "Baza okuć i systemów"
        case .dalmierz:
            return "Dalmierz HOTO"
        }
    }

    var subtitle: String {
        switch self {
        case .ustawienia:
            return "Stawki, technologia i dane do dokumentów"
        case .materialy:
            return "Płyty, wzorniki, ceny, rabaty i dostawcy"
        case .okucia:
            return "Zawiasy, prowadnice, cargo, LED i akcesoria"
        case .dalmierz:
            return "Połączenie BLE z dalmierzem HOTO D50"
        }
    }

    var systemImage: String {
        switch self {
        case .ustawienia:
            return "gearshape.2"
        case .materialy:
            return "square.grid.2x2"
        case .okucia:
            return "shippingbox"
        case .dalmierz:
            return "dot.radiowaves.left.and.right"
        }
    }
}
