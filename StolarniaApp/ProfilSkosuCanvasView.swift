import SwiftUI

struct ProfilSkosuCanvasView:
    View
{
    let pomiar:
        PomiarGarderobySkosy

    private let padding:
        CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            let points =
                normalizedPoints(
                    in: proxy.size
                )

            ZStack {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    .regularMaterial
                )

                grid(
                    size: proxy.size
                )

                if points.count >= 2 {
                    profileArea(
                        points: points,
                        size: proxy.size
                    )

                    profileLine(
                        points: points
                    )

                    pointLabels(
                        points: points
                    )
                } else {
                    ContentUnavailableView(
                        "Brak danych profilu",
                        systemImage:
                            "triangle.righthalf.filled",
                        description: Text(
                            "Dodaj co najmniej dwa punkty pomiarowe."
                        )
                    )
                }

                dimensionLabels(
                    size: proxy.size
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.10),
                    lineWidth: 1
                )
            }
        }
        .frame(
            minHeight: 320
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            accessibilityDescription
        )
    }

    private func grid(
        size: CGSize
    ) -> some View {
        Canvas { context, canvasSize in
            var path = Path()

            let columns = 10
            let rows = 8

            for index in 0...columns {
                let x =
                    padding
                    + (
                        canvasSize.width
                        - padding * 2
                    )
                    * CGFloat(index)
                    / CGFloat(columns)

                path.move(
                    to: CGPoint(
                        x: x,
                        y: padding
                    )
                )

                path.addLine(
                    to: CGPoint(
                        x: x,
                        y:
                            canvasSize.height
                            - padding
                    )
                )
            }

            for index in 0...rows {
                let y =
                    padding
                    + (
                        canvasSize.height
                        - padding * 2
                    )
                    * CGFloat(index)
                    / CGFloat(rows)

                path.move(
                    to: CGPoint(
                        x: padding,
                        y: y
                    )
                )

                path.addLine(
                    to: CGPoint(
                        x:
                            canvasSize.width
                            - padding,
                        y: y
                    )
                )
            }

            context.stroke(
                path,
                with:
                    .color(
                        Color.primary
                            .opacity(0.07)
                    ),
                lineWidth: 1
            )
        }
    }

    private func profileArea(
        points:
            [ProfilePoint],
        size: CGSize
    ) -> some View {
        Path { path in
            guard let first = points.first,
                  let last = points.last
            else {
                return
            }

            path.move(
                to: CGPoint(
                    x: first.position.x,
                    y:
                        size.height
                        - padding
                )
            )

            path.addLine(
                to: first.position
            )

            for point in points.dropFirst() {
                path.addLine(
                    to: point.position
                )
            }

            path.addLine(
                to: CGPoint(
                    x: last.position.x,
                    y:
                        size.height
                        - padding
                )
            )

            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    StolarniaPalette
                        .accent
                        .opacity(0.28),
                    StolarniaPalette
                        .accentStrong
                        .opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func profileLine(
        points:
            [ProfilePoint]
    ) -> some View {
        Path { path in
            guard let first = points.first
            else {
                return
            }

            path.move(
                to: first.position
            )

            for point in points.dropFirst() {
                path.addLine(
                    to: point.position
                )
            }
        }
        .stroke(
            StolarniaPalette
                .accentStrong,
            style: StrokeStyle(
                lineWidth: 4,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func pointLabels(
        points:
            [ProfilePoint]
    ) -> some View {
        ForEach(points) { point in
            VStack(spacing: 4) {
                Circle()
                    .fill(
                        StolarniaPalette
                            .accentStrong
                    )
                    .frame(
                        width: 14,
                        height: 14
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white,
                                lineWidth: 2
                            )
                    }

                Text(
                    "\(formatted(point.source.odlegloscOdLewejMM)) / \(formatted(point.source.wysokoscMM))"
                )
                .font(
                    .caption2
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .primary
                )
                .padding(
                    .horizontal,
                    6
                )
                .padding(
                    .vertical,
                    3
                )
                .background(
                    .thinMaterial,
                    in:
                        Capsule()
                )
            }
            .position(
                point.position
            )
        }
    }

    private func dimensionLabels(
        size: CGSize
    ) -> some View {
        VStack {
            HStack {
                Text(
                    "H max: \(formatted(pomiar.maksymalnaWysokoscZMiarMM)) mm"
                )

                Spacer()

                if let angle =
                    pomiar
                        .przyblizonyKatSkosuStopnie {
                    Text(
                        "Kąt: \(angle.formatted(.number.precision(.fractionLength(1))))°"
                    )
                }
            }

            Spacer()

            HStack {
                Text("0 mm")
                Spacer()
                Text(
                    "\(formatted(pomiar.szerokoscScianyMM)) mm"
                )
            }
        }
        .font(
            .caption
                .weight(.semibold)
        )
        .foregroundStyle(
            .secondary
        )
        .padding(
            .horizontal,
            padding
        )
        .padding(
            .vertical,
            12
        )
        .allowsHitTesting(false)
    }

    private func normalizedPoints(
        in size: CGSize
    ) -> [ProfilePoint] {
        let sorted =
            pomiar.punktySkosu
                .sorted {
                    $0.odlegloscOdLewejMM
                    < $1.odlegloscOdLewejMM
                }

        guard !sorted.isEmpty
        else {
            return []
        }

        let widthMM =
            max(
                pomiar.szerokoscScianyMM,
                sorted.map(
                    \.odlegloscOdLewejMM
                ).max() ?? 1,
                1
            )

        let heightMM =
            max(
                pomiar.wysokoscMaksymalnaMM,
                sorted.map(
                    \.wysokoscMM
                ).max() ?? 1,
                1
            )

        let availableWidth =
            max(
                size.width
                - padding * 2,
                1
            )

        let availableHeight =
            max(
                size.height
                - padding * 2,
                1
            )

        return sorted.map { source in
            let normalizedX =
                source.odlegloscOdLewejMM
                / widthMM

            let normalizedY =
                source.wysokoscMM
                / heightMM

            let position =
                CGPoint(
                    x:
                        padding
                        + availableWidth
                        * normalizedX,
                    y:
                        size.height
                        - padding
                        - availableHeight
                        * normalizedY
                )

            return ProfilePoint(
                id: source.id,
                position: position,
                source: source
            )
        }
    }

    private func formatted(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }

    private var accessibilityDescription:
        String
    {
        let pointCount =
            pomiar.punktySkosu.count

        let angleText: String

        if let angle =
            pomiar
                .przyblizonyKatSkosuStopnie {
            angleText =
                angle.formatted(
                    .number.precision(
                        .fractionLength(1)
                    )
                )
                + " stopni"
        } else {
            angleText =
                "nieokreślony"
        }

        return """
        Profil skosu. \
        Liczba punktów: \(pointCount). \
        Szerokość: \(formatted(pomiar.szerokoscScianyMM)) milimetrów. \
        Kąt: \(angleText).
        """
    }
}

private struct ProfilePoint:
    Identifiable
{
    let id: UUID
    let position: CGPoint
    let source:
        PunktPomiarowySkosu
}
