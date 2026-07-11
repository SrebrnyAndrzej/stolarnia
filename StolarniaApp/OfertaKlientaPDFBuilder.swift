import Foundation
import UIKit

@MainActor
enum OfertaKlientaPDFBuilder {
    static func build(
        projekt:
            ProjektWyceny,
        wyceny:
            [PodsumowanieWariantuWyceny],
        wybranyWariant:
            WariantWyceny,
        warunki:
            WarunkiOfertyKlienta,
        ustawienia:
            UstawieniaStolarni
    ) throws -> URL {
        guard let selected =
            wyceny.first(
                where: {
                    $0.wariant
                    == wybranyWariant
                }
            )
        else {
            throw OfertaKlientaPDFError
                .missingVariant
        }

        let pageBounds =
            CGRect(
                x: 0,
                y: 0,
                width: 595.2,
                height: 841.8
            )

        let url =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName(
                        project:
                            projekt.nazwaProjektu
                    )
                )

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageBounds
            )

        try renderer.writePDF(
            to: url
        ) { rendererContext in
            var page =
                OfertaPDFPage(
                    context:
                        rendererContext,
                    bounds:
                        pageBounds
                )

            page.beginPage()
            page.drawHeader(
                company:
                    ustawienia.daneFirmy,
                title:
                    warunki.tytulOferty,
                project:
                    projekt.nazwaProjektu
            )

            page.drawSectionTitle(
                "Dane oferty"
            )

            if !warunki.numerOferty.isEmpty {
                page.drawKeyValue(
                    key: "Nr oferty",
                    value: warunki.numerOferty
                )
            }

            page.drawKeyValue(
                key: "Klient",
                value:
                    warunki.klient.isEmpty
                    ? "Nie podano"
                    : warunki.klient
            )

            page.drawKeyValue(
                key: "Projekt",
                value:
                    projekt.nazwaProjektu
            )

            page.drawKeyValue(
                key: "Data",
                value:
                    Date().formatted(
                        date: .long,
                        time: .omitted
                    )
            )

            page.drawKeyValue(
                key: "Ważność oferty",
                value:
                    "\(warunki.waznoscOfertyDni) dni od daty wystawienia"
            )

            page.drawSectionTitle(
                "Zakres prac"
            )

            page.drawBodyText(
                warunki.zakresPrac
            )

            page.drawSectionTitle(
                "Rekomendowany wariant"
            )

            page.drawVariantCard(
                selected,
                highlighted: true,
                showNet:
                    warunki
                        .pokazCenyNetto,
                showVAT:
                    warunki
                        .pokazVAT
            )

            if warunki.pokazWszystkieWarianty {
                page.drawSectionTitle(
                    "Porównanie wariantów"
                )

                for summary in wyceny {
                    page.drawVariantCard(
                        summary,
                        highlighted:
                            summary.wariant
                            == wybranyWariant,
                        showNet:
                            warunki
                                .pokazCenyNetto,
                        showVAT:
                            warunki
                                .pokazVAT
                    )
                }
            }

            page.drawSectionTitle(
                "Zakres ilościowy"
            )

            page.drawKeyValue(
                key: "Liczba modułów",
                value:
                    String(
                        projekt
                            .liczbaModulow
                    )
            )

            page.drawKeyValue(
                key: "Długość zabudowy",
                value:
                    quantity(
                        projekt
                            .metryBiezaceZabudowy,
                        unit: "mb"
                    )
            )

            page.drawKeyValue(
                key: "Fronty",
                value:
                    quantity(
                        projekt
                            .powierzchniaFrontowM2,
                        unit: "m²"
                    )
            )

            page.drawKeyValue(
                key: "Blat",
                value:
                    quantity(
                        projekt
                            .metryBiezaceBlatu,
                        unit: "mb"
                    )
            )

            page.drawKeyValue(
                key: "Szuflady",
                value:
                    String(
                        projekt
                            .liczbaSzuflad
                    )
            )

            page.drawKeyValue(
                key: "Cargo",
                value:
                    String(
                        projekt
                            .liczbaCargo
                    )
            )

            page.drawSectionTitle(
                "Termin i płatności"
            )

            page.drawKeyValue(
                key: "Termin realizacji",
                value:
                    "około \(warunki.terminRealizacjiDni) dni"
            )

            page.drawBullet(
                "Zaliczka po akceptacji: \(percent(warunki.zaliczkaProcent))"
            )

            page.drawBullet(
                "Płatność przed montażem: \(percent(warunki.platnoscPrzedMontazemProcent))"
            )

            page.drawBullet(
                "Płatność po zakończeniu montażu: \(percent(warunki.platnoscPoMontazuProcent))"
            )

            if !warunki.uwagi
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty {
                page.drawSectionTitle(
                    "Uwagi"
                )

                page.drawBodyText(
                    warunki.uwagi
                )
            }

            // MARK: - Gwarancja
            if warunki.gwarancjaMiesiecy > 0 {
                page.drawSectionTitle(
                    "Gwarancja"
                )

                page.drawKeyValue(
                    key: "Okres gwarancji",
                    value:
                        "\(warunki.gwarancjaMiesiecy) miesięcy"
                )

                if !warunki.opisGwarancji
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                    page.drawBodyText(
                        warunki.opisGwarancji
                    )
                }
            }

            page.drawAcceptanceBlock(
                grossPrice:
                    selected
                        .cenaBrutto,
                variant:
                    selected
                        .wariant
                        .nazwa
            )

            page.drawFooter()
        }

        return url
    }

    private static func fileName(
        project: String
    ) -> String {
        let safe =
            project
                .folding(
                    options:
                        .diacriticInsensitive,
                    locale: .current
                )
                .components(
                    separatedBy:
                        CharacterSet
                            .alphanumerics
                            .union(
                                CharacterSet(
                                    charactersIn:
                                        "-_"
                                )
                            )
                            .inverted
                )
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: "-"
                )

        let stamp =
            Date().formatted(
                .dateTime
                    .year()
                    .month()
                    .day()
            )
            .replacingOccurrences(
                of: " ",
                with: "-"
            )

        return "Oferta-\(safe)-\(stamp).pdf"
    }

    private static func quantity(
        _ value: Double,
        unit: String
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...2)
            )
        )
        + " "
        + unit
    }

    private static func percent(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
        + "%"
    }
}

