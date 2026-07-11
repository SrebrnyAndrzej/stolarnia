import Foundation

/// System szuflad obsługiwany przez kreator rysunkowy.
/// Wymiary profili i minimalne otwarcia pochodzą z katalogów producentów
/// (Blum LEGRABOX, GTV Axis Pro, Amix Slim Box).
public enum DrawerSystem: String, Codable, CaseIterable, Sendable, Identifiable {
    case blumLegrabox
    case gtvAxisPro
    case amixSlimbox

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .blumLegrabox: return "Blum LEGRABOX"
        case .gtvAxisPro: return "GTV Axis Pro"
        case .amixSlimbox: return "Amix Slim Box"
        }
    }

    /// Grubość płaszcza bocznego szuflady (jedna strona).
    public var sideThickness: Millimeters {
        switch self {
        case .blumLegrabox: return Millimeters(12.7)
        case .gtvAxisPro: return 14
        case .amixSlimbox: return 12
        }
    }

    public var defaultProfileName: String {
        switch self {
        case .blumLegrabox: return "M"
        case .gtvAxisPro: return "H116"
        case .amixSlimbox: return "SB12"
        }
    }

    public var profiles: [DrawerProfile] {
        DrawerProfile.catalog(for: self)
    }
}

/// Profil (wysokość boku) systemu szuflad wraz z minimalnym otworem w korpusie
/// (profil + prowadnica + luz montażowy).
public struct DrawerProfile: Codable, Hashable, Sendable, Identifiable {
    public let system: DrawerSystem
    public let name: String
    public let profileHeight: Millimeters
    public let minimumOpening: Millimeters

    public var id: String { "\(system.rawValue)-\(name)" }

    public init(
        system: DrawerSystem,
        name: String,
        profileHeight: Millimeters,
        minimumOpening: Millimeters
    ) {
        self.system = system
        self.name = name
        self.profileHeight = profileHeight
        self.minimumOpening = minimumOpening
    }

    public static func catalog(for system: DrawerSystem) -> [DrawerProfile] {
        switch system {
        case .blumLegrabox:
            return [
                DrawerProfile(system: system, name: "N", profileHeight: 83, minimumOpening: 108),
                DrawerProfile(system: system, name: "M", profileHeight: Millimeters(90.5), minimumOpening: 116),
                DrawerProfile(system: system, name: "C", profileHeight: 128, minimumOpening: 154),
                DrawerProfile(system: system, name: "K", profileHeight: 193, minimumOpening: 220)
            ]
        case .gtvAxisPro:
            return [
                DrawerProfile(system: system, name: "H69", profileHeight: 69, minimumOpening: 100),
                DrawerProfile(system: system, name: "H86", profileHeight: 86, minimumOpening: 116),
                DrawerProfile(system: system, name: "H116", profileHeight: 116, minimumOpening: 148),
                DrawerProfile(system: system, name: "H168", profileHeight: 168, minimumOpening: 200),
                DrawerProfile(system: system, name: "H200", profileHeight: 200, minimumOpening: 234)
            ]
        case .amixSlimbox:
            return [
                DrawerProfile(system: system, name: "SB10", profileHeight: Millimeters(62.5), minimumOpening: 85),
                DrawerProfile(system: system, name: "SB11", profileHeight: 88, minimumOpening: 110),
                DrawerProfile(system: system, name: "SB12", profileHeight: 126, minimumOpening: 148),
                DrawerProfile(system: system, name: "SB13", profileHeight: 172, minimumOpening: 195),
                DrawerProfile(system: system, name: "SB14", profileHeight: 238, minimumOpening: 262)
            ]
        }
    }

    public static func profile(system: DrawerSystem, name: String) -> DrawerProfile? {
        catalog(for: system).first { $0.name == name }
    }

    /// Bezpieczny profil domyślny — katalog nigdy nie jest pusty.
    public static func defaultProfile(for system: DrawerSystem) -> DrawerProfile {
        profile(system: system, name: system.defaultProfileName)
            ?? catalog(for: system)[0]
    }
}

/// Wynik rozmieszczenia szuflad w strefie o zadanej wysokości.
public struct DrawerLayout: Hashable, Sendable {
    /// Wysokość jednego frontu przy zadanej liczbie szuflad.
    public var frontHeight: Millimeters
    /// Minimalny otwór wymagany przez wybrany profil.
    public var minimumOpening: Millimeters
    /// Maksymalna liczba szuflad tego profilu mieszcząca się w strefie.
    public var maximumCount: Int
    /// Wewnętrzna szerokość skrzynki (światło kolumny − 2× płaszcz boczny).
    public var boxWidth: Millimeters
    /// Czy front pomieści wybrany profil.
    public var isValid: Bool
}

public enum DrawerLayoutCalculator {
    public static let bottomMargin: Millimeters = 3
    public static let topMargin: Millimeters = 3
    public static let frontGap: Millimeters = 3

    public static func layout(
        zoneHeight: Millimeters,
        drawerCount: Int,
        columnInnerWidth: Millimeters,
        profile: DrawerProfile
    ) -> DrawerLayout {
        let count = max(1, drawerCount)
        let available = zoneHeight - bottomMargin - topMargin
        let frontHeight = (available - frontGap * Double(count - 1)) / Double(count)

        let rawMax = (available.rawValue + frontGap.rawValue)
            / (profile.minimumOpening.rawValue + frontGap.rawValue)
        let maximumCount = max(0, Int(rawMax.rounded(.down)))

        let boxWidth = columnInnerWidth - profile.system.sideThickness * 2

        return DrawerLayout(
            frontHeight: frontHeight,
            minimumOpening: profile.minimumOpening,
            maximumCount: maximumCount,
            boxWidth: boxWidth,
            isValid: frontHeight >= profile.minimumOpening
        )
    }
}
