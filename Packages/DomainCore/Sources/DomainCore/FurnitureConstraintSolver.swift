import Foundation

/// Rozwiązuje więzy parametryczne (`FurnitureConstraint`) zapisane w `FurnitureAssembly`,
/// przeliczając pozycje i gabaryty komponentów tak, aby spełniały zadeklarowane relacje.
///
/// Do tej pory `FurnitureConstraint` był modelem martwym — więzy były zapisywane
/// i kopiowane (`EdycjaModulowV065`), ale nic ich nie egzekwowało. Ten solver
/// aktywuje ten model: to rdzeń projektowania parametrycznego w stylu PRO100/ArchiCAD,
/// gdzie zmiana jednej wartości re-solvuje układ.
///
/// Konwencja współrzędnych (zgodna z `CabinetComponentFactory`):
/// `localPosition` to róg **minimalny** bryły (dolny-lewy-przód). Origin (0,0,0)
/// to dolny-lewy-przód zespołu. Oś X = szerokość, Y = wysokość, Z = głębokość.
/// Więzy działają w płaszczyźnie czołowej (X/Y) — głębokość (Z) pozostaje nietknięta.
public enum FurnitureConstraintSolver {

    /// Wynik solvera: przeliczony zespół + informacja o zbieżności.
    public struct Result: Sendable {
        public var assembly: FurnitureAssembly
        /// `true`, jeśli układ ustabilizował się w ramach limitu iteracji.
        public var didConverge: Bool
        /// Liczba wykonanych przebiegów relaksacji.
        public var iterations: Int
    }

    /// Domyślny limit przebiegów relaksacji. Więzy są stosowane sekwencyjnie,
    /// a przebiegi powtarzane aż do stabilizacji, więc kolejność deklaracji
    /// ma mniejsze znaczenie.
    public static let defaultMaxIterations = 12

    /// Przelicza zespół tak, aby spełniał swoje więzy.
    /// - Throws: `DomainError.invariantViolation`, gdy więz wskazuje na nieistniejący komponent
    ///   lub gdy przeliczenie dałoby niedodatni gabaryt.
    public static func solve(
        _ assembly: FurnitureAssembly,
        maxIterations: Int = defaultMaxIterations
    ) throws -> Result {
        guard !assembly.constraints.isEmpty else {
            return Result(assembly: assembly, didConverge: true, iterations: 0)
        }

        var components = assembly.components
        var indexByID = Dictionary(
            uniqueKeysWithValues: components.enumerated().map { ($0.element.id, $0.offset) }
        )

        var converged = false
        var iterationsRun = 0

        for iteration in 1...max(maxIterations, 1) {
            iterationsRun = iteration
            let before = components
            for constraint in assembly.constraints {
                try apply(constraint, to: &components, indexByID: indexByID)
            }
            // Indeksy się nie zmieniają (nie dodajemy/usuwamy komponentów),
            // ale odświeżamy dla czytelności inwariantu.
            indexByID = Dictionary(
                uniqueKeysWithValues: components.enumerated().map { ($0.element.id, $0.offset) }
            )
            if components == before {
                converged = true
                break
            }
        }

        let solved = try assembly.replacingComponents(components)
        return Result(assembly: solved, didConverge: converged, iterations: iterationsRun)
    }

    // MARK: - Zastosowanie pojedynczego więzu

    private static func apply(
        _ constraint: FurnitureConstraint,
        to components: inout [FurnitureComponent],
        indexByID: [ComponentID: Int]
    ) throws {
        switch constraint {

        case let .alignLeft(componentID, referenceID):
            let ref = try component(referenceID, components, indexByID)
            try mutate(componentID, &components, indexByID) { $0.localPosition.x = ref.localPosition.x }

        case let .alignRight(componentID, referenceID):
            let ref = try component(referenceID, components, indexByID)
            let refRight = ref.localPosition.x + ref.size.width
            try mutate(componentID, &components, indexByID) {
                $0.localPosition.x = refRight - $0.size.width
            }

        case let .alignBottom(componentID, referenceID):
            let ref = try component(referenceID, components, indexByID)
            try mutate(componentID, &components, indexByID) { $0.localPosition.y = ref.localPosition.y }

        case let .alignTop(componentID, referenceID):
            let ref = try component(referenceID, components, indexByID)
            let refTop = ref.localPosition.y + ref.size.height
            try mutate(componentID, &components, indexByID) {
                $0.localPosition.y = refTop - $0.size.height
            }

        case let .centerHorizontal(componentID, referenceID):
            let ref = try component(referenceID, components, indexByID)
            try mutate(componentID, &components, indexByID) {
                $0.localPosition.x = ref.localPosition.x + (ref.size.width - $0.size.width) * 0.5
            }

        case let .centerVertical(componentID, referenceID):
            let ref = try component(referenceID, components, indexByID)
            try mutate(componentID, &components, indexByID) {
                $0.localPosition.y = ref.localPosition.y + (ref.size.height - $0.size.height) * 0.5
            }

        case let .fixedGap(firstID, secondID, value):
            // Interpretacja czołowa: stała szczelina pozioma między kolumnami
            // (drugi komponent siada za pierwszym z zadaną przerwą).
            let first = try component(firstID, components, indexByID)
            let targetX = first.localPosition.x + first.size.width + value
            try mutate(secondID, &components, indexByID) { $0.localPosition.x = targetX }

        case let .offset(componentID, referenceID, value):
            let ref = try component(referenceID, components, indexByID)
            try mutate(componentID, &components, indexByID) {
                $0.localPosition.x = ref.localPosition.x + value.dx
                $0.localPosition.y = ref.localPosition.y + value.dy
            }

        case let .equalWidth(componentIDs):
            try equalize(componentIDs, &components, indexByID, axis: .width)

        case let .equalHeight(componentIDs):
            try equalize(componentIDs, &components, indexByID, axis: .height)

        case let .equalSpacing(componentIDs):
            try distributeEqualSpacing(componentIDs, &components, indexByID)

        case .sharedPartition:
            // Więz strukturalny (współdzielona ścianka między podzespołami),
            // nie geometryczny — nie zmienia pozycji w tym solverze.
            break
        }
    }

