import DomainCore
import Foundation

/// Wynik atomowego duplikowania kilku modułów.
///
/// Wszystkie nowe moduły są zapisywane albo żaden z nich nie pozostaje
/// w repozytorium. Operacja stanu zawiera również karty techniczne i ciągi,
/// dlatego może zostać bezpiecznie cofnięta przez historię v0.65.
struct WynikDuplikowaniaGrupyV067 {
    let noweID: Set<FurnitureAssemblyID>
    let glowneID: FurnitureAssemblyID?
    let operacja: OperacjaStanuModulowV065
}

/// Dane przekazywane z płótna do wspólnego stanu zaznaczenia workspace.
struct ZaznaczenieRamkaV067 {
    let ids: Set<FurnitureAssemblyID>
    let preferowaneGlowneID: FurnitureAssemblyID?
}
