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

    var body: some View {
        NavigationSplitView(
            columnVisibility:
                $columnVisibility
        ) {
            mainSidebar
        } content: {
            Group {
                secondaryColumn
            }
            .id(
                navigationGeneration
            )
        } detail: {
            NavigationStack {
                detailColumn
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

    private var mainSidebar:
        some View
    {
        List {
            Section {
                ForEach(
                    PanelGlownySekcja
                        .allCases
                ) { section in
                    Button {
                        selectMainSection(
                            section
                        )
                    } label: {
                        StolarniaNavigationRow(
                            title:
                                section.title,
                            subtitle:
                                section.subtitle,
                            systemImage:
                                section.systemImage,
                            isSelected:
                                selectedSection
                                == section,
                            tone: .dark
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedSection
                            == section
                        ? StolarniaPalette
                            .accent
                            .opacity(0.20)
                        : StolarniaPalette
                            .canvas
                            .opacity(0.46)
                    )
                    .accessibilityLabel(
                        section.title
                    )
                    .accessibilityHint(
                        section.subtitle
                    )
                }
            } header: {
                Text("Główne moduły")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Stolarnia")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .environment(\.colorScheme, .dark)
        .stolarniaScreenSurface(
            .sidebar
        )
        .navigationSplitViewColumnWidth(
            min: 250,
            ideal: 290,
            max: 340
        )
    }

    @ViewBuilder
    private var secondaryColumn:
        some View
    {
        switch selectedSection {
        case .projekty:
            ProjektListaView(
                viewModel:
                    projectViewModel
            )
            .navigationTitle(
                "Klienci i projekty"
            )

        case .firma:
            companyMenu

        case nil:
            StolarniaEmptyState(
                title: "Wybierz moduł",
                description:
                    "Wybierz moduł z menu po lewej.",
                systemImage:
                    "sidebar.left"
            )
        }
    }

    private var companyMenu:
        some View
    {
        List {
            Section(
                "Firma i bazy"
            ) {
                ForEach(
                    PanelFirmySekcja
                        .allCases
                ) { section in
                    Button {
                        selectCompanySection(
                            section
                        )
                    } label: {
                        StolarniaNavigationRow(
                            title:
                                section.title,
                            subtitle:
                                section.subtitle,
                            systemImage:
                                section.systemImage,
                            isSelected:
                                selectedCompanySection
                                == section
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedCompanySection
                            == section
                        ? StolarniaPalette
                            .accent
                            .opacity(0.20)
                        : StolarniaPalette
                            .canvasRaised
                            .opacity(0.46)
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Firma")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .environment(\.colorScheme, .dark)
        .stolarniaScreenSurface(
            .content
        )
        .navigationSplitViewColumnWidth(
            min: 280,
            ideal: 340,
            max: 420
        )
    }

    @ViewBuilder
    private var detailColumn:
        some View
    {
        switch selectedSection {
        case .projekty:
            projectDetail

        case .firma:
            companyDetail

        case nil:
            StolarniaEmptyState(
                title: "Wybierz moduł",
                description:
                    "Wybierz moduł z menu po lewej.",
                systemImage:
                    "sidebar.left"
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
            StolarniaEmptyState(
                title: "Wybierz projekt",
                description:
                    "Najpierw wybierz klienta lub projekt w środkowym panelu.",
                systemImage:
                    "doc.text.magnifyingglass"
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

    private func selectMainSection(
        _ section:
            PanelGlownySekcja
    ) {
        selectedSection = section

        switch section {
        case .projekty:
            selectedCompanySection =
                .ustawienia

        case .firma:
            projectViewModel
                .selectedProjectID = nil
            selectedCompanySection =
                .ustawienia
        }

        columnVisibility = .detailOnly
        navigationGeneration = UUID()
    }

    private func selectCompanySection(
        _ section:
            PanelFirmySekcja
    ) {
        selectedCompanySection = section
        navigationGeneration = UUID()
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

    private func returnToProjectList() {
        selectedSection = .projekty
        projectViewModel
            .selectedProjectID = nil
        columnVisibility = .detailOnly
    }
}

private enum PanelFirmySekcja:
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
