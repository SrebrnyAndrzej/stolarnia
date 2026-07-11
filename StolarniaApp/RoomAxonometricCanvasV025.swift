import DomainCore
import SwiftUI

struct RoomAxonometricCanvasV025:
    View
{
    let room: RoomDefinition
    let assemblies:
        [FurnitureAssembly]
    let cornerDefinitions:
        [CornerCabinetDefinitionV025]
    let settings:
        AxonometricSettingsV024

    var body: some View {
        GeometryReader { proxy in
            Canvas(
                rendersAsynchronously: true
            ) {
                context,
                size in

                draw(
                    context: &context,
                    size: size
                )
            }
            .background(Color.white)
            .accessibilityLabel(
                "Aksonometria całego pomieszczenia"
            )
        }
    }

    private func draw(
        context:
            inout GraphicsContext,
        size: CGSize
    ) {
        let geometry = makeGeometry()

        guard !geometry.boxes.isEmpty
        else {
            context.draw(
                Text(
                    "Brak mebli w pomieszczeniu"
                )
                .font(.headline)
                .foregroundColor(
                    .secondary
                ),
                at: CGPoint(
                    x: size.width / 2,
                    y: size.height / 2
                )
            )
            return
        }

        let projection =
            AxonometricProjectionV024(
                direction:
                    settings.direction,
                depthScale:
                    settings.depthScale,
                verticalScale:
                    settings.verticalScale
            )

        let projected =
            geometry.boxes.map {
                RoomProjectedBoxV025(
                    source: $0,
                    points:
                        project(
                            $0,
                            projection:
                                projection
                        )
                )
            }

        let wallPoints =
            geometry.wallLines.flatMap {
                [
                    projection.project(
                        .init(
                            x: $0.startX,
                            y: 0,
                            z: $0.startZ
                        )
                    ),
                    projection.project(
                        .init(
                            x: $0.endX,
                            y: 0,
                            z: $0.endZ
                        )
                    ),
                ]
            }

        let allPoints =
            projected.flatMap(
                \.points
            )
            + wallPoints

        let bounds =
            boundingRect(
                allPoints
            )

        let margin: CGFloat = 52
        let scale =
            min(
                (
                    size.width
                    - margin * 2
                )
                / max(
                    bounds.width,
                    1
                ),
                (
                    size.height
                    - margin * 2
                )
                / max(
                    bounds.height,
                    1
                )
            )

        let offset = CGPoint(
            x:
                margin
                - bounds.minX
                * scale
                + (
                    size.width
                    - margin * 2
                    - bounds.width
                    * scale
                ) / 2,
            y:
                margin
                - bounds.minY
                * scale
                + (
                    size.height
                    - margin * 2
                    - bounds.height
                    * scale
                ) / 2
        )

        drawRoomBoundary(
            geometry.wallLines,
            projection:
                projection,
            scale: scale,
            offset: offset,
            context: &context
        )

        for item in projected.sorted(
            by: {
                depthKey($0.source)
                < depthKey($1.source)
            }
        ) {
            drawBox(
                item,
                scale: scale,
                offset: offset,
                context: &context
            )
        }
    }

    private func makeGeometry()
        -> RoomGeometryV025
    {
        var boxes:
            [RoomBoxV025] = []
        var walls:
            [RoomWallLineV025] = []

        for wall in
            room.geometry.walls {
            guard let segment =
                room.geometry.geometry(
                    of: wall.id
                )
            else {
                continue
            }

            let start =
                segment.start
            let end =
                segment.end

            walls.append(
                RoomWallLineV025(
                    startX:
                        start.x.rawValue,
                    startZ:
                        start.y.rawValue,
                    endX:
                        end.x.rawValue,
                    endZ:
                        end.y.rawValue
                )
            )

            let dx =
                end.x.rawValue
                - start.x.rawValue
            let dz =
                end.y.rawValue
                - start.y.rawValue
            let length =
                max(
                    hypot(dx, dz),
                    1
                )
            let tangentX =
                dx / length
            let tangentZ =
                dz / length

            let normalX =
                -tangentZ
            let normalZ =
                tangentX

            let wallAssemblies =
                assemblies.filter {
                    $0.placement?
                        .wallID
                        == wall.id
                }

            let sorted =
                wallAssemblies.sorted {
                    (
                        $0.placement?
                            .offsetAlongWall
                            .rawValue
                        ?? 0
                    )
                    <
                    (
                        $1.placement?
                            .offsetAlongWall
                            .rawValue
                        ?? 0
                    )
                }

            for (
                index,
                assembly
            ) in sorted.enumerated() {
                guard let placement =
                    assembly.placement
                else {
                    continue
                }

                let along =
                    placement
                        .offsetAlongWall
                        .rawValue
                let depth =
                    assembly.size
                        .depth.rawValue
                let originX =
                    start.x.rawValue
                    + tangentX * along
                let originZ =
                    start.y.rawValue
                    + tangentZ * along

                let label =
                    "M\(String(format: "%02d", index + 1))"

                if let corner =
                    cornerDefinitions.first(
                        where: {
                            $0.assemblyID
                                == assembly.id
                        }
                    ) {
                    boxes.append(
                        contentsOf:
                            cornerBoxes(
                                corner,
                                originX:
                                    originX,
                                originZ:
                                    originZ,
                                tangentX:
                                    tangentX,
                                tangentZ:
                                    tangentZ,
                                normalX:
                                    normalX,
                                normalZ:
                                    normalZ,
                                bottom:
                                    placement
                                        .bottomOffset
                                        .rawValue,
                                height:
                                    assembly.size
                                        .height.rawValue,
                                label: label
                            )
                    )
                } else {
                    boxes.append(
                        RoomBoxV025(
                            originX:
                                originX,
                            originZ:
                                originZ,
                            tangentX:
                                tangentX,
                            tangentZ:
                                tangentZ,
                            normalX:
                                normalX,
                            normalZ:
                                normalZ,
                            width:
                                assembly.size
                                    .width.rawValue,
                            depth: depth,
                            bottom:
                                placement
                                    .bottomOffset
                                    .rawValue,
                            height:
                                assembly.size
                                    .height.rawValue,
                            label: label
                        )
                    )
                }
            }
        }

        return RoomGeometryV025(
            boxes: boxes,
            wallLines: walls
        )
    }

    private func cornerBoxes(
        _ definition:
            CornerCabinetDefinitionV025,
        originX: Double,
        originZ: Double,
        tangentX: Double,
        tangentZ: Double,
        normalX: Double,
        normalZ: Double,
        bottom: Double,
        height: Double,
        label: String
    ) -> [RoomBoxV025] {
        switch definition.kind {
        case .lShaped:
            let first =
                RoomBoxV025(
                    originX: originX,
                    originZ: originZ,
                    tangentX: tangentX,
                    tangentZ: tangentZ,
                    normalX: normalX,
                    normalZ: normalZ,
                    width:
                        definition
                            .leftArmMM,
                    depth:
                        definition
                            .depthMM,
                    bottom: bottom,
                    height: height,
                    label: label
                )

            let secondOriginX =
                originX
                + tangentX
                * definition.depthMM
            let secondOriginZ =
                originZ
                + tangentZ
                * definition.depthMM

            let second =
                RoomBoxV025(
                    originX:
                        secondOriginX,
                    originZ:
                        secondOriginZ,
                    tangentX:
                        normalX,
                    tangentZ:
                        normalZ,
                    normalX:
                        -tangentX,
                    normalZ:
                        -tangentZ,
                    width:
                        definition
                            .rightArmMM,
                    depth:
                        definition
                            .depthMM,
                    bottom: bottom,
                    height: height,
                    label: ""
                )

            return [
                first,
                second
            ]

        case .diagonalFront:
            return [
                RoomBoxV025(
                    originX: originX,
                    originZ: originZ,
                    tangentX: tangentX,
                    tangentZ: tangentZ,
                    normalX: normalX,
                    normalZ: normalZ,
                    width:
                        max(
                            definition
                                .leftArmMM,
                            definition
                                .rightArmMM
                        ),
                    depth:
                        definition
                            .depthMM,
                    bottom: bottom,
                    height: height,
                    label: label
                )
            ]

        case .blindCorner:
            return [
                RoomBoxV025(
                    originX: originX,
                    originZ: originZ,
                    tangentX: tangentX,
                    tangentZ: tangentZ,
                    normalX: normalX,
                    normalZ: normalZ,
                    width:
                        definition
                            .leftArmMM
                        + definition
                            .deadSpaceMM,
                    depth:
                        definition
                            .depthMM,
                    bottom: bottom,
                    height: height,
                    label: label
                )
            ]

        case .halfBlind:
            // Półnarożnik — pojedyncze pudło o szerokości widocznej części
            return [
                RoomBoxV025(
                    originX: originX,
                    originZ: originZ,
                    tangentX: tangentX,
                    tangentZ: tangentZ,
                    normalX: normalX,
                    normalZ: normalZ,
                    width:
                        definition
                            .leftArmMM,
                    depth:
                        definition
                            .depthMM,
                    bottom: bottom,
                    height: height,
                    label: label
                )
            ]
        }
    }

    private func project(
        _ box:
            RoomBoxV025,
        projection:
            AxonometricProjectionV024
    ) -> [CGPoint] {
        let p0 =
            point(
                box,
                along: 0,
                depth: 0,
                y: box.bottom
            )
        let p1 =
            point(
                box,
                along: box.width,
                depth: 0,
                y: box.bottom
            )
        let p2 =
            point(
                box,
                along: box.width,
                depth: 0,
                y:
                    box.bottom
                    + box.height
            )
        let p3 =
            point(
                box,
                along: 0,
                depth: 0,
                y:
                    box.bottom
                    + box.height
            )
        let p4 =
            point(
                box,
                along: 0,
                depth: box.depth,
                y: box.bottom
            )
        let p5 =
            point(
                box,
                along: box.width,
                depth: box.depth,
                y: box.bottom
            )
        let p6 =
            point(
                box,
                along: box.width,
                depth: box.depth,
                y:
                    box.bottom
                    + box.height
            )
        let p7 =
            point(
                box,
                along: 0,
                depth: box.depth,
                y:
                    box.bottom
                    + box.height
            )

        return [
            p0, p1, p2, p3,
            p4, p5, p6, p7
        ].map {
            projection.project($0)
        }
    }

    private func point(
        _ box: RoomBoxV025,
        along: Double,
        depth: Double,
        y: Double
    ) -> AxonometricPoint3DV024 {
        AxonometricPoint3DV024(
            x:
                box.originX
                + box.tangentX
                * along
                + box.normalX
                * depth,
            y: y,
            z:
                box.originZ
                + box.tangentZ
                * along
                + box.normalZ
                * depth
        )
    }

    private func drawRoomBoundary(
        _ lines:
            [RoomWallLineV025],
        projection:
            AxonometricProjectionV024,
        scale: CGFloat,
        offset: CGPoint,
        context:
            inout GraphicsContext
    ) {
        for line in lines {
            let start =
                transform(
                    projection.project(
                        .init(
                            x:
                                line.startX,
                            y: 0,
                            z:
                                line.startZ
                        )
                    ),
                    scale: scale,
                    offset: offset
                )

            let end =
                transform(
                    projection.project(
                        .init(
                            x:
                                line.endX,
                            y: 0,
                            z:
                                line.endZ
                        )
                    ),
                    scale: scale,
                    offset: offset
                )

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

            context.stroke(
                path,
                with:
                    .color(
                        .gray.opacity(
                            0.7
                        )
                    ),
                lineWidth: 1.2
            )
        }
    }

    private func drawBox(
        _ item:
            RoomProjectedBoxV025,
        scale: CGFloat,
        offset: CGPoint,
        context:
            inout GraphicsContext
    ) {
        let p = item.points.map {
            transform(
                $0,
                scale: scale,
                offset: offset
            )
        }

        drawFace(
            [p[0], p[1], p[2], p[3]],
            fill:
                Color(
                    white: 0.94
                ),
            context: &context
        )

        drawFace(
            [p[1], p[5], p[6], p[2]],
            fill:
                Color(
                    white: 0.87
                ),
            context: &context
        )

        drawFace(
            [p[3], p[2], p[6], p[7]],
            fill:
                Color(
                    white: 0.98
                ),
            context: &context
        )

        if settings.showModuleNumbers,
           !item.source.label.isEmpty {
            let center = CGPoint(
                x:
                    (
                        p[0].x
                        + p[1].x
                        + p[2].x
                        + p[3].x
                    ) / 4,
                y:
                    (
                        p[0].y
                        + p[1].y
                        + p[2].y
                        + p[3].y
                    ) / 4
            )

            context.draw(
                Text(
                    item.source.label
                )
                .font(
                    .system(
                        size: 10,
                        weight:
                            .semibold,
                        design:
                            .monospaced
                    )
                )
                .foregroundColor(
                    .black
                ),
                at: center
            )
        }
    }

    private func drawFace(
        _ points: [CGPoint],
        fill: Color,
        context:
            inout GraphicsContext
    ) {
        guard let first =
            points.first
        else {
            return
        }

        var path = Path()
        path.move(to: first)

        for point in
            points.dropFirst() {
            path.addLine(
                to: point
            )
        }

        path.closeSubpath()

        context.fill(
            path,
            with:
                .color(fill)
        )

        context.stroke(
            path,
            with:
                .color(.black),
            lineWidth: 1
        )
    }

    private func transform(
        _ point: CGPoint,
        scale: CGFloat,
        offset: CGPoint
    ) -> CGPoint {
        CGPoint(
            x:
                point.x * scale
                + offset.x,
            y:
                point.y * scale
                + offset.y
        )
    }

    private func boundingRect(
        _ points: [CGPoint]
    ) -> CGRect {
        let minX =
            points.map(\.x).min()
            ?? 0
        let maxX =
            points.map(\.x).max()
            ?? 1
        let minY =
            points.map(\.y).min()
            ?? 0
        let maxY =
            points.map(\.y).max()
            ?? 1

        return CGRect(
            x: minX,
            y: minY,
            width:
                max(
                    maxX - minX,
                    1
                ),
            height:
                max(
                    maxY - minY,
                    1
                )
        )
    }

    private func depthKey(
        _ box:
            RoomBoxV025
    ) -> Double {
        box.originX
        + box.originZ
        + box.bottom * 0.001
    }
}

private struct RoomGeometryV025 {
    let boxes: [RoomBoxV025]
    let wallLines:
        [RoomWallLineV025]
}

private struct RoomWallLineV025 {
    let startX: Double
    let startZ: Double
    let endX: Double
    let endZ: Double
}

private struct RoomBoxV025 {
    let originX: Double
    let originZ: Double
    let tangentX: Double
    let tangentZ: Double
    let normalX: Double
    let normalZ: Double
    let width: Double
    let depth: Double
    let bottom: Double
    let height: Double
    let label: String
}

private struct RoomProjectedBoxV025 {
    let source:
        RoomBoxV025
    let points: [CGPoint]
}