enum OfertaKlientaPDFError:
    LocalizedError
{
    case missingVariant

    var errorDescription:
        String?
    {
        "Nie znaleziono wybranego wariantu wyceny."
    }
}

private struct OfertaPDFPage {
    let context:
        UIGraphicsPDFRendererContext
    let bounds:
        CGRect

    private(set) var y:
        CGFloat = 48

    private let margin:
        CGFloat = 46

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

    private var width:
        CGFloat
    {
        bounds.width
        - margin * 2
    }

    mutating func beginPage() {
        context.beginPage()
        y = 48
    }

    mutating func ensure(
        _ height: CGFloat
    ) {
        if y + height
            > bounds.height - 52 {
            drawFooter()
            beginPage()
        }
    }

    mutating func drawHeader(
        company:
            DaneFirmyStolarni,
        title: String,
        project: String
    ) {
        let rect =
            CGRect(
                x: margin,
                y: y,
                width: width,
                height: 104
            )

        let path =
            UIBezierPath(
                roundedRect: rect,
                cornerRadius: 18
            )

        anthracite.setFill()
        path.fill()

        draw(
            title,
            rect:
                CGRect(
                    x: margin + 20,
                    y: y + 18,
                    width: width - 40,
                    height: 28
                ),
            font:
                .systemFont(
                    ofSize: 22,
                    weight: .bold
                ),
            color: .white
        )

        draw(
            project,
            rect:
                CGRect(
                    x: margin + 20,
                    y: y + 52,
                    width: width - 40,
                    height: 20
                ),
            font:
                .systemFont(
                    ofSize: 13,
                    weight: .semibold
                ),
            color:
                UIColor.white
                    .withAlphaComponent(
                        0.78
                    )
        )

        let companyLine =
            [
                company.nazwaFirmy,
                company.telefon,
                company.email
            ]
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: " • "
            )

