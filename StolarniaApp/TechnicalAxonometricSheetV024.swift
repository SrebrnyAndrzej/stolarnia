import DomainCore
import SwiftUI

struct TechnicalAxonometricSheetV024:
    View
{
    let document:
        TechnicalDrawingDocumentV023
    let settings:
        AxonometricSettingsV024
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

        let finalScale =
            max(
                min(fittedScale, 1),
                0.1
            )

        VStack(spacing: 0) {
            header

            Divider()

            TechnicalAxonometricCanvasV024(
                wall:
                    document.wall,
                assemblies:
                    document.assemblies,
                settings: settings
            )
            .padding(18)

            if showTitleBlock {
                Divider()
                titleBlock
            }
        }
        .frame(
            width:
                format.size.width,
            height:
                format.size.height
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
            finalScale,
            anchor: .center
        )
        .frame(
            width:
                format.size.width
                * finalScale,
            height:
                format.size.height
                * finalScale
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
                Text("STOLARNIA APP")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.2)

                Text(
                    "Aksonometria — \(document.wall.name)"
                )
                .font(.title3)
                .fontWeight(.semibold)
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 4
            ) {
                Text(
                    "RZUT AKSONOMETRYCZNY"
                )
                .font(.caption)
                .fontWeight(.bold)

                Text(
                    settings.direction.title
                )
                .font(.caption)
            }
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            10
        )
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
                title: "Ściana",
                value:
                    document.wall.name
            )

            titleCell(
                title: "Widok",
                value:
                    settings.direction.title
            )

            titleCell(
                title: "Skala",
                value: scale.title
            )

            titleCell(
                title: "Arkusz",
                value:
                    "A-\(document.wall.name)"
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
            Text(
                title.uppercased()
            )
            .font(.caption2)
            .foregroundStyle(
                .secondary
            )

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

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
