import Foundation

/// Geometria biegu schodów i obwiednia zabudowy pod nimi.
///
/// Powstało, bo `underStairs` było w bibliotece **samą kategorią bez geometrii** —
/// aplikacja nie znała ani wysokości stopnia, ani linii policzka, więc zabudowy
/// pod schodami nie dawało się zaprojektować inaczej niż ręcznie, szafka po
/// szafce, z wymiarami wziętymi z miarki.
///
/// Normy (warunki techniczne, PN-B-03406 dla budynków mieszkalnych):
/// - wysokość stopnia **maks. 190 mm**, typowo 170–180;
/// - głębokość stopnia **min. 250 mm**, optymalnie 280–300;
/// - wzór Blondela: `2h + s = 590…650 mm`, cel 630;
/// - minimalny przeświat nad biegiem **2000 mm**.
public struct StaircaseGeometry: Hashable, Sendable, Codable {

    /// W którą stronę bieg się wznosi, patrząc na elewację zabudowy.
    public enum Ascent: String, Codable, Hashable, Sendable, CaseIterable {
        case toRight
        case toLeft

        public var displayName: String {
            self == .toRight ? "W prawo" : "W lewo"
        }
    }

    // MARK: - Normy

    public static let maxRise: Millimeters = 190
    public static let minGoing: Millimeters = 250
    public static let blondelRange: ClosedRange<Double> = 590...650
    public static let blondelTarget: Millimeters = 630
    public static let minHeadroom: Millimeters = 2_000

    // MARK: - Definicja

    /// Wysokość jednego stopnia.
    public var rise: Millimeters
    /// Głębokość jednego stopnia (bez noska).
    public var going: Millimeters
    public var stepCount: Int
    public var ascent: Ascent
    /// Grubość policzka/płyty biegu — obwiednia zabudowy jest o nią niżej.
    public var stringerThickness: Millimeters

    public init(
        rise: Millimeters,
        going: Millimeters,
        stepCount: Int,
        ascent: Ascent = .toRight,
        stringerThickness: Millimeters = 40
    ) {
        self.rise = rise
        self.going = going
        self.stepCount = max(stepCount, 1)
        self.ascent = ascent
        self.stringerThickness = stringerThickness
    }

    // MARK: - Wymiary biegu

    /// Całkowity rzut poziomy biegu.
    public var totalRun: Millimeters { going * Double(stepCount) }
    /// Całkowita wysokość pokonywana przez bieg.
    public var totalRise: Millimeters { rise * Double(stepCount) }

    /// Kąt nachylenia biegu w stopniach.
    public var angleDegrees: Double {
        guard going.rawValue > 0 else { return 90 }
        return atan2(rise.rawValue, going.rawValue) * 180 / .pi
    }

    /// Wartość wzoru Blondela dla tego biegu.
    public var blondelValue: Double {
        2 * rise.rawValue + going.rawValue
    }

    // MARK: - Obwiednia zabudowy

    /// Dostępna wysokość zabudowy w odległości `distance` od najniższego stopnia.
    ///
    /// Liczona **po linii policzka**, czyli po dolnej krawędzi biegu, a nie po
    /// nosach stopni — pod schodami mebel opiera się o spód konstrukcji.
    /// Poza rzutem biegu zwraca zero: tam nie ma już czego zabudowywać.
    public func availableHeight(atDistance distance: Millimeters) -> Millimeters {
        guard distance >= .zero, distance <= totalRun else { return .zero }
        // Linia spodu biegu: wznosi się tak samo jak schody, ale jest niżej
        // o grubość policzka.
        let podLinia = distance.rawValue * (rise.rawValue / max(going.rawValue, 1))
            - stringerThickness.rawValue
        return Millimeters(max(podLinia, 0))
    }

    /// Największa wysokość szafki, jaka zmieści się na odcinku `[od, do]`.
    ///
    /// Bierzemy **niższy koniec** odcinka, bo szafka jest prostopadłościanem —
    /// musi zmieścić się w najniższym punkcie swojego zakresu, nie w najwyższym.
    /// To jest ten błąd, który przy ręcznym projektowaniu kończy się szafką
    /// wchodzącą w policzek.
    public func maximumCabinetHeight(
        from start: Millimeters,
        to end: Millimeters
    ) -> Millimeters {
        let a = availableHeight(atDistance: start)
        let b = availableHeight(atDistance: end)
        return min(a, b)
    }

