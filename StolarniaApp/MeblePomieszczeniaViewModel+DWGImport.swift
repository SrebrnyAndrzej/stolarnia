import DomainCore
import Foundation

/// Rozszerzenie ViewModelu o batch import modułów z DWG.
/// Wydzielone do osobnego pliku, żeby nie rozdmuchiwać istniejącego god-file
/// `MeblePomieszczeniaViewModel.swift` (3000+ linii).
///
/// MVP: wszystkie moduły importowane są jako przypięte do pierwszej dostępnej ściany.
/// Freestanding (wyspa) wymaga rozszerzenia `MebelPlan2DGeometry` o obsługę
/// `placement.wallID == nil` — zostawione na kolejny sprint zgodnie z GUIDE.
extension MeblePomieszczeniaViewModel {

    struct WynikImportuDWGV001 {
        var dodane: Int
        var pominiete: Int
        var blad: String?
    }

    /// Importuje batch modułów z DWG.
    /// - Parameters:
    ///   - plany: lista modułów przygotowana przez `DWGImportAssemblyMapperV001`
    ///   - room: pomieszczenie docelowe
    ///   - walls: ściany pomieszczenia — używane do fallbacku dla freestanding
    /// - Returns: podsumowanie z liczbą dodanych/pominiętych + ewentualny błąd.
    @MainActor
    func importujZDWG(
        plany: [PlanImportuDWGV001],
        room: RoomDefinition,
        walls: [WallSegment]
    ) async -> WynikImportuDWGV001 {
        guard let scianaBazowa = walls.first else {
            return WynikImportuDWGV001(
                dodane: 0,
                pominiete: plany.count,
                blad: "Brak ścian w pomieszczeniu — nie można zaimportować."
            )
        }

        var dodane = 0
        var pominiete = 0
        var ostatniBlad: String?

        for plan in plany {
            // Wybór ściany: docelowa (o ile podana), fallback do pierwszej.
            let scianaDocelowa: WallSegment
            if let wallID = plan.wallID,
               let znaleziona = walls.first(where: { $0.id == wallID }) {
                scianaDocelowa = znaleziona
            } else {
                scianaDocelowa = scianaBazowa
            }

            // Bezpieczne wartości offsetu — obetnij pozycję do zakresu ściany.
            var daneOgraniczone = plan.data
            daneOgraniczone.offsetAlongWall = min(
                max(plan.data.offsetAlongWall, .zero),
                max(scianaDocelowa.length - plan.data.width, .zero)
            )
            daneOgraniczone.offsetFromWall = .zero

            let ok = await createModule(
                template: plan.template,
                data: daneOgraniczone,
                wall: scianaDocelowa,
                room: room
            )

            if ok {
                dodane += 1
            } else {
                pominiete += 1
                if ostatniBlad == nil {
                    ostatniBlad = errorMessage
                }
            }
        }

        return WynikImportuDWGV001(
            dodane: dodane,
            pominiete: pominiete,
            blad: ostatniBlad
        )
    }
}
