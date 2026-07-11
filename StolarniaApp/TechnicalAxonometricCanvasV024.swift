import DomainCore
import SwiftUI

struct TechnicalAxonometricCanvasV024:
    View
{
    let wall: WallSegment
    let assemblies: [FurnitureAssembly]
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
                "Aksonometria techniczna ściany \(wall.name)"
            )
        }
    }

    private func draw(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let boxes = makeBoxes()

        guard !boxes.isEmpty else {
            context.draw(
                Text("Brak modułów na ścianie")
                    .font(.headline)
                    .foregroundColor(.secondary),
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

        let projectedBoxes =
            boxes.map {
                ProjectedBoxV024(
                    source: $0,
                    points:
                        projectedPoints(
                            for: $0,
                            projection:
                                projection
                        )
                )
            }

        let bounds =
            projectedBounds(
                projectedBoxes
            )

        let margin: CGFloat = 44
        let availableWidth =
            max(
                size.width
                - margin * 2,
                1
            )
        let availableHeight =
            max(
                size.height
                - margin * 2,
                1
            )

        let scale =
            min(
                availableWidth
                    / max(
                        bounds.width,
                        1
                    ),
                availableHeight
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
                    availableWidth
                    - bounds.width
                    * scale
                ) / 2,
            y:
                margin
                - bounds.minY
                * scale
                + (
                    availableHeight
                    - bounds.height
                    * scale
                ) / 2
        )

        if settings.showFloorPlane {
            drawFloorPlane(
                context: &context,
                boxes: boxes,
                projection: projection,
                scale: scale,
                offset: offset
            )
        }

        let ordered =
            projectedBoxes.sorted {
                depthKey($0.source)
                < depthKey($1.source)
            }

        for item in ordered {
            drawBox(
                item,
                context: &context,
                scale: scale,
                offset: offset
            )
        }

        if settings.showDimensions {
            drawOverallDimensions(
                context: &context,
                boxes: boxes,
                projection: projection,
                scale: scale,
                offset: offset
            )
        }
    }

    private func makeBoxes()
        -> [AxonometricBoxV024]
    {
        let sorted =
            assemblies.sorted {
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

        return sorted.enumerated()
            .compactMap {
                index,
                assembly in

                guard let placement =
                    assembly.placement
                else {
                    return nil
                }

                return AxonometricBoxV024(
                    minX:
                        placement
                            .offsetAlongWall
                            .rawValue,
                    minY:
                        placement
                            .bottomOffset
                            .rawValue,
                    minZ: 0,
                    width:
                        assembly.size
                            .width.rawValue,
                    height:
                        assembly.size
                            .height.rawValue,
                    depth:
                        assembly.size
                            .depth.rawValue,
                    label:
                        "M\(String(format: "%02d", index + 1))"
                )
            }
    }

    private func projectedPoints(
        for box:
            AxonometricBoxV024,
        projection:
            AxonometricProjectionV024
    ) -> [CGPoint] {
        let x0 = box.minX
        let x1 =
            box.minX + box.width
        let y0 = box.minY
        let y1 =
            box.minY + box.height
        let z0 = box.minZ
        let z1 =
            box.minZ + box.depth

        return [
            projection.project(
                .init(
                    x: x0,
                    y: y0,
                    z: z0
                )
            ),
            projection.project(
                .init(
                    x: x1,
                    y: y0,
                    z: z0
                )
            ),
            projection.project(
                .init(
                    x: x1,
                    y: y1,
                    z: z0
                )
            ),
            projection.project(
                .init(
                    x: x0,
                    y: y1,
                    z: z0
                )
            ),
            projection.project(
                .init(
                    x: x0,
                    y: y0,
                    z: z1
                )
            ),
            projection.project(
                .init(
                    x: x1,
                    y: y0,
                    z: z1
                )
            ),
            projection.project(
                .init(
                    x: x1,
                    y: y1,
                    z: z1
                )
            ),
            projection.project(
                .init(
                    x: x0,
                    y: y1,
                    z: z1
                )
            ),
        ]
    }

    private func projectedBounds(
        _ boxes:
            [ProjectedBoxV024]
    ) -> CGRect {
        let points =
            boxes.flatMap(\.points)

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
                max(maxX - minX, 1),
            height:
                max(maxY - minY, 1)
        )
    }

    private func transformed(
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

    private func drawBox(
        _ item:
            ProjectedBoxV024,
        context:
            inout GraphicsContext,
        scale: CGFloat,
        offset: CGPoint
    ) {
        let p = item.points.map {
            transformed(
                $0,
                scale: scale,
                offset: offset
            )
        }

        drawFace(
            [p[0], p[1], p[2], p[3]],
            fill:
                settings.showFronts
                ? Color(
                    white: 0.94
                )
                : Color.clear,
            context: &context
        )

        drawFace(
            [p[1], p[5], p[6], p[2]],
            fill:
                Color(
                    white: 0.88
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

        if settings.showHiddenEdges {
            drawHiddenEdges(
                p,
                context: &context
            )
        }

        if settings.showModuleNumbers {
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
                Text(item.source.label)
                    .font(
                        .system(
                            size: 11,
                            weight:
                                .semibold,
                            design:
                                .monospaced
                        )
                    )
                    .foregroundColor(.black),
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

        if fill != .clear {
            context.fill(
                path,
                with:
                    .color(fill)
            )
        }

        context.stroke(
            path,
            with:
                .color(.black),
            lineWidth: 1.1
        )
    }

    private func drawHiddenEdges(
        _ points: [CGPoint],
        context:
            inout GraphicsContext
    ) {
        let edges = [
            (points[0], points[4]),
            (points[4], points[5]),
            (points[4], points[7]),
            (points[5], points[6]),
            (points[7], points[6]),
        ]

        for edge in edges {
            var path = Path()
            path.move(
                to: edge.0
            )
            path.addLine(
                to: edge.1
            )

            context.stroke(
                path,
                with:
                    .color(
                        .gray.opacity(
                            0.65
                        )
                    ),
                style:
                    StrokeStyle(
                        lineWidth: 0.8,
                        dash: [5, 4]
                    )
            )
        }
    }

    private func drawFloorPlane(
        context:
            inout GraphicsContext,
        boxes:
            [AxonometricBoxV024],
        projection:
            AxonometricProjectionV024,
        scale: CGFloat,
        offset: CGPoint
    ) {
        let minX =
            boxes.map(\.minX).min()
            ?? 0
        let maxX =
            boxes.map {
                $0.minX
                + $0.width
            }.max() ?? 1
        let maxDepth =
            boxes.map {
                $0.minZ
                + $0.depth
            }.max() ?? 1

        let corners = [
            AxonometricPoint3DV024(
                x: minX,
                y: 0,
                z: 0
            ),
            AxonometricPoint3DV024(
                x: maxX,
                y: 0,
                z: 0
            ),
            AxonometricPoint3DV024(
                x: maxX,
                y: 0,
                z: maxDepth
            ),
            AxonometricPoint3DV024(
                x: minX,
                y: 0,
                z: maxDepth
            ),
        ].map {
            transformed(
                projection.project($0),
                scale: scale,
                offset: offset
            )
        }

        var path = Path()
        path.move(to: corners[0])

        for point in
            corners.dropFirst() {
            path.addLine(to: point)
        }

        path.closeSubpath()

        context.fill(
            path,
            with:
                .color(
                    Color(
                        white: 0.97
                    )
                )
        )

        context.stroke(
            path,
            with:
                .color(
                    .gray.opacity(
                        0.65
                    )
                ),
            lineWidth: 0.8
        )
    }

    private func drawOverallDimensions(
        context:
            inout GraphicsContext,
        boxes:
            [AxonometricBoxV024],
        projection:
            AxonometricProjectionV024,
        scale: CGFloat,
        offset: CGPoint
    ) {
        let minX =
            boxes.map(\.minX).min()
            ?? 0
        let maxX =
            boxes.map {
                $0.minX
                + $0.width
            }.max() ?? 0
        let maxHeight =
            boxes.map {
                $0.minY
                + $0.height
            }.max() ?? 0

        let start = transformed(
            projection.project(
                .init(
                    x: minX,
                    y: -120,
                    z: 0
                )
            ),
            scale: scale,
            offset: offset
        )

        let end = transformed(
            projection.project(
                .init(
                    x: maxX,
                    y: -120,
                    z: 0
                )
            ),
            scale: scale,
            offset: offset
        )

        var widthPath = Path()
        widthPath.move(to: start)
        widthPath.addLine(to: end)

        context.stroke(
            widthPath,
            with:
                .color(.black),
            lineWidth: 0.8
        )

        context.draw(
            Text(
                "\(Int((maxX - minX).rounded())) mm"
            )
            .font(
                .system(
                    size: 10,
                    design:
                        .monospaced
                )
            )
            .foregroundColor(.black),
            at: CGPoint(
                x:
                    (start.x + end.x)
                    / 2,
                y:
                    (start.y + end.y)
                    / 2 - 10
            )
        )

        let heightStart =
            transformed(
                projection.project(
                    .init(
                        x:
                            maxX + 140,
                        y: 0,
                        z: 0
                    )
                ),
                scale: scale,
                offset: offset
            )

        let heightEnd =
            transformed(
                projection.project(
                    .init(
                        x:
                            maxX + 140,
                        y: maxHeight,
                        z: 0
                    )
                ),
                scale: scale,
                offset: offset
            )

        var heightPath = Path()
        heightPath.move(
            to: heightStart
        )
        heightPath.addLine(
            to: heightEnd
        )

        context.stroke(
            heightPath,
            with:
                .color(.black),
            lineWidth: 0.8
        )

        context.draw(
            Text(
                "\(Int(maxHeight.rounded())) mm"
            )
            .font(
                .system(
                    size: 10,
                    design:
                        .monospaced
                )
            )
            .foregroundColor(.black),
            at: CGPoint(
                x:
                    (
                        heightStart.x
                        + heightEnd.x
                    ) / 2
                    + 26,
                y:
                    (
                        heightStart.y
                        + heightEnd.y
                    ) / 2
            )
        )
    }

    private func depthKey(
        _ box:
            AxonometricBoxV024
    ) -> Double {
        box.minX
        + box.minZ
        + box.minY * 0.001
    }
}

private struct ProjectedBoxV024 {
    let source:
        AxonometricBoxV024
    let points: [CGPoint]
}
