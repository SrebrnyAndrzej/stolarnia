import Combine
import SwiftUI

private enum WycenaWariantowaSheet:
    String,
    Identifiable
{
    case offerArchive
    case customerOffer
    case purchaseList
    case editor
    case bom

    var id: String { rawValue }
}

struct WycenaWariantowaView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var materialyRepository =
        BazaMaterialowRepository()

    @StateObject private var okuciaRepository =
        BazaOkucRepository()

    @State private var projekt:
        ProjektWyceny?
    @State private var selectedVariant:
        WariantWyceny = .standard
    @State private var activeSheet:
        WycenaWariantowaSheet?
    /// nil = użyj wartości z ustawień stolarni
    @State private var vatOverrideProcent:
        Double? = nil

    init(
        projekt:
            ProjektWyceny? = nil
    ) {
        _projekt = State(
            initialValue:
                projekt
        )
    }

    private var ustawienia:
        UstawieniaStolarni
    {
        UstawieniaStolarniRepository
            .aktualne()
    }

    /// Ustawienia z opcjonalnym nadpisaniem stawki VAT
    private var efektywneUstawienia:
        UstawieniaStolarni
    {
        guard let vatOverrideProcent else {
            return ustawienia
        }
        var u = ustawienia
        u.finanse.vatProcent =
            vatOverrideProcent
        return u
    }

    private var efektywnyVAT: Double {
        vatOverrideProcent
            ?? ustawienia.finanse.vatProcent
    }

    private var wyceny:
        [PodsumowanieWariantuWyceny]
    {
        guard let projekt else {
            return []
        }

        return SilnikWycenyWariantowej
            .oblicz(
                projekt: projekt,
                ustawienia:
                    efektywneUstawienia,
                materialy:
                    materialyRepository
                        .materialy,
                okucia:
                    okuciaRepository
                        .okucia
            )
    }

    private var selectedSummary:
        PodsumowanieWariantuWyceny?
    {
        wyceny.first {
            $0.wariant
                == selectedVariant
        }
    }

    private var projektBinding:
        Binding<ProjektWyceny>?
    {
        guard var current = projekt else {
            return nil
        }

        return Binding(
            get: {
                // projekt is non-nil: guard above ensured it;
                // re-read to pick up any changes since binding was created.
                self.projekt ?? current
            },
            set: { newValue in
                current = newValue
                self.projekt = newValue
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(
                WariantWyceny.allCases,
                id: \.self
            ) { wariant in
                Button {
                    selectedVariant = wariant
                } label: {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        HStack {
                            Text(wariant.nazwa)
                                .font(.headline)

                            Spacer()

                            if let summary =
                                wyceny.first(
                                    where: {
                                        $0.wariant
                                            == wariant
                                    }
                                ) {
                                Text(
                                    summary
                                        .cenaBrutto
                                        .formatted(
                                            .currency(
                                                code: "PLN"
                                            )
                                        )
                                )
                                .font(
                                    .headline
                                        .monospacedDigit()
                                )
                            }
                        }

                        Text(wariant.opis)
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                    }
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedVariant
                        == wariant
                    ? Color.accentColor
                        .opacity(0.14)
                    : Color.clear
                )
            }
            .navigationTitle(
                "Warianty wyceny"
            )
        } detail: {
            if let projekt,
               let summary =
                selectedSummary {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 18
                    ) {
                        header(
                            summary,
                            projekt: projekt
                        )
                        summaryCards(summary)
                        costTable(summary)
                        hardwareDatabaseCard
                        offerArchiveCard
                        customerOfferCard
                        purchaseListCard
                        marginsCard(summary)
                    }
                    .padding(22)
                }
                .navigationTitle(
                    summary.wariant.nazwa
                )
            } else {
                ContentUnavailableView(
                    "Brak danych wyceny",
                    systemImage:
                        "doc.text.magnifyingglass",
                    description:
                        Text(
                            "Otwórz wycenę z karty projektu albo przygotuj ją ponownie z aktualnych modułów."
                        )
                )
            }
        }
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .toolbar {
            ToolbarItem(
                placement:
                    .cancellationAction
            ) {
                Button("Zamknij") {
                    dismiss()
                }
            }

            ToolbarItem(
                placement:
                    .secondaryAction
            ) {
                Menu {
                    Button {
                        vatOverrideProcent = nil
                    } label: {
                        Label(
                            "Domyślny (\(Int(ustawienia.finanse.vatProcent.rounded()))%)",
                            systemImage:
                                vatOverrideProcent == nil
                                ? "checkmark"
                                : "percent"
                        )
                    }

                    Divider()

                    Button {
                        vatOverrideProcent = 23.0
                    } label: {
                        Label(
                            "23% — standardowy",
                            systemImage:
                                vatOverrideProcent == 23.0
                                ? "checkmark"
                                : "percent"
                        )
                    }

                    Button {
                        vatOverrideProcent = 8.0
                    } label: {
                        Label(
                            "8% — trwała zabudowa mieszkalna",
                            systemImage:
                                vatOverrideProcent == 8.0
                                ? "checkmark"
                                : "percent"
                        )
                    }

                    Button {
                        vatOverrideProcent = 0.0
                    } label: {
                        Label(
                            "0% — eksport / zwolniony",
                            systemImage:
                                vatOverrideProcent == 0.0
                                ? "checkmark"
                                : "percent"
                        )
                    }
                } label: {
                    Label(
                        "VAT \(Int(efektywnyVAT.rounded()))%",
                        systemImage: "percent"
                    )
                }
            }

            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    activeSheet =
                        .offerArchive
                } label: {
                    Label(
                        "Archiwum ofert",
                        systemImage:
                        "archivebox"
                    )
                }
                .disabled(
                    projekt == nil
                )

                Button {
                    activeSheet =
                        .customerOffer
                } label: {
                    Label(
                        "Oferta PDF",
                        systemImage:
                            "doc.text"
                    )
                }
                .disabled(
                    selectedSummary == nil
                    || projekt == nil
                )

                Button {
                    activeSheet =
                        .purchaseList
                } label: {
                    Label(
                        "Lista zakupowa",
                        systemImage:
                            "cart"
                    )
                }
                .disabled(
                    selectedSummary == nil
                    || projekt == nil
                )

                Button {
                    activeSheet = .bom
                } label: {
                    Label(
                        "BOM",
                        systemImage: "list.bullet.clipboard"
                    )
                }
                .disabled(
                    selectedSummary == nil
                    || projekt == nil
                )

                Button {
                    activeSheet = .editor
                } label: {
                    Label(
                        "Parametry projektu",
                        systemImage:
                            "slider.horizontal.3"
                    )
                }
                .disabled(
                    projekt == nil
                )
            }
        }
        .sheet(
            item: $activeSheet
        ) {
            sheet in

            activeSheetView(sheet)
        }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: WycenaWariantowaSheet
    ) -> some View {
        switch sheet {
        case .offerArchive:
            ArchiwumOfertView(
                projectName:
                    projekt?.nazwaProjektu ?? ""
            )

        case .customerOffer:
            if let projekt {
                OfertaKlientaView(
                    projekt: projekt,
                    wyceny: wyceny,
                    wybranyWariant:
                        selectedVariant,
                    ustawienia:
                        ustawienia
                )
            }

        case .purchaseList:
            if let selectedSummary {
                ListaZakupowaView(
                    list:
                        ListaZakupowaBuilder
                            .build(
                                projectName:
                                    projekt?.nazwaProjektu ?? "",
                                summary:
                                    selectedSummary
                            )
                )
            } else {
                ContentUnavailableView(
                    "Brak wariantu",
                    systemImage:
                        "cart.badge.questionmark",
                    description:
                        Text(
                            "Wybierz wariant wyceny, aby przygotować listę zakupową."
                        )
                )
            }

        case .editor:
            if let binding = projektBinding {
                EdytorParametrowWycenyView(
                    projekt: binding
                )
            }

        case .bom:
            if let selectedSummary {
                BOMProjektuViewV062(
                    bom:
                        BOMProjektuBuilderV062
                        .build(
                            projectName:
                                projekt?.nazwaProjektu ?? "",
                            summary:
                                selectedSummary
                        )
                )
            } else {
                ContentUnavailableView(
                    "Brak wariantu",
                    systemImage:
                        "list.bullet.clipboard",
                    description:
                        Text(
                            "Wybierz wariant wyceny, aby przygotować BOM."
                        )
                )
            }
        }
    }

    private func header(
        _ summary: PodsumowanieWariantuWyceny,
        projekt: ProjektWyceny
    ) -> some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    projekt.nazwaProjektu
                )
                .font(
                    .largeTitle.bold()
                )

                Text(
                    summary.wariant.opis
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 4
            ) {
                Text("Cena brutto")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(
                    summary
                        .cenaBrutto
                        .formatted(
                            .currency(
                                code: "PLN"
                            )
                        )
                )
                .font(
                    .largeTitle
                        .bold()
                        .monospacedDigit()
                )
            }
        }
    }

    private func summaryCards(
        _ summary:
            PodsumowanieWariantuWyceny
    ) -> some View {
        HStack(spacing: 12) {
            card(
                title: "Koszt bazowy",
                value:
                    money(
                        summary
                            .kosztBazowyNetto
                    ),
                icon: "sum"
            )

            card(
                title: "Cena netto",
                value:
                    money(
                        summary
                            .cenaNetto
                    ),
                icon: "banknote"
            )

            card(
                title: "VAT",
                value:
                    money(
                        summary
                            .vatKwota
                    ),
                icon:
                    "percent"
            )

            card(
                title: "Cena brutto",
                value:
                    money(
                        summary
                            .cenaBrutto
                    ),
                icon:
                    "checkmark.seal"
            )
        }
    }

    private func costTable(
        _ summary:
            PodsumowanieWariantuWyceny
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Label(
                "Pozycje kosztowe",
                systemImage:
                    "list.bullet.rectangle"
            )
            .font(.title3.bold())

            ForEach(
                summary.pozycje
            ) { item in
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(item.nazwa)
                            .font(.headline)

                        Text(
                            "\(item.ilosc.formatted()) \(item.jednostka) × \(money(item.cenaJednostkowaNetto))"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        if !item.uwagi.isEmpty {
                            Text(item.uwagi)
                                .font(.caption2)
                                .foregroundStyle(
                                    .secondary
                                )
                        }
                    }

                    Spacer()

                    Text(
                        money(
                            item.kosztNetto
                        )
                    )
                    .font(
                        .headline
                            .monospacedDigit()
                    )
                }
                .padding(
                    .vertical,
                    5
                )

                Divider()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemBackground
                )
            )
        )
    }

    private var hardwareDatabaseCard:
        some View
    {
        HStack(spacing: 12) {
            Image(
                systemName:
                    "shippingbox.fill"
            )
            .font(.title2)
            .foregroundStyle(.tint)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    "Automatyczny dobór okuć"
                )
                .font(.headline)

                Text(
                    okuciaRepository.okucia.isEmpty
                    ? "Baza okuć jest pusta — używane są ceny domyślne."
                    : "Wycena korzysta z \(okuciaRepository.okucia.filter(\.aktywne).count) aktywnych pozycji w bazie okuć."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
        .stolarniaFrostedCard()
    }

    private var offerArchiveCard:
        some View
    {
        Button {
            activeSheet = .offerArchive
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName:
                        "archivebox.fill"
                )
                .font(.title2)
                .foregroundStyle(.tint)

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        "Archiwum ofert"
                    )
                    .font(.headline)
                    .foregroundStyle(
                        .primary
                    )

                    Text(
                        "Historia PDF, status wysłania, akceptacji i ważności."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                }

                Spacer()

                Image(
                    systemName:
                        "chevron.right"
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .stolarniaFrostedCard()
    }

    private var customerOfferCard:
        some View
    {
        Button {
            activeSheet = .customerOffer
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName:
                        "doc.text.fill"
                )
                .font(.title2)
                .foregroundStyle(.tint)

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        "Oferta dla klienta"
                    )
                    .font(.headline)
                    .foregroundStyle(
                        .primary
                    )

                    Text(
                        "Generuj elegancki PDF bez kosztów wewnętrznych, narzutów i marży."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                }

                Spacer()

                Image(
                    systemName:
                        "chevron.right"
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .stolarniaFrostedCard()
    }

    private var purchaseListCard:
        some View
    {
        Button {
            activeSheet = .purchaseList
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName:
                        "cart.fill"
                )
                .font(.title2)
                .foregroundStyle(.tint)

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        "Lista zakupowa"
                    )
                    .font(.headline)
                    .foregroundStyle(
                        .primary
                    )

                    Text(
                        "Materiały, okucia i akcesoria do ręcznego zamówienia. Eksport do CSV."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                }

                Spacer()

                Image(
                    systemName:
                        "chevron.right"
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .stolarniaFrostedCard()
    }

    private func marginsCard(
        _ summary:
            PodsumowanieWariantuWyceny
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Label(
                "Narzuty i marża",
                systemImage:
                    "chart.line.uptrend.xyaxis"
            )
            .font(.title3.bold())

            row(
                "Zapas kosztowy",
                money(
                    summary
                        .zapasKosztowyKwota
                )
            )
            row(
                "Narzut",
                money(
                    summary
                        .narzutKwota
                )
            )
            row(
                "Marża",
                money(
                    summary
                        .marzaKwota
                )
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemBackground
                )
            )
        )
    }

    private func card(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Label(
                title,
                systemImage: icon
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            Text(value)
                .font(
                    .title3
                        .bold()
                        .monospacedDigit()
                )
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemBackground
                )
            )
        )
    }

    private func row(
        _ title: String,
        _ value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(
                    .secondary
                )
            Spacer()
            Text(value)
                .fontWeight(
                    .semibold
                )
                .monospacedDigit()
        }
    }

    private func money(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }
}

