import SwiftUI

struct OkleinowanieProjektuViewV072:
    View
{
    let lista:
        ListaFormatekProjektuV070

    @State private var ustawienia:
        UstawieniaOkleinowaniaV072
    @State private var pozycje:
        [PozycjaOkleinowaniaV072]
    @State private var filtrKategorii:
        KategoriaFormatkiV070?
    @State private var wyszukiwanie =
        ""
    @State private var sortowanie:
        ProdukcjaSortowanieV075? =
            .domyslne
    @State private var exportURL: URL?
    @State private var exportError: String?

    init(
        lista:
            ListaFormatekProjektuV070
    ) {
        self.lista = lista
        _ustawienia = State(
            initialValue:
                .standard
        )
        _pozycje = State(
            initialValue:
                OkleinowanieEngineV072
                    .automatycznePozycje(
                        dla: lista
                    )
        )
        _filtrKategorii = State(
            initialValue: nil
        )
    }

    private var raport:
        RaportOkleinowaniaV072
    {
        OkleinowanieEngineV072
            .raport(
                nazwaProjektu:
                    lista.nazwaProjektu,
                pozycje:
                    pozycje,
                ustawienia:
                    ustawienia
            )
    }

    private var widoczneIndeksy:
        [Int]
    {
        let phrase =
            wyszukiwanie
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return pozycje
            .indices
            .filter {
                index in

                let item =
                    pozycje[index]
                        .formatka
                let categoryOK =
                    filtrKategorii == nil
                    || item.kategoria
                        == filtrKategorii

                guard !phrase.isEmpty else {
                    return categoryOK
                }

                let haystack = [
                    item.etykieta,
                    item.nazwaModulu,
                    item.kodKomponentu,
                    item.material.opis,
                    item.kategoria.nazwa
                ]
                .joined(
                    separator: " "
                )

                return categoryOK
                    && haystack
                        .localizedCaseInsensitiveContains(
                            phrase
                        )
            }
            .sorted {
                lhs,
                rhs in

                (
                    sortowanie
                    ?? .domyslne
                )
                .porownaj(
                    pozycje[lhs]
                        .formatka,
                    pozycje[rhs]
                        .formatka
                )
            }
    }

    var body: some View {
        VStack(
            spacing: 0
        ) {
            ProdukcjaListaKontrolkiV075(
                tytul:
                    "Pozycje okleinowania",
                symbol:
                    "rectangle.and.hand.point.up.left",
                liczbaWidocznych:
                    widoczneIndeksy
                        .count,
                liczbaWszystkich:
                    pozycje.count,
                wyszukiwanie:
                    $wyszukiwanie,
                podpowiedzWyszukiwania:
                    "Etykieta, moduł, kod lub materiał",
                kategoria:
                    $filtrKategorii,
                sortowanie:
                    $sortowanie,
                dodatkowyOpis:
                    "Dotknij krawędzi formatki, aby przełączyć rodzaj obrzeża."
            )

            Divider()

            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                    ustawieniaCard
                    podsumowanieCard
                    zapotrzebowanieCard

                    if pozycje.isEmpty {
                        ProdukcjaPustyStanV075(
                            tytul:
                                "Brak formatek",
                            symbol:
                                "rectangle.on.rectangle.slash",
                            opis:
                                "Dodaj komponenty płytowe do projektu. Pozycje okleinowania zostaną utworzone automatycznie."
                        )
                    } else if widoczneIndeksy
                        .isEmpty {
                        ProdukcjaPustyStanV075(
                            tytul:
                                "Brak wyników",
                            symbol:
                                "line.3.horizontal.decrease.circle",
                            opis:
                                "Żadna pozycja okleinowania nie odpowiada aktywnemu wyszukiwaniu i filtrom.",
                            tytulAkcji:
                                "Wyczyść filtry",
                            akcja:
                                wyczyscFiltry
                        )
                    } else {
                        ForEach(
                            widoczneIndeksy,
                            id: \.self
                        ) {
                            index in

                            FormatkaOkleinowaniaCardV072(
                                pozycja:
                                    pozycje[index],
                                onCycle: {
                                    edge in

                                    przelacz(
                                        edge,
                                        w: index
                                    )
                                },
                                onSet: {
                                    edge,
                                    type in

                                    ustaw(
                                        type,
                                        dla: edge,
                                        w: index
                                    )
                                }
                            )
                        }
                    }
                }
                .padding(18)
            }
        }
        .onChange(
            of: ustawienia
        ) {
            _,
            _ in

            exportURL = nil
        }
        .alert(
            "Nie udało się przygotować CSV",
            isPresented:
                Binding(
                    get: {
                        exportError != nil
                    },
                    set: {
                        visible in

                        if !visible {
                            exportError = nil
                        }
                    }
                )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {}
        } message: {
            Text(
                exportError ?? ""
            )
        }
    }

    private var ustawieniaCard:
        some View
    {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                ViewThatFits(
                    in: .horizontal
                ) {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 16
                    ) {
                        numberField(
                            title:
                                "Naddatek na krawędź",
                            suffix:
                                "mm",
                            value:
                                $ustawienia
                                    .naddatekNaKrawedzMM
                        )

                        numberField(
                            title:
                                "Zapas zakupowy",
                            suffix:
                                "%",
                            value:
                                $ustawienia
                                    .zapasProcent
                        )

                        Spacer(
                            minLength: 8
                        )

                        przyciskiUstawien
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        HStack(
                            alignment:
                                .firstTextBaseline,
                            spacing: 16
                        ) {
                            numberField(
                                title:
                                    "Naddatek na krawędź",
                                suffix:
                                    "mm",
                                value:
                                    $ustawienia
                                        .naddatekNaKrawedzMM
                            )

                            numberField(
                                title:
                                    "Zapas zakupowy",
                                suffix:
                                    "%",
                                value:
                                    $ustawienia
                                        .zapasProcent
                            )
                        }

                        HStack(
                            spacing: 10
                        ) {
                            przyciskiUstawien
                        }
                    }
                }

                Divider()

                HStack {
                    Label(
                        "Brak → ABS 0,8 mm → ABS 2,0 mm",
                        systemImage:
                            "hand.tap"
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    if let exportURL {
                        ShareLink(
                            item: exportURL
                        ) {
                            Label(
                                "Udostępnij CSV",
                                systemImage:
                                    "square.and.arrow.up"
                            )
                        }
                        .buttonStyle(
                            .bordered
                        )
                    } else {
                        Button {
                            prepareExport()
                        } label: {
                            Label(
                                "Przygotuj CSV",
                                systemImage:
                                    "tablecells"
                            )
                        }
                        .buttonStyle(
                            .bordered
                        )
                        .disabled(
                            !ustawienia.poprawne
                            || raport
                                .liczbaKrawedzi
                                == 0
                        )
                    }
                }

                if !ustawienia
                    .poprawne {
                    Label(
                        "Naddatek musi być nieujemny, a zapas musi mieścić się w zakresie 0–100%.",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .orange
                    )
                }
            }
        } label: {
            Label(
                "Ustawienia okleinowania",
                systemImage:
                    "slider.horizontal.3"
            )
        }
    }

    @ViewBuilder
    private var przyciskiUstawien:
        some View
    {
        Button {
            zastosujAutomatyczne()
        } label: {
            Label(
                "Reguły automatyczne",
                systemImage:
                    "wand.and.stars"
            )
        }
        .buttonStyle(
            .borderedProminent
        )

        Button(
            role: .destructive
        ) {
            wyczyscWszystkie()
        } label: {
            Label(
                "Wyczyść obrzeża",
                systemImage:
                    "eraser"
            )
        }
        .buttonStyle(
            .bordered
        )
    }

    private func numberField(
        title: String,
        suffix: String,
        value: Binding<Double>
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            HStack(
                spacing: 5
            ) {
                TextField(
                    suffix,
                    value: value,
                    format:
                        .number
                            .precision(
                                .fractionLength(
                                    0...1
                                )
                            )
                )
                .textFieldStyle(
                    .roundedBorder
                )
                .keyboardType(
                    .decimalPad
                )

                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }
            .frame(
                width: 145
            )
        }
    }

    private var podsumowanieCard:
        some View
    {
        GroupBox {
            ViewThatFits(
                in: .horizontal
            ) {
                HStack(
                    spacing: 28
                ) {
                    metrykiPodsumowania
                    Spacer()
                }

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    metrykiPodsumowania
                }
            }
        } label: {
            Label(
                "Podsumowanie",
                systemImage:
                    "sum"
            )
        }
    }

    @ViewBuilder
    private var metrykiPodsumowania:
        some View
    {
        metric(
            "Formatki do oklejenia",
            "\(raport.liczbaFormatekDoOklejenia) / \(raport.liczbaFormatek)"
        )
        metric(
            "Krawędzie",
            "\(raport.liczbaKrawedzi)"
        )
        metric(
            "Długość netto",
            formatM(
                raport.dlugoscNettoM
            )
        )
        metric(
            "Do zakupu",
            formatM(
                raport.dlugoscZakupuM
            )
        )
    }

    private func metric(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            Text(value)
                .font(
                    .title3
                        .weight(
                            .semibold
                        )
                        .monospacedDigit()
                )
        }
        .frame(
            minWidth: 110,
            alignment: .leading
        )
    }

    private var zapotrzebowanieCard:
        some View
    {
        GroupBox {
            if raport
                .zapotrzebowanie
                .isEmpty {
                Text(
                    "Brak obrzeży do zamówienia."
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
            } else {
                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {
                    ForEach(
                        raport
                            .zapotrzebowanie
                    ) {
                        item in

                        HStack(
                            alignment:
                                .firstTextBaseline,
                            spacing: 12
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(
                                    item
                                        .specyfikacja
                                        .rodzaj
                                        .nazwa
                                )
                                .font(.headline)

                                Text(
                                    item
                                        .specyfikacja
                                        .opis
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                                .lineLimit(2)
                            }

                            Spacer()

                            Text(
                                "\(item.liczbaKrawedzi) kraw."
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )

                            Text(
                                formatM(
                                    item
                                        .dlugoscZakupuM
                                )
                            )
                            .font(
                                .headline
                                    .monospacedDigit()
                            )
                            .frame(
                                minWidth: 86,
                                alignment:
                                    .trailing
                            )
                        }
                        .padding(
                            .vertical,
                            9
                        )

                        if item.id
                            != raport
                                .zapotrzebowanie
                                .last?
                                .id {
                            Divider()
                        }
                    }
                }
            }
        } label: {
            Label(
                "Zapotrzebowanie na obrzeża",
                systemImage:
                    "shippingbox"
            )
        }
    }

    private func wyczyscFiltry() {
        wyszukiwanie = ""
        filtrKategorii = nil
        sortowanie = .domyslne
    }

    private func przelacz(
        _ edge: KrawedzFormatkiV072,
        w index: Int
    ) {
        guard pozycje.indices
            .contains(index)
        else {
            return
        }

        pozycje[index]
            .przelacz(edge)
        exportURL = nil
    }

    private func ustaw(
        _ type: RodzajObrzezaV072,
        dla edge:
            KrawedzFormatkiV072,
        w index: Int
    ) {
        guard pozycje.indices
            .contains(index)
        else {
            return
        }

        pozycje[index]
            .ustaw(
                type,
                dla: edge
            )
        exportURL = nil
    }

    private func zastosujAutomatyczne() {
        pozycje =
            OkleinowanieEngineV072
                .automatycznePozycje(
                    dla: lista
                )
        exportURL = nil
    }

    private func wyczyscWszystkie() {
        pozycje =
            OkleinowanieEngineV072
                .wyczysc(
                    pozycje
                )
        exportURL = nil
    }

    private func prepareExport() {
        do {
            exportURL =
                try OkleinowanieCSVV072
                    .makeFile(
                        for: raport
                    )
            exportError = nil
        } catch {
            exportURL = nil
            exportError =
                error.localizedDescription
        }
    }

    private func formatM(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(
                    Locale(
                        identifier:
                            "pl_PL"
                    )
                )
                .grouping(
                    .never
                )
                .precision(
                    .fractionLength(
                        2
                    )
                )
        ) + " m"
    }
}

