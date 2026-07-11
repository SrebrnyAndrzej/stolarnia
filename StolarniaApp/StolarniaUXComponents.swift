import SwiftUI

enum StolarniaNavigationTone {
    case dark
    case light
}

struct StolarniaNavigationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    var tone:
        StolarniaNavigationTone = .light

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(
                    iconBackground
                )

                Image(
                    systemName:
                        systemImage
                )
                .font(
                    .title3
                        .weight(.semibold)
                )
                .foregroundStyle(
                    iconForeground
                )
            }
            .frame(
                width: 38,
                height: 38
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(
                        primaryText
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(
                        secondaryText
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(
                    systemName:
                        "checkmark.circle.fill"
                )
                .font(.title3)
                .foregroundStyle(
                    StolarniaPalette
                        .accent
                )
                .accessibilityHidden(
                    true
                )
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .frame(minHeight: 62)
        .accessibilityElement(
            children: .combine
        )
        .accessibilityAddTraits(
            isSelected
            ? [.isSelected]
            : []
        )
    }

    private var primaryText:
        Color
    {
        switch tone {
        case .dark:
            return StolarniaPalette
                .sidebarPrimary
        case .light:
            return .primary
        }
    }

    private var secondaryText:
        Color
    {
        switch tone {
        case .dark:
            return StolarniaPalette
                .sidebarSecondary
        case .light:
            return .secondary
        }
    }

    private var iconBackground:
        Color
    {
        if isSelected {
            return StolarniaPalette
                .accent
                .opacity(0.22)
        }

        switch tone {
        case .dark:
            return Color.white
                .opacity(0.08)
        case .light:
            return StolarniaPalette
                .anthracite
                .opacity(0.08)
        }
    }

    private var iconForeground:
        Color
    {
        isSelected
        ? StolarniaPalette.accent
        : primaryText
    }
}

struct StolarniaSectionIntro: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(
                    StolarniaPalette
                        .accent
                        .opacity(0.16)
                )

                Image(
                    systemName:
                        systemImage
                )
                .font(
                    .title2
                        .weight(.semibold)
                )
                .foregroundStyle(
                    StolarniaPalette
                        .accentStrong
                )
            }
            .frame(
                width: 48,
                height: 48
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(title)
                    .font(.title2.bold())

                Text(description)
                    .font(.body)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer()
        }
        .stolarniaFrostedCard()
    }
}

struct StolarniaPrimaryButtonStyle:
    ButtonStyle
{
    let minHeight: CGFloat
    let horizontalPadding: CGFloat
    let cornerRadius: CGFloat

    init(
        minHeight: CGFloat = 50,
        horizontalPadding: CGFloat = 16,
        cornerRadius: CGFloat = 13
    ) {
        self.minHeight = minHeight
        self.horizontalPadding =
            horizontalPadding
        self.cornerRadius = cornerRadius
    }

    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(
                minHeight: minHeight
            )
            .padding(
                .horizontal,
                horizontalPadding
            )
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(
                    configuration.isPressed
                    ? StolarniaPalette
                        .accentStrong
                    : StolarniaPalette
                        .accent
                )
            )
            .foregroundStyle(
                StolarniaPalette
                    .drawingInk
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.98
                : 1
            )
    }
}

struct StolarniaPrimaryIconButtonStyle:
    ButtonStyle
{
    let size: CGFloat

    init(
        size: CGFloat = 44
    ) {
        self.size = size
    }

    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .font(
                .headline
                    .weight(.bold)
            )
            .foregroundStyle(
                StolarniaPalette
                    .drawingInk
            )
            .frame(
                width: size,
                height: size
            )
            .background(
                Circle()
                    .fill(
                        configuration
                            .isPressed
                        ? StolarniaPalette
                            .accentStrong
                        : StolarniaPalette
                            .accent
                    )
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.96
                : 1
            )
    }
}
