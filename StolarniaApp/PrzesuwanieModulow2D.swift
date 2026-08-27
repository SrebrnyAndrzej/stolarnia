import DomainCore
import Foundation

/// Rodzaj aktywnego punktu przyciągania podczas przesuwania modułu.
enum RodzajPrzyciagnieciaModulu2D: String, Sendable {
    case poczatekSciany
    case koniecSciany
    case poczatekCiagu
    case koniecCiagu
    case krawedzSasiada

    var tytul: String {
        switch self {
        case .poczatekSciany:
            return "Początek ściany"
        case .koniecSciany:
            return "Koniec ściany"
        case .poczatekCiagu:
            return "Początek ciągu"
        case .koniecCiagu:
            return "Koniec ciągu"
        case .krawedzSasiada:
            return "Krawędź mebla"
        }
    }
}



/// Rodzaj pionowego wyrównania aktywnego w elewacji.
enum RodzajPrzyciagnieciaPionowego2D: String, Sendable {
    case podloga
    case sufit
    case dolSasiada
    case goraSasiada

    var tytul: String {
        switch self {
        case .podloga:
            return "Wyrównanie do podłogi"
        case .sufit:
            return "Wyrównanie do góry"
        case .dolSasiada:
            return "Wyrównanie do dołu mebla"
        case .goraSasiada:
            return "Wyrównanie do góry mebla"
        }
    }
}

/// Zakres pionowy sąsiadującego modułu w elewacji.
struct ZakresPionowyModuluPrzyciagania2D: Sendable {
    let furnitureID: FurnitureAssemblyID
    let bottom: Millimeters
    let top: Millimeters
}

/// Wynik pionowego snapu. `proponowaneOdsuniecieOdDolu` odpowiada
/// wartości `FurniturePlacement.bottomOffset`.
struct PunktPrzyciagnieciaPionowego2D: Sendable {
    let proponowaneOdsuniecieOdDolu: Millimeters
    let liniaProwadzaca: Millimeters
    let rodzaj: RodzajPrzyciagnieciaPionowego2D
    let sasiadID: FurnitureAssemblyID?
}

/// Zakres zajmowany przez inny moduł na osi aktualnej ściany.
struct ZakresModuluPrzyciagania2D: Sendable {
    let furnitureID: FurnitureAssemblyID
    let start: Millimeters
    let end: Millimeters
}

/// Punkt, do którego został przyciągnięty przesuwany moduł.
///
/// `proponowaneOdsuniecie` oznacza położenie lewej krawędzi modułu,
/// a `liniaProwadzaca` pozycję prowadnicy wyświetlanej na rysunku.
struct PunktPrzyciagnieciaModulu2D: Sendable {
    let proponowaneOdsuniecie: Millimeters
    let liniaProwadzaca: Millimeters
    let rodzaj: RodzajPrzyciagnieciaModulu2D
    let sasiadID: FurnitureAssemblyID?
}

/// Wynik gestu przeciągania modułu w planie albo elewacji 2D.
///
/// Wartość `proponowaneOdsuniecie` jest liczona od początku aktualnej ściany.
/// Jeżeli środek przeciąganego modułu znajdzie się nad zgodnym modułem,
/// `celZamianyID` wskazuje moduł, z którym należy zamienić kolejność.
///
/// Przyciąganie ma pierwszeństwo przed zamianą. Dzięki temu przeciągnięcie
/// blisko krawędzi sąsiada ustawia moduł dokładnie przy nim, zamiast
/// przypadkowo uruchamiać zamianę.
struct KontekstPrzesunieciaModulu2D: Sendable {
    let furnitureID: FurnitureAssemblyID
    let wallID: WallID?
    let proponowaneOdsuniecie: Millimeters
    let proponowaneOdsuniecieOdSciany: Millimeters?
    let celZamianyID: FurnitureAssemblyID?
    let przyciagniecie: PunktPrzyciagnieciaModulu2D?
    let proponowaneOdsuniecieOdDolu: Millimeters?
    let przyciagnieciePionowe: PunktPrzyciagnieciaPionowego2D?