    // MARK: - Kontrola

    /// Sprawdza bieg wobec norm i wzoru Blondela.
    public func inspect() -> [ProductionIssue] {
        var uwagi: [ProductionIssue] = []

        if rise > Self.maxRise {
            uwagi.append(ProductionIssue(
                severity: .error,
                message: String(
                    format: "stopień %.0f mm przekracza dopuszczalne %.0f mm",
                    rise.rawValue, Self.maxRise.rawValue),
                hint: "warunki techniczne dla budynków mieszkalnych"))
        }
        if going < Self.minGoing {
            uwagi.append(ProductionIssue(
                severity: .error,
                message: String(
                    format: "głębokość stopnia %.0f mm poniżej minimum %.0f mm",
                    going.rawValue, Self.minGoing.rawValue),
                hint: "PN-B-03406"))
        }
        if !Self.blondelRange.contains(blondelValue) {
            uwagi.append(ProductionIssue(
                severity: .warning,
                message: String(
                    format: "2h+s = %.0f mm poza zakresem %.0f–%.0f mm",
                    blondelValue,
                    Self.blondelRange.lowerBound,
                    Self.blondelRange.upperBound),
                hint: "wzór Blondela — schody będą męczące w chodzeniu"))
        }
        if angleDegrees > 42 {
            uwagi.append(ProductionIssue(
                severity: .warning,
                message: String(format: "nachylenie %.0f° jest strome", angleDegrees),
                hint: "powyżej ok. 42° schody wymagają ostrożnego schodzenia"))
        }
        return uwagi
    }

    // MARK: - Propozycja zabudowy

    public struct UnderStairsBay: Hashable, Sendable, Identifiable {
        public var id: Int
        /// Odległość lewej krawędzi od najniższego stopnia.
        public var offset: Millimeters
        public var width: Millimeters
        /// Wysokość korpusu — ograniczona linią policzka na całej szerokości.
        public var height: Millimeters
        public var note: String

        public init(id: Int, offset: Millimeters, width: Millimeters,
                    height: Millimeters, note: String = "") {
            self.id = id
            self.offset = offset
            self.width = width
            self.height = height
            self.note = note
        }
    }

    /// Dzieli przestrzeń pod biegiem na szafki o malejącej wysokości.
    ///
    /// - Parameters:
    ///   - bayWidth: podziałka szafek; ostatnia bywa węższa.
    ///   - minimumHeight: poniżej tej wysokości nie ma sensu robić szafki —
    ///     zostaje przestrzeń techniczna albo front rewizyjny.
    ///   - clearance: luz między korpusem a spodem biegu (montaż, tynk, praca
    ///     konstrukcji drewnianej).
    public func proposeBays(
        bayWidth: Millimeters = 500,
        minimumHeight: Millimeters = 300,
        clearance: Millimeters = 20
    ) -> [UnderStairsBay] {
        guard totalRun > .zero, bayWidth > .zero else { return [] }

        var wynik: [UnderStairsBay] = []
        var offset = Millimeters.zero
        var i = 0

        while offset < totalRun {
            let szerokosc = min(bayWidth, totalRun - offset)
            let surowa = maximumCabinetHeight(from: offset, to: offset + szerokosc)
            let wysokosc = surowa - clearance

            if wysokosc >= minimumHeight {
                wynik.append(UnderStairsBay(
                    id: i,
                    offset: offset,
                    width: szerokosc,
                    height: wysokosc,
                    note: opis(dlaWysokosci: wysokosc)))
                i += 1
            }
            offset = offset + szerokosc
        }
        // Kolejność zawsze od najniższej strony biegu; przy biegu w lewo
        // odbijamy offsety, żeby elewacja zgadzała się z montażem.
        if ascent == .toLeft {
            wynik = wynik.map { bay in
                var kopia = bay
                kopia.offset = totalRun - bay.offset - bay.width
                return kopia
            }
            .sorted { $0.offset < $1.offset }
        }
        return wynik
    }

    /// Co da się w danej wysokości sensownie zmieścić — podpowiedź, nie reguła.
    private func opis(dlaWysokosci wysokosc: Millimeters) -> String {
        switch wysokosc.rawValue {
        case ..<600:   return "szuflada niska albo front rewizyjny"
        case ..<900:   return "szafka z drzwiami, jedna półka"
        case ..<1_400: return "szafka wysoka, dwie półki"
        default:       return "słupek albo garderoba"
        }
    }
}
