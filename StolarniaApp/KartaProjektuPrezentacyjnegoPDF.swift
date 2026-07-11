import DomainCore
import SwiftUI
import UIKit

enum KartaProjektuPrezentacyjnegoPDFV061 {
    enum Blad: LocalizedError {
        case renderowanie

        var errorDescription: String? {
            "Nie udało się wyrenderować karty projektu."
        }
    }

    @MainActor
    static func generuj(
        room: RoomDefinition,
        wall: WallSegment,
        assemblies: [FurnitureAssembly],
        globalneMaterialy: GlobalneMaterialyPomieszczenia
    ) throws -> URL {
        let pageSize = CGSize(width: 1190, height: 842)
        let renderer = ImageRenderer(
            content:
                KartaProjektuPrezentacyjnegoPlanszaV061(
                    room: room,
                    wall: wall,
                    assemblies: assemblies,
                    globalneMaterialy: globalneMaterialy
                )
                .frame(width: pageSize.width - 40)
                .padding(20)
                .background(Color.white)
        )
        renderer.scale = 2

        guard let image = renderer.uiImage else {
            throw Blad.renderowanie
        }

        let name = bezpiecznaNazwa(
            "Karta-\(room.name)-\(wall.name).pdf"
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)

        let pdf = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize)
        )
        try pdf.writePDF(to: url) { context in
            context.beginPage()
            image.draw(
                in: CGRect(origin: .zero, size: pageSize)
            )
        }
        return url
    }

    private static func bezpiecznaNazwa(
        _ value: String
    ) -> String {
        value
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "pl_PL")
            )
            .replacingOccurrences(
                of: "[^A-Za-z0-9._-]+",
                with: "-",
                options: .regularExpression
            )
    }
}