private struct FormatkaOkleinowaniaCardV072: View {
    let pozycja: PozycjaOkleinowaniaV072
    let onCycle: (KrawedzFormatkiV072) -> Void
    let onSet: (KrawedzFormatkiV072, RodzajObrzezaV072) -> Void

    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(pozycja.formatka.etykieta)
                            .font(.headline.monospaced())
                        Text(pozycja.formatka.kategoria.nazwa)
                            .font(.caption)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }

                    Text(pozycja.formatka.nazwaModulu)
                        .font(.title3.weight(.semibold))
                    Text(pozycja.formatka.rolaKomponentu.nazwaProdukcyjnaV072)
                        .font(.subheadline)
                    Text(pozycja.formatka.opisWymiaru)
                        .font(.subheadline.monospacedDigit())
                    Text(pozycja.formatka.material.opis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Label(
                        "\(pozycja.liczbaOklejanychKrawedzi) krawędzi • \(formatMM(pozycja.dlugoscNettoMM))",
                        systemImage: "ruler"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                KrawedzieFormatkiEditorV072(
                    pozycja: pozycja,
                    onCycle: onCycle,
                    onSet: onSet
                )
                .frame(width: 310)
            }
            .padding(.vertical, 4)
        }
    }

    private func formatMM(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...1))
        ) + " mm netto"
    }
}

