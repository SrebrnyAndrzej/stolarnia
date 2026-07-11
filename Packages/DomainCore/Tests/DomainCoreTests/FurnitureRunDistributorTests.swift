import Foundation
import Testing
@testable import DomainCore

struct FurnitureRunDistributorTests {

    private func makeAssembly(width: Millimeters) throws -> FurnitureAssembly {
        try FurnitureAssembly(
            name: "M",
            kind: .cabinet,
            size: Size3MM(width: width, height: 720, depth: 560)
        )
    }

    private func makeRun(
        moduleIDs: [FurnitureAssemblyID],
        startOffset: Millimeters = 0,
        endOffset: Millimeters = 0,
        leftEnd: RunEndStrategy = .none,
        rightEnd: RunEndStrategy = .none
    ) throws -> FurnitureRun {
        try FurnitureRun(
            roomID: RoomID(),
            wallID: WallID(),
            name: "Ciąg",
            kind: .base,
            startOffset: startOffset,
            endOffset: endOffset,
            moduleIDs: moduleIDs,
            technology: try CabinetRunTechnology(leftEnd: leftEnd, rightEnd: rightEnd)
        )
    }

    @Test
    func equalWidthSplitsAvailableLengthEvenly() throws {
        let ids = [FurnitureAssemblyID(), FurnitureAssemblyID(), FurnitureAssemblyID()]
        let run = try makeRun(moduleIDs: ids)
        let dist = try FurnitureRunDistributor.distributeEqualWidth(wallLength: 3000, run: run)

        #expect(dist.equalModuleWidth == 1000)
        #expect(dist.placements.count == 3)
        #expect(dist.placements[0].offsetAlongWall == 0)
        #expect(dist.placements[1].offsetAlongWall == 1000)
        #expect(dist.placements[2].offsetAlongWall == 2000)
        #expect(dist.placements.allSatisfy { $0.width == 1000 })
    }

    @Test
    func equalWidthRespectsOffsets() throws {
        let ids = [FurnitureAssemblyID(), FurnitureAssemblyID()]
        let run = try makeRun(moduleIDs: ids, startOffset: 100, endOffset: 100)
        // available = 3000 - 200 = 2800 → 1400 każdy, start od 100.
        let dist = try FurnitureRunDistributor.distributeEqualWidth(wallLength: 3000, run: run)
        #expect(dist.equalModuleWidth == 1400)
        #expect(dist.placements[0].offsetAlongWall == 100)
        #expect(dist.placements[1].offsetAlongWall == 1500)
    }

    @Test
    func fixedWidthAbsorbsLeftoverIntoTrailingFiller() throws {
        let a = try makeAssembly(width: 600)
        let b = try makeAssembly(width: 800)
        let run = try makeRun(moduleIDs: [a.id, b.id])
        // available 3000, occupied 1400, leftover 1600 → trailing filler.
        let dist = try FurnitureRunDistributor.distributeFixedWidth(
            wallLength: 3000, run: run, assemblies: [a, b], filler: .trailing
        )
        #expect(dist.trailingFiller == 1600)
        #expect(dist.leadingFiller == 0)
        #expect(dist.placements[0].offsetAlongWall == 0)
        #expect(dist.placements[1].offsetAlongWall == 600)
        #expect(!dist.isOverfilled)
    }

    @Test
    func fixedWidthLeadingFillerShiftsModules() throws {
        let a = try makeAssembly(width: 600)
        let run = try makeRun(moduleIDs: [a.id])
        // available 1000, occupied 600, leftover 400 → leading filler; moduł startuje od 400.
        let dist = try FurnitureRunDistributor.distributeFixedWidth(
            wallLength: 1000, run: run, assemblies: [a], filler: .leading
        )
        #expect(dist.leadingFiller == 400)
        #expect(dist.placements[0].offsetAlongWall == 400)
    }

    @Test
    func fixedWidthSplitSharesLeftoverBothEnds() throws {
        let a = try makeAssembly(width: 600)
        let run = try makeRun(moduleIDs: [a.id])
        // leftover 400 → split 200/200, moduł od 200.
        let dist = try FurnitureRunDistributor.distributeFixedWidth(
            wallLength: 1000, run: run, assemblies: [a], filler: .split
        )
        #expect(dist.leadingFiller == 200)
        #expect(dist.trailingFiller == 200)
        #expect(dist.placements[0].offsetAlongWall == 200)
    }

    @Test
    func fixedWidthDerivesFillerSideFromTechnology() throws {
        let a = try makeAssembly(width: 600)
        // Lewy koniec = filler → leading.
        let run = try makeRun(moduleIDs: [a.id], leftEnd: .filler)
        let dist = try FurnitureRunDistributor.distributeFixedWidth(
            wallLength: 1000, run: run, assemblies: [a]   // filler nil → z technologii
        )
        #expect(dist.leadingFiller == 400)
        #expect(dist.trailingFiller == 0)
    }

    @Test
    func fixedWidthFlagsOverfill() throws {
        let a = try makeAssembly(width: 800)
        let b = try makeAssembly(width: 800)
        let run = try makeRun(moduleIDs: [a.id, b.id])
        // available 1000, occupied 1600 → overfill -600.
        let dist = try FurnitureRunDistributor.distributeFixedWidth(
            wallLength: 1000, run: run, assemblies: [a, b], filler: .trailing
        )
        #expect(dist.isOverfilled)
        #expect(dist.remaining == -600)
    }

    @Test
    func availableThrowsWhenOffsetsExceedWall() throws {
        let run = try makeRun(moduleIDs: [FurnitureAssemblyID()], startOffset: 1500, endOffset: 1600)
        #expect(throws: DomainError.self) {
            _ = try FurnitureRunDistributor.available(wallLength: 3000, run: run)
        }
    }
}
