import DomainCore
import Foundation

/// Warstwa wysokościowa używana wyłącznie do prezentacji modułów
/// na rzucie pomieszczenia z góry.
enum MebelPlan2DWarstwa: Int, CaseIterable, Hashable {
    case dolna = 0
    case wysoka = 1
    case wiszaca = 2
    case gorna = 3

    var symbol: String {
        switch self {
        case .dolna:
            return "D"
        case .wiszaca:
            return "W"
        case .gorna:
            return "N"
        case .wysoka:
            return "H"
        }
    }
}

struct MebelPlan2DFootprint: Identifiable, Hashable {
    let id: FurnitureAssemblyID
    let wallID: WallID?
    let points: [Point2MM]
    let center: Point2MM
    let layer: MebelPlan2DWarstwa
    let frontOpeningV068:
        KierunekOtwarciaFrontuV068?
}

enum MebelPlan2DGeometry {
    /// Wysokość graniczna, od której mebel stojący traktujemy na rzucie
    /// jako zabudowę wysoką. Docelowo dedykowane buildery słupków i szaf
    /// będą również wpadały do tej warstwy przez `FurnitureAssemblyKind`.
    private static let tallFurnitureThreshold: Millimeters = 1600

    static func footprint(
        for assembly: FurnitureAssembly,
        in room: RoomDefinition,
        roomCenter: Point2MM? = nil
    ) -> MebelPlan2DFootprint? {
        guard let placement = assembly.placement,
              placement.roomID == room.id else {
            return nil
        }

        if placement.wallID == nil
            || placement.anchoringMode == .freestanding {
            return freestandingFootprint(
                for: assembly,
                placement: placement
            )
        }

        guard let wallID = placement.wallID,
              let segment = room.geometry.geometry(of: wallID),
              case .line(let line) = segment else {
            return nil
        }

        let startX = line.start.x.rawValue
        let startY = line.start.y.rawValue
        let endX = line.end.x.rawValue
        let endY = line.end.y.rawValue

        let wallDX = endX - startX
        let wallDY = endY - startY
        let wallLength = hypot(wallDX, wallDY)
        guard wallLength > 0 else {
            return nil
        }

        let directionX = wallDX / wallLength
        let directionY = wallDY / wallLength

        let backStartX = startX
            + directionX * placement.offsetAlongWall.rawValue
        let backStartY = startY
            + directionY * placement.offsetAlongWall.rawValue

        let backEndX = backStartX
            + directionX * assembly.size.width.rawValue
        let backEndY = backStartY
            + directionY * assembly.size.width.rawValue

        let roomCenter = roomCenter ?? centroid(of: room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        })
        let wallMidX = (backStartX + backEndX) / 2
        let wallMidY = (backStartY + backEndY) / 2

        let firstNormal = (x: -directionY, y: directionX)
        let secondNormal = (x: directionY, y: -directionX)
        let towardCenter = (
            x: roomCenter.x.rawValue - wallMidX,
            y: roomCenter.y.rawValue - wallMidY
        )

        let firstDot = firstNormal.x * towardCenter.x
            + firstNormal.y * towardCenter.y
        let inward = firstDot >= 0 ? firstNormal : secondNormal

        let wallOffset = placement.offsetFromWall.rawValue
        let depth = assembly.size.depth.rawValue

        let p0 = point(
            x: backStartX + inward.x * wallOffset,
            y: backStartY + inward.y * wallOffset
        )
        let p1 = point(
            x: backEndX + inward.x * wallOffset,
            y: backEndY + inward.y * wallOffset
        )
        let p2 = point(
            x: backEndX + inward.x * (wallOffset + depth),
            y: backEndY + inward.y * (wallOffset + depth)
        )
        let p3 = point(
            x: backStartX + inward.x * (wallOffset + depth),
            y: backStartY + inward.y * (wallOffset + depth)
        )

