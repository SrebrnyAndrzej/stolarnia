import Foundation
import UIKit

enum ProductionExportErrorV027:
    LocalizedError
{
    case noPackages
    case unableToCreateFile
    case unableToWriteFile

    var errorDescription: String? {
        switch self {
        case .noPackages:
            return "Brak danych produkcyjnych do eksportu."
        case .unableToCreateFile:
            return "Nie udało się utworzyć pliku eksportu."
        case .unableToWriteFile:
            return "Nie udało się zapisać pliku eksportu."
        }
    }
}

@MainActor
enum ProductionExportServiceV027 {
    static func export(
        packages:
            [CornerProductionPackageV026],
        format:
            ProductionExportFormatV027,
        projectName: String
    ) throws -> ProductionExportResultV027 {
        guard !packages.isEmpty else {
            throw ProductionExportErrorV027.noPackages
        }

        let safeProjectName =
            sanitizedFileName(projectName)
        let timestamp =
            Self.timestampFormatter.string(
                from: Date()
            )
        let fileName =
            "\(safeProjectName)_produkcja_naroznikow_\(timestamp).\(format.fileExtension)"
        let url =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName,
                    isDirectory: false
                )

        switch format {
        case .pdf:
            try writePDF(
                packages: packages,
                projectName: projectName,
                to: url
            )

        case .csv:
            try writeCSV(
                packages: packages,
                projectName: projectName,
                to: url
            )
        }

        guard
            FileManager.default
                .fileExists(
                    atPath: url.path
                )
        else {
            throw ProductionExportErrorV027.unableToCreateFile
        }

