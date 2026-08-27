import CoreGraphics
import SwiftUI
import UIKit

// MARK: - Strona PDF z rysunkiem przestrzennym

/// Dokłada do karty technicznej stronę z rysunkiem przestrzennym mebla:
/// widok złożony i widok rozstrzelony obok siebie.
///
/// `ArkuszTechnicznyA4V028` celowo nie zawiera aksonometrii, a widok 3D żyje
/// tylko interaktywnie w `Furniture3DSceneViewV017` i nie trafia do dokumentacji.
/// Ta strona zamyka tę lukę — montażysta dostaje bryłę na papierze.
enum StronaRysunkuPrzestrzennegoV090 {

    private static let marginesX: CGFloat = 36
    private static let dystansRozstrzeleniaMM = 220.0

    static func rysuj(
        context: UIGraphicsPDFRendererContext,
        bounds: CGRect,
        card: KartaTechnicznaSzafki
    ) {
        let bryly = bryly(dla: card)
        guard !bryly.isEmpty else { return }

        context.beginPage()
        let cg = context.cgContext
        let szerokoscUzyteczna = bounds.width - marginesX * 2

        // ── Nagłówek ──
        tekst("RYSUNEK PRZESTRZENNY",
              rect: CGRect(x: marginesX, y: 34, width: szerokoscUzyteczna, height: 22),
              font: .boldSystemFont(ofSize: 16))
        tekst("\(card.numerSzafki)  ·  \(card.nazwa)",
              rect: CGRect(x: marginesX, y: 56, width: szerokoscUzyteczna, height: 16),
              font: .systemFont(ofSize: 11), kolor: .darkGray)
        tekst(gabaryt(card),
              rect: CGRect(x: marginesX, y: 72, width: szerokoscUzyteczna, height: 16),
              font: .systemFont(ofSize: 10), kolor: .darkGray)
        linia(y: 94, bounds: bounds)

        let kreska = UIColor.label.cgColor
        let akcent = UIColor.systemGreen.cgColor

        // ── Widok złożony ──
        let ramkaZlozony = CGRect(x: marginesX, y: 106,
                                  width: szerokoscUzyteczna, height: 300)
        podpisRamki("WIDOK ZŁOŻONY", ramka: ramkaRysunku(ramkaZlozony))
        RysunekAksonometrycznyV090.rysuj(
            bryly: bryly, w: cg, ramka: ramkaRysunku(ramkaZlozony),
            kolorKreski: kreska, kolorAkcentu: akcent)

        // ── Widok rozstrzelony ──
        let ramkaRozstrzelony = CGRect(x: marginesX, y: 420,
                                       width: szerokoscUzyteczna, height: 300)
        podpisRamki("WIDOK ROZSTRZELONY — kolejność montażu",
                    ramka: ramkaRysunku(ramkaRozstrzelony))
        RysunekAksonometrycznyV090.rysuj(
            bryly: bryly, w: cg, ramka: ramkaRysunku(ramkaRozstrzelony),
            kolorKreski: kreska, kolorAkcentu: akcent,
            rozstrzelenieMM: dystansRozstrzeleniaMM)

        // ── Legenda ──
        var y: CGFloat = 736
        tekst("LEGENDA",
              rect: CGRect(x: marginesX, y: y, width: szerokoscUzyteczna, height: 14),
              font: .boldSystemFont(ofSize: 9), kolor: .darkGray)
        y += 16
        for (_, opis, liczba) in RysunekPrzestrzennyKartyV090.legenda(dla: bryly) {
            tekst("• \(opis) — \(liczba)",
                  rect: CGRect(x: marginesX, y: y, width: szerokoscUzyteczna, height: 13),
                  font: .systemFont(ofSize: 9), kolor: .darkGray)
            y += 13
        }

        stopka(bounds: bounds,
               tekst: "Rysunek poglądowy — rozmieszczenie elementów wynika z ich typu, "
                    + "nie zastępuje wymiarowania na stronach formatek.")
    }

    // MARK: Bryły z karty

    static func bryly(
        dla card: KartaTechnicznaSzafki
    ) -> [BrylaAksonometrycznaV090] {
        let elementy = card.efektywneElementy.map {
            (etykieta: $0.etykieta.isEmpty ? $0.typ.rawValue : $0.etykieta,
             typ: $0.typ,
             gruboscMM: $0.gruboscMM,
             ilosc: max(1, $0.ilosc))
        }
        return RysunekPrzestrzennyKartyV090.bryly(
            dla: .init(
                szerokoscMM: card.szerokoscMM,
                wysokoscMM: card.wysokoscMM,
                glebokoscMM: card.glebokoscMM,
                elementy: elementy
            )
        )
    }

    // MARK: Pomocnicze rysowanie

    private static func gabaryt(_ card: KartaTechnicznaSzafki) -> String {
        let f: (Double) -> String = { String(format: "%.0f", $0) }
        return "\(f(card.szerokoscMM)) × \(f(card.wysokoscMM)) × \(f(card.glebokoscMM)) mm"
            + "   ·   korpus: \(card.materialKorpusu)"
            + (card.materialFrontu.isEmpty ? "" : "   ·   fronty: \(card.materialFrontu)")
    }

    private static func ramkaRysunku(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: r.minY + 16, width: r.width, height: r.height - 16)
    }

    private static func podpisRamki(_ napis: String, ramka: CGRect) {
        tekst(napis,
              rect: CGRect(x: ramka.minX, y: ramka.minY - 15,
                           width: ramka.width, height: 13),
              font: .boldSystemFont(ofSize: 9), kolor: .darkGray)
        UIColor.separator.setStroke()
        let obrys = UIBezierPath(rect: ramka)
        obrys.lineWidth = 0.5
        obrys.stroke()
    }

    private static func tekst(
        _ napis: String,
        rect: CGRect,
        font: UIFont,
        kolor: UIColor = .label
    ) {
        let styl = NSMutableParagraphStyle()
        styl.lineBreakMode = .byTruncatingTail
        napis.draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: kolor, .paragraphStyle: styl,
        ])
    }

    private static func linia(y: CGFloat, bounds: CGRect) {
        UIColor.separator.setStroke()
        let l = UIBezierPath()
        l.move(to: CGPoint(x: marginesX, y: y))
        l.addLine(to: CGPoint(x: bounds.width - marginesX, y: y))
        l.lineWidth = 0.5
        l.stroke()
    }

    private static func stopka(bounds: CGRect, tekst napis: String) {
        linia(y: bounds.height - 34, bounds: bounds)
        let styl = NSMutableParagraphStyle()
        styl.alignment = .center
        napis.draw(
            in: CGRect(x: marginesX, y: bounds.height - 28,
                       width: bounds.width - marginesX * 2, height: 20),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.gray,
                .paragraphStyle: styl,
            ])
    }
}

// MARK: - Podgląd SwiftUI