private struct KrawedzieFormatkiEditorV072: View {
    let pozycja: PozycjaOkleinowaniaV072
    let onCycle: (KrawedzFormatkiV072) -> Void
    let onSet: (KrawedzFormatkiV072, RodzajObrzezaV072) -> Void

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 70)
                edgeButton(.dlugaA)
                Color.clear.frame(width: 70)
            }
            GridRow {
                edgeButton(.krotkaA)
                panel
                edgeButton(.krotkaB)
            }
            GridRow {
                Color.clear.frame(width: 70)
                edgeButton(.dlugaB)
                Color.clear.frame(width: 70)
            }
        }
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 126, height: 74)
            .overlay {
                VStack(spacing: 3) {
                    Text(pozycja.formatka.etykieta)
                        .font(.caption.weight(.semibold).monospaced())
                    Text(
                        "\(formatMM(pozycja.formatka.dlugoscMM)) × \(formatMM(pozycja.formatka.szerokoscMM))"
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
    }

    private func edgeButton(_ edge: KrawedzFormatkiV072) -> some View {
        let type = pozycja.rodzaj(dla: edge)

        return Button {
            onCycle(edge)
        } label: {
            VStack(spacing: 2) {
                Text(edge.skrot)
                    .font(.caption2)
                Text(type.skrot)
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .frame(width: 62, height: 36)
        }
        .buttonStyle(.bordered)
        .tint(type == .brak ? Color.secondary : Color.accentColor)
        .contextMenu {
            ForEach(RodzajObrzezaV072.allCases) { option in
                Button {
                    onSet(edge, option)
                } label: {
                    if option == type {
                        Label(option.nazwa, systemImage: "checkmark")
                    } else {
                        Text(option.nazwa)
                    }
                }
            }
        }
        .accessibilityLabel("\(edge.nazwa), \(type.nazwa)")
        .accessibilityHint("Dotknij, aby przełączyć rodzaj obrzeża.")
    }

    private func formatMM(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0))
        )
    }
}
