import SwiftUI

/// **Usunięte 2026-08-27: `StolarniaNavigationRow` i `StolarniaNavigationTone`.**
///
/// Wiersz nawigacyjny obsługiwał dawny pasek boczny i menu firmy w
/// `PanelGlownyView`. Oba zastąpił pulpit kaflowy, więc komponent stracił
/// jedynego użytkownika. Zostawiony w bibliotece zapraszałby do odtworzenia
/// menu, które właśnie wygasiliśmy — a nawigacja tej aplikacji idzie teraz
/// kaflami i paskiem etapów, nie listą wierszy.

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
            // Skala bez animacji skacze — było wciśnięcie i puszczenie
            // natychmiastowe, więc przycisk „mrugał" zamiast odpowiadać.
            // Wciśnięcie zostaje natychmiastowe, puszczenie wybrzmiewa.
            .animation(
                configuration.isPressed
                ? StolarniaMotion.dotykWcisniecie
                : StolarniaMotion.dotykPuszczenie,
                value: configuration.isPressed
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
            .animation(
                configuration.isPressed
                ? StolarniaMotion.dotykWcisniecie
                : StolarniaMotion.dotykPuszczenie,
                value: configuration.isPressed
            )
    }
}

enum StolarniaReadinessStatus {
    case neutral
    case ready
    case warning
    case blocked

    var label: String {
        switch self {
        case .neutral:
            return "Do sprawdzenia"
        case .ready:
            return "Gotowe"
        case .warning:
            return "Wymaga uwagi"
        case .blocked:
            return "Brakuje danych"
        }
    }

    var systemImage: String {
        switch self {
        case .neutral:
            return "circle.dashed"
        case .ready:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .neutral:
            return StolarniaPalette.steel
        case .ready:
            return StolarniaPalette.accent
        case .warning:
            return Color.orange
        case .blocked:
            return Color.red
        }
    }
}

struct StolarniaStatusPill: View {
    let status: StolarniaReadinessStatus
    var text: String?

    var body: some View {
        Label(
            text ?? status.label,
            systemImage: status.systemImage
        )
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .foregroundStyle(status.color)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(
            Capsule()
                .fill(status.color.opacity(0.14))
        )
        .overlay {
            Capsule()
                .stroke(status.color.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StolarniaTaskActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var status: StolarniaReadinessStatus = .neutral
    var accent: Color = StolarniaPalette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(accent.opacity(0.18))

                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(StolarniaPalette.sidebarPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(StolarniaPalette.sidebarSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(status.color)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .stolarniaPressable(skala: 0.985)
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(StolarniaPalette.canvasRaised.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(status.color.opacity(0.34), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

struct StolarniaNextStepStrip: View {
    let title: String
    let description: String
    let status: StolarniaReadinessStatus
    let actionTitle: String
    let actionSystemImage: String
    let action: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(StolarniaPalette.canvasRaised.opacity(0.82))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(StolarniaPalette.frostStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            StolarniaStatusPill(status: status)

            copy

            Spacer(minLength: 12)

            actionButton
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                StolarniaStatusPill(status: status)

                copy

                Spacer(minLength: 0)
            }

            actionButton
        }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(StolarniaPalette.sidebarPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(StolarniaPalette.sidebarSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionButton: some View {
        Button(action: action) {
            Label(actionTitle, systemImage: actionSystemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .buttonStyle(
            StolarniaPrimaryButtonStyle(
                minHeight: 52,
                horizontalPadding: 16,
                cornerRadius: 14
            )
        )
    }
}

struct StolarniaConsequenceRow: View {
    let title: String
    let value: String
    var delta: String?
    var status: StolarniaReadinessStatus = .neutral

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(status.color)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StolarniaPalette.sidebarPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(StolarniaPalette.sidebarPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let delta {
                    Text(delta)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Zawijający rząd akcji

/// Rząd przycisków, który zawija się do kolejnych linii zamiast wypychać
/// zawartość poza kolumnę.
///
/// Powstało z audytu UI 2026-08-26. Szybkie akcje w kreatorze były wciśnięte
/// w `HStack` po trzy przyciski i musiały mieć `controlSize(.small)`, żeby się
/// zmieścić w inspektorze szerokim na ~300 pt. To łamało regułę projektu
/// o wierszu 52–62 pt: przycisk obsługiwany w warsztacie, często brudną albo
/// suchą ręką, był celem wielkości paznokcia.
///
/// `HStack` nie zawija, a `ViewThatFits` wybiera jeden z gotowych wariantów —
/// przy zmiennej liczbie akcji trzeba by je wypisywać ręcznie. Stąd własny
/// `Layout`: przyciski zachowują pełny rozmiar, a gdy zabraknie szerokości,
/// schodzą linijkę niżej.
struct StolarniaWrapLayout: Layout {

    var odstepPoziomy: CGFloat = 8
    var odstepPionowy: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let dostepna = proposal.width ?? .infinity
        let uklad = rozmiesc(w: dostepna, subviews: subviews)
        return CGSize(width: dostepna.isFinite ? dostepna : uklad.szerokosc,
                      height: uklad.wysokosc)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let uklad = rozmiesc(w: bounds.width, subviews: subviews)
        for (indeks, punkt) in uklad.pozycje.enumerated() {
            subviews[indeks].place(
                at: CGPoint(x: bounds.minX + punkt.x, y: bounds.minY + punkt.y),
                proposal: ProposedViewSize(subviews[indeks].sizeThatFits(.unspecified))
            )
        }
    }

    private func rozmiesc(
        w dostepna: CGFloat, subviews: Subviews
    ) -> (pozycje: [CGPoint], szerokosc: CGFloat, wysokosc: CGFloat) {
        var pozycje: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0
        var wysokoscLinii: CGFloat = 0
        var najszerszaLinia: CGFloat = 0

        for subview in subviews {
            let rozmiar = subview.sizeThatFits(.unspecified)
            // Pierwszy element w linii nigdy nie jest przenoszony — inaczej
            // przycisk szerszy od kolumny zapętliłby układ.
            if x > 0, x + rozmiar.width > dostepna {
                najszerszaLinia = max(najszerszaLinia, x - odstepPoziomy)
                x = 0
                y += wysokoscLinii + odstepPionowy
                wysokoscLinii = 0
            }
            pozycje.append(CGPoint(x: x, y: y))
            x += rozmiar.width + odstepPoziomy
            wysokoscLinii = max(wysokoscLinii, rozmiar.height)
        }
        najszerszaLinia = max(najszerszaLinia, x - odstepPoziomy)
        return (pozycje, max(najszerszaLinia, 0), y + wysokoscLinii)
    }
}
