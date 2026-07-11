import Combine
import DomainCore
import Foundation
import Persistence

@MainActor
final class PomieszczenieListaViewModel: ObservableObject {
    @Published private(set) var rooms: [RoomDefinition] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let projectID: ProjectID
    private let roomRepository: SwiftDataRoomRepository

    init(
        projectID: ProjectID,
        roomRepository: SwiftDataRoomRepository
    ) {
        self.projectID = projectID
        self.roomRepository = roomRepository
    }

    func loadRooms() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rooms = try await roomRepository.fetchAll(projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createRectangularRoom(
        name: String,
        width: Double,
        depth: Double,
        wallHeight: Double,
        wallThickness: Double,
        constructionType: ConstructionType
    ) async -> Bool {
        do {
            let room = try RoomDefinitionFactory.makeRectangularRoom(
                projectID: projectID,
                name: name,
                width: Millimeters(width),
                depth: Millimeters(depth),
                wallHeight: Millimeters(wallHeight),
                wallThickness: Millimeters(wallThickness),
                constructionType: constructionType
            )
            return await saveRoom(room)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveRoom(_ room: RoomDefinition) async -> Bool {
        guard room.projectID == projectID else {
            errorMessage = "Pomieszczenie należy do innego projektu."
            return false
        }
        do {
            try await roomRepository.save(room)
            await loadRooms()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteRoom(id: RoomID) async {
        do {
            try await roomRepository.delete(id: id)
            await loadRooms()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