    // MARK: - Grupowe

    private enum Axis { case width, height }

    /// Ustawia jednakowy wymiar (szerokość/wysokość) dla grupy — wartość docelowa
    /// to średnia z grupy (zachowuje sumaryczny gabaryt lepiej niż kopiowanie pierwszego).
    private static func equalize(
        _ ids: [ComponentID],
        _ components: inout [FurnitureComponent],
        _ indexByID: [ComponentID: Int],
        axis: Axis
    ) throws {
        guard ids.count > 1 else { return }
        let sizes = try ids.map { id -> Millimeters in
            let c = try component(id, components, indexByID)
            return axis == .width ? c.size.width : c.size.height
        }
        let sum = sizes.reduce(Millimeters.zero, +)
        let target = sum / Double(ids.count)
        guard target > .zero else {
            throw DomainError.invariantViolation("Więz jednakowego wymiaru dałby niedodatni gabaryt.")
        }
        for id in ids {
            try mutate(id, &components, indexByID) {
                if axis == .width { $0.size.width = target } else { $0.size.height = target }
            }
        }
    }

    /// Rozkłada komponenty w poziomie z równymi szczelinami, zachowując lewą
    /// krawędź pierwszego i prawą krawędź ostatniego (po posortowaniu wg X).
    private static func distributeEqualSpacing(
        _ ids: [ComponentID],
        _ components: inout [FurnitureComponent],
        _ indexByID: [ComponentID: Int]
    ) throws {
        guard ids.count > 2 else { return }
        let items = try ids.map { try component($0, components, indexByID) }
            .sorted { $0.localPosition.x < $1.localPosition.x }

        guard let first = items.first, let last = items.last else { return }
        let spanLeft = first.localPosition.x
        let spanRight = last.localPosition.x + last.size.width
        let totalWidth = items.reduce(Millimeters.zero) { $0 + $1.size.width }
        let free = (spanRight - spanLeft) - totalWidth
        let gap = free / Double(items.count - 1)

        var cursor = spanLeft
        for item in items {
            let id = item.id
            try mutate(id, &components, indexByID) { $0.localPosition.x = cursor }
            cursor = cursor + item.size.width + gap
        }
    }

    // MARK: - Pomocnicze

    private static func component(
        _ id: ComponentID,
        _ components: [FurnitureComponent],
        _ indexByID: [ComponentID: Int]
    ) throws -> FurnitureComponent {
        guard let idx = indexByID[id] else {
            throw DomainError.invariantViolation("Więz wskazuje na nieistniejący ComponentID.")
        }
        return components[idx]
    }

    private static func mutate(
        _ id: ComponentID,
        _ components: inout [FurnitureComponent],
        _ indexByID: [ComponentID: Int],
        _ transform: (inout FurnitureComponent) -> Void
    ) throws {
        guard let idx = indexByID[id] else {
            throw DomainError.invariantViolation("Więz wskazuje na nieistniejący ComponentID.")
        }
        transform(&components[idx])
        guard components[idx].size.isValid else {
            throw DomainError.invariantViolation("Więz dałby komponent o niedodatnim gabarycie.")
        }
    }
}

// MARK: - Bezpieczna podmiana komponentów w zespole

public extension FurnitureAssembly {
    /// Zwraca kopię zespołu z podmienioną listą komponentów, zachowując pozostałe
    /// pola i przechodząc pełną walidację inwariantów `FurnitureAssembly`.
    func replacingComponents(_ newComponents: [FurnitureComponent]) throws -> FurnitureAssembly {
        try FurnitureAssembly(
            id: id,
            templateID: templateID,
            name: name,
            kind: kind,
            size: size,
            components: newComponents,
            subassemblies: subassemblies,
            constraints: constraints,
            placement: placement
        )
    }
}
