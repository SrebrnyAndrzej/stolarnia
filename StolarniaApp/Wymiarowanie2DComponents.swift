import Foundation
import SwiftUI

/// Poziom informacji pokazywany na planie i elewacji.
///
/// Ustawienie jest współdzielone przez wszystkie widoki 2D. Dzięki temu
/// użytkownik nie musi osobno konfigurować planu, elewacji i pełnego ekranu.
enum PoziomWymiarowania2D: String, CaseIterable, Identifiable, Hashable {
    case ukryte
    case podstawowe
    case szczegolowe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ukryte:
            return "Bez wymiarów"
        case .podstawowe:
            return "Podstawowe"
        case .szczegolowe:
            return "Szczegółowe"
        }
    }

    var shortTitle: String {
        switch self {
        case .ukryte:
            return "Ukryte"
        case .podstawowe:
            return "Podstawowe"
        case .szczegolowe:
            return "Szczegółowe"
        }
    }

    var systemImage: String {
        switch self {
        case .ukryte:
            return "ruler.fill"
        case .podstawowe:
            return "ruler"
        case .szczegolowe:
            return "ruler.fill"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .ukryte:
            return "Ukrywa linie i etykiety wymiarowe"
        case .podstawowe:
            return "Pokazuje gabaryty oraz wymiary zaznaczonego elementu"
        case .szczegolowe:
            return "Pokazuje gabaryty, moduły i otwory"
        }
    }
}

enum Wymiarowanie2DUstawienia {
    static let poziomAppStorageKey =
        "stolarnia.wymiarowanie2d.poziom"
}

/// Wspólna kontrolka używana w planie, elewacji i widoku pełnoekranowym.
struct KontrolkaPoziomuWymiarowania2D: View {
    @Binding var poziom: PoziomWymiarowania2D

