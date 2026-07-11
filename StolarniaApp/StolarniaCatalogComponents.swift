import SwiftUI
import UIKit

enum StolarniaBannerTone {
    case information
    case success
    case warning
    case error

    var foreground: Color {
        switch self {
        case .information:
            return StolarniaPalette.accentStrong
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var background: Color {
        foreground.opacity(0.12)
    }
}

struct StolarniaStatusBanner: View {
    let message: String
    let systemImage: String
    var tone: StolarniaBannerTone = .information

    var body: some View {
        Label {
            Text(message)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(
                    tone.foreground
                )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(tone.background)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.55)
        }
        .accessibilityElement(
            children: .combine
        )
    }
}

struct StolarniaFilterShelf<Content: View>: View {
    private let content: Content

    init(
        @ViewBuilder content:
            () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(
                spacing:
                    StolarniaLayout
                        .compactSpacing
            ) {
                content
            }
            .padding(
                .horizontal,
                StolarniaLayout.pagePadding
            )
            .padding(.vertical, 10)
        }
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.55)
        }
    }
}

struct StolarniaFilterButtonStyle:
    ButtonStyle
{
    let isActive: Bool

    func makeBody(
        configuration:
            Configuration
    ) -> some View {
        configuration.label
            .font(
                .subheadline
                    .weight(.semibold)
            )
            .lineLimit(1)
            .padding(.horizontal, 13)
            .frame(
                minHeight:
                    StolarniaLayout
                        .compactControlHeight
            )
            .foregroundStyle(
                isActive
                ? StolarniaPalette.accentStrong
                : Color.primary
            )
            .background(
                Capsule()
                    .fill(
                        isActive
                        ? StolarniaPalette
                            .accent
                            .opacity(
                                configuration.isPressed
                                ? 0.24
                                : 0.16
                            )
                        : Color(
                            uiColor:
                                .secondarySystemBackground
                        )
                        .opacity(
                            configuration.isPressed
                            ? 0.72
                            : 0.92
                        )
                    )
            )
            .overlay {
                Capsule()
                    .stroke(
                        isActive
                        ? StolarniaPalette
                            .accent
                            .opacity(0.56)
                        : Color.secondary
                            .opacity(0.16),
                        lineWidth: 1
                    )
            }
            .scaleEffect(
                configuration.isPressed
                ? 0.98
                : 1
            )
            .animation(
                StolarniaAnimation.quick,
                value:
                    configuration.isPressed
            )
    }
}

extension View {
    func stolarniaFilterControl(
        isActive: Bool = false
    ) -> some View {
        buttonStyle(
            StolarniaFilterButtonStyle(
                isActive: isActive
            )
        )
    }
}

struct StolarniaResultCount: View {
    let count: Int
    var noun: String = "pozycji"

    var body: some View {
        Text("\(count) \(noun)")
            .font(
                .subheadline
                    .monospacedDigit()
            )
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityLabel(
                "Liczba wyników: \(count)"
            )
    }
}

enum StolarniaBadgeTone:
    Hashable
{
    case accent
    case neutral
    case success
    case warning

    var foreground: Color {
        switch self {
        case .accent:
            return StolarniaPalette.accentStrong
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        }
    }

    var background: Color {
        foreground.opacity(0.12)
    }
}

struct StolarniaBadgeView: View {
    let text: String
    var tone: StolarniaBadgeTone =
        .accent

    var body: some View {
        Text(text)
            .font(
                .caption2
                    .weight(.semibold)
            )
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(
                tone.foreground
            )
            .background(
                tone.background,
                in: Capsule()
            )
            .accessibilityLabel(text)
    }
}

struct StolarniaCatalogBadge:
    Identifiable,
    Hashable
{
    let text: String
    let tone: StolarniaBadgeTone

    var id: String {
        "\(String(describing: tone))|\(text)"
    }

    init(
        _ text: String,
        tone:
            StolarniaBadgeTone = .accent
    ) {
        self.text = text
        self.tone = tone
    }
}

struct StolarniaCatalogRow<
    Leading: View
