import Foundation
import Testing
@testable import DomainCore

struct CabinetBuildersTests {
    @Test
    func systemTemplateIDsAreStable() {
        #expect(
            SystemFurnitureTemplates.baseCabinetID.description
                == "b1500000-0000-4000-8000-000000000001"
        )
        #expect(
            SystemFurnitureTemplates.wallCabinetID.description
                == "b1500000-0000-4000-8000-000000000002"
        )
    }

    @Test
    func baseCabinetBuilderCreatesExpectedCarcass() throws {
        let template = try SystemFurnitureTemplates.baseCabinet()
        let assembly = try BaseCabinetBuilder().build(template: template)

        #expect(assembly.templateID == SystemFurnitureTemplates.baseCabinetID)
        #expect(assembly.size == Size3MM(width: 600, height: 720, depth: 560))
        #expect(assembly.component(code: "BOK-L")?.size == Size3MM(width: 18, height: 720, depth: 560))
        #expect(assembly.component(code: "BOK-P")?.localPosition.x == 582)
        #expect(assembly.component(code: "WIENIEC-D")?.size.width == 564)
        #expect(assembly.component(code: "WZM-G-P") != nil)
        #expect(assembly.component(code: "WZM-G-T") != nil)
        #expect(assembly.component(code: "WIENIEC-G") == nil)
        #expect(assembly.component(code: "POLKA-01") != nil)
        #expect(assembly.component(code: "PLECY")?.size.depth == 3)
        #expect(assembly.component(code: "FRONT-01")?.size.width == 596)
    }

    @Test
    func wallCabinetBuilderCreatesFullTopAndTwoShelves() throws {
        let template = try SystemFurnitureTemplates.wallCabinet()
        let assembly = try WallCabinetBuilder().build(template: template)

        #expect(assembly.component(code: "WIENIEC-G") != nil)
        #expect(assembly.component(code: "WZM-G-P") == nil)
        #expect(assembly.component(code: "POLKA-01") != nil)
        #expect(assembly.component(code: "POLKA-02") != nil)
        #expect(assembly.component(code: "POLKA-03") == nil)
        #expect(assembly.component(code: "WIENIEC-D")?.size.depth == 320)
    }

    @Test
    func shortenedFingerPullReducesAndMovesBottomPanel() throws {
        let template = try SystemFurnitureTemplates.wallCabinet()
        let overrides = try FurnitureParameterSet(entries: [
            .init(
                key: .openingTechnology,
                value: .openingTechnology(.shortenedBottomFingerPull)
            )
        ])

        let assembly = try WallCabinetBuilder().build(
            template: template,
            parameters: overrides
        )
        let bottom = try #require(assembly.component(code: "WIENIEC-D"))

        #expect(bottom.size.depth == 290)
        #expect(bottom.localPosition.z == 30)
    }

    @Test
    func changingWidthRecalculatesDependentComponentsAndPreservesIDs() throws {
        let template = try SystemFurnitureTemplates.baseCabinet()
        let builder = BaseCabinetBuilder()
        let original = try builder.build(template: template)
        let originalLeftSideID = try #require(original.component(code: "BOK-L")?.id)
        let originalBottomID = try #require(original.component(code: "WIENIEC-D")?.id)

        let overrides = try FurnitureParameterSet(entries: [
            .init(key: .width, value: .millimeters(800))
        ])
        let rebuilt = try builder.build(
            template: template,
            parameters: overrides,
            preservingIDsFrom: original
        )

        #expect(rebuilt.id == original.id)
        #expect(rebuilt.component(code: "BOK-L")?.id == originalLeftSideID)
        #expect(rebuilt.component(code: "WIENIEC-D")?.id == originalBottomID)
        #expect(rebuilt.component(code: "BOK-P")?.localPosition.x == 782)
        #expect(rebuilt.component(code: "WIENIEC-D")?.size.width == 764)
        #expect(rebuilt.component(code: "FRONT-01")?.size.width == 796)
    }

    @Test
    func rebuildPreservesPlacement() throws {
        let template = try SystemFurnitureTemplates.baseCabinet()
        let builder = BaseCabinetBuilder()
        let initial = try builder.build(template: template)
        let placement = try FurniturePlacement(
            roomID: RoomID(),
            wallID: WallID(),
            assemblyID: initial.id,
            offsetAlongWall: 125,
            anchoringMode: .floorStanding
        )
        let placed = try FurnitureAssembly(
            id: initial.id,
            templateID: initial.templateID,
            name: initial.name,
            kind: initial.kind,
            size: initial.size,
            components: initial.components,
            subassemblies: initial.subassemblies,
            constraints: initial.constraints,
            placement: placement
        )

        let rebuilt = try builder.build(
            template: template,
            parameters: FurnitureParameterSet(),
            preservingIDsFrom: placed
        )

        #expect(rebuilt.placement?.id == placement.id)
        #expect(rebuilt.placement?.offsetAlongWall == 125)
        #expect(rebuilt.placement?.assemblyID == rebuilt.id)
    }

    @Test
    func unsupportedParameterIsRejectedByTemplate() throws {
        let template = try SystemFurnitureTemplates.baseCabinet()
        let overrides = try FurnitureParameterSet(entries: [
            .init(key: .bottomShortening, value: .integer(30))
        ])

        #expect(throws: DomainError.self) {
            _ = try BaseCabinetBuilder().build(
                template: template,
                parameters: overrides
            )
        }
    }

    @Test
    func cabinetRejectsWidthSmallerThanTwoSidePanels() throws {
        let template = try SystemFurnitureTemplates.baseCabinet()
        let overrides = try FurnitureParameterSet(entries: [
            .init(key: .width, value: .millimeters(30))
        ])

        #expect(throws: DomainError.self) {
            _ = try BaseCabinetBuilder().build(
                template: template,
                parameters: overrides
            )
        }
    }
}
