import SwiftUI

private enum KartaTechnicznaSzafkiSheet:
    Identifiable
{
    case drawerConfigurator
    case accessoryRules
    case drillingTemplates
    case pdfShare(KartaTechnicznaPDFShareItem)
    case element(ElementTechnicznySzafki)

    var id: String {
        switch self {
        case .drawerConfigurator:
            return "drawer-configurator"

        case .accessoryRules:
            return "accessory-rules"

        case .drillingTemplates:
            return "drilling-templates"

        case .pdfShare(let item):
            return "pdf-share-\(item.id)"

        case .element(let element):
            return "element-\(element.id)"
        }
    }
}

struct KartaTechnicznaSzafkiView:
    View
{
    @State private var card:
        KartaTechnicznaSzafki

    @Environment(\.dismiss)
    private var dismiss

    @State private var activeSheet:
        KartaTechnicznaSzafkiSheet?

    @State private var pdfErrorMessage:
        String?

    @State private var showingPDFError =
        false

    @State private var isGeneratingPDF =
        false

    init(
        card:
            KartaTechnicznaSzafki
    ) {
        _card = State(
            initialValue: card
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Szafka") {
                    LabeledContent(
                        "Numer",
                        value:
                            card.numerSzafki
                    )

                    TextField(
                        "Nazwa",
                        text:
                            $card.nazwa
                    )

                    LabeledContent(
                        "Konstrukcja",
                        value:
                            card.rodzajKonstrukcji
                    )

                    LabeledContent(
                        "Wymiary",
                        value:
                            dimensions
                    )
                }

                Section("Rysunek techniczny") {
                    drawing
                        .frame(
                            minHeight: 360
                        )
                        .listRowInsets(
                            EdgeInsets()
                        )
                }


                if let slopeReport =
                    card.raportPaneliSkosuV0691 {
                    Section(
                        "Panele pod skosem"
                    ) {
                        LabeledContent(
                            "Liczba paneli",
                            value:
                                "\(slopeReport.panele.count)"
                        )

                        LabeledContent(
                            "Profil",
                            value:
                                slopeReport
                                    .profilID
                                    .uuidString
                                    .prefix(8)
                                    .uppercased()
                        )

                        ForEach(
                            slopeReport.panele
                        ) { panel in
                            VStack(
                                alignment: .leading,
                                spacing: 5
                            ) {
                                HStack {
                                    Text(panel.kod)
                                        .font(
                                            .headline
                                                .monospaced()
                                        )

                                    Spacer()

                                    Text(
                                        "\(formatted(panel.szerokoscObrysuMM)) × \(formatted(panel.wysokoscObrysuMM)) mm"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }

                                Text(panel.nazwa)
                                    .font(.subheadline)

                                Text(
                                    "Pole \(formatted(panel.poleMM2 / 1_000_000)) m² • obwód \(formatted(panel.obwodMM)) mm"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )

                                if abs(
                                    panel
                                        .katMontazuStopnie
                                ) > 0.01 {
                                    Text(
                                        "Kąt montażu \(formatted(panel.katMontazuStopnie))°"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }

                                if panel.wymagaSzablonu {
                                    Label(
                                        "Wymagany szablon fizyczny",
                                        systemImage:
                                            "exclamationmark.triangle.fill"
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(
                                        .orange
                                    )
                                }
                            }
                            .padding(
                                .vertical,
                                3
                            )
                        }

                        ForEach(
                            slopeReport
                                .ostrzezenia,
                            id: \.self
                        ) { warning in
                            Label(
                                warning,
                                systemImage:
                                    "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .orange
                            )
                        }
                    }
                }

                Section("Zamknięcie bryły") {
                    Toggle(
                        "Blenda lewa",
                        isOn:
                            enclosureBinding(
                                \.blendaLewa
                            )
                    )

                    if card
                        .efektywneZamkniecieBryly
                        .blendaLewa {
                        enclosureNumberField(
                            "Szerokość blendy lewej",
                            keyPath:
                                \.szerokoscBlendyLewejMM
                        )
                    }

                    Toggle(
                        "Blenda prawa",
                        isOn:
                            enclosureBinding(
                                \.blendaPrawa
                            )
                    )

                    if card
                        .efektywneZamkniecieBryly
                        .blendaPrawa {
                        enclosureNumberField(
                            "Szerokość blendy prawej",
                            keyPath:
                                \.szerokoscBlendyPrawejMM
                        )
                    }

                    Toggle(
                        "Wieniec górny",
                        isOn:
                            enclosureBinding(
                                \.wieniecGorny
                            )
                    )

                    if card
                        .efektywneZamkniecieBryly
                        .wieniecGorny {
                        enclosureNumberField(
                            "Wysunięcie wieńca górnego",
                            keyPath:
                                \.wysuniecieWiencaGornegoMM
                        )
                    }

                    Toggle(
                        "Wieniec dolny",
                        isOn:
                            enclosureBinding(
                                \.wieniecDolny
                            )
                    )

                    if card
                        .efektywneZamkniecieBryly
                        .wieniecDolny {
                        enclosureNumberField(
                            "Wysunięcie wieńca dolnego",
                            keyPath:
                                \.wysuniecieWiencaDolnegoMM
                        )
                    }

                    Toggle(
                        "Ścianka boczna lewa",
                        isOn:
                            enclosureBinding(
                                \.sciankaBocznaLewa
                            )
                    )

                    Toggle(
                        "Ścianka boczna prawa",
                        isOn:
                            enclosureBinding(
                                \.sciankaBocznaPrawa
                            )
                    )

                    if card
                        .efektywneZamkniecieBryly
                        .sciankaBocznaLewa
                        || card
                            .efektywneZamkniecieBryly
                            .sciankaBocznaPrawa {
                        enclosureNumberField(
                            "Wysunięcie przed front",
                            keyPath:
                                \.wysuniecieScianekPrzedFrontMM
                        )

                        Text(
                            "Domyślne 20 mm (2 cm) pozwala schować fronty między ściankami i wizualnie zamknąć bryłę."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Section("Szuflady") {
                    HStack {
                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text(
                                "\(card.efektywneSzuflady.count) szuflad"
                            )
                            .font(.headline)

                            Text(
                                drawerFitSummary
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Spacer()

                        Button {
                            activeSheet =
                                .drawerConfigurator
                        } label: {
                            Label(
                                card
                                    .efektywneSzuflady
                                    .isEmpty
                                ? "Dodaj"
                                : "Edytuj",
                                systemImage:
                                    "shippingbox.and.arrow.backward"
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                    }

                    if !card
                        .efektywneSzuflady
                        .isEmpty {
                        ForEach(
                            card
                                .efektywneSzuflady
                        ) { drawer in
                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {
                                Text(
                                    drawer.etykieta
                                )
                                .font(
                                    .headline
                                        .monospaced()
                                )

                                Text(
                                    "\(drawer.typFrontu.nazwa) • front \(formatted(drawer.wysokoscFrontuMM)) mm • L \(formatted(drawer.nominalnaDlugoscMM)) mm • cofnięcie \(formatted(drawer.efektywneCofniecieOdFrontuMM)) mm"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }
                }

                Section("Okucia i akcesoria") {
                    HStack {
                        Text(
                            "\(card.efektywneAkcesoria.count) pozycji"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Spacer()

                        Button {
                            activeSheet =
                                .accessoryRules
                        } label: {
                            Label(
                                "Katalog",
                                systemImage:
                                    "wrench.adjustable"
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                    }

                    if card
                        .efektywneAkcesoria
                        .isEmpty {
                        Text(
                            "Nie przypisano jeszcze okuć ani akcesoriów."
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    } else {
                        ForEach(
                            card
                                .efektywneAkcesoria
                        ) { accessory in
                            VStack(
                                alignment:
                                    .leading,
                                spacing: 4
                            ) {
                                HStack {
                                    Text(
                                        "\(accessory.producent) \(accessory.rodzina)"
                                    )
                                    .font(.headline)

                                    Spacer()

                                    Text(
                                        "×\(accessory.ilosc)"
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }

                                Text(
                                    accessory.model
                                )
                                .font(.subheadline)

                                if !accessory
                                    .docelowaEtykietaElementu
                                    .isEmpty {
                                    Text(
                                        "Element: \(accessory.docelowaEtykietaElementu)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }
                            }
                            .padding(
                                .vertical,
                                3
                            )
                        }
                        .onDelete {
                            card
                                .efektywneAkcesoria
                                .remove(
                                    atOffsets: $0
                                )
                        }
                    }
                }

                Section("Elementy szafki") {
                    HStack {
                        Text(
                            "\(card.efektywneElementy.count) elementów"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Spacer()

                        Button {
                            card.efektywneElementy =
                                KartaTechnicznaSzafkiBuilder
                                    .regenerateElements(
                                        for: card
                                    )
                        } label: {
                            Label(
                                "Regeneruj",
                                systemImage:
                                    "arrow.clockwise"
                            )
                        }
                    }

                    ForEach(
                        card.efektywneElementy
                    ) { element in
                        Button {
                            activeSheet =
                                .element(element)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Text(
                                        element.etykieta
                                    )
                                    .font(
                                        .headline
                                            .monospaced()
                                    )

                                    Text(
                                        element.nazwa
                                    )
                                    .font(.subheadline)

                                    Text(
                                        "\(formatted(element.dlugoscMM)) × \(formatted(element.szerokoscMM)) × \(formatted(element.gruboscMM)) mm • \(element.ilosc) szt."
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
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
                    }
                    .onDelete {
                        card
                            .efektywneElementy
                            .remove(
                                atOffsets: $0
                            )
                    }
                }

                Section("Punkty wiercenia") {
                    if card
                        .punktyWiercenia
                        .isEmpty {
                        ContentUnavailableView(
                            "Brak punktów wiercenia",
                            systemImage:
                                "circle.dotted"
                        )
                    } else {
                        ForEach(
                            $card
                                .punktyWiercenia
                        ) {
                            $point in

                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                HStack {
                                    Label(
                                        point.typ
                                            .nazwa,
                                        systemImage:
                                            point.typ
                                                == .prowadnica
                                            ? "line.3.horizontal"
                                            : "circle.circle"
                                    )

                                    Spacer()

                                    Text(
                                        point.element
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }

                                HStack {
                                    valueField(
                                        "X",
                                        value:
                                            $point.xMM
                                    )

                                    valueField(
                                        "Y",
                                        value:
                                            $point.yMM
                                    )

                                    valueField(
                                        "Ø",
                                        value:
                                            $point
                                                .srednicaMM
                                    )

                                    valueField(
                                        "Gł.",
                                        value:
                                            $point
                                                .glebokoscMM
                                    )
                                }

                                TextField(
                                    "Opis",
                                    text:
                                        $point.opis,
                                    axis:
                                        .vertical
                                )
                            }
                            .padding(
                                .vertical,
                                6
                            )
                        }
                        .onDelete {
                            card
                                .punktyWiercenia
                                .remove(
                                    atOffsets: $0
                                )
                        }
                    }

                    Button {
                        card
                            .punktyWiercenia
                            .append(
                                PunktWierceniaSzafki(
                                    element:
                                        "Nowy element"
                                )
                            )
                    } label: {
                        Label(
                            "Dodaj punkt wiercenia",
                            systemImage: "plus"
                        )
                    }
                }

                Section("Materiały") {
                    LabeledContent(
                        "Korpus",
                        value:
                            card.materialKorpusu
                    )

                    LabeledContent(
                        "Front",
                        value:
                            card.materialFrontu
                    )
                }

                if !card.wneki.isEmpty {
                    Section {
                        ForEach(
                            card.wneki
                        ) { wneka in
                            VStack(
                                alignment:
                                    .leading,
                                spacing:
                                    6
                            ) {
                                Text(
                                    wneka.etykieta
                                        .isEmpty
                                    ? "Wnęka bez nazwy"
                                    : wneka.etykieta
                                )
                                .font(.headline)

                                LabeledContent(
                                    "Wymiar otworu",
                                    value:
                                        wneka.opisWymiaru
                                )

                                if wneka.odPodlogiMM
                                    > 0
                                {
                                    LabeledContent(
                                        "Od podłogi",
                                        value:
                                            "\(Int(wneka.odPodlogiMM)) mm"
                                    )
                                }

                                LabeledContent(
                                    "Dostęp",
                                    value:
                                        wneka.otwartaZPrzodu
                                        ? "Otwarty z przodu"
                                        : "Wymaga drzwiczek"
                                )

                                if !wneka.uwagi
                                    .isEmpty
                                {
                                    Text(wneka.uwagi)
                                        .font(
                                            .caption
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Label(
                            "Wnęki specjalne",
                            systemImage:
                                "square.split.bottomrightquarter"
                        )
                    } footer: {
                        Text(
                            "Wymiary odnoszą się do otworu (wolna przestrzeń). Uwzględnij podziały i grubości boczków przy projektowaniu."
                        )
                        .font(.caption2)
                    }
                }

                Section("Uwagi") {
                    TextEditor(
                        text:
                            $card.uwagi
                    )
                    .frame(
                        minHeight: 100
                    )
                }
            }
            .navigationTitle(
                "Karta techniczna"
            )
            .sheet(
                item:
                    $activeSheet
            ) {
                sheet in

                activeSheetView(sheet)
            }
            .alert(
                "Nie udało się utworzyć PDF",
                isPresented:
                    $showingPDFError
            ) {
                Button("OK") {
                    pdfErrorMessage = nil
                }
            } message: {
                Text(
                    pdfErrorMessage
                    ?? "Nieznany błąd."
                )
            }
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(
                    placement:
                        .confirmationAction
                ) {
                    Button {
                        generateTechnicalPDF()
                    } label: {
                        Label(
                            isGeneratingPDF
                            ? "Tworzenie PDF"
                            : "Eksport PDF",
                            systemImage:
                                "doc.richtext"
                        )
                    }
                    .disabled(
                        isGeneratingPDF
                    )

                    Button {
                        activeSheet =
                            .drawerConfigurator
                    } label: {
                        Label(
                            "Szuflady",
                            systemImage:
                                "shippingbox.and.arrow.backward"
                        )
                    }

                    Button {
                        activeSheet =
                            .accessoryRules
                    } label: {
                        Label(
                            "Akcesoria",
                            systemImage:
                                "wrench.adjustable"
                        )
                    }

                    Button {
                        activeSheet =
                            .drillingTemplates
                    } label: {
                        Label(
                            "Szablony wierceń",
                            systemImage:
                                "scope"
                        )
                    }

                    Button("Zapisz") {
                        card.dataAktualizacji =
                            Date()
                        KartaTechnicznaSzafkiStore
                            .save(card)
                        dismiss()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: KartaTechnicznaSzafkiSheet
    ) -> some View {
        switch sheet {
        case .drawerConfigurator:
            SzufladyModuluView(
                karta: $card
            )

        case .accessoryRules:
            KatalogRegulAkcesoriowView(
                karta: $card
            )

        case .drillingTemplates:
            SzablonyWiercenOkucView()

        case .pdfShare(let item):
            KartaTechnicznaPDFShareSheet(
                url: item.url
            )

        case .element(let element):
            ElementTechnicznySzafkiView(
                element: element
            ) { updated in
                guard let index =
                    card
                        .efektywneElementy
                        .firstIndex(
                            where: {
                                $0.id
                                == updated.id
                            }
                        )
                else {
                    return
                }

                card
                    .efektywneElementy[
                        index
                    ] = updated
            }
        }
    }

    private var drawerFitSummary:
        String
    {
        guard !card
            .efektywneSzuflady
            .isEmpty
        else {
            return "Brak skonfigurowanego układu."
        }

        let collisions =
            SzufladyModuluEngine
                .waliduj(
                    szuflady:
                        card
                            .efektywneSzuflady,
                    w: card
                )

        let errors =
            collisions.filter {
                $0.poziom == .blad
            }.count
        let warnings =
            collisions.filter {
                $0.poziom
                    == .ostrzezenie
            }.count

        if errors > 0 {
            return "\(errors) błędów kolizji"
        }

        if warnings > 0 {
            return "\(warnings) ostrzeżeń"
        }

        return "Układ mieści się w korpusie"
    }

    private var dimensions:
        String
    {
        "\(formatted(card.szerokoscMM)) × \(formatted(card.wysokoscMM)) × \(formatted(card.glebokoscMM)) mm"
    }

    private var drawing:
        some View
    {
        GeometryReader { proxy in
            let inset:
                CGFloat = 44
            let available =
                CGSize(
                    width:
                        max(
                            proxy.size.width
                            - inset * 2,
                            1
                        ),
                    height:
                        max(
                            proxy.size.height
                            - inset * 2,
                            1
                        )
                )

            let scale =
                min(
                    available.width
                    / max(
                        card.szerokoscMM,
                        1
                    ),
                    available.height
                    / max(
                        card.wysokoscMM,
                        1
                    )
                )

            let cabinetSize =
                CGSize(
                    width:
                        card.szerokoscMM
                        * scale,
                    height:
                        card.wysokoscMM
                        * scale
                )

            let origin =
                CGPoint(
                    x:
                        (
                            proxy.size.width
                            - cabinetSize.width
                        ) / 2,
                    y:
                        (
                            proxy.size.height
                            - cabinetSize.height
                        ) / 2
                )

            ZStack {
                RoundedRectangle(
                    cornerRadius: 18
                )
                .fill(
                    .regularMaterial
                )

                Path { path in
                    path.addRect(
                        CGRect(
                            origin: origin,
                            size:
                                cabinetSize
                        )
                    )
                }
                .stroke(
                    .primary,
                    lineWidth: 2
                )

                enclosureOverlay(
                    origin: origin,
                    cabinetSize:
                        cabinetSize,
                    scale: scale
                )

                drawerOverlay(
                    origin: origin,
                    cabinetSize:
                        cabinetSize,
                    scale: scale
                )

                ForEach(
                    card.punktyWiercenia
                ) { point in
                    let x =
                        origin.x
                        + min(
                            max(
                                point.xMM,
                                0
                            ),
                            card
                                .szerokoscMM
                        )
                        * scale

                    let y =
                        origin.y
                        + cabinetSize.height
                        - min(
                            max(
                                point.yMM,
                                0
                            ),
                            card
                                .wysokoscMM
                        )
                        * scale

                    Circle()
                        .fill(
                            point.typ
                                == .prowadnica
                            ? Color.orange
                            : Color.accentColor
                        )
                        .frame(
                            width: 12,
                            height: 12
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    .white,
                                    lineWidth: 2
                                )
                        }
                        .position(
                            x: x,
                            y: y
                        )
                }
            }
        }
    }

    private func generateTechnicalPDF() {
        guard !isGeneratingPDF else {
            return
        }

        isGeneratingPDF = true

        do {
            let url =
                try KartaTechnicznaPDFBuilder
                    .build(
                        card: card
                    )

            activeSheet =
                .pdfShare(
                    KartaTechnicznaPDFShareItem(
                        url: url
                    )
                )
        } catch {
            pdfErrorMessage =
                error.localizedDescription
            showingPDFError =
                true
        }

        isGeneratingPDF = false
    }

    private func enclosureBinding(
        _ keyPath:
            WritableKeyPath<
                ZamkniecieBrylySzafki,
                Bool
            >
    ) -> Binding<Bool> {
        Binding(
            get: {
                card
                    .efektywneZamkniecieBryly[
                        keyPath: keyPath
                    ]
            },
            set: { value in
                var enclosure =
                    card
                        .efektywneZamkniecieBryly

                enclosure[
                    keyPath: keyPath
                ] = value

                card
                    .efektywneZamkniecieBryly =
                        enclosure
            }
        )
    }

    private func enclosureNumberField(
        _ title: String,
        keyPath:
            WritableKeyPath<
                ZamkniecieBrylySzafki,
                Double
            >
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value:
                    Binding(
                        get: {
                            card
                                .efektywneZamkniecieBryly[
                                    keyPath:
                                        keyPath
                                ]
                        },
                        set: { value in
                            var enclosure =
                                card
                                    .efektywneZamkniecieBryly

                            enclosure[
                                keyPath:
                                    keyPath
                            ] = max(
                                value,
                                0
                            )

                            card
                                .efektywneZamkniecieBryly =
                                    enclosure
                        }
                    ),
                format:
                    .number.precision(
                        .fractionLength(
                            0...1
                        )
                    )
            )
            .keyboardType(
                .decimalPad
            )
            .multilineTextAlignment(
                .trailing
            )
            .frame(width: 90)

            Text("mm")
                .foregroundStyle(
                    .secondary
                )
        }
    }

    @ViewBuilder
    private func drawerOverlay(
        origin: CGPoint,
        cabinetSize: CGSize,
        scale: CGFloat
    ) -> some View {
        let bottomThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ == .dno
                    || $0.typ
                        == .wieniecDolny
                }?
                .gruboscMM
            ?? 18

        ForEach(
            card
                .efektywneSzuflady
                .filter(\.aktywna)
        ) { drawer in
            let frontHeight =
                max(
                    drawer
                        .wysokoscFrontuMM
                    * scale,
                    1
                )

            let bottomY =
                drawer.pozycjaDolnaYMM
                + bottomThickness

            let centerY =
                origin.y
                + cabinetSize.height
                - (
                    bottomY
                    + drawer
                        .wysokoscFrontuMM
                        / 2
                )
                * scale

            RoundedRectangle(
                cornerRadius: 2
            )
            .fill(
                Color.accentColor
                    .opacity(0.08)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 2
                )
                .stroke(
                    Color.accentColor,
                    lineWidth: 1
                )
            }
            .frame(
                width:
                    max(
                        cabinetSize.width
                        - 4,
                        1
                    ),
                height:
                    frontHeight
            )
            .position(
                x:
                    origin.x
                    + cabinetSize.width / 2,
                y: centerY
            )

            Text(drawer.etykieta)
                .font(
                    .system(
                        size: 8,
                        design:
                            .monospaced
                    )
                    .weight(
                        .semibold
                    )
                )
                .lineLimit(1)
                .position(
                    x:
                        origin.x
                        + cabinetSize.width / 2,
                    y: centerY
                )
        }
    }

    @ViewBuilder
    private func enclosureOverlay(
        origin: CGPoint,
        cabinetSize: CGSize,
        scale: CGFloat
    ) -> some View {
        let enclosure =
            card.efektywneZamkniecieBryly

        if enclosure.blendaLewa {
            Rectangle()
                .fill(
                    Color.accentColor
                        .opacity(0.18)
                )
                .frame(
                    width:
                        max(
                            enclosure
                                .szerokoscBlendyLewejMM
                            * scale,
                            4
                        ),
                    height:
                        cabinetSize.height
                )
                .position(
                    x:
                        origin.x
                        - max(
                            enclosure
                                .szerokoscBlendyLewejMM
                            * scale,
                            4
                        ) / 2,
                    y:
                        origin.y
                        + cabinetSize.height / 2
                )
        }

        if enclosure.blendaPrawa {
            Rectangle()
                .fill(
                    Color.accentColor
                        .opacity(0.18)
                )
                .frame(
                    width:
                        max(
                            enclosure
                                .szerokoscBlendyPrawejMM
                            * scale,
                            4
                        ),
                    height:
                        cabinetSize.height
                )
                .position(
                    x:
                        origin.x
                        + cabinetSize.width
                        + max(
                            enclosure
                                .szerokoscBlendyPrawejMM
                            * scale,
                            4
                        ) / 2,
                    y:
                        origin.y
                        + cabinetSize.height / 2
                )
        }

        if enclosure.wieniecGorny {
            Rectangle()
                .fill(
                    Color.orange
                        .opacity(0.22)
                )
                .frame(
                    width:
                        cabinetSize.width,
                    height:
                        max(
                            enclosure
                                .gruboscWiencaGornegoMM
                            * scale,
                            4
                        )
                )
                .position(
                    x:
                        origin.x
                        + cabinetSize.width / 2,
                    y:
                        origin.y
                        - max(
                            enclosure
                                .gruboscWiencaGornegoMM
                            * scale,
                            4
                        ) / 2
                )
        }

        if enclosure.wieniecDolny {
            Rectangle()
                .fill(
                    Color.orange
                        .opacity(0.22)
                )
                .frame(
                    width:
                        cabinetSize.width,
                    height:
                        max(
                            enclosure
                                .gruboscWiencaDolnegoMM
                            * scale,
                            4
                        )
                )
                .position(
                    x:
                        origin.x
                        + cabinetSize.width / 2,
                    y:
                        origin.y
                        + cabinetSize.height
                        + max(
                            enclosure
                                .gruboscWiencaDolnegoMM
                            * scale,
                            4
                        ) / 2
                )
        }

        if enclosure.sciankaBocznaLewa {
            Rectangle()
                .stroke(
                    Color.green,
                    lineWidth: 4
                )
                .frame(
                    width: 4,
                    height:
                        cabinetSize.height
                )
                .position(
                    x: origin.x,
                    y:
                        origin.y
                        + cabinetSize.height / 2
                )
        }

        if enclosure.sciankaBocznaPrawa {
            Rectangle()
                .stroke(
                    Color.green,
                    lineWidth: 4
                )
                .frame(
                    width: 4,
                    height:
                        cabinetSize.height
                )
                .position(
                    x:
                        origin.x
                        + cabinetSize.width,
                    y:
                        origin.y
                        + cabinetSize.height / 2
                )
        }
    }

    private func valueField(
        _ title: String,
        value:
            Binding<Double>
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)

            TextField(
                title,
                value: value,
                format:
                    .number.precision(
                        .fractionLength(
                            0...1
                        )
                    )
            )
            .keyboardType(
                .decimalPad
            )
            .frame(width: 64)

            Text("mm")
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private func formatted(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }
}


private struct ElementTechnicznySzafkiView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @State private var draft:
        ElementTechnicznySzafki

    @StateObject private var templateRepository =
        SzablonyWiercenOkucRepository()

    @State private var selectedTemplateID:
        UUID?

    @State private var baseYMM = 0.0

    @State private var showingSystem32 =
        false

    let onSave:
        (ElementTechnicznySzafki)
        -> Void

    init(
        element:
            ElementTechnicznySzafki,
        onSave:
            @escaping
            (ElementTechnicznySzafki)
            -> Void
    ) {
        _draft = State(
            initialValue: element
        )
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Etykieta") {
                    TextField(
                        "Etykieta",
                        text:
                            $draft.etykieta
                    )
                    .font(
                        .body.monospaced()
                    )

                    Picker(
                        "Typ",
                        selection:
                            $draft.typ
                    ) {
                        ForEach(
                            TypElementuSzafki
                                .allCases
                        ) { type in
                            Text(
                                "\(type.kod) — \(type.nazwa)"
                            )
                            .tag(type)
                        }
                    }

                    TextField(
                        "Nazwa elementu",
                        text:
                            $draft.nazwa
                    )
                }

                Section("Wymiary") {
                    numberField(
                        "Długość",
                        value:
                            $draft.dlugoscMM
                    )

                    numberField(
                        "Szerokość",
                        value:
                            $draft.szerokoscMM
                    )

                    numberField(
                        "Grubość",
                        value:
                            $draft.gruboscMM
                    )

                    Stepper(
                        "Liczba sztuk: \(draft.ilosc)",
                        value:
                            $draft.ilosc,
                        in: 1...999
                    )
                }

                Section("Materiał") {
                    TextField(
                        "Materiał",
                        text:
                            $draft.material
                    )

                    Picker(
                        "Kierunek",
                        selection:
                            $draft.kierunek
                    ) {
                        ForEach(
                            KierunekElementuSzafki
                                .allCases
                        ) { direction in
                            Text(direction.nazwa)
                                .tag(direction)
                        }
                    }
                }

                Section("Rysunek elementu") {
                    GeometryReader { proxy in
                        let inset:
                            CGFloat = 34
                        let availableWidth =
                            max(
                                proxy.size.width
                                - inset * 2,
                                1
                            )
                        let availableHeight =
                            max(
                                proxy.size.height
                                - inset * 2,
                                1
                            )

                        let scale =
                            min(
                                availableWidth
                                / max(
                                    draft.szerokoscMM,
                                    1
                                ),
                                availableHeight
                                / max(
                                    draft.dlugoscMM,
                                    1
                                )
                            )

                        let width =
                            draft.szerokoscMM
                            * scale
                        let height =
                            draft.dlugoscMM
                            * scale

                        ZStack {
                            RoundedRectangle(
                                cornerRadius: 16
                            )
                            .fill(
                                .regularMaterial
                            )

                            Rectangle()
                                .stroke(
                                    .primary,
                                    lineWidth: 2
                                )
                                .frame(
                                    width: width,
                                    height: height
                                )

                            ForEach(
                                draft
                                    .punktyWiercenia
                            ) { point in
                                Circle()
                                    .fill(
                                        Color
                                            .accentColor
                                    )
                                    .frame(
                                        width: 12,
                                        height: 12
                                    )
                                    .position(
                                        x:
                                            proxy
                                                .size
                                                .width / 2
                                            - width / 2
                                            + min(
                                                max(
                                                    point.xMM,
                                                    0
                                                ),
                                                draft
                                                    .szerokoscMM
                                            )
                                            * scale,
                                        y:
                                            proxy
                                                .size
                                                .height / 2
                                            + height / 2
                                            - min(
                                                max(
                                                    point.yMM,
                                                    0
                                                ),
                                                draft
                                                    .dlugoscMM
                                            )
                                            * scale
                                    )
                            }

                            Text(
                                draft.etykieta
                            )
                            .font(
                                .caption
                                    .monospaced()
                                    .weight(
                                        .semibold
                                    )
                            )
                            .padding(6)
                            .background(
                                .thinMaterial,
                                in: Capsule()
                            )
                        }
                    }
                    .frame(
                        minHeight: 300
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                }

                if draft.typ
                    == .scianaBoczna
                    || draft.typ
                        == .sciankaMaskujaca {
                    Section("System 32") {
                        Button {
                            showingSystem32 =
                                true
                        } label: {
                            Label(
                                "Konfiguruj System 32",
                                systemImage:
                                    "circle.grid.cross"
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )

                        LabeledContent(
                            "Punkty Systemu 32",
                            value:
                                "\(system32PointCount)"
                        )

                        if let parameters =
                            draft.parametrySystemu32 {
                            LabeledContent(
                                "Skok",
                                value:
                                    "\(parameters.skokMM.formatted(.number.precision(.fractionLength(0...1)))) mm"
                            )

                            LabeledContent(
                                "Odsunięcie przód",
                                value:
                                    "\(parameters.efektywnyOdsunPrzodMM.formatted(.number.precision(.fractionLength(0...1)))) mm"
                            )
                        }
                    }
                }

                Section("Zastosuj szablon okucia") {
                    Picker(
                        "Szablon",
                        selection:
                            $selectedTemplateID
                    ) {
                        Text("Wybierz")
                            .tag(
                                Optional<UUID>.none
                            )

                        ForEach(
                            matchingTemplates
                        ) { template in
                            Text(
                                "\(template.nazwa) • \(template.kodOkucia)"
                            )
                            .tag(
                                Optional(
                                    template.id
                                )
                            )
                        }
                    }

                    HStack {
                        Text(
                            "Wysokość bazowa Y"
                        )

                        Spacer()

                        TextField(
                            "Y",
                            value:
                                $baseYMM,
                            format:
                                .number.precision(
                                    .fractionLength(
                                        0...1
                                    )
                                )
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(width: 90)

                        Text("mm")
                            .foregroundStyle(
                                .secondary
                            )
                    }

                    Button {
                        applySelectedTemplate()
                    } label: {
                        Label(
                            "Dodaj punkty z szablonu",
                            systemImage:
                                "scope"
                        )
                    }
                    .disabled(
                        selectedTemplateID
                        == nil
                    )
                    .buttonStyle(
                        .borderedProminent
                    )
                }

                Section("Punkty wiercenia elementu") {
                    if draft
                        .punktyWiercenia
                        .isEmpty {
                        Text(
                            "Brak przypisanych punktów."
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    } else {
                        ForEach(
                            draft
                                .punktyWiercenia
                        ) { point in
                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {
                                Text(
                                    point.typ.nazwa
                                )
                                .font(.headline)

                                Text(
                                    "X \(point.xMM.formatted(.number.precision(.fractionLength(0...1)))) mm • Y \(point.yMM.formatted(.number.precision(.fractionLength(0...1)))) mm • Ø \(point.srednicaMM.formatted(.number.precision(.fractionLength(0...1)))) mm • gł. \(point.glebokoscMM.formatted(.number.precision(.fractionLength(0...1)))) mm"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )

                                if !point.opis.isEmpty {
                                    Text(
                                        point.opis
                                    )
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }

                Section("Uwagi") {
                    TextEditor(
                        text:
                            $draft.uwagi
                    )
                    .frame(
                        minHeight: 100
                    )
                }
            }
            .navigationTitle(
                draft.etykieta
            )
            .sheet(
                isPresented:
                    $showingSystem32
            ) {
                System32EditorView(
                    element: draft,
                    parameters:
                        draft.parametrySystemu32
                        ?? ParametrySystemu32()
                ) {
                    parameters,
                    points in

                    draft.parametrySystemu32 =
                        parameters

                    draft.punktyWiercenia
                        .removeAll {
                            $0.opis
                                .hasPrefix(
                                    "System 32"
                                )
                        }

                    draft.punktyWiercenia
                        .append(
                            contentsOf:
                                points
                        )
                }
            }
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Zapisz") {
                        onSave(draft)
                        dismiss()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
    }

    private var system32PointCount:
        Int
    {
        draft.punktyWiercenia
            .filter {
                $0.opis
                    .hasPrefix(
                        "System 32"
                    )
            }
            .count
    }

    private var matchingTemplates:
        [SzablonWierceniaOkucia]
    {
        let preferredTypes:
            [TypPunktuWiercenia]

        switch draft.typ {
        case .scianaBoczna,
             .sciankaMaskujaca:
            preferredTypes = [
                .prowadnica,
                .podporaPolki,
                .lacznik
            ]

        case .front:
            preferredTypes = [
                .zawias,
                .uchwyt
            ]

        default:
            preferredTypes = [
                .lacznik,
                .kolkowanie,
                .inny
            ]
        }

        return templateRepository
            .templates
            .filter {
                $0.aktywny
                && preferredTypes
                    .contains(
                        $0.typ
                    )
            }
    }

    private func applySelectedTemplate() {
        guard let selectedTemplateID,
              let template =
                templateRepository
                    .templates
                    .first(
                        where: {
                            $0.id
                            == selectedTemplateID
                        }
                    )
        else {
            return
        }

        let generated =
            SzablonWierceniaApplicator
                .apply(
                    template: template,
                    to: draft,
                    baseYMM:
                        baseYMM
                )

        draft.punktyWiercenia
            .append(
                contentsOf:
                    generated
            )
    }

    private func numberField(
        _ title: String,
        value:
            Binding<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value: value,
                format:
                    .number.precision(
                        .fractionLength(
                            0...1
                        )
                    )
            )
            .keyboardType(
                .decimalPad
            )
            .multilineTextAlignment(
                .trailing
            )
            .frame(width: 100)

            Text("mm")
                .foregroundStyle(
                    .secondary
                )
        }
    }
}
