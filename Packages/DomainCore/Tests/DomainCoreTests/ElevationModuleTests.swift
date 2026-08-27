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
        // dostępne = 350 − 6 = 344; front dla 3 szt. = (344 − 2 × 4)/3 = 112 < 148.
        // Fuga to 4 mm z `ProductionRules.frontToFrontGap`, nie dawne lokalne 3 mm —
        // fronty szuflad i drzwi mają w jednej zabudowie ten sam odstęp.
        #expect(!layout.isValid)
        #expect(abs(layout.frontHeight.rawValue - 112.0) < 0.01)
        #expect(layout.maximumCount == 2)

        module.updateZone(at: 0) { $0.drawerCount = 2 }
        let fixed = try! #require(module.drawerLayout(forZoneAt: 0))
        #expect(fixed.isValid)
        #expect(abs(fixed.frontHeight.rawValue - 170.0) < 0.01)
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
    func customDrawerFrontHeightsDriveCutListAndAssembly() throws {
        let module = ElevationModule(
            zones: [
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 3,
                    drawerSystem: .gtvAxisPro,
                    drawerProfileName: "H69",
                    drawerFrontHeights: [140, 140, 280]
                )
            ]
        )

        // **Zamierzona zmiana reguły, nie regresja.**
        //
        // Wcześniej ten test utrwalał zachowanie, które warsztat zgłosił jako
        // wadę: zapisane wysokości wracały bez skalowania. W module 720 mm
        // układ 140/140/280 sumuje się do 560, więc razem z fugami i luzami
        // **146 mm bryły zostawało bez frontu**.
        //
        // Teraz zapisane wysokości są **proporcjami** — stosunek 1:1:2 zostaje
        // zachowany, ale fronty wypełniają strefę co do milimetra:
        // 176 + 176 + 354 + 2×4 fugi + 3 + 3 luzy = 720.
        let wysokosci = module.drawerFrontHeights(forZoneAt: 0)
        #expect(wysokosci == [176, 176, 354], "\(wysokosci)")
        #expect(DrawerFrontStack.fillsExactly(
            heights: wysokosci, zoneHeight: 720))
        // Proporcja 1:1:2 przeżyła przeliczenie.
        #expect(wysokosci[0] == wysokosci[1])
        #expect(abs(wysokosci[2].rawValue / wysokosci[0].rawValue - 2) < 0.02)

        let layout = try #require(module.drawerLayout(forZoneAt: 0))
        #expect(layout.isValid)

        let cutList = module.cutList()
        let lowFront = try #require(
            cutList.first {
                $0.name == "Front szuflady 1 (H69)"
            }
        )
        let highFront = try #require(
            cutList.first {
                $0.name == "Front szuflady 3 (H69)"
            }
        )
        #expect(lowFront.length == 176)
        #expect(highFront.length == 354)

        let assembly = try module.makeAssembly()
        let frontHeights = assembly.components
            .filter { $0.role == .front }
            .sorted { $0.localPosition.y < $1.localPosition.y }
            .map(\.size.height)
        #expect(frontHeights == [176, 176, 354])
        // Najważniejsze: fronty zbudowanego zespołu domykają moduł.
        #expect(DrawerFrontStack.fillsExactly(
            heights: frontHeights, zoneHeight: 720))
    }

    @Test
    func columnInnerWidthAccountsForDividers() {
        let module = ElevationModule(width: 600)
        #expect(module.columnInnerWidth(columns: 1) == 564)
        #expect(module.columnInnerWidth(columns: 2) == 273)   // (600−36−18)/2
    }

    @Test
    func cellsDescribeGeneratedCompartments() throws {
        let module = ElevationModule(width: 600, zones: [
            ElevationZone(kind: .doors, columns: 2)
        ])

        let cells = module.cells
        #expect(cells.count == 2)
        #expect(cells.map(\.id) == ["z0-c0", "z0-c1"])

        let first = try #require(cells.first)
        #expect(first.kind == .doors)
        #expect(first.lower == 0)
        #expect(first.upper == 720)
        #expect(first.left == 18)
        #expect(first.right == 291)
        #expect(first.width == 273)
        #expect(first.height == 720)
    }

    @Test
    func cellsUseSingleTechnicalOpeningForApplianceZones() {
        let module = ElevationModule(splits: [600], zones: [
            ElevationZone(kind: .appliance, columns: 3),
            ElevationZone(kind: .shelves, columns: 2, shelfCount: 2)
        ])

        let applianceCells = module.cells.filter { $0.kind == .appliance }
        let shelfCells = module.cells.filter { $0.kind == .shelves }

        #expect(applianceCells.count == 1)
        #expect(applianceCells[0].id == "z0-c0")
        #expect(applianceCells[0].width == 564)
        #expect(shelfCells.count == 2)
        #expect(shelfCells.allSatisfy { $0.shelfCount == 2 })
    }

    @Test
    func unknownProfileFallsBackToSystemDefault() {
        var module = ElevationModule(splits: [300], zones: [
            ElevationZone(kind: .drawers, drawerSystem: .gtvAxisPro, drawerProfileName: "NIE-MA"),
            ElevationZone(kind: .doors)
        ])
        module.updateZone(at: 0) { _ in }
        // Domyślny profil GTV to H120 — zweryfikowane w katalogu producenta.
        // Wariant H116 nie istnieje w ofercie; wcześniej aplikacja podawała go
        // jako domyślny, co przy zamówieniu dawało zły profil.
        #expect(module.zones[0].drawerProfileName == "H120")
    }

    // MARK: Lista formatek

    @Test
    func cutListForSingleDoorModule() {
        let module = ElevationModule() // 600×720×560, drzwi
        let items = module.cutList()
        // Bok, Dno, Trawers, Plecy, Front drzwi
        #expect(items.count == 5)
        #expect(module.totalCutPieces == 7) // 2+1+2+1+1

        // **Zamierzona zmiana reguły.** Wcześniej front liczono od światła
        // korpusu z zaszytą trójką: 564 − 3 = 561. Front nakładany zakrywa
        // korpus, więc liczy się go od podziałki modułu: 600 − 4 = 596,
        // a wysokość 720 − 4 = 716 (luz 2 mm u góry i u dołu).
        // Trójka nie zgadzała się z żadną regułą projektu.
        let front = try! #require(items.first { $0.name == "Front drzwi" })
        #expect(front.length == 716)
        #expect(front.width == 596)
        #expect(front.width == ProductionRules.frontWidth(forModulePitch: 600))
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
        // Dwa fronty na module 600: (600 − 4 luzy − 4 fuga) / 2 = 296.
        // Między nimi zostaje dokładnie 4 mm fugi.
        #expect(fronts.width == 296)
    }

    @Test
    func hardwareListCarriesDrawerSystemVariantAndNominalLength() throws {
        let module = ElevationModule(
            depth: 560,
            zones: [
                ElevationZone(
                    kind: .drawers,
                    columns: 2,
                    drawerCount: 3,
                    drawerSystem: .gtvAxisPro,
                    drawerProfileName: "H120"
                )
            ]
        )

        let pozycja = try #require(
            module.hardwareList().first { $0.kind == .drawerRunner }
        )
        #expect(pozycja.system == "GTV Axis Pro")
        #expect(pozycja.variant == "H120")
        #expect(pozycja.dimension == 500)
        #expect(pozycja.count == 6)
        #expect(pozycja.unit == .pair)
        #expect(!pozycja.requiresVariantConfirmation)
    }

    @Test
    func hardwareListKeepsDifferentRunnerLengthsInSeparateRows() throws {
        let plytki = ElevationModule(
            depth: 480,
            zones: [
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 1,
                    drawerSystem: .amixSlimbox,
                    drawerProfileName: "SB12"
                )
            ]
        )
        let gleboki = ElevationModule(
            depth: 560,
            zones: [
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 1,
                    drawerSystem: .amixSlimbox,
                    drawerProfileName: "SB12"
                )
            ]
        )

        let wymiarPlytki = try #require(plytki.hardwareList().first).dimension
        let wymiarGleboki = try #require(gleboki.hardwareList().first).dimension
        #expect(wymiarPlytki == 450)
        #expect(wymiarGleboki == 500)
    }

    @Test
    func hardwareListDoesNotMixHingesWithCutItems() throws {
        let module = ElevationModule()

        #expect(module.cutList().count == 5)
        let zawias = try #require(
            module.hardwareList().first { $0.kind == .hinge }
        )
        #expect(zawias.dimension == 35)
        #expect(zawias.count == 2)
        #expect(zawias.unit == .piece)
        #expect(zawias.requiresVariantConfirmation)
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

    @Test
    func moduleCodableKeepsCompatibilityWhenFrontSpansAreMissing() throws {
        let data = try JSONEncoder().encode(ElevationModule())
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("frontSpans"))

        let decoded = try JSONDecoder().decode(ElevationModule.self, from: data)
        #expect(decoded.frontSpans.isEmpty)
        #expect(decoded.zones.count == 1)
    }

    @Test
    func frontSpansOverrideAutomaticFrontCutList() throws {
        let module = ElevationModule(
            splits: [300],
            zones: [
                ElevationZone(kind: .drawers, drawerCount: 2),
                ElevationZone(kind: .shelves, shelfCount: 2)
            ],
            frontSpans: [
                ElevationFrontSpan(
                    lowerZoneIndex: 0,
                    upperZoneIndex: 1,
                    opening: .leftHinged,
                    coversInternalDrawers: true
                )
            ]
        )

        let items = module.cutList()
        let names = items.map(\.name)
        #expect(!names.contains { $0.hasPrefix("Front szuflady") })
        #expect(names.contains("Dno szuflady"))
        #expect(names.contains("Półka"))

        // **Zmienione świadomie 2026-08-27: 717×561 → 716×596.**
        //
        // Stare wartości utrwalały ten sam błąd, który tego samego dnia rano
        // naprawiliśmy dla frontów generowanych per strefa: front liczony
        // od **światła korpusu** (564 − 3 = 561) zamiast od podziałki modułu
        // (600 − 4 = 596). W module 600 zostawiało to 35 mm odsłoniętego
        // korpusu i zaniżało powierzchnię frontu w wycenie.
        //
        // Warstwa frontów miała własną arytmetykę, więc poprawka szerokości
        // frontów jej nie dotknęła — ten sam mebel dostawał front 596 mm bez
        // warstwy frontów i 561 mm z nią.
        let front = try #require(items.first { $0.name == "Front drzwi" })
        #expect(front.count == 1)
        #expect(front.length == 716)
        #expect(front.width == 596)

        // `frontSpanBounds` nadal zwraca obrys **komór** — to jest jego rola.
        // Geometrię lica liczy `frontSpanFaceV0104`.
        let bounds = try #require(module.frontSpanBounds(module.frontSpans[0]))
        #expect(bounds.width == 564)
        #expect(bounds.height == 720)

        let lico = try #require(module.frontSpanFaceV0104(module.frontSpans[0]))
        #expect(lico.x == ProductionRules.frontClearancePerEdge)
        #expect(lico.width == ProductionRules.frontWidth(forModulePitch: 600, columns: 1))
    }

    @Test
    func frontSpanUpdateNormalizesAndRemoveClearsLayer() throws {
        var module = ElevationModule(
            splits: [300],
            zones: [
                ElevationZone(kind: .doors, columns: 2),
                ElevationZone(kind: .shelves, columns: 2)
            ],
            frontSpans: [
                ElevationFrontSpan(
                    lowerZoneIndex: 0,
                    upperZoneIndex: 0,
                    leadingColumnIndex: 0,
                    trailingColumnIndex: 0
                )
            ]
        )
        let id = try #require(module.frontSpans.first?.id)

        module.updateFrontSpan(id: id) {
            $0.lowerZoneIndex = 3
            $0.upperZoneIndex = 1
            $0.leadingColumnIndex = 4
            $0.trailingColumnIndex = 1
            $0.opening = .rightHinged
        }

        let span = try #require(module.frontSpans.first)
        #expect(span.lowerZoneIndex == 1)
        #expect(span.upperZoneIndex == 1)
        #expect(span.leadingColumnIndex == 1)
        #expect(span.trailingColumnIndex == 3)
        #expect(span.opening == .rightHinged)

        module.removeFrontSpan(id: id)
        #expect(module.frontSpans.isEmpty)
    }

    @Test
    func productionSnapshotCountsPiecesAreasAndBanding() {
        let module = ElevationModule()
        let snapshot =
            module.productionSnapshot()

        #expect(snapshot.cutItemRows == 5)
        #expect(snapshot.cutPieceCount == 7)
        #expect(snapshot.boardPieceCount == 5)
        #expect(snapshot.frontPieceCount == 1)
        #expect(snapshot.hdfPieceCount == 1)
        #expect(snapshot.shelfCount == 0)
        #expect(snapshot.drawerBoxCount == 0)
        #expect(abs(snapshot.boardAreaM2 - 1.23504) < 0.0001)
        // Front 716 × 596 = 0,426736 m². Wcześniej 717 × 561 = 0,402237 —
        // ta liczba szła do wyceny, więc błąd w szerokości frontu zaniżał
        // powierzchnię o ok. 6% i razem z nią koszt materiału.
        #expect(abs(snapshot.frontAreaM2 - 0.426736) < 0.0001)
        #expect(abs(snapshot.hdfAreaM2 - 0.385776) < 0.0001)
        // Okleina rośnie o 68 mm na froncie — obwód 2×(0,716+0,596).
        #expect(abs(snapshot.estimatedBandingM - 5.756) < 0.001)
        #expect(snapshot.hingeCount == 2)
        #expect(snapshot.drawerRunnerPairCount == 0)
        #expect(snapshot.shelfSupportCount == 0)
        #expect(snapshot.hardwareItemCount == 2)
        #expect(snapshot.estimatedHardwareCostNetto == 24)
        #expect(snapshot.estimatedMaterialCostNetto > 0)
        #expect(snapshot.estimatedLaborCostNetto == 76)
        #expect(
            abs(
                snapshot.estimatedBaseCostNetto
                - (
                    snapshot.estimatedMaterialCostNetto
                    + snapshot.estimatedHardwareCostNetto
                    + snapshot.estimatedLaborCostNetto
                )
            ) < 0.0001
        )
        #expect(
            abs(
                snapshot.estimatedRetailPriceNetto
                - snapshot.estimatedBaseCostNetto * 1.55
            ) < 0.001
        )
        #expect(
            abs(
                snapshot.estimatedMarginNetto
                - (
                    snapshot.estimatedRetailPriceNetto
                    - snapshot.estimatedBaseCostNetto
                )
            ) < 0.0001
        )
    }

    @Test
    func productionDeltaReportsSplitConsequences() {
        var module = ElevationModule()
        let before =
            module.productionSnapshot()

        _ = module.splitZone(at: 300)
        let after =
            module.productionSnapshot()
        let delta =
            ElevationProductionDelta(
                before: before,
                after: after
            )

        #expect(delta.hasChanges)
        #expect(delta.cutPieceCount == 6)
        #expect(delta.frontPieceCount == 3)
        #expect(delta.drawerBoxCount == 3)
        #expect(delta.boardPieceCount == 0)
        #expect(delta.hdfPieceCount == 3)
        #expect(abs(delta.frontAreaM2) > 0)
        #expect(delta.estimatedBandingM > 0)
        #expect(delta.hingeCount == 0)
        #expect(delta.drawerRunnerPairCount == 3)
        #expect(delta.hardwareItemCount == 3)
        #expect(delta.estimatedHardwareCostNetto == 240)
        #expect(delta.estimatedLaborCostNetto == 69)
        #expect(delta.estimatedBaseCostNetto > 0)
        #expect(delta.estimatedRetailPriceNetto > delta.estimatedBaseCostNetto)
        #expect(
            abs(
                delta.estimatedMarginNetto
                - delta.estimatedBaseCostNetto * 0.55
            ) < 0.001
        )
    }

    @Test
    func productionSnapshotCountsFrontSpanHardware() throws {
        let module = ElevationModule(
            height: 1700,
            zones: [
                ElevationZone(kind: .doors)
            ],
            frontSpans: [
                ElevationFrontSpan(
                    lowerZoneIndex: 0,
                    upperZoneIndex: 0,
                    opening: .leftHinged
                )
            ]
        )

        let snapshot =
            module.productionSnapshot()

        #expect(snapshot.hingeCount == 4)
        #expect(snapshot.drawerRunnerPairCount == 0)
        #expect(snapshot.hardwareItemCount == 4)
        #expect(snapshot.estimatedHardwareCostNetto == 48)
        #expect(snapshot.estimatedBaseCostNetto > snapshot.estimatedHardwareCostNetto)
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

    /// Granica, na której liczenie z gabarytu i ze światła daje dwa różne
    /// szczeble drabinki: 522 mm korpusu ma 519 mm światła, więc mieści NL 450,
    /// ale nie NL 500 wymagającą 522 mm światła.
    @Test
    func makeAssemblyStoresRunnerLengthCalculatedFromCabinetClearance() throws {
        let module = ElevationModule(
            depth: 522,
            zones: [
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 2,
                    drawerSystem: .gtvAxisPro,
                    drawerProfileName: "H120"
                )
            ]
        )

        let assembly = try module.makeAssembly()
        let orderedRunner = try #require(
            module.hardwareList().first { $0.kind == .drawerRunner }
        )

        #expect(assembly.drawerRunnerNominalLength == 450)
        #expect(assembly.drawerRunnerNominalLength == orderedRunner.dimension)
    }

    @Test(arguments: DrawerSystem.allCases, Array(stride(from: 300, through: 700, by: 10)))
    func assemblyAndHardwareListUseTheSameRunnerLength(
        system: DrawerSystem,
        depth: Int
    ) throws {
        let module = ElevationModule(
            depth: Millimeters(Double(depth)),
            zones: [
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 1,
                    drawerSystem: system
                )
            ]
        )
        let expected = DrawerProfile.nominalLength(
            for: system,
            cabinetInnerDepth: module.depth - ProductionRules.backPanelThickness
        )
        let ordered = module.hardwareList()
            .first { $0.kind == .drawerRunner }?
            .dimension
        let stored = try module.makeAssembly().drawerRunnerNominalLength

        #expect(ordered == expected)
        #expect(stored == expected)
    }

    @Test
    func assemblyWithoutDrawersHasNoRunnerLength() throws {
        let assembly = try ElevationModule(
            zones: [ElevationZone(kind: .doors)]
        ).makeAssembly()

        #expect(assembly.drawerRunnerNominalLength == nil)
    }

    /// Przy płytkim korpusie GTV i Amix dobierają różne szczeble drabinki.
    /// Pole zespołu nie może podawać prowadnicy pierwszej strefy jako wartości
    /// całego mebla, skoro druga strefa wymaga innego systemu i innej długości.
    @Test
    func assemblyWithMixedDrawerSystemsHasNoSingleRunnerLength() throws {
        let module = ElevationModule(
            depth: 297,
            splits: [300],
            zones: [
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 1,
                    drawerSystem: .gtvAxisPro
                ),
                ElevationZone(
                    kind: .drawers,
                    drawerCount: 1,
                    drawerSystem: .amixSlimbox
                )
            ]
        )

        let runners = module.hardwareList().filter { $0.kind == .drawerRunner }
        #expect(Set(runners.map(\.system)).count == 2)
        #expect(Set(runners.map(\.dimension)) == Set([250, 270]))
        #expect(try module.makeAssembly().drawerRunnerNominalLength == nil)
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
                ElevationZone(kind: .drawers, drawerCount: 3, drawerSystem: .gtvAxisPro, drawerProfileName: "H120"),
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

