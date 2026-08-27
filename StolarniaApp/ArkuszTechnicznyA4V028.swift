import Foundation
import SwiftUI

/// Format arkusza rysunkowego wg PN-EN ISO 5457. Domyślnie A4 pionowo
/// (warsztat drukuje na drukarce biurowej); A3 poziomo dla większych szafek
/// gdzie A4 nie wystarcza na wszystkie wymiary i tabele.
enum FormatArkuszaTechnicznego: String, CaseIterable, Identifiable {
    case a4Pionowy
    case a3Poziomy

    var id: String { rawValue }

    var tytul: String {
        switch self {
        case .a4Pionowy: return "A4"
        case .a3Poziomy: return "A3"
        }
    }

    /// Wymiary arkusza w milimetrach — użyte do proporcji i skali PDF.
    var szerokoscMM: Double {
        switch self {
        case .a4Pionowy: return 210
        case .a3Poziomy: return 420
        }
    }

    var wysokoscMM: Double {
        switch self {
        case .a4Pionowy: return 297
        case .a3Poziomy: return 297
        }
    }

    var aspectRatio: Double {
        szerokoscMM / wysokoscMM
    }
}

/// Pojedynczy arkusz techniczny modułu w formacie A4 lub A3.
/// Zawartość zgodna z wymaganiami warsztatu:
/// - rzut elewacji (główny widok) z wymiarami i otworami wierceń Ø
/// - rzut boczny z zaznaczonymi pozycjami prowadnic szuflad
/// - tabela wierceń — typ, średnica, X/Y, głębokość
/// - tabela prowadnic — producent, model, długość, pozycja od dna
/// - tabliczka rysunkowa ISO 7200 na dole
///
/// Bez aksonometrii i widoków 3D — te są w osobnych trybach dokumentacji.
struct ArkuszTechnicznyA4V028: View {
    let card: KartaTechnicznaSzafki
    let numerStrony: Int
    let liczbaStron: Int
    let format: FormatArkuszaTechnicznego

