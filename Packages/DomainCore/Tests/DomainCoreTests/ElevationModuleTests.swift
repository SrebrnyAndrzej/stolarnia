import Foundation
import Testing
@testable import DomainCore

struct ElevationModuleTests {

    // MARK: Normalizacja i operacje na strefach

    @Test
    func initPadsZonesToMatchSplits() {
        let module = ElevationModule(splits: [300, 500], zones: [])
        #expect(module.splits == [300, 500])
        #expect(module.zones.count == 3)
        #expect(module.boundaries == [0, 300, 500, 720])
    }

    @Test
    func splitZoneInsertsNewDrawerZoneBelowCut() {
        var module = ElevationModule() // 600×720, jedna strefa drzwi
        let newIndex = module.splitZone(at: 300)
        #expect(newIndex == 0)
        #expect(module.splits == [300])
        #expect(module.zones.count == 2)
        #expect(module.zones[0].kind == .drawers)   // nowa strefa poniżej cięcia
        #expect(module.zones[1].kind == .doors)     // pierwotna nad cięciem
    }

    @Test
    func splitZoneRejectsCutsTooCloseToBoundaries() {
        var module = ElevationModule()
        #expect(module.splitZone(at: 50) == nil)     // < 100 od dna
        #expect(module.splitZone(at: 680) == nil)    // < 100 od góry
        #expect(module.splitZone(at: 300) != nil)
        #expect(module.splitZone(at: 350) == nil)    // < 100 od istniejącego podziału
    }

    @Test
    func removeSplitBelowMergesIntoLowerZone() {
        var module = ElevationModule(splits: [300], zones: [
            ElevationZone(kind: .drawers),
            ElevationZone(kind: .doors)
        ])
        #expect(module.removeSplitBelow(zoneIndex: 0) == false)
        #expect(module.removeSplitBelow(zoneIndex: 1) == true)
        #expect(module.splits.isEmpty)
        #expect(module.zones.count == 1)
        #expect(module.zones[0].kind == .drawers)
    }

    @Test
    func moveSplitClampsToMinimumZoneHeights() {
        var module = ElevationModule(splits: [300], zones: [])
        module.moveSplit(at: 0, to: 20)
        #expect(module.splits[0] == 100)
        module.moveSplit(at: 0, to: 900)
        #expect(module.splits[0] == 620)   // 720 − 100
    }

    @Test
    func setZoneHeightOnTopZoneAdjustsModuleHeight() {
        var module = ElevationModule(splits: [300], zones: [])
        module.setZoneHeight(500, forZoneAt: 1)
        #expect(module.height == 800)      // 300 + 500
        module.setZoneHeight(250, forZoneAt: 0)
        #expect(module.splits[0] == 250)
    }

    // MARK: Szuflady — walidacja z realnymi profilami

    @Test
    func amixSB12InShortZoneIsInvalidAndSuggestsMaxTwo() {
        var module = ElevationModule(splits: [350], zones: [
            ElevationZone(kind: .drawers, drawerCount: 3, drawerSystem: .amixSlimbox, drawerProfileName: "SB12"),
            ElevationZone(kind: .doors)
        ])
        let layout = try! #require(module.drawerLayout(forZoneAt: 0))
        // dostępne = 350 − 6 = 344; front dla 3 szt. = (344 − 6)/3 ≈ 112,67 < 148
        #expect(!layout.isValid)
        #expect(abs(layout.frontHeight.rawValue - 112.6667) < 0.01)
        #expect(layout.maximumCount == 2)   // floor(347/151)

        module.updateZone(at: 0) { $0.drawerCount = 2 }
        let fixed = try! #require(module.drawerLayout(forZoneAt: 0))
        #expect(fixed.isValid)
        #expect(abs(fixed.frontHeight.rawValue - 170.5) < 0.01)
        #expect(module.invalidDrawerZoneCount == 0)
    }

    @Test
    func drawerBoxWidthSubtractsSystemSides() {
        let module = ElevationModule(width: 600, splits: [350], zones: [
            ElevationZone(kind: .drawers, drawerSystem: .blumLegrabox, drawerProfileName: "M"),
            ElevationZone(kind: .doors)
        ])
        let layout = try! #require(module.drawerLayout(forZoneAt: 0))
        // światło 564 − 2×12,7 = 538,6
        #expect(abs(layout.boxWidth.rawValue - 538.6) < 0.01)
    }

    @Test
    func columnInnerWidthAccountsForDividers() {
        let module = ElevationModule(width: 600)
        #expect(module.columnInnerWidth(columns: 1) == 564)
        #expect(module.columnInnerWidth(columns: 2) == 273)   // (600−36−18)/2
    }

    @Test
    func unknownProfileFallsBackToSystemDefault() {
        var module = ElevationModule(splits: [300], zones: [
            ElevationZone(kind: .drawers, drawerSystem: .gtvAxisPro, drawerProfileName: "NIE-MA"),
            ElevationZone(kind: .doors)
        ])
        module.updateZone(at: 0) { _ in }
        #expect(module.zones[0].drawerProfileName == "H116")
    }

    // MARK: Lista formatek

    @Test
    func cutListForSingleDoorModule() {
        let module = ElevationModule() // 600×720×560, drzwi
        let items = module.cutList()
        // Bok, Dno, Trawers, Plecy, Front drzwi
        #expect(items.count == 5)
        #expect(module.totalCutPieces == 7) // 2+1+2+1+1

        let front = try! #require(items.first { $0.name == "Front drzwi" })
        #expect(front.length == 717)     // 720 − 3
        #expect(front.width == 561)      // 564 − 3
    }

