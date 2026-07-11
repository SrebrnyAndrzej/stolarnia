import Foundation
import Testing
@testable import DomainCore

struct WorkshopProjectTests {
    @Test
    func newProjectStartsWithStableInitialRevision() throws {
        let project = try makeProject()

        #expect(project.currentRevision.number.code == "R01")
        #expect(project.currentRevision.stage == .initial)
        #expect(project.isFrozenForProduction == false)
        #expect(project.protectionPolicy == .privateProject)
    }

    @Test
    func revisionNumbersAdvanceWithoutChangingProjectID() throws {
        var project = try makeProject()
        let originalID = project.id

        let revision = try project.createRevision(
            stage: .measurement,
            summary: "Pomiar wykonany"
        )

        #expect(project.id == originalID)
        #expect(revision.number.code == "R02")
        #expect(project.revisionHistory.count == 2)
    }

    @Test
    func freezingProjectCreatesNewRevisionAndProductionStatus() throws {
        var project = try makeProject()

        let frozenRevision = try project.freezeForProduction()

        #expect(frozenRevision.number.code == "R02")
        #expect(frozenRevision.isFrozenForProduction)
        #expect(project.isFrozenForProduction)
        #expect(project.status == .readyForProduction)
    }

    @Test
    func roomIdentifierIsAddedOnlyOnce() throws {
        var project = try makeProject()
        let roomID = RoomID()

        project.addRoom(id: roomID)
        project.addRoom(id: roomID)

        #expect(project.roomIDs == [roomID])
    }

    @Test
    func projectRoundTripsThroughJSON() throws {
        var project = try makeProject()
        project.addRoom(id: RoomID())
        _ = try project.createRevision(
            stage: .design,
            summary: "Pierwsza wersja projektu"
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(WorkshopProject.self, from: data)

        #expect(decoded == project)
    }

    private func makeProject() throws -> WorkshopProject {
        try WorkshopProject(
            code: ProjectCode("prj-2026-0001"),
            name: "Projekt testowy",
            customer: Customer(displayName: "Klient testowy")
        )
    }
}