    init(
        furnitureID: FurnitureAssemblyID,
        wallID: WallID?,
        proponowaneOdsuniecie: Millimeters,
        proponowaneOdsuniecieOdSciany: Millimeters? = nil,
        celZamianyID: FurnitureAssemblyID?,
        przyciagniecie: PunktPrzyciagnieciaModulu2D? = nil,
        proponowaneOdsuniecieOdDolu: Millimeters? = nil,
        przyciagnieciePionowe: PunktPrzyciagnieciaPionowego2D? = nil
    ) {
        self.furnitureID = furnitureID
        self.wallID = wallID
        self.proponowaneOdsuniecie = proponowaneOdsuniecie
        self.proponowaneOdsuniecieOdSciany =
            proponowaneOdsuniecieOdSciany
        self.celZamianyID = celZamianyID
        self.przyciagniecie = przyciagniecie
        self.proponowaneOdsuniecieOdDolu = proponowaneOdsuniecieOdDolu
        self.przyciagnieciePionowe = przyciagnieciePionowe
    }

    var jestZamiana: Bool {
        celZamianyID != nil
    }

    var jestPrzyciagniety: Bool {
        przyciagniecie != nil || przyciagnieciePionowe != nil
    }
}

/// Wspólny, deterministyczny silnik przyciągania dla planu od góry
/// i elewacji ściany.
enum PrzyciaganieModulow2D {
    /// Domyślny próg jest liczony w punktach ekranu przez konkretny widok,
    /// a następnie przeliczany na milimetry modelu.
    static let domyslnyProgEkranowy: Double = 18

    static func najlepszyPunkt(
        suroweOdsuniecie: Millimeters,
        szerokoscModulu: Millimeters,
        dlugoscSciany: Millimeters,
        sasiedzi: [ZakresModuluPrzyciagania2D],
        prog: Millimeters
    ) -> PunktPrzyciagnieciaModulu2D? {
        let maximumOffset = max(
            dlugoscSciany.rawValue - szerokoscModulu.rawValue,
            0
        )
        let rawOffset = min(
            max(suroweOdsuniecie.rawValue, 0),
            maximumOffset
        )
        let threshold = max(prog.rawValue, 0)

        struct Candidate {
            let offset: Double
            let guide: Double
            let kind: RodzajPrzyciagnieciaModulu2D
            let neighborID: FurnitureAssemblyID?
            let priority: Int
        }

        var candidates: [Candidate] = [
            Candidate(
                offset: 0,
                guide: 0,
                kind: .poczatekSciany,
                neighborID: nil,
                priority: 2
            ),
            Candidate(
                offset: maximumOffset,
                guide: dlugoscSciany.rawValue,
                kind: .koniecSciany,
                neighborID: nil,
                priority: 2
            )
        ]

        let sortedNeighbors = sasiedzi.sorted {
            if abs($0.start.rawValue - $1.start.rawValue) > 0.5 {
                return $0.start.rawValue < $1.start.rawValue
            }
            return $0.end.rawValue < $1.end.rawValue
        }

        for (index, neighbor) in sortedNeighbors.enumerated() {
            let isFirst = index == sortedNeighbors.startIndex
            let isLast = index == sortedNeighbors.index(before: sortedNeighbors.endIndex)

            // Moduł ustawiony bezpośrednio przed sąsiadem.
            candidates.append(
                Candidate(
                    offset:
                        neighbor.start.rawValue
                        - szerokoscModulu.rawValue,
                    guide: neighbor.start.rawValue,
                    kind: isFirst
                        ? .poczatekCiagu
                        : .krawedzSasiada,
                    neighborID: neighbor.furnitureID,
                    priority: isFirst ? 1 : 0
                )
            )

            // Moduł ustawiony bezpośrednio za sąsiadem.
            candidates.append(
                Candidate(
                    offset: neighbor.end.rawValue,
                    guide: neighbor.end.rawValue,
                    kind: isLast
                        ? .koniecCiagu
                        : .krawedzSasiada,
                    neighborID: neighbor.furnitureID,
                    priority: isLast ? 1 : 0
                )
            )
        }

        let valid = candidates.filter { candidate in
            guard candidate.offset >= -0.5,
                  candidate.offset <= maximumOffset + 0.5,
                  abs(candidate.offset - rawOffset) <= threshold else {
                return false
            }

            let proposedStart = candidate.offset
            let proposedEnd =
                proposedStart + szerokoscModulu.rawValue

            return !sortedNeighbors.contains { neighbor in
                proposedStart < neighbor.end.rawValue - 0.5
                    && proposedEnd > neighbor.start.rawValue + 0.5
            }
        }

        guard let best = valid.min(by: { lhs, rhs in
            let lhsDistance = abs(lhs.offset - rawOffset)
            let rhsDistance = abs(rhs.offset - rawOffset)

            if abs(lhsDistance - rhsDistance) > 0.25 {
                return lhsDistance < rhsDistance
            }
            return lhs.priority < rhs.priority
        }) else {
            return nil
        }

        return PunktPrzyciagnieciaModulu2D(
            proponowaneOdsuniecie: Millimeters(
                min(max(best.offset, 0), maximumOffset)
            ),
            liniaProwadzaca: Millimeters(
                min(
                    max(best.guide, 0),
                    dlugoscSciany.rawValue
                )
            ),
            rodzaj: best.kind,
            sasiadID: best.neighborID
        )
    }

