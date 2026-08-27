import Foundation

/// Proponuje podział ciągu na korpusy.
///
/// Powstało, bo kreator pozwala narysować ciąg 4160 mm jako jeden moduł, a taka
/// bryła daje dno 4124×560 i plecy 4124×684 — czego nie da się wyciąć z arkusza
/// 2800×2070. `AssemblyInspector` to zgłasza, ale zgłoszenie po fakcie nie mówi
/// projektantowi, co ma zrobić. Ten planer odpowiada na pytanie „to jak mam to
/// podzielić".
///
/// Ograniczeniem nie jest tylko arkusz. Wcześniej odzywa się **ugięcie półki**:
/// półka 18 mm o rozpiętości ponad ok. 900 mm ugina się pod obciążeniem, nawet
/// jeśli formatka mieści się w arkuszu. Dlatego domyślny limit to 900, a nie
/// 2800 — arkusz jest twardą granicą, ugięcie praktyczną.
public enum RunSplitPlanner {

    /// Gotowa propozycja podziału.
    public struct Plan: Hashable, Sendable {
        /// Podziałki korpusów od lewej. Sumują się dokładnie do szerokości ciągu.
        public var widths: [Millimeters]
        /// Dlaczego taki podział — do pokazania projektantowi, nie do logów.
        public var reason: String

        public var count: Int { widths.count }

        public init(widths: [Millimeters], reason: String) {
            self.widths = widths
            self.reason = reason
        }
    }

    /// Rozpiętość, powyżej której półka 18 mm ugina się pod obciążeniem.
    ///
    /// To jest realna granica projektowa, nie wynikająca z arkusza. Przy dłuższych
    /// światłach trzeba albo podpory pośredniej, albo grubszej półki — a jedno
    /// i drugie to decyzja, nie domyślna.
    public static let maxShelfSpan: Millimeters = 900

    /// Najwęższy sensowny korpus. Poniżej tego okucia i szuflady przestają wchodzić.
    public static let minCarcassWidth: Millimeters = 300

    /// Dzieli ciąg na równe korpusy mieszczące się w limicie.
    ///
    /// - Parameters:
    ///   - runWidth: całkowita szerokość ciągu w świetle ścian.
    ///   - maxWidth: górny limit podziałki; domyślnie rozpiętość półki.
    ///   - grid: zaokrąglenie podziałek, domyślnie 1 mm. Przy 10 reszta i tak
    ///     jest rozdzielana po 1 mm, żeby suma zgadzała się co do milimetra —
    ///     ciąg musi wypełnić ścianę, a nie „prawie".
    public static func plan(
        runWidth: Millimeters,
        maxWidth: Millimeters = maxShelfSpan,
        grid: Millimeters = 1
    ) -> Plan {
        guard runWidth > .zero else {
            return Plan(widths: [], reason: "Ciąg ma zerową szerokość.")
        }
        let limit = max(maxWidth, minCarcassWidth)

        if runWidth <= limit {
            return Plan(
                widths: [runWidth],
                reason: String(
                    format: "Jeden korpus %.0f mm — mieści się w limicie %.0f mm.",
                    runWidth.rawValue, limit.rawValue))
        }

        let ile = Int(ceil(runWidth.rawValue / limit.rawValue))
        let widths = rozdziel(runWidth, na: ile, grid: grid)
        let podzialka = widths.first?.rawValue ?? 0

        return Plan(
            widths: widths,
            reason: String(
                format: "%d korpusów po ok. %.0f mm — przy jednym module "
                    + "półka miałaby %.0f mm rozpiętości i ugięłaby się.",
                ile, podzialka, runWidth.rawValue))
    }

    /// Podział na zadaną liczbę korpusów, gdy projektant sam wie ile chce.
    public static func plan(
        runWidth: Millimeters,
        count: Int,
        grid: Millimeters = 1
    ) -> Plan {
        let ile = max(1, count)
        let widths = rozdziel(runWidth, na: ile, grid: grid)
        let szerokosc = widths.first ?? .zero
        var powod = String(
            format: "%d korpusów po ok. %.0f mm.", ile, szerokosc.rawValue)
        if szerokosc > maxShelfSpan {
            powod += String(
                format: " Uwaga: %.0f mm to więcej niż %.0f mm rozpiętości półki.",
                szerokosc.rawValue, maxShelfSpan.rawValue)
        }
        if szerokosc < minCarcassWidth {
            powod += String(
                format: " Uwaga: %.0f mm to mniej niż %.0f mm — okucia nie wejdą.",
                szerokosc.rawValue, minCarcassWidth.rawValue)
        }
        return Plan(widths: widths, reason: powod)
    }

    /// Czy zespół o tej szerokości da się w ogóle wykonać jako jeden korpus.
    public static func needsSplit(runWidth: Millimeters,
                                  maxWidth: Millimeters = maxShelfSpan) -> Bool {
        runWidth > max(maxWidth, minCarcassWidth)
    }

    // MARK: - Rozdział

    /// Równe podziałki, których suma jest DOKŁADNIE równa szerokości ciągu.
    ///
    /// Zaokrąglanie każdej podziałki osobno zostawia resztę i ciąg nie domyka się
    /// do ściany. Dlatego najpierw dzielimy po siatce w dół, a resztę rozdajemy
    /// po jednym milimetrze od lewej — różnica między najszerszym a najwęższym
    /// korpusem nigdy nie przekracza kroku siatki.
    private static func rozdziel(
        _ calosc: Millimeters, na ile: Int, grid: Millimeters
    ) -> [Millimeters] {
        guard ile > 0 else { return [] }
        let krok = max(grid.rawValue, 1)
        let suma = calosc.rawValue
        let bazowa = (suma / Double(ile) / krok).rounded(.down) * krok
        var widths = Array(repeating: bazowa, count: ile)

        var reszta = suma - bazowa * Double(ile)
        var i = 0
        while reszta > 0.0001 {
            let dodaj = min(krok, reszta)
            widths[i % ile] += dodaj
            reszta -= dodaj
            i += 1
        }
        return widths.map { Millimeters($0) }
    }
}