/// Warstwa frontów w zespole, nie tylko na liście formatek.
///
/// `cutList()` respektowało `frontSpans` od dawna, a `makeAssembly` nie —
/// ten sam moduł miał inne fronty na liście formatek i inne w zespole, który
/// karmi `AssemblyInspector`, kartę techniczną i widok 3D. Kontrola sprawdzała
/// fronty, których lista formatek nie zamawiała.
struct WarstwaFrontowWZespoleTests {

    private func modulZWarstwaFrontow() -> ElevationModule {
        ElevationModule(
            name: "Dolna 600 · jedno lico",
            width: 600, height: 720, depth: 560,
            zones: [
                ElevationZone(kind: .drawers, drawerCount: 3)
            ],
            frontSpans: [
                ElevationFrontSpan(
                    lowerZoneIndex: 0,
                    upperZoneIndex: 0,
                    opening: .rightHinged,
                    coversInternalDrawers: true
                )
            ]
        )
    }

    /// Zespół dostaje front z warstwy, a nie trzy fronty szuflad.
    @Test
    func zespolBierzeFrontyZWarstwyFrontow() throws {
        let zespol = try modulZWarstwaFrontow().makeAssembly()
        let fronty = zespol.components.filter { $0.role == .front }

        #expect(fronty.count == 1, "fronty: \(fronty.map(\.code))")
        // Skrzynki zostają — warstwa frontów zakrywa szuflady, nie usuwa ich.
        #expect(zespol.components.contains { $0.role == .drawerBox })
    }

