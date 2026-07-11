import DomainCore
import Persistence
import SwiftUI

private enum ProjektSzczegolySheet:
    Identifiable
{
    case newRoom
    case projectQuote
    case globalMaterialy

    var id: String {
        switch self {
        case .newRoom:
            return "new-room"

        case .projectQuote:
            return "project-quote"

        case .globalMaterialy:
            return "global-materialy"
        }
    }
}

struct ProjektSzczegolyView: View {
    let project: WorkshopProject
    let onReturnToProjectList: (() -> Void)?

    @StateObject private var roomViewModel: PomieszczenieListaViewModel
    @State private var isLoadingProjectQuote = false
    @State private var projectQuote: ProjektWyceny?
    @State private var quoteErrorMessage: String?
    @State private var activeSheet:
        ProjektSzczegolySheet?
    @State private var selectedRoomForMeasurements:
        RoomDefinition?
    @State private var roomForProject:
        RoomDefinition?
    @State private var activeWorkflowRoomID:
        RoomID?
    @State private var roomPendingDeletion:
        RoomDefinition?
    @State private var showTechnicalInfo = false
    @State private var showMeasurementsSavedToast = false

    @StateObject private var globalMaterialyRepo:
        GlobalneMaterialyProjektuRepository

    private let roomRepository: SwiftDataRoomRepository
    private let mebleRepositories: MebleRepositoryContainer

    init(
        project: WorkshopProject,
        roomRepository: SwiftDataRoomRepository,
        mebleRepositories: MebleRepositoryContainer,
        onReturnToProjectList: (() -> Void)? = nil
    ) {
        self.project = project
        self.roomRepository = roomRepository
        self.mebleRepositories = mebleRepositories
        self.onReturnToProjectList = onReturnToProjectList

        _roomViewModel = StateObject(
            wrappedValue: PomieszczenieListaViewModel(
                projectID: project.id,
                roomRepository: roomRepository
            )
        )

        _globalMaterialyRepo = StateObject(
            wrappedValue: GlobalneMaterialyProjektuRepository(
                projectID: project.id.description
            )
        )
    }