        draw(
            companyLine,
            rect:
                CGRect(
                    x: margin + 20,
                    y: y + 78,
                    width: width - 40,
                    height: 16
                ),
            font:
                .systemFont(
                    ofSize: 9
                ),
            color:
                UIColor.white
                    .withAlphaComponent(
                        0.64
                    )
        )

        y += 122
    }

    mutating func drawSectionTitle(
        _ title: String
    ) {
        ensure(38)

        draw(
            title,
            rect:
                CGRect(
                    x: margin,
                    y: y,
                    width: width,
                    height: 24
                ),
            font:
                .systemFont(
                    ofSize: 15,
                    weight: .bold
                ),
            color:
                anthracite
        )

        accent.setFill()

        UIBezierPath(
            roundedRect:
                CGRect(
                    x: margin,
                    y: y + 25,
                    width: 58,
                    height: 3
                ),
            cornerRadius: 1.5
        ).fill()

        y += 38
    }

    mutating func drawKeyValue(
        key: String,
        value: String
    ) {
        ensure(24)

        draw(
            key,
            rect:
                CGRect(
                    x: margin,
                    y: y,
                    width: 170,
                    height: 18
                ),
            font:
                .systemFont(
                    ofSize: 10,
                    weight: .semibold
                ),
            color:
                .darkGray
        )

        draw(
            value,
            rect:
                CGRect(
                    x: margin + 176,
                    y: y,
                    width: width - 176,
                    height: 18
                ),
            font:
                .systemFont(
                    ofSize: 10
                ),
            color: .black
        )

        y += 23
    }

    mutating func drawBodyText(
        _ value: String
    ) {
        let font =
            UIFont.systemFont(
                ofSize: 10
            )

        let paragraph =
            NSMutableParagraphStyle()

        paragraph.lineSpacing = 3

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor:
                    UIColor.black,
                .paragraphStyle:
                    paragraph
            ]

        let height =
            NSString(
                string: value
            )
            .boundingRect(
                with:
                    CGSize(
                        width: width,
                        height:
                            .greatestFiniteMagnitude
                    ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes:
                    attributes,
                context: nil
            )
            .height + 8

        ensure(height)

        NSString(
            string: value
        )
        .draw(
            in:
                CGRect(
                    x: margin,
                    y: y,
                    width: width,
                    height: height
                ),
            withAttributes:
                attributes
        )

        y += height
    }

    mutating func drawBullet(
        _ value: String
    ) {
        drawBodyText(
            "• \(value)"
        )
    }

    mutating func drawVariantCard(
        _ summary:
            PodsumowanieWariantuWyceny,
        highlighted: Bool,
        showNet: Bool,
        showVAT: Bool
    ) {
        let height:
            CGFloat =
                showNet || showVAT
                ? 88
                : 70

        ensure(height + 10)

        let rect =
            CGRect(
                x: margin,
                y: y,
                width: width,
                height: height
            )

        let path =
            UIBezierPath(
                roundedRect: rect,
                cornerRadius: 14
            )

        (
            highlighted
            ? accent.withAlphaComponent(
                0.14
            )
            : UIColor(
                white: 0.95,
                alpha: 1
            )
        )
        .setFill()

        path.fill()

        (
            highlighted
            ? accent
            : UIColor.lightGray
        )
        .setStroke()

        path.lineWidth =
            highlighted
            ? 2
            : 1

        path.stroke()

        draw(
            summary.wariant.nazwa,
            rect:
                CGRect(
                    x: margin + 16,
                    y: y + 12,
                    width: 180,
                    height: 22
                ),
            font:
                .systemFont(
                    ofSize: 14,
                    weight: .bold
                ),
            color:
                anthracite
        )

        draw(
            summary.wariant.opis,
            rect:
                CGRect(
                    x: margin + 16,
                    y: y + 38,
                    width: width - 210,
                    height: 34
                ),
            font:
                .systemFont(
                    ofSize: 8.5
                ),
            color:
                .darkGray
        )

        draw(
            summary.cenaBrutto
                .formatted(
                    .currency(
                        code: "PLN"
                    )
                ),
            rect:
                CGRect(
                    x: margin + width - 190,
                    y: y + 12,
                    width: 174,
                    height: 24
                ),
            font:
                .systemFont(
                    ofSize: 16,
                    weight: .bold
                ),
            color:
                highlighted
                ? accent
                : anthracite,
            alignment:
                .right
        )

        var details:
            [String] = []

        if showNet {
            details.append(
                "netto "
                + summary.cenaNetto
                    .formatted(
                        .currency(
                            code: "PLN"
                        )
                    )
            )
        }

        if showVAT {
            details.append(
                "VAT "
                + summary.vatKwota
                    .formatted(
                        .currency(
                            code: "PLN"
                        )
                    )
            )
        }

        if !details.isEmpty {
            draw(
                details.joined(
                    separator: " • "
                ),
                rect:
                    CGRect(
                        x: margin + width - 230,
                        y: y + 42,
                        width: 214,
                        height: 20
                    ),
                font:
                    .systemFont(
                        ofSize: 8.5
                    ),
                color:
                    .darkGray,
                alignment:
                    .right
            )
        }

        y += height + 10
    }

    mutating func drawAcceptanceBlock(
        grossPrice: Double,
        variant: String
    ) {
        ensure(116)

        let rect =
            CGRect(
                x: margin,
                y: y,
                width: width,
                height: 100
            )

        let path =
            UIBezierPath(
                roundedRect: rect,
                cornerRadius: 14
            )

        UIColor(
            white: 0.96,
            alpha: 1
        )
        .setFill()

        path.fill()

        draw(
            "Akceptuję wariant \(variant) w cenie \(grossPrice.formatted(.currency(code: "PLN")))",
            rect:
                CGRect(
                    x: margin + 16,
                    y: y + 14,
                    width: width - 32,
                    height: 22
                ),
            font:
                .systemFont(
                    ofSize: 11,
                    weight: .semibold
                ),
            color:
                anthracite
        )

        draw(
            "Data i podpis klienta",
            rect:
                CGRect(
                    x: margin + 16,
                    y: y + 70,
                    width: 180,
                    height: 16
                ),
            font:
                .systemFont(
                    ofSize: 8
                ),
            color:
                .gray
        )

        UIColor.gray.setStroke()

        let line =
            UIBezierPath()

        line.move(
            to:
                CGPoint(
                    x: margin + 210,
                    y: y + 79
                )
        )

        line.addLine(
            to:
                CGPoint(
                    x: margin + width - 16,
                    y: y + 79
                )
        )

        line.lineWidth = 0.7
        line.stroke()

        y += 116
    }

    mutating func drawFooter() {
        draw(
            "StolarniaApp • dokument wygenerowany \(Date().formatted(date: .numeric, time: .shortened))",
            rect:
                CGRect(
                    x: margin,
                    y: bounds.height - 28,
                    width: width,
                    height: 14
                ),
            font:
                .systemFont(
                    ofSize: 7.5
                ),
            color:
                .gray,
            alignment:
                .center
        )
    }

    private func draw(
        _ value: String,
        rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment:
            NSTextAlignment = .left
    ) {
        let paragraph =
            NSMutableParagraphStyle()

        paragraph.alignment =
            alignment

        NSString(
            string: value
        )
        .draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor:
                    color,
                .paragraphStyle:
                    paragraph
            ]
        )
    }
}
