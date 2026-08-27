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
            let maxWidth = min(proxy.size.width - 32, 900)
            let sheetWidth = maxWidth
            let sheetHeight = sheetWidth / format.aspectRatio

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
                .frame(width: sheetSize.width * 0.24)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, padding)

            // Tabele — wiercenia + prowadnice
            HStack(alignment: .top, spacing: 8) {
                blokTabela(tytul: "TABELA WIERCEŃ") {
                    tabelaWiercen
                }
                blokTabela(tytul: "PROWADNICE SZUFLAD") {
                    tabelaProwadnic
                }
            }
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
    private func blokTabela<Content: View>(
        tytul: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        blokRysunkowy(tytul: tytul) {
            content()
                .padding(4)
        }
        .frame(maxWidth: .infinity)
    }

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

                // Otwory wierceń z krzyżem osi.
                ForEach(card.punktyWiercenia) { punkt in
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

                // Pozycje prowadnic szuflad — poziome kreski na ścianie bocznej.
                ForEach(prowadniceSzuflad(scale: scale, boxRect: rect)) { pr in
                    Path { path in
                        path.move(to: CGPoint(x: rect.minX + 4, y: pr.yEkran))
                        path.addLine(to: CGPoint(x: rect.maxX - 4, y: pr.yEkran))
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

    private var tabelaWiercen: some View {
        VStack(spacing: 0) {
            wierszTabeli(
                komorki: ["#", "Typ", "Ø", "X mm", "Y mm", "Gł.", "Str."],
                naglowek: true
            )
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(
                        Array(card.punktyWiercenia.enumerated()),
                        id: \.offset
                    ) { pair in
                        let p = pair.element
                        wierszTabeli(
                            komorki: [
                                "\(pair.offset + 1)",
                                p.typ.nazwa,
                                "\(intMM(p.srednicaMM))",
                                "\(intMM(p.xMM))",
                                "\(intMM(p.yMM))",
                                "\(intMM(p.glebokoscMM))",
                                p.strona.nazwa
                            ],
                            naglowek: false
                        )
                        Divider().opacity(0.3)
                    }

                    if card.punktyWiercenia.isEmpty {
                        Text("Brak zdefiniowanych punktów wiercenia.")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    // MARK: - Tabela prowadnic

    private var tabelaProwadnic: some View {
        VStack(spacing: 0) {
            wierszTabeli(
                komorki: ["#", "Producent", "Model", "Długość", "Wys. od dna"],
                naglowek: true
            )
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    let prowadnice = daneProwadnicTabeli()
                    ForEach(Array(prowadnice.enumerated()), id: \.offset) { pair in
                        let d = pair.element
                        wierszTabeli(
                            komorki: [
                                "\(pair.offset + 1)",
                                d.producent,
                                d.model,
                                "\(intMM(d.dlugoscMM)) mm",
                                "\(intMM(d.wysokoscOdDnaMM)) mm"
                            ],
                            naglowek: false
                        )
                        Divider().opacity(0.3)
                    }

                    if prowadnice.isEmpty {
                        Text("Brak szuflad z prowadnicami.")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private func wierszTabeli(
        komorki: [String],
        naglowek: Bool
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(komorki.enumerated()), id: \.offset) { pair in
                Text(pair.element)
                    .font(
                        .system(
                            size: naglowek ? 7 : 8,
                            weight: naglowek ? .bold : .regular,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
                    .padding(.vertical, naglowek ? 2 : 1)
            }
        }
        .background(naglowek ? Color.black.opacity(0.06) : Color.clear)
    }

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

    private struct DaneProwadnicy: Hashable {
        let producent: String
        let model: String
        let dlugoscMM: Double
        let wysokoscOdDnaMM: Double
        let etykietaKrotka: String
    }

    private struct ProwadnicaNaRysunku: Identifiable {
        let id = UUID()
        let yEkran: CGFloat
        let etykietaKrotka: String
    }

    private func daneProwadnicTabeli() -> [DaneProwadnicy] {
        card.efektywneSzuflady
            .filter(\.aktywna)
            .compactMap { drawer -> DaneProwadnicy? in
                let profile = KatalogRegulAkcesoriow.profil(id: drawer.profilID)
                let producent = profile?.producent ?? "—"
                let model = profile?.model ?? drawer.profilID
                return DaneProwadnicy(
                    producent: producent,
                    model: model,
                    dlugoscMM: drawer.nominalnaDlugoscMM,
                    wysokoscOdDnaMM: drawer.pozycjaDolnaYMM,
                    etykietaKrotka: "\(producent) \(model)"
                )
            }
    }

    private func prowadniceSzuflad(scale: CGFloat, boxRect: CGRect) -> [ProwadnicaNaRysunku] {
        card.efektywneSzuflady
            .filter(\.aktywna)
            .compactMap { drawer in
                let y = boxRect.maxY - drawer.pozycjaDolnaYMM * scale
                let profile = KatalogRegulAkcesoriow.profil(id: drawer.profilID)
                let etykieta = "\(profile?.producent ?? "-") \(profile?.model ?? "")"
                return ProwadnicaNaRysunku(yEkran: y, etykietaKrotka: etykieta)
            }
    }

    // MARK: - Helpers

    private func xClamped(_ value: Double) -> Double {
        min(max(value, 0), card.szerokoscMM)
    }

    private func yClamped(_ value: Double) -> Double {
        min(max(value, 0), card.wysokoscMM)
    }

    private func intMM(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
