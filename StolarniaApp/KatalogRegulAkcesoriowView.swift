import SwiftUI

struct KatalogRegulAkcesoriowView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @Binding var karta:
        KartaTechnicznaSzafki

    @State private var selectedCategory:
        KategoriaAkcesoriumMeblowego?

    @State private var searchText = ""

    @State private var selectedProfile:
        ProfilAkcesoriumMeblowego?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StolarniaSectionIntro(
                        title:
                            "Reguły okuć i akcesoriów",
                        description:
                            "Profile producentów, walidacja wymiarów i parametry dokumentacji technicznej.",
                        systemImage:
                            "wrench.adjustable"
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                }

                if !karta
                    .efektywneAkcesoria
                    .isEmpty {
                    Section(
                        "Akcesoria przypisane do szafki"
                    ) {
                        ForEach(
                            karta
                                .efektywneAkcesoria
                        ) { accessory in
                            VStack(
                                alignment: .leading,
                                spacing: 5
                            ) {
                                HStack {
                                    Text(
                                        accessory.producent
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
                                    "\(accessory.rodzina) — \(accessory.model)"
                                )

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

                                accessoryParameters(
                                    accessory
                                )
                            }
                            .padding(
                                .vertical,
                                4
                            )
                        }
                        .onDelete {
                            karta
                                .efektywneAkcesoria
                                .remove(
                                    atOffsets: $0
                                )
                        }
                    }
                }

                Section("Filtr") {
                    Picker(
                        "Kategoria",
                        selection:
                            $selectedCategory
                    ) {
                        Text("Wszystkie")
                            .tag(
                                Optional<
                                    KategoriaAkcesoriumMeblowego
                                >.none
                            )

                        ForEach(
                            KategoriaAkcesoriumMeblowego
                                .allCases
                        ) { category in
                            Text(category.nazwa)
                                .tag(
                                    Optional(
                                        category
                                    )
                                )
                        }
                    }
                }

                Section("Profile") {
                    if filteredProfiles
                        .isEmpty {
                        ContentUnavailableView(
                            "Brak profili",
                            systemImage:
                                "magnifyingglass",
                            description:
                                Text(
                                    "Zmień kategorię lub wyszukiwane hasło."
                                )
                        )
                    } else {
                        ForEach(
                            filteredProfiles
                        ) { profile in
                            Button {
                                selectedProfile =
                                    profile
                            } label: {
                                profileRow(
                                    profile
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt:
                    "Producent, rodzina lub model"
            )
            .navigationTitle(
                "Katalog akcesoriów"
            )
            .task {
                let repository =
                    BazaMaterialowRepository()
                _ = repository
                    .synchronizujCennikAkcesoriow()
            }
            .toolbar {
                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Gotowe") {
                        dismiss()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
            .sheet(
                item:
                    $selectedProfile
            ) { profile in
                KonfiguracjaAkcesoriumView(
                    profil: profile,
                    karta: karta
                ) { instance in
                    karta
                        .efektywneAkcesoria
                        .append(instance)
                }
            }
        }
    }

    private var filteredProfiles:
        [ProfilAkcesoriumMeblowego]
    {
        KatalogRegulAkcesoriow
            .profile(
                kategoria:
                    selectedCategory
            )
            .filter { profile in
                guard !searchText
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                else {
                    return true
                }

                let source =
                    [
                        profile.producent,
                        profile.rodzina,
                        profile.model,
                        profile.kategoria.nazwa,
                        profile
                            .indeksyPrzykladowe
                            .joined(
                                separator: " "
                            )
                    ]
                    .joined(
                        separator: " "
                    )
                    .folding(
                        options: [
                            .diacriticInsensitive,
                            .caseInsensitive
                        ],
                        locale: .current
                    )

                let query =
                    searchText
                        .folding(
                            options: [
                                .diacriticInsensitive,
                                .caseInsensitive
                            ],
                            locale: .current
                        )

                return source
                    .localizedCaseInsensitiveContains(
                        query
                    )
            }
    }

    private func profileRow(
        _ profile:
            ProfilAkcesoriumMeblowego
    ) -> some View {
        HStack(spacing: 12) {
            Image(
                systemName:
                    profile
                        .kategoria
                        .symbol
            )
            .font(.title3)
            .frame(width: 30)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    "\(profile.producent) \(profile.rodzina)"
                )
                .font(.headline)

                Text(profile.model)
                    .font(.subheadline)

                if let price =
                    profile.cenaRynkowa {
                    Text(
                        "Średnio \(currency(price.cenaSredniaBruttoPLN)) / \(price.jednostka.skrot)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                HStack {
                    Text(
                        profile.kategoria.nazwa
                    )

                    Text("•")

                    Text(
                        profile.status.nazwa
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    profile.status
                        == .wymagaPotwierdzenia
                    ? Color.orange
                    : Color.secondary
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

    @ViewBuilder
    private func accessoryParameters(
        _ accessory:
            InstancjaAkcesoriumSzafki
    ) -> some View {
        let values =
            [
                accessory
                    .nominalnaDlugoscMM
                    .map {
                        "L \(format($0)) mm"
                    },
                accessory
                    .wariantWysokosciMM
                    .map {
                        "H \(format($0)) mm"
                    },
                accessory
                    .gruboscDnaMM
                    .map {
                        "dno \(format($0)) mm"
                    },
                accessory
                    .gruboscBokuMM
                    .map {
                        "bok \(format($0)) mm"
                    }
            ]
            .compactMap {
                $0
            }

        if !values.isEmpty {
            Text(
                values.joined(
                    separator: " • "
                )
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func currency(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }

    private func format(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }
}

private struct KonfiguracjaAkcesoriumView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    let profil:
        ProfilAkcesoriumMeblowego
    let karta:
        KartaTechnicznaSzafki
    let onAdd:
        (InstancjaAkcesoriumSzafki)
        -> Void

    @State private var draft:
        InstancjaAkcesoriumSzafki

    init(
        profil:
            ProfilAkcesoriumMeblowego,
        karta:
            KartaTechnicznaSzafki,
        onAdd:
            @escaping
            (InstancjaAkcesoriumSzafki)
            -> Void
    ) {
        self.profil = profil
        self.karta = karta
        self.onAdd = onAdd

        let suitableElement =
            karta
                .efektywneElementy
                .first {
                    profil
                        .elementyDocelowe
                        .isEmpty
                    || profil
                        .elementyDocelowe
                        .contains(
                            $0.typ
                        )
                }

        _draft = State(
            initialValue:
                InstancjaAkcesoriumSzafki(
                    profilID:
                        profil.id,
                    producent:
                        profil.producent,
                    rodzina:
                        profil.rodzina,
                    model:
                        profil.model,
                    kategoria:
                        profil.kategoria,
                    docelowaEtykietaElementu:
                        suitableElement?
                            .etykieta
                        ?? "",
                    nominalnaDlugoscMM:
                        profil
                            .dozwoloneDlugosciMM
                            .first,
                    wariantWysokosciMM:
                        profil
                            .dozwoloneWysokosciMM
                            .first,
                    gruboscDnaMM:
                        initialAccessoryThickness(
                            profil
                                .regulaGrubosciDna
                        ),
                    gruboscTyluMM:
                        initialAccessoryThickness(
                            profil
                                .regulaGrubosciTylu
                        ),
                    gruboscBokuMM:
                        initialAccessoryThickness(
                            profil
                                .regulaGrubosciBoku
                        ),
                    gruboscKorpusuMM:
                        18,
                    masaObciazeniaKG:
                        profil
                            .maksymalneObciazenieKG,
                    powierzchniaWentylacjiCM2:
                        profil
                            .minimalnaPowierzchniaWentylacjiCM2,
                    wysokoscFrontuMM:
                        karta.wysokoscMM
                        / Double(
                            max(
                                karta
                                    .liczbaSegmentow,
                                1
                            )
                        ),
                    cenaJednostkowaNettoPLN:
                        profil
                            .cenaRynkowa?
                            .cenaSredniaNettoPLN,
                    cenaJednostkowaBruttoPLN:
                        profil
                            .cenaRynkowa?
                            .cenaSredniaBruttoPLN,
                    jednostkaCeny:
                        profil
                            .cenaRynkowa?
                            .jednostka
                            .skrot,
                    dataCeny:
                        profil
                            .cenaRynkowa?
                            .dataResearchu,
                    liczbaProbekCeny:
                        profil
                            .cenaRynkowa?
                            .liczbaProbek
                )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    LabeledContent(
                        "Producent",
                        value:
                            profil.producent
                    )

                    LabeledContent(
                        "Rodzina",
                        value:
                            profil.rodzina
                    )

                    LabeledContent(
                        "Model",
                        value:
                            profil.model
                    )

                    LabeledContent(
                        "Status",
                        value:
                            profil.status.nazwa
                    )

                    if !profil.zrodlo
                        .isEmpty {
                        Text(profil.zrodlo)
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }

                if let price =
                    profil.cenaRynkowa {
                    Section("Cena rynkowa") {
                        LabeledContent(
                            "Średnia brutto",
                            value:
                                currency(
                                    price
                                        .cenaSredniaBruttoPLN
                                )
                                + " / "
                                + price
                                    .jednostka
                                    .skrot
                        )

                        LabeledContent(
                            "Zakres",
                            value:
                                currency(
                                    price
                                        .cenaMinimalnaBruttoPLN
                                )
                                + "–"
                                + currency(
                                    price
                                        .cenaMaksymalnaBruttoPLN
                                )
                        )

                        LabeledContent(
                            "Liczba próbek",
                            value:
                                "\(price.liczbaProbek)"
                        )

                        LabeledContent(
                            "Wartość pozycji",
                            value:
                                currency(
                                    price
                                        .cenaSredniaBruttoPLN
                                    * Double(
                                        max(
                                            draft.ilosc,
                                            0
                                        )
                                    )
                                )
                        )

                        Text(
                            price.opisZakresu
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            "Cena jest migawką rynku z \(price.dataResearchu.formatted(date: .numeric, time: .omitted)) i zostanie zapisana jako snapshot w projekcie."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Section("Przypisanie") {
                    Stepper(
                        "Liczba: \(draft.ilosc)",
                        value:
                            $draft.ilosc,
                        in: 1...999
                    )

                    Picker(
                        "Element",
                        selection:
                            $draft
                                .docelowaEtykietaElementu
                    ) {
                        Text("Cała szafka")
                            .tag("")

                        ForEach(
                            suitableElements
                        ) { element in
                            Text(
                                "\(element.etykieta) — \(element.nazwa)"
                            )
                            .tag(
                                element.etykieta
                            )
                        }
                    }
                }

                if !profil
                    .dozwoloneDlugosciMM
                    .isEmpty {
                    Section("Długość") {
                        Picker(
                            "Nominalna",
                            selection:
                                optionalDoubleBinding(
                                    $draft
                                        .nominalnaDlugoscMM,
                                    fallback:
                                        profil
                                            .dozwoloneDlugosciMM
                                            .first
                                        ?? 0
                                )
                        ) {
                            ForEach(
                                profil
                                    .dozwoloneDlugosciMM,
                                id: \.self
                            ) { value in
                                Text(
                                    "\(format(value)) mm"
                                )
                                .tag(value)
                            }
                        }
                    }
                }

                if !profil
                    .dozwoloneWysokosciMM
                    .isEmpty {
                    Section("Wariant wysokości") {
                        Picker(
                            "Wysokość",
                            selection:
                                optionalDoubleBinding(
                                    $draft
                                        .wariantWysokosciMM,
                                    fallback:
                                        profil
                                            .dozwoloneWysokosciMM
                                            .first
                                        ?? 0
                                )
                        ) {
                            ForEach(
                                profil
                                    .dozwoloneWysokosciMM,
                                id: \.self
                            ) { value in
                                Text(
                                    "\(format(value)) mm"
                                )
                                .tag(value)
                            }
                        }
                    }
                }

                if profil
                    .kategoria
                    == .systemSzuflady
                    || profil
                        .kategoria
                        == .prowadnica {
                    Section("Płyty i korpus") {
                        thicknessField(
                            "Dno",
                            value:
                                $draft
                                    .gruboscDnaMM,
                            rule:
                                profil
                                    .regulaGrubosciDna
                        )

                        thicknessField(
                            "Tył",
                            value:
                                $draft
                                    .gruboscTyluMM,
                            rule:
                                profil
                                    .regulaGrubosciTylu
                        )

                        thicknessField(
                            "Bok skrzynki",
                            value:
                                $draft
                                    .gruboscBokuMM,
                            rule:
                                profil
                                    .regulaGrubosciBoku
                        )

                        numberField(
                            "Grubość korpusu",
                            value:
                                $draft
                                    .gruboscKorpusuMM,
                            unit: "mm"
                        )

                        if let threshold =
                            profil
                                .progRelinguDlaFrontuMM {
                            optionalNumberField(
                                "Wysokość frontu",
                                value:
                                    $draft
                                        .wysokoscFrontuMM,
                                fallback:
                                    threshold,
                                unit: "mm"
                            )
                        }
                    }
                }

                if profil
                    .maksymalneObciazenieKG
                    != nil {
                    Section("Obciążenie") {
                        optionalNumberField(
                            "Planowane",
                            value:
                                $draft
                                    .masaObciazeniaKG,
                            fallback:
                                profil
                                    .maksymalneObciazenieKG
                                ?? 0,
                            unit: "kg"
                        )

                        if let maximum =
                            profil
                                .maksymalneObciazenieKG {
                            LabeledContent(
                                "Limit profilu",
                                value:
                                    "\(format(maximum)) kg"
                            )
                        }
                    }
                }

                if profil
                    .minimalnaPowierzchniaWentylacjiCM2
                    != nil {
                    Section("Wentylacja") {
                        optionalNumberField(
                            "Czynny przekrój",
                            value:
                                $draft
                                    .powierzchniaWentylacjiCM2,
                            fallback:
                                profil
                                    .minimalnaPowierzchniaWentylacjiCM2
                                ?? 0,
                            unit: "cm²"
                        )

                        Text(
                            "Podaj rzeczywistą wolną powierzchnię po odjęciu lameli kratki."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                if let dimensions {
                    Section("Wynik wymiarowania") {
                        LabeledContent(
                            "Światło korpusu LW",
                            value:
                                "\(format(dimensions.szerokoscWewnetrznaKorpusuMM)) mm"
                        )

                        dimensionRow(
                            "Szerokość dna",
                            value:
                                dimensions
                                    .szerokoscDnaMM
                        )

                        dimensionRow(
                            "Długość dna",
                            value:
                                dimensions
                                    .dlugoscDnaMM
                        )

                        dimensionRow(
                            "Szerokość tyłu",
                            value:
                                dimensions
                                    .szerokoscTyluMM
                        )

                        dimensionRow(
                            "Synchronizator",
                            value:
                                dimensions
                                    .dlugoscSynchronizatoraMM
                        )

                        dimensionRow(
                            "Minimalna głębokość",
                            value:
                                dimensions
                                    .minimalnaGlebokoscKorpusuMM
                        )

                        if let formula =
                            profil.formulaSzuflady,
                           !formula.opis.isEmpty {
                            Text(formula.opis)
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                        }
                    }
                }

                Section("Walidacja") {
                    ForEach(validation) {
                        result in

                        Label(
                            result.komunikat,
                            systemImage:
                                validationSymbol(
                                    result.poziom
                                )
                        )
                        .foregroundStyle(
                            validationColor(
                                result.poziom
                            )
                        )
                    }
                }

                if !profil.funkcje
                    .isEmpty {
                    Section("Funkcje") {
                        ForEach(
                            profil.funkcje,
                            id: \.self
                        ) {
                            Label(
                                $0,
                                systemImage:
                                    "checkmark.circle"
                            )
                        }
                    }
                }

                if !profil.uwagi
                    .isEmpty {
                    Section("Uwagi profilu") {
                        ForEach(
                            profil.uwagi,
                            id: \.self
                        ) {
                            Text($0)
                        }
                    }
                }

                Section("Uwagi projektu") {
                    TextEditor(
                        text:
                            $draft.uwagi
                    )
                    .frame(
                        minHeight: 90
                    )
                }
            }
            .navigationTitle(
                profil.rodzina
            )
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
                    Button("Dodaj") {
                        var saved =
                            draft

                        if let price =
                            profil.cenaRynkowa {
                            saved
                                .cenaJednostkowaNettoPLN =
                                    price
                                        .cenaSredniaNettoPLN
                            saved
                                .cenaJednostkowaBruttoPLN =
                                    price
                                        .cenaSredniaBruttoPLN
                            saved
                                .jednostkaCeny =
                                    price
                                        .jednostka
                                        .skrot
                            saved.dataCeny =
                                price.dataResearchu
                            saved
                                .liczbaProbekCeny =
                                    price
                                        .liczbaProbek
                        }

                        onAdd(saved)
                        dismiss()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        validation.contains {
                            $0.poziom
                                == .blad
                        }
                    )
                }
            }
        }
    }

    private var suitableElements:
        [ElementTechnicznySzafki]
    {
        karta
            .efektywneElementy
            .filter {
                profil
                    .elementyDocelowe
                    .isEmpty
                || profil
                    .elementyDocelowe
                    .contains(
                        $0.typ
                    )
            }
    }

    private var validation:
        [WynikWalidacjiAkcesorium]
    {
        RegulyAkcesoriowValidator
            .validate(
                profil: profil,
                instancja: draft,
                karta: karta
            )
    }

    private var dimensions:
        WynikWymiarowaniaSzuflady?
    {
        RegulyAkcesoriowValidator
            .dimensions(
                profil: profil,
                instancja: draft,
                karta: karta
            )
    }

    @ViewBuilder
    private func thicknessField(
        _ title: String,
        value:
            Binding<Double?>,
        rule:
            RegulaGrubosciPlyty
    ) -> some View {
        if rule.tryb
            == .brak {
            LabeledContent(
                title,
                value:
                    rule.opisSkrocony
            )
        } else {
            optionalNumberField(
                title,
                value: value,
                fallback:
                    initialAccessoryThickness(rule)
                    ?? 0,
                unit: "mm"
            )

            Text(
                "Reguła: \(rule.opisSkrocony)"
            )
            .font(.caption)
            .foregroundStyle(
                rule.tryb
                    == .wymagaPotwierdzenia
                ? Color.orange
                : Color.secondary
            )
        }
    }

    private func numberField(
        _ title: String,
        value:
            Binding<Double>,
        unit: String
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
            .frame(width: 90)

            Text(unit)
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private func optionalNumberField(
        _ title: String,
        value:
            Binding<Double?>,
        fallback: Double,
        unit: String
    ) -> some View {
        numberField(
            title,
            value:
                optionalDoubleBinding(
                    value,
                    fallback:
                        fallback
                ),
            unit: unit
        )
    }

    private func optionalDoubleBinding(
        _ binding:
            Binding<Double?>,
        fallback: Double
    ) -> Binding<Double> {
        Binding(
            get: {
                binding.wrappedValue
                ?? fallback
            },
            set: {
                binding.wrappedValue =
                    $0
            }
        )
    }

    @ViewBuilder
    private func dimensionRow(
        _ title: String,
        value: Double?
    ) -> some View {
        if let value {
            LabeledContent(
                title,
                value:
                    "\(format(value)) mm"
            )
        }
    }

    private func validationSymbol(
        _ level:
            PoziomWalidacjiAkcesorium
    ) -> String {
        switch level {
        case .informacja:
            return "info.circle"
        case .ostrzezenie:
            return "exclamationmark.triangle"
        case .blad:
            return "xmark.octagon"
        }
    }

    private func validationColor(
        _ level:
            PoziomWalidacjiAkcesorium
    ) -> Color {
        switch level {
        case .informacja:
            return .secondary
        case .ostrzezenie:
            return .orange
        case .blad:
            return .red
        }
    }

    private func currency(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }

    private func format(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }

}

private func initialAccessoryThickness(
    _ rule:
        RegulaGrubosciPlyty
) -> Double? {
    switch rule.tryb {
    case .stala:
        return rule.stalaMM
    case .zakres:
        return rule.minimumMM
    case .wybor:
        return rule.dozwoloneMM.first
    case .brak,
         .wymagaPotwierdzenia:
        return nil
    }
}
