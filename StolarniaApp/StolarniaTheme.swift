import SwiftUI
import UIKit

enum StolarniaPalette {
    static let steel =
        Color(
            red: 0.518,
            green: 0.549,
            blue: 0.557
        )

    static let graphite =
        Color(
            red: 0.263,
            green: 0.314,
            blue: 0.345
        )

    static let lime =
        Color(
            red: 0.646,
            green: 0.720,
            blue: 0.352
        )

    static let stone =
        Color(
            red: 0.749,
            green: 0.718,
            blue: 0.714
        )

    static let paper =
        Color(
            red: 0.945,
            green: 0.949,
            blue: 0.933
        )

    static let drawingDesk =
        Color(
            red: 0.945,
            green: 0.949,
            blue: 0.933
        )

    static let drawingPaper =
        Color(
            red: 0.985,
            green: 0.988,
            blue: 0.975
        )

    static let drawingLabelFill =
        Color.white.opacity(0.96)

    static let drawingInk =
        Color(
            red: 0.105,
            green: 0.125,
            blue: 0.135
        )

    static let drawingMutedInk =
        Color(
            red: 0.263,
            green: 0.314,
            blue: 0.345
        )

    static let anthracite =
        Color(
            uiColor: UIColor {
                _ in UIColor(
                    red: 0.045,
                    green: 0.052,
                    blue: 0.058,
                    alpha: 1
                )
            }
        )

    static let anthraciteRaised =
        Color(
            uiColor: UIColor {
                _ in UIColor(
                    red: 0.095,
                    green: 0.118,
                    blue: 0.132,
                    alpha: 1
                )
            }
        )

    static let canvas =
        Color(
            uiColor: UIColor {
                _ in UIColor(
                    red: 0.030,
                    green: 0.035,
                    blue: 0.040,
                    alpha: 1
                )
            }
        )

    static let canvasRaised =
        Color(
            uiColor: UIColor {
                _ in UIColor(
                    red: 0.072,
                    green: 0.090,
                    blue: 0.102,
                    alpha: 1
                )
            }
        )

    static let accent =
        lime

    static let accentStrong =
        Color(
            red: 0.500,
            green: 0.595,
            blue: 0.250
        )

    static let frostStroke =
        paper.opacity(0.26)

    static let frostFilm =
        paper.opacity(0.12)

    static let frostHighlight =
        Color.white.opacity(0.36)

    static let frostShadow =
        Color.black.opacity(0.42)

    static let limeGlow =
        lime.opacity(0.24)

    static let sidebarPrimary =
        paper.opacity(0.96)

    static let sidebarSecondary =
        stone.opacity(0.78)
}

enum StolarniaSurfaceTone {
    case sidebar
    case content
    case detail
}

struct StolarniaAppThemeRoot<Content: View>:
    View
{
    @Environment(
        \.accessibilityReduceTransparency
    )
    private var reduceTransparency

    private let content: Content

    init(
            @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    StolarniaPalette.canvas,
                    StolarniaPalette
                        .canvasRaised
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .tint(StolarniaPalette.accent)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .environment(
            \.defaultMinListRowHeight,
            52
        )
        .controlSize(.large)
        .animation(
            StolarniaMotion.pojawienie,
            value: reduceTransparency
        )
    }
}

