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

                workflowButtons
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
        VStack(alignment: .leading, spacing: 10) {
            StolarniaNextStepStrip(
                title: workflowPrimaryTitle,
                description: workflowPrimaryDescription,
                status: workflowPrimaryStatus,
                actionTitle: workflowPrimaryActionTitle,
                actionSystemImage:
                    workflowPrimaryActionSystemImage,
                action: performPrimaryWorkflowAction
            )

            HStack(spacing: 10) {
                workflowSecondaryActionsMenu

                Spacer(minLength: 0)
            }
        }
    }

    private var workflowSecondaryActionsMenu: some View {
        Menu {
            if let room =
                preferredWorkflowRoom
            {
                Button {
                    openMeasurements(
                        for: room
                    )
                } label: {
                    Label(
                        "Otwórz pomiary",
                        systemImage: "ruler"
                    )
                }

                Button {
                    openProject(
                        for: room
                    )
                } label: {
                    Label(
                        "Otwórz projekt zabudowy",
                        systemImage:
                            "square.grid.2x2"
                    )
                }

                Divider()
            }

            Button {
                openQuoteOrPrepare()
            } label: {
                Label(
                    projectQuote == nil
                    ? "Przygotuj wycenę"
                    : "Otwórz wycenę",
                    systemImage:
                        "chart.bar.doc.horizontal"
                )
            }
            .disabled(
                roomViewModel.rooms.isEmpty
                || isLoadingProjectQuote
            )

            Button {
                activeSheet =
                    .globalMaterialy
            } label: {
                Label(
                    "Materiały projektu",
                    systemImage: "swatchpalette"
                )
            }

            Divider()

            Button {
                activeSheet =
                    .newRoom
            } label: {
                Label(
                    "Dodaj pomieszczenie",
                    systemImage: "plus"
                )
            }
        } label: {
            Label(
                "Więcej",
                systemImage: "ellipsis.circle"
            )
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
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

    private var workflowPrimaryTitle: String {
        if isLoadingProjectQuote {
            return "Liczymy wycenę"
        }

        guard let room =
            preferredWorkflowRoom
        else {
            return "Dodaj pierwsze pomieszczenie"
        }

        if !roomIsMeasured(room) {
            return "Zacznij od pomiaru"
        }

        if projectQuote == nil {
            return "Projektuj zabudowę"
        }

        return "Oferta gotowa do sprawdzenia"
    }

    private var workflowPrimaryDescription: String {
        if isLoadingProjectQuote {
            return "Zbieramy moduły, materiały i elementy produkcyjne do jednej wyceny."
        }

        guard let room =
            preferredWorkflowRoom
        else {
            return "Najpierw powstaje obrys pomieszczenia, potem układ mebli i wycena."
        }

        if !roomIsMeasured(room) {
            return "\(room.name): zapisz ściany, wysokości i najważniejsze punkty montażowe."
        }

        if projectQuote == nil {
            return "\(room.name): ustaw ciągi, moduły, fronty i elementy wspólne."
        }

        return "Sprawdź warianty, podsumowanie zakresu i dokument dla klienta."
    }

    private var workflowPrimaryStatus:
        StolarniaReadinessStatus
    {
        if roomViewModel.rooms.isEmpty {
            return .blocked
        }

        if let room = preferredWorkflowRoom,
           !roomIsMeasured(room) {
            return .warning
        }

        return .ready
    }

    private var workflowPrimaryActionTitle: String {
        if isLoadingProjectQuote {
            return "Liczenie..."
        }

        guard let room =
            preferredWorkflowRoom
        else {
            return "Dodaj pomieszczenie"
        }

        if !roomIsMeasured(room) {
            return "Otwórz pomiar"
        }

        if projectQuote == nil {
            return "Projektuj"
        }

        return "Otwórz wycenę"
    }

    private var workflowPrimaryActionSystemImage: String {
        if preferredWorkflowRoom == nil {
            return "plus"
        }

        if isLoadingProjectQuote {
            return "hourglass"
        }

        if let room = preferredWorkflowRoom,
           !roomIsMeasured(room) {
            return "ruler"
        }

        if projectQuote == nil {
            return "square.grid.2x2"
        }

        return "chart.bar.doc.horizontal"
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
                Button {
                    activeWorkflowRoomID =
                        room.id
                } label: {
                    Label(
                        room.name,
                        systemImage: isActiveWorkflowRoom(room)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }

            Divider()

            Button {
                activeSheet =
                    .newRoom
            } label: {
                Label(
                    "Dodaj pomieszczenie",
                    systemImage: "plus"
                )
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
            HStack(spacing: 10) {
                Button {
                    activeWorkflowRoomID =
                        room.id
                } label: {
                    roomRowLabel(room)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityHint(
                    "Ustawia pomieszczenie jako aktywne w procesie."
                )
                .stolarniaPressable()

                akcjePomieszczeniaV0107(room)
            }
            .padding(.vertical, 4)
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
                    activeWorkflowRoomID =
                        room.id
                } label: {
                    Label(
                        "Ustaw jako aktywne",
                        systemImage: "target"
                    )
                }

                Button {
                    openMeasurements(
                        for: room
                    )
                } label: {
                    Label(
                        "Pomiary",
                        systemImage: "ruler"
                    )
                }

                Button {
                    openProject(
                        for: room
                    )
                } label: {
                    Label(
                        "Projekt",
                        systemImage: "square.grid.2x2"
                    )
                }

                Divider()

                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    roomPendingDeletion = room
                }
            }
        }
    }

    /// Dwie realne akcje pomieszczenia **widoczne w wierszu**.
    ///
    /// Wcześniej `Pomiary` i `Projekt` istniały wyłącznie w menu
    /// kontekstowym, czyli pod przytrzymaniem palca. Stuknięcie wiersza
    /// ustawiało pomieszczenie jako aktywne i **na tym się kończyło** —
    /// żeby cokolwiek w nim zrobić, trzeba było wiedzieć o geście, którego
    /// nic nie zapowiada. Reguła projektu mówi wprost: ważna akcja ma być
    /// widoczna, a ikona zawsze z podpisem.
    ///
    /// Menu kontekstowe zostaje jako droga na skróty dla tych, którzy je
    /// znają — nie jest już jednak jedyną drogą.
    private func akcjePomieszczeniaV0107(
        _ room: RoomDefinition
    ) -> some View {
        HStack(spacing: 8) {
            przyciskPomieszczeniaV0107(
                "Pomiar",
                ikona: "ruler",
                wyrozniony: !roomIsMeasured(room)
            ) {
                openMeasurements(for: room)
            }

            przyciskPomieszczeniaV0107(
                "Projekt",
                ikona: "square.grid.2x2",
                wyrozniony: roomIsMeasured(room)
            ) {
                openProject(for: room)
            }
        }
    }

    /// Wyróżniony jest **następny sensowny krok** dla tego pomieszczenia:
    /// niezmierzone woła o pomiar, zmierzone o projekt. Oba przyciski
    /// zostają aktywne — do pomiarów wraca się przy każdej korekcie na
    /// budowie, a nie tylko raz na początku.
    private func przyciskPomieszczeniaV0107(
        _ tytul: String,
        ikona: String,
        wyrozniony: Bool,
        akcja: @escaping () -> Void
    ) -> some View {
        Button(action: akcja) {
            Label(tytul, systemImage: ikona)
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                    .fill(
                        wyrozniony
                        ? StolarniaPalette.accent.opacity(0.16)
                        : StolarniaPalette.canvasInset
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                    .stroke(
                        wyrozniony
                        ? StolarniaPalette.accent.opacity(0.55)
                        : Color.secondary.opacity(0.22),
                        lineWidth: 1
                    )
                }
                .foregroundStyle(
                    wyrozniony
                    ? StolarniaPalette.accent
                    : Color.primary
                )
        }
        .buttonStyle(.plain)
        .stolarniaPressable()
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

            Image(
                systemName: isActiveWorkflowRoom(room)
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .font(.body.weight(.semibold))
            .foregroundStyle(
                isActiveWorkflowRoom(room)
                    ? StolarniaPalette.accentStrong
                    : Color.secondary.opacity(0.45)
            )
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

    private func performPrimaryWorkflowAction() {
        guard !isLoadingProjectQuote else {
            return
        }

        guard let room =
            preferredWorkflowRoom
        else {
            activeSheet =
                .newRoom
            return
        }

        if !roomIsMeasured(room) {
            openMeasurements(
                for: room
            )
            return
        }

        if projectQuote == nil {
            openProject(
                for: room
            )
            return
        }

        activeSheet =
            .projectQuote
    }

    private func openMeasurements(
        for room: RoomDefinition
    ) {
        activeWorkflowRoomID =
            room.id
        selectedRoomForMeasurements =
            room
    }

    private func openProject(
        for room: RoomDefinition
    ) {
        activeWorkflowRoomID =
            room.id
        roomForProject =
            room
    }

    private func openQuoteOrPrepare() {
        if projectQuote == nil {
            startPreparingQuote()
        } else {
            activeSheet =
                .projectQuote
        }
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
            return "Dalej"
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
