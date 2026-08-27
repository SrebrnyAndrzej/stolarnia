import DomainCore
import Foundation

/// Sąsiedzi modułu do przyciągania na płótnie 2D.
///
/// Ta sama logika stała wcześniej **bajt w bajt w dwóch plikach** —
/// `Plan2DCanvasView` i `ElewacjaScianyCanvasView`. Kopia nie jest tu
/// nieszkodliwa: przyciąganie decyduje o tym, czy moduły stoją do siebie
/// w styk, czy ze szparą, a poprawka zrobiona w planie nie docierała do
/// elewacji i odwrotnie. Projektant widziałby wtedy dwa różne zachowania
/// tego samego gestu w dwóch widokach tego samego mebla.
enum PrzyciaganieSasiadow2DV0102 {

    /// Czego **nie** przyciągać do siebie.
    ///
    /// Sam przesuwany moduł oczywiście odpada. Przy zaznaczeniu wielu modułów
    /// odpada cała grupa: przesuwa się ją jako całość, więc jej elementy nie
    /// mogą przyciągać się nawzajem — inaczej grupa zacinałaby się na własnych
    /// krawędziach zamiast jechać za palcem.
    static func idsWykluczone(
        sourceID: FurnitureAssemblyID,
        zaznaczone: Set<FurnitureAssemblyID>
    ) -> Set<FurnitureAssemblyID> {
        guard zaznaczone.count > 1,
              zaznaczone.contains(sourceID) else {
            return [sourceID]
        }
        return zaznaczone
    }

    /// Zakresy modułów, do których wolno przyciągnąć przesuwany moduł.
    ///
    /// Sąsiadem jest moduł stojący **w tej samej linii zabudowy**: ta sama
    /// ściana, ta sama warstwa (dolna / wisząca / górna / wysoka), ta sama
    /// wysokość od podłogi i to samo odsunięcie od ściany. Tolerancja 1 mm
    /// bierze się stąd, że wysokości i odsunięcia pochodzą z liczb
    /// zmiennoprzecinkowych — dwa moduły ustawione „równo" potrafią różnić się
    /// o ułamek milimetra i bez tolerancji przestałyby być sąsiadami.
    ///
    /// Szafka wisząca nie przyciąga się więc do dolnej, choć na rzucie stoją
    /// jedna nad drugą.
    static func sasiedzi(
        dla assembly: FurnitureAssembly,
        placement: FurniturePlacement,
        wsrod assemblies: [FurnitureAssembly],
        zaznaczone: Set<FurnitureAssemblyID>
    ) -> [ZakresModuluPrzyciagania2D] {
        let warstwaZrodla = MebelPlan2DGeometry.layer(for: assembly)
        let wykluczone = idsWykluczone(
            sourceID: assembly.id,
            zaznaczone: zaznaczone
        )

        return assemblies.compactMap { kandydat in
            guard !wykluczone.contains(kandydat.id),
                  let polozenie = kandydat.placement,
                  polozenie.wallID == placement.wallID,
                  MebelPlan2DGeometry.layer(for: kandydat) == warstwaZrodla,
                  abs(
                    polozenie.bottomOffset.rawValue
                    - placement.bottomOffset.rawValue
                  ) <= tolerancjaLiniiMM,
                  abs(
                    polozenie.offsetFromWall.rawValue
                    - placement.offsetFromWall.rawValue
                  ) <= tolerancjaLiniiMM
            else {
                return nil
            }

            return ZakresModuluPrzyciagania2D(
                furnitureID: kandydat.id,
                start: polozenie.offsetAlongWall,
                end: polozenie.offsetAlongWall + kandydat.size.width
            )
        }
    }

    /// Ile milimetrów różnicy wysokości albo odsunięcia nadal znaczy
    /// „ta sama linia zabudowy".
    private static let tolerancjaLiniiMM = 1.0
}