    var body: some View {
        GeometryReader { proxy in
            // Zabezpieczenie przed ujemnym rozmiarem podczas initial layout —
            // GeometryReader potrafi dostać 0×0 zanim rodzic policzy swój frame,
            // a `width - 32` daje wtedy wartość ujemną i SwiftUI wypisuje
            // "Invalid frame dimension" w runtime warnings.
            let maxWidth = max(1, min(proxy.size.width - 32, 900))
            let sheetWidth = maxWidth
            let sheetHeight = max(1, sheetWidth / format.aspectRatio)

            VStack(spacing: 0) {
                trescArkusza(
                    sheetSize: CGSize(width: sheetWidth, height: sheetHeight)
                )
                .frame(width: sheetWidth, height: sheetHeight)
                .background(Color.white)
                .overlay {
                    Rectangle().stroke(Color.black, lineWidth: 1.2)
                }
                .shadow(radius: 6, y: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
    }

    // MARK: - Zawartość arkusza

    @ViewBuilder
    private func trescArkusza(sheetSize: CGSize) -> some View {
        let padding: CGFloat = 12
        VStack(spacing: 6) {
            naglowek
                .frame(height: 26)
                .padding(.horizontal, padding)
                .padding(.top, padding)

            // Górny wiersz: elewacja (szeroko) + rzut boczny (wąsko po prawej)
            HStack(spacing: 8) {
                blokRysunkowy(tytul: "ELEWACJA — RZUT PIONOWY") {
                    rzutElewacji
                }
                .frame(maxWidth: .infinity)

                blokRysunkowy(tytul: "RZUT BOCZNY") {
                    rzutBoczny
                }
                .frame(
                    width:
                        sheetSize.width
                        * (
                            card.narożnikTechnicznyV086 == nil
                            ? 0.24
                            : 0.20
                        )
                )

                if card.narożnikTechnicznyV086 != nil {
                    blokRysunkowy(tytul: "RZUT NAROŻNIKA") {
                        rzutNaroznika
                    }
                    .frame(width: sheetSize.width * 0.28)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, padding)

            // Detale montażowe: pierwsze otwory zamiast tabel współrzędnych.
            HStack(alignment: .top, spacing: 8) {
                blokRysunkowy(tytul: "DETAL PROWADNIC — PIERWSZE OTWORY") {
                    detalProwadnicPierwszeOtwory
                }
                .frame(maxWidth: .infinity)

                if maSzufladyZaFrontem {
                    blokRysunkowy(tytul: "DETAL SZUFLADY ZA FRONTEM") {
                        detalSzufladyZaFrontem
                    }
                    .frame(maxWidth: .infinity)
                }

                blokRysunkowy(tytul: "DETAL ZAWIASÓW FRONTU") {
                    detalZawiasowFrontowych
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: sheetSize.height * 0.18)
            .padding(.horizontal, padding)

            tabliczkaISO7200
                .padding(.horizontal, padding)
                .padding(.bottom, padding)
        }
    }

    // MARK: - Nagłówek

    private var naglowek: some View {
        HStack(spacing: 8) {
            Text("STOLARNIA — KARTA TECHNICZNA")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
            Spacer()
            Text("Arkusz \(numerStrony) / \(liczbaStron)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.black)
            Divider()
                .frame(height: 14)
            Text(format.tytul)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
        }
    }

    // MARK: - Blok z ramką

    @ViewBuilder
    private func blokRysunkowy<Content: View>(
        tytul: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Text(tytul)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.06))

            Divider().background(Color.black.opacity(0.5))

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        }
        .overlay {
            Rectangle().stroke(Color.black.opacity(0.4), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    // MARK: - Rzut elewacji (front)

    private var rzutElewacji: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 26
            let usableW = max(proxy.size.width - inset * 2, 1)
            let usableH = max(proxy.size.height - inset * 2, 1)
            let scale = min(
                usableW / max(card.szerokoscMM, 1),
                usableH / max(card.wysokoscMM, 1)
            )
            let boxW = card.szerokoscMM * scale
            let boxH = card.wysokoscMM * scale
            let origin = CGPoint(
                x: (proxy.size.width - boxW) / 2,
                y: (proxy.size.height - boxH) / 2
            )
            let rect = CGRect(x: origin.x, y: origin.y, width: boxW, height: boxH)

            ZStack {
                // Kontur szafki (linia ciągła gruba wg ISO 128).
                Path { $0.addRect(rect) }
                    .stroke(Color.black, lineWidth: 1.5)

                // Wymiar szerokości pod spodem.
                wymiarPoziomy(
                    y: rect.maxY + 14,
                    xStart: rect.minX,
                    xEnd: rect.maxX,
                    text: "\(intMM(card.szerokoscMM)) mm"
                )

                // Wymiar wysokości po prawej.
                wymiarPionowy(
                    x: rect.maxX + 14,
                    yStart: rect.minY,
                    yEnd: rect.maxY,
                    text: "\(intMM(card.wysokoscMM)) mm"
                )

                // Otwory frontowe z krzyżem osi. Punkty przypięte do boków
                // korpusu są pokazane na rzucie bocznym.
                ForEach(punktyElewacji) { punkt in
                    let px = origin.x + xClamped(punkt.xMM) * scale
                    let py = origin.y + boxH - yClamped(punkt.yMM) * scale
                    symbolWiercenia(srodek: CGPoint(x: px, y: py), srednicaMM: punkt.srednicaMM, scale: scale)
                }
            }
        }
    }

    // MARK: - Rzut boczny (widok z boku, głębokość × wysokość)

    private var rzutBoczny: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 18
            let usableW = max(proxy.size.width - inset * 2, 1)
            let usableH = max(proxy.size.height - inset * 2, 1)
            let scale = min(
                usableW / max(card.glebokoscMM, 1),
                usableH / max(card.wysokoscMM, 1)
            )
            let boxW = card.glebokoscMM * scale
            let boxH = card.wysokoscMM * scale
            let origin = CGPoint(
                x: (proxy.size.width - boxW) / 2,
                y: (proxy.size.height - boxH) / 2
            )
            let rect = CGRect(x: origin.x, y: origin.y, width: boxW, height: boxH)

            ZStack {
                // Kontur boku.
                Path { $0.addRect(rect) }
                    .stroke(Color.black, lineWidth: 1.3)

                // Linie montażowe z boków korpusu: prowadnice, mechanizmy i strefy narożne.
                ForEach(prowadniceSzuflad(scale: scale, boxRect: rect)) { pr in
                    Path { path in
                        path.move(to: CGPoint(x: pr.xStartEkran, y: pr.yEkran))
                        path.addLine(to: CGPoint(x: pr.xEndEkran, y: pr.yEkran))
                    }
                    .stroke(
                        Color.black,
                        style: StrokeStyle(lineWidth: 0.8, dash: [3, 2])
                    )

                    Text(pr.etykietaKrotka)
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(x: rect.midX, y: pr.yEkran - 5)
                }

                ForEach(punktyProwadnic(scale: scale, boxRect: rect)) { punkt in
                    symbolWiercenia(
                        srodek:
                            CGPoint(
                                x: punkt.xEkran,
                                y: punkt.yEkran
                            ),
                        srednicaMM:
                            punkt.srednicaMM,
                        scale:
                            scale
                    )
                }

                // Wymiar głębokości pod spodem.
                wymiarPoziomy(
                    y: rect.maxY + 10,
                    xStart: rect.minX,
                    xEnd: rect.maxX,
                    text: "\(intMM(card.glebokoscMM))"
                )
            }
        }
    }

    // MARK: - Rzut narożnika (plan technologiczny)

    private var rzutNaroznika: some View {
        GeometryReader { proxy in
            if let corner =
                card.narożnikTechnicznyV086 {
                let inset: CGFloat = 16
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
                        (proxy.size.width - inset * 2)
                        / totalW,
                        (proxy.size.height - inset * 2)
                        / totalH
                    )
                let drawingW =
                    totalW * scale
                let drawingH =
                    totalH * scale
                let origin =
                    CGPoint(
                        x:
                            (proxy.size.width - drawingW)
                            / 2,
                        y:
                            (proxy.size.height - drawingH)
                            / 2
                    )
                let primaryRect =
                    CGRect(
                        x: origin.x,
                        y: origin.y,
                        width:
                            primaryW * scale,
                        height:
                            depth * scale
                    )
                let secondaryX =
                    corner.handedness == .left
                    ? origin.x
                    : origin.x
                        + (
                            primaryW
                            - depth
                        )
                        * scale
                let secondaryRect =
                    CGRect(
                        x: secondaryX,
                        y:
                            origin.y
                            + depth * scale,
                        width:
                            depth * scale,
                        height:
                            secondaryH * scale
                    )
                let frontX =
                    corner.handedness == .left
                    ? primaryRect.minX
                    : primaryRect.maxX
                        - corner.frontOpeningMM
                        * scale
                let frontY =
                    primaryRect.maxY
                let fillerX =
                    corner.handedness == .left
                    ? primaryRect.minX
                    : primaryRect.maxX
                        - corner.fillerWidthMM
                        * scale
                let deadW =
                    min(
                        corner.deadZoneMM,
                        primaryW
                    )
                    * scale
                let deadX =
                    corner.handedness == .left
                    ? primaryRect.maxX - deadW
                    : primaryRect.minX

                ZStack {
                    Path { path in
                        path.addRect(primaryRect)
                        path.addRect(secondaryRect)
                    }
                    .fill(Color.black.opacity(0.035))

                    Path { path in
                        path.addRect(primaryRect)
                        path.addRect(secondaryRect)
                    }
                    .stroke(Color.black, lineWidth: 1.1)

                    if corner.fillerKind != .none {
                        Rectangle()
                            .fill(Color.black.opacity(0.12))
                            .frame(
                                width:
                                    max(
                                        corner.fillerWidthMM
                                        * scale,
                                        3
                                    ),
                                height:
                                    primaryRect.height
                            )
                            .position(
                                x:
                                    fillerX
                                    + max(
                                        corner.fillerWidthMM
                                        * scale,
                                        3
                                    )
                                    / 2,
                                y:
                                    primaryRect.midY
                            )

                        Text(
                            "BL \(intMM(corner.fillerWidthMM))"
                        )
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .rotationEffect(.degrees(-90))
                        .position(
                            x:
                                fillerX
                                + max(
                                    corner.fillerWidthMM
                                    * scale,
                                    3
                                )
                                / 2,
                            y:
                                primaryRect.midY
                        )
                    }

                    if corner.shouldShowDeadZone {
                        Path { path in
                            path.addRect(
                                CGRect(
                                    x: deadX,
                                    y: primaryRect.minY,
                                    width: deadW,
                                    height:
                                        primaryRect.height
                                )
                            )
                        }
                        .fill(Color.black.opacity(0.08))

                        Path { path in
                            path.addRect(
                                CGRect(
                                    x: deadX,
                                    y: primaryRect.minY,
                                    width: deadW,
                                    height:
                                        primaryRect.height
                                )
                            )
                        }
                        .stroke(
                            Color.black,
                            style:
                                StrokeStyle(
                                    lineWidth: 0.8,
                                    dash: [4, 2]
                                )
                        )

                        Text(
                            "MARTWA \(intMM(corner.deadZoneMM))"
                        )
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(
                            x:
                                deadX
                                + deadW / 2,
                            y:
                                primaryRect.midY
                        )
                    }

                    Path { path in
                        path.move(
                            to:
                                CGPoint(
                                    x: frontX,
                                    y: frontY
                                )
                        )
                        path.addLine(
                            to:
                                CGPoint(
                                    x:
                                        frontX
                                        + corner.frontOpeningMM
                                        * scale,
                                    y: frontY
                                )
                        )
                    }
                    .stroke(Color.black, lineWidth: 2.2)

                    Text("FR \(intMM(corner.frontOpeningMM))")
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(
                            x:
                                frontX
                                + corner.frontOpeningMM
                                * scale / 2,
                            y:
                                frontY + 8
                        )

                    if corner.requiresMotionEnvelopeCheck {
                        Path { path in
                            path.addEllipse(
                                in:
                                    primaryRect
                                    .insetBy(
                                        dx:
                                            primaryRect.width
                                            * 0.18,
                                        dy:
                                            primaryRect.height
                                            * 0.18
                                    )
                            )
                        }
                        .stroke(
                            Color.black,
                            style:
                                StrokeStyle(
                                    lineWidth: 0.8,
                                    dash: [3, 3]
                                )
                        )

                        Text("KOPERTA")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black)
                            .position(
                                x: primaryRect.midX,
                                y: primaryRect.midY
                            )
                    }

                    VStack(spacing: 2) {
                        Text(corner.accessTechnology.title)
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                        Text("\(corner.kind.title) • \(corner.handedness.title)")
                            .font(.system(size: 6, design: .monospaced))
                        if corner.requiresManufacturerTemplate {
                            Text("WIERCENIA WG SZABLONU")
                                .font(.system(size: 5.5, weight: .semibold, design: .monospaced))
                        }
                    }
                    .foregroundStyle(.black)
                    .padding(3)
                    .background(Color.white.opacity(0.85))
                    .position(
                        x: proxy.size.width / 2,
                        y: max(origin.y - 8, 10)
                    )
                }
            } else {
                Text("Brak narożnika")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Detale pierwszych otworów

    private var detalProwadnicPierwszeOtwory: some View {
        GeometryReader { proxy in
            let details =
                detalePierwszychOtworowProwadnic()
            let visible =
                Array(
                    details.prefix(6)
                )

            if visible.isEmpty {
                emptyDetail(
                    "Brak prowadnic z punktem bazowym."
                )
            } else {
                let insetLeft: CGFloat = 42
                let insetRight: CGFloat = 24
                let insetTop: CGFloat = 12
                let insetBottom: CGFloat = 24
                let usableW =
                    max(
                        proxy.size.width
                        - insetLeft
                        - insetRight,
                        1
                    )
                let usableH =
                    max(
                        proxy.size.height
                        - insetTop
                        - insetBottom,
                        1
                    )
                let scale =
                    min(
                        usableW
                        / max(card.glebokoscMM, 1),
                        usableH
                        / max(card.wysokoscMM, 1)
                    )
                let rect =
                    CGRect(
                        x:
                            insetLeft,
                        y:
                            insetTop,
                        width:
                            card.glebokoscMM
                            * scale,
                        height:
                            card.wysokoscMM
                            * scale
                    )

                ZStack {
                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(Color.black, lineWidth: 1)

                    Path { path in
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
                                    x: rect.minX,
                                    y: rect.maxY
                                )
                        )
                    }
                    .stroke(Color.black, lineWidth: 2)

                    Text("FRONT")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .rotationEffect(.degrees(-90))
                        .position(
                            x: rect.minX - 12,
                            y: rect.midY
                        )

                    Text("BOK KORPUSU")
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(
                            x: rect.midX,
                            y: max(rect.minY - 5, 6)
                        )

                    wymiarPoziomy(
                        y:
                            rect.maxY + 12,
                        xStart:
                            rect.minX,
                        xEnd:
                            rect.maxX,
                        text:
                            "\(intMM(card.glebokoscMM)) mm"
                    )

                    ForEach(
                        Array(visible.enumerated()),
                        id: \.element.id
                    ) { pair in
                        let index =
                            pair.offset
                        let detail =
                            pair.element
                        let holeX =
                            rect.minX
                            + CGFloat(
                                xBokuClamped(
                                    detail.xMM
                                )
                            )
                            * scale
                        let holeY =
                            rect.maxY
                            - CGFloat(
                                yClamped(
                                    detail.yMM
                                )
                            )
                            * scale
                        let stagger: CGFloat =
                            index.isMultiple(of: 2)
                            ? -11
                            : 11
                        let dimY =
                            limited(
                                holeY + stagger,
                                min:
                                    rect.minY + 8,
                                max:
                                    rect.maxY - 8
                            )

                        Path { path in
                            path.move(
                                to:
                                    CGPoint(
                                        x: rect.minX,
                                        y: holeY
                                    )
                            )
                            path.addLine(
                                to:
                                    CGPoint(
                                        x: rect.maxX,
                                        y: holeY
                                    )
                            )
                        }
                        .stroke(
                            Color.black,
                            style:
                                StrokeStyle(
                                    lineWidth: 0.55,
                                    dash: [3, 2]
                                )
                        )

                        symbolWiercenia(
                            srodek:
                                CGPoint(
                                    x: holeX,
                                    y: holeY
                                ),
                            srednicaMM:
                                detail.srednicaMM,
                            scale:
                                scale
                        )

                        wymiarPoziomy(
                            y:
                                dimY,
                            xStart:
                                rect.minX,
                            xEnd:
                                holeX,
                            text:
                                "X \(intMM(detail.xMM))"
                        )

                        wymiarPionowy(
                            x:
                                rect.minX - 20
                                - CGFloat(index % 2) * 10,
                            yStart:
                                holeY,
                            yEnd:
                                rect.maxY,
                            text:
                                "Y \(intMM(detail.yMM))"
                        )

                        Text(detail.etykieta)
                            .font(.system(size: 6, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .position(
                                x:
                                    min(
                                        rect.maxX + 24,
                                        proxy.size.width - 26
                                    ),
                                y:
                                    holeY
                            )
                    }

                    if details.count > visible.count {
                        Text("+\(details.count - visible.count) kolejnych")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black)
                            .position(
                                x: proxy.size.width - 42,
                                y: proxy.size.height - 12
                            )
                    }
                }
            }
        }
    }

    private var detalZawiasowFrontowych: some View {
        GeometryReader { proxy in
            let details =
                detaleZawiasowFrontowych()
            let visible =
                Array(
                    details.prefix(6)
                )

            if visible.isEmpty {
                emptyDetail(
                    "Brak zawiasów frontowych."
                )
            } else {
                let frontSize =
                    wymiaryFrontuDlaDetalu
                let insetLeft: CGFloat = 36
                let insetRight: CGFloat = 30
                let insetTop: CGFloat = 12
                let insetBottom: CGFloat = 24
                let usableW =
                    max(
                        proxy.size.width
                        - insetLeft
                        - insetRight,
                        1
                    )
                let usableH =
                    max(
                        proxy.size.height
                        - insetTop
                        - insetBottom,
                        1
                    )
                let scale =
                    min(
                        usableW
                        / max(frontSize.width, 1),
                        usableH
                        / max(frontSize.height, 1)
                    )
                let rect =
                    CGRect(
                        x:
                            insetLeft,
                        y:
                            insetTop,
                        width:
                            frontSize.width * scale,
                        height:
                            frontSize.height * scale
                    )
                let hingeOnLeft =
                    visible
                        .map(\.xMM)
                        .reduce(0, +)
                    / Double(
                        max(
                            visible.count,
                            1
                        )
                    )
                    <= frontSize.width / 2
                let hingeEdgeX =
                    hingeOnLeft
                    ? rect.minX
                    : rect.maxX

                ZStack {
                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(Color.black, lineWidth: 1)

                    Path { path in
                        path.move(
                            to:
                                CGPoint(
                                    x: hingeEdgeX,
                                    y: rect.minY
                                )
                        )
                        path.addLine(
                            to:
                                CGPoint(
                                    x: hingeEdgeX,
                                    y: rect.maxY
                                )
                        )
                    }
                    .stroke(Color.black, lineWidth: 2)

                    Text("KRAWĘDŹ ZAWIASU")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .rotationEffect(.degrees(-90))
                        .position(
                            x:
                                hingeOnLeft
                                ? rect.minX - 12
                                : rect.maxX + 12,
                            y:
                                rect.midY
                        )

                    Text("FRONT")
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(
                            x: rect.midX,
                            y: max(rect.minY - 5, 6)
                        )

                    wymiarPoziomy(
                        y:
                            rect.maxY + 12,
                        xStart:
                            rect.minX,
                        xEnd:
                            rect.maxX,
                        text:
                            "\(intMM(frontSize.width)) mm"
                    )

                    ForEach(
                        Array(visible.enumerated()),
                        id: \.element.id
                    ) { pair in
                        let index =
                            pair.offset
                        let detail =
                            pair.element
                        let holeX =
                            rect.minX
                            + CGFloat(
                                min(
                                    max(
                                        detail.xMM,
                                        0
                                    ),
                                    frontSize.width
                                )
                            )
                            * scale
                        let holeY =
                            rect.maxY
                            - CGFloat(
                                min(
                                    max(
                                        detail.yMM,
                                        0
                                    ),
                                    frontSize.height
                                )
                            )
                            * scale
                        let edgeOffset =
                            hingeOnLeft
                            ? detail.xMM
                            : max(
                                frontSize.width
                                - detail.xMM,
                                0
                            )
                        let dimY =
                            limited(
                                holeY
                                + (
                                    index.isMultiple(of: 2)
                                    ? -11
                                    : 11
                                ),
                                min:
                                    rect.minY + 8,
                                max:
                                    rect.maxY - 8
                            )

                        symbolWiercenia(
                            srodek:
                                CGPoint(
                                    x: holeX,
                                    y: holeY
                                ),
                            srednicaMM:
                                detail.srednicaMM,
                            scale:
                                scale
                        )

                        wymiarPoziomy(
                            y:
                                dimY,
                            xStart:
                                hingeOnLeft
                                ? hingeEdgeX
                                : holeX,
                            xEnd:
                                hingeOnLeft
                                ? holeX
                                : hingeEdgeX,
                            text:
                                "X \(intMM(edgeOffset))"
                        )

                        wymiarPionowy(
                            x:
                                rect.minX - 18
                                - CGFloat(index % 2) * 10,
                            yStart:
                                holeY,
                            yEnd:
                                rect.maxY,
                            text:
                                "Y \(intMM(detail.yMM))"
                        )

                        Text("Ø\(intMM(detail.srednicaMM)) / gł. \(intMM(detail.glebokoscMM))")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .position(
                                x:
                                    min(
                                        rect.maxX + 34,
                                        proxy.size.width - 36
                                    ),
                                y:
                                    holeY
                            )
                    }
                }
            }
        }
    }

    private var detalSzufladyZaFrontem: some View {
        GeometryReader { proxy in
            if let drawer =
                pierwszaSzufladaZaFrontem {
                let sideInset =
                    drawer
                        .efektywneOdsuniecieOdScianBocznychMM
                let setback =
                    drawer
                        .efektywneCofniecieOdFrontuMM
                let inset: CGFloat = 18
                let usableW =
                    max(
                        proxy.size.width
                        - inset * 2,
                        1
                    )
                let usableH =
                    max(
                        proxy.size.height
                        - inset * 2,
                        1
                    )
                let scale =
                    min(
                        usableW
                        / max(card.szerokoscMM, 1),
                        usableH
                        / max(card.glebokoscMM, 1)
                    )
                let bodyW =
                    card.szerokoscMM * scale
                let bodyH =
                    card.glebokoscMM * scale
                let rect =
                    CGRect(
                        x:
                            (proxy.size.width - bodyW)
                            / 2,
                        y:
                            (proxy.size.height - bodyH)
                            / 2,
                        width:
                            bodyW,
                        height:
                            bodyH
                    )
                let drawerX =
                    rect.minX
                    + sideInset * scale
                let drawerW =
                    max(
                        rect.width
                        - sideInset * 2 * scale,
                        1
                    )
                let drawerDepth =
                    min(
                        drawer.nominalnaDlugoscMM,
                        max(
                            card.glebokoscMM
                            - setback,
                            0
                        )
                    )
                let drawerRect =
                    CGRect(
                        x:
                            drawerX,
                        y:
                            rect.maxY
                            - (setback + drawerDepth)
                            * scale,
                        width:
                            drawerW,
                        height:
                            drawerDepth * scale
                    )

                ZStack {
                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(Color.black, lineWidth: 1)

                    Path { path in
                        path.move(
                            to:
                                CGPoint(
                                    x: rect.minX,
                                    y: rect.maxY
                                )
                        )
                        path.addLine(
                            to:
                                CGPoint(
                                    x: rect.maxX,
                                    y: rect.maxY
                                )
                        )
                    }
                    .stroke(Color.black, lineWidth: 2)

                    Text("FRONT ZEWN.")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(
                            x: rect.midX,
                            y:
                                min(
                                    rect.maxY + 8,
                                    proxy.size.height - 6
                                )
                        )

                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(
                            width:
                                max(
                                    sideInset * scale,
                                    2
                                ),
                            height:
                                drawerRect.height
                        )
                        .position(
                            x:
                                rect.minX
                                + max(
                                    sideInset * scale,
                                    2
                                )
                                / 2,
                            y:
                                drawerRect.midY
                        )

                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(
                            width:
                                max(
                                    sideInset * scale,
                                    2
                                ),
                            height:
                                drawerRect.height
                        )
                        .position(
                            x:
                                rect.maxX
                                - max(
                                    sideInset * scale,
                                    2
                                )
                                / 2,
                            y:
                                drawerRect.midY
                        )

                    Path { path in
                        path.addRect(drawerRect)
                    }
                    .fill(Color.black.opacity(0.035))

                    Path { path in
                        path.addRect(drawerRect)
                    }
                    .stroke(Color.black, lineWidth: 0.9)

                    Text(drawer.etykieta)
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .position(
                            x: drawerRect.midX,
                            y: drawerRect.midY
                        )

                    wymiarPionowy(
                        x:
                            rect.maxX + 12,
                        yStart:
                            drawerRect.maxY,
                        yEnd:
                            rect.maxY,
                        text:
                            "C \(intMM(setback))"
                    )

                    if sideInset > 0.5 {
                        wymiarPoziomy(
                            y:
                                max(
                                    drawerRect.minY - 8,
                                    rect.minY + 8
                                ),
                            xStart:
                                rect.minX,
                            xEnd:
                                drawerRect.minX,
                            text:
                                "L \(intMM(sideInset))"
                        )

                        wymiarPoziomy(
                            y:
                                max(
                                    drawerRect.minY - 8,
                                    rect.minY + 8
                                ),
                            xStart:
                                drawerRect.maxX,
                            xEnd:
                                rect.maxX,
                            text:
                                "P \(intMM(sideInset))"
                        )
                    }
                }
            } else {
                emptyDetail(
                    "Brak szuflad za frontem."
                )
            }
        }
    }

    private func emptyDetail(
        _ text: String
    ) -> some View {
        Text(text)
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wymiarowanie

    private func wymiarPoziomy(
        y: CGFloat,
        xStart: CGFloat,
        xEnd: CGFloat,
        text: String
    ) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: xStart, y: y - 3))
                path.addLine(to: CGPoint(x: xStart, y: y + 3))
                path.move(to: CGPoint(x: xEnd, y: y - 3))
                path.addLine(to: CGPoint(x: xEnd, y: y + 3))
                path.move(to: CGPoint(x: xStart, y: y))
                path.addLine(to: CGPoint(x: xEnd, y: y))
            }
            .stroke(Color.black, lineWidth: 0.5)

