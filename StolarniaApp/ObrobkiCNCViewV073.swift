import SwiftUI

private enum ObrobkiCNCSheetV073:
    Identifiable
{
    case settings
    case operation(OperacjaCNCV073)

    var id: String {
        switch self {
        case .settings:
            return "settings"

        case .operation(let operation):
            return "operation-\(operation.id)"
        }
    }
}

struct ObrobkiCNCProjektuViewV073:
    View
{
    let lista:
        ListaFormatekProjektuV070

    @State private var ustawienia:
        UstawieniaObrobekCNCV073
    @State private var raport:
        RaportObrobekCNCV073
    @State private var wybranaFormatkaID:
        String?
    @State private var filtr:
        KategoriaFormatkiV070?
    @State private var szukaj = ""
    @State private var sortowanie:
        ProdukcjaSortowanieV075? =
            .domyslne
    @State private var nowaOperacjaID:
        String?
    @State private var activeSheet:
        ObrobkiCNCSheetV073?
    @State private var exportURL: URL?
    @State private var exportError: String?

    init(
        lista:
            ListaFormatekProjektuV070
    ) {
        let settings =
            UstawieniaObrobekCNCV073
                .standard
        let report =
            ObrobkiCNCEngineV073
                .build(
                    list: lista,
                    settings:
                        settings
                )

        self.lista = lista
        _ustawienia = State(
            initialValue:
                settings
        )
        _raport = State(
            initialValue:
                report
        )
        _wybranaFormatkaID =
            State(
                initialValue:
                    report
                        .pozycje
                        .first?
                        .id
            )
    }

    var body: some View {
        cncWorkspace
        .toolbar {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    activeSheet =
                        .settings
                } label: {
                    Label(
                        "Ustawienia CNC",
                        systemImage:
                            "slider.horizontal.3"
                    )
                }

                Button {
                    regeneruj()
                } label: {
                    Label(
                        "Generuj ponownie",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .disabled(
                    !ustawienia.poprawne
                    || lista.formatki
                        .isEmpty
                )

                if let exportURL {
                    ShareLink(
                        item: exportURL
                    ) {
                        Label(
                            "Eksport CNC CSV",
                            systemImage:
                                "square.and.arrow.up"
                        )
                    }
                } else {
                    Button {
                        przygotujEksport()
                    } label: {
                        Label(
                            "Przygotuj CSV",
                            systemImage:
                                "tablecells"
                        )
                    }
                    .disabled(
                        raport
                            .liczbaOperacji
                            == 0
                    )
                }
            }
        }
        .sheet(
            item: $activeSheet
        ) {
            sheet in

            activeSheetView(sheet)
        }
        .alert(
            "Nie udało się przygotować raportu",
            isPresented:
                Binding(
                    get: {
                        exportError != nil
                    },
                    set: {
                        if !$0 {
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
    }

    private var cncWorkspace:
        some View
    {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 16
            ) {
                cncSummaryCard
                cncControls
                formatkiSection
                detail
            }
            .padding(18)
            .frame(
                maxWidth: 1180,
                alignment: .top
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .scrollContentBackground(
            .hidden
        )
        .background(
            StolarniaPalette
                .canvas
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: ObrobkiCNCSheetV073
    ) -> some View {
        switch sheet {
        case .settings:
            UstawieniaObrobekCNCViewV073(
                settings:
                    $ustawienia,
                onApply: {
                    regeneruj()
                    activeSheet = nil
                }
            )

        case .operation(let operation):
            if let position =
                raport
                    .pozycje
                    .first(
                        where: {
                            $0.id
                                == operation
                                    .formatkaID
                        }
                    ) {
                EdycjaOperacjiCNCViewV073(
                    operation:
                        operation,
                    formatka:
                        position
                            .formatka,
                    onSave: {
                        updated in

                        raport.aktualizuj(
                            ObrobkiCNCEngineV073
                                .validated(
                                    updated,
                                    for:
                                        position
                                            .formatka
                                )
                        )
                        nowaOperacjaID =
                            nil
                        exportURL = nil
                        activeSheet = nil
                    },
                    onCancel: {
                        if let nowaOperacjaID {
                            raport.usun(
                                id:
                                    nowaOperacjaID
                            )
                            self
                                .nowaOperacjaID =
                                nil
                        }

                        activeSheet = nil
                    }
                )
            }
        }
    }

    private var cncSummaryCard:
        some View
    {
        podsumowanie
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                StolarniaPalette.canvasRaised,
                in:
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .stroke(
                    Color.white
                        .opacity(0.08),
                    lineWidth: 1
                )
            }
    }

    private var cncControls:
        some View
    {
        ProdukcjaListaKontrolkiV075(
            tytul:
                "Formatki CNC",
            symbol:
                "gearshape.2",
            liczbaWidocznych:
                filtrowanePozycje
                    .count,
            liczbaWszystkich:
                raport.pozycje
                    .count,
            wyszukiwanie:
                $szukaj,
            podpowiedzWyszukiwania:
                "Etykieta, moduł lub kod",
            kategoria:
                $filtr,
            sortowanie:
                $sortowanie,
            dodatkowyOpis:
                "Wybierz formatkę, sprawdź podgląd i dopracuj operacje w jednym oknie."
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                Color.white
                    .opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private var formatkiSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack(
                spacing: 12
            ) {
                Label(
                    "Formatki do obróbki",
                    systemImage:
                        "square.stack.3d.up"
                )
                .font(
                    .title3
                        .bold()
                )

                Spacer(
                    minLength: 12
                )

                ProdukcjaLicznikWynikowV075(
                    widoczne:
                        filtrowanePozycje
                            .count,
                    wszystkie:
                        raport.pozycje
                            .count
                )
            }

            if raport.pozycje
                .isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak formatek",
                    symbol:
                        "square.dashed",
                    opis:
                        "Dodaj komponenty płytowe do projektu, aby wygenerować operacje CNC."
                )
            } else if filtrowanePozycje
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
                LazyVGrid(
                    columns:
                        formatkiColumns,
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(
                        filtrowanePozycje
                    ) {
                        position in

                        Button {
                            wybranaFormatkaID =
                                position.id
                        } label: {
                            FormatkaCNCRowV073(
                                position:
                                    position
                            )
                            .padding(12)
                            .frame(
                                maxWidth:
                                    .infinity,
                                alignment:
                                    .leading
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                        .foregroundStyle(
                            .primary
                        )
                        .background {
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                            .fill(
                                wybranaPozycja?.id
                                == position.id
                                ? StolarniaPalette
                                    .accent
                                    .opacity(0.18)
                                : StolarniaPalette.canvasInset
                            )
                        }
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                            .stroke(
                                wybranaPozycja?.id
                                == position.id
                                ? StolarniaPalette
                                    .accent
                                : Color.white
                                    .opacity(0.08),
                                lineWidth:
                                    wybranaPozycja?.id
                                    == position.id
                                    ? 1.5
                                    : 1
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            StolarniaPalette.canvasRaised,
            in:
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                Color.white
                    .opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private var formatkiColumns:
        [GridItem]
    {
        [
            GridItem(
                .adaptive(
                    minimum: 260,
                    maximum: 380
                ),
                spacing: 12,
                alignment: .top
            )
        ]
    }

    private var podsumowanie:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                Label(
                    "Obróbki CNC",
                    systemImage:
                        "gearshape.2"
                )
                .font(.headline)

                Spacer()

                if raport
                    .liczbaBledow
                    > 0 {
                    Label(
                        "\(raport.liczbaBledow)",
                        systemImage:
                            "xmark.octagon.fill"
                    )
                    .foregroundStyle(
                        .red
                    )
                } else if raport
                    .liczbaDoWeryfikacji
                    > 0 {
                    Label(
                        "\(raport.liczbaDoWeryfikacji)",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )
                } else {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        .green
                    )
                }
            }

            HStack(
                spacing: 22
            ) {
                metric(
                    "\(raport.liczbaFormatekZObrobka)",
                    "formatki"
                )
                metric(
                    "\(raport.liczbaOperacji)",
                    "operacje"
                )
                metric(
                    "\(raport.liczbaDoWeryfikacji)",
                    "sprawdź"
                )
            }
        }
        .padding(16)
    }

    private func metric(
        _ value: String,
        _ label: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(value)
                .font(
                    .title3
                        .weight(
                            .semibold
                        )
                )
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
        }
    }

    @ViewBuilder
    private var detail:
        some View
    {
        if let position =
            wybranaPozycja {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                header(position)

                ObrobkiCNCPreviewV073(
                    position:
                        position
                )
                .frame(
                    height: 360
                )

                operacje(position)
            }
            .padding(16)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                StolarniaPalette.canvasRaised,
                in:
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .stroke(
                    Color.white
                        .opacity(0.08),
                    lineWidth: 1
                )
            }
        } else if raport.pozycje
            .isEmpty {
            ProdukcjaPustyStanV075(
                tytul:
                    "Brak danych CNC",
                symbol:
                    "gearshape.2",
                opis:
                    "Po dodaniu modułów obróbki zostaną wygenerowane z listy formatek."
            )
        } else if filtrowanePozycje
            .isEmpty {
            ProdukcjaPustyStanV075(
                tytul:
                    "Brak widocznej formatki",
                symbol:
                    "line.3.horizontal.decrease.circle",
                opis:
                    "Wyczyść filtry, aby ponownie wybrać element do podglądu.",
                tytulAkcji:
                    "Wyczyść filtry",
                akcja:
                    wyczyscFiltry
            )
        } else {
            ProdukcjaPustyStanV075(
                tytul:
                    "Wybierz formatkę",
                symbol:
                    "cursorarrow.click",
                opis:
                    "Wybierz element z listy formatek powyżej."
            )
        }
    }

    private func header(
        _ position:
            PozycjaObrobekCNCV073
    ) -> some View {
        ViewThatFits(
            in: .horizontal
        ) {
            HStack(
                alignment: .top,
                spacing: 16
            ) {
                headerText(position)
                    .layoutPriority(1)

                Spacer(
                    minLength: 12
                )

                addOperationButton(position)
                    .fixedSize()
            }

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                headerText(position)
                addOperationButton(position)
            }
        }
    }

    private func headerText(
        _ position:
            PozycjaObrobekCNCV073
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(
                position
                    .formatka
                    .etykieta
            )
            .font(
                .title2
                    .bold()
            )
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Text(
                position
                    .formatka
                    .nazwaModulu
            )
            .font(.headline)
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Text(
                "\(position.formatka.rolaKomponentu.nazwaProdukcyjnaV072) · \(position.formatka.opisWymiaru)"
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Text(
                position
                    .formatka
                    .material
                    .opis
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(2)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private func addOperationButton(
        _ position:
            PozycjaObrobekCNCV073
    ) -> some View {
        Button {
            let operation =
                ObrobkiCNCEngineV073
                    .blankOperation(
                        for:
                            position
                                .formatka
                    )
            raport.dodaj(
                operation
            )
            nowaOperacjaID =
                operation.id
            exportURL = nil
            activeSheet =
                .operation(operation)
        } label: {
            Label(
                "Dodaj operację",
                systemImage:
                    "plus"
            )
        }
        .buttonStyle(
            StolarniaPrimaryButtonStyle(
                minHeight: 44,
                horizontalPadding: 14,
                cornerRadius: 12
            )
        )
    }

    private func operacje(
        _ position:
            PozycjaObrobekCNCV073
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Text(
                    "Operacje"
                )
                .font(
                    .title3
                        .bold()
                )

                Spacer()

                Text(
                    "\(position.liczbaOperacji)"
                )
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(
                    .secondary
                )
            }

            if position
                .operacje
                .isEmpty {
                ProdukcjaPustyStanV075(
                    tytul:
                        "Brak operacji",
                    symbol:
                        "gearshape",
                    opis:
                        "Dodaj operację ręcznie albo zmień reguły automatyczne."
                )
            } else {
                LazyVStack(
                    spacing: 10
                ) {
                    ForEach(
                        position.operacje
                    ) {
                        operation in

                        OperacjaCNCRowV073(
                            operation:
                            operation,
                            onEdit: {
                                nowaOperacjaID =
                                    nil
                                activeSheet =
                                    .operation(operation)
                            },
                            onDelete: {
                                raport.usun(
                                    id:
                                        operation
                                            .id
                                )
                                exportURL =
                                    nil
                            }
                        )
                    }
                }
            }
        }
    }

    private var filtrowanePozycje:
        [PozycjaObrobekCNCV073]
    {
        let query =
            szukaj
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return raport
            .pozycje
            .filter {
                position in

                let categoryOK =
                    filtr == nil
                    || position
                        .formatka
                        .kategoria
                        == filtr

                guard !query.isEmpty else {
                    return categoryOK
                }

                let item =
                    position.formatka
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
                            query
                        )
            }
            .sorted {
                (
                    sortowanie
                    ?? .domyslne
                )
                .porownaj(
                    $0.formatka,
                    $1.formatka
                )
            }
    }

    private var wybranaPozycja:
        PozycjaObrobekCNCV073?
    {
        guard !filtrowanePozycje
            .isEmpty
        else {
            return nil
        }

        if let id =
            wybranaFormatkaID,
           let visible =
            filtrowanePozycje
                .first(
                    where: {
                        $0.id == id
                    }
                ) {
            return visible
        }

        return filtrowanePozycje
            .first
    }

    private func wyczyscFiltry() {
        szukaj = ""
        filtr = nil
        sortowanie = .domyslne
        wybranaFormatkaID =
            raport
                .pozycje
                .first?
                .id
    }

    private func regeneruj() {
        let reczne =
            Dictionary(
                grouping:
                    raport
                        .pozycje
                        .flatMap(
                            \.operacje
                        )
                        .filter {
                            !$0.automatyczna
                        },
                by:
                    \.formatkaID
            )

        var nowyRaport =
            ObrobkiCNCEngineV073
                .build(
                    list: lista,
                    settings:
                        ustawienia
                )

        for index in
            nowyRaport
                .pozycje
                .indices {
            let formatkaID =
                nowyRaport
                    .pozycje[index]
                    .id
            let zachowane =
                reczne[formatkaID]
                ?? []
            let zachowaneIDs =
                Set(
                    zachowane
                        .map(\.id)
                )

            nowyRaport
                .pozycje[index]
                .operacje
                .removeAll {
                    zachowaneIDs
                        .contains(
                            $0.id
                        )
                }
            nowyRaport
                .pozycje[index]
                .operacje
                .append(
                    contentsOf:
                        zachowane
                )
            nowyRaport
                .pozycje[index]
                .operacje
                .sort(
                    by:
                        ObrobkiCNCOrderingV073
                            .operacje
                )
        }

        raport = nowyRaport
        nowaOperacjaID = nil
        exportURL = nil

        if !raport
            .pozycje
            .contains(
                where: {
                    $0.id
                        == wybranaFormatkaID
                }
            ) {
            wybranaFormatkaID =
                raport
                    .pozycje
                    .first?
                    .id
        }
    }

    private func przygotujEksport() {
        do {
            exportURL =
                try ObrobkiCNCCSVV073
                    .writeTemporary(
                        report:
                            raport
                    )
            exportError = nil
        } catch {
            exportURL = nil
            exportError =
                error.localizedDescription
        }
    }
}

private struct FormatkaCNCRowV073: View {
    let position: PozycjaObrobekCNCV073

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: position.formatka.kategoria.systemImage)
                .frame(width: 24)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(position.formatka.etykieta)
                    .font(.headline)
                Text(position.formatka.nazwaModulu)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(position.formatka.opisWymiaru)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(position.liczbaOperacji)")
                    .font(.headline)
                    .monospacedDigit()
                if position.liczbaBledow > 0 {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                } else if position.liczbaDoWeryfikacji > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if !position.operacje.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OperacjaCNCRowV073: View {
    let operation: OperacjaCNCV073
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: operation.typ.symbol)
                .font(.title3)
                .frame(width: 34, height: 34)
                .stolarniaMaterial(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(operation.typ.nazwa)
                        .font(.headline)
                    Text(operation.powierzchnia.skrot)
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
                Text("X \(number(operation.xMM)) · Y \(number(operation.yMM)) mm")
                    .font(.subheadline)
                    .monospacedDigit()
                Text(operation.opisParametrow)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !operation.uwagi.isEmpty {
                    Text(operation.uwagi)
                        .font(.caption)
                        .foregroundStyle(operation.status == .blad ? Color.red : Color(uiColor: .secondaryLabel))
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: operation.status.symbol)
                    .foregroundStyle(statusColor)
                Menu {
                    Button(action: onEdit) {
                        Label("Edytuj", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Usuń", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .padding(12)
        .background(
            StolarniaPalette.canvasRaised,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    private var statusColor: Color {
        switch operation.status {
        case .gotowa: return .green
        case .doWeryfikacji: return .orange
        case .blad: return .red
        }
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct ObrobkiCNCPreviewV073: View {
    let position: PozycjaObrobekCNCV073

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Podgląd strony A", systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Spacer()
                Text("X/Y od lewego dolnego narożnika")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Canvas { context, size in
                draw(context: &context, size: size)
            }
            .background(
                StolarniaPalette.canvasRaised,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .accessibilityLabel("Schemat obróbek formatki \(position.formatka.etykieta)")
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let padding: CGFloat = 28
        let available = CGSize(
            width: max(1, size.width - 2 * padding),
            height: max(1, size.height - 2 * padding)
        )
        let length = max(1, position.formatka.dlugoscMM)
        let width = max(1, position.formatka.szerokoscMM)
        let scale = min(
            available.width / CGFloat(length),
            available.height / CGFloat(width)
        )
        let rendered = CGSize(width: CGFloat(length) * scale, height: CGFloat(width) * scale)
        let rect = CGRect(
            x: (size.width - rendered.width) / 2,
            y: (size.height - rendered.height) / 2,
            width: rendered.width,
            height: rendered.height
        )

        context.fill(Path(rect), with: .color(.secondary.opacity(0.08)))
        context.stroke(Path(rect), with: .color(.primary), lineWidth: 1.5)

        for operation in position.operacje {
            let color: Color
            switch operation.status {
            case .gotowa: color = .accentColor
            case .doWeryfikacji: color = .orange
            case .blad: color = .red
            }

            if operation.powierzchnia.jestPowierzchnia {
                if operation.typ.jestLiniowa,
                   let lineLength = operation.dlugoscMM,
                   let lineWidth = operation.szerokoscMM {
                    let pathRect = CGRect(
                        x: rect.minX + CGFloat(operation.xMM) * scale,
                        y: rect.maxY - CGFloat(operation.yMM + lineWidth) * scale,
                        width: CGFloat(lineLength) * scale,
                        height: max(2, CGFloat(lineWidth) * scale)
                    )
                    context.fill(Path(pathRect), with: .color(color.opacity(0.75)))
                } else {
                    for point in points(operation) {
                        let center = CGPoint(
                            x: rect.minX + CGFloat(point.x) * scale,
                            y: rect.maxY - CGFloat(point.y) * scale
                        )
                        let diameter = max(5, CGFloat(operation.srednicaMM ?? 5) * scale)
                        let hole = CGRect(
                            x: center.x - diameter / 2,
                            y: center.y - diameter / 2,
                            width: diameter,
                            height: diameter
                        )
                        context.fill(Path(ellipseIn: hole), with: .color(color.opacity(0.85)))
                    }
                }
            } else {
                drawEdge(operation, rect: rect, scale: scale, color: color, context: &context)
            }
        }
    }

    private func drawEdge(
        _ operation: OperacjaCNCV073,
        rect: CGRect,
        scale: CGFloat,
        color: Color,
        context: inout GraphicsContext
    ) {
        for point in points(operation) {
            var path = Path()
            let tick: CGFloat = 8
            switch operation.powierzchnia {
            case .krawedzDlugaA:
                let x = rect.minX + CGFloat(point.x) * scale
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - tick))
            case .krawedzDlugaB:
                let x = rect.minX + CGFloat(point.x) * scale
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.minY + tick))
            case .krawedzKrotkaA:
                let y = rect.maxY - CGFloat(point.x) * scale
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.minX + tick, y: y))
            case .krawedzKrotkaB:
                let y = rect.maxY - CGFloat(point.x) * scale
                path.move(to: CGPoint(x: rect.maxX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - tick, y: y))
            case .stronaA, .stronaB:
                break
            }
            context.stroke(path, with: .color(color), lineWidth: 3)
        }
    }

    private func points(_ operation: OperacjaCNCV073) -> [(x: Double, y: Double)] {
        let count = max(1, operation.liczbaPowtorzen)
        let pitch = operation.rozstawMM ?? 0
        return (0..<count).map { index in
            let distance = Double(index) * pitch
            return operation.kierunekPowtorzen == .wzdluzX
                ? (operation.xMM + distance, operation.yMM)
                : (operation.xMM, operation.yMM + distance)
        }
    }
}

private struct UstawieniaObrobekCNCViewV073: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: UstawieniaObrobekCNCV073
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Automatyczne reguły") {
                    Toggle("Rzędy System 32", isOn: $settings.generujSystem32)
                    Toggle("Rowki pod plecy", isOn: $settings.generujRowekPlecy)
                    Toggle("Połączenia korpusu", isOn: $settings.generujLaczeniaKorpusu)
                    Toggle("Puszki zawiasów", isOn: $settings.generujPuszkiZawiasow)
                }

                Section("System 32") {
                    mm("Odsunięcie rzędu", $settings.odsuniecieSystem32MM)
                    mm("Pierwszy otwór", $settings.pierwszyOtworMM)
                    mm("Skok", $settings.skokSystem32MM)
                    mm("Średnica", $settings.srednicaSystem32MM)
                    mm("Głębokość", $settings.glebokoscSystem32MM)
                }

                Section("Rowek pod plecy") {
                    mm("Odsunięcie od tyłu", $settings.odsuniecieRowkaMM)
                    mm("Szerokość", $settings.szerokoscRowkaMM)
                    mm("Głębokość", $settings.glebokoscRowkaMM)
                }

                Section("Połączenia korpusu") {
                    mm("Odsunięcie od końca", $settings.odsuniecieLaczeniaMM)
                    mm("Średnica kołka", $settings.srednicaKolkaMM)
                    mm("Głębokość kołka", $settings.glebokoscKolkaMM)
                }

                Section("Puszki zawiasów") {
                    mm("Średnica", $settings.srednicaPuszkiMM)
                    mm("Głębokość", $settings.glebokoscPuszkiMM)
                    mm("Oś od krawędzi", $settings.osPuszkiOdKrawedziMM)
                    mm("Od końca frontu", $settings.puszkaOdKoncaMM)
                }

                if !settings.poprawne {
                    Section {
                        Label(
                            "Wszystkie wartości muszą być dodatnie i skończone.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ustawienia obróbek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zastosuj", action: onApply)
                        .disabled(!settings.poprawne)
                }
            }
        }
    }

    private func mm(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                "mm",
                value: value,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 110)
            Text("mm")
                .foregroundStyle(.secondary)
        }
    }
}

