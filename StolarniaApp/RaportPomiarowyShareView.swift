import SwiftUI

struct RaportPomiarowyShareView:
    View
{
    let fileURL: URL

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(
                    systemName:
                        "doc.richtext.fill"
                )
                .font(
                    .system(
                        size: 72
                    )
                )
                .foregroundStyle(
                    .tint
                )

                VStack(spacing: 8) {
                    Text(
                        "Raport jest gotowy"
                    )
                    .font(.title.bold())

                    Text(
                        fileURL
                            .lastPathComponent
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
                }

                ShareLink(
                    item: fileURL,
                    preview:
                        SharePreview(
                            "Raport pomiarowy",
                            image:
                                Image(
                                    systemName:
                                        "doc.richtext"
                                )
                        )
                ) {
                    Label(
                        "Udostępnij lub zapisz PDF",
                        systemImage:
                            "square.and.arrow.up"
                    )
                    .frame(
                        maxWidth: 320
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)

                Spacer()
            }
            .padding(28)
            .navigationTitle(
                "Eksport PDF"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
        }
    }
}