            Text(text)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.black)
                .position(x: (xStart + xEnd) / 2, y: y - 7)
        }
    }

    private func wymiarPionowy(
        x: CGFloat,
        yStart: CGFloat,
        yEnd: CGFloat,
        text: String
    ) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: x - 3, y: yStart))
                path.addLine(to: CGPoint(x: x + 3, y: yStart))
                path.move(to: CGPoint(x: x - 3, y: yEnd))
                path.addLine(to: CGPoint(x: x + 3, y: yEnd))
                path.move(to: CGPoint(x: x, y: yStart))
                path.addLine(to: CGPoint(x: x, y: yEnd))
            }
            .stroke(Color.black, lineWidth: 0.5)

            Text(text)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.black)
                .rotationEffect(.degrees(-90))
                .position(x: x + 8, y: (yStart + yEnd) / 2)
        }
    }

    // MARK: - Symbol wiercenia (okrąg + krzyż osi + Ø)

    private func symbolWiercenia(
        srodek: CGPoint,
        srednicaMM: Double,
        scale: CGFloat
    ) -> some View {
        let d = max(srednicaMM * scale, 5)
        let r = d / 2
        let over: CGFloat = 4

        return ZStack {
            Circle()
                .stroke(Color.black, lineWidth: 0.8)
                .frame(width: d, height: d)
            Path { path in
                path.move(to: CGPoint(x: -r - over, y: 0))
                path.addLine(to: CGPoint(x: r + over, y: 0))
                path.move(to: CGPoint(x: 0, y: -r - over))
                path.addLine(to: CGPoint(x: 0, y: r + over))
            }
            .stroke(
                Color.black,
                style: StrokeStyle(lineWidth: 0.4, dash: [3, 2, 1, 2])
            )
            .frame(width: (r + over) * 2, height: (r + over) * 2)

            Text("Ø\(intMM(srednicaMM))")
                .font(.system(size: 6, weight: .regular, design: .monospaced))
                .foregroundStyle(.black)
                .offset(x: r + 8, y: -r - 2)
        }
        .position(srodek)
    }

    // MARK: - Tabela wierceń

    // MARK: - Tabela prowadnic

    // MARK: - Tabliczka rysunkowa

    private var tabliczkaISO7200: some View {
        HStack(spacing: 0) {
            komorkaTabliczki(etykieta: "NAZWA", wartosc: card.nazwa.isEmpty ? "—" : card.nazwa)
            komorkaTabliczki(etykieta: "NR", wartosc: card.numerSzafki.isEmpty ? "—" : card.numerSzafki)
            komorkaTabliczki(
                etykieta: "MATERIAŁ",
                wartosc: [card.materialKorpusu, card.materialFrontu]
                    .filter { !$0.isEmpty }
                    .joined(separator: " / ")
                    .isEmpty
                    ? "—"
                    : [card.materialKorpusu, card.materialFrontu]
                        .filter { !$0.isEmpty }
                        .joined(separator: " / ")
            )
            komorkaTabliczki(
                etykieta: "WYMIAR",
                wartosc: "\(intMM(card.szerokoscMM)) × \(intMM(card.wysokoscMM)) × \(intMM(card.glebokoscMM))"
            )
            komorkaTabliczki(etykieta: "SKALA", wartosc: "auto")
            komorkaTabliczki(
                etykieta: "DATA",
                wartosc: card.dataAktualizacji.formatted(
                    .dateTime.year().month(.twoDigits).day(.twoDigits)
                )
            )
        }
        .frame(height: 30)
        .overlay {
            Rectangle().stroke(Color.black, lineWidth: 0.8)
        }
    }

    private func komorkaTabliczki(etykieta: String, wartosc: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(etykieta)
                .font(.system(size: 6, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(wartosc)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            Divider().background(Color.black.opacity(0.4))
        }
    }

    // MARK: - Prowadnice — wyciąganie danych do tabeli i rzutu bocznego

    private struct ProwadnicaNaRysunku: Identifiable {
        let id = UUID()
        let xStartEkran: CGFloat
        let xEndEkran: CGFloat
        let yEkran: CGFloat
        let etykietaKrotka: String
    }

    private struct PunktProwadnicyNaRysunku: Identifiable {
        let id = UUID()
        let xEkran: CGFloat
        let yEkran: CGFloat
        let srednicaMM: Double
    }

    private struct DetalPierwszegoOtworuProwadnicy: Identifiable {
        let id = UUID()
        let etykieta: String
        let xMM: Double
        let yMM: Double
        let srednicaMM: Double
        let glebokoscMM: Double
    }

    private struct DetalZawiasuFrontowego: Identifiable {
        let id = UUID()
        let xMM: Double
        let yMM: Double
        let srednicaMM: Double
        let glebokoscMM: Double
    }

    private var punktyElewacji: [PunktWierceniaSzafki] {
        let cardPoints =
            card
                .punktyWiercenia
                .filter {
                    !isSidePoint($0)
                }
        let frontElementPoints =
            card
                .efektywneElementy
                .filter {
                    $0.typ == .front
                }
                .flatMap(\.punktyWiercenia)

        return uniqueDrillPoints(
            cardPoints
            + frontElementPoints
        )
    }

    private func uniqueDrillPoints(
        _ punkty:
            [PunktWierceniaSzafki]
    ) -> [PunktWierceniaSzafki] {
        var seen = Set<String>()

        return punkty.filter { punkt in
            let key =
                [
                    punkt.element,
                    punkt.typ.rawValue,
                    intMM(punkt.xMM),
                    intMM(punkt.yMM),
                    intMM(punkt.srednicaMM),
                    intMM(punkt.glebokoscMM)
                ]
                .joined(separator: "|")

            return seen.insert(key).inserted
        }
    }

    private func isSidePoint(
        _ punkt:
            PunktWierceniaSzafki
    ) -> Bool {
        punkt.element
            .localizedCaseInsensitiveContains("Bok")
        || punkt.element
            .localizedCaseInsensitiveContains(
                "Ściana boczna"
            )
    }

    private var referencyjnyBokDlaRzutu:
        ElementTechnicznySzafki?
    {
        let boki =
            card
                .efektywneElementy
                .filter {
                    $0.typ == .scianaBoczna
                    || $0.typ == .sciankaMaskujaca
                }

        return boki.first {
            $0.nazwa
                .localizedCaseInsensitiveContains(
                    "lew"
                )
        }
        ?? boki.first
    }

    private var referencyjnyFrontDlaDetalu:
        ElementTechnicznySzafki?
    {
        let fronty =
            card
                .efektywneElementy
                .filter {
                    $0.typ == .front
                }

        return fronty.first {
            $0.punktyWiercenia
                .contains {
                    $0.typ == .zawias
                }
        }
        ?? fronty.first
    }

    private var wymiaryFrontuDlaDetalu:
        (width: Double, height: Double)
    {
        if let front =
            referencyjnyFrontDlaDetalu {
            return (
                width:
                    max(
                        front.szerokoscMM,
                        1
                    ),
                height:
                    max(
                        front.dlugoscMM,
                        1
                    )
            )
        }

        return (
            width:
                max(
                    card.szerokoscMM,
                    1
                ),
            height:
                max(
                    card.wysokoscMM,
                    1
                )
        )
    }

    private var maSzufladyZaFrontem: Bool {
        pierwszaSzufladaZaFrontem != nil
    }

    private var pierwszaSzufladaZaFrontem:
        SzufladaModulu?
    {
        card
            .efektywneSzuflady
            .filter(\.aktywna)
            .first {
                $0.typFrontu == .wewnetrzny
            }
    }

    private func detalePierwszychOtworowProwadnic()
        -> [DetalPierwszegoOtworuProwadnicy]
    {
        guard let side =
            referencyjnyBokDlaRzutu
        else {
            return []
        }

        let points =
            side
                .punktyWiercenia
                .filter {
                    $0.typ == .prowadnica
                }
        let lines =
            side
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
            [DetalPierwszegoOtworuProwadnicy] = []

        for (
            index,
            line
        ) in lines.enumerated() {
            let matchingPoint =
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
                DetalPierwszegoOtworuProwadnicy(
                    etykieta:
                        label.isEmpty
                        ? "P\(index + 1)"
                        : label,
                    xMM:
                        matchingPoint?.xMM
                        ?? min(
                            line.xStartMM,
                            line.xEndMM
                        ),
                    yMM:
                        line.yMM,
                    srednicaMM:
                        matchingPoint?.srednicaMM
                        ?? 5,
                    glebokoscMM:
                        matchingPoint?.glebokoscMM
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
                if let existingIndex =
                    result.firstIndex(
                        where: {
                            abs(
                                $0.yMM
                                - point.yMM
                            ) < 2
                        }
                    ) {
                    if point.xMM
                        < result[existingIndex].xMM {
                        result[existingIndex] =
                            DetalPierwszegoOtworuProwadnicy(
                                etykieta:
                                    result[
                                        existingIndex
                                    ]
                                    .etykieta,
                                xMM:
                                    point.xMM,
                                yMM:
                                    point.yMM,
                                srednicaMM:
                                    point.srednicaMM,
                                glebokoscMM:
                                    point.glebokoscMM
                            )
                    }
                } else {
                    result.append(
                        DetalPierwszegoOtworuProwadnicy(
                            etykieta:
                                "P\(result.count + 1)",
                            xMM:
                                point.xMM,
                            yMM:
                                point.yMM,
                            srednicaMM:
                                point.srednicaMM,
                            glebokoscMM:
                                point.glebokoscMM
                        )
                    )
                }
            }
        }

        return result.sorted {
            if abs($0.yMM - $1.yMM) > 1 {
                return $0.yMM < $1.yMM
            }

            return $0.xMM < $1.xMM
        }
    }

    private func detaleZawiasowFrontowych()
        -> [DetalZawiasuFrontowego]
    {
        let elementPoints =
            referencyjnyFrontDlaDetalu?
                .punktyWiercenia
                .filter {
                    $0.typ == .zawias
                }
            ?? []
        let source =
            elementPoints.isEmpty
            ? punktyElewacji
                .filter {
                    $0.typ == .zawias
                }
            : elementPoints

        return source
            .sorted {
                if abs($0.yMM - $1.yMM) > 1 {
                    return $0.yMM < $1.yMM
                }

                return $0.xMM < $1.xMM
            }
            .map {
                DetalZawiasuFrontowego(
                    xMM:
                        $0.xMM,
                    yMM:
                        $0.yMM,
                    srednicaMM:
                        $0.srednicaMM,
                    glebokoscMM:
                        $0.glebokoscMM
                )
            }
    }

    private func prowadniceSzuflad(scale: CGFloat, boxRect: CGRect) -> [ProwadnicaNaRysunku] {
        if let side =
            referencyjnyBokDlaRzutu {
            let lines =
                side
                    .efektywneLinieWiercenia

            if !lines.isEmpty {
                return lines.map { line in
                    ProwadnicaNaRysunku(
                        xStartEkran:
                            boxRect.minX
                            + CGFloat(
                                xBokuClamped(
                                    line.xStartMM
                                )
                            )
                            * scale,
                        xEndEkran:
                            boxRect.minX
                            + CGFloat(
                                xBokuClamped(
                                    line.xEndMM
                                )
                            )
                            * scale,
                        yEkran:
                            boxRect.maxY
                            - CGFloat(
                                yClamped(
                                    line.yMM
                                )
                            )
                            * scale,
                        etykietaKrotka:
                            line.etykieta
                    )
                }
            }
        }

        return card.efektywneSzuflady
            .filter(\.aktywna)
            .compactMap { drawer in
                let y =
                    boxRect.maxY
                    - (
                        drawer.pozycjaDolnaYMM
                        + drawer.wysokoscSkrzynkiMM
                        / 2
                    )
                    * scale
                let profile = KatalogRegulAkcesoriow.profil(id: drawer.profilID)
                let etykieta = "\(profile?.producent ?? "-") \(profile?.model ?? "")"
                return ProwadnicaNaRysunku(
                    xStartEkran:
                        boxRect.minX + 4,
                    xEndEkran:
                        boxRect.maxX - 4,
                    yEkran: y,
                    etykietaKrotka: etykieta
                )
            }
    }

    private func punktyProwadnic(
        scale: CGFloat,
        boxRect: CGRect
    ) -> [PunktProwadnicyNaRysunku] {
        guard let side =
                referencyjnyBokDlaRzutu
        else {
            return []
        }

        return side
            .punktyWiercenia
            .filter {
                $0.typ == .prowadnica
            }
            .map { point in
                PunktProwadnicyNaRysunku(
                    xEkran:
                        boxRect.minX
                        + CGFloat(
                            xBokuClamped(
                                point.xMM
                            )
                        )
                        * scale,
                    yEkran:
                        boxRect.maxY
                        - CGFloat(
                            yClamped(
                                point.yMM
                            )
                        )
                        * scale,
                    srednicaMM:
                        point.srednicaMM
                )
            }
    }

    // MARK: - Helpers

    private func xClamped(_ value: Double) -> Double {
        min(max(value, 0), card.szerokoscMM)
    }

    private func xBokuClamped(_ value: Double) -> Double {
        min(max(value, 0), card.glebokoscMM)
    }

    private func yClamped(_ value: Double) -> Double {
        min(max(value, 0), card.wysokoscMM)
    }

    private func limited(
        _ value: CGFloat,
        min minValue: CGFloat,
        max maxValue: CGFloat
    ) -> CGFloat {
        Swift.min(
            Swift.max(
                value,
                minValue
            ),
            maxValue
        )
    }

    private func intMM(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
