import DomainCore
import Foundation

/// Pojedynczy przygotowany moduł do zapisu w bibliotece pomieszczenia.
/// Mapper produkuje listę takich planów; `MeblePomieszczeniaViewModel`
/// je konsumuje w batch, zapisując przez repozytoria.
struct PlanImportuDWGV001: Sendable, Identifiable {
    var id: String
    var template: FurnitureTemplate
    var data: KonfiguracjaModuluMeblowegoDane
    /// `nil` dla mebli wolnostojących (wyspa) — placement bez wallID.
    var wallID: WallID?
    var rotationDegrees: Double
    var anchoringMode: FurnitureAnchoringMode
    /// Współrzędne w pomieszczeniu dla mebli wolnostojących
    /// (X = pozycja od lewego dolnego rogu, Y = odległość od tylnej ściany).
    var freestandingRoomX: Millimeters
    var freestandingRoomY: Millimeters
}

/// Mapper konwertuje zaakceptowane dopasowania z matchera na plany importu
/// gotowe do przekazania do ViewModelu pomieszczenia.
enum DWGImportAssemblyMapperV001 {
    /// Buduje plany importu tylko dla dopasowań które użytkownik zaakceptował w UI.
    /// `document.unit` decyduje o konwersji mm.
    static func planyImportu(
        document: DWGImportDocumentV001,
        zaakceptowaneMatche: [DWGModuleMatchV001]
    ) -> [PlanImportuDWGV001] {
        let bbox = document.boundingBox
        let originX = bbox?.minX ?? 0
        let originY = bbox?.minY ?? 0

        return zaakceptowaneMatche.compactMap { match -> PlanImportuDWGV001? in
            guard let template = match.suggestedTemplate else {
                return nil
            }

            // Normalizacja układu — przesunięcie bounding boxu do (0,0).
            let normalizedX = match.detected.footprint.x - originX
            let normalizedY = match.detected.footprint.y - originY
            let roomX = DWGImportUnitConverterV001.mm(normalizedX, unit: document.unit)
            let roomY = DWGImportUnitConverterV001.mm(normalizedY, unit: document.unit)

            let data = KonfiguracjaModuluMeblowegoDane(
                name: opisMebla(match: match),
                width: match.targetWidth,
                height: match.targetHeight,
                depth: match.targetDepth,
                shelfCount: 1,
                drawerCount: 0,
                offsetAlongWall: roomX,
                offsetFromWall: roomY,
                bottomOffset: .zero
            )

            return PlanImportuDWGV001(
                id: match.id,
                template: template,
                data: data,
                wallID: nil, // MVP: wszystkie moduły jako wolnostojące; przypinanie do ściany w kolejnym kroku
                rotationDegrees: match.detected.footprint.rotationDegrees,
                anchoringMode: match.anchoringMode,
                freestandingRoomX: roomX,
                freestandingRoomY: roomY
            )
        }
    }

    private static func opisMebla(match: DWGModuleMatchV001) -> String {
        if let rawName = match.detected.rawName, !rawName.isEmpty {
            return rawName
        }
        return match.detected.kind.czytelnaNazwa
    }
}
