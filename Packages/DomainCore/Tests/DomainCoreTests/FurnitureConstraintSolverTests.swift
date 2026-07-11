import Foundation
import Testing
@testable import DomainCore

struct FurnitureConstraintSolverTests {

    // Pomocnik: prosty komponent w płaszczyźnie czołowej (głębokość stała 18).
    private func makeComponent(
        code: String,
        role: FurnitureComponentRole = .front,
        width: Millimeters,
        height: Millimeters,
        x: Millimeters,
        y: Millimeters
    ) throws -> FurnitureComponent {
        try FurnitureComponent(
            code: code,
            role: role,
            size: Size3MM(width: width, height: height, depth: 18),
            localPosition: Point3MM(x: x, y: y, z: .zero)
        )
    }

    private func assembly(
        components: [FurnitureComponent],
        constraints: [FurnitureConstraint]
    ) throws -> FurnitureAssembly {
        try FurnitureAssembly(
            name: "Test",
            kind: .cabinet,
            size: Size3MM(width: 600, height: 720, depth: 560),
            components: components,
            constraints: constraints
        )
    }

    @Test
    func emptyConstraintsReturnUnchangedAndConverged() throws {
        let front = try makeComponent(code: "FRONT", width: 596, height: 700, x: 2, y: 10)
        let asm = try assembly(components: [front], constraints: [])
        let result = try FurnitureConstraintSolver.solve(asm)
        #expect(result.didConverge)
        #expect(result.iterations == 0)
        #expect(result.assembly.component(id: front.id)?.localPosition.x == 2)
    }

    @Test
    func alignRightPlacesComponentFlushToReferenceRightEdge() throws {
        // Referencja: front 596 szer. od x=2 → prawa krawędź = 598.
        let ref = try makeComponent(code: "FRONT", width: 596, height: 700, x: 2, y: 10)
        // Uchwyt 128 szer., start gdziekolwiek — po więzie prawa krawędź = 598 → x = 470.
        let handle = try makeComponent(code: "UCHWYT", role: .custom, width: 128, height: 20, x: 0, y: 40)
        let asm = try assembly(
            components: [ref, handle],
            constraints: [.alignRight(componentID: handle.id, referenceID: ref.id)]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        let solvedHandle = try #require(result.assembly.component(id: handle.id))
        #expect(solvedHandle.localPosition.x == 470)   // 598 - 128
        #expect(result.didConverge)
    }

    @Test
    func centerHorizontalCentersComponentOnReference() throws {
        let front = try makeComponent(code: "FRONT", width: 600, height: 700, x: 0, y: 0)
        let handle = try makeComponent(code: "UCHWYT", role: .custom, width: 128, height: 20, x: 0, y: 300)
        let asm = try assembly(
            components: [front, handle],
            constraints: [.centerHorizontal(componentID: handle.id, referenceID: front.id)]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        let solved = try #require(result.assembly.component(id: handle.id))
        #expect(solved.localPosition.x == 236)   // (600 - 128) / 2
    }

    @Test
    func fixedGapPlacesSecondColumnAfterFirstWithGap() throws {
        // Dwa fronty w kolumnach: pierwszy 300 szer. od x=0, szczelina 3 → drugi x=303.
        let left = try makeComponent(code: "L", width: 300, height: 700, x: 0, y: 0)
        let right = try makeComponent(code: "P", width: 297, height: 700, x: 0, y: 0)
        let asm = try assembly(
            components: [left, right],
            constraints: [.fixedGap(firstID: left.id, secondID: right.id, value: 3)]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        let solved = try #require(result.assembly.component(id: right.id))
        #expect(solved.localPosition.x == 303)
    }

    @Test
    func equalWidthSetsEachToGroupAverage() throws {
        // Szerokości 100/200/300 → średnia 200.
        let a = try makeComponent(code: "A", width: 100, height: 200, x: 0, y: 0)
        let b = try makeComponent(code: "B", width: 200, height: 200, x: 0, y: 0)
        let c = try makeComponent(code: "C", width: 300, height: 200, x: 0, y: 0)
        let asm = try assembly(
            components: [a, b, c],
            constraints: [.equalWidth(componentIDs: [a.id, b.id, c.id])]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        #expect(result.assembly.component(id: a.id)?.size.width == 200)
        #expect(result.assembly.component(id: b.id)?.size.width == 200)
        #expect(result.assembly.component(id: c.id)?.size.width == 200)
    }

    @Test
    func equalSpacingDistributesWithEqualGaps() throws {
        // Trzy elementy po 100 szer. Pierwszy x=0, ostatni prawa krawędź = 500.
        // Span = 500, suma szer. = 300, wolne = 200, szczelina = 100.
        // Pozycje: 0, 200, 400.
        let a = try makeComponent(code: "A", width: 100, height: 50, x: 0, y: 0)
        let b = try makeComponent(code: "B", width: 100, height: 50, x: 150, y: 0)
        let c = try makeComponent(code: "C", width: 100, height: 50, x: 400, y: 0)
        let asm = try assembly(
            components: [a, b, c],
            constraints: [.equalSpacing(componentIDs: [a.id, b.id, c.id])]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        #expect(result.assembly.component(id: a.id)?.localPosition.x == 0)
        #expect(result.assembly.component(id: b.id)?.localPosition.x == 200)
        #expect(result.assembly.component(id: c.id)?.localPosition.x == 400)
    }

    @Test
    func offsetPositionsRelativeToReference() throws {
        let ref = try makeComponent(code: "REF", width: 100, height: 100, x: 50, y: 60)
        let dep = try makeComponent(code: "DEP", width: 40, height: 40, x: 0, y: 0)
        let asm = try assembly(
            components: [ref, dep],
            constraints: [.offset(
                componentID: dep.id,
                referenceID: ref.id,
                value: Vector2MM(dx: 10, dy: 20)
            )]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        let solved = try #require(result.assembly.component(id: dep.id))
        #expect(solved.localPosition.x == 60)   // 50 + 10
        #expect(solved.localPosition.y == 80)   // 60 + 20
    }

    @Test
    func chainedConstraintsConverge() throws {
        // A wyrównany do lewej B; B z offsetem od C. Kolejność w tablicy "zła"
        // (A przed B), ale przebiegi relaksacji doprowadzają do stabilizacji.
        let c = try makeComponent(code: "C", width: 100, height: 100, x: 200, y: 0)
        let b = try makeComponent(code: "B", width: 100, height: 100, x: 0, y: 0)
        let a = try makeComponent(code: "A", width: 40, height: 40, x: 0, y: 0)
        let asm = try assembly(
            components: [a, b, c],
            constraints: [
                .alignLeft(componentID: a.id, referenceID: b.id),
                .offset(componentID: b.id, referenceID: c.id, value: Vector2MM(dx: -150, dy: 0))
            ]
        )
        let result = try FurnitureConstraintSolver.solve(asm)
        // B = C.x - 150 = 50; A wyrównany do lewej B = 50.
        #expect(result.assembly.component(id: b.id)?.localPosition.x == 50)
        #expect(result.assembly.component(id: a.id)?.localPosition.x == 50)
        #expect(result.didConverge)
    }

    @Test
    func unknownComponentIDThrows() throws {
        let a = try makeComponent(code: "A", width: 100, height: 100, x: 0, y: 0)
        let ghost = ComponentID()
        let asm = try assembly(
            components: [a],
            constraints: [.alignLeft(componentID: a.id, referenceID: ghost)]
        )
        #expect(throws: DomainError.self) {
            try FurnitureConstraintSolver.solve(asm)
        }
    }
}
