import DomainCore
import Foundation
import SwiftUI

/// Adapter rzutujący geometrię pomieszczenia z milimetrów na współrzędne ekranu.
/// Nie zmienia modelu domenowego i nie zapisuje żadnych danych.
struct Plan2DProjection {
    let size: CGSize
    let padding: CGFloat
    let scale: CGFloat

    private let modelCenterX: Double
    private let modelCenterY: Double
    private let panOffset: CGSize

    init(
        points: [Point2MM],
        size: CGSize,
        padding: CGFloat = 72,
        zoomScale: CGFloat = 1,
        panOffset: CGSize = .zero
    ) {
        self.size = size
        self.padding = padding
        self.panOffset = panOffset

        let rawMinX = points.map(\.x.rawValue).min() ?? 0
        let rawMaxX = points.map(\.x.rawValue).max() ?? 1
        let rawMinY = points.map(\.y.rawValue).min() ?? 0
        let rawMaxY = points.map(\.y.rawValue).max() ?? 1

        let domainWidth = max(rawMaxX - rawMinX, 1)
        let domainHeight = max(rawMaxY - rawMinY, 1)
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let fitScale = min(
            availableWidth / domainWidth,
            availableHeight / domainHeight
        )

        self.modelCenterX = (rawMinX + rawMaxX) / 2
        self.modelCenterY = (rawMinY + rawMaxY) / 2
        self.scale = fitScale * max(zoomScale, 0.01)
    }

    func screenPoint(_ point: Point2MM) -> CGPoint {
        CGPoint(
            x: size.width / 2
                + panOffset.width
                + (point.x.rawValue - modelCenterX) * scale,
            y: size.height / 2
                + panOffset.height
                - (point.y.rawValue - modelCenterY) * scale
        )
    }
}

/// Wspólne operacje prezentacyjne dla geometrii planu 2D.
enum Plan2DGeometryAdapter {
    static func sampledPoints(
        for segment: ContourSegment2D
    ) -> [Point2MM] {
        switch segment {
        case .line(let line):
            return [line.start, line.end]

        case .arc(let arc):
            let startAngle = atan2(
                arc.start.y.rawValue - arc.center.y.rawValue,
                arc.start.x.rawValue - arc.center.x.rawValue
            )
            let endAngle = atan2(
                arc.end.y.rawValue - arc.center.y.rawValue,
                arc.end.x.rawValue - arc.center.x.rawValue
            )

            var delta = endAngle - startAngle

            if arc.clockwise {
                if delta >= 0 {
                    delta -= 2 * .pi
                }
            } else if delta <= 0 {
                delta += 2 * .pi
            }

            let sampleCount = max(12, Int(abs(delta) / (.pi / 24)))

            return (0...sampleCount).map { index in
                let progress = Double(index) / Double(sampleCount)
                let angle = startAngle + delta * progress

                return Point2MM(
                    x: Millimeters(
                        arc.center.x.rawValue + cos(angle) * arc.radius.rawValue
                    ),
                    y: Millimeters(
                        arc.center.y.rawValue + sin(angle) * arc.radius.rawValue
                    )
                )
            }
        }
    }

    static func distance(
        from point: CGPoint,
        to polyline: [CGPoint]
    ) -> CGFloat {
        guard polyline.count >= 2 else {
            return .greatestFiniteMagnitude
        }

        return zip(polyline, polyline.dropFirst())
            .map { start, end in
                distance(
                    from: point,
                    toSegmentFrom: start,
                    to: end
                )
            }
            .min() ?? .greatestFiniteMagnitude
    }

    private static func distance(
        from point: CGPoint,
        toSegmentFrom start: CGPoint,
        to end: CGPoint
    ) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let projection = (
            (point.x - start.x) * dx
            + (point.y - start.y) * dy
        ) / lengthSquared

        let clamped = min(max(projection, 0), 1)
        let closest = CGPoint(
            x: start.x + clamped * dx,
            y: start.y + clamped * dy
        )

        return hypot(point.x - closest.x, point.y - closest.y)
    }
}
