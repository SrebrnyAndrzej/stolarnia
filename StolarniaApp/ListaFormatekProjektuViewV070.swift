import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI
import UIKit

struct ListaFormatekProjektuViewV070:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    let list: ListaFormatekProjektuV070

    @State private var exportURL: URL?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            ListaFormatekProjektuContentV070(
                list: list
            )
            .navigationTitle(
                "Formatki"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button(
                        "Zamknij"
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .primaryAction
                ) {
                    if let exportURL {
                        ShareLink(
                            item:
                                exportURL
                        ) {
                            Label(
                                "Eksport CSV",
                                systemImage:
                                    "square.and.arrow.up"
                            )
                        }
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
                        .disabled(
                            list.formatki
                                .isEmpty
                        )
                    }
                }
            }
            .alert(
                "Nie udało się przygotować CSV",
                isPresented:
                    Binding(
                        get: {
                            exportError
                                != nil
                        },
                        set: {
                            visible in

                            if !visible {
                                exportError =
                                    nil
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
            .task {
                guard !list
                    .formatki
                    .isEmpty
                else {
                    return
                }

                prepareExport()
            }
        }
    }

    private func prepareExport() {
        do {
            let travellerRepository =
                FormatkaTravellerRepositoryV078()

            exportURL =
                try ListaFormatekCSVV070
                    .makeFile(
                        for: list,
                        travellerProvider: {
                            travellerRepository
                                .podglad(dla: $0)
                        }
                    )
            exportError = nil
        } catch {
            exportURL = nil
            exportError =
                error.localizedDescription
        }
    }
}

struct ListaFormatekProjektuContentV070:
    View
{
    let list: ListaFormatekProjektuV070

    @State private var filtrKategorii:
        KategoriaFormatkiV070?
    @State private var filtrStatusuV078:
        StatusFormatkiV078?
    @State private var wyszukiwanie =
        ""
    @State private var sortowanie:
        ProdukcjaSortowanieV075? =
            .domyslne
    @State private var wybranaFormatkaV078:
        FormatkaProjektuV070?
    @StateObject private var travellerRepositoryV078 =
        FormatkaTravellerRepositoryV078()

    private var filtryAktywne:
        Bool
    {
        filtrKategorii != nil
            || filtrStatusuV078 != nil
            || !wyszukiwanie
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
    }

    private var widoczneFormatki:
        [FormatkaProjektuV070]
    {
        let phrase =
            wyszukiwanie
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return list
            .formatki
            .filter {
                item in

                let matchesCategory =
                    filtrKategorii == nil
                    || item.kategoria
                        == filtrKategorii
                let matchesStatus =
                    filtrStatusuV078 == nil
                    || travellerRepositoryV078
                    .podglad(dla: item)
                    .status
                    == filtrStatusuV078

                guard !phrase.isEmpty else {
                    return matchesCategory
                        && matchesStatus
                }

                let haystack = [
                    item.etykieta,
                    item.nazwaModulu,
                    item.kodKomponentu,
                    item.material.kod,
                    item.material.nazwa,
                    item.material.producent,
                    item.kategoria.nazwa
                ]
                .joined(
                    separator: " "
                )

                return matchesCategory
                    && matchesStatus
                    && haystack
                        .localizedCaseInsensitiveContains(
                            phrase
                        )
            }
            .sorted {
                (
                    sortowanie
                    ?? .domyslne
                )
                .porownaj(
                    $0,
                    $1
                )
            }
    }

    var body: some View {
        VStack(
            spacing: 0
        ) {
            ProdukcjaListaKontrolkiV075(
                tytul:
                    "Lista formatek",
                symbol:
                    "list.number",
                liczbaWidocznych:
                    widoczneFormatki
                        .count,
                liczbaWszystkich:
                    list.formatki
                        .count,
                wyszukiwanie:
                    $wyszukiwanie,
                podpowiedzWyszukiwania:
                    "Etykieta, moduł, kod lub materiał",
                kategoria:
                    $filtrKategorii,
                sortowanie:
                    $sortowanie,
                dodatkowyOpis:
                    opisPodsumowania
            )

            statusFilterBar

            Divider()

            if list.formatki
                .isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak formatek",
                    symbol:
                        "square.dashed",
                    opis:
                        "Dodaj do projektu moduły zawierające komponenty płytowe. Lista powstanie automatycznie."
                )
            } else if widoczneFormatki
                .isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak wyników",
                    symbol:
                        "line.3.horizontal.decrease.circle",
                    opis:
                        "Żadna formatka nie odpowiada aktywnemu wyszukiwaniu i filtrom.",
                    tytulAkcji:
                        "Wyczyść filtry",
                    akcja:
                        wyczyscFiltry
                )
            } else {
                listaWynikow
            }
        }
        .sheet(
            item:
                $wybranaFormatkaV078
        ) {
            item in

            KartaFormatkiProjektuV078(
                item: item,
                travellerRepository:
                    travellerRepositoryV078
            )
        }
    }

    private var listaWynikow:
        some View
    {
        List {
            ForEach(
                KategoriaFormatkiV070
                    .allCases
            ) {
                category in

                let items =
                    widoczneFormatki
                        .filter {
                            $0.kategoria
                                == category
                        }

                if !items.isEmpty {
                    Section {
                        ForEach(
                            items
                        ) {
                            itemRow(
                                $0
                            )
                        }
                    } header: {
                        HStack {
                            Label(
                                category.nazwa,
                                systemImage:
                                    category
                                        .systemImage
                            )

                            Spacer()

                            Text(
                                "\(items.count)"
                            )
                            .monospacedDigit()
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
            }
        }
        .listStyle(
            .insetGrouped
        )
    }

    private var opisPodsumowania:
        String
    {
        let gotowe =
            travellerRepositoryV078
            .liczbaStatusow(
                .gotowa,
                w: list.formatki
            )
        let problemy =
            list.formatki
            .filter {
                travellerRepositoryV078
                    .podglad(dla: $0)
                    .status
                    .blokujePrzekazanie
            }
            .count

        return "\(list.liczbaFormatek) elementów • \(area(list.powierzchniaM2)) m² • \(list.materialy.count) materiałów • gotowe \(gotowe) • problemy \(problemy)"
    }

    private func wyczyscFiltry() {
        wyszukiwanie = ""
        filtrKategorii = nil
        filtrStatusuV078 = nil
        sortowanie = .domyslne
    }

    private var statusFilterBar:
        some View
    {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(
                spacing: 8
            ) {
                statusFilterButton(
                    status: nil,
                    title: "Wszystkie",
                    symbol:
                        "line.3.horizontal.decrease.circle",
                    count:
                        list.formatki.count
                )

                ForEach(
                    StatusFormatkiV078
                        .allCases
                ) {
                    status in

                    let count =
                        travellerRepositoryV078
                        .liczbaStatusow(
                            status,
                            w: list.formatki
                        )

                    if count > 0
                        || filtrStatusuV078
                        == status {
                        statusFilterButton(
                            status: status,
                            title:
                                status.nazwa,
                            symbol:
                                status.symbol,
                            count: count
                        )
                    }
                }
            }
            .padding(
                .horizontal,
                16
            )
            .padding(
                .vertical,
                10
            )
        }
        .background(.bar)
    }

    private func statusFilterButton(
        status:
            StatusFormatkiV078?,
        title: String,
        symbol: String,
        count: Int
    ) -> some View {
        let selected =
            filtrStatusuV078 == status
        let tint =
            status?
            .tintV078
            ?? Color.secondary

        return Button {
            withAnimation(
                .easeInOut(
                    duration: 0.16
                )
            ) {
                filtrStatusuV078 =
                    status
            }
        } label: {
            HStack(
                spacing: 6
            ) {
                Image(
                    systemName:
                        symbol
                )

                Text(title)
                    .lineLimit(1)

                Text("\(count)")
                    .font(
                        .caption2
                            .weight(.bold)
                            .monospacedDigit()
                    )
                    .padding(
                        .horizontal,
                        6
                    )
                    .padding(
                        .vertical,
                        2
                    )
                    .background(
                        selected
                        ? Color.black
                            .opacity(0.12)
                        : tint.opacity(0.16),
                        in: Capsule()
                    )
            }
            .font(
                .caption
                    .weight(.semibold)
            )
            .foregroundStyle(
                selected
                ? StolarniaPalette
                    .drawingInk
                : tint
            )
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                7
            )
            .background(
                selected
                ? StolarniaPalette
                    .accent
                : (
                    status?
                    .fillV078
                    ?? Color.secondary
                        .opacity(0.12)
                ),
                in:
                    Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        tint.opacity(
                            selected
                            ? 0.20
                            : 0.28
                        ),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(title), \(count) formatek"
        )
    }

    private func itemRow(
        _ item: FormatkaProjektuV070
    ) -> some View {
        let traveller =
            travellerRepositoryV078
            .podglad(dla: item)

        return HStack(
            alignment: .top,
            spacing: 12
        ) {
            Image(
                systemName:
                    item.kategoria
                        .systemImage
            )
            .font(.title3)
            .foregroundStyle(
                .tint
            )
            .frame(
                width: 28,
                height: 28
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack(
                    alignment:
                        .firstTextBaseline
                ) {
                    Text(
                        item.etykieta
                    )
                    .font(
                        .headline
                            .monospaced()
                    )

                    if item.wspoldzielona {
                        Text(
                            "WSPÓLNA"
                        )
                        .font(
                            .caption2
                                .weight(
                                    .bold
                                )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Text(
                    "\(item.nazwaModulu) • \(item.kodKomponentu)"
                )
                .font(
                    .subheadline
                )

                Text(
                    item.opisWymiaru
                )
                .font(
                    .subheadline
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )

                Text(
                    item.material.opis
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Label(
                    item.kierunekDekoru
                        .nazwa,
                    systemImage:
                        item.kierunekDekoru
                            == .dowolny
                        ? "arrow.triangle.2.circlepath"
                        : "arrow.up.and.down"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 7
            ) {
                FormatkaStatusChipV078(
                    status: traveller.status,
                    compact: true
                )

                Text(
                    "\(area(item.powierzchniaM2)) m²"
                )
                .font(
                    .caption
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Image(
                systemName:
                    "chevron.right"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(
            .vertical,
            4
        )
        .contentShape(Rectangle())
        .onTapGesture {
            wybranaFormatkaV078 =
                item
        }
        .accessibilityElement(
            children:
                .combine
        )
    }

    private func area(
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
                .precision(
                    .fractionLength(
                        0...3
                    )
                )
        )
    }
}

private struct KartaFormatkiProjektuV078:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    let item:
        FormatkaProjektuV070
    @ObservedObject var travellerRepository:
        FormatkaTravellerRepositoryV078

    @State private var opisZdarzeniaV078 =
        ""
    @State private var notatkaV078 =
        ""

    private var traveller:
        TravellerFormatkiV078
    {
        travellerRepository
            .podglad(dla: item)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    header
                    qrCard
                    statusCard
                    detailsCard
                }
                .padding(20)
                .frame(
                    maxWidth: 720,
                    alignment: .leading
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                )
            }
            .background(
                Color(
                    uiColor:
                        .systemGroupedBackground
                )
            )
            .navigationTitle(
                "Karta formatki"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                notatkaV078 =
                    traveller.notatka
            }
        }
    }

    private var header:
        some View
    {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    item
                    .kategoria
                    .systemImage
            )
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(
                width: 56,
                height: 56
            )
            .background(
                Color.accentColor.opacity(0.14),
                in:
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(item.etykieta)
                    .font(.title.bold().monospaced())

                Text(item.identyfikatorProdukcyjnyV078)
                    .font(.headline.monospaced())
                    .foregroundStyle(.secondary)

                Text(item.nazwaModulu)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            FormatkaStatusChipV078(
                status:
                    traveller.status,
                compact: false
            )
        }
    }

    private var qrCard:
        some View
    {
        GroupBox {
            HStack(
                alignment: .center,
                spacing: 18
            ) {
                FormatkaQRCodeV078(
                    payload:
                        item.qrPayloadV078
                )
                .frame(
                    width: 170,
                    height: 170
                )

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Text(
                        "Skan prowadzi do tej formatki"
                    )
                    .font(.headline)

                    Text(
                        "Payload zawiera stabilne ID, etykietę, moduł, komponent, materiał i wymiar. Ten sam payload trafia do CSV."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    Text(item.qrPayloadV078)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
        } label: {
            Label(
                "QR produkcyjny",
                systemImage:
                    "qrcode"
            )
        }
    }

    private var statusCard:
        some View
    {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                HStack(
                    alignment: .top,
                    spacing: 12
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {
                        Text(
                            traveller.status.nazwa
                        )
                        .font(.headline)

                        Text(
                            traveller.status.opis
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }

                    Spacer()

                    if traveller.liczbaRecut > 0 {
                        Label(
                            "\(traveller.liczbaRecut)x recut",
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                        .font(
                            .caption
                                .weight(.semibold)
                        )
                        .foregroundStyle(
                            Color.orange
                        )
                        .padding(
                            .horizontal,
                            9
                        )
                        .padding(
                            .vertical,
                            5
                        )
                        .background(
                            Color.orange
                                .opacity(0.14),
                            in: Capsule()
                        )
                    }
                }

                statusButtons

                Divider()

                TextField(
                    "Notatka operatora albo opis problemu",
                    text:
                        $opisZdarzeniaV078,
                    axis:
                        .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

                HStack(
                    spacing: 10
                ) {
                    Button {
                        notatkaV078 =
                            opisZdarzeniaV078
                        travellerRepository
                            .zapiszNotatke(
                                dla: item,
                                notatka:
                                    opisZdarzeniaV078
                            )
                        opisZdarzeniaV078 = ""
                    } label: {
                        Label(
                            "Zapisz notatkę",
                            systemImage:
                                "text.badge.checkmark"
                        )
                    }

                    Button(
                        role: .destructive
                    ) {
                        travellerRepository
                            .zglosDefekt(
                                dla: item,
                                opis:
                                    opisZdarzeniaV078
                            )
                        opisZdarzeniaV078 = ""
                    } label: {
                        Label(
                            "Defekt",
                            systemImage:
                                "exclamationmark.triangle"
                        )
                    }

                    Button {
                        travellerRepository
                            .zlecRecut(
                                dla: item,
                                opis:
                                    opisZdarzeniaV078
                            )
                        opisZdarzeniaV078 = ""
                    } label: {
                        Label(
                            "Recut",
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                    }
                }
                .buttonStyle(.bordered)

                if !traveller.notatka.isEmpty {
                    Label(
                        traveller.notatka,
                        systemImage:
                            "note.text"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !traveller.opisProblemu.isEmpty {
                    Label(
                        traveller.opisProblemu,
                        systemImage:
                            "wrench.and.screwdriver"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        traveller.status
                            .blokujePrzekazanie
                        ? Color.orange
                        : .secondary
                    )
                }

                historiaStatusow
            }
        } label: {
            Label(
                "Status produkcji",
                systemImage:
                    "timeline.selection"
            )
        }
    }

    private var statusButtons:
        some View
    {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: 122
                    ),
                    spacing: 10
                )
            ],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(
                StatusFormatkiV078
                    .szybkaSciezka
            ) {
                status in

                statusButton(
                    status
                )
            }
        }
    }

    private var historiaStatusow:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Historia")
                .font(
                    .caption
                        .weight(.semibold)
                )
                .foregroundStyle(.secondary)

            ForEach(
                Array(
                    traveller
                        .historia
                        .prefix(6)
                )
            ) {
                event in

                HStack(
                    alignment: .top,
                    spacing: 9
                ) {
                    Image(
                        systemName:
                            event.status.symbol
                    )
                    .foregroundStyle(
                        event.status.tintV078
                    )
                    .frame(
                        width: 18
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(
                            "\(event.typ.nazwa) • \(event.status.nazwa)"
                        )
                        .font(
                            .caption
                                .weight(.semibold)
                        )

                        Text(
                            event.opis
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }

                    Spacer()

                    Text(
                        Self.eventFormatterV078
                            .string(from: event.data)
                    )
                    .font(
                        .caption2
                            .monospacedDigit()
                    )
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 2)
    }

    private func statusButton(
        _ status:
            StatusFormatkiV078
    ) -> some View {
        let selected =
            traveller.status == status

        return Button {
            travellerRepository
                .ustawStatus(
                    status,
                    dla: item,
                    opis:
                        opisZdarzeniaV078
                )
            opisZdarzeniaV078 = ""
        } label: {
            Label(
                status.nazwa,
                systemImage:
                    status.symbol
            )
            .font(
                .caption
                    .weight(.semibold)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(
                maxWidth: .infinity,
                minHeight: 36
            )
            .padding(
                .horizontal,
                9
            )
            .foregroundStyle(
                selected
                ? StolarniaPalette
                    .drawingInk
                : status.tintV078
            )
            .background(
                selected
                ? StolarniaPalette
                    .accent
                : status.fillV078,
                in:
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .stroke(
                    status.tintV078
                        .opacity(
                            selected
                            ? 0.18
                            : 0.28
                        ),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
    }

    private static let eventFormatterV078:
        DateFormatter =
    {
        let formatter =
            DateFormatter()
        formatter.locale =
            Locale(
                identifier:
                    "pl_PL"
            )
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var detailsCard:
        some View
    {
        GroupBox {
            VStack(spacing: 0) {
                detailRow(
                    "Kategoria",
                    item.kategoria.nazwa
                )
                detailRow(
                    "Kod komponentu",
                    item.kodKomponentu
                )
                detailRow(
                    "Wymiar",
                    item.opisWymiaru
                )
                detailRow(
                    "Powierzchnia",
                    "\(area(item.powierzchniaM2)) m²"
                )
                detailRow(
                    "Materiał",
                    item.material.opis
                )
                detailRow(
                    "Kierunek dekoru",
                    item.kierunekDekoru.nazwa
                )
                detailRow(
                    "Współdzielona",
                    item.wspoldzielona
                        ? "Tak"
                        : "Nie",
                    showDivider:
                        false
                )
            }
        } label: {
            Label(
                "Dane elementu",
                systemImage:
                    "doc.text.magnifyingglass"
            )
        }
    }

    private func detailRow(
        _ title: String,
        _ value: String,
        showDivider: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: 12
            ) {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            .font(.subheadline)
            .padding(.vertical, 10)

            if showDivider {
                Divider()
            }
        }
    }

    private func area(
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
                .precision(
                    .fractionLength(0...3)
                )
        )
    }
}

private struct FormatkaStatusChipV078:
    View
{
    let status:
        StatusFormatkiV078
    let compact: Bool

    var body: some View {
        Label(
            status.nazwa,
            systemImage:
                status.symbol
        )
        .font(
            compact
            ? .caption2
                .weight(.semibold)
            : .caption
                .weight(.semibold)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .foregroundStyle(
            status.tintV078
        )
        .padding(
            .horizontal,
            compact ? 7 : 9
        )
        .padding(
            .vertical,
            compact ? 4 : 6
        )
        .background(
            status.fillV078,
            in:
                Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    status.tintV078
                        .opacity(0.28),
                    lineWidth: 1
                )
        }
        .accessibilityLabel(
            "Status formatki: \(status.nazwa)"
        )
    }
}

private extension StatusFormatkiV078 {
    var tintV078:
        Color
    {
        switch self {
        case .doCiecia:
            return StolarniaPalette
                .sidebarSecondary
        case .wycieta:
            return StolarniaPalette
                .accent
        case .oklejanie,
             .oklejona:
            return Color.cyan
        case .cnc,
             .poCNC:
            return Color.indigo
        case .wPaczce:
            return Color.blue
        case .gotowa:
            return Color.green
        case .defekt:
            return Color.red
        case .recut:
            return Color.orange
        }
    }

    var fillV078:
        Color
    {
        tintV078
            .opacity(
                blokujePrzekazanie
                ? 0.18
                : 0.14
            )
    }
}

private struct FormatkaQRCodeV078:
    View
{
    let payload: String

    var body: some View {
        if let image =
            QRCodeGeneratorV078
                .image(
                    from: payload
                ) {
            Image(
                uiImage: image
            )
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(12)
            .background(
                Color.white,
                in:
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
            )
        } else {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .fill(
                Color.secondary
                    .opacity(0.12)
            )
            .overlay {
                Image(
                    systemName:
                        "qrcode"
                )
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private enum QRCodeGeneratorV078 {
    static func image(
        from payload: String
    ) -> UIImage? {
        let data =
            Data(
                payload
                    .utf8
            )
        let filter =
            CIFilter
                .qrCodeGenerator()
        filter.message =
            data
        filter.correctionLevel =
            "M"

        guard let output =
            filter.outputImage
        else {
            return nil
        }

        let scaled =
            output.transformed(
                by:
                    CGAffineTransform(
                        scaleX: 10,
                        y: 10
                    )
            )
        let context =
            CIContext()

        guard let cgImage =
            context.createCGImage(
                scaled,
                from:
                    scaled.extent
            )
        else {
            return nil
        }

        return UIImage(
            cgImage: cgImage
        )
    }
}
