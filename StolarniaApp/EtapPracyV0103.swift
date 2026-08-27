import SwiftUI

/// Etapy pracy nad projektem — szkielet nawigacji warsztatu.
///
/// Kolejność wzięta wprost od użytkownika: *odpalam → projektuję → wyceniam
/// → rozkrój → zamówienie do hurtowni*. To jest droga, którą chodzi się
/// codziennie, więc to ona ma być widoczna w interfejsie.
///
/// Dotąd boczny pasek miał **dwanaście równorzędnych pozycji** w dwóch
/// workach („Projekt" i „Produkcja"), a wyceny nie było wśród nich wcale —
/// mieszkała jako `sheet` na ekranie projektu, czyli *pod* warsztatem
/// otwartym jako `fullScreenCover`. Żeby wycenić to, co się właśnie
/// narysowało, trzeba było zamknąć cały warsztat.
///
/// Etapy grupują istniejące ekrany; **żaden z nich nie znika**. To pierwszy
/// krok: ten sam zestaw miejsc, ale ułożony wzdłuż drogi, którą się idzie.
/// Docelowo każdy etap zwinie się do jednej pozycji z zakładkami w treści
/// (plan / elewacja / 3D to trzy widoki tego samego, nie trzy miejsca).
enum EtapPracyV0103: String, CaseIterable, Identifiable, Hashable {
    case projekt
    case wycena
    case rozkroj
    case zamowienie

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .projekt:    return "Projekt"
        case .wycena:     return "Wycena"
        case .rozkroj:    return "Rozkrój"
        case .zamowienie: return "Zamówienie"
        }
    }

    /// Co się na tym etapie robi — nagłówek sekcji mówi celem, nie kategorią.
    var opis: String {
        switch self {
        case .projekt:    return "Ustaw i zmień meble"
        case .wycena:     return "Ile to kosztuje"
        case .rozkroj:    return "Formatki i arkusze"
        case .zamowienie: return "Lista do hurtowni"
        }
    }

    var ikona: String {
        switch self {
        case .projekt:    return "square.grid.2x2"
        case .wycena:     return "banknote"
        case .rozkroj:    return "square.grid.3x3.square"
        case .zamowienie: return "cart"
        }
    }

    /// Ekran, na który wchodzi się, wybierając etap.
    ///
    /// Etap ma **jedną pozycję w pasku**, a nie listę ekranów. Plan, elewacja
    /// i 3D to trzy widoki tego samego mebla — przełącznik między nimi stoi
    /// nad rysunkiem, tam gdzie się patrzy. Produkcja ma własny pasek zakładek
    /// w treści, więc `Rozkrój` i `Zamówienie` wchodzą w niego na innej
    /// zakładce; nic się nie dubluje.
    var celDomyslny: WorkspaceDestinationV074 {
        switch self {
        case .projekt:    return .plan
        case .wycena:     return .wycena
        case .rozkroj:    return .produkcjaStart
        case .zamowienie: return .zakupPlyt
        }
    }

    /// Numer kroku pokazywany w pasku.
    ///
    /// Numeracja niesie tu prawdziwą informację — te etapy **są** kolejnością,
    /// a nie listą kategorii. Pomiar ma numer 1 i dzieje się przed wejściem
    /// do warsztatu, dlatego projekt zaczyna się od dwójki.
    var numer: Int {
        switch self {
        case .projekt:    return 2
        case .wycena:     return 3
        case .rozkroj:    return 4
        case .zamowienie: return 5
        }
    }
}
