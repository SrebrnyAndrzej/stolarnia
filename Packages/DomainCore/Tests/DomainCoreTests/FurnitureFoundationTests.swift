import Foundation
import Testing
@testable import DomainCore

struct FurnitureFoundationTests {
    @Test
    func assemblyRunnerLengthRoundTripsAndOldPayloadDefaultsToNil() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let withRunner = try FurnitureAssembly(
            name: "Szafka z szufladami",
            kind: .cabinet,
            size: Size3MM(width: 600, height: 720, depth: 522),
            drawerRunnerNominalLength: 450
        )

        let decodedWithRunner = try decoder.decode(
            FurnitureAssembly.self,
            from: encoder.encode(withRunner)
        )
        #expect(decodedWithRunner.drawerRunnerNominalLength == 450)

        let oldAssembly = try FurnitureAssembly(
            name: "Starszy zapis",
            kind: .cabinet,
            size: Size3MM(width: 600, height: 720, depth: 522)
        )
        let oldData = try encoder.encode(oldAssembly)
        let oldJSON = try #require(String(data: oldData, encoding: .utf8))
        #expect(!oldJSON.contains("drawerRunnerNominalLength"))

        let decodedOldAssembly = try decoder.decode(
            FurnitureAssembly.self,
            from: oldData
        )
        #expect(decodedOldAssembly.drawerRunnerNominalLength == nil)
    }

    @Test
    func placementKeepsStableIDsAndWallReference() throws {
        let roomID = RoomID()
        let wallID = WallID()
        let assemblyID = FurnitureAssemblyID()

        let placement = try FurniturePlacement(
            roomID: roomID,
            wallID: wallID,
            assemblyID: assemblyID,
            offsetAlongWall: 120,
            offsetFromWall: 10,
            bottomOffset: 100,
            anchoringMode: .wallMounted
        )

        #expect(placement.roomID == roomID)
        #expect(placement.wallID == wallID)
        #expect(placement.assemblyID == assemblyID)
        #expect(placement.offsetAlongWall == 120)
    }

    @Test
    func assemblyRejectsDuplicateComponentIDs() throws {
        let componentID = ComponentID()
        let first = try FurnitureComponent(
            id: componentID,
            code: "BOK-L",
            role: .side,
            size: Size3MM(width: 18, height: 720, depth: 560)
        )
        let second = try FurnitureComponent(
            id: componentID,
            code: "BOK-P",
            role: .side,
            size: Size3MM(width: 18, height: 720, depth: 560)
        )

        #expect(throws: DomainError.self) {
            _ = try FurnitureAssembly(
                name: "Szafka testowa",
                kind: .cabinet,
                size: Size3MM(width: 600, height: 720, depth: 560),
                components: [first, second]
            )
        }
    }

    @Test
    func sharedPartitionCanBelongToTwoSubassemblies() throws {
        let partition = try FurnitureComponent(
            code: "PRZ-01",
            role: .divider,
            size: Size3MM(width: 18, height: 720, depth: 560),
            isShared: true
        )
        let leftID = SubassemblyID()
        let rightID = SubassemblyID()

        let assembly = try FurnitureAssembly(
            name: "Regał modułowy",
            kind: .shelving,
            size: Size3MM(width: 1200, height: 1800, depth: 350),
            components: [partition],
            subassemblies: [
                try FurnitureSubassembly(id: leftID, name: "Moduł lewy", componentIDs: [partition.id]),
                try FurnitureSubassembly(id: rightID, name: "Moduł prawy", componentIDs: [partition.id])
            ],
            constraints: [
                .sharedPartition(componentID: partition.id, subassemblyIDs: [leftID, rightID])
            ]
        )

        #expect(assembly.components.count == 1)
        #expect(assembly.subassemblies.count == 2)
        #expect(assembly.component(id: partition.id)?.isShared == true)
    }

    @Test
    func runLayoutCalculatesRemainingLength() throws {
        let roomID = RoomID()
        let wallID = WallID()
        let first = try FurnitureAssembly(
            name: "Szafka 600",
            kind: .cabinet,
            size: Size3MM(width: 600, height: 720, depth: 560)
        )
        let second = try FurnitureAssembly(
            name: "Szafka 800",
            kind: .cabinet,
            size: Size3MM(width: 800, height: 720, depth: 560)
        )
        let technology = try CabinetRunTechnology(
            leftEnd: .filler,
            rightEnd: .filler,
            openingTechnology: .pushToOpen
        )
        let run = try FurnitureRun(
            roomID: roomID,
            wallID: wallID,
            name: "Ciąg dolny",
            kind: .base,
            startOffset: 50,
            endOffset: 50,
            moduleIDs: [first.id, second.id],
            technology: technology
        )

        let result = try FurnitureRunLayoutEngine.calculate(
            wallLength: 2000,
            run: run,
            assemblies: [first, second]
        )

        #expect(result.availableLength == 1900)
        #expect(result.occupiedLength == 1400)
        #expect(result.remainingLength == 500)
        #expect(result.isOverfilled == false)
    }

    @Test
    func runLayoutDetectsOverfill() throws {
        let assembly = try FurnitureAssembly(
            name: "Słupek 1200",
            kind: .cabinet,
            size: Size3MM(width: 1200, height: 2200, depth: 600)
        )
        let run = try FurnitureRun(
            roomID: RoomID(),
            wallID: WallID(),
            name: "Ciąg wysoki",
            kind: .tall,
            startOffset: 0,
            endOffset: 0,
            moduleIDs: [assembly.id],
            technology: try CabinetRunTechnology()
        )

        let result = try FurnitureRunLayoutEngine.calculate(
            wallLength: 1000,
            run: run,
            assemblies: [assembly]
        )

        #expect(result.remainingLength == -200)
        #expect(result.isOverfilled == true)
    }
}
