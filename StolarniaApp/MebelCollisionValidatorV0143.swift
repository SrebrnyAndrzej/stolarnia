import DomainCore
import Foundation

/// Walidator przestrzenny v0.14.3.
///
/// Najważniejsza zmiana: podczas edycji pomija rekord o ID edytowanego
/// modułu. Sam kandydat jest także zawsze pomijany po `candidate.id`.
///
/// Kolizja zachodzi tylko wtedy, gdy bryły mają dodatnie przecięcie
/// jednocześnie:
/// - wzdłuż ściany,
/// - w głąb pomieszczenia,
/// - w pionie.
///
/// Styk krawędzi (np. szafki ustawione dokładnie obok siebie) nie jest
/// traktowany jako kolizja.
enum MebelCollisionValidatorV0143 {
    private static let toleranceMM = 0.1

    static func firstCollision(
        for candidate: FurnitureAssembly,
        excluding editedAssemblyID: FurnitureAssemblyID? = nil,
        among existingAssemblies: [FurnitureAssembly]
    ) -> FurnitureAssembly? {
        guard let candidateBounds = bounds(for: candidate) else {
            return nil
        }

        return existingAssemblies.first { existing in
            guard existing.id != candidate.id else {
                return false
            }

            if let editedAssemblyID,
               existing.id == editedAssemblyID {
                return false
            }

            guard let existingBounds = bounds(for: existing),
                  existingBounds.roomID == candidateBounds.roomID,
                  existingBounds.wallID == candidateBounds.wallID else {
                return false
            }

            return overlaps(candidateBounds.alongWall, existingBounds.alongWall)
                && overlaps(candidateBounds.fromWall, existingBounds.fromWall)
                && overlaps(candidateBounds.vertical, existingBounds.vertical)
        }
    }

    static func collides(
        _ candidate: FurnitureAssembly,
        excluding editedAssemblyID: FurnitureAssemblyID? = nil,
        among existingAssemblies: [FurnitureAssembly]
    ) -> Bool {
        firstCollision(
            for: candidate,
            excluding: editedAssemblyID,
            among: existingAssemblies
        ) != nil
    }

    /// Zwraca zbiór ID wszystkich modułów, które kolidują z co najmniej jednym innym modułem.
    /// Używane do wizualizacji kolizji w canvasie elewacji — bez blokowania zapisu.
    static func allCollidingIDs(
        among assemblies: [FurnitureAssembly]
    ) -> Set<FurnitureAssemblyID> {
        var result = Set<FurnitureAssemblyID>()

        // O(n²) — wystarczające dla typowego ciągu 5-20 szafek
        for i in assemblies.indices {
            for j in (i + 1)..<assemblies.count {
                let a = assemblies[i]
                let b = assemblies[j]

                guard let boundsA = bounds(for: a),
                      let boundsB = bounds(for: b),
                      boundsA.roomID == boundsB.roomID,
                      boundsA.wallID == boundsB.wallID else {
                    continue
                }

                if overlaps(boundsA.alongWall, boundsB.alongWall)
                    && overlaps(boundsA.fromWall, boundsB.fromWall)
                    && overlaps(boundsA.vertical, boundsB.vertical) {
                    result.insert(a.id)
                    result.insert(b.id)
                }
            }
        }

        return result
    }

    private static func bounds(
        for assembly: FurnitureAssembly
    ) -> Bounds? {
        guard let placement = assembly.placement,
              let wallID = placement.wallID else {
            return nil
        }

        let alongStart = placement.offsetAlongWall.rawValue
        let depthStart = placement.offsetFromWall.rawValue
        let verticalStart = placement.bottomOffset.rawValue

        return Bounds(
            roomID: placement.roomID,
            wallID: wallID,
            alongWall: orderedRange(
                alongStart,
                alongStart + assembly.size.width.rawValue
            ),
            fromWall: orderedRange(
                depthStart,
                depthStart + assembly.size.depth.rawValue
            ),
            vertical: orderedRange(
                verticalStart,
                verticalStart + assembly.size.height.rawValue
            )
        )
    }

    private static func orderedRange(
        _ first: Double,
        _ second: Double
    ) -> ClosedRange<Double> {
        min(first, second)...max(first, second)
    }

    private static func overlaps(
        _ lhs: ClosedRange<Double>,
        _ rhs: ClosedRange<Double>
    ) -> Bool {
        let overlapStart = max(lhs.lowerBound, rhs.lowerBound)
        let overlapEnd = min(lhs.upperBound, rhs.upperBound)

        return overlapEnd - overlapStart > toleranceMM
    }

    private struct Bounds {
        let roomID: RoomID
        let wallID: WallID
        let alongWall: ClosedRange<Double>
        let fromWall: ClosedRange<Double>
        let vertical: ClosedRange<Double>
    }
}