struct StolarniaFrostedCardModifier:
    ViewModifier
{
    @Environment(
        \.accessibilityReduceTransparency
    )
    private var reduceTransparency

    let cornerRadius: CGFloat
    let padding: CGFloat

    @ViewBuilder
    func body(
        content: Content
    ) -> some View {
        let paddedContent =
            content.padding(padding)

        if reduceTransparency {
            paddedContent
                .background {
                    RoundedRectangle(
                        cornerRadius:
                            cornerRadius,
                        style: .continuous
                    )
                    .fill(
                        StolarniaPalette
                            .canvasRaised
                    )
                    .overlay {
                        glassFilm
                    }
                }
                .overlay {
                    glassSheen
                }
                .overlay {
                    glassStroke
                }
                .shadow(
                    color:
                        StolarniaPalette
                            .frostShadow,
                    radius: 20,
                    x: 0,
                    y: 10
                )
        } else if #available(
            iOS 26.0,
            *
        ) {
            paddedContent
                .background {
                    RoundedRectangle(
                        cornerRadius:
                            cornerRadius,
                        style: .continuous
                    )
                    .fill(
                        .ultraThinMaterial
                    )
                    .overlay {
                        glassFilm
                    }
                }
                .glassEffect(
                    .regular
                        .tint(
                            StolarniaPalette
                                .accent
                                .opacity(0.11)
                        )
                        .interactive(),
                    in: .rect(
                        cornerRadius:
                            cornerRadius
                    )
                )
                .overlay {
                    glassSheen
                }
                .overlay {
                    glassStroke
                }
                .shadow(
                    color:
                        StolarniaPalette
                            .frostShadow,
                    radius: 24,
                    x: 0,
                    y: 12
                )
        } else {
            paddedContent
                .background {
                    RoundedRectangle(
                        cornerRadius:
                            cornerRadius,
                        style: .continuous
                    )
                    .fill(
                        .regularMaterial
                    )
                    .overlay {
                        glassFilm
                    }
                }
                .overlay {
                    glassSheen
                }
                .overlay {
                    glassStroke
                }
                .shadow(
                    color:
                        StolarniaPalette
                            .frostShadow,
                    radius: 22,
                    x: 0,
                    y: 11
                )
        }
    }

    private var glassFilm:
        some View
    {
        RoundedRectangle(
            cornerRadius:
                cornerRadius,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    StolarniaPalette
                        .paper
                        .opacity(0.16),
                    Color.white
                        .opacity(0.055),
                    StolarniaPalette
                        .accent
                        .opacity(0.08),
                    Color.white
                        .opacity(0.025)
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
            )
        )
        .allowsHitTesting(false)
    }

    private var glassSheen:
        some View
    {
        RoundedRectangle(
            cornerRadius:
                cornerRadius,
            style: .continuous
        )
        .stroke(
            LinearGradient(
                colors: [
                    StolarniaPalette
                        .frostHighlight,
                    Color.white
                        .opacity(0.10),
                    Color.white
                        .opacity(0.02)
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
            ),
            lineWidth: 1.25
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private var glassStroke:
        some View
    {
        RoundedRectangle(
            cornerRadius:
                cornerRadius,
            style: .continuous
        )
        .stroke(
            LinearGradient(
                colors: [
                    Color.white
                        .opacity(0.24),
                    StolarniaPalette
                        .accent
                        .opacity(0.40),
                    Color.white
                        .opacity(0.10)
                ],
                startPoint:
                    .topLeading,
                endPoint:
                    .bottomTrailing
            ),
            lineWidth: 1
        )
        .allowsHitTesting(false)
    }
}

struct StolarniaScreenSurfaceModifier:
    ViewModifier
{
    let tone:
        StolarniaSurfaceTone

    func body(
        content: Content
    ) -> some View {
        content
            .scrollContentBackground(
                .hidden
            )
            .background(
                background
                    .ignoresSafeArea()
            )
    }

    @ViewBuilder
    private var background:
        some View
    {
        switch tone {
        case .sidebar:
            ZStack {
                LinearGradient(
                    colors: [
                        StolarniaPalette
                            .anthracite
                            .opacity(0.94),
                        StolarniaPalette
                            .graphite
                            .opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(
                        .ultraThinMaterial
                    )
                    .opacity(0.28)
            }

        case .content:
            ZStack {
                LinearGradient(
                    colors: [
                        StolarniaPalette
                            .canvas
                            .opacity(0.96),
                        StolarniaPalette
                            .graphite
                            .opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(
                        StolarniaPalette
                            .graphite
                    )
                    .opacity(0.20)
            }

        case .detail:
            LinearGradient(
                colors: [
                    StolarniaPalette
                        .canvasRaised,
                    StolarniaPalette
                        .canvas
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct StolarniaReadableInterfaceModifier:
    ViewModifier
{
    func body(
        content: Content
    ) -> some View {
        content
            .environment(
                \.defaultMinListRowHeight,
                52
            )
            .controlSize(.large)
            .dynamicTypeSize(
                .small ... .accessibility3
            )
    }
}

/// Tło materiałowe, które respektuje Reduce Transparency.
///
/// `StolarniaFrostedCardModifier` robi to samo, ale narzuca padding i zaokrąglenie,
/// więc nadaje się tylko na karty. Paski, nakładki i pigułki potrzebowały czegoś
/// bez własnego kształtu — i z braku takiego narzędzia wstawiały `.thinMaterial`
/// wprost, przez co systemowe ustawienie dostępności ich nie dotyczyło.
/// Audyt UI 2026-08-26 naliczył 39 takich miejsc w 24 plikach.
///
/// Etykiety argumentów są **celowo takie same jak w `background(_:in:)`**, żeby
/// migracja była czystym przemianowaniem wywołania.
struct StolarniaAdaptiveMaterialModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    let material: Material
    let ksztalt: S
    let zastepcze: Color

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(zastepcze, in: ksztalt)
        } else {
            content.background(material, in: ksztalt)
        }
    }
}

extension View {
    /// Tło materiałowe bez własnego kształtu.
    func stolarniaMaterial(
        _ material: Material,
        zastepcze: Color = StolarniaPalette.canvasRaised
    ) -> some View {
        modifier(
            StolarniaAdaptiveMaterialModifier(
                material: material,
                ksztalt: Rectangle(),
                zastepcze: zastepcze
            )
        )
    }

    /// Tło materiałowe przycięte do kształtu.
    func stolarniaMaterial<S: Shape>(
        _ material: Material,
        in ksztalt: S,
        zastepcze: Color = StolarniaPalette.canvasRaised
    ) -> some View {
        modifier(
            StolarniaAdaptiveMaterialModifier(
                material: material,
                ksztalt: ksztalt,
                zastepcze: zastepcze
            )
        )
    }
}

extension View {
    func stolarniaFrostedCard(
        cornerRadius: CGFloat = 18,
        padding: CGFloat = 16
    ) -> some View {
        modifier(
            StolarniaFrostedCardModifier(
                cornerRadius:
                    cornerRadius,
                padding: padding
            )
        )
    }

    func stolarniaScreenSurface(
        _ tone:
            StolarniaSurfaceTone
    ) -> some View {
        modifier(
            StolarniaScreenSurfaceModifier(
                tone: tone
            )
        )
    }

    func stolarniaReadableInterface()
        -> some View
    {
        modifier(
            StolarniaReadableInterfaceModifier()
        )
    }
}

@MainActor
enum StolarniaAppearance {
    static func configure() {
        configureWindowStyle()
        configureNavigationBar()
        configureToolbar()
        configureLists()
        configureSearch()
        configureControls()
    }

    private static var anthraciteUIColor: UIColor {
        UIColor(
            red: 0.045,
            green: 0.052,
            blue: 0.058,
            alpha: 1
        )
    }

    private static var raisedUIColor: UIColor {
        UIColor(
            red: 0.095,
            green: 0.118,
            blue: 0.132,
            alpha: 1
        )
    }

    private static var limeUIColor: UIColor {
        UIColor(
            red: 0.646,
            green: 0.720,
            blue: 0.352,
            alpha: 1
        )
    }

    private static func configureWindowStyle() {
        UIWindow
            .appearance()
            .overrideUserInterfaceStyle = .dark

        UIView
            .appearance()
            .tintColor = limeUIColor
    }

    private static func configureNavigationBar() {
        let appearance =
            UINavigationBarAppearance()

        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect =
            UIBlurEffect(
                style:
                    .systemChromeMaterial
            )

        appearance.backgroundColor =
            anthraciteUIColor
            .withAlphaComponent(0.86)

        appearance.titleTextAttributes = [
            .foregroundColor:
                UIColor.white
                .withAlphaComponent(0.92)
        ]

        appearance.largeTitleTextAttributes = [
            .foregroundColor:
                UIColor.white
                .withAlphaComponent(0.96)
        ]

        appearance.shadowColor =
            UIColor.white
                .withAlphaComponent(
                    0.10
                )

        UINavigationBar
            .appearance()
            .standardAppearance =
                appearance

        UINavigationBar
            .appearance()
            .scrollEdgeAppearance =
                appearance

        UINavigationBar
            .appearance()
            .compactAppearance =
                appearance
    }

    private static func configureToolbar() {
        let appearance =
            UIToolbarAppearance()

        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect =
            UIBlurEffect(
                style:
                    .systemChromeMaterial
            )

        appearance.backgroundColor =
            anthraciteUIColor
            .withAlphaComponent(0.78)

        UIToolbar
            .appearance()
            .standardAppearance =
                appearance

        UIToolbar
            .appearance()
            .scrollEdgeAppearance =
                appearance
    }

    private static func configureLists() {
        UITableView
            .appearance()
            .backgroundColor = anthraciteUIColor

        UICollectionView
            .appearance()
            .backgroundColor = anthraciteUIColor

        UITableViewCell
            .appearance()
            .backgroundColor = raisedUIColor

        let selectedCellBackground =
            UIView(frame: .zero)
        selectedCellBackground.backgroundColor =
            limeUIColor.withAlphaComponent(0.38)

        UITableViewCell
            .appearance()
            .selectedBackgroundView =
                selectedCellBackground
    }

    private static func configureSearch() {
        UISearchBar
            .appearance()
            .searchTextField
            .backgroundColor =
                UIColor {
                    _ in UIColor(
                        white: 1,
                        alpha: 0.10
                    )
                }
    }

    private static func configureControls() {
        UISwitch
            .appearance()
            .onTintColor =
                limeUIColor

        UISegmentedControl
            .appearance()
            .selectedSegmentTintColor =
                limeUIColor
                .withAlphaComponent(0.92)

        UISegmentedControl
            .appearance()
            .setTitleTextAttributes(
                [
                    .foregroundColor:
                        UIColor(
                            red: 0.05,
                            green: 0.06,
                            blue: 0.07,
                            alpha: 1
                        )
                ],
                for: .selected
            )

        UISegmentedControl
            .appearance()
            .setTitleTextAttributes(
                [
                    .foregroundColor:
                        UIColor.white
                            .withAlphaComponent(0.82)
                ],
                for: .normal
            )
    }
}


enum StolarniaLayout {
    static let pagePadding: CGFloat = 20
    static let compactSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 18
    static let controlHeight: CGFloat = 42
    static let compactControlHeight: CGFloat = 36
    static let catalogLeadingSize: CGFloat = 46
    static let cardCornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 12
    static let maxReadableWidth: CGFloat = 980
}

/// Starsze nazwy animacji, przepięte na słownik ruchu.
///
/// Obie brały `easeInOut`, czyli krzywą **zaczynającą się wolno**. Dla wejść,
/// wyjść i reakcji na dotyk to zły wybór: opóźnia ruch dokładnie w chwili,
/// w której użytkownik patrzy najuważniej, więc interfejs czyta się jako
/// ociężały mimo krótkiego czasu trwania.
///
/// `easeInOut` ma sens tylko dla rzeczy **przemieszczających się po ekranie** —
/// tam przyspieszenie na starcie odpowiada temu, jak ruszają rzeczy z masą.
/// Do tego jest `StolarniaMotion.ruch(_:)`.
///
/// Nazwy zostają, żeby nie ruszać kilkunastu wywołań; wartości idą
/// z `StolarniaMotion`.
enum StolarniaAnimation {
    static let quick = StolarniaMotion.wejscie(StolarniaMotion.puszczenie)
    static let standard = StolarniaMotion.wejscie(StolarniaMotion.lista)
}
