import Foundation
import UIKit

@MainActor
enum RaportPomiarowyPDFBuilder {
    static func build(
        context:
            KontekstPomiaruPomieszczenia,
        slopeMeasurements:
            [PomiarGarderobySkosy],
        unusualMeasurements:
            [PomiarNietypowy],
        photos:
            [ZdjeciePomiarowe],
        photoRepository:
            ZdjeciaPomiaroweRepository
    ) throws -> URL {
        let pageSize =
            CGSize(
                width: 595.2,
                height: 841.8
            )

        let pageBounds =
            CGRect(
                origin: .zero,
                size: pageSize
            )

        let outputURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName(
                        context: context
                    )
                )

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageBounds
            )

        try renderer.writePDF(
            to: outputURL
        ) { contextPDF in
            var page =
                PDFPageWriter(
                    context:
                        contextPDF,
                    pageBounds:
                        pageBounds
                )

            page.beginPage()
            page.drawHeader(
                title:
                    "Raport pomiarowy",
                subtitle:
                    "\(context.projectName) • \(context.roomName)"
            )

            page.drawSectionTitle(
                "Dane zlecenia"
            )

            page.drawKeyValue(
                key: "Klient",
                value:
                    context.customerName
            )

            page.drawKeyValue(
                key: "Projekt",
                value:
                    context.projectName
            )

            page.drawKeyValue(
                key: "Pomieszczenie",
                value:
                    context.roomName
            )

            page.drawKeyValue(
                key: "Data raportu",
                value:
                    Date().formatted(
                        date: .long,
                        time: .shortened
                    )
            )

            page.drawSectionTitle(
                "Podsumowanie"
            )

            page.drawKeyValue(
                key: "Pomiary skosów",
                value:
                    String(
                        slopeMeasurements.count
                    )
            )

            page.drawKeyValue(
                key: "Pomiary nietypowe",
                value:
                    String(
                        unusualMeasurements.count
                    )
            )

            page.drawKeyValue(
                key: "Zdjęcia",
                value:
                    String(
                        photos.count
                    )
            )

            let completeCount =
                slopeMeasurements.filter {
                    $0.status == .kompletny
                }.count
                + unusualMeasurements.filter {
                    $0.status == .kompletny
                }.count

            page.drawKeyValue(
                key: "Pomiary kompletne",
                value:
                    "\(completeCount) / \(slopeMeasurements.count + unusualMeasurements.count)"
            )

            for measurement in slopeMeasurements {
                page.ensureSpace(250)
                page.drawSectionTitle(
                    "Skos pomieszczenia"
                )

                page.drawKeyValue(
                    key: "Nazwa",
                    value:
                        measurement
                            .nazwaPomieszczenia
                )

                page.drawKeyValue(
                    key: "Status",
                    value:
                        measurement.status.nazwa
                )

                page.drawKeyValue(
                    key: "Ściana",
                    value:
                        measurement
                            .wallNameV069
                        ?? "Nieprzypisana"
                )

                page.drawKeyValue(
                    key: "Źródło",
                    value:
                        measurement
                            .zrodloPomiaruV069
                            .nazwa
                )

                if !measurement
                    .opisUrzadzeniaV069
                    .isEmpty {
                    page.drawKeyValue(
                        key: "Urządzenie",
                        value:
                            measurement
                                .opisUrzadzeniaV069
                    )
                }

                page.drawKeyValue(
                    key: "Tolerancja",
                    value:
                        millimeters(
                            measurement
                                .tolerancjaDomyslnaV069
                        )
                )

                page.drawKeyValue(
                    key: "Weryfikacja",
                    value:
                        measurement
                            .profilZweryfikowanyV069
                        ? "Potwierdzono ręcznie"
                        : "Niepotwierdzony"
                )

                page.drawKeyValue(
                    key: "Szerokość ściany",
                    value:
                        millimeters(
                            measurement
                                .szerokoscScianyMM
                        )
                )

                page.drawKeyValue(
                    key: "Wysokość maksymalna",
                    value:
                        millimeters(
                            measurement
                                .wysokoscMaksymalnaMM
                        )
                )

                page.drawKeyValue(
                    key: "Ścianka kolankowa",
                    value:
                        millimeters(
                            measurement
                                .wysokoscSciankiKolankowejMM
                        )
                )

                page.drawKeyValue(
                    key: "Głębokość docelowa",
                    value:
                        millimeters(
                            measurement
                                .glebokoscDocelowaMM
                        )
                )

                if let angle =
                    measurement
                        .przyblizonyKatSkosuStopnie {
                    page.drawKeyValue(
                        key: "Przybliżony kąt",
                        value:
                            angle.formatted(
                                .number.precision(
                                    .fractionLength(1)
                                )
                            )
                            + "°"
                    )
                }

                page.drawSubsectionTitle(
                    "Punkty profilu"
                )

                let sortedPoints =
                    measurement
                        .punktySkosu
                        .sorted {
                            $0.odlegloscOdLewejMM
                            < $1.odlegloscOdLewejMM
                        }

                if sortedPoints.isEmpty {
                    page.drawBodyText(
                        "Brak punktów profilu."
                    )
                } else {
                    for point in sortedPoints {
                        page.drawBullet(
                            "X \(millimeters(point.odlegloscOdLewejMM)), wysokość \(millimeters(point.wysokoscMM))\(point.uwagi.isEmpty ? "" : " — \(point.uwagi)")"
                        )
                    }
                }

                if !measurement.przeszkody.isEmpty {
                    page.drawSubsectionTitle(
                        "Przeszkody"
                    )

                    for obstacle in
                        measurement.przeszkody {
                        page.drawBullet(
                            "\(obstacle.nazwa): od lewej \(millimeters(obstacle.odLewejMM)), od podłogi \(millimeters(obstacle.odPodlogiMM)), \(millimeters(obstacle.szerokoscMM)) × \(millimeters(obstacle.wysokoscMM)) × \(millimeters(obstacle.glebokoscMM))"
                        )
                    }
                }

                if !measurement.notatki.isEmpty {
                    page.drawSubsectionTitle(
                        "Notatki"
                    )
                    page.drawBodyText(
                        measurement.notatki
                    )
                }
            }

            for measurement in unusualMeasurements {
                page.ensureSpace(130)
                page.drawSectionTitle(
                    measurement.typ.nazwa
                )

                page.drawKeyValue(
                    key: "Nazwa",
                    value:
                        measurement.nazwa
                )

                page.drawKeyValue(
                    key: "Status",
                    value:
                        measurement.status.nazwa
                )

                page.drawKeyValue(
                    key: "Szerokość",
                    value:
                        millimeters(
                            measurement
                                .szerokoscMM
                        )
                )

                page.drawKeyValue(
                    key: "Wysokość",
                    value:
                        millimeters(
                            measurement
                                .wysokoscMM
                        )
                )

                page.drawKeyValue(
                    key: "Głębokość",
                    value:
                        millimeters(
                            measurement
                                .glebokoscMM
                        )
                )

                page.drawKeyValue(
                    key: "Kąt",
                    value:
                        measurement.katStopnie
                            .formatted(
                                .number.precision(
                                    .fractionLength(1)
                                )
                            )
                        + "°"
                )

                if !measurement.punkty.isEmpty {
                    page.drawSubsectionTitle(
                        "Punkty XYZ"
                    )

                    for point in measurement.punkty {
                        page.drawBullet(
                            "X \(millimeters(point.xMM)), Y \(millimeters(point.yMM)), Z \(millimeters(point.zMM))\(point.opis.isEmpty ? "" : " — \(point.opis)")"
                        )
                    }
                }

                if !measurement.notatki.isEmpty {
                    page.drawSubsectionTitle(
                        "Notatki"
                    )
                    page.drawBodyText(
                        measurement.notatki
                    )
                }
            }

            if !photos.isEmpty {
                page.beginPage()
                page.drawHeader(
                    title:
                        "Dokumentacja zdjęciowa",
                    subtitle:
                        "\(context.projectName) • \(context.roomName)"
                )

                for photo in photos {
                    page.ensureSpace(220)

                    if let image =
                        photoRepository.image(
                            for: photo
                        ) {
                        page.drawPhoto(
                            image,
                            title:
                                photo.category.nazwa,
                            caption:
                                photo.caption
                        )
                    } else {
                        page.drawBodyText(
                            "Brak pliku zdjęcia: \(photo.category.nazwa)"
                        )
                    }
                }
            }

            page.drawFooterOnCurrentPage()
        }

        return outputURL
    }

    private static func fileName(
        context:
            KontekstPomiaruPomieszczenia
    ) -> String {
        let safeProject =
            sanitized(
                context.projectName
            )

        let safeRoom =
            sanitized(
                context.roomName
            )

        let stamp =
            Date().formatted(
                .dateTime
                    .year()
                    .month()
                    .day()
                    .hour()
                    .minute()
            )
            .replacingOccurrences(
                of: " ",
                with: "-"
            )
            .replacingOccurrences(
                of: ":",
                with: "-"
            )

        return "Raport-\(safeProject)-\(safeRoom)-\(stamp).pdf"
    }

    private static func sanitized(
        _ value: String
    ) -> String {
        let allowed =
            CharacterSet
                .alphanumerics
                .union(
                    CharacterSet(
                        charactersIn: "-_"
                    )
                )

        return value
            .components(
                separatedBy:
                    allowed.inverted
            )
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "-"
            )
    }

    private static func millimeters(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
        + " mm"
    }
}

