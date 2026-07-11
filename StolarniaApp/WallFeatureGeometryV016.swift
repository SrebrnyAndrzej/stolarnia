import DomainCore
import Foundation

enum WallFeaturePlanKindV016: Hashable {
    case window
    case door
    case recess
    case bayOutward
    case bayInward
}

struct WallFeaturePlanElementV016: Identifiable, Hashable {
    let id: String
    let kind: WallFeaturePlanKindV016
    let code: String
    let linePoints: [Point2MM]
    let polygonPoints: [Point2MM]
    let labelPoint: Point2MM
}

enum WallFeatureGeometryV016 {
    static func elements(
        in room: RoomDefinition
    ) -> [WallFeaturePlanElementV016] {
        let center = centroid(
            room.geometry.boundary.segments.flatMap {
                Plan2DGeometryAdapter.sampledPoints(for: $0)
            }
        )

        var result: [WallFeaturePlanElementV016] = []

        for (index, window) in room.windows.enumerated() {
            guard let basis = basis(
                wallID: window.placement.wallID,
                room: room,
                roomCenter: center
            ) else {
                continue
            }

            let p0 = point(
                basis: basis,
                offset: window.placement.offsetFromWallStart,
                normalOffset: .zero
            )
            let p1 = point(
                basis: basis,
                offset: window.placement.offsetFromWallStart
                    + window.placement.width,
                normalOffset: .zero
            )

            result.append(
                WallFeaturePlanElementV016(
                    id: "window-\(window.id.description)",
                    kind: .window,
                    code: "O\(index + 1)",
                    linePoints: [p0, p1],
                    polygonPoints: [],
                    labelPoint: point(
                        basis: basis,
                        offset: window.placement.offsetFromWallStart
                            + window.placement.width / 2,
                        normalOffset: 85
                    )
                )
            )
        }

        for (index, door) in room.doors.enumerated() {
            guard let basis = basis(
                wallID: door.placement.wallID,
                room: room,
                roomCenter: center
            ) else {
                continue
            }

            let p0 = point(
                basis: basis,
                offset: door.placement.offsetFromWallStart,
                normalOffset: .zero
            )
            let p1 = point(
                basis: basis,
                offset: door.placement.offsetFromWallStart
                    + door.placement.width,
                normalOffset: .zero
            )

            result.append(
                WallFeaturePlanElementV016(
                    id: "door-\(door.id.description)",
                    kind: .door,
                    code: "D\(index + 1)",
                    linePoints: [p0, p1],
                    polygonPoints: [],
                    labelPoint: point(
                        basis: basis,
                        offset: door.placement.offsetFromWallStart
                            + door.placement.width / 2,
                        normalOffset: 105
                    )
                )
            )
        }

        for (index, recess) in room.recesses.enumerated() {
            guard let basis = basis(
                wallID: recess.wallID,
                room: room,
                roomCenter: center
            ) else {
                continue
            }

            let bounds = localBounds(
                contour: recess.openingContour
            )
            let polygon = rectangle(
                basis: basis,
                offset: bounds.x,
                width: bounds.width,
                depth: recess.depth,
                towardRoom: false
            )

            result.append(
                WallFeaturePlanElementV016(
                    id: "recess-\(recess.id.description)",
                    kind: .recess,
                    code: "WN\(index + 1)",
                    linePoints: [],
                    polygonPoints: polygon,
                    labelPoint: centroid(polygon)
                )
            )
        }

        for (index, bay) in room.bayProjections.enumerated() {
            guard let basis = basis(
                wallID: bay.wallID,
                room: room,
                roomCenter: center
            ) else {
                continue
            }

            let towardRoom = bay.direction == .inward
            let polygon = rectangle(
                basis: basis,
                offset: bay.offsetFromWallStart,
                width: bay.width,
                depth: bay.depth,
                towardRoom: towardRoom
            )

            result.append(
                WallFeaturePlanElementV016(
                    id: "bay-\(bay.id.description)",
                    kind: towardRoom
                        ? .bayInward
                        : .bayOutward,
                    code: "WY\(index + 1)",
                    linePoints: [],
                    polygonPoints: polygon,
                    labelPoint: centroid(polygon)
                )
            )
        }

        return result
    }

