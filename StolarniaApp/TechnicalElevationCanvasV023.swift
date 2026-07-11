import DomainCore
import SwiftUI

struct TechnicalElevationCanvasV023:
    View
{
    let document:
        TechnicalDrawingDocumentV023
    let mode:
        TechnicalDrawingModeV023
    let visibleLayers:
        Set<TechnicalDrawingLayerV023>
    let selectedInstallationPointID:
        UUID?

    var style =
        TechnicalDrawingStyleV023()

    var body: some View {
        GeometryReader { proxy in
            Canvas(
                rendersAsynchronously: true
            ) { context, size in
                draw(
                    context: &context,
                    size: size
                )
            }
            .background(Color.white)
            .overlay(alignment: .topLeading) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(12)
            }
            .accessibilityLabel(
                "Rysunek techniczny: \(document.title)"
            )
        }
    }

    private func draw(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let transform =
            drawingTransform(size: size)

        drawWall(
            context: &context,
            transform: transform
        )

        if visibleLayers.contains(.carcasses) {
            drawAssemblies(
                context: &context,
                transform: transform
            )
        }

        if visibleLayers.contains(.dimensions),
           mode != .simplified {
            drawAutomaticDimensions(
                context: &context,
                transform: transform
            )

            drawCustomDimensions(
                context: &context,
                transform: transform
            )
        }

        if visibleLayers.contains(.installations),
           mode == .installations {
            drawInstallationPoints(
                context: &context,
                transform: transform
            )
        }

        drawFloorLevel(
            context: &context,
            transform: transform
        )
    }

    private func drawingTransform(
        size: CGSize
    ) -> DrawingTransformV023 {
        let availableWidth =
            max(
                size.width
                - style.margin * 2,
                1
            )

        let availableHeight =
            max(
                size.height
                - style.margin * 2,
                1
            )

        let scaleX =
            availableWidth
            / document.contentWidthMM

        let scaleY =
            availableHeight
            / document.contentHeightMM

        return DrawingTransformV023(
            scale: min(scaleX, scaleY),
            origin: CGPoint(
                x: style.margin,
                y:
                    size.height
                    - style.margin
            )
        )
    }

    private func drawWall(
        context: inout GraphicsContext,
        transform: DrawingTransformV023
    ) {
        let rect = transform.rect(
            xMM: 0,
            bottomMM: 0,
            widthMM:
                document.contentWidthMM,
            heightMM:
                document.contentHeightMM
        )

        context.stroke(
            Path(rect),
            with: .color(.black),
            lineWidth:
                style.majorLineWidth
        )
    }

    private func drawAssemblies(
        context: inout GraphicsContext,
        transform: DrawingTransformV023
    ) {
        let sorted =
            document.assemblies.sorted {
                let left =
                    $0.placement?
                        .offsetAlongWall
                        .rawValue ?? 0
                let right =
                    $1.placement?
                        .offsetAlongWall
                        .rawValue ?? 0
                return left < right
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

            let xMM =
                placement.offsetAlongWall
                    .rawValue
            let bottomMM =
                placement.bottomOffset
                    .rawValue
            let widthMM =
                assembly.size.width
                    .rawValue
            let heightMM =
                assembly.size.height
                    .rawValue

            let rect = transform.rect(
                xMM: xMM,
                bottomMM: bottomMM,
                widthMM: widthMM,
                heightMM: heightMM
            )

            context.fill(
                Path(rect),
                with:
                    .color(
                        Color(
                            white:
                                mode == .simplified
                                ? 0.91
                                : 0.97
                        )
                    )
            )

            context.stroke(
                Path(rect),
                with: .color(.black),
                lineWidth:
                    style.majorLineWidth
            )

            if mode == .technical
                || mode == .production {
                drawAssemblyComponents(
                    assembly,
                    in: rect,
                    context: &context
                )
            }

            if visibleLayers.contains(.labels) {
                let label = Text(
                    "M\(String(format: "%02d", index + 1))"
                )
                .font(
                    .system(
                        size:
                            style.labelFontSize,
                        weight: .semibold,
                        design: .monospaced
                    )
                )
                .foregroundColor(.black)

                context.draw(
                    label,
                    at: CGPoint(
                        x: rect.midX,
                        y: rect.midY
                    )
                )
            }

            if visibleLayers.contains(.dimensions),
               mode != .simplified {
                drawHorizontalDimension(
                    context: &context,
                    transform: transform,
                    startMM: xMM,
                    endMM: xMM + widthMM,
                    levelMM:
                        bottomMM - 90,
                    text:
                        "\(Int(widthMM.rounded()))"
                )
            }
        }
    }

    private func drawAssemblyComponents(
        _ assembly: FurnitureAssembly,
        in rect: CGRect,
        context: inout GraphicsContext
    ) {
        let count = max(
            assembly.components.count,
            1
        )

        guard count > 1 else {
            let centerLine =
                Path {
                    path in
                    path.move(
                        to: CGPoint(
                            x: rect.midX,
                            y: rect.minY
                        )
                    )
                    path.addLine(
                        to: CGPoint(
                            x: rect.midX,
                            y: rect.maxY
                        )
                    )
                }

            context.stroke(
                centerLine,
                with:
                    .color(
                        .gray.opacity(0.55)
                    ),
                lineWidth:
                    style.minorLineWidth
            )
            return
        }

        let visibleLineCount =
            min(count - 1, 8)

        for index in 1...visibleLineCount {
            let y =
                rect.minY
                + rect.height
                * CGFloat(index)
                / CGFloat(
                    visibleLineCount + 1
                )

            var line = Path()
            line.move(
                to: CGPoint(
                    x: rect.minX,
                    y: y
                )
            )
            line.addLine(
                to: CGPoint(
                    x: rect.maxX,
                    y: y
                )
            )

            context.stroke(
                line,
                with:
                    .color(
                        .gray.opacity(0.55)
                    ),
                lineWidth:
                    style.minorLineWidth
            )
        }
    }

    private func drawAutomaticDimensions(
        context: inout GraphicsContext,
        transform: DrawingTransformV023
    ) {
        drawHorizontalDimension(
            context: &context,
            transform: transform,
            startMM: 0,
            endMM:
                document.contentWidthMM,
            levelMM: -220,
            text:
                "\(Int(document.contentWidthMM.rounded()))"
        )

        drawVerticalDimension(
            context: &context,
            transform: transform,
            startMM: 0,
            endMM:
                document.contentHeightMM,
            xMM:
                document.contentWidthMM
                + 170,
            text:
                "\(Int(document.contentHeightMM.rounded()))"
        )
    }

    private func drawCustomDimensions(
        context: inout GraphicsContext,
        transform: DrawingTransformV023
    ) {
        for dimension in document.dimensions {
            switch dimension.kind {
            case .horizontal,
                 .chain,
                 .overall:
                drawHorizontalDimension(
                    context: &context,
                    transform: transform,
                    startMM:
                        dimension.start.xMM,
                    endMM:
                        dimension.end.xMM,
                    levelMM:
                        dimension.start.yMM
                        + dimension.offsetMM,
                    text:
                        dimension.displayText
                )

            case .vertical,
                 .elevationLevel:
                drawVerticalDimension(
                    context: &context,
                    transform: transform,
                    startMM:
                        dimension.start.yMM,
                    endMM:
                        dimension.end.yMM,
                    xMM:
                        dimension.start.xMM
                        + dimension.offsetMM,
                    text:
                        dimension.displayText
                )

            case .aligned,
                 .angular:
                drawAlignedDimension(
                    context: &context,
                    transform: transform,
                    dimension: dimension
                )
            }
        }
    }

    private func drawInstallationPoints(
        context: inout GraphicsContext,
        transform: DrawingTransformV023
    ) {
        for point in
            document.installationPoints {
            let center = transform.point(
                xMM:
                    point.offsetAlongWallMM,
                yMM:
                    point.heightFromFloorMM
            )

            let selected =
                point.id
                == selectedInstallationPointID

            let radius: CGFloat =
                selected ? 10 : 7

            let ellipse = Path(
                ellipseIn: CGRect(
                    x:
                        center.x - radius,
                    y:
                        center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )

            context.fill(
                ellipse,
                with:
                    .color(
                        selected
                        ? .orange
                        : .white
                    )
            )

            context.stroke(
                ellipse,
                with: .color(.black),
                lineWidth:
                    selected ? 2 : 1
            )

            let symbol = Text(
                point.kind.symbol
            )
            .font(
                .system(
                    size: 10,
                    weight: .bold
                )
            )
            .foregroundColor(.black)

            context.draw(
                symbol,
                at: center
            )

            let noteText =
                point.note.isEmpty
                ? point.kind.title
                : point.note

            let label = Text(
                "\(noteText)\n\(Int(point.heightFromFloorMM.rounded())) mm"
            )
            .font(
                .system(
                    size: 9
                )
            )
            .foregroundColor(.black)

            context.draw(
                label,
                at: CGPoint(
                    x: center.x + 12,
                    y: center.y - 16
                ),
                anchor: .leading
            )
        }
    }

    private func drawFloorLevel(
        context: inout GraphicsContext,
        transform: DrawingTransformV023
    ) {
        let start = transform.point(
            xMM: 0,
            yMM: 0
        )

        let end = transform.point(
            xMM:
                document.contentWidthMM,
            yMM: 0
        )

        var floor = Path()
        floor.move(to: start)
        floor.addLine(to: end)

        context.stroke(
            floor,
            with: .color(.black),
            lineWidth: 2
        )
    }

    private func drawHorizontalDimension(
        context: inout GraphicsContext,
        transform: DrawingTransformV023,
        startMM: Double,
        endMM: Double,
        levelMM: Double,
        text: String
    ) {
        let start = transform.point(
            xMM: startMM,
            yMM: levelMM
        )
        let end = transform.point(
            xMM: endMM,
            yMM: levelMM
        )

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(.black),
            lineWidth:
                style.dimensionLineWidth
        )

        drawArrow(
            context: &context,
            point: start,
            direction: 1
        )

        drawArrow(
            context: &context,
            point: end,
            direction: -1
        )

        let label = Text(text)
            .font(
                .system(
                    size:
                        style.dimensionFontSize,
                    design: .monospaced
                )
            )
            .foregroundColor(.black)

        context.draw(
            label,
            at: CGPoint(
                x: (start.x + end.x) / 2,
                y: start.y - 9
            )
        )
    }

    private func drawVerticalDimension(
        context: inout GraphicsContext,
        transform: DrawingTransformV023,
        startMM: Double,
        endMM: Double,
        xMM: Double,
        text: String
    ) {
        let start = transform.point(
            xMM: xMM,
            yMM: startMM
        )
        let end = transform.point(
            xMM: xMM,
            yMM: endMM
        )

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(.black),
            lineWidth:
                style.dimensionLineWidth
        )

        let label = Text(text)
            .font(
                .system(
                    size:
                        style.dimensionFontSize,
                    design: .monospaced
                )
            )
            .foregroundColor(.black)

        context.draw(
            label,
            at: CGPoint(
                x: start.x + 15,
                y: (start.y + end.y) / 2
            )
        )
    }

    private func drawAlignedDimension(
        context: inout GraphicsContext,
        transform: DrawingTransformV023,
        dimension:
            DimensionAnnotationV023
    ) {
        let start = transform.point(
            xMM: dimension.start.xMM,
            yMM: dimension.start.yMM
        )
        let end = transform.point(
            xMM: dimension.end.xMM,
            yMM: dimension.end.yMM
        )

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(.black),
            lineWidth:
                style.dimensionLineWidth
        )

        let label = Text(
            dimension.displayText
        )
        .font(
            .system(
                size:
                    style.dimensionFontSize,
                design: .monospaced
            )
        )
        .foregroundColor(.black)

        context.draw(
            label,
            at: CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2 - 9
            )
        )
    }

    private func drawArrow(
        context: inout GraphicsContext,
        point: CGPoint,
        direction: CGFloat
    ) {
        var arrow = Path()
        arrow.move(to: point)
        arrow.addLine(
            to: CGPoint(
                x:
                    point.x
                    + direction
                    * style.arrowSize,
                y:
                    point.y
                    - style.arrowSize / 2
            )
        )
        arrow.addLine(
            to: CGPoint(
                x:
                    point.x
                    + direction
                    * style.arrowSize,
                y:
                    point.y
                    + style.arrowSize / 2
            )
        )
        arrow.closeSubpath()

        context.fill(
            arrow,
            with: .color(.black)
        )
    }
}

private struct DrawingTransformV023 {
    let scale: CGFloat
    let origin: CGPoint

    func point(
        xMM: Double,
        yMM: Double
    ) -> CGPoint {
        CGPoint(
            x:
                origin.x
                + CGFloat(xMM) * scale,
            y:
                origin.y
                - CGFloat(yMM) * scale
        )
    }

    func rect(
        xMM: Double,
        bottomMM: Double,
        widthMM: Double,
        heightMM: Double
    ) -> CGRect {
        let bottomLeft = point(
            xMM: xMM,
            yMM: bottomMM
        )

        return CGRect(
            x: bottomLeft.x,
            y:
                bottomLeft.y
                - CGFloat(heightMM) * scale,
            width:
                CGFloat(widthMM) * scale,
            height:
                CGFloat(heightMM) * scale
        )
    }
}