    static func najlepszyPunktPionowy(
        suroweOdsuniecieOdDolu: Millimeters,
        wysokoscModulu: Millimeters,
        wysokoscSciany: Millimeters,
        sasiedzi: [ZakresPionowyModuluPrzyciagania2D],
        prog: Millimeters
    ) -> PunktPrzyciagnieciaPionowego2D? {
        let maximumBottom = max(
            wysokoscSciany.rawValue - wysokoscModulu.rawValue,
            0
        )
        let rawBottom = min(
            max(suroweOdsuniecieOdDolu.rawValue, 0),
            maximumBottom
        )
        let threshold = max(prog.rawValue, 0)

        struct Candidate {
            let bottom: Double
            let guide: Double
            let kind: RodzajPrzyciagnieciaPionowego2D
            let neighborID: FurnitureAssemblyID?
            let priority: Int
        }

        var candidates: [Candidate] = [
            Candidate(
                bottom: 0,
                guide: 0,
                kind: .podloga,
                neighborID: nil,
                priority: 1
            ),
            Candidate(
                bottom: maximumBottom,
                guide: wysokoscSciany.rawValue,
                kind: .sufit,
                neighborID: nil,
                priority: 1
            )
        ]

        for neighbor in sasiedzi {
            candidates.append(
                Candidate(
                    bottom: neighbor.bottom.rawValue,
                    guide: neighbor.bottom.rawValue,
                    kind: .dolSasiada,
                    neighborID: neighbor.furnitureID,
                    priority: 0
                )
            )
            candidates.append(
                Candidate(
                    bottom:
                        neighbor.top.rawValue
                        - wysokoscModulu.rawValue,
                    guide: neighbor.top.rawValue,
                    kind: .goraSasiada,
                    neighborID: neighbor.furnitureID,
                    priority: 0
                )
            )
        }

        let valid = candidates.filter { candidate in
            candidate.bottom >= -0.5
                && candidate.bottom <= maximumBottom + 0.5
                && abs(candidate.bottom - rawBottom) <= threshold
        }

        guard let best = valid.min(by: { lhs, rhs in
            let lhsDistance = abs(lhs.bottom - rawBottom)
            let rhsDistance = abs(rhs.bottom - rawBottom)

            if abs(lhsDistance - rhsDistance) > 0.25 {
                return lhsDistance < rhsDistance
            }
            return lhs.priority < rhs.priority
        }) else {
            return nil
        }

        return PunktPrzyciagnieciaPionowego2D(
            proponowaneOdsuniecieOdDolu: Millimeters(
                min(max(best.bottom, 0), maximumBottom)
            ),
            liniaProwadzaca: Millimeters(
                min(
                    max(best.guide, 0),
                    wysokoscSciany.rawValue
                )
            ),
            rodzaj: best.kind,
            sasiadID: best.neighborID
        )
    }

    static func odsuniecieDoSiatki(
        _ value: Millimeters,
        krok: Millimeters = 10
    ) -> Millimeters {
        guard krok.rawValue > 0 else {
            return value
        }

        return Millimeters(
            (value.rawValue / krok.rawValue).rounded()
                * krok.rawValue
        )
    }
}
