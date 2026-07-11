import DomainCore
import SwiftUI

struct RoomAxonometricSheetV025:
    View
{
    let room: RoomDefinition
    let wall: WallSegment
    let assemblies:
        [FurnitureAssembly]
    let cornerDefinitions:
        [CornerCabinetDefinitionV025]
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
                min(
                    fittedScale,
                    1
                ),
                0.1
            )

        VStack(spacing: 0) {
            header

            Divider()

            RoomAxonometricCanvasV025(
                room: room,
                assemblies: assemblies,
                cornerDefinitions:
                    cornerDefinitions,
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
                    "Aksonometria pomieszczenia — \(room.name)"
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
                    "CAŁE POMIESZCZENIE"
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
            cell(
                "Projekt",
                room.name
            )
            cell(
                "Widok",
                settings.direction.title
            )
            cell(
                "Moduły",
                "\(assemblies.count)"
            )
            cell(
                "Narożniki",
                "\(cornerDefinitions.count)"
            )
            cell(
                "Skala",
                scale.title
            )
            cell(
                "Data",
                Date.now.formatted(
                    date: .numeric,
                    time: .omitted
                )
            )
        }
        .frame(height: 68)
    }

    private func cell(
        _ title: String,
        _ value: String
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