        return MebelPlan2DFootprint(
            id: assembly.id,
            wallID: wallID,
            points: [p0, p1, p2, p3],
            center: point(
                x: (p0.x.rawValue + p1.x.rawValue + p2.x.rawValue + p3.x.rawValue) / 4,
                y: (p0.y.rawValue + p1.y.rawValue + p2.y.rawValue + p3.y.rawValue) / 4
            ),
            layer: layer(for: assembly),
            frontOpeningV068:
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .efektywneOtwarcie(
                        dla: assembly
                    )
        )
    }

    private static func freestandingFootprint(
        for assembly:
            FurnitureAssembly,
        placement:
            FurniturePlacement
    ) -> MebelPlan2DFootprint {
        let x = placement.offsetAlongWall.rawValue
        let y = placement.offsetFromWall.rawValue
        let width = assembly.size.width.rawValue
        let depth = assembly.size.depth.rawValue

        let center = point(
            x: x + width / 2,
            y: y + depth / 2
        )
        let rawPoints = [
            point(x: x, y: y),
            point(x: x + width, y: y),
            point(x: x + width, y: y + depth),
            point(x: x, y: y + depth)
        ]

        return MebelPlan2DFootprint(
            id: assembly.id,
            wallID: nil,
            points:
                rotate(
                    rawPoints,
                    around: center,
                    degrees:
                        placement.rotationDegrees
                ),
            center: center,
            layer: layer(for: assembly),
            frontOpeningV068:
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .efektywneOtwarcie(
                        dla: assembly
                    )
        )
    }

    private static func rotate(
        _ points:
            [Point2MM],
        around center:
            Point2MM,
        degrees:
            Double
    ) -> [Point2MM] {
        guard abs(degrees) > 0.01 else {
            return points
        }

        let radians = degrees * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)

        return points.map { pointValue in
            let dx =
                pointValue.x.rawValue
                - center.x.rawValue
            let dy =
                pointValue.y.rawValue
                - center.y.rawValue

            return point(
                x:
                    center.x.rawValue
                    + dx * cosValue
                    - dy * sinValue,
                y:
                    center.y.rawValue
                    + dx * sinValue
                    + dy * cosValue
            )
        }
    }

    /// Zwraca footprinty w kolejności rysowania:
    /// dolne, wysokie, wiszące, górne/nadstawki.
    /// Dzięki temu szafka wisząca pozostaje widoczna nad głębszą szafką dolną,
    /// a hit-test wybiera najwyższą warstwę jako pierwszą.
    ///
    /// Centroid pokoju jest liczony **raz** i przekazywany do każdego
    /// `footprint(for:in:roomCenter:)` — unikamy wielokrotnego flatMap
    /// po segmentach dla każdego mebla osobno.
    static func footprints(
        for assemblies: [FurnitureAssembly],
        in room: RoomDefinition
    ) -> [MebelPlan2DFootprint] {
        let sharedCenter = centroid(of: room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        })
        return assemblies
            .enumerated()
            .compactMap { index, assembly in
                footprint(for: assembly, in: room, roomCenter: sharedCenter).map { (index, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1.layer.rawValue == rhs.1.layer.rawValue {
                    return lhs.0 < rhs.0
                }
                return lhs.1.layer.rawValue < rhs.1.layer.rawValue
            }
            .map(\.1)
    }

    static func layer(
        for assembly: FurnitureAssembly
    ) -> MebelPlan2DWarstwa {
        if let templateID = assembly.templateID,
           let preset =
            StandardKitchenTemplatesV0143
            .preset(for: templateID),
           preset.construction == .topBox
            || preset.tags.contains(
                where: {
                    $0.folding(
                        options: [
                            .caseInsensitive,
                            .diacriticInsensitive
                        ],
                        locale:
                            Locale(identifier: "pl_PL")
                    )
                    == "nadstawka"
                }
            ) {
            return .gorna
        }

        if let placement = assembly.placement,
           placement.bottomOffset.rawValue >= 1_900,
           assembly.size.height.rawValue <= 800 {
            return .gorna
        }

        if assembly.placement?.anchoringMode == .wallMounted {
            return .wiszaca
        }

        switch assembly.kind {
        case .wardrobe, .recessBuiltIn, .slidingWardrobe:
            return .wysoka
        default:
            break
        }

        if assembly.placement?.anchoringMode == .builtIn
            || assembly.size.height >= tallFurnitureThreshold {
            return .wysoka
        }

        // v0.14.3: zabezpieczenie dla starszych rekordów, w których podczas
        // edycji utracono anchoringMode. Moduł o typowej wysokości szafki
        // wiszącej, którego dolna krawędź znajduje się co najmniej 900 mm
        // nad podłogą, nadal trafia do warstwy wiszącej.
        //
        // To jest wyłącznie naprawa prezentacji. Podczas zapisu v0.14.3
        // należy również zachować anchoringMode istniejącego modułu.
        if let placement = assembly.placement,
           placement.bottomOffset.rawValue >= 900,
           assembly.size.height.rawValue <= 1200 {
            return .wiszaca
        }

        return .dolna
    }

    private static func centroid(
        of points: [Point2MM]
    ) -> Point2MM {
        guard !points.isEmpty else {
            return .zero
        }

        let sumX = points.reduce(0) { $0 + $1.x.rawValue }
        let sumY = points.reduce(0) { $0 + $1.y.rawValue }

        return point(
            x: sumX / Double(points.count),
            y: sumY / Double(points.count)
        )
    }

    private static func point(
        x: Double,
        y: Double
    ) -> Point2MM {
        Point2MM(
            x: Millimeters(x),
            y: Millimeters(y)
        )
    }
}
