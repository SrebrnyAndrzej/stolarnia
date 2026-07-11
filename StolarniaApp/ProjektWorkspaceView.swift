import DomainCore
import Persistence
import SwiftUI

struct ProjektWorkspaceView: View {
    let project: WorkshopProject

    @StateObject private var viewModel:
        PomieszczenieSzczegolyViewModel
    @StateObject private var mebleViewModel:
        MeblePomieszczeniaViewModel
    @StateObject private var globalneMaterialyRepository:
        GlobalneMaterialyPomieszczeniaRepository
    @StateObject private var slopeRepository =
        PomiarGarderobySkosyRepository()
    @StateObject private var sciankaRepo: SciankaPodzialowaRepository

    @State private var selectedWallID:
        WallID?
    @State private var selectedFurnitureID:
        FurnitureAssemblyID?
    @State private var wallForSlopeEdit:
        WallSegment?

    init(
        project: WorkshopProject,
        room: RoomDefinition,
        roomRepository: SwiftDataRoomRepository,
        mebleRepositories: MebleRepositoryContainer
    ) {
        self.project = project

        _viewModel = StateObject(
            wrappedValue:
                PomieszczenieSzczegolyViewModel(
                    room: room,
                    roomRepository: roomRepository
                )
        )

        _mebleViewModel = StateObject(
            wrappedValue:
                MeblePomieszczeniaViewModel(
                    roomID: room.id,
                    repositories: mebleRepositories
                )
        )

        _globalneMaterialyRepository = StateObject(
            wrappedValue:
                GlobalneMaterialyPomieszczeniaRepository(
                    roomID:
                        String(describing: room.id)
                )
        )

        _sciankaRepo = StateObject(
            wrappedValue:
                SciankaPodzialowaRepository(
                    roomID:
                        String(describing: room.id)
                )
        )
    }

    var body: some View {
        WorkspaceProjektowyViewV063(
            room: viewModel.room,
            mebleViewModel: mebleViewModel,
            globalneMaterialyRepository:
                globalneMaterialyRepository,
            selectedWallID: $selectedWallID,
            selectedFurnitureID:
                $selectedFurnitureID,
            onUpdateWall: updateWall,
            onEditSlope: openSlopeEditor,
            sciankaRepo: sciankaRepo
        )
        .task {
            await loadWorkspace()
        }
        .onChange(
            of: viewModel.room.wallProfiles
        ) { _, _ in
            synchronizeSlopedPanels()
        }
        .onChange(
            of: mebleViewModel.renderRevision
        ) { _, _ in
            synchronizeSlopedPanels()
        }
        .sheet(item: $wallForSlopeEdit) { wall in
            NavigationStack {
                PomiarGarderobySkosyView(
                    context: measurementContext,
                    initialMeasurementID:
                        findOrCreateSlope(for: wall),
                    room: viewModel.room,
                    onSaveRoom: saveRoom
                )
            }
            .onDisappear {
                synchronizeSlopedPanels()
            }
        }
        .alert(
            "Nie udało się zapisać pomieszczenia",
            isPresented: roomErrorBinding
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(
                viewModel.errorMessage
                ?? "Nieznany błąd"
            )
        }
        .alert(
            "Nie udało się wczytać projektu",
            isPresented: furnitureErrorBinding
        ) {
            Button("OK", role: .cancel) {
                mebleViewModel.errorMessage = nil
            }
        } message: {
            Text(
                mebleViewModel.errorMessage
                ?? "Nieznany błąd"
            )
        }
    }

    private var measurementContext: KontekstPomiaruPomieszczenia {
        KontekstPomiaruPomieszczenia(
            projectID: project.id.description,
            roomID: viewModel.room.id.description,
            projectName: project.name,
            roomName: viewModel.room.name,
            customerName: project.customer.displayName
        )
    }

    private var roomErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var furnitureErrorBinding: Binding<Bool> {
        Binding(
            get: { mebleViewModel.errorMessage != nil },
            set: { if !$0 { mebleViewModel.errorMessage = nil } }
        )
    }

    private func loadWorkspace() async {
        await mebleViewModel.load()
        synchronizeSlopedPanels()
    }

    private func updateWall(
        _ update: WallMeasurementUpdate
    ) async -> Bool {
        let didUpdate = await viewModel.updateWall(update)
        if didUpdate { synchronizeSlopedPanels() }
        return didUpdate
    }

    private func saveRoom(_ room: RoomDefinition) async -> Bool {
        let saved = await viewModel.saveRoom(room)
        if saved { synchronizeSlopedPanels() }
        return saved
    }

    private func synchronizeSlopedPanels() {
        _ = mebleViewModel
            .synchronizujPaneleSkosuV0691(
                room: viewModel.room
            )
    }

    private func openSlopeEditor(for wall: WallSegment) {
        wallForSlopeEdit = wall
    }

    private func findOrCreateSlope(for wall: WallSegment) -> UUID? {
        let existing = slopeRepository.measurements(
            projectID: project.id.description,
            roomID: viewModel.room.id.description
        ).first {
            $0.wallIDRawValueV069 == wall.id.description
        }

        if let existing { return existing.id }

        guard let geometry = viewModel.room.geometry.geometry(of: wall.id) else {
            return nil
        }

        var measurement = slopeRepository.addNew(context: measurementContext)
        measurement.wallIDRawValueV069 = wall.id.description
        measurement.wallNameV069 = wall.name
        measurement.szerokoscScianyMM = geometry.length.rawValue
        measurement.wysokoscMaksymalnaMM = max(
            wall.startHeight, wall.endHeight
        ).rawValue
        measurement.punktySkosu =
            SilnikSkosuPomieszczeniaV069.przygotujProfilDwupunktowy(
                szerokoscScianyMM: geometry.length.rawValue,
                wysokoscMaksymalnaMM: measurement.wysokoscMaksymalnaMM,
                wysokoscNiskaMM: measurement.wysokoscSciankiKolankowejMM,
                strona: measurement.stronaSkosu
            )
        slopeRepository.upsert(measurement)
        return measurement.id
    }
}
