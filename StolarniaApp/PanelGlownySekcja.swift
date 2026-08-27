import Foundation

/// Która połowa aplikacji jest otwarta: projekty czy bazy.
///
/// **Sam rozróżnik, bez opisu.** Do 2026-08-27 ten typ niósł też `title`,
/// `subtitle` i `systemImage` — teksty dwóch wierszy dawnego paska bocznego
/// („Klienci i projekty", „Firma i bazy"). Pasek zastąpił pulpit kaflowy,
/// który ma własne nazwy przy kaflach, a stare zostały w typie i wracały
/// jako tytuł kolumny listy projektów.
///
/// Jeśli potrzebujesz podpisu sekcji, weź go z miejsca, które go pokazuje —
/// nie odtwarzaj tu słownika, bo wtedy dwa ekrany znów zaczną nazywać to
/// samo inaczej.
enum PanelGlownySekcja:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case projekty
    case firma

    var id: String { rawValue }
}