    /// Kierunek otwierania dociera do zespołu.
    ///
    /// To jest cel całej zmiany: bez tego strona zawiasu nie wychodziła poza
    /// edytor, więc odsunięcie skrzynki szuflady szło symetrycznie po obu
    /// stronach, choć zawias jest po jednej.
    @Test
    func frontNiesieKierunekOtwierania() throws {
        let zespol = try modulZWarstwaFrontow().makeAssembly()
        let front = try #require(zespol.components.first { $0.role == .front })
        #expect(front.opening == .rightHinged)
    }

    /// Front w zespole ma **ten sam wymiar** co na liście formatek.
    ///
    /// Rozjazd między tymi dwoma to była istota problemu.
    @Test
    func zespolIListaFormatekZgadzajaSieCoDoMilimetra() throws {
        let modul = modulZWarstwaFrontow()
        let zespol = try modul.makeAssembly()

        let front = try #require(zespol.components.first { $0.role == .front })
        let formatka = try #require(
            modul.cutList().first { $0.material == .front18 }
        )

        #expect(front.size.width == formatka.width)
        #expect(front.size.height == formatka.length)
        #expect(front.size.width
                == ProductionRules.frontWidth(forModulePitch: 600, columns: 1))
    }

    /// Bez warstwy frontów kierunek zostaje **nieokreślony**, nie zgadnięty.
    ///
    /// Front generowany per strefa nie wie, po której stronie jest zawias.
    /// `nil` mówi o tym wprost; wpisanie `.leftHinged` byłoby zmyśleniem,
    /// po którym silnik odsunąłby skrzynkę w złą stronę.
    @Test
    func bezWarstwyFrontowKierunekJestNieokreslony() throws {
        let modul = ElevationModule(
            name: "Dolna 600 · drzwi",
            width: 600, height: 720, depth: 560,
            zones: [ElevationZone(kind: .doors)]
        )
        let zespol = try modul.makeAssembly()
        let front = try #require(zespol.components.first { $0.role == .front })
        #expect(front.opening == nil)
    }

    /// Zespół z warstwą frontów przechodzi kontrolę produkcyjną.
    ///
    /// Wcześniej kontrola oglądała fronty per strefa, których lista formatek
    /// nie zamawiała — więc jej wynik nie mówił nic o meblu, który powstanie.
    @Test
    func zespolZWarstwaFrontowPrzechodziKontrole() throws {
        let zespol = try modulZWarstwaFrontow().makeAssembly()
        let uwagi = AssemblyInspector.inspect(zespol)
        let bledy = uwagi.filter { $0.severity == .error }
        #expect(bledy.isEmpty, "błędy: \(bledy.map(\.message))")
    }
}