    @Test
    func cutListWithColumnsAddsDividerAndMultipliesFronts() {
        let module = ElevationModule(width: 600, zones: [
            ElevationZone(kind: .doors, columns: 2)
        ])
        let items = module.cutList()
        let divider = try! #require(items.first { $0.name == "Przegroda pionowa" })
        #expect(divider.count == 1)
        let fronts = try! #require(items.first { $0.name == "Front drzwi" })
        #expect(fronts.count == 2)
        #expect(fronts.width == 270)     // 273 − 3
    }

    @Test
    func applianceZoneGeneratesNoParts() {
        let module = ElevationModule(splits: [600], zones: [
            ElevationZone(kind: .appliance),
            ElevationZone(kind: .doors)
        ])
        let names = module.cutList().map(\.name)
        #expect(!names.contains { $0.hasPrefix("Front szuflady") })
        #expect(names.filter { $0 == "Front drzwi" }.count == 1)
    }

    // MARK: Adapter do FurnitureAssembly

    @Test
    func makeAssemblyMatchesCutPieceCount() throws {
        let module = ElevationModule(name: "Test 80", width: 800, splits: [300], zones: [
            ElevationZone(kind: .drawers, drawerCount: 2, drawerSystem: .blumLegrabox, drawerProfileName: "C"),
            ElevationZone(kind: .doors)
        ])
        let assembly = try module.makeAssembly()

        #expect(assembly.size == Size3MM(width: 800, height: 720, depth: 560))
        // korpus 6 + fronty szuflad 2 + dna szuflad 2 + front drzwi 1
        #expect(assembly.components.count == 11)
        #expect(assembly.components.count == module.totalCutPieces)

        #expect(assembly.components.contains { $0.role == .side })
        #expect(assembly.components.contains { $0.role == .back })
        #expect(assembly.components.filter { $0.role == .front }.count == 3)
    }

    // MARK: Rekonstrukcja (edycja istniejącego mebla tym samym mechanizmem)

    @Test
    func reconstructRoundTripsSingleDoorModule() throws {
        let original = ElevationModule(name: "Dolna 60")
        let rebuilt = ElevationModule.reconstructed(from: try original.makeAssembly())

        #expect(rebuilt.width == original.width)
        #expect(rebuilt.height == original.height)
        #expect(rebuilt.depth == original.depth)
        #expect(rebuilt.zones.count == 1)
        #expect(rebuilt.zones[0].kind == .doors)
    }

    @Test
    func reconstructRoundTripsDrawersPlusDoors() throws {
        let original = ElevationModule(
            name: "Szafka 80",
            width: 800,
            splits: [300],
            zones: [
                ElevationZone(kind: .drawers, drawerCount: 2, drawerSystem: .blumLegrabox, drawerProfileName: "C"),
                ElevationZone(kind: .doors)
            ]
        )
        let rebuilt = ElevationModule.reconstructed(from: try original.makeAssembly())

        #expect(rebuilt.zones.map(\.kind) == [.drawers, .doors])
        #expect(rebuilt.zones[0].drawerCount == 2)
        #expect(rebuilt.splits.count == 1)
        #expect(abs(rebuilt.splits[0].rawValue - 300) <= 5)
    }

    @Test
    func reconstructDetectsApplianceGapAndShelves() throws {
        let original = ElevationModule(
            name: "Słupek",
            height: 2100,
            splits: [700, 1300],
            zones: [
                ElevationZone(kind: .drawers, drawerCount: 3, drawerSystem: .gtvAxisPro, drawerProfileName: "H116"),
                ElevationZone(kind: .appliance),
                ElevationZone(kind: .shelves, shelfCount: 3)
            ]
        )
        let rebuilt = ElevationModule.reconstructed(from: try original.makeAssembly())

        #expect(rebuilt.zones.map(\.kind) == [.drawers, .appliance, .shelves])
        #expect(rebuilt.zones[0].drawerCount == 3)
        #expect(rebuilt.zones[2].shelfCount == 3)
        #expect(abs(rebuilt.splits[0].rawValue - 700) <= 5)
    }

    @Test
    func reconstructKeepsDoorColumns() throws {
        let original = ElevationModule(
            name: "Szafka 90",
            width: 900,
            zones: [ElevationZone(kind: .doors, columns: 2)]
        )
        let rebuilt = ElevationModule.reconstructed(from: try original.makeAssembly())

        #expect(rebuilt.zones.count == 1)
        #expect(rebuilt.zones[0].kind == .doors)
        #expect(rebuilt.zones[0].columns == 2)
    }

    @Test
    func reconstructFallsBackToSingleDoorZoneForBareCarcass() throws {
        let assembly = try FurnitureAssembly(
            name: "Goły korpus",
            kind: .cabinet,
            size: Size3MM(width: 500, height: 700, depth: 400)
        )
        let rebuilt = ElevationModule.reconstructed(from: assembly)
        #expect(rebuilt.zones.count == 1)
        #expect(rebuilt.zones[0].kind == .doors)
        #expect(rebuilt.width == 500)
    }

    @Test
    func makeAssemblyPlacesDividerBetweenColumns() throws {
        let module = ElevationModule(width: 600, zones: [
            ElevationZone(kind: .doors, columns: 2)
        ])
        let assembly = try module.makeAssembly()
        let divider = try #require(assembly.components.first { $0.role == .divider })
        // x = 18 + 273 = 291
        #expect(divider.localPosition.x == 291)
        #expect(divider.size.width == 18)
    }
}