        return ProductionExportResultV027(
            url: url,
            format: format,
            generatedAt: Date()
        )
    }

    private static func writeCSV(
        packages:
            [CornerProductionPackageV026],
        projectName: String,
        to url: URL
    ) throws {
        var rows: [String] = []

        rows.append(
            csvRow([
                "Projekt",
                projectName
            ])
        )

        rows.append(
            csvRow([
                "Wygenerowano",
                Date.now.formatted(
                    date: .numeric,
                    time: .standard
                )
            ])
        )

        rows.append("")

        rows.append(
            csvRow([
                "Moduł",
                "Element",
                "Ilość",
                "Długość [mm]",
                "Szerokość [mm]",
                "Grubość [mm]",
                "Materiał",
                "Obrzeża",
                "Uwagi"
            ])
        )

        for (
            packageIndex,
            package
        ) in packages.enumerated() {
            let moduleLabel =
                "N\(String(format: "%02d", packageIndex + 1))"

            for part in package.parts {
                let edgeBanding =
                    part.edgeBanding
                        .map(\.title)
                        .sorted()
                        .joined(
                            separator: ", "
                        )

                rows.append(
                    csvRow([
                        moduleLabel,
                        part.name,
                        "\(part.quantity)",
                        decimal(part.lengthMM),
                        decimal(part.widthMM),
                        decimal(part.thicknessMM),
                        part.material.title,
                        edgeBanding,
                        part.note
                    ])
                )
            }
        }

        rows.append("")
        rows.append(
            csvRow([
                "Moduł",
                "Okucie",
                "Ilość",
                "Uwagi"
            ])
        )

        for (
            packageIndex,
            package
        ) in packages.enumerated() {
            let moduleLabel =
                "N\(String(format: "%02d", packageIndex + 1))"

            for item in package.hardware {
                rows.append(
                    csvRow([
                        moduleLabel,
                        item.name,
                        "\(item.quantity)",
                        item.note
                    ])
                )
            }
        }

        let content =
            "\u{FEFF}"
            + rows.joined(
                separator: "\r\n"
            )

        do {
            try content.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw ProductionExportErrorV027.unableToWriteFile
        }
    }

    private static func writePDF(
        packages:
            [CornerProductionPackageV026],
        projectName: String,
        to url: URL
    ) throws {
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: 842,
            height: 595
        )

        let format =
            UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String:
                "Dokumentacja produkcyjna — \(projectName)",
            kCGPDFContextCreator as String:
                "StolarniaApp"
        ]

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageBounds,
                format: format
            )

        do {
            try renderer.writePDF(
                to: url
            ) { context in
                var pageNumber = 0

                for (
                    packageIndex,
                    package
                ) in packages.enumerated() {
                    context.beginPage()
                    pageNumber += 1

                    drawPackagePage(
                        package,
                        packageIndex:
                            packageIndex,
                        projectName:
                            projectName,
                        pageNumber:
                            pageNumber,
                        bounds:
                            pageBounds,
                        context:
                            context.cgContext
                    )
                }
            }
        } catch {
            throw ProductionExportErrorV027.unableToWriteFile
        }
    }

    private static func drawPackagePage(
        _ package:
            CornerProductionPackageV026,
        packageIndex: Int,
        projectName: String,
        pageNumber: Int,
        bounds: CGRect,
        context: CGContext
    ) {
        UIColor.white.setFill()
        context.fill(bounds)

        let margin: CGFloat = 34
        let contentWidth =
            bounds.width
            - margin * 2

        drawText(
            "DOKUMENTACJA PRODUKCYJNA",
            in: CGRect(
                x: margin,
                y: 24,
                width: contentWidth,
                height: 24
            ),
            font:
                .systemFont(
                    ofSize: 17,
                    weight: .bold
                ),
            alignment: .left
        )

        drawText(
            projectName,
            in: CGRect(
                x: margin,
                y: 50,
                width: contentWidth,
                height: 18
            ),
            font:
                .systemFont(
                    ofSize: 12,
                    weight: .medium
                ),
            alignment: .left
        )

        drawText(
            "Narożnik N\(String(format: "%02d", packageIndex + 1))",
            in: CGRect(
                x: margin,
                y: 76,
                width:
                    contentWidth * 0.55,
                height: 22
            ),
            font:
                .systemFont(
                    ofSize: 15,
                    weight: .semibold
                ),
            alignment: .left
        )

        drawText(
            "Strona \(pageNumber)",
            in: CGRect(
                x:
                    bounds.width
                    - margin
                    - 120,
                y: 76,
                width: 120,
                height: 22
            ),
            font:
                .monospacedDigitSystemFont(
                    ofSize: 10,
                    weight: .regular
                ),
            alignment: .right
        )

        let summaryY: CGFloat = 106

        drawSummaryBox(
            title: "Elementy",
            value:
                "\(package.totalPartCount)",
            frame: CGRect(
                x: margin,
                y: summaryY,
                width:
                    contentWidth / 3
                    - 8,
                height: 48
            )
        )

        drawSummaryBox(
            title: "Powierzchnia",
            value:
                package
                    .totalBoardAreaSquareMeters
                    .formatted(
                        .number.precision(
                            .fractionLength(2)
                        )
                    )
                + " m²",
            frame: CGRect(
                x:
                    margin
                    + contentWidth / 3,
                y: summaryY,
                width:
                    contentWidth / 3
                    - 8,
                height: 48
            )
        )

        drawSummaryBox(
            title: "Pozycje okuć",
            value:
                "\(package.hardware.count)",
            frame: CGRect(
                x:
                    margin
                    + contentWidth * 2 / 3,
                y: summaryY,
                width:
                    contentWidth / 3,
                height: 48
            )
        )

        var y: CGFloat = 170

        y = drawPartsTable(
            package.parts,
            startY: y,
            margin: margin,
            contentWidth:
                contentWidth,
            bottomLimit:
                bounds.height - 106
        )

        if y < bounds.height - 84 {
            drawHardwareSummary(
                package.hardware,
                startY: y + 10,
                margin: margin,
                contentWidth:
                    contentWidth
            )
        }

        context.setStrokeColor(
            UIColor.black.cgColor
        )
        context.setLineWidth(0.8)
        context.stroke(
            CGRect(
                x: margin,
                y:
                    bounds.height - 48,
                width: contentWidth,
                height: 24
            )
        )

        drawText(
            "StolarniaApp • wygenerowano \(Date.now.formatted(date: .numeric, time: .shortened))",
            in: CGRect(
                x: margin + 8,
                y:
                    bounds.height - 44,
                width:
                    contentWidth - 16,
                height: 16
            ),
            font:
                .systemFont(
                    ofSize: 8
                ),
            alignment: .left
        )
    }

    @discardableResult
    private static func drawPartsTable(
        _ parts:
            [CornerProductionPartV026],
        startY: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        bottomLimit: CGFloat
    ) -> CGFloat {
        let columns: [CGFloat] = [
            250,
            42,
            92,
            92,
            72,
            contentWidth
            - 548
        ]

        var y = startY
        let headerHeight: CGFloat = 24
        let rowHeight: CGFloat = 24

        drawTableRow(
            values: [
                "Element",
                "Ilość",
                "Długość",
                "Szerokość",
                "Grubość",
                "Materiał"
            ],
            columns: columns,
            x: margin,
            y: y,
            height: headerHeight,
            bold: true
        )

        y += headerHeight

        for part in parts {
            guard
                y + rowHeight
                <= bottomLimit
            else {
                break
            }

            drawTableRow(
                values: [
                    part.name,
                    "\(part.quantity)",
                    decimal(part.lengthMM),
                    decimal(part.widthMM),
                    decimal(part.thicknessMM),
                    part.material.title
                ],
                columns: columns,
                x: margin,
                y: y,
                height: rowHeight,
                bold: false
            )

            y += rowHeight
        }

        return y
    }

    private static func drawTableRow(
        values: [String],
        columns: [CGFloat],
        x: CGFloat,
        y: CGFloat,
        height: CGFloat,
        bold: Bool
    ) {
        var currentX = x

        for index in columns.indices {
            let width = columns[index]
            let frame = CGRect(
                x: currentX,
                y: y,
                width: width,
                height: height
            )

            UIColor.black.setStroke()
            UIRectFrame(frame)

            let text =
                index < values.count
                ? values[index]
                : ""

            drawText(
                text,
                in: frame.insetBy(
                    dx: 4,
                    dy: 4
                ),
                font:
                    .systemFont(
                        ofSize: 8,
                        weight:
                            bold
                            ? .semibold
                            : .regular
                    ),
                alignment:
                    index == 0
                    ? .left
                    : .center
            )

            currentX += width
        }
    }

    private static func drawHardwareSummary(
        _ items:
            [CornerHardwareItemV026],
        startY: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        drawText(
            "OKUCIA",
            in: CGRect(
                x: margin,
                y: startY,
                width: contentWidth,
                height: 18
            ),
            font:
                .systemFont(
                    ofSize: 11,
                    weight: .bold
                ),
            alignment: .left
        )

        let line =
            items.map {
                "\($0.name): \($0.quantity) szt."
            }
            .joined(
                separator: "   •   "
            )

        drawText(
            line,
            in: CGRect(
                x: margin,
                y: startY + 20,
                width: contentWidth,
                height: 36
            ),
            font:
                .systemFont(
                    ofSize: 9
                ),
            alignment: .left
        )
    }

    private static func drawSummaryBox(
        title: String,
        value: String,
        frame: CGRect
    ) {
        UIColor.black.setStroke()
        UIRectFrame(frame)

        drawText(
            title.uppercased(),
            in: CGRect(
                x: frame.minX + 8,
                y: frame.minY + 6,
                width:
                    frame.width - 16,
                height: 12
            ),
            font:
                .systemFont(
                    ofSize: 7,
                    weight: .medium
                ),
            alignment: .left
        )

        drawText(
            value,
            in: CGRect(
                x: frame.minX + 8,
                y: frame.minY + 21,
                width:
                    frame.width - 16,
                height: 20
            ),
            font:
                .monospacedDigitSystemFont(
                    ofSize: 13,
                    weight: .semibold
                ),
            alignment: .left
        )
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        alignment:
            NSTextAlignment
    ) {
        let style =
            NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode =
            .byTruncatingTail

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor:
                    UIColor.black,
                .paragraphStyle: style
            ]

        text.draw(
            in: rect,
            withAttributes: attributes
        )
    }

    private static func csvRow(
        _ values: [String]
    ) -> String {
        values.map(csvValue)
            .joined(separator: ";")
    }

    private static func csvValue(
        _ value: String
    ) -> String {
        let escaped =
            value.replacingOccurrences(
                of: "\"",
                with: "\"\""
            )

        return "\"\(escaped)\""
    }

    private static func decimal(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .grouping(.never)
                .precision(
                    .fractionLength(
                        0...2
                    )
                )
        )
    }

    private static func sanitizedFileName(
        _ value: String
    ) -> String {
        let allowed =
            CharacterSet
                .alphanumerics
                .union(
                    CharacterSet(
                        charactersIn:
                            "-_"
                    )
                )

        let mapped =
            value.unicodeScalars.map {
                allowed.contains($0)
                ? Character(String($0))
                : "_"
            }

        let result = String(mapped)

        return result.isEmpty
            ? "StolarniaApp"
            : result
    }

    private static let timestampFormatter:
        DateFormatter = {
            let formatter =
                DateFormatter()
            formatter.locale =
                Locale(
                    identifier: "pl_PL"
                )
            formatter.dateFormat =
                "yyyy-MM-dd_HH-mm"
            return formatter
        }()
}