>: View {
    let title: String
    let subtitle: String
    let tertiaryText: String?
    let badges: [StolarniaCatalogBadge]
    let trailingPrimary: String
    let trailingSecondary: String?
    let isEnabled: Bool
    private let leading: Leading

    init(
        title: String,
        subtitle: String,
        tertiaryText: String? = nil,
        badges:
            [StolarniaCatalogBadge] = [],
        trailingPrimary: String,
        trailingSecondary: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder leading:
            () -> Leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tertiaryText =
            tertiaryText
        self.badges = badges
        self.trailingPrimary =
            trailingPrimary
        self.trailingSecondary =
            trailingSecondary
        self.isEnabled = isEnabled
        self.leading = leading()
    }

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 14
        ) {
            leading
                .frame(
                    width:
                        StolarniaLayout
                            .catalogLeadingSize,
                    height:
                        StolarniaLayout
                            .catalogLeadingSize
                )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !badges.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(badges) {
                            badge in
                            StolarniaBadgeView(
                                text:
                                    badge.text,
                                tone:
                                    badge.tone
                            )
                        }
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(2)

                if let tertiaryText,
                   !tertiaryText.isEmpty {
                    Text(tertiaryText)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(
                alignment: .trailing,
                spacing: 5
            ) {
                Text(trailingPrimary)
                    .font(
                        .headline
                            .monospacedDigit()
                    )
                    .multilineTextAlignment(
                        .trailing
                    )

                if let trailingSecondary,
                   !trailingSecondary
                    .isEmpty {
                    Text(trailingSecondary)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .lineLimit(2)
                }
            }
            .frame(
                minWidth: 112,
                alignment: .trailing
            )

            Image(
                systemName:
                    "chevron.right"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(
            isEnabled
            ? 1
            : 0.56
        )
        .accessibilityElement(
            children: .combine
        )
    }
}

struct StolarniaEmptyState: View {
    let title: String
    let description: String
    let systemImage: String
    var actionTitle: String?
    var actionSystemImage: String =
        "plus"
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(
                title,
                systemImage:
                    systemImage
            )
        } description: {
            Text(description)
        } actions: {
            if let actionTitle,
               let action {
                Button(action: action) {
                    Label(
                        actionTitle,
                        systemImage:
                            actionSystemImage
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
        }
    }
}

struct StolarniaToast: View {
    let message: String
    let systemImage: String
    var tone:
        StolarniaBannerTone = .success

    var body: some View {
        Label(
            message,
            systemImage:
                systemImage
        )
        .font(
            .subheadline
                .weight(.semibold)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .foregroundStyle(
            tone.foreground
        )
        .background(
            .regularMaterial,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    tone.foreground
                        .opacity(0.22),
                    lineWidth: 1
                )
        }
        .shadow(
            color:
                Color.black
                    .opacity(0.12),
            radius: 12,
            x: 0,
            y: 6
        )
        .accessibilityAddTraits(
            .isStaticText
        )
    }
}

struct StolarniaNumberField: View {
    let title: String
    @Binding var value: Double
    let suffix: String
    var width: CGFloat = 126

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            TextField(
                title,
                value: $value,
                format:
                    .number
                    .grouping(.never)
                    .precision(
                        .fractionLength(
                            0...2
                        )
                    )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(
                .trailing
            )
            .frame(width: width)
            .monospacedDigit()

            Text(suffix)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    minWidth: 38,
                    alignment: .leading
                )
        }
        .accessibilityElement(
            children: .combine
        )
    }
}

private struct StolarniaCatalogListModifier:
    ViewModifier
{
    func body(
        content: Content
    ) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(
                .hidden
            )
            .listRowSpacing(2)
    }
}

private struct StolarniaFormSurfaceModifier:
    ViewModifier
{
    func body(
        content: Content
    ) -> some View {
        content
            .scrollContentBackground(
                .hidden
            )
            .background(Color.clear)
    }
}

extension View {
    func stolarniaCatalogList()
        -> some View
    {
        modifier(
            StolarniaCatalogListModifier()
        )
    }

    func stolarniaFormSurface()
        -> some View
    {
        modifier(
            StolarniaFormSurfaceModifier()
        )
    }
}
