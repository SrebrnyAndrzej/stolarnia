import Foundation
import os

/// Centralny punkt logowania dla StolarniaApp.
///
/// Używaj zamiast `assertionFailure` w blokach `catch` i innych
/// miejscach gdzie błąd nie może zatrzymać aplikacji, ale musi być
/// widoczny w Instruments / Console.app w trybie Release.
enum StolarniaLogger {
    static let zapis = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "StolarniaApp",
        category: "Zapis"
    )

    static let wycena = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "StolarniaApp",
        category: "Wycena"
    )

    static let ui = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "StolarniaApp",
        category: "UI"
    )

    static let app = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "StolarniaApp",
        category: "App"
    )
}
