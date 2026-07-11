import DomainCore
import Foundation
import SwiftUI

struct RoomSurveyCanvasView: View {
    let session: RoomSurveySession
    var wallFeatures: [WallFeaturePayloadV016] = []

    var body: some View {
        GeometryReader { proxy in
            let points = surveyPoints
            let features = surveyFeatureDrawings
            let allPoints = points + features.flatMap(\.points)
            let transform = makeTransform(
                points: allPoints,
                size: proxy.size
            )

            Canvas { context, _ in
                drawSurveyPath(
                    points: points,
                    transform: transform,
                    context: context
                )
                drawClosureGuide(
                    transform: transform,
                    context: context
                )
                drawActiveHeading(
                    transform: transform,
                    context: context
                )
                drawFeatures(
                    features,
                    transform: transform,
                    context: context
                )
            }
            .background(
                Color(
                    red: 0.965,
                    green: 0.957,
                    blue: 0.925
                )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        .black.opacity(0.12),
                        lineWidth: 1
                    )
            }
        }
    }

    private var surveyPoints: [Point2MM] {
        [session.startPoint]
            + session.measuredSegments.map(\.end)
    }

    private var surveyFeatureDrawings:
        [SurveyFeatureDrawingV016] {
        let center = centroid(surveyPoints)

        return wallFeatures.enumerated().compactMap {
            index,
            payload in
            guard let segment =
                session.measuredSegments.first(where: {
                    $0.wallID == payload.wallID
                }),
                let line = try? LineSegment2D(
                    id: segment.id,
                    start: segment.start,
                    end: segment.end
                ) else {
                return nil
            }

            return SurveyFeatureDrawingV016(
                payload: payload,
                code: featureCode(
                    payload.kind,
                    index: index + 1
                ),
                points: WallFeatureGeometryV016.points(
                    for: payload,
                    line: line,
                    roomCenter: center
                )
            )
        }
    }

    private func drawSurveyPath(
        points: [Point2MM],
        transform: (Point2MM) -> CGPoint,
        context: GraphicsContext
    ) {
        guard let firstPoint = points.first else {
            return
        }

        if points.count > 1 {
            var path = Path()
            path.move(to: transform(firstPoint))

            for point in points.dropFirst() {
                path.addLine(to: transform(point))
            }

            context.stroke(
                path,
                with: .color(.primary),
                lineWidth: 3
            )
        }

        for (index, point) in points.enumerated() {
            let display = transform(point)

            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: display.x - 5,
                        y: display.y - 5,
                        width: 10,
                        height: 10
                    )
                ),
                with: .color(
                    index == points.count - 1
                        ? .orange
                        : .oliveSurvey
                )
            )
            context.draw(
                Text("P\(index)")
                    .font(.caption2.monospaced()),
                at: CGPoint(
                    x: display.x + 16,
                    y: display.y - 12
                )
            )
        }
    }

    private func drawClosureGuide(
        transform: (Point2MM) -> CGPoint,
        context: GraphicsContext
    ) {
        guard session.measuredSegments.count >= 2,
              session.closureDistance.rawValue > 2 else {
            return
        }

        let start = transform(session.currentPoint)
        let end = transform(session.startPoint)
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(.orange.opacity(0.78)),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                dash: [8, 6]
            )
        )

        let labelPoint = CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2 - 14
        )
        context.draw(
            Text("do P0 \(formatted(session.closureDistance))")
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.orange),
            at: labelPoint
        )
    }

    private func drawActiveHeading(
        transform: (Point2MM) -> CGPoint,
        context: GraphicsContext
    ) {
        let radians = session.currentHeadingDegrees * .pi / 180
        let previewLength = Millimeters(550)
        let end = Point2MM(
            x: session.currentPoint.x
                + Millimeters(cos(radians) * previewLength.rawValue),
            y: session.currentPoint.y
                + Millimeters(sin(radians) * previewLength.rawValue)
        )
        let startPoint = transform(session.currentPoint)
        let endPoint = transform(end)

        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        context.stroke(
            path,
            with: .color(.oliveSurvey.opacity(0.62)),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                dash: [3, 5]
            )
        )
    }

    private func drawFeatures(
        _ features: [SurveyFeatureDrawingV016],
        transform: (Point2MM) -> CGPoint,
        context: GraphicsContext
    ) {
        for feature in features {
            let points = feature.points.map(transform)
            guard let first = points.first else {
                continue
            }

            let color = featureColor(
                feature.payload.kind
            )
            var path = Path()
            path.move(to: first)

            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            switch feature.payload.kind {
            case .window, .door:
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round,
                        dash: feature.payload.kind == .door
                            ? [7, 4]
                            : []
                    )
                )

            case .recess, .bayProjection:
                path.closeSubpath()
                context.fill(
                    path,
                    with: .color(color.opacity(0.12))
                )
                context.stroke(
                    path,
                    with: .color(color),
                    lineWidth: 2
                )
            }

            let middle = centroid(points)
            context.draw(
                Text(feature.code)
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(color),
                at: middle
            )
        }
    }

    private func featureColor(
        _ kind: WallFeatureKindV016
    ) -> Color {
        switch kind {
        case .window:
            return .blue
        case .door:
            return .brown
        case .recess:
            return .purple
        case .bayProjection:
            return .teal
        }
    }

    private func featureCode(
        _ kind: WallFeatureKindV016,
        index: Int
    ) -> String {
        switch kind {
        case .window:
            return "O\(index)"
        case .door:
            return "D\(index)"
        case .recess:
            return "WN\(index)"
        case .bayProjection:
            return "WY\(index)"
        }
    }

    private func makeTransform(
        points: [Point2MM],
        size: CGSize
    ) -> (Point2MM) -> CGPoint {
        let xs = points.map { $0.x.rawValue }
        let ys = points.map { $0.y.rawValue }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 1
        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)
        let padding: CGFloat = 38
        let scale = min(
            max(
                (size.width - 2 * padding) / width,
                0.01
            ),
            max(
                (size.height - 2 * padding) / height,
                0.01
            )
        )

        return { point in
            CGPoint(
                x: padding
                    + (point.x.rawValue - minX) * scale,
                y: size.height
                    - padding
                    - (point.y.rawValue - minY) * scale
            )
        }
    }

    private func centroid(
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

    private func centroid(
        _ points: [CGPoint]
    ) -> CGPoint {
        guard !points.isEmpty else {
            return .zero
        }

        return CGPoint(
            x: points.reduce(0) {
                $0 + $1.x
            } / CGFloat(points.count),
            y: points.reduce(0) {
                $0 + $1.y
            } / CGFloat(points.count)
        )
    }

    private func formatted(_ value: Millimeters) -> String {
        "\(value.rawValue.formatted(.number.precision(.fractionLength(0...0)))) mm"
    }
}

private struct SurveyFeatureDrawingV016 {
    let payload: WallFeaturePayloadV016
    let code: String
    let points: [Point2MM]
}

private extension Color {
    static let oliveSurvey = Color(
        red: 0.49,
        green: 0.53,
        blue: 0.38
    )
}
