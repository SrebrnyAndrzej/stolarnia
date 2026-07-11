import Combine
import DomainCore
import Foundation
import Persistence

@MainActor
final class PomieszczenieSzczegolyViewModel: ObservableObject {
    @Published private(set) var room: RoomDefinition
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let roomRepository: SwiftDataRoomRepository

    init(
        room: RoomDefinition,
        roomRepository: SwiftDataRoomRepository
    ) {
        self.room = room
        self.roomRepository = roomRepository
    }


    func addWallFeature(
        _ payload: WallFeaturePayloadV016,
        assemblies: [FurnitureAssembly]
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            try WallFeatureValidatorV016.validate(
                payload,
                in: room,
                assemblies: assemblies
            )

            var updatedRoom = room
            try applyWallFeatureV016(
                payload,
                to: &updatedRoom
            )
            try await roomRepository.save(updatedRoom)
            room = updatedRoom
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveRoom(_ updatedRoom: RoomDefinition) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            try await roomRepository.save(updatedRoom)
            room = updatedRoom
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateWall(
        _ update: WallMeasurementUpdate
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            var updatedRoom = room
            try updatedRoom.applyWallMeasurementUpdate(update)
            try await roomRepository.save(updatedRoom)
            room = updatedRoom
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
