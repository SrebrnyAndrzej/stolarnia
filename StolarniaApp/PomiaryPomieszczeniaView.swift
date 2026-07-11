import DomainCore
import SwiftUI

private enum PomiaryPomieszczeniaSheet:
    Identifiable
{
    case photoDocumentation
    case report(GeneratedMeasurementReport)

    var id: String {
        switch self {
        case .photoDocumentation:
            return "photo-documentation"

        case .report(let report):
            return "report-\(report.id)"
        }
    }
}

struct PomiaryPomieszczeniaView:
    View
{
    let context:
        KontekstPomiaruPomieszczenia

    private let onSaveRoom:
        (RoomDefinition) async -> Bool

    @State private var workingRoom:
        RoomDefinition

    init(
        context:
            KontekstPomiaruPomieszczenia,
        room:
            RoomDefinition,
        onSaveRoom:
            @escaping (RoomDefinition) async -> Bool
    ) {
        self.context = context
        self.onSaveRoom =
            onSaveRoom
        self._workingRoom =
            State(
                initialValue: room
            )
    }

    @StateObject private var slopeRepository =
        PomiarGarderobySkosyRepository()

    @StateObject private var unusualRepository =
        PomiaryNietypoweRepository()

    @State private var route:
        MeasurementRoute?

    @State private var showingNewMeasurement =
        false

    @State private var showingDeleteConfirmation =
        false

    @State private var pendingDelete:
        DeleteTarget?

    @State private var activeSheet:
        PomiaryPomieszczeniaSheet?

    @StateObject private var photoRepository =
        ZdjeciaPomiaroweRepository()

    @State private var isGeneratingReport =
        false

    @State private var reportErrorMessage:
        String?

    private var slopeMeasurements:
        [PomiarGarderobySkosy]
    {
        slopeRepository.measurements(
            projectID:
                context.projectID,
            roomID:
                context.roomID
        )
    }

    private var unusualMeasurements:
        [PomiarNietypowy]
    {
        unusualRepository.measurements(
            projectID:
                context.projectID,
            roomID:
                context.roomID
        )
    }

    private var totalCount: Int {
        slopeMeasurements.count
        + unusualMeasurements.count
    }

    private var roomPhotos:
        [ZdjeciePomiarowe]
    {
        photoRepository.photos(
            projectID:
                context.projectID,
            roomID:
                context.roomID
        )
    }

    var body: some View {
        List {
            Section {
                StolarniaSectionIntro(
                    title:
                        "Pomiary: \(context.roomName)",
                    description:
                        "Wszystkie pomiary są przypisane do projektu „\(context.projectName)” i tego pomieszczenia.",
                    systemImage:
                        "ruler.fill"
                )
                .listRowInsets(
                    EdgeInsets()
                )
                .listRowBackground(
                    Color.clear
                )
            }

            Section {
                measurementCompletenessCard
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
            }

            Section("Podsumowanie") {
                LabeledContent(
                    "Status pomiaru",
                    value:
                        measurementStatus.nazwa
                )

                LabeledContent(
                    "Ściany obrysu",
                    value:
                        String(
                            workingRoom
                                .geometry
                                .walls
                                .count
                        )
                )

                LabeledContent(
                    "Liczba pomiarów",
                    value:
                        String(totalCount)
                )

                LabeledContent(
                    "Kompletne",
                    value:
                        String(
                            completedCount
                        )
                )

                LabeledContent(
                    "Do uzupełnienia",
                    value:
                        String(
                            incompleteCount
                        )
                )

                LabeledContent(
                    "Zdjęcia terenowe",
                    value:
                        String(roomPhotos.count)
                )
            }

            Section("Dokumentacja terenowa") {
                Button {
                    activeSheet =
                        .photoDocumentation
                } label: {
                    HStack(spacing: 14) {
                        Image(
                            systemName:
                                "camera.fill"
                        )
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(
                            width: 34,
                            height: 34
                        )

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(
                                "Zdjęcia pomieszczenia"
                            )
                            .font(.headline)

                            Text(
                                "Widoki ogólne, narożniki, instalacje i przeszkody"
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(.plain)
            }

            slopeSectionView

            Section("Pomiary dodatkowe") {
                if unusualMeasurements.isEmpty {
                    Text("Brak pomiarów dodatkowych.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    unusualRows
                }
            }
        }
        .navigationTitle(
            "Pomiary pomieszczenia"
        )
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .toolbar {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    generateReport()
                } label: {
                    Label(
                        isGeneratingReport
                        ? "Tworzenie PDF…"
                        : "Raport PDF",
                        systemImage:
                            "doc.richtext"
                    )
                }
                .disabled(
                    isGeneratingReport
                )

                Button {
                    showingNewMeasurement =
                        true
                } label: {
                    Label(
                        "Dodaj pomiar",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(
                    StolarniaPrimaryButtonStyle(
                        minHeight: 44,
                        horizontalPadding: 14,
                        cornerRadius: 12
                    )
                )
            }
        }
        .confirmationDialog(
            "Wybierz rodzaj pomiaru",
            isPresented:
                $showingNewMeasurement,
            titleVisibility:
                .visible
        ) {
            Button(
                "Pomiar po obrysie"
            ) {
                route = .outlineSurvey
            }

            ForEach(
                TypPomiaruNietypowego
                    .allCases
            ) { type in
                Button(type.nazwa) {
                    createUnusualMeasurement(
                        type
                    )
                }
            }

            Button(
                "Anuluj",
                role: .cancel
            ) {}
        } message: {
            Text(
                "Nowy pomiar zostanie automatycznie przypisany do pomieszczenia \(context.roomName)."
            )
        }
        .navigationDestination(
            item: $route
        ) { destination in
            destinationView(
                destination
            )
        }
        .sheet(
            item: $activeSheet
        ) {
            sheet in

            activeSheetView(sheet)
        }
        .alert(
            "Nie udało się wygenerować raportu",
            isPresented:
                Binding(
                    get: {
                        reportErrorMessage
                            != nil
                    },
                    set: { visible in
                        if !visible {
                            reportErrorMessage =
                                nil
                        }
                    }
                )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                reportErrorMessage = nil
            }
        } message: {
            Text(
                reportErrorMessage
                ?? "Nieznany błąd"
            )
        }
        .alert(
            "Usunąć pomiar?",
            isPresented:
                $showingDeleteConfirmation
        ) {
            Button(
                "Usuń",
                role: .destructive
            ) {
                performDelete()
            }

            Button(
                "Anuluj",
                role: .cancel
            ) {
                pendingDelete = nil
            }
        } message: {
            Text(
                "Tej operacji nie można cofnąć."
            )
        }
        .onAppear {
            reload()
        }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: PomiaryPomieszczeniaSheet
    ) -> some View {
        switch sheet {
        case .photoDocumentation:
            NavigationStack {
                DokumentacjaZdjęciowaPomieszczeniaView(
                    context: context
                )
                .toolbar {
                    ToolbarItem(
                        placement:
                            .cancellationAction
                    ) {
                        Button("Zamknij") {
                            activeSheet = nil
                        }
                    }
                }
            }

        case .report(let report):
            RaportPomiarowyShareView(
                fileURL:
                    report.fileURL
            )
        }
    }

    @ViewBuilder
    private var slopeSectionView: some View {
        Section {
            if slopeMeasurements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "triangle.righthalf.filled")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Brak skosu")
                                .font(.headline)
                            Text("Pomieszczenie nie ma zdefiniowanego skosu.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        createSlopeMeasurement()
                    } label: {
                        Label("Dodaj skos", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        StolarniaPrimaryButtonStyle(
                            minHeight: 44,
                            horizontalPadding: 14,
                            cornerRadius: 12
                        )
                    )
                }
                .padding(.vertical, 8)
            } else {
                slopeRows
            }
        } header: {
            Text("Skos pomieszczenia")
        } footer: {
            if !slopeMeasurements.isEmpty {
                Text("Kliknij wpis aby edytować kąt, profil i przypisanie do ściany.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var slopeRows:
        some View
    {
        ForEach(
            slopeMeasurements
        ) { measurement in
            Button {
                route = .slope(measurement.id)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "triangle.righthalf.filled")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(measurement.nazwaPomieszczenia)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Profil skosu ściany")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Label(
                        measurement.status.nazwa,
                        systemImage: measurement.status.systemImage
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        measurement.status == .kompletny ? .green : .orange
                    )
                    .labelStyle(.titleAndIcon)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions {
                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    pendingDelete = .slope(measurement.id)
                    showingDeleteConfirmation = true
                }
            }
        }
    }

    @ViewBuilder
    private var unusualRows:
        some View
    {
        ForEach(
            unusualMeasurements
        ) { measurement in
            measurementRow(
                title:
                    measurement.nazwa,
                subtitle:
                    measurement.typ.nazwa,
                status:
                    measurement.status,
                systemImage:
                    measurement.typ
                        .systemImage
            )
            .contentShape(Rectangle())
            .onTapGesture {
                route =
                    .unusual(
                        measurement
                    )
            }
            .swipeActions {
                Button(
                    "Usuń",
                    role: .destructive
                ) {
                    pendingDelete =
                        .unusual(
                            measurement.id
                        )
                    showingDeleteConfirmation =
                        true
                }
            }
        }
    }

    private func measurementRow(
        title: String,
        subtitle: String,
        status:
            StatusPomiaruPomieszczenia,
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(
                systemName:
                    systemImage
            )
            .font(.title3)
            .foregroundStyle(.tint)
            .frame(
                width: 34,
                height: 34
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            Label(
                status.nazwa,
                systemImage:
                    status.systemImage
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                statusColor(status)
            )

            Image(
                systemName:
                    "chevron.right"
            )
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(.vertical, 6)
    }

    private var measurementCompletenessCard:
        some View
    {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Label(
                    "Kompletność pomiaru",
                    systemImage:
                        measurementStatus.systemImage
                )
                .font(.headline)
                .foregroundStyle(
                    statusColor(
                        measurementStatus
                    )
                )

                Spacer()

                Text(
                    measurementProgress
                        .formatted(
                            .percent
                                .precision(
                                    .fractionLength(0)
                                )
                        )
                )
                .font(
                    .headline
                        .monospacedDigit()
                )
            }

            ProgressView(
                value:
                    measurementProgress
            )
            .tint(
                statusColor(
                    measurementStatus
                )
            )

            VStack(spacing: 10) {
                ForEach(
                    measurementChecklist
                ) { item in
                    measurementChecklistRow(
                        item
                    )
                }
            }
        }
        .stolarniaFrostedCard(
            cornerRadius: 18,
            padding: 16
        )
    }

    private func measurementChecklistRow(
        _ item:
            MeasurementChecklistItem
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(
                systemName:
                    item.state.systemImage
            )
            .font(.headline)
            .foregroundStyle(
                item.state.color
            )
            .frame(width: 24)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func destinationView(
        _ destination:
            MeasurementRoute
    ) -> some View {
        switch destination {
        case .outlineSurvey:
            ProwadzonyPomiarPomieszczeniaView(
                projectID:
                    workingRoom.projectID,
                roomID:
                    workingRoom.id,
                onSave: {
                    room in

                    let saved =
                        await onSaveRoom(
                            room
                        )

                    if saved {
                        await MainActor.run {
                            workingRoom =
                                room
                        }
                    }

                    return saved
                }
            )
            .onDisappear {
                reload()
            }

        case .slope(let id):
            PomiarGarderobySkosyView(
                context: context,
                initialMeasurementID:
                    id,
                room:
                    workingRoom,
                onSaveRoom: {
                    updatedRoom in

                    let saved =
                        await onSaveRoom(
                            updatedRoom
                        )

                    if saved {
                        await MainActor.run {
                            workingRoom =
                                updatedRoom
                        }
                    }

                    return saved
                }
            )
            .onDisappear {
                reload()
            }

        case .unusual(let measurement):
            PomiarNietypowyEditorView(
                type:
                    measurement.typ,
                context: context,
                existingMeasurement:
                    measurement
            )
            .onDisappear {
                reload()
            }
        }
    }

    private var measurementChecklist:
        [MeasurementChecklistItem]
    {
        let walls =
            workingRoom
                .geometry
                .walls
        let wallCount =
            walls.count
        let geometryState:
            MeasurementChecklistState =
            wallCount >= 3
            ? .complete
            : .missing

        let hasInvalidWallDimension =
            walls.contains {
                $0.thickness <= .zero
                || $0.startHeight <= .zero
                || $0.endHeight <= .zero
            }
        let hasUnknownConstruction =
            walls.contains {
                $0.constructionType == .unknown
            }
        let wallDataState:
            MeasurementChecklistState =
            hasInvalidWallDimension
            ? .missing
            : hasUnknownConstruction
                ? .attention
                : .complete

        let featureCount =
            roomFeatureCount
        let featureState:
            MeasurementChecklistState =
            featureCount > 0
            ? .complete
            : .attention

        let photoState:
            MeasurementChecklistState
        if roomPhotos.isEmpty {
            photoState = .missing
        } else if hasCorePhotoSet {
            photoState = .complete
        } else {
            photoState = .attention
        }

        let additionalMeasurementsState:
            MeasurementChecklistState
        if totalCount == 0 {
            additionalMeasurementsState = .attention
        } else if incompleteCount > 0 {
            additionalMeasurementsState = .missing
        } else {
            additionalMeasurementsState = .complete
        }

        return [
            MeasurementChecklistItem(
                id: "outline",
                title: "Obrys pomieszczenia",
                detail:
                    wallCount >= 3
                    ? "\(wallCount) ścian w zamkniętym obrysie."
                    : "Dodaj pomiar po obrysie albo szybki prostokąt.",
                state: geometryState
            ),
            MeasurementChecklistItem(
                id: "walls",
                title: "Wysokości, grubości i konstrukcja",
                detail:
                    wallDataDetail(
                        walls: walls,
                        hasUnknownConstruction:
                            hasUnknownConstruction
                    ),
                state: wallDataState
            ),
            MeasurementChecklistItem(
                id: "features",
                title: "Otwory, wnęki i przeszkody",
                detail:
                    featureCount > 0
                    ? "\(featureCount) elementów ścian zapisanych w pokoju."
                    : "Jeśli pokój ma okna, drzwi, piony albo słupy, dodaj je do ścian.",
                state: featureState
            ),
            MeasurementChecklistItem(
                id: "photos",
                title: "Zdjęcia terenowe",
                detail:
                    photoChecklistDetail,
                state: photoState
            ),
            MeasurementChecklistItem(
                id: "extra",
                title: "Skosy i pomiary nietypowe",
                detail:
                    additionalMeasurementsDetail,
                state: additionalMeasurementsState
            )
        ]
    }

    private var measurementProgress:
        Double
    {
        let checklist =
            measurementChecklist
        guard !checklist.isEmpty else {
            return 0
        }

        let score =
            checklist
                .map(\.state.score)
                .reduce(0, +)

        return score / Double(checklist.count)
    }

    private var measurementStatus:
        StatusPomiaruPomieszczenia
    {
        let states =
            measurementChecklist
                .map(\.state)

        if states.contains(.missing) {
            return .wymagaUzupełnienia
        }

        if states.contains(.attention) {
            return .rozpoczęty
        }

        return .kompletny
    }

    private var roomFeatureCount:
        Int
    {
        workingRoom.windows.count
        + workingRoom.doors.count
        + workingRoom.recesses.count
        + workingRoom.obstacles.count
        + workingRoom.bayProjections.count
    }

    private var hasCorePhotoSet:
        Bool
    {
        let categories =
            roomPhotos.map(\.category)
        let hasOverview =
            categories.contains(.widokOgólny)
        let hasCorner =
            categories.contains(.lewyNarożnik)
            || categories.contains(.prawyNarożnik)

        return roomPhotos.count >= 3
            && hasOverview
            && hasCorner
    }

    private var photoChecklistDetail:
        String
    {
        if roomPhotos.isEmpty {
            return "Dodaj minimum widok ogólny, narożnik i instalacje/przeszkody."
        }

        if hasCorePhotoSet {
            return "\(roomPhotos.count) zdjęć, w tym widok ogólny i narożnik."
        }

        return "\(roomPhotos.count) zdjęć. Uzupełnij widok ogólny oraz przynajmniej jeden narożnik."
    }

    private var additionalMeasurementsDetail:
        String
    {
        if totalCount == 0 {
            return "Brak skosów i pomiarów nietypowych. To OK tylko dla prostego pomieszczenia."
        }

        if incompleteCount == 0 {
            return "\(totalCount) pomiarów dodatkowych oznaczonych jako kompletne."
        }

        return "\(incompleteCount) z \(totalCount) pomiarów wymaga uzupełnienia."
    }

    private func wallDataDetail(
        walls:
            [WallSegment],
        hasUnknownConstruction:
            Bool
    ) -> String {
        guard let firstWall =
                walls.first
        else {
            return "Brak ścian do sprawdzenia."
        }

        let height =
            max(
                firstWall.startHeight,
                firstWall.endHeight
            )
            .rawValue
            .formatted(
                .number
                    .precision(
                        .fractionLength(0)
                    )
            )
        let thickness =
            firstWall
                .thickness
                .rawValue
                .formatted(
                    .number
                        .precision(
                            .fractionLength(0)
                        )
                )

        if hasUnknownConstruction {
            return "Wymiary są zapisane, ale część ścian ma nieustaloną konstrukcję."
        }

        return "Bazowo \(height) mm wysokości i \(thickness) mm grubości."
    }

    private var completedCount: Int {
        slopeMeasurements.filter {
            $0.status == .kompletny
        }.count
        + unusualMeasurements.filter {
            $0.status == .kompletny
        }.count
    }

    private var incompleteCount: Int {
        totalCount - completedCount
    }

    private func createSlopeMeasurement() {
        var measurement =
            slopeRepository.addNew(
                context: context
            )

        if let wall =
                workingRoom
                    .geometry
                    .walls
                    .first,
           let geometry =
                workingRoom
                    .geometry
                    .geometry(
                        of: wall.id
                    ) {
            measurement
                .wallIDRawValueV069 =
                    wall.id.description
            measurement
                .wallNameV069 =
                    wall.name
            measurement
                .szerokoscScianyMM =
                    geometry.length.rawValue
            measurement
                .wysokoscMaksymalnaMM =
                    max(
                        wall.startHeight,
                        wall.endHeight
                    )
                    .rawValue
            measurement
                .punktySkosu =
                    SilnikSkosuPomieszczeniaV069
                        .przygotujProfilDwupunktowy(
                            szerokoscScianyMM:
                                geometry.length
                                    .rawValue,
                            wysokoscMaksymalnaMM:
                                measurement
                                    .wysokoscMaksymalnaMM,
                            wysokoscNiskaMM:
                                measurement
                                    .wysokoscSciankiKolankowejMM,
                            strona:
                                measurement
                                    .stronaSkosu
                        )

            slopeRepository
                .upsert(measurement)
        }

        route =
            .slope(
                measurement.id
            )
    }

    private func createUnusualMeasurement(
        _ type:
            TypPomiaruNietypowego
    ) {
        let measurement =
            unusualRepository.add(
                type: type,
                context: context
            )

        route =
            .unusual(
                measurement
            )
    }

    private func performDelete() {
        guard let pendingDelete else {
            return
        }

        switch pendingDelete {
        case .slope(let id):
            slopeRepository.delete(
                id: id
            )

            Task {
                do {
                    let updatedRoom =
                        try SilnikSkosuPomieszczeniaV069
                            .usunProfil(
                                measurementID: id,
                                z: workingRoom
                            )

                    guard updatedRoom
                            != workingRoom
                    else {
                        return
                    }

                    let saved =
                        await onSaveRoom(
                            updatedRoom
                        )

                    if saved {
                        await MainActor.run {
                            workingRoom =
                                updatedRoom
                        }
                    }
                } catch {
                    await MainActor.run {
                        reportErrorMessage =
                            error
                                .localizedDescription
                    }
                }
            }

        case .unusual(let id):
            unusualRepository.delete(
                id: id
            )
        }

        self.pendingDelete = nil
        reload()
    }

    private func generateReport() {
        guard !isGeneratingReport
        else {
            return
        }

        isGeneratingReport = true
        reportErrorMessage = nil

        do {
            photoRepository.reload()

            let fileURL =
                try RaportPomiarowyPDFBuilder
                    .build(
                        context: context,
                        slopeMeasurements:
                            slopeMeasurements,
                        unusualMeasurements:
                            unusualMeasurements,
                        photos:
                            photoRepository
                                .photos(
                                    projectID:
                                        context
                                            .projectID,
                                    roomID:
                                        context
                                            .roomID
                                ),
                        photoRepository:
                            photoRepository
                    )

            activeSheet =
                .report(
                    GeneratedMeasurementReport(
                        fileURL: fileURL
                    )
                )
        } catch {
            reportErrorMessage =
                error.localizedDescription
        }

        isGeneratingReport = false
    }

    private func reload() {
        slopeRepository.reload()
        unusualRepository.reload()
        photoRepository.reload()
    }

    private func statusColor(
        _ status:
            StatusPomiaruPomieszczenia
    ) -> Color {
        switch status {
        case .rozpoczęty:
            return .secondary
        case .wymagaUzupełnienia:
            return .orange
        case .kompletny:
            return .green
        }
    }
}

private enum MeasurementRoute:
    Identifiable,
    Hashable
{
    case outlineSurvey
    case slope(UUID)
    case unusual(PomiarNietypowy)

    var id: String {
        switch self {
        case .outlineSurvey:
            return "outline-survey"
        case .slope(let id):
            return "slope.\(id.uuidString)"
        case .unusual(let measurement):
            return "unusual.\(measurement.id.uuidString)"
        }
    }
}

private enum DeleteTarget {
    case slope(UUID)
    case unusual(UUID)
}


private struct GeneratedMeasurementReport:
    Identifiable
{
    let id = UUID()
    let fileURL: URL
}

private struct MeasurementChecklistItem:
    Identifiable
{
    let id: String
    let title: String
    let detail: String
    let state:
        MeasurementChecklistState
}

private enum MeasurementChecklistState {
    case complete
    case attention
    case missing

    var score: Double {
        switch self {
        case .complete:
            return 1
        case .attention:
            return 0.5
        case .missing:
            return 0
        }
    }

    var systemImage: String {
        switch self {
        case .complete:
            return "checkmark.circle.fill"
        case .attention:
            return "exclamationmark.circle"
        case .missing:
            return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .complete:
            return .green
        case .attention:
            return .orange
        case .missing:
            return .red
        }
    }
}