    var body: some View {
        content
            .stolarniaScreenSurface(
                .detail
            )
            .stolarniaReadableInterface()
            .navigationTitle(project.name)
            .toolbar {
                toolbarContent
            }
            .task {
                await roomViewModel.loadRooms()
                ensureActiveWorkflowRoom()
            }
            .onChange(
                of:
                    roomViewModel.rooms.map(\.id)
            ) {
                _,
                _ in

                ensureActiveWorkflowRoom()
            }
            .navigationDestination(
                item: $selectedRoomForMeasurements
            ) { room in
                measurementDestination(for: room)
            }
            .sheet(
                item: $activeSheet
            ) {
                sheet in

                activeSheetView(sheet)
            }
            .fullScreenCover(
                item: $roomForProject
            ) { room in
                ProjektWorkspaceView(
                    project: project,
                    room: room,
                    roomRepository:
                        roomRepository,
                    mebleRepositories:
                        mebleRepositories
                )
            }
            .confirmationDialog(
                "Usunąć pomieszczenie?",
                isPresented: Binding(
                    get: {
                        roomPendingDeletion != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            roomPendingDeletion = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let room = roomPendingDeletion {
                    Button(
                        "Usuń \"\(room.name)\"",
                        role: .destructive
                    ) {
                        Task {
                            await roomViewModel
                                .deleteRoom(id: room.id)
                        }
                        roomPendingDeletion = nil
                    }
                    Button("Anuluj", role: .cancel) {
                        roomPendingDeletion = nil
                    }
                }
            } message: {
                Text(
                    "Wszystkie pomiary i dane tego pomieszczenia zostaną trwale usunięte."
                )
            }
            .alert(
                "Nie udało się wykonać operacji",
                isPresented: roomErrorBinding
            ) {
                Button("OK", role: .cancel) {
                    roomViewModel.errorMessage = nil
                }
            } message: {
                Text(
                    roomViewModel.errorMessage
                    ?? "Nieznany błąd"
                )
            }
            .alert(
                "Nie udało się przygotować wyceny",
                isPresented: quoteErrorBinding
            ) {
                Button("OK", role: .cancel) {
                    quoteErrorMessage = nil
                }
            } message: {
                Text(
                    quoteErrorMessage
                    ?? "Nieznany błąd"
                )
            }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: ProjektSzczegolySheet
    ) -> some View {
        switch sheet {
        case .newRoom:
            newRoomSheet

        case .projectQuote:
            quoteSheet

        case .globalMaterialy:
            GlobalneMaterialyProjektuView(
                repository: globalMaterialyRepo
            )
        }
    }

    @ViewBuilder
    private func measurementDestination(
        for room: RoomDefinition
    ) -> some View {
        PomiaryPomieszczeniaView(
            context:
                measurementContext(
                    for: room
                ),
            room: room,
            onSaveRoom: {
                updatedRoom in

                let saved =
                    await roomViewModel
                        .saveRoom(
                            updatedRoom
                        )

                await MainActor.run {
                    withAnimation(
                        StolarniaAnimation.standard
                    ) {
                        showMeasurementsSavedToast =
                            true
                    }
                }

                Task {
                    try? await Task.sleep(
                        for: .seconds(1.8)
                    )
                    await MainActor.run {
                        withAnimation(
                            StolarniaAnimation.standard
                        ) {
                            showMeasurementsSavedToast =
                                false
                        }
                    }
                }

                return saved
            }
        )
        .overlay(alignment: .bottom) {
            if showMeasurementsSavedToast {
                StolarniaToast(
                    message:
                        "Pomiary zapisane",
                    systemImage:
                        "checkmark.circle.fill",
                    tone: .success
                )
                .padding(.bottom, 24)
                .transition(
                    .move(edge: .bottom)
                    .combined(with: .opacity)
                )
            }
        }
    }

    private var content: some View {
        List {
            workflowSection
            projectSummarySection
            globalMaterialySection
            roomsSection
            technicalInfoSection
        }
        .listStyle(.insetGrouped)
        .environment(\.colorScheme, .dark)
        .scrollContentBackground(.hidden)
        .background(
            StolarniaPalette.canvas
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var technicalInfoSection: some View {
        Section {
            Button {
                withAnimation(
                    StolarniaAnimation.standard
                ) {
                    showTechnicalInfo.toggle()
                }
            } label: {
                HStack {
                    Label(
                        "Informacje techniczne",
                        systemImage: "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Image(
                        systemName: showTechnicalInfo
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(detailRowBackground)
        }

        if showTechnicalInfo {
            revisionSection
            protectionSection
            stableIDSection
        }
    }

    @ViewBuilder
    private var workflowSection: some View {
        Section("Proces realizacji") {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack(
                    alignment: .top,
                    spacing: 12
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text("Pomiar -> projekt -> wycena")
                            .font(.title3.bold())

                        Text(workflowSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                    }

                    Spacer(minLength: 8)

                    if roomViewModel.rooms.count > 1 {
                        activeRoomMenu
                    } else if let room =
                        preferredWorkflowRoom {
                        Label(
                            room.name,
                            systemImage: "mappin.and.ellipse"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    ProjektProcesPillView(
                        number: 1,
                        title: "Pomiar",
                        systemImage: "ruler",
                        state: pomiarState
                    )

                    ProjektProcesPillView(
                        number: 2,
                        title: "Projekt",
                        systemImage: "square.grid.2x2",
                        state: projektState
                    )

                    ProjektProcesPillView(
                        number: 3,
                        title: "Wycena",
                        systemImage:
                            "chart.bar.doc.horizontal",
                        state: wycenaState
                    )
                }

                Divider()

                HStack(spacing: 10) {
                    workflowButtons
                }
            }
            .stolarniaFrostedCard(
                cornerRadius: 16,
                padding: 16
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var workflowButtons: some View {
        if let room =
            preferredWorkflowRoom
        {
            Button {
                selectedRoomForMeasurements = room
            } label: {
                workflowActionLabel(
                    "Pomiar",
                    systemImage: "ruler"
                )
            }
            .buttonStyle(
                StolarniaPrimaryButtonStyle(
                    minHeight: 46,
                    horizontalPadding: 12,
                    cornerRadius: 18
                )
            )

            Button {
                roomForProject = room
            } label: {
                workflowActionLabel(
                    "Projekt",
                    systemImage:
                        "square.grid.2x2"
                )
            }
            .buttonStyle(.bordered)

            Button {
                if projectQuote == nil {
                    startPreparingQuote()
                } else {
                    activeSheet =
                        .projectQuote
                }
            } label: {
                workflowActionLabel(
                    isLoadingProjectQuote
                    ? "Liczenie..."
                    : (
                        projectQuote == nil
                        ? "Wycena"
                        : "Otwórz"
                    ),
                    systemImage:
                        "chart.bar.doc.horizontal"
                )
            }
            .buttonStyle(.bordered)
            .disabled(
                roomViewModel.rooms.isEmpty
                || isLoadingProjectQuote
            )
        } else {
            Button {
                activeSheet =
                    .newRoom
            } label: {
                workflowActionLabel(
                    "Dodaj pomieszczenie",
                    systemImage: "plus"
                )
            }
            .buttonStyle(
                StolarniaPrimaryButtonStyle(
                    minHeight: 46,
                    horizontalPadding: 12,
                    cornerRadius: 18
                )
            )
        }
    }

    private func workflowActionLabel(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(
            title,
            systemImage: systemImage
        )
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 46)
    }

    private var preferredWorkflowRoom:
        RoomDefinition?
    {
        if let activeWorkflowRoomID,
           let room =
            roomViewModel.rooms.first(
                where: {
                    $0.id
                        == activeWorkflowRoomID
                }
            ) {
            return room
        }

        return roomViewModel.rooms.first
    }

    private var workflowSubtitle: String {
        if roomViewModel.rooms.isEmpty {
            return "Dodaj pomieszczenie i zacznij od realnego pomiaru."
        }
        if pomiarState == .complete && projektState == .ready {
            return "Pomiary gotowe. Przejdź do projektu zabudowy."
        }
        if projektState == .complete {
            return "Projekt gotowy. Wygeneruj wycenę dla klienta."
        }
        return "Wybierz pomieszczenie i przejdź kolejno przez pomiar, projekt i wycenę."
    }

    private var pomiarState: ProjektProcesKrokState {
        guard !roomViewModel.rooms.isEmpty else {
            return .blocked
        }
        let anyMeasured = roomViewModel.rooms.contains {
            $0.geometry.walls.count > 0
        }
        return anyMeasured ? .complete : .ready
    }

    private var projektState: ProjektProcesKrokState {
        guard pomiarState == .complete else {
            return roomViewModel.rooms.isEmpty ? .blocked : .ready
        }
        // We treat having a saved quote as evidence the project was designed.
        // Furniture assembly count isn't available synchronously here,
        // so we use the quote as a proxy for "project done".
        return projectQuote != nil ? .complete : .ready
    }

    private var wycenaState: ProjektProcesKrokState {
        guard !roomViewModel.rooms.isEmpty else {
            return .blocked
        }
        return projectQuote == nil ? .ready : .complete
    }

    @ViewBuilder
    private var activeRoomMenu: some View {
        Menu {
            ForEach(roomViewModel.rooms) { room in
                Menu {
                    Button {
                        selectedRoomForMeasurements = room
                    } label: {
                        Label("Pomiary", systemImage: "ruler")
                    }

                    Button {
                        roomForProject = room
                    } label: {
                        Label("Projekt", systemImage: "square.grid.2x2")
                    }

                    Divider()

                    Button {
                        activeWorkflowRoomID = room.id
                    } label: {
                        Label(
                            "Ustaw jako aktywne",
                            systemImage: isActiveWorkflowRoom(room)
                                ? "checkmark.circle.fill"
                                : "target"
                        )
                    }
                } label: {
                    Label(
                        room.name,
                        systemImage: isActiveWorkflowRoom(room)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }
        } label: {
            Label(
                preferredWorkflowRoom?.name
                ?? "Pomieszczenie",
                systemImage: "mappin.and.ellipse"
            )
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var projectSummarySection: some View {
        Section("Dane zlecenia") {
            LabeledContent(
                "Nazwa",
                value: project.name
            )

            LabeledContent(
                "Kod",
                value: project.code.rawValue
            )

            LabeledContent(
                "Status",
                value: project.status.displayName
            )

            LabeledContent(
                "Wariant wyceny",
                value:
                    project.selectedPricingTier
                        .displayName
            )

            LabeledContent(
                "Klient",
                value:
                    project.customer.displayName
            )
        }
        .listRowBackground(detailRowBackground)
    }

    // MARK: - Globalne materiały projektu

    @ViewBuilder
    private var globalMaterialySection: some View {
        let mat = globalMaterialyRepo.ustawienia

        Section("Globalne materiały") {
            Button {
                activeSheet = .globalMaterialy
            } label: {
                HStack(spacing: 12) {
                    // Podgląd kolorów korpus + front
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(stolarniaHEX: mat.korpus.kolorHEX))
                            .frame(width: 28, height: 28)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(.secondary.opacity(0.3))
                            }

                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(stolarniaHEX: mat.front.kolorHEX))
                            .frame(width: 28, height: 28)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(.secondary.opacity(0.3))
                            }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Korpus:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(mat.korpus.nazwa)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Text("Front:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(mat.front.nazwa)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }

                        if mat.systemSzuflad.jestWybrany {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.2")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(
                                    mat.systemSzuflad.seria.isEmpty
                                        ? mat.systemSzuflad.nazwa
                                        : "\(mat.systemSzuflad.producent) \(mat.systemSzuflad.seria)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(detailRowBackground)
    }

    @ViewBuilder
    private var roomsSection: some View {
        Section("Pomieszczenia") {
            if roomViewModel.isLoading
                && roomViewModel.rooms.isEmpty {
                ProgressView(
                    "Wczytywanie pomieszczeń…"
                )
            } else if roomViewModel.rooms.isEmpty {
                emptyRoomsView
            } else {
                roomRows
            }
        }
        .listRowBackground(detailRowBackground)
    }

    private var emptyRoomsView: some View {
        ContentUnavailableView {
            Label(
                "Brak pomieszczeń",
                systemImage: "square.dashed"
            )
        } description: {
            Text(
                "Dodaj pierwszy obrys pomieszczenia do projektu."
            )
        } actions: {
            Button("Dodaj pomieszczenie") {
                activeSheet =
                    .newRoom
            }
        }
    }

    @ViewBuilder
    private var roomRows: some View {
        ForEach(roomViewModel.rooms) { room in
            Button {
                selectedRoomForMeasurements = room
            } label: {
                roomRowLabel(room)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .accessibilityHint(
                "Otwiera pomiary pomieszczenia."
            )
            .swipeActions(edge: .leading) {
                Button {
                    roomForProject = room
                } label: {
                    Label(
                        "Projekt",
                        systemImage: "square.grid.2x2"
                    )
                }
                .tint(StolarniaPalette.graphite)
            }
            .swipeActions(
                edge: .trailing
            ) {
                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    roomPendingDeletion = room
                }
            }
            .contextMenu {
                Button {
                    selectedRoomForMeasurements = room
                } label: {
                    Label(
                        "Pomiary",
                        systemImage: "ruler"
                    )
                }

                Button {
                    roomForProject = room
                } label: {
                    Label(
                        "Projekt",
                        systemImage: "square.grid.2x2"
                    )
                }

                Divider()

                Button {
                    activeWorkflowRoomID =
                        room.id
                } label: {
                    Label(
                        "Ustaw jako aktywne",
                        systemImage: "target"
                    )
                }

                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    roomPendingDeletion = room
                }
            }
        }
    }

    private func roomRowLabel(
        _ room: RoomDefinition
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(
                    roomIsMeasured(room)
                    ? StolarniaPalette.accent.opacity(0.15)
                    : Color.white.opacity(0.06)
                )

                Image(
                    systemName: roomIsMeasured(room)
                        ? "ruler.fill"
                        : "ruler"
                )
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    roomIsMeasured(room)
                    ? StolarniaPalette.accentStrong
                    : Color.secondary
                )
            }
            .frame(width: 40, height: 40)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack(spacing: 8) {
                    Text(room.name)
                        .font(.headline)

                    if isActiveWorkflowRoom(room) {
                        StolarniaBadgeView(
                            text: "Aktywne",
                            tone: .accent
                        )
                    }
                }

                Text(roomSubtitle(room))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    private func roomIsMeasured(
        _ room: RoomDefinition
    ) -> Bool {
        room.geometry.walls.count > 0
    }

    private func isActiveWorkflowRoom(
        _ room: RoomDefinition
    ) -> Bool {
        preferredWorkflowRoom?.id
            == room.id
    }

    private func measurementContext(
        for room:
            RoomDefinition
    ) -> KontekstPomiaruPomieszczenia {
        KontekstPomiaruPomieszczenia(
            projectID:
                project.id.description,
            roomID:
                room.id.description,
            projectName:
                project.name,
            roomName:
                room.name,
            customerName:
                project.customer
                    .displayName
        )
    }

    private func roomSubtitle(
        _ room: RoomDefinition
    ) -> String {
        let walls =
            room.geometry.walls.count

        let perimeterMeters =
            room.geometry.boundary
                .perimeter.rawValue / 1_000.0

        let formattedPerimeter =
            perimeterMeters.formatted(
                .number.precision(
                    .fractionLength(1...2)
                )
            )

        return "\(walls) ściany • \(formattedPerimeter) m"
    }

    @ViewBuilder
    private var revisionSection: some View {
        Section("Rewizja") {
            LabeledContent(
                "Numer",
                value:
                    project.currentRevision
                        .number.code
            )

            LabeledContent(
                "Opis",
                value:
                    project.currentRevision
                        .summary
            )

            LabeledContent(
                "Zamrożony do produkcji",
                value:
                    project.isFrozenForProduction
                    ? "Tak"
                    : "Nie"
            )
        }
        .listRowBackground(detailRowBackground)
    }

    @ViewBuilder
    private var protectionSection: some View {
        Section("Ochrona projektu") {
            LabeledContent(
                "Widoczność",
                value:
                    project.protectionPolicy
                        .visibility.rawValue
            )

            LabeledContent(
                "Publikacja",
                value:
                    project.protectionPolicy
                        .allowsPublication
                    ? "Dozwolona"
                    : "Zablokowana"
            )

            LabeledContent(
                "Eksport szablonu",
                value:
                    project.protectionPolicy
                        .allowsTemplateExport
                    ? "Dozwolony"
                    : "Zablokowany"
            )
        }
        .listRowBackground(detailRowBackground)
    }

    @ViewBuilder
    private var stableIDSection: some View {
        Section("Stabilne ID") {
            Text(project.id.description)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .listRowBackground(detailRowBackground)
    }

    private var detailRowBackground: some View {
        RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )
        .fill(
            StolarniaPalette
                .canvasRaised
                .opacity(0.74)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                StolarniaPalette
                    .frostStroke,
                lineWidth: 0.8
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent:
        some ToolbarContent
    {
        if let onReturnToProjectList {
            ToolbarItem(
                placement: .topBarLeading
            ) {
                Button {
                    onReturnToProjectList()
                } label: {
                    Label(
                        "Klienci i projekty",
                        systemImage: "person.2"
                    )
                }
            }
        }

        ToolbarItemGroup(
            placement: .primaryAction
        ) {
            Button {
                activeSheet =
                    .newRoom
            } label: {
                Label(
                    "Nowe pomieszczenie",
                    systemImage: "plus"
                )
            }
        }
    }

    private var newRoomSheet: some View {
        WyborTrybuNowegoPomieszczeniaView(
            projectID: project.id,
            onCreateRectangle: {
                name,
                width,
                depth,
                wallHeight,
                wallThickness,
                constructionType in

                await roomViewModel
                    .createRectangularRoom(
                        name: name,
                        width: width,
                        depth: depth,
                        wallHeight:
                            wallHeight,
                        wallThickness:
                            wallThickness,
                        constructionType:
                            constructionType
                    )
            },
            onSaveSurveyedRoom: { room in
                await roomViewModel
                    .saveRoom(room)
            }
        )
    }

    @ViewBuilder
    private var quoteSheet: some View {
        if let quote = projectQuote {
            WycenaWariantowaView(projekt: quote)
        } else {
            ProgressView(
                "Przygotowywanie wyceny…"
            )
        }
    }

    private var roomErrorBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                roomViewModel
                    .errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    roomViewModel
                        .errorMessage = nil
                }
            }
        )
    }

    private var quoteErrorBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                quoteErrorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    quoteErrorMessage = nil
                }
            }
        )
    }

    private func startPreparingQuote() {
        Task {
            await prepareProjectQuote()
        }
    }

    private func ensureActiveWorkflowRoom() {
        guard !roomViewModel.rooms.isEmpty
        else {
            activeWorkflowRoomID = nil
            return
        }

        if let activeWorkflowRoomID,
           roomViewModel.rooms.contains(
               where: {
                   $0.id
                       == activeWorkflowRoomID
               }
           ) {
            return
        }

        activeWorkflowRoomID =
            roomViewModel.rooms.first?.id
    }

    @MainActor
    private func prepareProjectQuote() async {
        guard !isLoadingProjectQuote else {
            return
        }

        isLoadingProjectQuote = true
        quoteErrorMessage = nil

        defer {
            isLoadingProjectQuote = false
        }

        do {
            let assemblies =
                try await loadAllAssemblies()

            let materialyPomieszczen =
                Dictionary(
                    uniqueKeysWithValues:
                        roomViewModel
                            .rooms
                            .map { room in
                                let roomID =
                                    room.id
                                        .description
                                let repository =
                                    GlobalneMaterialyPomieszczeniaRepository(
                                        roomID:
                                            roomID
                                    )

                                return (
                                    roomID,
                                    repository
                                        .ustawienia
                                )
                            }
                )

            let generatedQuote =
                ProjektWycenyBuilder.zbuduj(
                    nazwaProjektu:
                        project.name,
                    assemblies:
                        assemblies,
                    materialyPomieszczen:
                        materialyPomieszczen
                )

            projectQuote = generatedQuote

            activeSheet =
                .projectQuote
        } catch {
            quoteErrorMessage =
                error.localizedDescription
        }
    }

    private func loadAllAssemblies()
        async throws
        -> [FurnitureAssembly]
    {
        var result:
            [FurnitureAssembly] = []

        for room in roomViewModel.rooms {
            let stored =
                try await mebleRepositories
                    .assemblyRepository
                    .fetchAll(
                        roomID: room.id
                    )

            result.append(
                contentsOf:
                    stored.map(\.assembly)
            )
        }

        return result
    }

    private func formattedMillimeters(
        _ value: Millimeters
    ) -> String {
        let formatted =
            value.rawValue.formatted(
                .number.precision(
                    .fractionLength(0...1)
                )
            )

        return "\(formatted) mm"
    }

    private func formattedMeters(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...2)
            )
        )
        + " mb"
    }
}

private enum ProjektProcesKrokState: Equatable {
    case blocked
    case ready
    case complete

    var label: String {
        switch self {
        case .blocked:
            return "Czeka"
        case .ready:
            return "Gotowe"
        case .complete:
            return "Zrobione"
        }
    }

    var color: Color {
        switch self {
        case .blocked:
            return .secondary
        case .ready:
            return StolarniaPalette.accentStrong
        case .complete:
            return .green
        }
    }
}

private struct ProjektProcesPillView: View {
    let number: Int
    let title: String
    let systemImage: String
    let state: ProjektProcesKrokState

    var body: some View {
        HStack(
            spacing: 7
        ) {
            Text("\(number)")
                .font(
                    .caption
                        .weight(.bold)
                )
                .foregroundStyle(
                    state.color
                )
                .frame(
                    width: 22,
                    height: 22
                )
                .background(
                    Circle()
                        .fill(
                            state.color
                                .opacity(0.15)
                        )
                )

            Label(
                title,
                systemImage:
                    systemImage
            )
            .font(
                .caption
                    .weight(.semibold)
            )
            .foregroundStyle(
                state.color
            )
            .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(
                    state.color
                        .opacity(0.10)
                )
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            "\(number). \(title), \(state.label)"
        )
    }
}
