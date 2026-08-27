import Foundation
import UIKit

enum KartaTechnicznaPDFError: LocalizedError {
    case cannotCreateDirectory
    case cannotCreateFile

    var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory:
            return "Nie udało się utworzyć folderu dokumentacji."
        case .cannotCreateFile:
            return "Nie udało się utworzyć pliku PDF."
        }
    }
}

@MainActor
enum KartaTechnicznaPDFBuilder {
    static func build(card: KartaTechnicznaSzafki) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StolarniaAppTechnicalDocs", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw KartaTechnicznaPDFError.cannotCreateDirectory
        }

        let fileName = sanitizedFileName(
            "\(card.numerSzafki)_\(card.nazwa)_KartaTechniczna.pdf"
        )
        let url = directory.appendingPathComponent(fileName)
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        do {
            try renderer.writePDF(to: url) { context in
                drawSummaryPage(context: context, bounds: pageBounds, card: card)

                if !card
                    .efektywneAkcesoria
                    .isEmpty {
                    drawAccessoriesPages(
                        context: context,
                        bounds: pageBounds,
                        card: card
                    )
                }

                if let slopeReport =
                    card.raportPaneliSkosuV0691 {
                    drawSlopePanelPagesV0691(
                        context: context,
                        bounds: pageBounds,
                        card: card,
                        report: slopeReport
                    )
                }

                // v0.90.0: rysunek przestrzenny — widok złożony i rozstrzelony.
                // Arkusz A4 celowo go nie zawiera, a scena 3D nie trafia do PDF.
                StronaRysunkuPrzestrzennegoV090.rysuj(
                    context: context,
                    bounds: pageBounds,
                    card: card
                )

                for element in card.efektywneElementy {
                    drawElementPage(
                        context: context,
                        bounds: pageBounds,
                        card: card,
                        element: element
                    )
                }
            }
        } catch {
            throw KartaTechnicznaPDFError.cannotCreateFile
        }

        return url
    }

    private static func drawSummaryPage(
        context: UIGraphicsPDFRendererContext,
        bounds: CGRect,
        card: KartaTechnicznaSzafki
    ) {
        context.beginPage()
        let margin: CGFloat = 36
        var y: CGFloat = 36

        drawText(
            "KARTA TECHNICZNA SZAFKI",
            rect: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 30),
            font: .boldSystemFont(ofSize: 22)
        )
        y += 38

        drawText(
            "\(card.numerSzafki) — \(card.nazwa)",
            rect: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 26),
            font: .boldSystemFont(ofSize: 18)
        )
        y += 34

        let railLines =
            KartaTechnicznaProwadniceSzufladV084
                .linie(w: card)
        var rows = [
            ("Konstrukcja", card.rodzajKonstrukcji),
            ("Wymiary", "\(format(card.szerokoscMM)) × \(format(card.wysokoscMM)) × \(format(card.glebokoscMM)) mm"),
            ("Materiał korpusu", card.materialKorpusu),
            ("Materiał frontu", card.materialFrontu),
            ("Liczba elementów", "\(card.efektywneElementy.count)"),
            ("Szuflady", "\(card.efektywneSzuflady.count)"),
            ("Pozycje okuć", "\(card.efektywneAkcesoria.count)"),
            ("Szacowana wartość okuć", currency(hardwareGrossTotal(card)))
        ]

        if let slopeReport =
            card.raportPaneliSkosuV0691 {
            rows.append(
                (
                    "Panele pod skosem",
                    "\(slopeReport.panele.count)"
                )
            )
        }

        if let corner =
            card.narożnikTechnicznyV086 {
            rows.append(
                (
                    "Narożnik",
                    "\(corner.kind.title) • \(corner.accessTechnology.title) • \(corner.handedness.title)"
                )
            )
        }

        if !railLines.isEmpty {
            let systems =
                Set(
                    railLines
                        .map(\.systemSkrocony)
                        .filter {
                            !$0.isEmpty
                                && $0 != "—"
                        }
                )
                .sorted()
                .joined(separator: " / ")

            rows.append(
                (
                    "Linie prowadnic szuflad",
                    "\(railLines.count) osi"
                        + (
                            systems.isEmpty
                            ? ""
                            : " • \(systems)"
                        )
                )
            )
        }

        if let configuration =
            card
                .konfiguracjaFunkcjonalnaV068 {
            let opening =
                ProfilOkuciaResolverV068
                    .efektywneOtwarcie(
                        konfiguracja:
                            configuration
                    )
            let hardware =
                configuration
                    .front
                    .profilOkuciaID
                    .isEmpty
                ? "Brak"
                : ProfilOkuciaResolverV068
                    .opis(
                        id:
                            configuration
                                .front
                                .profilOkuciaID
                    )

            rows.insert(
                (
                    "Otwieranie frontu",
                    opening.nazwa
                ),
                at: 4
            )
            rows.insert(
                (
                    "Okucie frontu",
                    hardware
                ),
                at: 5
            )
        }

        for row in rows {
            drawLabelValue(
                label: row.0,
                value: row.1,
                x: margin,
                y: y,
                width: bounds.width - margin * 2
            )
            y += 22
        }

        y += 12
        drawText(
            "Schemat frontowy",
            rect: CGRect(x: margin, y: y, width: 200, height: 22),
            font: .boldSystemFont(ofSize: 14)
        )
        y += 28

        let drawingRect = CGRect(
            x: margin,
            y: y,
            width: bounds.width - margin * 2,
            height:
                card.narożnikTechnicznyV086 == nil
                ? 280
                : 220
        )

        if let corner =
            card.narożnikTechnicznyV086 {
            let gap: CGFloat = 12
            let frontRect =
                CGRect(
                    x: drawingRect.minX,
                    y: drawingRect.minY,
                    width:
                        drawingRect.width * 0.55,
                    height:
                        drawingRect.height
                )
            let cornerRect =
                CGRect(
                    x: frontRect.maxX + gap,
                    y: drawingRect.minY,
                    width:
                        max(
                            drawingRect.maxX
                            - frontRect.maxX
                            - gap,
                            1
                        ),
                    height:
                        drawingRect.height
                )

            drawCabinetSchematic(rect: frontRect, card: card)
            drawCornerPlanV086(
                rect: cornerRect,
                corner: corner
            )
        } else {
            drawCabinetSchematic(rect: drawingRect, card: card)
        }

        y = drawingRect.maxY + 18

        drawText(
            "Lista elementów",
            rect: CGRect(x: margin, y: y, width: 200, height: 22),
            font: .boldSystemFont(ofSize: 14)
        )
        y += 26

        drawElementHeader(x: margin, y: y, width: bounds.width - margin * 2)
        y += 22

        for element in card.efektywneElementy.prefix(11) {
            drawElementRow(
                element: element,
                x: margin,
                y: y,
                width: bounds.width - margin * 2
            )
            y += 22
        }

        if card.efektywneElementy.count > 11 {
            drawText(
                "Pozostałe elementy znajdują się na kolejnych stronach.",
                rect: CGRect(x: margin, y: y + 4, width: bounds.width - margin * 2, height: 18),
                font: .italicSystemFont(ofSize: 9),
                color: .darkGray
            )
        }

        drawFooter(bounds: bounds, text: "StolarniaApp • dokumentacja techniczna")
    }

    private static func drawAccessoriesPages(
        context:
            UIGraphicsPDFRendererContext,
        bounds: CGRect,
        card:
            KartaTechnicznaSzafki
    ) {
        let accessories =
            card.efektywneAkcesoria
        let margin: CGFloat = 36
        let rowHeight: CGFloat = 58
        let usableHeight =
            bounds.height - 110
        let rowsPerPage =
            max(
                Int(
                    usableHeight
                    / rowHeight
                ),
                1
            )

        for pageStart in stride(
            from: 0,
            to: accessories.count,
            by: rowsPerPage
        ) {
            context.beginPage()
            var y: CGFloat = 36

            drawText(
                "OKUCIA I AKCESORIA",
                rect: CGRect(
                    x: margin,
                    y: y,
                    width:
                        bounds.width
                        - margin * 2,
                    height: 30
                ),
                font:
                    .boldSystemFont(
                        ofSize: 22
                    )
            )

            y += 36

            drawText(
                "\(card.numerSzafki) — \(card.nazwa)",
                rect: CGRect(
                    x: margin,
                    y: y,
                    width:
                        bounds.width
                        - margin * 2,
                    height: 22
                ),
                font:
                    .boldSystemFont(
                        ofSize: 14
                    )
            )

            y += 30

            let pageEnd =
                min(
                    pageStart
                    + rowsPerPage,
                    accessories.count
                )

            for accessory in accessories[
                pageStart..<pageEnd
            ] {
                let profile =
                    KatalogRegulAkcesoriow
                        .profil(
                            id:
                                accessory
                                    .profilID
                        )

                UIColor.secondarySystemBackground
                    .setFill()

                UIBezierPath(
                    roundedRect: CGRect(
                        x: margin,
                        y: y,
                        width:
                            bounds.width
                            - margin * 2,
                        height:
                            rowHeight - 6
                    ),
                    cornerRadius: 6
                )
                .fill()

                drawText(
                    "\(accessory.producent) \(accessory.rodzina) — \(accessory.model)",
                    rect: CGRect(
                        x: margin + 8,
                        y: y + 6,
                        width:
                            bounds.width
                            - margin * 2
                            - 80,
                        height: 18
                    ),
                    font:
                        .boldSystemFont(
                            ofSize: 10
                        )
                )

                drawText(
                    "×\(accessory.ilosc)",
                    rect: CGRect(
                        x:
                            bounds.width
                            - margin
                            - 50,
                        y: y + 6,
                        width: 42,
                        height: 18
                    ),
                    font:
                        .boldSystemFont(
                            ofSize: 10
                        ),
                    alignment:
                        .right
                )

                let details =
                    accessoryDetails(
                        accessory,
                        profile: profile
                    )

                drawText(
                    details,
                    rect: CGRect(
                        x: margin + 8,
                        y: y + 25,
                        width:
                            bounds.width
                            - margin * 2
                            - 16,
                        height: 24
                    ),
                    font:
                        .systemFont(
                            ofSize: 8
                        ),
                    color:
                        .darkGray
                )

                y += rowHeight
            }

            drawFooter(
                bounds: bounds,
                text:
                    "\(card.numerSzafki) • okucia i akcesoria"
            )
        }
    }

    private static func accessoryDetails(
        _ accessory:
            InstancjaAkcesoriumSzafki,
        profile:
            ProfilAkcesoriumMeblowego?
    ) -> String {
        var values:
            [String] = []

        if !accessory
            .docelowaEtykietaElementu
            .isEmpty {
            values.append(
                "element \(accessory.docelowaEtykietaElementu)"
            )
        }

        if let length =
            accessory
                .nominalnaDlugoscMM {
            values.append(
                "L \(format(length)) mm"
            )
        }

        if let height =
            accessory
                .wariantWysokosciMM {
            values.append(
                "H \(format(height)) mm"
            )
        }

        if let mass = accessory.masaFrontuKG {
            values.append("masa frontu \(format(mass)) kg")
        }

        if let factor = accessory.wspolczynnikMocy {
            values.append("współczynnik mocy \(format(factor))")
        }

        if let unused = accessory.niewykorzystanaGlebokoscMM {
            values.append("niewykorzystana głębokość \(format(unused)) mm")
        }

        if accessory.wymagaPotwierdzeniaSKU == true {
            values.append("SKU DO POTWIERDZENIA")
        }

        if let bottom =
            accessory
                .gruboscDnaMM {
            values.append(
                "dno \(format(bottom)) mm"
            )
        }

        if let side =
            accessory
                .gruboscBokuMM {
            values.append(
                "bok \(format(side)) mm"
            )
        }

        if let load =
            accessory
                .masaObciazeniaKG {
            values.append(
                "obciążenie \(format(load)) kg"
            )
        }

        if let area =
            accessory
                .powierzchniaWentylacjiCM2 {
            values.append(
                "wentylacja \(format(area)) cm²"
            )
        }

        if let unitPrice =
            accessory
                .cenaJednostkowaBruttoPLN {
            values.append(
                "cena \(currency(unitPrice))"
            )

            values.append(
                "wartość \(currency(unitPrice * Double(max(accessory.ilosc, 0))))"
            )
        }

        if let profile {
            values.append(
                profile.status.nazwa
            )
        }

        return values.joined(
            separator: " • "
        )
    }


    private static func drawSlopePanelPagesV0691(
        context:
            UIGraphicsPDFRendererContext,
        bounds: CGRect,
        card:
            KartaTechnicznaSzafki,
        report:
            RaportPaneliSkosuV0691
    ) {
        let margin: CGFloat = 36

        for (index, panel) in
            report.panele.enumerated()
        {
            context.beginPage()
            var y: CGFloat = 36

            drawText(
                "PANEL PRODUKCYJNY POD SKOSEM",
                rect: CGRect(
                    x: margin,
                    y: y,
                    width:
                        bounds.width
                        - margin * 2,
                    height: 30
                ),
                font:
                    .boldSystemFont(
                        ofSize: 21
                    )
            )
            y += 36

            drawText(
                "\(card.numerSzafki) — \(card.nazwa)",
                rect: CGRect(
                    x: margin,
                    y: y,
                    width:
                        bounds.width
                        - margin * 2,
                    height: 22
                ),
                font:
                    .boldSystemFont(
                        ofSize: 14
                    )
            )
            y += 28

            drawLabelValue(
                label: "Kod",
                value: panel.kod,
                x: margin,
                y: y,
                width:
                    bounds.width
                    - margin * 2
            )
            y += 22

            drawLabelValue(
                label: "Nazwa",
                value: panel.nazwa,
                x: margin,
                y: y,
                width:
                    bounds.width
                    - margin * 2
            )
            y += 22

            drawLabelValue(
                label: "Gabaryt obrysu",
                value:
                    "\(format(panel.szerokoscObrysuMM)) × \(format(panel.wysokoscObrysuMM)) mm",
                x: margin,
                y: y,
                width:
                    bounds.width
                    - margin * 2
            )
            y += 22

            drawLabelValue(
                label: "Grubość",
                value:
                    "\(format(panel.gruboscMM)) mm",
                x: margin,
                y: y,
                width:
                    bounds.width
                    - margin * 2
            )
            y += 22

            drawLabelValue(
                label: "Pole / obwód",
                value:
                    "\(format(panel.poleMM2 / 1_000_000)) m² / \(format(panel.obwodMM)) mm",
                x: margin,
                y: y,
                width:
                    bounds.width
                    - margin * 2
            )
            y += 22

            if abs(
                panel.katMontazuStopnie
            ) > 0.01 {
                drawLabelValue(
                    label: "Kąt montażu",
                    value:
                        "\(format(panel.katMontazuStopnie))°",
                    x: margin,
                    y: y,
                    width:
                        bounds.width
                        - margin * 2
                )
                y += 22
            }

            drawLabelValue(
                label: "Rezerwa montażowa",
                value:
                    "\(format(panel.rezerwaMontazowaMM)) mm",
                x: margin,
                y: y,
                width:
                    bounds.width
                    - margin * 2
            )
            y += 30

            let drawingRect =
                CGRect(
                    x: margin,
                    y: y,
                    width:
                        bounds.width
                        - margin * 2,
                    height: 390
                )
            drawSlopePanelContourV0691(
                panel,
                rect: drawingRect
            )
            y = drawingRect.maxY + 14

            if panel.wymagaSzablonu {
                drawText(
                    "UWAGA: profil wymaga potwierdzenia fizycznym szablonem przed produkcją.",
                    rect: CGRect(
                        x: margin,
                        y: y,
                        width:
                            bounds.width
                            - margin * 2,
                        height: 34
                    ),
                    font:
                        .boldSystemFont(
                            ofSize: 10
                        ),
                    color:
                        .systemOrange
                )
                y += 38
            }

            if index == 0,
               !report.ostrzezenia.isEmpty
            {
                drawText(
                    "Uwagi",
                    rect: CGRect(
                        x: margin,
                        y: y,
                        width: 120,
                        height: 18
                    ),
                    font:
                        .boldSystemFont(
                            ofSize: 11
                        )
                )
                y += 18

                for warning in
                    report.ostrzezenia
                        .prefix(4)
                {
                    drawText(
                        "• \(warning)",
                        rect: CGRect(
                            x: margin,
                            y: y,
                            width:
                                bounds.width
                                - margin * 2,
                            height: 28
                        ),
                        font:
                            .systemFont(
                                ofSize: 9
                            ),
                        color:
                            .darkGray
                    )
                    y += 28
                }
            }

            drawFooter(
                bounds: bounds,
                text:
                    "\(card.numerSzafki) • panel \(index + 1)/\(report.panele.count) • profil \(report.profilID.uuidString.prefix(8))"
            )
        }
    }

    private static func drawSlopePanelContourV0691(
        _ panel:
            PanelProdukcyjnySkosuV0691,
        rect: CGRect
    ) {
        UIColor.secondarySystemBackground
            .setFill()
        UIBezierPath(
            roundedRect: rect,
            cornerRadius: 8
        )
        .fill()

        guard
            panel.kontur.count >= 3,
            let minimumX =
                panel.kontur.map(\.xMM).min(),
            let maximumX =
                panel.kontur.map(\.xMM).max(),
            let minimumY =
                panel.kontur.map(\.yMM).min(),
            let maximumY =
                panel.kontur.map(\.yMM).max()
        else {
            return
        }

        let width =
            max(
                maximumX - minimumX,
                1
            )
        let height =
            max(
                maximumY - minimumY,
                1
            )
        let inset: CGFloat = 34
        let availableWidth =
            max(
                rect.width - inset * 2,
                1
            )
        let availableHeight =
            max(
                rect.height - inset * 2,
                1
            )
        let scale =
            min(
                availableWidth
                    / CGFloat(width),
                availableHeight
                    / CGFloat(height)
            )
        let renderedWidth =
            CGFloat(width) * scale
        let renderedHeight =
            CGFloat(height) * scale
        let originX =
            rect.midX
            - renderedWidth / 2
        let originY =
            rect.midY
            + renderedHeight / 2

        func point(
            _ source:
                PunktKonturuPaneluV0691
        ) -> CGPoint {
            CGPoint(
                x:
                    originX
                    + CGFloat(
                        source.xMM
                        - minimumX
                    )
                    * scale,
                y:
                    originY
                    - CGFloat(
                        source.yMM
                        - minimumY
                    )
                    * scale
            )
        }

        let path = UIBezierPath()
        if let first =
            panel.kontur.first
        {
            path.move(
                to: point(first)
            )
            for item in
                panel.kontur.dropFirst()
            {
                path.addLine(
                    to: point(item)
                )
            }
            path.close()
        }

        UIColor.systemTeal
            .withAlphaComponent(0.16)
            .setFill()
        UIColor.systemTeal.setStroke()
        path.lineWidth = 1.5
        path.fill()
        path.stroke()

        for (index, source) in
            panel.kontur.enumerated()
        {
            let location = point(source)
            UIColor.systemTeal.setFill()
            UIBezierPath(
                ovalIn: CGRect(
                    x: location.x - 2.5,
                    y: location.y - 2.5,
                    width: 5,
                    height: 5
                )
            )
            .fill()

            drawText(
                "\(index + 1): \(format(source.xMM)), \(format(source.yMM))",
                rect: CGRect(
                    x: location.x + 4,
                    y: location.y - 10,
                    width: 110,
                    height: 18
                ),
                font:
                    .systemFont(
                        ofSize: 7
                    ),
                color:
                    .darkGray
            )
        }

        drawText(
            "Współrzędne punktów w mm od lewego dolnego narożnika panelu.",
            rect: CGRect(
                x: rect.minX + 10,
                y: rect.maxY - 22,
                width:
                    rect.width - 20,
                height: 16
            ),
            font:
                .italicSystemFont(
                    ofSize: 8
                ),
            color:
                .darkGray,
            alignment: .center
        )
    }


    private static func drawElementPage(
        context: UIGraphicsPDFRendererContext,
        bounds: CGRect,
        card: KartaTechnicznaSzafki,
        element: ElementTechnicznySzafki
    ) {
        context.beginPage()
        let margin: CGFloat = 36
        var y: CGFloat = 36

        drawText(
            element.etykieta,
            rect: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 30),
            font: .monospacedSystemFont(ofSize: 22, weight: .bold)
        )
        y += 34

        drawText(
            element.nazwa,
            rect: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 24),
            font: .boldSystemFont(ofSize: 17)
        )
        y += 32

        let rows = [
            ("Moduł", "\(card.numerSzafki) — \(card.nazwa)"),
            ("Typ", "\(element.typ.kod) — \(element.typ.nazwa)"),
            ("Wymiary", "\(format(element.dlugoscMM)) × \(format(element.szerokoscMM)) × \(format(element.gruboscMM)) mm"),
            ("Ilość", "\(element.ilosc) szt."),
            ("Materiał", element.material),
            ("Kierunek", element.kierunek.nazwa)
        ]

        for row in rows {
            drawLabelValue(
                label: row.0,
                value: row.1,
                x: margin,
                y: y,
                width: bounds.width - margin * 2
            )
            y += 22
        }

        y += 10
        let drawingRect = CGRect(
            x: margin,
            y: y,
            width: bounds.width - margin * 2,
            height: 330
        )
        drawElementSchematic(rect: drawingRect, element: element)
        y = drawingRect.maxY + 18

        if hasDimensionedMountingMarks(
            element
        ) {
            drawText(
                "Wymiary pierwszych otworów",
                rect: CGRect(x: margin, y: y, width: 260, height: 22),
                font: .boldSystemFont(ofSize: 14)
            )
            y += 26
            drawText(
                "Rysunek powyżej pokazuje punkt startowy: X od krawędzi bazowej oraz Y od dołu formatki. Dalsze otwory prowadnicy wykonać według szablonu wybranego systemu.",
                rect: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 42),
                font: .systemFont(ofSize: 11),
                color: .darkGray
            )
            y += 48
        }

        if !element.uwagi.isEmpty {
            y += 10
            drawText(
                "Uwagi",
                rect: CGRect(x: margin, y: y, width: 100, height: 20),
                font: .boldSystemFont(ofSize: 13)
            )
            y += 22
            drawText(
                element.uwagi,
                rect: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 60),
                font: .systemFont(ofSize: 10),
                color: .darkGray
            )
        }

        drawFooter(bounds: bounds, text: "\(card.numerSzafki) • \(element.etykieta)")
    }

    private static func drawCornerPlanV086(
        rect: CGRect,
        corner:
            NarożnikTechnicznyKartyV086
    ) {
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        drawText(
            "RZUT NAROŻNIKA",
            rect:
                CGRect(
                    x: rect.minX + 10,
                    y: rect.minY + 8,
                    width: rect.width - 20,
                    height: 14
                ),
            font:
                .boldSystemFont(ofSize: 9),
            color:
                .darkGray,
            alignment:
                .center
        )

        let inset: CGFloat = 24
        let available =
            rect.insetBy(
                dx: inset,
                dy: inset + 8
            )
        let primaryW =
            max(
                corner.primaryWallSpanMM,
                1
            )
        let secondaryH =
            max(
                corner.secondaryWallSpanMM,
                1
            )
        let depth =
            max(
                corner.depthMM,
                1
            )
        let totalW =
            max(
                primaryW,
                depth
            )
        let totalH =
            max(
                depth + secondaryH,
                depth * 2
            )
        let scale =
            min(
                available.width
                / CGFloat(totalW),
                available.height
                / CGFloat(totalH)
            )
        let drawingW =
            CGFloat(totalW) * scale
        let drawingH =
            CGFloat(totalH) * scale
        let origin =
            CGPoint(
                x:
                    available.midX
                    - drawingW / 2,
                y:
                    available.midY
                    - drawingH / 2
            )
        let primaryRect =
            CGRect(
                x: origin.x,
                y: origin.y,
                width:
                    CGFloat(primaryW)
                    * scale,
                height:
                    CGFloat(depth)
                    * scale
            )
        let secondaryX =
            corner.handedness == .left
            ? origin.x
            : origin.x
                + CGFloat(primaryW - depth)
                * scale
        let secondaryRect =
            CGRect(
                x: secondaryX,
                y:
                    origin.y
                    + CGFloat(depth)
                    * scale,
                width:
                    CGFloat(depth)
                    * scale,
                height:
                    CGFloat(secondaryH)
                    * scale
            )

        UIColor.systemGray5.setFill()
        UIColor.label.setStroke()
        let bodyPath =
            UIBezierPath()
        bodyPath.append(
            UIBezierPath(rect: primaryRect)
        )
        bodyPath.append(
            UIBezierPath(rect: secondaryRect)
        )
        bodyPath.fill()
        bodyPath.lineWidth = 1
        bodyPath.stroke()

        if corner.fillerKind != .none {
            let fillerW =
                max(
                    CGFloat(corner.fillerWidthMM)
                    * scale,
                    3
                )
            let fillerX =
                corner.handedness == .left
                ? primaryRect.minX
                : primaryRect.maxX - fillerW
            let fillerRect =
                CGRect(
                    x: fillerX,
                    y: primaryRect.minY,
                    width: fillerW,
                    height: primaryRect.height
                )
            UIColor.systemGray
                .withAlphaComponent(0.28)
                .setFill()
            UIBezierPath(rect: fillerRect).fill()
            drawText(
                "BL \(format(corner.fillerWidthMM))",
                rect:
                    fillerRect.insetBy(
                        dx: -18,
                        dy: fillerRect.height * 0.40
                    ),
                font:
                    .monospacedSystemFont(
                        ofSize: 6,
                        weight: .semibold
                    ),
                color:
                    .darkGray,
                alignment:
                    .center
            )
        }

        if corner.shouldShowDeadZone {
            let deadW =
                min(
                    CGFloat(corner.deadZoneMM)
                    * scale,
                    primaryRect.width
                )
            let deadX =
                corner.handedness == .left
                ? primaryRect.maxX - deadW
                : primaryRect.minX
            let deadRect =
                CGRect(
                    x: deadX,
                    y: primaryRect.minY,
                    width: deadW,
                    height: primaryRect.height
                )
            UIColor.systemGray
                .withAlphaComponent(0.18)
                .setFill()
            UIBezierPath(rect: deadRect).fill()

            UIColor.label.setStroke()
            let deadPath =
                UIBezierPath(rect: deadRect)
            let dash: [CGFloat] = [4, 2]
            dash.withUnsafeBufferPointer {
                deadPath.setLineDash(
                    $0.baseAddress,
                    count: $0.count,
                    phase: 0
                )
            }
            deadPath.lineWidth = 0.8
            deadPath.stroke()

            drawText(
                "MARTWA \(format(corner.deadZoneMM))",
                rect:
                    CGRect(
                        x: deadRect.minX + 2,
                        y: deadRect.midY - 6,
                        width:
                            max(deadRect.width - 4, 1),
                        height: 12
                    ),
                font:
                    .monospacedSystemFont(
                        ofSize: 6,
                        weight: .semibold
                    ),
                color:
                    .darkGray,
                alignment:
                    .center
            )
        }

        if corner.requiresMotionEnvelopeCheck {
            UIColor.label.setStroke()
            let envelope =
                UIBezierPath(
                    ovalIn:
                        primaryRect.insetBy(
                            dx:
                                primaryRect.width
                                * 0.18,
                            dy:
                                primaryRect.height
                                * 0.18
                        )
            )
            let dash: [CGFloat] = [3, 3]
            dash.withUnsafeBufferPointer {
                envelope.setLineDash(
                    $0.baseAddress,
                    count: $0.count,
                    phase: 0
                )
            }
            envelope.lineWidth = 0.8
            envelope.stroke()
            drawText(
                "KOPERTA",
                rect:
                    CGRect(
                        x: primaryRect.minX,
                        y: primaryRect.midY - 6,
                        width: primaryRect.width,
                        height: 12
                    ),
                font:
                    .monospacedSystemFont(
                        ofSize: 6,
                        weight: .semibold
                    ),
                color:
                    .darkGray,
                alignment:
                    .center
            )
        }

        let frontX =
            corner.handedness == .left
            ? primaryRect.minX
            : primaryRect.maxX
                - CGFloat(corner.frontOpeningMM)
                * scale
        let frontPath =
            UIBezierPath()
        frontPath.move(
            to:
                CGPoint(
                    x: frontX,
                    y: primaryRect.maxY
                )
        )
        frontPath.addLine(
            to:
                CGPoint(
                    x:
                        frontX
                        + CGFloat(corner.frontOpeningMM)
                        * scale,
                    y: primaryRect.maxY
                )
        )
        frontPath.lineWidth = 2
        frontPath.stroke()

        drawText(
            "FR \(format(corner.frontOpeningMM))",
            rect:
                CGRect(
                    x:
                        frontX,
                    y:
                        primaryRect.maxY + 4,
                    width:
                        CGFloat(corner.frontOpeningMM)
                        * scale,
                    height: 12
                ),
            font:
                .monospacedSystemFont(
                    ofSize: 6,
                    weight: .semibold
                ),
            color:
                .darkGray,
            alignment:
                .center
        )

        drawText(
            "\(corner.accessTechnology.title) • \(corner.kind.title) • \(corner.handedness.title)",
            rect:
                CGRect(
                    x: rect.minX + 8,
                    y: rect.maxY - 28,
                    width: rect.width - 16,
                    height: 12
                ),
            font:
                .monospacedSystemFont(
                    ofSize: 7,
                    weight: .semibold
                ),
            color:
                .label,
            alignment:
                .center
        )

        if corner.requiresManufacturerTemplate {
            drawText(
                "Wiercenia wg szablonu producenta",
                rect:
                    CGRect(
                        x: rect.minX + 8,
                        y: rect.maxY - 16,
                        width: rect.width - 16,
                        height: 10
                    ),
                font:
                    .italicSystemFont(ofSize: 7),
                color:
                    .darkGray,
                alignment:
                    .center
            )
        }
    }

    private static func drawCabinetSchematic(
        rect: CGRect,
        card: KartaTechnicznaSzafki
    ) {
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        let inset: CGFloat = 28
        let available = rect.insetBy(dx: inset, dy: inset)
        let scale = min(
            available.width / max(card.szerokoscMM, 1),
            available.height / max(card.wysokoscMM, 1)
        )

        let cabinetRect = CGRect(
            x: available.midX - card.szerokoscMM * scale / 2,
            y: available.midY - card.wysokoscMM * scale / 2,
            width: card.szerokoscMM * scale,
            height: card.wysokoscMM * scale
        )

        UIColor.label.setStroke()
        let path = UIBezierPath(rect: cabinetRect)
        path.lineWidth = 1.5
        path.stroke()

        let shelfCount = max(
            card.liczbaPolek ?? card.efektywneElementy.filter { $0.typ == .polka }.count,
            0
        )

        if shelfCount > 0 {
            for index in 0..<shelfCount {
                let fraction = CGFloat(index + 1) / CGFloat(shelfCount + 1)
                let shelfY = cabinetRect.maxY - cabinetRect.height * fraction
                let shelfPath = UIBezierPath()
                shelfPath.move(to: CGPoint(x: cabinetRect.minX, y: shelfY))
                shelfPath.addLine(to: CGPoint(x: cabinetRect.maxX, y: shelfY))
                shelfPath.lineWidth = 1
                shelfPath.stroke()
            }
        }

        drawFrontConfigurationV068(
            cabinetRect:
                cabinetRect,
            card: card
        )

        let bottomThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ == .dno
                    || $0.typ
                        == .wieniecDolny
                }?
                .gruboscMM
            ?? 18

        for drawer in card
            .efektywneSzuflady
            .filter(\.aktywna) {
            let bottomY =
                drawer.pozycjaDolnaYMM
                + bottomThickness

            let drawerRect =
                CGRect(
                    x:
                        cabinetRect.minX + 1,
                    y:
                        cabinetRect.maxY
                        - CGFloat(
                            bottomY
                            + drawer
                                .wysokoscFrontuMM
                        )
                        * scale,
                    width:
                        max(
                            cabinetRect.width - 2,
                            1
                        ),
                    height:
                        max(
                            CGFloat(
                                drawer
                                    .wysokoscFrontuMM
                            )
                            * scale,
                            1
                        )
                )

            UIColor.systemBlue
                .withAlphaComponent(0.08)
                .setFill()
            UIColor.systemBlue
                .setStroke()

            let drawerPath =
                UIBezierPath(
                    roundedRect:
                        drawerRect,
                    cornerRadius: 2
                )

            drawerPath.lineWidth = 0.8
            drawerPath.fill()
            drawerPath.stroke()

            drawText(
                drawer.etykieta,
                rect: CGRect(
                    x: drawerRect.minX + 3,
                    y: drawerRect.midY - 6,
                    width:
                        max(
                            drawerRect.width - 6,
                            1
                        ),
                    height: 12
                ),
                font:
                    .monospacedSystemFont(
                        ofSize: 7,
                        weight:
                            .semibold
                    ),
                color:
                    .darkGray,
                alignment:
                    .center
            )
        }

        drawDimension(
            "\(format(card.szerokoscMM)) mm",
            rect: CGRect(x: cabinetRect.minX, y: cabinetRect.maxY + 8, width: cabinetRect.width, height: 16)
        )
        drawDimension(
            "\(format(card.wysokoscMM)) mm",
            rect: CGRect(x: cabinetRect.maxX + 8, y: cabinetRect.midY - 10, width: 90, height: 20)
        )
    }

    private static func drawFrontConfigurationV068(
        cabinetRect:
            CGRect,
        card:
            KartaTechnicznaSzafki
    ) {
        guard
            card
                .efektywneSzuflady
                .filter(\.aktywna)
                .isEmpty,
            let configuration =
                card
                    .konfiguracjaFunkcjonalnaV068
        else {
            return
        }

        let count =
            configuration
                .front
                .bezpiecznaLiczbaFrontow
        let opening =
            ProfilOkuciaResolverV068
                .efektywneOtwarcie(
                    konfiguracja:
                        configuration
                )
        let gap: CGFloat = 2
        let availableWidth =
            max(
                cabinetRect.width
                - gap
                    * CGFloat(
                        count + 1
                    ),
                1
            )
        let frontWidth =
            availableWidth
            / CGFloat(count)

        for index in 0..<count {
            let rect =
                CGRect(
                    x:
                        cabinetRect.minX
                        + gap
                        + CGFloat(index)
                            * (
                                frontWidth
                                + gap
                            ),
                    y:
                        cabinetRect.minY
                        + gap,
                    width:
                        frontWidth,
                    height:
                        max(
                            cabinetRect.height
                            - gap * 2,
                            1
                        )
                )
            let segmentOpening:
                KierunekOtwarciaFrontuV068

            if count > 1,
               opening == .lewy
                || opening == .prawy {
                segmentOpening =
                    index
                        .isMultiple(
                            of: 2
                        )
                    ? .lewy
                    : .prawy
            } else {
                segmentOpening =
                    opening
            }

            UIColor.systemBlue
                .withAlphaComponent(
                    0.82
                )
                .setStroke()
            let outline =
                UIBezierPath(
                    roundedRect:
                        rect,
                    cornerRadius: 2
                )
            outline.lineWidth = 0.8
            outline.stroke()

            drawFrontOpeningSymbolV068(
                opening:
                    segmentOpening,
                rect:
                    rect.insetBy(
                        dx:
                            max(
                                min(
                                    rect.width,
                                    rect.height
                                )
                                * 0.10,
                                3
                            ),
                        dy:
                            max(
                                min(
                                    rect.width,
                                    rect.height
                                )
                                * 0.10,
                                3
                            )
                    )
            )
        }
    }

    private static func drawFrontOpeningSymbolV068(
        opening:
            KierunekOtwarciaFrontuV068,
        rect: CGRect
    ) {
        guard
            rect.width > 5,
            rect.height > 5
        else {
            return
        }

        UIColor.systemBlue
            .withAlphaComponent(
                0.72
            )
            .setStroke()

        let path =
            UIBezierPath()
        let center =
            CGPoint(
                x: rect.midX,
                y: rect.midY
            )

        switch opening {
        case .lewy:
            path.move(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: rect.minY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: rect.midY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: rect.maxY
                    )
            )

        case .prawy:
            path.move(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: rect.minY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: rect.midY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: rect.maxY
                    )
            )

        case .doGory, .wDol:
            let targetY =
                opening == .doGory
                ? rect.minY
                : rect.maxY
            let tailY =
                opening == .doGory
                ? rect.maxY
                : rect.minY

            path.move(
                to:
                    CGPoint(
                        x: center.x,
                        y: tailY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: center.x,
                        y: targetY
                    )
            )

            let direction: CGFloat =
                opening == .doGory
                ? 1
                : -1
            path.move(
                to:
                    CGPoint(
                        x: center.x,
                        y: targetY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: center.x - 5,
                        y:
                            targetY
                            + direction * 7
                    )
            )
            path.move(
                to:
                    CGPoint(
                        x: center.x,
                        y: targetY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: center.x + 5,
                        y:
                            targetY
                            + direction * 7
                    )
            )

        case .przesuwny:
            path.move(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: center.y
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: center.y
                    )
            )

        case .staly:
            path.move(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: rect.minY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: rect.maxY
                    )
            )
            path.move(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: rect.minY
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: rect.maxY
                    )
            )

        case .szuflada:
            path.move(
                to:
                    CGPoint(
                        x: rect.minX,
                        y: center.y
                    )
            )
            path.addLine(
                to:
                    CGPoint(
                        x: rect.maxX,
                        y: center.y
                    )
            )
        }

        path.lineWidth = 0.8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func drawElementSchematic(
        rect: CGRect,
        element: ElementTechnicznySzafki
    ) {
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        let inset: CGFloat = 42
        let available = rect.insetBy(dx: inset, dy: inset)

        // For slope-cut elements use a taller available box so the
        // trapezoid fits with the cut annotation above it.
        let drawingHeight = element.jestScietySkosemV0691
            ? available.height * 0.72
            : available.height

        let scale = min(
            available.width / max(element.szerokoscMM, 1),
            drawingHeight / max(element.dlugoscMM, 1)
        )

        let elementW = element.szerokoscMM * scale
        let elementH = element.dlugoscMM * scale
        let originX = available.midX - elementW / 2
        // Push element down a bit when we need annotation room above.
        let originY = element.jestScietySkosemV0691
            ? available.minY + (available.height - drawingHeight) * 0.5 + (drawingHeight - elementH) * 0.5
            : available.midY - elementH / 2

        let elementRect = CGRect(
            x: originX,
            y: originY,
            width: elementW,
            height: elementH
        )

        // --- shape ---
        UIColor.label.setStroke()
        let shapePath: UIBezierPath

        if let kontur = element.konturSkosuV0691, kontur.count >= 3 {
            // Non-rectangular outline (front/back under a complex slope).
            // Kontur is in element space: x=width, y=height, origin=bottom-left.
            shapePath = UIBezierPath()
            let first = kontur[0]
            shapePath.move(to: CGPoint(
                x: originX + CGFloat(first.xMM) * scale,
                y: originY + elementH - CGFloat(first.yMM) * scale
            ))
            for pt in kontur.dropFirst() {
                shapePath.addLine(to: CGPoint(
                    x: originX + CGFloat(pt.xMM) * scale,
                    y: originY + elementH - CGFloat(pt.yMM) * scale
                ))
            }
            shapePath.close()
        } else if let kat = element.katCieciaGornejKrawedziStopnieV0691,
                  abs(kat) > 0.01 {
            // Rectangular element with angled top cut — draw as trapezoid.
            // The cut drops from the left corner across the full width.
            let dropPx = CGFloat(tan(kat * .pi / 180)) * elementW
            let clampedDrop = min(dropPx, elementH * 0.85)
            shapePath = UIBezierPath()
            shapePath.move(to: CGPoint(x: originX, y: originY + clampedDrop))
            shapePath.addLine(to: CGPoint(x: originX + elementW, y: originY))
            shapePath.addLine(to: CGPoint(x: originX + elementW, y: originY + elementH))
            shapePath.addLine(to: CGPoint(x: originX, y: originY + elementH))
            shapePath.close()
        } else {
            shapePath = UIBezierPath(rect: elementRect)
        }

        UIColor.systemBlue.withAlphaComponent(0.08).setFill()
        shapePath.fill()
        UIColor.label.setStroke()
        shapePath.lineWidth = 1.6
        shapePath.stroke()

        // --- drilling / mounting lines ---
        for line in element.efektywneLinieWiercenia {
            let xStart = originX + CGFloat(
                min(
                    max(
                        line.xStartMM,
                        0
                    ),
                    element.szerokoscMM
                )
            ) * scale
            let xEnd = originX + CGFloat(
                min(
                    max(
                        line.xEndMM,
                        0
                    ),
                    element.szerokoscMM
                )
            ) * scale
            let y = originY + elementH - CGFloat(
                min(
                    max(
                        line.yMM,
                        0
                    ),
                    element.dlugoscMM
                )
            ) * scale

            let linePath = UIBezierPath()
            linePath.move(
                to:
                    CGPoint(
                        x: xStart,
                        y: y
                    )
            )
            linePath.addLine(
                to:
                    CGPoint(
                        x: xEnd,
                        y: y
                    )
            )
            UIColor.systemTeal.setStroke()
            linePath.lineWidth = 1.0
            linePath.setLineDash(
                [5, 3],
                count: 2,
                phase: 0
            )
            linePath.stroke()

            if !line.etykieta.isEmpty {
                drawText(
                    line.etykieta,
                    rect: CGRect(
                        x:
                            min(
                                xStart,
                                xEnd
                            ),
                        y:
                            y - 15,
                        width:
                            max(
                                abs(
                                    xEnd
                                    - xStart
                                ),
                                54
                            ),
                        height:
                            12
                    ),
                    font:
                        .monospacedSystemFont(
                            ofSize: 7,
                            weight:
                                .semibold
                        ),
                    color:
                        .systemTeal,
                    alignment:
                        .center
                )
            }
        }

        // --- drilling points ---
        for point in element.punktyWiercenia {
            let x = originX + CGFloat(
                min(max(point.xMM, 0), element.szerokoscMM)
            ) * scale
            let y = originY + elementH - CGFloat(
                min(max(point.yMM, 0), element.dlugoscMM)
            ) * scale
            UIColor.systemOrange.setFill()
            UIBezierPath(
                ovalIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            ).fill()
        }

        drawFirstHoleDimensions(
            element:
                element,
            elementRect:
                elementRect,
            scale:
                scale
        )

        // --- cut angle annotation ---
        if let kat = element.katCieciaGornejKrawedziStopnieV0691,
           abs(kat) > 0.01,
           element.konturSkosuV0691 == nil {

            let cornerPt = CGPoint(x: originX + elementW, y: originY)
            let arcRadius: CGFloat = min(elementW, elementH) * 0.22
            // Arc from –90° (up) sweeping toward the slope direction.
            let slopeAngleRad = CGFloat(kat * .pi / 180)
            // The slope goes from top-right down to top-left, so in screen
            // coords the cut line angle is π + slopeAngleRad from the right edge.
            let arcStart: CGFloat = -.pi / 2        // pointing up
            let arcEnd: CGFloat   = -.pi + slopeAngleRad // along cut line

            let arcPath = UIBezierPath()
            arcPath.addArc(
                withCenter: cornerPt,
                radius: arcRadius,
                startAngle: arcStart,
                endAngle: arcEnd,
                clockwise: false
            )
            UIColor.systemPurple.setStroke()
            arcPath.lineWidth = 1.2
            arcPath.stroke()

            // Angle label at the bisector of the arc.
            let bisector = (arcStart + arcEnd) / 2
            let labelDist = arcRadius + 14
            let labelCenter = CGPoint(
                x: cornerPt.x + labelDist * cos(bisector),
                y: cornerPt.y + labelDist * sin(bisector)
            )
            let katText = "\(format(kat))°"
            drawText(
                katText,
                rect: CGRect(
                    x: labelCenter.x - 28,
                    y: labelCenter.y - 9,
                    width: 56,
                    height: 18
                ),
                font: .boldSystemFont(ofSize: 10),
                color: .systemPurple,
                alignment: .center
            )

            // Note below the shape.
            drawText(
                "Kąt cięcia górnej krawędzi: \(format(kat))°",
                rect: CGRect(
                    x: rect.minX + 10,
                    y: originY + elementH + 10,
                    width: rect.width - 20,
                    height: 16
                ),
                font: .systemFont(ofSize: 10, weight: .medium),
                color: .systemPurple,
                alignment: .center
            )
        }

        if element.konturSkosuV0691 != nil {
            drawText(
                "Kontur nieregularny — patrz strona paneli skosu",
                rect: CGRect(
                    x: rect.minX + 10,
                    y: originY + elementH + 10,
                    width: rect.width - 20,
                    height: 16
                ),
                font: .systemFont(ofSize: 10, weight: .medium),
                color: .systemPurple,
                alignment: .center
            )
        }

        // --- dimensions ---
        drawDimension(
            "\(format(element.szerokoscMM)) mm",
            rect: CGRect(
                x: elementRect.minX,
                y: elementRect.maxY + 8,
                width: elementRect.width,
                height: 16
            )
        )
        drawDimension(
            "\(format(element.dlugoscMM)) mm",
            rect: CGRect(
                x: elementRect.maxX + 8,
                y: elementRect.midY - 10,
                width: 90,
                height: 20
            )
        )

        drawText(
            element.etykieta,
            rect: CGRect(
                x: elementRect.midX - 90,
                y: elementRect.midY - 12,
                width: 180,
                height: 24
            ),
            font: .monospacedSystemFont(ofSize: 13, weight: .semibold),
            alignment: .center
        )
    }

    private struct PDFMountingPoint {
        let label: String
        let xMM: Double
        let yMM: Double
        let diameterMM: Double
        let depthMM: Double
    }

    private static func hasDimensionedMountingMarks(
        _ element:
            ElementTechnicznySzafki
    ) -> Bool {
        !firstRunnerHoleDetails(
            for:
                element
        ).isEmpty
        || !hingeCupDetails(
            for:
                element
        ).isEmpty
    }

    private static func drawFirstHoleDimensions(
        element:
            ElementTechnicznySzafki,
        elementRect:
            CGRect,
        scale:
            CGFloat
    ) {
        let runnerDetails =
            firstRunnerHoleDetails(
                for:
                    element
            )
        let hingeDetails =
            hingeCupDetails(
                for:
                    element
            )

        for (
            index,
            detail
        ) in runnerDetails
            .prefix(5)
            .enumerated() {
            let x =
                elementRect.minX
                + CGFloat(
                    clamped(
                        detail.xMM,
                        lower:
                            0,
                        upper:
                            element.szerokoscMM
                    )
                )
                * scale
            let y =
                elementRect.maxY
                - CGFloat(
                    clamped(
                        detail.yMM,
                        lower:
                            0,
                        upper:
                            element.dlugoscMM
                    )
                )
                * scale
            let dimY =
                clampedCGFloat(
                    y
                    + (
                        index.isMultiple(of: 2)
                        ? -14
                        : 14
                    ),
                    lower:
                        elementRect.minY + 12,
                    upper:
                        elementRect.maxY - 12
                )

            drawPDFDashedLine(
                from:
                    CGPoint(
                        x: elementRect.minX,
                        y: y
                    ),
                to:
                    CGPoint(
                        x: elementRect.maxX,
                        y: y
                    ),
                color:
                    .systemTeal
            )
            drawPDFDimensionHorizontal(
                y:
                    dimY,
                xStart:
                    elementRect.minX,
                xEnd:
                    x,
                text:
                    "X \(format(detail.xMM))"
            )
            drawPDFDimensionVertical(
                x:
                    elementRect.minX
                    - 18
                    - CGFloat(index % 2) * 12,
                yStart:
                    y,
                yEnd:
                    elementRect.maxY,
                text:
                    "Y \(format(detail.yMM))"
            )
            drawText(
                detail.label,
                rect:
                    CGRect(
                        x:
                            elementRect.maxX + 8,
                        y:
                            y - 8,
                        width:
                            88,
                        height:
                            16
                    ),
                font:
                    .monospacedSystemFont(
                        ofSize: 7,
                        weight:
                            .semibold
                    ),
                color:
                    .systemTeal
            )
        }

        guard !hingeDetails.isEmpty else {
            return
        }

        let averageX =
            hingeDetails
                .map(\.xMM)
                .reduce(0, +)
            / Double(
                max(
                    hingeDetails.count,
                    1
                )
            )
        let hingeOnLeft =
            averageX
            <= element.szerokoscMM / 2
        let edgeX =
            hingeOnLeft
            ? elementRect.minX
            : elementRect.maxX

        for (
            index,
            detail
        ) in hingeDetails
            .prefix(5)
            .enumerated() {
            let x =
                elementRect.minX
                + CGFloat(
                    clamped(
                        detail.xMM,
                        lower:
                            0,
                        upper:
                            element.szerokoscMM
                    )
                )
                * scale
            let y =
                elementRect.maxY
                - CGFloat(
                    clamped(
                        detail.yMM,
                        lower:
                            0,
                        upper:
                            element.dlugoscMM
                    )
                )
                * scale
            let xOffset =
                hingeOnLeft
                ? detail.xMM
                : max(
                    element.szerokoscMM
                    - detail.xMM,
                    0
                )
            let dimY =
                clampedCGFloat(
                    y
                    + (
                        index.isMultiple(of: 2)
                        ? -14
                        : 14
                    ),
                    lower:
                        elementRect.minY + 12,
                    upper:
                        elementRect.maxY - 12
                )

            drawPDFDimensionHorizontal(
                y:
                    dimY,
                xStart:
                    edgeX,
                xEnd:
                    x,
                text:
                    "X \(format(xOffset))"
            )
            drawPDFDimensionVertical(
                x:
                    elementRect.minX
                    - 18
                    - CGFloat(index % 2) * 12,
                yStart:
                    y,
                yEnd:
                    elementRect.maxY,
                text:
                    "Y \(format(detail.yMM))"
            )
            drawText(
                "Ø\(format(detail.diameterMM)) / gł. \(format(detail.depthMM))",
                rect:
                    CGRect(
                        x:
                            elementRect.maxX + 8,
                        y:
                            y - 8,
                        width:
                            96,
                        height:
                            16
                    ),
                font:
                    .monospacedSystemFont(
                        ofSize: 7,
                        weight:
                            .semibold
                    ),
                color:
                    .systemOrange
            )
        }
    }

    private static func firstRunnerHoleDetails(
        for element:
            ElementTechnicznySzafki
    ) -> [PDFMountingPoint] {
        let points =
            element
                .punktyWiercenia
                .filter {
                    $0.typ == .prowadnica
                }
        let lines =
            element
                .efektywneLinieWiercenia
                .filter {
                    $0.typ == .osProwadnicySzuflady
                }
                .sorted {
                    if abs($0.yMM - $1.yMM) > 1 {
                        return $0.yMM < $1.yMM
                    }

                    return $0.xStartMM < $1.xStartMM
                }

        var result:
            [PDFMountingPoint] = []

        for (
            index,
            line
        ) in lines.enumerated() {
            let point =
                points
                    .filter {
                        abs(
                            $0.yMM
                            - line.yMM
                        ) < 2
                    }
                    .sorted {
                        $0.xMM < $1.xMM
                    }
                    .first
            let label =
                line.etykieta
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            result.append(
                PDFMountingPoint(
                    label:
                        label.isEmpty
                        ? "Prow. \(index + 1)"
                        : label,
                    xMM:
                        point?.xMM
                        ?? min(
                            line.xStartMM,
                            line.xEndMM
                        ),
                    yMM:
                        line.yMM,
                    diameterMM:
                        point?.srednicaMM
                        ?? 5,
                    depthMM:
                        point?.glebokoscMM
                        ?? 12
                )
            )
        }

        if result.isEmpty {
            for point in points.sorted(
                by: {
                    if abs($0.yMM - $1.yMM) > 1 {
                        return $0.yMM < $1.yMM
                    }

                    return $0.xMM < $1.xMM
                }
            ) {
                if result.contains(
                    where: {
                        abs(
                            $0.yMM
                            - point.yMM
                        ) < 2
                    }
                ) {
                    continue
                }

                result.append(
                    PDFMountingPoint(
                        label:
                            "Prow. \(result.count + 1)",
                        xMM:
                            point.xMM,
                        yMM:
                            point.yMM,
                        diameterMM:
                            point.srednicaMM,
                        depthMM:
                            point.glebokoscMM
                    )
                )
            }
        }

        return result
    }

    private static func hingeCupDetails(
        for element:
            ElementTechnicznySzafki
    ) -> [PDFMountingPoint] {
        element
            .punktyWiercenia
            .filter {
                $0.typ == .zawias
            }
            .sorted {
                if abs($0.yMM - $1.yMM) > 1 {
                    return $0.yMM < $1.yMM
                }

                return $0.xMM < $1.xMM
            }
            .map {
                PDFMountingPoint(
                    label:
                        "Zawias",
                    xMM:
                        $0.xMM,
                    yMM:
                        $0.yMM,
                    diameterMM:
                        $0.srednicaMM,
                    depthMM:
                        $0.glebokoscMM
                )
            }
    }

    private static func drawPDFDimensionHorizontal(
        y: CGFloat,
        xStart: CGFloat,
        xEnd: CGFloat,
        text: String
    ) {
        let left =
            min(
                xStart,
                xEnd
            )
        let right =
            max(
                xStart,
                xEnd
            )

        guard right - left > 2 else {
            return
        }

        UIColor.label.setStroke()
        let path =
            UIBezierPath()
        path.move(
            to:
                CGPoint(
                    x: left,
                    y: y - 3
                )
        )
        path.addLine(
            to:
                CGPoint(
                    x: left,
                    y: y + 3
                )
        )
        path.move(
            to:
                CGPoint(
                    x: right,
                    y: y - 3
                )
        )
        path.addLine(
            to:
                CGPoint(
                    x: right,
                    y: y + 3
                )
        )
        path.move(
            to:
                CGPoint(
                    x: left,
                    y: y
                )
        )
        path.addLine(
            to:
                CGPoint(
                    x: right,
                    y: y
                )
        )
        path.lineWidth = 0.6
        path.stroke()

        drawText(
            text,
            rect:
                CGRect(
                    x:
                        (left + right) / 2 - 30,
                    y:
                        y - 13,
                    width:
                        60,
                    height:
                        12
                ),
            font:
                .monospacedSystemFont(
                    ofSize: 7,
                    weight:
                        .semibold
                ),
            color:
                .label,
            alignment:
                .center
        )
    }

    private static func drawPDFDimensionVertical(
        x: CGFloat,
        yStart: CGFloat,
        yEnd: CGFloat,
        text: String
    ) {
        let top =
            min(
                yStart,
                yEnd
            )
        let bottom =
            max(
                yStart,
                yEnd
            )

        guard bottom - top > 2 else {
            return
        }

        UIColor.label.setStroke()
        let path =
            UIBezierPath()
        path.move(
            to:
                CGPoint(
                    x: x - 3,
                    y: top
                )
        )
        path.addLine(
            to:
                CGPoint(
                    x: x + 3,
                    y: top
                )
        )
        path.move(
            to:
                CGPoint(
                    x: x - 3,
                    y: bottom
                )
        )
        path.addLine(
            to:
                CGPoint(
                    x: x + 3,
                    y: bottom
                )
        )
        path.move(
            to:
                CGPoint(
                    x: x,
                    y: top
                )
        )
        path.addLine(
            to:
                CGPoint(
                    x: x,
                    y: bottom
                )
        )
        path.lineWidth = 0.6
        path.stroke()

        drawText(
            text,
            rect:
                CGRect(
                    x:
                        x - 48,
                    y:
                        (top + bottom) / 2 - 6,
                    width:
                        44,
                    height:
                        12
                ),
            font:
                .monospacedSystemFont(
                    ofSize: 7,
                    weight:
                        .semibold
                ),
            color:
                .label,
            alignment:
                .right
        )
    }

    private static func drawPDFDashedLine(
        from start:
            CGPoint,
        to end:
            CGPoint,
        color:
            UIColor
    ) {
        color.setStroke()
        let path =
            UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        path.lineWidth = 0.5
        path.setLineDash(
            [4, 3],
            count: 2,
            phase: 0
        )
        path.stroke()
    }

    private static func clamped(
        _ value: Double,
        lower: Double,
        upper: Double
    ) -> Double {
        min(
            max(
                value,
                lower
            ),
            upper
        )
    }

    private static func clampedCGFloat(
        _ value: CGFloat,
        lower: CGFloat,
        upper: CGFloat
    ) -> CGFloat {
        min(
            max(
                value,
                lower
            ),
            upper
        )
    }

    private static func drawElementHeader(x: CGFloat, y: CGFloat, width: CGFloat) {
        UIColor.tertiarySystemFill.setFill()
        UIBezierPath(rect: CGRect(x: x, y: y, width: width, height: 20)).fill()

        drawTableText("Etykieta", x: x + 4, y: y + 3, width: 105, bold: true)
        drawTableText("Element", x: x + 112, y: y + 3, width: 180, bold: true)
        drawTableText("Wymiary", x: x + 294, y: y + 3, width: 185, bold: true)
        drawTableText("Szt.", x: x + width - 38, y: y + 3, width: 34, bold: true)
    }

    private static func drawElementRow(
        element: ElementTechnicznySzafki,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        drawSeparator(x: x, y: y + 21, width: width)
        drawTableText(element.etykieta, x: x + 4, y: y + 3, width: 105, monospaced: true)
        drawTableText(element.nazwa, x: x + 112, y: y + 3, width: 180)
        drawTableText(
            "\(format(element.dlugoscMM)) × \(format(element.szerokoscMM)) × \(format(element.gruboscMM))",
            x: x + 294,
            y: y + 3,
            width: 185
        )
        drawTableText(
            "\(element.ilosc)",
            x: x + width - 38,
            y: y + 3,
            width: 34,
            alignment: .center
        )
    }

    private static func drawLabelValue(
        label: String,
        value: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        drawText(
            "\(label):",
            rect: CGRect(x: x, y: y, width: 130, height: 20),
            font: .boldSystemFont(ofSize: 11)
        )
        drawText(
            value,
            rect: CGRect(x: x + 132, y: y, width: width - 132, height: 20),
            font: .systemFont(ofSize: 11)
        )
    }

    private static func drawDimension(_ value: String, rect: CGRect) {
        drawText(
            value,
            rect: rect,
            font: .systemFont(ofSize: 9),
            color: .darkGray,
            alignment: .center
        )
    }

    private static func drawFooter(bounds: CGRect, text: String) {
        drawSeparator(x: 36, y: bounds.height - 34, width: bounds.width - 72)
        drawText(
            text,
            rect: CGRect(x: 36, y: bounds.height - 28, width: bounds.width - 72, height: 14),
            font: .systemFont(ofSize: 8),
            color: .gray,
            alignment: .center
        )
    }

    private static func drawSeparator(x: CGFloat, y: CGFloat, width: CGFloat) {
        UIColor.separator.setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: x, y: y))
        line.addLine(to: CGPoint(x: x + width, y: y))
        line.lineWidth = 0.5
        line.stroke()
    }

    private static func drawTableText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        bold: Bool = false,
        monospaced: Bool = false,
        alignment: NSTextAlignment = .left
    ) {
        let font: UIFont

        if monospaced {
            font = .monospacedSystemFont(
                ofSize: 8,
                weight: bold ? .semibold : .regular
            )
        } else {
            font = bold ? .boldSystemFont(ofSize: 8) : .systemFont(ofSize: 8)
        }

        drawText(
            text,
            rect: CGRect(x: x, y: y, width: width, height: 18),
            font: font,
            alignment: alignment
        )
    }

    private static func drawText(
        _ text: String,
        rect: CGRect,
        font: UIFont,
        color: UIColor = .label,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail

        text.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private static func hardwareGrossTotal(
        _ card:
            KartaTechnicznaSzafki
    ) -> Double {
        card.efektywneAkcesoria
            .reduce(0) {
                partial,
                accessory in

                partial
                + (
                    accessory
                        .cenaJednostkowaBruttoPLN
                    ?? 0
                )
                * Double(
                    max(
                        accessory.ilosc,
                        0
                    )
                )
            }
    }

    private static func currency(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }

    private static func format(_ value: Double) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return value
            .components(separatedBy: forbidden)
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