    static func points(
        for payload: WallFeaturePayloadV016,
        line: LineSegment2D,
        roomCenter: Point2MM
    ) -> [Point2MM] {
        let basis = basis(
            line: line,
            roomCenter: roomCenter
        )
        let rect = payload.localRect

        switch payload {
        case .window, .door:
            return [
                point(
                    basis: basis,
                    offset: rect.x,
                    normalOffset: .zero
                ),
                point(
                    basis: basis,
                    offset: rect.x + rect.width,
                    normalOffset: .zero
                )
            ]

        case .recess:
            return rectangle(
                basis: basis,
                offset: rect.x,
                width: rect.width,
                depth: rect.depth,
                towardRoom: false
            )

        case .bayProjection(let bay):
            return rectangle(
                basis: basis,
                offset: rect.x,
                width: rect.width,
                depth: rect.depth,
                towardRoom: bay.direction == .inward
            )
        }
    }

    private struct Basis {
        let start: Point2MM
        let directionX: Double
        let directionY: Double
        let inwardX: Double
        let inwardY: Double
    }

    private static func basis(
        wallID: WallID,
        room: RoomDefinition,
        roomCenter: Point2MM
    ) -> Basis? {
        guard let segment = room.geometry.geometry(of: wallID),
              case .line(let line) = segment else {
            return nil
        }

        return basis(
            line: line,
            roomCenter: roomCenter
        )
    }

    private static func basis(
        line: LineSegment2D,
        roomCenter: Point2MM
    ) -> Basis {
        let dx = line.end.x.rawValue
            - line.start.x.rawValue
        let dy = line.end.y.rawValue
            - line.start.y.rawValue
        let length = max(hypot(dx, dy), 0.001)
        let directionX = dx / length
        let directionY = dy / length
        let firstNormalX = -directionY
        let firstNormalY = directionX
        let middleX = (
            line.start.x.rawValue
            + line.end.x.rawValue
        ) / 2
        let middleY = (
            line.start.y.rawValue
            + line.end.y.rawValue
        ) / 2
        let dot = firstNormalX
            * (roomCenter.x.rawValue - middleX)
            + firstNormalY
            * (roomCenter.y.rawValue - middleY)
        let inwardX = dot >= 0
            ? firstNormalX
            : -firstNormalX
        let inwardY = dot >= 0
            ? firstNormalY
            : -firstNormalY

        return Basis(
            start: line.start,
            directionX: directionX,
            directionY: directionY,
            inwardX: inwardX,
            inwardY: inwardY
        )
    }

    private static func rectangle(
        basis: Basis,
        offset: Millimeters,
        width: Millimeters,
        depth: Millimeters,
        towardRoom: Bool
    ) -> [Point2MM] {
        let signedDepth = towardRoom
            ? depth
            : Millimeters(-depth.rawValue)

        return [
            point(
                basis: basis,
                offset: offset,
                normalOffset: .zero
            ),
            point(
                basis: basis,
                offset: offset + width,
                normalOffset: .zero
            ),
            point(
                basis: basis,
                offset: offset + width,
                normalOffset: signedDepth
            ),
            point(
                basis: basis,
                offset: offset,
                normalOffset: signedDepth
            )
        ]
    }

    private static func point(
        basis: Basis,
        offset: Millimeters,
        normalOffset: Millimeters
    ) -> Point2MM {
        Point2MM(
            x: Millimeters(
                basis.start.x.rawValue
                    + basis.directionX * offset.rawValue
                    + basis.inwardX * normalOffset.rawValue
            ),
            y: Millimeters(
                basis.start.y.rawValue
                    + basis.directionY * offset.rawValue
                    + basis.inwardY * normalOffset.rawValue
            )
        )
    }

    private static func localBounds(
        contour: ClosedContour2D
    ) -> WallFeatureLocalRectV016 {
        let points = contour.segments.flatMap {
            [$0.start, $0.end]
        }
        let minX = points.map(\.x).min() ?? .zero
        let maxX = points.map(\.x).max() ?? minX
        let minY = points.map(\.y).min() ?? .zero
        let maxY = points.map(\.y).max() ?? minY

        return WallFeatureLocalRectV016(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY,
            depth: .zero
        )
    }

    private static func centroid(
        _ points: [Point2MM]
    ) -> Point2MM {
        guard !points.isEmpty else {
            return .zero
        }

        return Point2MM(
            x: Millimeters(
                points.reduce(0) {
                    $0 + $1.x.rawValue
                } / Double(points.count)
            ),
            y: Millimeters(
                points.reduce(0) {
                    $0 + $1.y.rawValue
                } / Double(points.count)
            )
        )
    }
}
