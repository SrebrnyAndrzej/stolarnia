import Foundation
import SwiftUI

private enum ZakladkaMontazuV076:
    String,
    CaseIterable,
    Identifiable
{
    case montaz
    case paczki
    case podsumowanie

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .montaz:
            return "Montaż"
        case .paczki:
            return "Paczki"
        case .podsumowanie:
            return "Podsumowanie"
        }
    }

    var symbol: String {
        switch self {
        case .montaz:
            return "checklist"
        case .paczki:
            return "shippingbox"
        case .podsumowanie:
            return "chart.bar"
        }
    }
}

struct MontazIPakowanieProjektuViewV076:
    View
{
    let lista:
        ListaFormatekProjektuV070

    @State private var ustawienia:
        UstawieniaMontazuIPakowaniaV076
    @State private var raport:
        RaportMontazuIPakowaniaV076
    @State private var zakladka:
        ZakladkaMontazuV076 = .montaz
    @State private var wyszukiwanieMontazu = ""
    @State private var wyszukiwaniePaczek = ""
    @State private var filtrEtapu:
        EtapMontazuV076?
    @State private var filtrTypuPaczki:
        TypPaczkiV076?
    @State private var wykonaneOperacje:
        Set<String> = []
    @State private var spakowanePaczki:
        Set<String> = []
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var pokazUstawienia = false
    @State private var pokazKontekstMontazuV079 =
        true
    @StateObject private var travellerRepositoryV078 =
        FormatkaTravellerRepositoryV078()

    init(
        lista:
            ListaFormatekProjektuV070
    ) {
        self.lista = lista

        let settings =
            UstawieniaMontazuIPakowaniaV076
                .standard

        _ustawienia = State(
            initialValue: settings
        )
        _raport = State(
            initialValue:
                MontazPakowanieEngineV076
                    .build(
                        list: lista,
                        settings: settings
                    )
        )
    }

    private var widoczneOperacje:
        [OperacjaMontazowaV076]
    {
        let query =
            wyszukiwanieMontazu
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return raport
            .operacje
            .filter {
                operation in

                let matchesStage =
                    filtrEtapu == nil
                    || operation.etap
                        == filtrEtapu
                let matchesQuery =
                    query.isEmpty
                    || operation
                        .tekstWyszukiwania
                        .localizedCaseInsensitiveContains(
                            query
                        )

                return matchesStage
                    && matchesQuery
            }
    }

    private var widocznePaczki:
        [PaczkaProdukcyjnaV076]
    {
        let query =
            wyszukiwaniePaczek
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return raport
            .paczki
            .filter {
                package in

                let matchesType =
                    filtrTypuPaczki == nil
                    || package.typ
                        == filtrTypuPaczki
                let matchesQuery =
                    query.isEmpty
                    || package
                        .tekstWyszukiwania
                        .localizedCaseInsensitiveContains(
                            query
                        )

                return matchesType
                    && matchesQuery
            }
    }

    private var postepMontazu: Double {
        guard !raport.operacje.isEmpty
        else {
            return 0
        }

        return Double(
            wykonaneOperacjeEfektywneV078
                .count
        )
        / Double(
            raport.operacje.count
        )
    }

    private var postepPakowania: Double {
        guard !raport.paczki.isEmpty
        else {
            return 0
        }

        return Double(
            spakowanePaczkiEfektywneV078
                .count
        )
        / Double(
            raport.paczki.count
        )
    }

    private var formatkiByIDV078:
        [String: FormatkaProjektuV070]
    {
        Dictionary(
            uniqueKeysWithValues:
                lista.formatki.map {
                    (
                        $0.id,
                        $0
                    )
                }
        )
    }

    private var wykonaneOperacjeEfektywneV078:
        Set<String>
    {
        Set(
            raport.operacje
                .filter {
                    wykonaneOperacje
                        .contains($0.id)
                    && ocenaOperacjiV078($0)
                        .blokady
                        .isEmpty
                }
                .map(\.id)
        )
    }

    private var spakowanePaczkiEfektywneV078:
        Set<String>
    {
        Set(
            raport.paczki
                .filter {
                    spakowanePaczki
                        .contains($0.id)
                    && ocenaPaczkiV078($0)
                        .moznaZamknac
                }
                .map(\.id)
        )
    }

    private var zablokowanePaczkiV078:
        [OcenaStatusuPaczkiV078]
    {
        raport.paczki
            .map(ocenaPaczkiV078)
            .filter {
                !$0.blokady.isEmpty
            }
    }

    private var operacjeWKolejnosciV079:
        [OperacjaMontazowaV076]
    {
        raport.operacje
            .sorted(
                by:
                    sortOperacjeMontazoweV079
            )
    }

    private var aktywnyKrokMontazuV079:
        KrokMontazuV079?
    {
        let operations =
            operacjeWKolejnosciV079

        guard let index =
                operations
                .firstIndex(where: {
                    !wykonaneOperacjeEfektywneV078
                        .contains($0.id)
                }) else {
            return nil
        }

        let operation =
            operations[index]
        let packages =
            paczkiDlaOperacjiV079(
                operation
            )
            .map {
                PaczkaKrokuMontazuV079(
                    package: $0,
                    ocena:
                        ocenaPaczkiV078($0),
                    spakowana:
                        spakowanePaczkiEfektywneV078
                            .contains($0.id)
                )
            }

        return KrokMontazuV079(
            numer: index + 1,
            liczbaKrokow:
                operations.count,
            operation:
                operation,
            ocena:
                ocenaOperacjiV078(
                    operation
                ),
            paczki:
                packages
        )
    }

    private var kolejneOperacjeMontazuV079:
        [OperacjaMontazowaV076]
    {
        let operations =
            operacjeWKolejnosciV079

        guard let activeID =
                aktywnyKrokMontazuV079?
                .operation
                .id,
              let index =
                operations
                .firstIndex(where: {
                    $0.id == activeID
                }) else {
            return []
        }

        return Array(
            operations
                .dropFirst(index + 1)
                .prefix(3)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            switch zakladka {
            case .montaz:
                montazContent
            case .paczki:
                paczkiContent
            case .podsumowanie:
                podsumowanieContent
            }
        }
        .alert(
            "Nie udało się przygotować eksportu",
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
            Text(exportError ?? "")
        }
    }

    private var header:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            ViewThatFits(
                in: .horizontal
            ) {
                HStack(
                    alignment: .center,
                    spacing: 16
                ) {
                    titleBlock
                    Spacer(minLength: 20)
                    progressBlock
                }

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    titleBlock
                    progressBlock
                }
            }

            Picker(
                "Obszar montażu i pakowania",
                selection:
                    $zakladka
            ) {
                ForEach(
                    ZakladkaMontazuV076
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
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            14
        )
        .background(.bar)
    }

    private var titleBlock:
        some View
    {
        HStack(spacing: 12) {
            Image(
                systemName:
                    "shippingbox.fill"
            )
            .font(.title2)
            .foregroundStyle(
                Color.accentColor
            )
            .frame(
                width: 42,
                height: 42
            )
            .background(
                Color.accentColor
                    .opacity(0.12),
                in:
                    RoundedRectangle(
                        cornerRadius: 11,
                        style:
                            .continuous
                    )
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    "Montaż i pakowanie"
                )
                .font(.title3.bold())

                Text(
                    "\(raport.moduly.count) modułów • \(raport.paczki.count) paczek • \(formatKGV076(raport.lacznaSzacowanaMasaKG)) kg szacunkowo"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }

    private var progressBlock:
        some View
    {
        HStack(spacing: 18) {
            progressItem(
                title: "Montaż",
                value: postepMontazu,
                completed:
                    wykonaneOperacjeEfektywneV078
                        .count,
                total:
                    raport.operacje
                        .count
            )

            progressItem(
                title: "Pakowanie",
                value: postepPakowania,
                completed:
                    spakowanePaczkiEfektywneV078
                        .count,
                total:
                    raport.paczki
                        .count
            )
        }
    }

    private func progressItem(
        title: String,
        value: Double,
        completed: Int,
        total: Int
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            HStack(spacing: 8) {
                Text(title)
                    .font(
                        .caption
                            .weight(
                                .semibold
                            )
                    )

                Text(
                    "\(completed)/\(total)"
                )
                .font(
                    .caption2
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ProgressView(
                value: value
            )
            .frame(width: 120)
        }
    }

    private var montazContent:
        some View
    {
        VStack(spacing: 0) {
            ProdukcjaListaKontrolkiV075(
                tytul:
                    "Operacje montażowe",
                symbol:
                    "checklist",
                liczbaWidocznych:
                    widoczneOperacje
                        .count,
                liczbaWszystkich:
                    raport.operacje
                        .count,
                wyszukiwanie:
                    $wyszukiwanieMontazu,
                podpowiedzWyszukiwania:
                    "Moduł, etap, operacja lub etykieta",
                dodatkowyOpis:
                    "Zaznaczenia są stanem roboczym tej sesji i trafiają do eksportu CSV."
            )

            stageFilterBar

            Divider()

            if raport.operacje.isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak operacji montażowych",
                    symbol:
                        "checklist",
                    opis:
                        "Dodaj do projektu moduły zawierające formatki."
                )
            } else if widoczneOperacje
                .isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak wyników",
                    symbol:
                        "line.3.horizontal.decrease.circle",
                    opis:
                        "Żadna operacja nie odpowiada wyszukiwaniu lub wybranemu etapowi.",
                    tytulAkcji:
                        "Wyczyść filtry",
                    akcja: {
                        wyszukiwanieMontazu =
                            ""
                        filtrEtapu = nil
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        guidedAssemblyCardV079

                        ForEach(
                            groupedVisibleOperations,
                            id: \.id
                        ) {
                            group in

                            operationModuleCard(
                                group
                            )
                        }
                    }
                    .padding(18)
                }
                .background(
                    StolarniaPalette.canvas
                )
            }
        }
    }

    private var groupedVisibleOperations:
        [OperationGroupV076]
    {
        Dictionary(
            grouping:
                widoczneOperacje
        ) {
            ModuleIdentityV076(
                index:
                    $0.indeksModulu,
                name:
                    $0.nazwaModulu
            )
        }
        .map {
            OperationGroupV076(
                id:
                    "\($0.key.index)|\($0.key.name)",
                index:
                    $0.key.index,
                name:
                    $0.key.name,
                operations:
                    $0.value.sorted {
                        if $0.etap
                            .kolejnosc
                            != $1.etap
                                .kolejnosc {
                            return $0.etap
                                .kolejnosc
                                < $1.etap
                                    .kolejnosc
                        }

                        return $0.kolejnosc
                            < $1.kolejnosc
                    }
            )
        }
        .sorted {
            if $0.index != $1.index {
                return $0.index
                    < $1.index
            }

            return $0.name
                .localizedStandardCompare(
                    $1.name
                )
                == .orderedAscending
        }
    }

    private var stageFilterBar:
        some View
    {
        HStack(spacing: 10) {
            Menu {
                Picker(
                    "Etap montażu",
                    selection:
                        $filtrEtapu
                ) {
                    Text("Wszystkie etapy")
                        .tag(
                            nil as
                                EtapMontazuV076?
                        )

                    ForEach(
                        EtapMontazuV076
                            .allCases
                    ) {
                        Label(
                            $0.nazwa,
                            systemImage:
                                $0.symbol
                        )
                        .tag(
                            Optional($0)
                        )
                    }
                }
            } label: {
                Label(
                    filtrEtapu?
                        .nazwa
                    ?? "Wszystkie etapy",
                    systemImage:
                        filtrEtapu == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            if !wykonaneOperacje
                .isEmpty {
                Button {
                    wykonaneOperacje
                        .removeAll()
                    unieważnijEksport()
                } label: {
                    Label(
                        "Wyczyść postęp",
                        systemImage:
                            "arrow.counterclockwise"
                    )
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .bottom,
            10
        )
        .background(.bar)
    }

    private func operationModuleCard(
        _ group:
            OperationGroupV076
    ) -> some View {
        GroupBox {
            VStack(spacing: 0) {
                ForEach(
                    Array(
                        group.operations
                            .enumerated()
                    ),
                    id: \.element.id
                ) {
                    offset,
                    operation in

                    operationRow(
                        operation
                    )

                    if offset
                        < group.operations
                            .count - 1 {
                        Divider()
                            .padding(
                                .leading,
                                44
                            )
                    }
                }
            }
        } label: {
            HStack {
                Label(
                    String(
                        format:
                            "M%02d — %@",
                        group.index,
                        group.name
                    ),
                    systemImage:
                        "cabinet"
                )

                Spacer()

                let completed =
                    group.operations
                        .filter {
                            wykonaneOperacje
                                .contains(
                                    $0.id
                                )
                        }
                        .count

                Text(
                    "\(completed)/\(group.operations.count)"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                        .monospacedDigit()
                )
                .foregroundStyle(
                    completed
                        == group.operations
                            .count
                    ? Color.green
                    : Color.secondary
                )
            }
        }
    }

    private func operationRow(
        _ operation:
            OperacjaMontazowaV076
    ) -> some View {
        let isDone =
            wykonaneOperacje
                .contains(operation.id)
        let ocena =
            ocenaOperacjiV078(operation)
        let maBlokade =
            !ocena.blokady.isEmpty

        return HStack(
            alignment: .top,
            spacing: 12
        ) {
            Button {
                if isDone {
                    wykonaneOperacje
                        .remove(
                            operation.id
                        )
                } else if !maBlokade {
                    wykonaneOperacje
                        .insert(
                            operation.id
                        )
                }

                unieważnijEksport()
            } label: {
                Image(
                    systemName:
                        isDone
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    isDone
                        ? Color.green
                        : (
                            maBlokade
                            ? Color.orange
                            : Color.secondary
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !isDone
                    && maBlokade
            )
            .accessibilityLabel(
                isDone
                    ? "Oznacz jako niewykonane"
                    : (
                        maBlokade
                        ? "Operacja zablokowana przez status formatki"
                        : "Oznacz jako wykonane"
                    )
            )

            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                HStack(
                    alignment:
                        .firstTextBaseline,
                    spacing: 8
                ) {
                    Text(operation.tytul)
                        .font(
                            .subheadline
                                .weight(
                                    .semibold
                                )
                        )
                        .strikethrough(
                            isDone
                        )

                    stageBadge(
                        operation.etap
                    )

                    if operation
                        .wymagaWeryfikacji {
                        Image(
                            systemName:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            Color.orange
                        )
                        .help(
                            "Operacja wymaga kontroli"
                        )
                    }

                    if maBlokade {
                        Label(
                            "\(ocena.blokady.count)",
                            systemImage:
                                "lock.trianglebadge.exclamationmark"
                        )
                        .font(
                            .caption2
                                .weight(.semibold)
                        )
                        .foregroundStyle(
                            Color.orange
                        )
                    }
                }

                Text(operation.opis)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                if !operation
                    .etykietyFormatek
                    .isEmpty {
                    Text(
                        operation
                            .etykietyFormatek
                            .joined(
                                separator:
                                    " • "
                            )
                    )
                    .font(
                        .caption2
                            .monospaced()
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                    .textSelection(
                        .enabled
                    )
                }

                problemyStatusowV078(
                    ocena.problemy
                )
            }

            Spacer(minLength: 0)
        }
        .padding(
            .vertical,
            10
        )
        .contentShape(Rectangle())
    }

    private func stageBadge(
        _ stage:
            EtapMontazuV076
    ) -> some View {
        Label(
            stage.nazwa,
            systemImage:
                stage.symbol
        )
        .font(
            .caption2
                .weight(
                    .semibold
                )
        )
        .foregroundStyle(
            Color.accentColor
        )
        .padding(
            .horizontal,
            7
        )
        .padding(
            .vertical,
            3
        )
        .background(
            Color.accentColor
                .opacity(0.10),
            in: Capsule()
        )
    }

    @ViewBuilder
    private var guidedAssemblyCardV079:
        some View
    {
        GroupBox {
            if let step =
                aktywnyKrokMontazuV079 {
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
                                "Krok \(step.numer) z \(step.liczbaKrokow)"
                            )
                            .font(
                                .caption
                                    .weight(
                                        .semibold
                                    )
                                    .monospacedDigit()
                            )
                            .foregroundStyle(
                                .secondary
                            )

                            Text(
                                step.operation
                                    .tytul
                            )
                            .font(.title3.bold())

                            Text(
                                String(
                                    format:
                                        "M%02d — %@",
                                    step.operation
                                        .indeksModulu,
                                    step.operation
                                        .nazwaModulu
                                )
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Spacer(minLength: 12)

                        stageBadge(
                            step.operation
                                .etap
                        )
                    }

                    ProgressView(
                        value:
                            Double(
                                step.numer - 1
                            ),
                        total:
                            Double(
                                max(
                                    step.liczbaKrokow,
                                    1
                                )
                            )
                    )

                    Text(
                        step.operation
                            .opis
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    if !step.operation
                        .etykietyFormatek
                        .isEmpty {
                        Text(
                            step.operation
                                .etykietyFormatek
                                .joined(
                                    separator:
                                        " • "
                                )
                        )
                        .font(
                            .caption
                                .monospaced()
                        )
                        .foregroundStyle(
                            Color.accentColor
                        )
                        .textSelection(.enabled)
                    }

                    if !step.paczki.isEmpty {
                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            Text(
                                "Paczki do tego kroku"
                            )
                            .font(
                                .caption
                                    .weight(
                                        .semibold
                                    )
                            )
                            .foregroundStyle(
                                .secondary
                            )

                            LazyVGrid(
                                columns: [
                                    GridItem(
                                        .adaptive(
                                            minimum:
                                                190
                                        ),
                                        spacing: 8
                                    )
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(
                                    step.paczki
                                ) {
                                    packageStatusTileV079(
                                        $0
                                    )
                                }
                            }
                        }
                    }

                    problemyStatusowV078(
                        step.ocena
                            .problemy
                    )

                    if pokazKontekstMontazuV079,
                       !kolejneOperacjeMontazuV079
                        .isEmpty {
                        Divider()

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            Text(
                                "Następne kroki"
                            )
                            .font(
                                .caption
                                    .weight(
                                        .semibold
                                    )
                            )
                            .foregroundStyle(
                                .secondary
                            )

                            ForEach(
                                kolejneOperacjeMontazuV079
                            ) {
                                operation in
                                HStack(
                                    spacing: 8
                                ) {
                                    Image(
                                        systemName:
                                            operation
                                                .etap
                                                .symbol
                                    )
                                    .foregroundStyle(
                                        Color
                                            .accentColor
                                    )
                                    .frame(width: 20)

                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing: 2
                                    ) {
                                        Text(
                                            operation
                                                .tytul
                                        )
                                        .font(
                                            .caption
                                                .weight(
                                                    .semibold
                                                )
                                        )

                                        Text(
                                            operation
                                                .etap
                                                .nazwa
                                        )
                                        .font(.footnote)
                                        .foregroundStyle(
                                            .secondary
                                        )
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }

                    HStack {
                        Button {
                            wykonaneOperacje
                                .insert(
                                    step.operation.id
                                )
                            unieważnijEksport()
                        } label: {
                            Label(
                                step.ocena
                                    .blokady
                                    .isEmpty
                                ? "Zamknij krok"
                                : "Krok zablokowany",
                                systemImage:
                                    step.ocena
                                        .blokady
                                        .isEmpty
                                    ? "checkmark.circle"
                                    : "lock.trianglebadge.exclamationmark"
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .disabled(
                            !step.ocena
                                .blokady
                                .isEmpty
                        )

                        if !step.paczki
                            .isEmpty {
                            Button {
                                zakladka = .paczki
                                wyszukiwaniePaczek =
                                    step.operation
                                    .nazwaModulu
                                filtrTypuPaczki = nil
                            } label: {
                                Label(
                                    "Pokaż paczki",
                                    systemImage:
                                        "shippingbox"
                                )
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button {
                            pokazKontekstMontazuV079
                                .toggle()
                        } label: {
                            Label(
                                pokazKontekstMontazuV079
                                ? "Ukryj kontekst"
                                : "Pokaż kontekst",
                                systemImage:
                                    "sidebar.trailing"
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Label(
                        "Montaż zamknięty",
                        systemImage:
                            "checkmark.seal.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(Color.green)

                    Text(
                        "Wszystkie operacje są oznaczone jako wykonane i nie mają aktywnych blokad statusu formatki."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label(
                "Przewodnik montażu",
                systemImage:
                    "figure.run.circle"
            )
        }
    }

    private func packageStatusTileV079(
        _ stepPackage:
            PaczkaKrokuMontazuV079
    ) -> some View {
        let color =
            kolorPaczkiKrokuV079(
                stepPackage
            )

        return HStack(
            alignment: .top,
            spacing: 8
        ) {
            Image(
                systemName:
                    stepPackage.symbol
            )
            .foregroundStyle(color)
            .frame(width: 22)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    stepPackage
                        .package
                        .kod
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                        .monospaced()
                )

                Text(
                    stepPackage
                        .opisStatusu
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            8
        )
        .background(
            color.opacity(0.12),
            in:
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
        )
    }

    private var paczkiContent:
        some View
    {
        VStack(spacing: 0) {
            ProdukcjaListaKontrolkiV075(
                tytul:
                    "Paczki produkcyjne",
                symbol:
                    "shippingbox",
                liczbaWidocznych:
                    widocznePaczki
                        .count,
                liczbaWszystkich:
                    raport.paczki
                        .count,
                wyszukiwanie:
                    $wyszukiwaniePaczek,
                podpowiedzWyszukiwania:
                    "Kod paczki, moduł, element lub materiał",
                dodatkowyOpis:
                    "Masa jest wartością szacunkową wynikającą z wymiarów, gęstości i ustawionego zapasu."
            )

            packageFilterBar

            Divider()

            if raport.paczki.isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak paczek",
                    symbol:
                        "shippingbox",
                    opis:
                        lista.formatki
                            .isEmpty
                        ? "Dodaj moduły zawierające formatki."
                        : "Sprawdź ustawienia pakowania i przelicz raport."
                )
            } else if widocznePaczki
                .isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak wyników",
                    symbol:
                        "line.3.horizontal.decrease.circle",
                    opis:
                        "Żadna paczka nie odpowiada wyszukiwaniu lub wybranemu typowi.",
                    tytulAkcji:
                        "Wyczyść filtry",
                    akcja: {
                        wyszukiwaniePaczek =
                            ""
                        filtrTypuPaczki =
                            nil
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        settingsCard

                        if !raport
                            .ostrzezenia
                            .isEmpty {
                            warningsCard
                        }

                        ForEach(
                            widocznePaczki
                        ) {
                            packageCard($0)
                        }
                    }
                    .padding(18)
                }
                .background(
                    StolarniaPalette.canvas
                )
            }
        }
    }

    private var packageFilterBar:
        some View
    {
        HStack(spacing: 10) {
            Menu {
                Picker(
                    "Typ paczki",
                    selection:
                        $filtrTypuPaczki
                ) {
                    Text(
                        "Wszystkie typy"
                    )
                    .tag(
                        nil as
                            TypPaczkiV076?
                    )

                    ForEach(
                        TypPaczkiV076
                            .allCases
                    ) {
                        Label(
                            $0.nazwa,
                            systemImage:
                                $0.symbol
                        )
                        .tag(
                            Optional($0)
                        )
                    }
                }
            } label: {
                Label(
                    filtrTypuPaczki?
                        .nazwa
                    ?? "Wszystkie typy",
                    systemImage:
                        filtrTypuPaczki
                        == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .buttonStyle(.bordered)

            Button {
                pokazUstawienia
                    .toggle()
            } label: {
                Label(
                    pokazUstawienia
                        ? "Ukryj ustawienia"
                        : "Ustawienia",
                    systemImage:
                        "slider.horizontal.3"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            if !spakowanePaczki
                .isEmpty {
                Button {
                    spakowanePaczki
                        .removeAll()
                    unieważnijEksport()
                } label: {
                    Label(
                        "Wyczyść postęp",
                        systemImage:
                            "arrow.counterclockwise"
                    )
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .bottom,
            10
        )
        .background(.bar)
    }

    @ViewBuilder
    private var settingsCard:
        some View
    {
        if pokazUstawienia {
            GroupBox {
                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {
                    ViewThatFits(
                        in: .horizontal
                    ) {
                        HStack(
                            alignment: .top,
                            spacing: 18
                        ) {
                            settingsColumnOne
                            settingsColumnTwo
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 14
                        ) {
                            settingsColumnOne
                            settingsColumnTwo
                        }
                    }

                    Divider()

                    HStack {
                        if !ustawienia
                            .poprawne {
                            Label(
                                "Popraw wartości ustawień.",
                                systemImage:
                                    "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                Color.red
                            )
                        }

                        Spacer()

                        Button {
                            ustawienia =
                                .standard
                        } label: {
                            Label(
                                "Przywróć standard",
                                systemImage:
                                    "arrow.counterclockwise"
                            )
                        }
                        .buttonStyle(
                            .borderless
                        )

                        Button {
                            przelicz()
                        } label: {
                            Label(
                                "Przelicz paczki",
                                systemImage:
                                    "arrow.clockwise"
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .disabled(
                            !ustawienia
                                .poprawne
                        )
                    }
                }
                .textFieldStyle(
                    .roundedBorder
                )
            } label: {
                Label(
                    "Ustawienia pakowania",
                    systemImage:
                        "slider.horizontal.3"
                )
            }
        }
    }

    private var settingsColumnOne:
        some View
    {
        Grid(
            alignment:
                .leadingFirstTextBaseline,
            horizontalSpacing: 10,
            verticalSpacing: 10
        ) {
            numericSettingRow(
                title:
                    "Maks. masa paczki",
                value:
                    $ustawienia
                        .maksymalnaMasaPaczkiKG,
                suffix: "kg"
            )

            GridRow {
                Text(
                    "Maks. elementów"
                )

                TextField(
                    "szt.",
                    value:
                        $ustawienia
                            .maksymalnaLiczbaElementow,
                    format: .number
                )
                .multilineTextAlignment(
                    .trailing
                )
                .keyboardType(
                    .numberPad
                )
                .frame(
                    minWidth: 86
                )

                Text("szt.")
                    .foregroundStyle(
                        .secondary
                    )
            }

            numericSettingRow(
                title:
                    "Próg 2 osób",
                value:
                    $ustawienia
                        .progDwochOsobKG,
                suffix: "kg"
            )

            numericSettingRow(
                title:
                    "Długi element od",
                value:
                    $ustawienia
                        .progDlugiegoElementuMM,
                suffix: "mm"
            )
        }
    }

    private var settingsColumnTwo:
        some View
    {
        Grid(
            alignment:
                .leadingFirstTextBaseline,
            horizontalSpacing: 10,
            verticalSpacing: 10
        ) {
            numericSettingRow(
                title:
                    "Gęstość płyty",
                value:
                    $ustawienia
                        .gestoscPlytyKGNaM3,
                suffix: "kg/m³"
            )

            numericSettingRow(
                title:
                    "Gęstość pleców",
                value:
                    $ustawienia
                        .gestoscPlecowKGNaM3,
                suffix: "kg/m³"
            )

            numericSettingRow(
                title:
                    "Gęstość blatu",
                value:
                    $ustawienia
                        .gestoscBlatuKGNaM3,
                suffix: "kg/m³"
            )

            numericSettingRow(
                title:
                    "Zapas masy",
                value:
                    $ustawienia
                        .zapasMasyProcent,
                suffix: "%"
            )

            GridRow {
                Toggle(
                    "Fronty osobno",
                    isOn:
                        $ustawienia
                            .osobnoFronty
                )
                .gridCellColumns(3)
            }

            GridRow {
                Toggle(
                    "Blaty osobno",
                    isOn:
                        $ustawienia
                            .osobnoBlaty
                )
                .gridCellColumns(3)
            }
        }
    }

    private func numericSettingRow(
        title: String,
        value: Binding<Double>,
        suffix: String
    ) -> some View {
        GridRow {
            Text(title)

            TextField(
                suffix,
                value: value,
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
            .frame(
                minWidth: 86
            )

            Text(suffix)
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private var warningsCard:
        some View
    {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(
                    raport.ostrzezenia
                ) {
                    warning in

                    HStack(
                        alignment: .top,
                        spacing: 10
                    ) {
                        Image(
                            systemName:
                                warning
                                    .poziom
                                    .symbol
                        )
                        .foregroundStyle(
                            warningColor(
                                warning.poziom
                            )
                        )

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(
                                warning.tytul
                            )
                            .font(
                                .subheadline
                                    .weight(
                                        .semibold
                                    )
                            )

                            Text(
                                warning.opis
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
            }
        } label: {
            Label(
                "Uwagi transportowe",
                systemImage:
                    "exclamationmark.triangle"
            )
        }
    }

    private func packageCard(
        _ package:
            PaczkaProdukcyjnaV076
    ) -> some View {
        let isPacked =
            spakowanePaczki
                .contains(package.id)
        let ocena =
            ocenaPaczkiV078(package)
        let maBlokade =
            !ocena.blokady.isEmpty

        return GroupBox {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                HStack(
                    alignment: .top,
                    spacing: 12
                ) {
                    Button {
                        if isPacked {
                            spakowanePaczki
                                .remove(
                                    package.id
                                )
                        } else if !maBlokade {
                            oznaczPaczkeJakoSpakowanaV078(
                                package
                            )
                        }

                        unieważnijEksport()
                    } label: {
                        Image(
                            systemName:
                                isPacked
                                ? "checkmark.square.fill"
                                : "square"
                        )
                        .font(.title3)
                        .foregroundStyle(
                            isPacked
                                ? Color.green
                                : (
                                    maBlokade
                                    ? Color.orange
                                    : Color.secondary
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        !isPacked
                            && maBlokade
                    )
                    .accessibilityLabel(
                        isPacked
                            ? "Oznacz paczkę jako niespakowaną"
                            : (
                                maBlokade
                                ? "Paczka zablokowana przez status formatki"
                                : "Oznacz paczkę jako spakowaną"
                            )
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        HStack(
                            spacing: 8
                        ) {
                            Text(package.kod)
                                .font(
                                    .headline
                                        .monospaced()
                                )

                            Label(
                                package.typ.nazwa,
                                systemImage:
                                    package.typ
                                        .symbol
                            )
                            .font(.caption)
                            .foregroundStyle(
                                Color.accentColor
                            )
                        }

                        Text(
                            String(
                                format:
                                    "M%02d — %@",
                                package
                                    .indeksModulu,
                                package
                                    .nazwaModulu
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    VStack(
                        alignment: .trailing,
                        spacing: 4
                    ) {
                        Text(
                            "\(formatKGV076(package.szacowanaMasaKG)) kg"
                        )
                        .font(
                            .headline
                                .monospacedDigit()
                        )
                        .foregroundStyle(
                            package
                                .przekraczaLimitMasy
                            ? Color.red
                            : Color.primary
                        )

                        Label(
                            package
                                .sposobPrzenoszenia
                                .nazwa,
                            systemImage:
                                package
                                    .sposobPrzenoszenia
                                    .symbol
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                if !ocena.problemy.isEmpty {
                    problemyStatusowV078(
                        ocena.problemy
                    )
                }

                Divider()

                ForEach(
                    package.pozycje
                ) {
                    item in
                    let traveller =
                        travellerDlaPozycjiV078(
                            item
                        )

                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 10
                    ) {
                        Text(
                            item.etykieta
                        )
                        .font(
                            .caption
                                .weight(
                                    .semibold
                                )
                                .monospaced()
                        )
                        .foregroundStyle(
                            Color.accentColor
                        )
                        .frame(
                            minWidth: 92,
                            alignment:
                                .leading
                        )

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(
                                item
                                    .kodKomponentu
                            )
                            .font(.subheadline)

                            Text(
                                "\(item.opisWymiaru) • \(item.material.opis)"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(2)
                        }

                        Spacer()

                        VStack(
                            alignment: .trailing,
                            spacing: 4
                        ) {
                            if let traveller {
                                statusPillV078(
                                    traveller.status
                                )
                            }

                            Text(
                                "\(formatKGV076(item.szacowanaMasaKG)) kg"
                            )
                            .font(
                                .caption
                                    .monospacedDigit()
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
            }
        } label: {
            HStack {
                Label(
                    maBlokade
                        ? "Blokada"
                    : isPacked
                        ? "Spakowano"
                        : "Do spakowania",
                    systemImage:
                        maBlokade
                        ? "lock.trianglebadge.exclamationmark"
                    : isPacked
                        ? "checkmark.seal.fill"
                        : "shippingbox"
                )
                .foregroundStyle(
                    maBlokade
                        ? Color.orange
                    : isPacked
                        ? Color.green
                        : Color.primary
                )

                Spacer()

                Text(
                    "\(package.liczbaElementow) elementów"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }

    private var podsumowanieContent:
        some View
    {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 18
            ) {
                summaryMetrics
                readinessCard

                if !raport
                    .ostrzezenia
                    .isEmpty {
                    warningsCard
                }

                exportCard
            }
            .padding(18)
            .frame(
                maxWidth: 1000,
                alignment: .leading
            )
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
        }
        .background(
            StolarniaPalette.canvas
        )
    }

    private var summaryMetrics:
        some View
    {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: 170
                    ),
                    spacing: 12
                )
            ],
            spacing: 12
        ) {
            summaryMetric(
                title: "Operacje",
                value:
                    "\(wykonaneOperacjeEfektywneV078.count)/\(raport.operacje.count)",
                subtitle:
                    "wykonane bez blokad",
                symbol:
                    "checklist"
            )

            summaryMetric(
                title: "Paczki",
                value:
                    "\(spakowanePaczkiEfektywneV078.count)/\(raport.paczki.count)",
                subtitle:
                    "spakowane bez blokad",
                symbol:
                    "shippingbox"
            )

            summaryMetric(
                title: "Masa",
                value:
                    "\(formatKGV076(raport.lacznaSzacowanaMasaKG)) kg",
                subtitle:
                    "wartość szacunkowa",
                symbol:
                    "scalemass"
            )

            summaryMetric(
                title: "Blokady",
                value:
                    String(
                        zablokowanePaczkiV078
                            .count
                    ),
                subtitle:
                    "paczek do decyzji",
                symbol:
                    "lock.trianglebadge.exclamationmark"
            )
        }
    }

    private func summaryMetric(
        title: String,
        value: String,
        subtitle: String,
        symbol: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                Image(
                    systemName: symbol
                )
                .font(.title3)
                .foregroundStyle(
                    Color.accentColor
                )

                Spacer()

                Text(value)
                    .font(
                        .title3
                            .bold()
                            .monospacedDigit()
                    )
            }

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: 116,
            alignment: .leading
        )
        .background(
            StolarniaPalette.canvasRaised,
            in:
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
        )
    }

    private var readinessCard:
        some View
    {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                readinessRow(
                    title:
                        "Operacje montażowe",
                    completed:
                        wykonaneOperacjeEfektywneV078
                            .count,
                    total:
                        raport.operacje
                            .count
                )

                readinessRow(
                    title:
                        "Paczki",
                    completed:
                        spakowanePaczkiEfektywneV078
                            .count,
                    total:
                        raport.paczki
                            .count
                )

                if !zablokowanePaczkiV078
                    .isEmpty {
                    Label(
                        "\(zablokowanePaczkiV078.count) paczek ma blokadę statusu formatki.",
                        systemImage:
                            "lock.trianglebadge.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        Color.orange
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {
                        ForEach(
                            zablokowanePaczkiV078
                                .prefix(5)
                        ) {
                            ocena in
                            let etykiety =
                                ocena.blokady
                                .map(\.etykieta)
                                .joined(separator: ", ")

                            Text(
                                "\(ocena.kodPaczki): \(etykiety)"
                            )
                            .font(
                                .caption2
                                    .monospaced()
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }

                if raport
                    .liczbaOperacjiDoWeryfikacji
                    > 0 {
                    Label(
                        "\(raport.liczbaOperacjiDoWeryfikacji) operacji zawiera obowiązkowy punkt kontroli.",
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        Color.orange
                    )
                }

                Text(
                    "Postęp uwzględnia statusy formatek. Paczka z elementem w defekcie, recucie albo niedokończonej produkcji nie zostanie policzona jako gotowa."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        } label: {
            Label(
                "Gotowość montażu i transportu",
                systemImage:
                    "checkmark.seal"
            )
        }
    }

    private func readinessRow(
        title: String,
        completed: Int,
        total: Int
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            HStack {
                Text(title)
                    .font(
                        .subheadline
                            .weight(
                                .semibold
                            )
                    )

                Spacer()

                Text(
                    "\(completed) z \(total)"
                )
                .font(
                    .caption
                        .monospacedDigit()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ProgressView(
                value:
                    total == 0
                    ? 0
                    : Double(completed)
                        / Double(total)
            )
        }
    }

    private var exportCard:
        some View
    {
        GroupBox {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Text(
                    "CSV zawiera operacje montażowe, status wykonania, zawartość paczek, masę szacowaną, sposób przenoszenia i ostrzeżenia."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )

                HStack {
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
                            .borderedProminent
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
                            .borderedProminent
                        )
                        .disabled(
                            raport.operacje
                                .isEmpty
                            && raport.paczki
                                .isEmpty
                        )
                    }

                    if exportURL != nil {
                        Button {
                            prepareExport()
                        } label: {
                            Label(
                                "Odśwież",
                                systemImage:
                                    "arrow.clockwise"
                            )
                        }
                        .buttonStyle(
                            .bordered
                        )
                    }
                }
            }
        } label: {
            Label(
                "Eksport produkcyjny",
                systemImage:
                    "square.and.arrow.up"
            )
        }
    }

    private func przelicz() {
        let newReport =
            MontazPakowanieEngineV076
                .build(
                    list: lista,
                    settings:
                        ustawienia
                )
        let operationIDs =
            Set(
                newReport
                    .operacje
                    .map(\.id)
            )
        let packageIDs =
            Set(
                newReport
                    .paczki
                    .map(\.id)
            )

        wykonaneOperacje =
            wykonaneOperacje
                .intersection(
                    operationIDs
                )
        spakowanePaczki =
            spakowanePaczki
                .intersection(
                    packageIDs
                )
        raport = newReport
        unieważnijEksport()
    }

    private func prepareExport() {
        do {
            exportURL =
                try MontazPakowanieCSVV076
                    .writeTemporary(
                        report: raport,
                        completedOperationIDs:
                            wykonaneOperacjeEfektywneV078,
                        packedPackageIDs:
                            spakowanePaczkiEfektywneV078,
                        travellerProvider: {
                            travellerDlaFormatkiIDV078(
                                $0
                            )
                        }
                    )
            exportError = nil
        } catch {
            exportURL = nil
            exportError =
                error.localizedDescription
        }
    }

    private func unieważnijEksport() {
        exportURL = nil
    }

    private func ocenaPaczkiV078(
        _ package:
            PaczkaProdukcyjnaV076
    ) -> OcenaStatusuPaczkiV078 {
        let problemy =
            package.pozycje
                .compactMap {
                    item in

                    problemStatusuV078(
                        formatkaID: item.id,
                        etykieta: item.etykieta,
                        traveller:
                            travellerDlaPozycjiV078(
                                item
                            )
                    )
                }

        return OcenaStatusuPaczkiV078(
            id: package.id,
            kodPaczki: package.kod,
            problemy: problemy
        )
    }

    private func ocenaOperacjiV078(
        _ operation:
            OperacjaMontazowaV076
    ) -> OcenaStatusuOperacjiV078 {
        let etykietyByID =
            Dictionary(
                uniqueKeysWithValues:
                    zip(
                        operation.formatkaIDs,
                        operation.etykietyFormatek
                    )
                    .map {
                        (
                            $0.0,
                            $0.1
                        )
                    }
            )

        let problemy =
            operation.formatkaIDs
                .compactMap {
                    id in

                    let etykieta =
                        etykietyByID[id]
                        ?? formatkiByIDV078[id]?
                        .etykieta
                        ?? id

                    return problemStatusuV078(
                        formatkaID: id,
                        etykieta: etykieta,
                        traveller:
                            travellerDlaFormatkiIDV078(
                                id
                            )
                    )
                }

        return OcenaStatusuOperacjiV078(
            id: operation.id,
            problemy: problemy
        )
    }

    private func problemStatusuV078(
        formatkaID: String,
        etykieta: String,
        traveller:
            TravellerFormatkiV078?
    ) -> ProblemStatusuFormatkiV078? {
        guard let traveller else {
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: .doCiecia,
                poziom: .blokada,
                komunikat:
                    "Brak karty statusu formatki. Otwórz listę formatek i potwierdź element."
            )
        }

        switch traveller.status {
        case .defekt:
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: traveller.status,
                poziom: .blokada,
                komunikat:
                    "Defekt wymaga decyzji technologicznej."
            )
        case .recut:
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: traveller.status,
                poziom: .blokada,
                komunikat:
                    "Element skierowany do ponownego cięcia."
            )
        case .doCiecia:
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: traveller.status,
                poziom: .blokada,
                komunikat:
                    "Formatka nie została oznaczona jako wycięta."
            )
        case .oklejanie:
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: traveller.status,
                poziom: .blokada,
                komunikat:
                    "Okleinowanie jest w toku."
            )
        case .cnc:
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: traveller.status,
                poziom: .blokada,
                komunikat:
                    "Obróbka CNC jest w toku."
            )
        case .wycieta:
            return ProblemStatusuFormatkiV078(
                formatkaID: formatkaID,
                etykieta: etykieta,
                status: traveller.status,
                poziom: .uwaga,
                komunikat:
                    "Potwierdź, czy element nie wymaga okleinowania lub CNC."
            )
        case .oklejona,
             .poCNC,
             .wPaczce,
             .gotowa:
            return nil
        }
    }

    private func travellerDlaPozycjiV078(
        _ item:
            PozycjaPaczkiV076
    ) -> TravellerFormatkiV078? {
        travellerDlaFormatkiIDV078(
            item.id
        )
    }

    private func travellerDlaFormatkiIDV078(
        _ id: String
    ) -> TravellerFormatkiV078? {
        guard let formatka =
                formatkiByIDV078[id]
        else {
            return nil
        }

        return travellerRepositoryV078
            .podglad(dla: formatka)
    }

    private func oznaczPaczkeJakoSpakowanaV078(
        _ package:
            PaczkaProdukcyjnaV076
    ) {
        for item in package.pozycje {
            guard let formatka =
                    formatkiByIDV078[item.id]
            else {
                continue
            }

            let traveller =
                travellerRepositoryV078
                .podglad(dla: formatka)

            if traveller.status != .gotowa
                && traveller.status != .wPaczce {
                travellerRepositoryV078
                    .ustawStatus(
                        .wPaczce,
                        dla: formatka,
                        opis:
                            "Spakowano w paczce \(package.kod)."
                    )
            }
        }

        spakowanePaczki.insert(
            package.id
        )
    }

    @ViewBuilder
    private func problemyStatusowV078(
        _ problemy:
            [ProblemStatusuFormatkiV078]
    ) -> some View {
        if !problemy.isEmpty {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(
                    problemy
                        .prefix(4)
                ) {
                    problem in

                    Label(
                        "\(problem.etykieta): \(problem.komunikat)",
                        systemImage:
                            problem.poziom.symbol
                    )
                    .font(.caption)
                    .foregroundStyle(
                        kolorProblemuStatusuV078(
                            problem.poziom
                        )
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                if problemy.count > 4 {
                    Text(
                        "+\(problemy.count - 4) kolejnych elementów do sprawdzenia"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                8
            )
            .background(
                Color.orange
                    .opacity(0.10),
                in:
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
            )
        }
    }

    private func statusPillV078(
        _ status:
            StatusFormatkiV078
    ) -> some View {
        Label(
            status.nazwa,
            systemImage:
                status.symbol
        )
        .font(
            .caption2
                .weight(.semibold)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .foregroundStyle(
            kolorStatusuV078(status)
        )
        .padding(
            .horizontal,
            7
        )
        .padding(
            .vertical,
            3
        )
        .background(
            kolorStatusuV078(status)
                .opacity(0.14),
            in: Capsule()
        )
    }

    private func kolorProblemuStatusuV078(
        _ poziom:
            PoziomProblemuStatusuV078
    ) -> Color {
        switch poziom {
        case .blokada:
            return .orange
        case .uwaga:
            return .yellow
        }
    }

    private func kolorStatusuV078(
        _ status:
            StatusFormatkiV078
    ) -> Color {
        switch status {
        case .defekt:
            return .red
        case .recut,
             .doCiecia,
             .oklejanie,
             .cnc:
            return .orange
        case .wPaczce,
             .gotowa:
            return .green
        case .poCNC,
             .oklejona:
            return Color.accentColor
        case .wycieta:
            return .blue
        }
    }

    private func paczkiDlaOperacjiV079(
        _ operation:
            OperacjaMontazowaV076
    ) -> [PaczkaProdukcyjnaV076] {
        let operationPartIDs =
            Set(
                operation.formatkaIDs
            )

        return raport.paczki
            .filter {
                package in

                guard package.indeksModulu
                    == operation.indeksModulu,
                      package.nazwaModulu
                    == operation.nazwaModulu else {
                    return false
                }

                guard !operationPartIDs
                    .isEmpty else {
                    return true
                }

                let packagePartIDs =
                    Set(
                        package.pozycje
                            .map(\.id)
                    )

                return !packagePartIDs
                    .isDisjoint(
                        with:
                            operationPartIDs
                    )
            }
            .sorted(
                by:
                    sortPaczkiMontazoweV079
            )
    }

    private func sortOperacjeMontazoweV079(
        _ lhs:
            OperacjaMontazowaV076,
        _ rhs:
            OperacjaMontazowaV076
    ) -> Bool {
        if lhs.indeksModulu
            != rhs.indeksModulu {
            return lhs.indeksModulu
                < rhs.indeksModulu
        }

        if lhs.etap.kolejnosc
            != rhs.etap.kolejnosc {
            return lhs.etap.kolejnosc
                < rhs.etap.kolejnosc
        }

        if lhs.kolejnosc
            != rhs.kolejnosc {
            return lhs.kolejnosc
                < rhs.kolejnosc
        }

        return lhs.tytul
            .localizedStandardCompare(
                rhs.tytul
            )
            == .orderedAscending
    }

    private func sortPaczkiMontazoweV079(
        _ lhs:
            PaczkaProdukcyjnaV076,
        _ rhs:
            PaczkaProdukcyjnaV076
    ) -> Bool {
        if lhs.indeksModulu
            != rhs.indeksModulu {
            return lhs.indeksModulu
                < rhs.indeksModulu
        }

        if lhs.typ.skrot
            != rhs.typ.skrot {
            return lhs.typ.skrot
                .localizedStandardCompare(
                    rhs.typ.skrot
                )
                == .orderedAscending
        }

        return lhs.numerWTymTypie
            < rhs.numerWTymTypie
    }

    private func kolorPaczkiKrokuV079(
        _ stepPackage:
            PaczkaKrokuMontazuV079
    ) -> Color {
        if !stepPackage.ocena
            .blokady
            .isEmpty {
            return .orange
        }

        if stepPackage.spakowana {
            return .green
        }

        return Color.accentColor
    }

    private func warningColor(
        _ level:
            PoziomOstrzezeniaPakowaniaV076
    ) -> Color {
        switch level {
        case .informacja:
            return .blue
        case .uwaga:
            return .orange
        case .blad:
            return .red
        }
    }
}

private struct KrokMontazuV079:
    Identifiable
{
    var numer: Int
    var liczbaKrokow: Int
    var operation:
        OperacjaMontazowaV076
    var ocena:
        OcenaStatusuOperacjiV078
    var paczki:
        [PaczkaKrokuMontazuV079]

    var id: String {
        operation.id
    }
}

private struct PaczkaKrokuMontazuV079:
    Identifiable
{
    var package:
        PaczkaProdukcyjnaV076
    var ocena:
        OcenaStatusuPaczkiV078
    var spakowana: Bool

    var id: String {
        package.id
    }

    var symbol: String {
        if !ocena.blokady.isEmpty {
            return "lock.trianglebadge.exclamationmark"
        }

        if spakowana {
            return "checkmark.seal.fill"
        }

        return package.typ.symbol
    }

    var opisStatusu: String {
        if !ocena.blokady.isEmpty {
            return "\(ocena.blokady.count) blokad"
        }

        if spakowana {
            return "spakowana"
        }

        return "\(package.liczbaElementow) elementów"
    }
}

private struct ModuleIdentityV076:
    Hashable
{
    var index: Int
    var name: String
}

private struct OperationGroupV076:
    Identifiable
{
    var id: String
    var index: Int
    var name: String
    var operations:
        [OperacjaMontazowaV076]
}

private enum PoziomProblemuStatusuV078:
    String,
    Hashable
{
    case blokada
    case uwaga

    var symbol: String {
        switch self {
        case .blokada:
            return "lock.trianglebadge.exclamationmark"
        case .uwaga:
            return "exclamationmark.triangle"
        }
    }
}

private struct ProblemStatusuFormatkiV078:
    Identifiable,
    Hashable
{
    var formatkaID: String
    var etykieta: String
    var status: StatusFormatkiV078
    var poziom: PoziomProblemuStatusuV078
    var komunikat: String

    var id: String {
        [
            formatkaID,
            status.rawValue,
            poziom.rawValue,
            komunikat
        ]
        .joined(separator: "|")
    }
}

private struct OcenaStatusuPaczkiV078:
    Identifiable,
    Hashable
{
    var id: String
    var kodPaczki: String
    var problemy:
        [ProblemStatusuFormatkiV078]

    var blokady:
        [ProblemStatusuFormatkiV078]
    {
        problemy.filter {
            $0.poziom == .blokada
        }
    }

    var moznaZamknac: Bool {
        blokady.isEmpty
    }
}

private struct OcenaStatusuOperacjiV078:
    Identifiable,
    Hashable
{
    var id: String
    var problemy:
        [ProblemStatusuFormatkiV078]

    var blokady:
        [ProblemStatusuFormatkiV078]
    {
        problemy.filter {
            $0.poziom == .blokada
        }
    }
}
