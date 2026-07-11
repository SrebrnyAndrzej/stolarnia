import DomainCore
import Persistence
import SwiftUI

enum ZakladkaProdukcjiV071:
    String,
    CaseIterable,
    Identifiable
{
    case pulpit
    case formatki
    case rozkroj
    case obrzeza
    case obrobki
    case montaz
    case zakup

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .pulpit:
            return "Start"
        case .formatki:
            return "Formatki"
        case .rozkroj:
            return "Rozkrój"
        case .obrzeza:
            return "Obrzeża"
        case .obrobki:
            return "CNC"
        case .montaz:
            return "Montaż"
        case .zakup:
            return "Zakup płyt"
        }
    }

    var symbol: String {
        switch self {
        case .pulpit:
            return "shippingbox"
        case .formatki:
            return "list.number"
        case .rozkroj:
            return "square.grid.3x3.square"
        case .obrzeza:
            return "rectangle.and.hand.point.up.left"
        case .obrobki:
            return "gearshape.2"
        case .montaz:
            return "shippingbox"
        case .zakup:
            return "cart"
        }
    }
}

struct RozkrojPlytViewV071:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    private let zewnetrznaZakladka:
        Binding<ZakladkaProdukcjiV071>?
    private let prezentacjaV074:
        PrezentacjaProdukcjiV074
    private let room:
        RoomDefinition?
    private let assemblies:
        [StoredFurnitureAssembly]
    private let materialy:
        GlobalneMaterialyPomieszczenia
    private let liczbaModulow: Int

    @State private var lokalnaZakladka:
        ZakladkaProdukcjiV071
    @State private var ustawienia:
        UstawieniaRozkrojuPlytV071
    @State private var lista:
        ListaFormatekProjektuV070
    @State private var raport:
        RaportRozkrojuPlytV071
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var rozkrojSzukaj = ""
    @State private var zakupSzukaj = ""

    init(
        projectName: String,
        room:
            RoomDefinition? = nil,
        assemblies:
            [StoredFurnitureAssembly],
        materialy:
            GlobalneMaterialyPomieszczenia,
        zakladkaV074:
            Binding<ZakladkaProdukcjiV071>? = nil,
        prezentacjaV074:
            PrezentacjaProdukcjiV074 = .modalna
    ) {
        let list =
            ListaFormatekProjektuBuilderV070
                .build(
                    projectName:
                        projectName,
                    assemblies:
                        assemblies,
                    globalneMaterialy:
                        materialy
                )
        let settings =
            UstawieniaRozkrojuPlytV071
                .standard

        zewnetrznaZakladka =
            zakladkaV074
        self.prezentacjaV074 =
            prezentacjaV074
        self.room =
            room
        self.assemblies =
            assemblies
        self.materialy =
            materialy
        liczbaModulow =
            assemblies.count

        _lokalnaZakladka = State(
            initialValue:
                zakladkaV074?
                    .wrappedValue
                ?? .pulpit
        )
        _ustawienia = State(
            initialValue: settings
        )
        _lista = State(
            initialValue: list
        )
        _raport = State(
            initialValue:
                RozkrojPlytEngineV071
                    .build(
                        list: list,
                        settings: settings
                    )
        )
    }

    private var aktywnaZakladka:
        ZakladkaProdukcjiV071
    {
        zewnetrznaZakladka?
            .wrappedValue
        ?? lokalnaZakladka
    }

    private var aktywnaZakladkaBinding:
        Binding<ZakladkaProdukcjiV071>
    {
        zewnetrznaZakladka
        ?? $lokalnaZakladka
    }

    private var reportGotowosciV078:
        ProjectReadinessReportV078
    {
        ProjectReadinessEngineV078
            .build(
                room: room,
                assemblies: assemblies,
                materialy: materialy,
                lista: lista,
                raport: raport
            )
    }


    private var widoczneArkuszeV075:
        [ArkuszRozkrojuV071]
    {
        let query =
            rozkrojSzukaj
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !query.isEmpty else {
            return raport.arkusze
        }

        return raport
            .arkusze
            .filter {
                sheet in

                [
                    "Arkusz \(sheet.numer)",
                    sheet.grupa.opis,
                    sheet.grupa.material.opis,
                    sheet.grupa.material.producent,
                    sheet.grupa.material.kod,
                    sheet.grupa.material.nazwa
                ]
                .joined(
                    separator: " "
                )
                .localizedCaseInsensitiveContains(
                    query
                )
            }
    }

    private var widoczneZapotrzebowanieV075:
        [ZapotrzebowaniePlytyV071]
    {
        let query =
            zakupSzukaj
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !query.isEmpty else {
            return raport
                .zapotrzebowanie
        }

        return raport
            .zapotrzebowanie
            .filter {
                item in

                [
                    item.grupa.opis,
                    item.grupa.material.opis,
                    item.grupa.material.producent,
                    item.grupa.material.kod,
                    item.grupa.material.nazwa,
                    item.formatArkusza,
                    formatMM(item.grupa.gruboscMM)
                ]
                .joined(
                    separator: " "
                )
                .localizedCaseInsensitiveContains(
                    query
                )
            }
    }

    var body: some View {
        Group {
            switch prezentacjaV074 {
            case .modalna:
                NavigationStack {
                    zawartoscProdukcji
                        .navigationTitle(
                            "Produkcja"
                        )
                        .navigationBarTitleDisplayMode(
                            .inline
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

                            akcjeProdukcji
                        }
                }

            case .osadzona:
                zawartoscProdukcji
                    .toolbar {
                        akcjeProdukcji
                    }
            }
        }
        .alert(
            "Nie udało się przygotować raportu",
            isPresented:
                Binding(
                    get: {
                        exportError != nil
                    },
                    set: { visible in
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
            Text(exportError ?? "")
        }
    }

    private var zawartoscProdukcji:
        some View
    {
        VStack(spacing: 0) {
            if prezentacjaV074
                == .modalna {
                Picker(
                    "Moduł produkcyjny",
                    selection:
                        aktywnaZakladkaBinding
                ) {
                    ForEach(
                        ZakladkaProdukcjiV071
                            .allCases
                    ) {
                        Label(
                            $0.nazwa,
                            systemImage:
                                $0.symbol
                        )
                        .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(
                    .horizontal,
                    18
                )
                .padding(
                    .vertical,
                    12
                )

                Divider()
            }

            switch aktywnaZakladka {
            case .pulpit:
                ProdukcjaPulpitV074(
                    lista: lista,
                    raport: raport,
                    liczbaModulow:
                        liczbaModulow,
                    reportGotowosci:
                        reportGotowosciV078,
                    onOpen: {
                        aktywnaZakladkaBinding
                            .wrappedValue = $0
                    }
                )

            case .formatki:
                ListaFormatekProjektuContentV070(
                    list: lista
                )

            case .rozkroj:
                rozkrojContent

            case .obrzeza:
                OkleinowanieProjektuViewV072(
                    lista: lista
                )

            case .obrobki:
                ObrobkiCNCProjektuViewV073(
                    lista: lista
                )

            case .montaz:
                MontazIPakowanieProjektuViewV076(
                    lista: lista
                )

            case .zakup:
                zakupContent
            }
        }
    }

    @ToolbarContentBuilder
    private var akcjeProdukcji:
        some ToolbarContent
    {
        ToolbarItemGroup(
            placement:
                .primaryAction
        ) {
            if aktywnaZakladka == .rozkroj
                || aktywnaZakladka == .zakup {
                Button {
                    przelicz()
                } label: {
                    Label(
                        "Przelicz rozkrój",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .disabled(
                    !ustawienia.poprawne
                    || lista.formatki.isEmpty
                )

                if let exportURL {
                    ShareLink(
                        item: exportURL
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
                        raport.arkusze.isEmpty
                        && raport
                            .nierozmieszczone
                            .isEmpty
                    )
                }
            }
        }
    }

    private var rozkrojContent:
        some View
    {
        VStack(
            spacing: 0
        ) {
            ProdukcjaListaKontrolkiV075(
                tytul:
                    "Arkusze rozkroju",
                symbol:
                    "square.grid.3x3.square",
                liczbaWidocznych:
                    widoczneArkuszeV075
                        .count,
                liczbaWszystkich:
                    raport.arkusze
                        .count,
                wyszukiwanie:
                    $rozkrojSzukaj,
                podpowiedzWyszukiwania:
                    "Numer arkusza, materiał, kod lub producent",
                dodatkowyOpis:
                    "Ustawienia i podsumowanie dotyczą całego rozkroju."
            )

            Divider()

            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    ustawieniaCard
                    podsumowanieCard

                    if !raport
                        .nierozmieszczone
                        .isEmpty {
                        nierozmieszczoneCard
                    }

                    if raport.arkusze
                        .isEmpty {
                        ProdukcjaPustyStanV075(
                            tytul:
                                lista.formatki
                                    .isEmpty
                                ? "Brak formatek"
                                : "Brak rozkroju",
                            symbol:
                                "square.grid.3x3.square",
                            opis:
                                lista.formatki
                                    .isEmpty
                                ? "Dodaj moduły zawierające komponenty płytowe."
                                : "Sprawdź format arkusza i ustawienia rozkroju."
                        )
                    } else if widoczneArkuszeV075
                        .isEmpty {
                        ProdukcjaPustyStanV075(
                            tytul:
                                "Brak wyników",
                            symbol:
                                "line.3.horizontal.decrease.circle",
                            opis:
                                "Żaden arkusz nie odpowiada wyszukiwanej frazie.",
                            tytulAkcji:
                                "Wyczyść wyszukiwanie",
                            akcja: {
                                rozkrojSzukaj =
                                    ""
                            }
                        )
                    } else {
                        ForEach(
                            widoczneArkuszeV075
                        ) {
                            sheetCard($0)
                        }
                    }
                }
                .padding(18)
            }
        }
    }

    private var ustawieniaCard:
        some View
    {
        GroupBox {
            Grid(
                alignment:
                    .leadingFirstTextBaseline,
                horizontalSpacing: 18,
                verticalSpacing: 12
            ) {
                GridRow {
                    Text(
                        "Długość arkusza"
                    )
                    TextField(
                        "mm",
                        value:
                            $ustawienia
                                .dlugoscArkuszaMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(
                                        0...1
                                    )
                                )
                    )
                    .multilineTextAlignment(
                        .trailing
                    )
                    .keyboardType(
                        .decimalPad
                    )
                    Text("mm")
                        .foregroundStyle(
                            .secondary
                        )
                }

                GridRow {
                    Text(
                        "Szerokość arkusza"
                    )
                    TextField(
                        "mm",
                        value:
                            $ustawienia
                                .szerokoscArkuszaMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(
                                        0...1
                                    )
                                )
                    )
                    .multilineTextAlignment(
                        .trailing
                    )
                    .keyboardType(
                        .decimalPad
                    )
                    Text("mm")
                        .foregroundStyle(
                            .secondary
                        )
                }

                GridRow {
                    Text("Rzaz piły")
                    TextField(
                        "mm",
                        value:
                            $ustawienia
                                .rzazMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(
                                        0...2
                                    )
                                )
                    )
                    .multilineTextAlignment(
                        .trailing
                    )
                    .keyboardType(
                        .decimalPad
                    )
                    Text("mm")
                        .foregroundStyle(
                            .secondary
                        )
                }

                GridRow {
                    Text(
                        "Margines arkusza"
                    )
                    TextField(
                        "mm",
                        value:
                            $ustawienia
                                .marginesMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(
                                        0...1
                                    )
                                )
                    )
                    .multilineTextAlignment(
                        .trailing
                    )
                    .keyboardType(
                        .decimalPad
                    )
                    Text("mm")
                        .foregroundStyle(
                            .secondary
                        )
                }
            }
            .textFieldStyle(.roundedBorder)

            Toggle(
                "Uwzględniaj kierunek dekoru",
                isOn:
                    $ustawienia
                        .uwzgledniajKierunekDekoru
            )
            .padding(.top, 12)

            if !ustawienia.poprawne {
                Label(
                    "Wymiary arkusza muszą być dodatnie, a margines nie może zajmować całego arkusza.",
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.top, 8)
            }
        } label: {
            Label(
                "Parametry rozkroju",
                systemImage:
                    "slider.horizontal.3"
            )
        }
    }

    private var podsumowanieCard:
        some View
    {
        GroupBox {
            Grid(
                alignment: .leading,
                horizontalSpacing: 16,
                verticalSpacing: 12
            ) {
                GridRow {
                    metric(
                        title: "Arkusze",
                        value:
                            String(
                                raport
                                    .liczbaArkuszy
                            ),
                        symbol:
                            "square.stack.3d.up"
                    )

                    metric(
                        title: "Formatki",
                        value:
                            String(
                                raport
                                    .liczbaRozmieszczonychFormatek
                            ),
                        symbol:
                            "rectangle.split.3x1"
                    )
                }

                GridRow {
                    metric(
                        title:
                            "Wykorzystanie",
                        value:
                            percent(
                                raport
                                    .wykorzystanieProcent
                            ),
                        symbol:
                            "chart.pie"
                    )

                    metric(
                        title: "Odpad",
                        value:
                            "\(area(raport.odpadM2)) m²",
                        symbol:
                            "trash"
                    )
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

    private var nierozmieszczoneCard:
        some View
    {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(
                    raport
                        .nierozmieszczone
                ) {
                    item in

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(
                            "\(item.formatka.etykieta) • \(item.formatka.opisWymiaru)"
                        )
                        .font(
                            .subheadline
                                .weight(
                                    .semibold
                                )
                        )

                        Text(item.powod)
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }
            }
        } label: {
            Label(
                "Nierozmieszczone: \(raport.nierozmieszczone.count)",
                systemImage:
                    "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        }
    }

    private func sheetCard(
        _ sheet: ArkuszRozkrojuV071
    ) -> some View {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                HStack(
                    alignment:
                        .firstTextBaseline
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(
                            "Arkusz \(sheet.numer)"
                        )
                        .font(
                            .title3
                                .weight(
                                    .semibold
                                )
                        )

                        Text(
                            sheet.grupa.opis
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Text(
                        percent(
                            sheet
                                .wykorzystanieProcent
                        )
                    )
                    .font(
                        .headline
                            .monospacedDigit()
                    )
                }

                RozkrojArkuszaCanvasV071(
                    arkusz: sheet
                )
                .frame(height: 480)

                HStack {
                    Label(
                        "\(sheet.polozenia.count) formatek",
                        systemImage:
                            "rectangle.split.3x1"
                    )

                    Spacer()

                    Text(
                        "Odpad \(area(sheet.odpadM2)) m²"
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                DisclosureGroup(
                    "Pozycje na arkuszu"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(
                            sheet.polozenia
                        ) {
                            placement in

                            HStack(
                                alignment: .top
                            ) {
                                Text(
                                    placement
                                        .formatka
                                        .etykieta
                                )
                                .font(
                                    .caption
                                        .monospaced()
                                        .weight(
                                            .semibold
                                        )
                                )

                                Text(
                                    placement
                                        .formatka
                                        .kodKomponentu
                                )
                                .font(.caption)

                                Spacer()

                                Text(
                                    "\(formatMM(placement.dlugoscNaArkuszuMM)) × \(formatMM(placement.szerokoscNaArkuszuMM))"
                                )
                                .font(
                                    .caption
                                        .monospacedDigit()
                                )

                                if placement.obrocona {
                                    Text("90°")
                                        .font(
                                            .caption2
                                                .weight(
                                                    .bold
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)
            }
        }
    }

    private var zakupContent:
        some View
    {
        VStack(
            spacing: 0
        ) {
            ProdukcjaListaKontrolkiV075(
                tytul:
                    "Zakup płyt",
                symbol:
                    "cart",
                liczbaWidocznych:
                    widoczneZapotrzebowanieV075
                        .count,
                liczbaWszystkich:
                    raport
                        .zapotrzebowanie
                        .count,
                wyszukiwanie:
                    $zakupSzukaj,
                podpowiedzWyszukiwania:
                    "Materiał, kod, producent, grubość lub format"
            )

            Divider()

            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    GroupBox {
                        HStack {
                            metric(
                                title:
                                    "Pozycje materiałowe",
                                value:
                                    String(
                                        raport
                                            .zapotrzebowanie
                                            .count
                                    ),
                                symbol:
                                    "shippingbox"
                            )

                            metric(
                                title:
                                    "Arkusze łącznie",
                                value:
                                    String(
                                        raport
                                            .liczbaArkuszy
                                    ),
                                symbol:
                                    "square.stack.3d.up"
                            )
                        }
                    } label: {
                        Label(
                            "Zapotrzebowanie",
                            systemImage:
                                "cart"
                        )
                    }

                    if raport
                        .zapotrzebowanie
                        .isEmpty {
                        ProdukcjaPustyStanV075(
                            tytul:
                                "Brak zapotrzebowania",
                            symbol:
                                "cart",
                            opis:
                                "Przelicz rozkrój po dodaniu formatek."
                        )
                    } else if widoczneZapotrzebowanieV075
                        .isEmpty {
                        ProdukcjaPustyStanV075(
                            tytul:
                                "Brak wyników",
                            symbol:
                                "line.3.horizontal.decrease.circle",
                            opis:
                                "Żadna pozycja zakupowa nie odpowiada wyszukiwanej frazie.",
                            tytulAkcji:
                                "Wyczyść wyszukiwanie",
                            akcja: {
                                zakupSzukaj =
                                    ""
                            }
                        )
                    } else {
                        ForEach(
                            widoczneZapotrzebowanieV075
                        ) {
                            item in

                            GroupBox {
                                Grid(
                                    alignment:
                                        .leadingFirstTextBaseline,
                                    horizontalSpacing:
                                        16,
                                    verticalSpacing:
                                        8
                                ) {
                                    GridRow {
                                        Text(
                                            "Arkusze"
                                        )
                                        Text(
                                            "\(item.liczbaArkuszy) szt."
                                        )
                                        .font(
                                            .headline
                                                .monospacedDigit()
                                        )
                                    }

                                    GridRow {
                                        Text(
                                            "Format"
                                        )
                                        Text(
                                            item.formatArkusza
                                        )
                                        .monospacedDigit()
                                    }

                                    GridRow {
                                        Text(
                                            "Powierzchnia zakupu"
                                        )
                                        Text(
                                            "\(area(item.powierzchniaZakupuM2)) m²"
                                        )
                                        .monospacedDigit()
                                    }

                                    GridRow {
                                        Text(
                                            "Odpad"
                                        )
                                        Text(
                                            "\(area(item.odpadM2)) m²"
                                        )
                                        .monospacedDigit()
                                    }

                                    GridRow {
                                        Text(
                                            "Wykorzystanie"
                                        )
                                        Text(
                                            percent(
                                                item
                                                    .wykorzystanieProcent
                                            )
                                        )
                                        .monospacedDigit()
                                    }
                                }
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text(
                                        item
                                            .grupa
                                            .material
                                            .opis
                                    )

                                    Text(
                                        "Grubość \(formatMM(item.grupa.gruboscMM)) mm"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
    }

    private func metric(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(
                    width: 28,
                    height: 28
                )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(value)
                    .font(
                        .headline
                            .monospacedDigit()
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private func przelicz() {
        guard ustawienia.poprawne else {
            return
        }

        raport = RozkrojPlytEngineV071
            .build(
                list: lista,
                settings: ustawienia
            )
        exportURL = nil
        exportError = nil
    }

    private func prepareExport() {
        do {
            exportURL = try RozkrojPlytCSVV071
                .makeFile(for: raport)
            exportError = nil
        } catch {
            exportError =
                error.localizedDescription
        }
    }

    private func area(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(
                    Locale(
                        identifier: "pl_PL"
                    )
                )
                .precision(
                    .fractionLength(0...3)
                )
        )
    }

    private func percent(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(
                    Locale(
                        identifier: "pl_PL"
                    )
                )
                .precision(
                    .fractionLength(0...1)
                )
        )
        + "%"
    }

    private func formatMM(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(
                    Locale(
                        identifier: "pl_PL"
                    )
                )
                .grouping(.never)
                .precision(
                    .fractionLength(0...1)
                )
        )
    }
}

private struct RozkrojArkuszaCanvasV071:
    View
{
    let arkusz: ArkuszRozkrojuV071

    var body: some View {
        GeometryReader {
            geometry in

            Canvas {
                context,
                size in

                let horizontalPadding:
                    CGFloat = 18
                let verticalPadding:
                    CGFloat = 18
                let availableWidth =
                    max(
                        1,
                        size.width
                            - horizontalPadding
                                * 2
                    )
                let availableHeight =
                    max(
                        1,
                        size.height
                            - verticalPadding
                                * 2
                    )
                let scale = min(
                    availableWidth
                        / CGFloat(
                            arkusz
                                .szerokoscMM
                        ),
                    availableHeight
                        / CGFloat(
                            arkusz
                                .dlugoscMM
                        )
                )
                let boardWidth =
                    CGFloat(
                        arkusz.szerokoscMM
                    )
                    * scale
                let boardHeight =
                    CGFloat(
                        arkusz.dlugoscMM
                    )
                    * scale
                let origin = CGPoint(
                    x:
                        (
                            size.width
                            - boardWidth
                        )
                        / 2,
                    y:
                        (
                            size.height
                            - boardHeight
                        )
                        / 2
                )
                let boardRect = CGRect(
                    origin: origin,
                    size: CGSize(
                        width: boardWidth,
                        height: boardHeight
                    )
                )

                context.fill(
                    Path(boardRect),
                    with:
                        .color(
                            Color.secondary
                                .opacity(0.08)
                        )
                )
                context.stroke(
                    Path(boardRect),
                    with:
                        .color(
                            Color.primary
                        ),
                    lineWidth: 1.5
                )

                for placement
                    in arkusz.polozenia {
                    let rect = CGRect(
                        x:
                            origin.x
                            + CGFloat(
                                placement.xMM
                            )
                                * scale,
                        y:
                            origin.y
                            + CGFloat(
                                placement.yMM
                            )
                                * scale,
                        width:
                            CGFloat(
                                placement
                                    .szerokoscNaArkuszuMM
                            )
                            * scale,
                        height:
                            CGFloat(
                                placement
                                    .dlugoscNaArkuszuMM
                            )
                            * scale
                    )

                    context.fill(
                        Path(rect),
                        with:
                            .color(
                                Color.accentColor
                                    .opacity(
                                        0.18
                                    )
                            )
                    )
                    context.stroke(
                        Path(rect),
                        with:
                            .color(
                                Color.accentColor
                            ),
                        lineWidth: 1
                    )

                    if rect.width > 42,
                       rect.height > 22 {
                        let label =
                            context.resolve(
                                Text(
                                    placement
                                        .formatka
                                        .etykieta
                                )
                                .font(
                                    .system(
                                        size: 9,
                                        weight:
                                            .semibold,
                                        design:
                                            .monospaced
                                    )
                                )
                            )

                        context.draw(
                            label,
                            at: CGPoint(
                                x:
                                    rect.midX,
                                y:
                                    rect.midY
                            ),
                            anchor: .center
                        )
                    }
                }
            }
            .accessibilityElement(
                children: .ignore
            )
            .accessibilityLabel(
                "Arkusz \(arkusz.numer), \(arkusz.polozenia.count) formatek, wykorzystanie \(arkusz.wykorzystanieProcent.formatted(.number.precision(.fractionLength(0...1)))) procent"
            )
        }
    }
}