private struct EdycjaOperacjiCNCViewV073: View {
    @State private var draft: OperacjaCNCV073

    let formatka: FormatkaProjektuV070
    let onSave: (OperacjaCNCV073) -> Void
    let onCancel: () -> Void

    init(
        operation: OperacjaCNCV073,
        formatka: FormatkaProjektuV070,
        onSave: @escaping (OperacjaCNCV073) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: operation)
        self.formatka = formatka
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Operacja") {
                    Picker("Typ", selection: $draft.typ) {
                        ForEach(TypOperacjiCNCV073.allCases) { Text($0.nazwa).tag($0) }
                    }
                    Picker("Powierzchnia", selection: $draft.powierzchnia) {
                        ForEach(PowierzchniaObrobkiV073.allCases) { Text($0.nazwa).tag($0) }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(StatusOperacjiCNCV073.allCases) { Text($0.nazwa).tag($0) }
                    }
                }

                Section("Pozycja") {
                    mm("X", $draft.xMM)
                    mm("Y", $draft.yMM)
                    mm("Głębokość", $draft.glebokoscMM)
                }

                Section("Narzędzie") {
                    if draft.typ.wymagaSrednicy {
                        optionalMM("Średnica", $draft.srednicaMM)
                    }
                    if draft.typ.jestLiniowa {
                        optionalMM("Długość", $draft.dlugoscMM)
                        optionalMM("Szerokość", $draft.szerokoscMM)
                    }
                }

                Section("Powtórzenia") {
                    Stepper(
                        "Liczba: \(draft.liczbaPowtorzen)",
                        value: $draft.liczbaPowtorzen,
                        in: 1...500
                    )
                    if draft.liczbaPowtorzen > 1 {
                        optionalMM("Rozstaw", $draft.rozstawMM)
                        Picker("Kierunek", selection: $draft.kierunekPowtorzen) {
                            ForEach(KierunekPowtorzenV073.allCases) { Text($0.nazwa).tag($0) }
                        }
                    }
                }

                Section("Uwagi") {
                    TextField("Uwagi technologiczne", text: $draft.uwagi, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Label(
                        "\(formatka.etykieta) · \(formatka.opisWymiaru)",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edycja operacji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        var saved = draft
                        saved.automatyczna = false
                        onSave(saved)
                    }
                }
            }
        }
    }

    private func mm(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                "mm",
                value: value,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 120)
            Text("mm").foregroundStyle(.secondary)
        }
    }

    private func optionalMM(_ title: String, _ value: Binding<Double?>) -> some View {
        mm(
            title,
            Binding(
                get: { value.wrappedValue ?? 0 },
                set: { value.wrappedValue = $0 > 0 ? $0 : nil }
            )
        )
    }
}
