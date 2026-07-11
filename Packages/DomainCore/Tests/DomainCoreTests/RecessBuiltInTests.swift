import Testing
@testable import DomainCore

struct RecessBuiltInTests {
    @Test
    func equalFillerDistributionSubtractsDecorativeSidesAndGaps() throws {
        let result = try FillerCalculationEngine.calculate(
            FillerCalculationInput(
                recessWidth: 1012,
                carcassWidth: 900,
                leftDecorativeSideWidth: 18,
                rightDecorativeSideWidth: 18,
                leftInstallationGap: 2,
                rightInstallationGap: 2,
                mode: .equal
            )
        )

        #expect(result.availableForFillers == 72)
        #expect(result.leftFillerWidth == 36)
        #expect(result.rightFillerWidth == 36)
    }

    @Test
    func customFillerDistributionPreservesTotalWidth() throws {
        let result = try FillerCalculationEngine.calculate(
            FillerCalculationInput(
                recessWidth: 1200,
                carcassWidth: 1000,
                mode: .custom,
                customLeftFillerWidth: 65
            )
        )

        #expect(result.availableForFillers == 200)
        #expect(result.leftFillerWidth == 65)
        #expect(result.rightFillerWidth == 135)
    }

    @Test
    func oversizedConstructionIsRejected() {
        #expect(throws: DomainError.self) {
            _ = try FillerCalculationEngine.calculate(
                FillerCalculationInput(
                    recessWidth: 900,
                    carcassWidth: 900,
                    leftDecorativeSideWidth: 18,
                    rightDecorativeSideWidth: 18
                )
            )
        }
    }

    @Test
    func multiZoneBuiltInKeepsStableComponentIDs() throws {
        let leftSide = try DecorativeSideDefinition(
            code: "ZD-L01",
            side: .left,
            size: Size3MM(width: 18, height: 2600, depth: 600)
        )
        let rightSide = try DecorativeSideDefinition(
            code: "ZD-P01",
            side: .right,
            size: Size3MM(width: 18, height: 2600, depth: 600)
        )
        let openZone = try BuiltInZone(
            name: "Strefa otwarta",
            kind: .open,
            bottomOffset: 700,
            height: 900,
            leftBoundaryComponentID: leftSide.id,
            rightBoundaryComponentID: rightSide.id
        )

        let builtIn = try RecessBuiltInDefinition(
            name: "Zabudowa wnękowa",
            layoutType: .multiZoneBuiltIn,
            recessID: RecessID(),
            leftDecorativeSide: leftSide,
            rightDecorativeSide: rightSide,
            zones: [openZone]
        )

        #expect(builtIn.layoutType == .multiZoneBuiltIn)
        #expect(builtIn.leftDecorativeSide?.id == leftSide.id)
        #expect(builtIn.zones.first?.id == openZone.id)
        #expect(builtIn.facePlane == .decorativePanelFace)
    }

    @Test
    func scribedFillerRequiresProductionWidthAtLeastNominalWidth() {
        #expect(throws: DomainError.self) {
            _ = try ScribeElementDefinition(
                code: "BL-P01",
                type: .sideFiller,
                side: .right,
                nominalWidth: 50,
                productionWidth: 45,
                height: 2400,
                productionAllowance: 5,
                targetGap: 1.5,
                requiresOnSiteScribing: true
            )
        }
    }
}
