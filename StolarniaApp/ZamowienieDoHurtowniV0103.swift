import SwiftUI

/// Jedna lista do hurtowni: płyty i okucia obok siebie.
///
/// Etap „Zamówienie" istniał dotąd tylko jako zakładka `Zakup płyt`, która —
/// zgodnie z nazwą — pokazuje **same arkusze**. Okucia szły osobną drogą,
/// przez wycenę i listę zakupową, więc żeby zamówić komplet, trzeba było
/// odwiedzić dwa różne miejsca i ręcznie je zszyć.
///
/// Ten ekran nie liczy niczego od nowa. Bierze arkusze z raportu rozkroju
/// i okucia z podsumowania wyceny — dwa źródła, które już istnieją — i pokazuje
/// je jako jedno zamówienie.
///
/// **Prowadnice mają tu wymiar.** „GTV • AXIS PRO • H120" mówi, jaki system,
/// ale nie mówi, jaką sztukę wysłać: prowadnica 450 i 500 to dwa różne indeksy
/// w hurtowni. Długość nominalna jest częścią nazwy pozycji.
struct ZamowienieDoHurtowniV0103: View {

    let nazwaPomieszczenia: String
    let zapotrzebowaniePlyt: [ZapotrzebowaniePlytyV071]
    let podsumowanieWyceny: PodsumowanieWariantuWyceny?

    /// Kategorie, które faktycznie się zamawia u dostawcy okuć.
    ///
    /// Robocizna, montaż i transport są kosztami wyceny, nie pozycjami
    /// zamówienia — gdyby tu weszły, lista przestałaby być listą do wysłania.
    private static let kategorieZamawiane: Set<KategoriaKosztuWyceny> = [
        .okucia, .akcesoria, .oswietlenie
    ]

    private var pozycjeOkuc: [PozycjaKosztowaWyceny] {
        (podsumowanieWyceny?.pozycje ?? [])
            .filter { Self.kategorieZamawiane.contains($0.kategoria) && $0.ilosc > 0 }
            .sorted { $0.nazwa.localizedCompare($1.nazwa) == .orderedAscending }
    }

    private var brakiCen: Int {
        pozycjeOkuc.filter(\.jestBledemWyceny).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                naglowekZamowienia
                sekcjaPlyt
                sekcjaOkuc
            }
            .padding(20)
        }
        .stolarniaScreenSurface(.detail)
        .stolarniaReadableInterface()
    }

    // MARK: - Nagłówek

    private var naglowekZamowienia: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(nazwaPomieszczenia)
                .font(.title2.bold())
            Text(
                "\(zapotrzebowaniePlyt.reduce(0) { $0 + $1.liczbaArkuszy }) arkuszy · "
                + "\(pozycjeOkuc.count) pozycji okuciowych"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if brakiCen > 0 {
                Label(
                    "\(brakiCen) pozycji okuciowych bez ceny — zamówienie da się złożyć, "
                    + "ale wartość jest szacunkiem",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Płyty

    @ViewBuilder
    private var sekcjaPlyt: some View {
        sekcja("Płyty", systemImage: "square.grid.3x3") {
            if zapotrzebowaniePlyt.isEmpty {
                pustaSekcja("Brak arkuszy — dodaj moduły do pomieszczenia.")
            } else {
                ForEach(zapotrzebowaniePlyt) { pozycja in
                    wiersz(
                        tytul: pozycja.grupa.opis,
                        podtytul: "format \(pozycja.formatArkusza)",
                        ilosc: "\(pozycja.liczbaArkuszy) ark.",
                        // Wykorzystanie arkusza jest tu istotne: przy niskim
                        // opłaca się dobrać zamówienie albo zmienić rozkrój,
                        // zanim płyta pojedzie na piłę.
                        uwaga: String(
                            format: "wykorzystanie %.0f%%",
                            pozycja.wykorzystanieProcent
                        ),
                        alarm: false
                    )
                }
            }
        }
    }

    // MARK: - Okucia

    @ViewBuilder
    private var sekcjaOkuc: some View {
        sekcja("Okucia", systemImage: "wrench.and.screwdriver") {
            if pozycjeOkuc.isEmpty {
                pustaSekcja(
                    "Brak okuć w wycenie. Sprawdź, czy moduły mają przypisane "
                    + "profile prowadnic i zawiasów w karcie technicznej."
                )
            } else {
                ForEach(pozycjeOkuc) { pozycja in
                    wiersz(
                        tytul: pozycja.nazwa,
                        podtytul: pozycja.uwagi,
                        ilosc: "\(pozycja.ilosc.formatted()) \(pozycja.jednostka)",
                        uwaga: pozycja.jestBledemWyceny ? "brak ceny w cenniku" : nil,
                        alarm: pozycja.jestBledemWyceny
                    )
                }
            }
        }
    }

    // MARK: - Budulec

    @ViewBuilder
    private func sekcja<Content: View>(
        _ tytul: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tytul, systemImage: systemImage)
                .font(.title3.bold())
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private func wiersz(
        tytul: String,
        podtytul: String,
        ilosc: String,
        uwaga: String?,
        alarm: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tytul)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    if !podtytul.isEmpty {
                        Text(podtytul)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let uwaga {
                        // Kolor nie niesie znaczenia sam — ikona i słowo też.
                        Label(
                            uwaga,
                            systemImage: alarm
                                ? "exclamationmark.triangle.fill"
                                : "chart.bar"
                        )
                        .font(.caption2)
                        .foregroundStyle(alarm ? Color.orange : Color.secondary)
                    }
                }

                Spacer(minLength: 8)

                Text(ilosc)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)

            Divider().padding(.leading, 14)
        }
    }

    private func pustaSekcja(_ tekst: String) -> some View {
        Text(tekst)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }
}
