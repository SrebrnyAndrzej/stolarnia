import DomainCore
import SwiftUI

struct TechnicalSheetViewV023: View {
    let document:
        TechnicalDrawingDocumentV023
    let mode:
        TechnicalDrawingModeV023
    let visibleLayers:
        Set<TechnicalDrawingLayerV023>
    let selectedInstallationPointID:
        UUID?
    let scale:
        DrawingScaleV023
    let format:
        DrawingSheetFormatV023
    let showTitleBlock: Bool
    let availableSize: CGSize

    var body: some View {
        let fittedScale =
            min(
                availableSize.width
                    / format.size.width,
                availableSize.height
                    / format.size.height
            )

        VStack(spacing: 0) {
            header

            Divider()

            TechnicalElevationCanvasV023(
                document: document,
                mode: mode,
                visibleLayers:
                    visibleLayers,
                selectedInstallationPointID:
                    selectedInstallationPointID
            )
            .padding(18)

            if showTitleBlock {
                Divider()
                titleBlock
            }
        }
        .frame(
            width: format.size.width,
            height: format.size.height
        )
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(
                    Color.black,
                    lineWidth: 1.5
                )
        )
        .scaleEffect(
            max(
                min(fittedScale, 1),
                0.1
            ),
            anchor: .center
        )
        .frame(
            width:
                format.size.width
                * max(
                    min(fittedScale, 1),
                    0.1
                ),
            height:
                format.size.height
                * max(
                    min(fittedScale, 1),
                    0.1
                )
        )
        .shadow(
            radius: 12,
            y: 5
        )
    }

    private var header:
        some View
    {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    "STOLARNIA APP"
                )
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.2)

                Text(document.title)
                    .font(.title3)
                    .fontWeight(
                        .semibold
                    )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 4
            ) {
                Text(
                    "ELEWACJA TECHNICZNA"
                )
                .font(.caption)
                .fontWeight(.bold)

                Text(
                    "ŚCIANA \(document.wall.name)"
                )
                .font(.caption)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var titleBlock:
        some View
    {
        HStack(spacing: 0) {
            titleCell(
                title: "Projekt",
                value: "Kuchnia"
            )

            titleCell(
                title: "Pomieszczenie",
                value: "Kuchnia"
            )

            titleCell(
                title: "Ściana",
                value:
                    document.wall.name
            )

            titleCell(
                title: "Skala",
                value: scale.title
            )

            titleCell(
                title: "Arkusz",
                value:
                    "E-\(document.wall.name)"
            )

            titleCell(
                title: "Data",
                value:
                    Date.now.formatted(
                        date: .numeric,
                        time: .omitted
                    )
            )
        }
        .frame(height: 68)
    }

    private func titleCell(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )

            Text(value)
                .font(.caption)
                .fontWeight(
                    .semibold
                )

            Spacer()
        }
        .padding(10)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .overlay(
            alignment: .trailing
        ) {
            Divider()
        }
    }
}