    var body: some View {
        Menu {
            Picker("Zakres wymiarów", selection: $poziom) {
                ForEach(PoziomWymiarowania2D.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        } label: {
            Label(
                poziom.shortTitle,
                systemImage: poziom.systemImage
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(poziom.accessibilityDescription)
        .accessibilityLabel("Zakres wymiarów")
        .accessibilityValue(poziom.title)
    }
}

enum WyroznienieWymiaru2D: Equatable {
    case standardowe
    case zaznaczone
    case pomocnicze
}

/// Jeden renderer linii wymiarowej dla planu i elewacji.
///
/// Rysuje linie pomocnicze, linię główną, groty oraz kontrastową kapsułę.
/// Wartość jest zawsze pozioma, również przy wymiarze pionowym, co poprawia
/// czytelność na iPadzie i nie wymaga obracania urządzenia.
enum Wymiarowanie2DRenderer {
    static func drawLinearDimension(
        in context: GraphicsContext,
        sourceStart: CGPoint,
        sourceEnd: CGPoint,
        offset: CGVector,
        label: String,
        emphasis: WyroznienieWymiaru2D = .standardowe,
        showsLabel: Bool = true
    ) {
        let lineStart = translated(sourceStart, by: offset)
        let lineEnd = translated(sourceEnd, by: offset)
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = max(hypot(dx, dy), 0.001)
        let direction = CGVector(
            dx: dx / length,
            dy: dy / length
        )
        let normal = CGVector(
            dx: -direction.dy,
            dy: direction.dx
        )
        let color = color(for: emphasis)
        let lineWidth: CGFloat = emphasis == .zaznaczone
            ? 1.6
            : 1.05

        let offsetLength = max(hypot(offset.dx, offset.dy), 0.001)
        let offsetDirection = CGVector(
            dx: offset.dx / offsetLength,
            dy: offset.dy / offsetLength
        )
        let extensionGap: CGFloat = 4
        let extensionOvershoot: CGFloat = 5

        var path = Path()
        path.move(
            to: translated(
                sourceStart,
                by: scaled(offsetDirection, extensionGap)
            )
        )
        path.addLine(
            to: translated(
                lineStart,
                by: scaled(offsetDirection, extensionOvershoot)
            )
        )
        path.move(
            to: translated(
                sourceEnd,
                by: scaled(offsetDirection, extensionGap)
            )
        )
        path.addLine(
            to: translated(
                lineEnd,
                by: scaled(offsetDirection, extensionOvershoot)
            )
        )
        path.move(to: lineStart)
        path.addLine(to: lineEnd)

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )

        drawArrow(
            in: context,
            tip: lineStart,
            pointingAlong: direction,
            normal: normal,
            color: color,
            lineWidth: lineWidth
        )
        drawArrow(
            in: context,
            tip: lineEnd,
            pointingAlong: CGVector(
                dx: -direction.dx,
                dy: -direction.dy
            ),
            normal: normal,
            color: color,
            lineWidth: lineWidth
        )

        guard showsLabel else { return }

        let midpoint = CGPoint(
            x: (lineStart.x + lineEnd.x) / 2,
            y: (lineStart.y + lineEnd.y) / 2
        )
        drawLabel(
            in: context,
            text: label,
            at: midpoint,
            emphasis: emphasis
        )
    }

    static func drawLabel(
        in context: GraphicsContext,
        text: String,
        at point: CGPoint,
        emphasis: WyroznienieWymiaru2D = .standardowe
    ) {
        let size = labelSize(for: text)
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let labelHeight = size.height
        let shape = Path(
            roundedRect: rect,
            cornerRadius: labelHeight / 2
        )
        let color = color(for: emphasis)

        context.drawLayer { layer in
            layer.addFilter(
                .shadow(
                    color: Color.black.opacity(0.16),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            )
            layer.fill(
                shape,
                with: .color(
                    StolarniaPalette
                        .drawingLabelFill
                )
            )
        }

        context.stroke(
            shape,
            with: .color(color.opacity(0.28)),
            lineWidth: 0.8
        )
        context.draw(
            Text(text)
                .font(
                    .caption
                        .monospacedDigit()
                        .weight(.semibold)
                )
                .foregroundStyle(color),
            at: point,
            anchor: .center
        )
    }

    static func hasRoomForLabel(
        _ label: String,
        start: CGPoint,
        end: CGPoint,
        minimumPadding: CGFloat = 10
    ) -> Bool {
        let lineLength = hypot(
            end.x - start.x,
            end.y - start.y
        )
        let estimatedLabelWidth = labelSize(
            for: label
        ).width
        return lineLength >= estimatedLabelWidth + minimumPadding
    }

    static func labelSize(
        for text: String
    ) -> CGSize {
        CGSize(
            width: min(
                max(CGFloat(text.count) * 7.1 + 18, 56),
                154
            ),
            height: 27
        )
    }

    static func labelCenter(
        sourceStart: CGPoint,
        sourceEnd: CGPoint,
        offset: CGVector
    ) -> CGPoint {
        CGPoint(
            x:
                (sourceStart.x + sourceEnd.x) / 2
                + offset.dx,
            y:
                (sourceStart.y + sourceEnd.y) / 2
                + offset.dy
        )
    }

    static func labelRect(
        text: String,
        center: CGPoint,
        hitPadding: CGFloat = 8
    ) -> CGRect {
        let size = labelSize(for: text)
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        .insetBy(
            dx: -hitPadding,
            dy: -hitPadding
        )
    }

    static func contains(
        point: CGPoint,
        label: String,
        center: CGPoint
    ) -> Bool {
        labelRect(
            text: label,
            center: center
        )
        .contains(point)
    }

    private static func drawArrow(
        in context: GraphicsContext,
        tip: CGPoint,
        pointingAlong direction: CGVector,
        normal: CGVector,
        color: Color,
        lineWidth: CGFloat
    ) {
        let arrowLength: CGFloat = 8
        let arrowHalfWidth: CGFloat = 3.5
        let base = translated(
            tip,
            by: scaled(direction, arrowLength)
        )
        let first = translated(
            base,
            by: scaled(normal, arrowHalfWidth)
        )
        let second = translated(
            base,
            by: scaled(normal, -arrowHalfWidth)
        )

        var arrow = Path()
        arrow.move(to: first)
        arrow.addLine(to: tip)
        arrow.addLine(to: second)

        context.stroke(
            arrow,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private static func color(
        for emphasis: WyroznienieWymiaru2D
    ) -> Color {
        switch emphasis {
        case .standardowe:
            return StolarniaPalette
                .drawingInk
                .opacity(0.86)
        case .zaznaczone:
            return .accentColor
        case .pomocnicze:
            return StolarniaPalette
                .drawingMutedInk
                .opacity(0.78)
        }
    }

    private static func translated(
        _ point: CGPoint,
        by vector: CGVector
    ) -> CGPoint {
        CGPoint(
            x: point.x + vector.dx,
            y: point.y + vector.dy
        )
    }

    private static func scaled(
        _ vector: CGVector,
        _ factor: CGFloat
    ) -> CGVector {
        CGVector(
            dx: vector.dx * factor,
            dy: vector.dy * factor
        )
    }
}