private struct PDFPageWriter {
    let context:
        UIGraphicsPDFRendererContext
    let pageBounds:
        CGRect

    private(set) var cursorY:
        CGFloat = 54

    private let leftMargin:
        CGFloat = 46
    private let rightMargin:
        CGFloat = 46
    private let topMargin:
        CGFloat = 48
    private let bottomMargin:
        CGFloat = 48

    private let anthracite =
        UIColor(
            red: 0.13,
            green: 0.15,
            blue: 0.17,
            alpha: 1
        )

    private let accent =
        UIColor(
            red: 0.10,
            green: 0.56,
            blue: 0.66,
            alpha: 1
        )

    private var contentWidth:
        CGFloat
    {
        pageBounds.width
        - leftMargin
        - rightMargin
    }

    mutating func beginPage() {
        context.beginPage()
        cursorY = topMargin
    }

    mutating func ensureSpace(
        _ height: CGFloat
    ) {
        if cursorY + height
            > pageBounds.height
            - bottomMargin {
            drawFooterOnCurrentPage()
            beginPage()
        }
    }

    mutating func drawHeader(
        title: String,
        subtitle: String
    ) {
        let headerRect =
            CGRect(
                x: leftMargin,
                y: cursorY,
                width: contentWidth,
                height: 72
            )

        let path =
            UIBezierPath(
                roundedRect:
                    headerRect,
                cornerRadius: 14
            )

        anthracite.setFill()
        path.fill()

        let titleAttributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 22,
                        weight: .bold
                    ),
                .foregroundColor:
                    UIColor.white
            ]

        let subtitleAttributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 11,
                        weight: .regular
                    ),
                .foregroundColor:
                    UIColor.white
                        .withAlphaComponent(
                            0.72
                        )
            ]

        NSString(
            string: title
        ).draw(
            at:
                CGPoint(
                    x:
                        leftMargin + 18,
                    y:
                        cursorY + 14
                ),
            withAttributes:
                titleAttributes
        )

        NSString(
            string: subtitle
        ).draw(
            at:
                CGPoint(
                    x:
                        leftMargin + 18,
                    y:
                        cursorY + 44
                ),
            withAttributes:
                subtitleAttributes
        )

        cursorY += 90
    }

    mutating func drawSectionTitle(
        _ title: String
    ) {
        ensureSpace(38)

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 15,
                        weight: .bold
                    ),
                .foregroundColor:
                    anthracite
            ]

        NSString(
            string: title
        ).draw(
            at:
                CGPoint(
                    x: leftMargin,
                    y: cursorY
                ),
            withAttributes:
                attributes
        )

        accent.setFill()

        UIBezierPath(
            roundedRect:
                CGRect(
                    x: leftMargin,
                    y: cursorY + 24,
                    width: 54,
                    height: 3
                ),
            cornerRadius: 1.5
        ).fill()

        cursorY += 38
    }

    mutating func drawSubsectionTitle(
        _ title: String
    ) {
        ensureSpace(28)

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 12,
                        weight: .semibold
                    ),
                .foregroundColor:
                    anthracite
            ]

        NSString(
            string: title
        ).draw(
            at:
                CGPoint(
                    x: leftMargin,
                    y: cursorY
                ),
            withAttributes:
                attributes
        )

        cursorY += 24
    }

    mutating func drawKeyValue(
        key: String,
        value: String
    ) {
        ensureSpace(26)

        let keyAttributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 10,
                        weight: .semibold
                    ),
                .foregroundColor:
                    UIColor.darkGray
            ]

        let valueAttributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 10,
                        weight: .regular
                    ),
                .foregroundColor:
                    UIColor.black
            ]

        NSString(
            string: key
        ).draw(
            in:
                CGRect(
                    x: leftMargin,
                    y: cursorY,
                    width: 170,
                    height: 18
                ),
            withAttributes:
                keyAttributes
        )

        NSString(
            string: value
        ).draw(
            in:
                CGRect(
                    x:
                        leftMargin + 176,
                    y: cursorY,
                    width:
                        contentWidth - 176,
                    height: 18
                ),
            withAttributes:
                valueAttributes
        )

        cursorY += 23
    }

    mutating func drawBullet(
        _ text: String
    ) {
        let paragraph =
            NSMutableParagraphStyle()

        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = 13
        paragraph.lineSpacing = 2

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 9.5
                    ),
                .foregroundColor:
                    UIColor.black,
                .paragraphStyle:
                    paragraph
            ]

        let value = "• \(text)"

        let height =
            NSString(
                string: value
            ).boundingRect(
                with:
                    CGSize(
                        width: contentWidth,
                        height:
                            CGFloat.greatestFiniteMagnitude
                    ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes:
                    attributes,
                context: nil
            ).height
            + 5

        ensureSpace(height)

        NSString(
            string: value
        ).draw(
            in:
                CGRect(
                    x: leftMargin,
                    y: cursorY,
                    width: contentWidth,
                    height: height
                ),
            withAttributes:
                attributes
        )

        cursorY += height
    }

    mutating func drawBodyText(
        _ text: String
    ) {
        let paragraph =
            NSMutableParagraphStyle()

        paragraph.lineSpacing = 3

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 10
                    ),
                .foregroundColor:
                    UIColor.black,
                .paragraphStyle:
                    paragraph
            ]

        let height =
            NSString(
                string: text
            ).boundingRect(
                with:
                    CGSize(
                        width: contentWidth,
                        height:
                            CGFloat.greatestFiniteMagnitude
                    ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes:
                    attributes,
                context: nil
            ).height
            + 8

        ensureSpace(height)

        NSString(
            string: text
        ).draw(
            in:
                CGRect(
                    x: leftMargin,
                    y: cursorY,
                    width: contentWidth,
                    height: height
                ),
            withAttributes:
                attributes
        )

        cursorY += height
    }

    mutating func drawPhoto(
        _ image: UIImage,
        title: String,
        caption: String
    ) {
        let imageHeight:
            CGFloat = 170

        ensureSpace(
            imageHeight + 56
        )

        let imageRect =
            aspectFitRect(
                imageSize:
                    image.size,
                inside:
                    CGRect(
                        x: leftMargin,
                        y: cursorY,
                        width: contentWidth,
                        height: imageHeight
                    )
            )

        image.draw(
            in: imageRect
        )

        cursorY += imageHeight + 8

        drawSubsectionTitle(title)

        if !caption.isEmpty {
            drawBodyText(caption)
        }
    }

    mutating func drawFooterOnCurrentPage() {
        let attributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    UIFont.systemFont(
                        ofSize: 8
                    ),
                .foregroundColor:
                    UIColor.gray
            ]

        NSString(
            string:
                "StolarniaApp • raport wygenerowany \(Date().formatted(date: .numeric, time: .shortened))"
        ).draw(
            in:
                CGRect(
                    x: leftMargin,
                    y:
                        pageBounds.height - 28,
                    width: contentWidth,
                    height: 14
                ),
            withAttributes:
                attributes
        )
    }

    private func aspectFitRect(
        imageSize: CGSize,
        inside rect: CGRect
    ) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0
        else {
            return rect
        }

        let scale =
            min(
                rect.width
                    / imageSize.width,
                rect.height
                    / imageSize.height
            )

        let size =
            CGSize(
                width:
                    imageSize.width
                    * scale,
                height:
                    imageSize.height
                    * scale
            )

        return CGRect(
            x:
                rect.midX
                - size.width / 2,
            y:
                rect.midY
                - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