private struct EdytorParametrowWycenyView:
    View
{
    @Binding var projekt:
        ProjektWyceny

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Projekt") {
                    TextField(
                        "Nazwa projektu",
                        text:
                            $projekt
                                .nazwaProjektu
                    )

                    Stepper(
                        "Moduły: \(projekt.liczbaModulow)",
                        value:
                            $projekt
                                .liczbaModulow,
                        in: 1...200
                    )
                }

                Section("Materiały") {
                    number(
                        "Płyty",
                        value:
                            $projekt
                                .powierzchniaPlytM2,
                        suffix: "m²"
                    )

                    number(
                        "Fronty",
                        value:
                            $projekt
                                .powierzchniaFrontowM2,
                        suffix: "m²"
                    )

                    number(
                        "Blat",
                        value:
                            $projekt
                                .metryBiezaceBlatu,
                        suffix: "mb"
                    )
                }

                Section("Okucia") {
                    Stepper(
                        "Szuflady: \(projekt.liczbaSzuflad)",
                        value:
                            $projekt
                                .liczbaSzuflad,
                        in: 0...100
                    )

                    Stepper(
                        "Zawiasy: \(projekt.liczbaZawiasow)",
                        value:
                            $projekt
                                .liczbaZawiasow,
                        in: 0...300
                    )

                    Stepper(
                        "Cargo: \(projekt.liczbaCargo)",
                        value:
                            $projekt
                                .liczbaCargo,
                        in: 0...20
                    )
                }

                Section("Czas") {
                    number(
                        "Produkcja",
                        value:
                            $projekt
                                .liczbaGodzinProdukcji,
                        suffix: "h"
                    )

                    number(
                        "Montaż",
                        value:
                            $projekt
                                .liczbaGodzinMontazu,
                        suffix: "h"
                    )

                    Stepper(
                        "Transporty: \(projekt.liczbaTransportow)",
                        value:
                            $projekt
                                .liczbaTransportow,
                        in: 1...20
                    )
                }
            }
            .navigationTitle(
                "Parametry wyceny"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Gotowe") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func number(
        _ title: String,
        value:
            Binding<Double>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value: value,
                format:
                    .number
                    .grouping(.never)
                    .precision(
                        .fractionLength(
                            0...2
                        )
                    )
            )
            .keyboardType(
                .decimalPad
            )
            .multilineTextAlignment(
                .trailing
            )
            .frame(width: 120)

            Text(suffix)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 34,
                    alignment: .leading
                )
        }
    }
}
