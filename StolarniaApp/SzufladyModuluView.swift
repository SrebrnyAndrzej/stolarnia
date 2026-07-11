import SwiftUI

struct SzufladyModuluView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    @Binding var karta:
        KartaTechnicznaSzafki

    @State private var selectedProfileID = ""
    @State private var liczba = 3
    @State private var wysokoscFrontuMM = 180.0
    @State private var wysokoscSkrzynkiMM = 120.0
    @State private var nominalnaDlugoscMM = 450.0
    @State private var szczelinaMM = 3.0
    @State private var marginesDolnyMM = 3.0
    @State private var marginesGornyMM = 3.0
    @State private var typFrontu:
        TypFrontuSzuflady =
            .zewnetrzny
    @State private var usunKolidujacePolki = true
    @State private var initialized = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Label(
                            "Szuflady w module",
                            systemImage:
                                "shippingbox.and.arrow.backward"
                        )
                        .font(.title2.bold())

                        Text(
                            "Automatyczny układ dla szafek dolnych i słupków. Silnik sprawdza wysokość, głębokość, szerokość, półki, wzajemne nakładanie oraz tor frontu."
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        .vertical,
                        6
                    )
                }

                Section("Geometria korpusu") {
                    LabeledContent(
                        "Światło szerokości",
                        value:
                            mm(
                                geometry
                                    .szerokoscMM
                            )
                    )

                    LabeledContent(
                        "Światło wysokości",
                        value:
                            mm(
                                geometry
                                    .wysokoscMM
                            )
                    )

                    LabeledContent(
                        "Światło głębokości",
                        value:
                            mm(
                                geometry
                                    .glebokoscMM
                            )
                    )

                    LabeledContent(
                        "Maksymalna liczba",
                        value:
                            "\(maximumCount)"
                    )
                }

                Section("System szuflady") {
                    Picker(
                        "Profil",
                        selection:
                            $selectedProfileID
                    ) {
                        ForEach(
                            availableProfiles
                        ) { profile in
                            Text(
                                "\(profile.producent) \(profile.rodzina) — \(profile.model)"
                            )
                            .tag(profile.id)
                        }
                    }

                    if let profile =
                        selectedProfile {
                        LabeledContent(
                            "Kategoria",
                            value:
                                profile
                                    .kategoria
                                    .nazwa
                        )

                        LabeledContent(
                            "Grubość dna",
                            value:
                                profile
                                    .regulaGrubosciDna
                                    .opisSkrocony
                        )

                        LabeledContent(
                            "Grubość tyłu",
                            value:
                                profile
                                    .regulaGrubosciTylu
                                    .opisSkrocony
                        )

                        if let price =
                            profile.cenaRynkowa {
                            LabeledContent(
                                "Średnia cena",
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
                                "Szacowany koszt",
                                value:
                                    currency(
                                        price
                                            .cenaSredniaBruttoPLN
                                        * Double(
                                            max(
                                                liczba,
                                                0
                                            )
                                        )
                                    )
                            )

                            Text(
                                "Zakres researchu: \(currency(price.cenaMinimalnaBruttoPLN))–\(currency(price.cenaMaksymalnaBruttoPLN)), \(price.liczbaProbek) próbek. Cena jest punktem startowym i można ją później zmienić w bazie materiałowej."
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }

                Section("Układ") {
                    Stepper(
                        "Liczba szuflad: \(liczba)",
                        value:
                            $liczba,
                        in: 1...30
                    )

                    Picker(
                        "Rodzaj frontu",
                        selection:
                            $typFrontu
                    ) {
                        ForEach(
                            TypFrontuSzuflady
                                .allCases
                        ) { type in
                            Text(type.nazwa)
                                .tag(type)
                        }
                    }

                    if typFrontu == .wewnetrzny {
                        LabeledContent(
                            "Cofnięcie za frontem",
                            value:
                                mm(
                                    innerDrawerSetbackMM
                                )
                        )

                        Text(
                            "Szuflada wewnętrzna jest cofana za płaszczyznę frontu zewnętrznego. Cofnięcie dolicza się do wymaganej głębokości korpusu oraz do osi prowadnic."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    if !allowedLengths
                        .isEmpty {
                        Picker(
                            "Długość nominalna",
                            selection:
                                $nominalnaDlugoscMM
                        ) {
                            ForEach(
                                allowedLengths,
                                id: \.self
                            ) { value in
                                Text(mm(value))
                                    .tag(value)
                            }
                        }
                    } else {
                        numberField(
                            "Długość nominalna",
                            value:
                                $nominalnaDlugoscMM
                        )
                    }

                    numberField(
                        "Wysokość frontu",
                        value:
                            $wysokoscFrontuMM
                    )

                    numberField(
                        "Wysokość skrzynki",
                        value:
                            $wysokoscSkrzynkiMM
                    )

                    numberField(
                        "Szczelina frontów",
                        value:
                            $szczelinaMM
                    )

                    numberField(
                        "Margines dolny",
                        value:
                            $marginesDolnyMM
                    )

                    numberField(
                        "Margines górny",
                        value:
                            $marginesGornyMM
                    )

                    Toggle(
                        "Usuń kolidujące półki",
                        isOn:
                            $usunKolidujacePolki
                    )
                }

                Section("Podgląd") {
                    drawerPreview
                        .frame(
                            minHeight: 340
                        )
                        .listRowInsets(
                            EdgeInsets()
                        )
                }

                Section("Kontrola kolizji") {
                    ForEach(
                        collisions
                    ) { collision in
                        Label(
                            collision.komunikat,
                            systemImage:
                                collisionSymbol(
                                    collision.poziom
                                )
                        )
                        .foregroundStyle(
                            collisionColor(
                                collision.poziom
                            )
                        )
                    }
                }

                if !generatedDrawers
                    .isEmpty {
                    Section("Generowane szuflady") {
                        ForEach(
                            generatedDrawers
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
                                    "\(drawer.nazwa) • Y \(mm(drawer.pozycjaDolnaYMM)) • front \(mm(drawer.wysokoscFrontuMM)) • skrzynka \(mm(drawer.wysokoscSkrzynkiMM)) • cofnięcie \(mm(drawer.efektywneCofniecieOdFrontuMM))"
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
            .navigationTitle(
                "Dodaj szuflady"
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
                    Button("Zastosuj") {
                        apply()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        selectedProfile
                            == nil
                        || hasBlockingCollision
                    )
                }
            }
            .onAppear {
                initialize()
            }
            .onChange(
                of: selectedProfileID
            ) {
                _,
                _ in

                normalizeLength()
            }
        }
    }

    private var availableProfiles:
        [ProfilAkcesoriumMeblowego]
    {
        KatalogRegulAkcesoriow
            .profile(
                kategoria: nil
            )
            .filter {
                $0.kategoria
                    == .systemSzuflady
                || $0.kategoria
                    == .prowadnica
            }
    }

    private var selectedProfile:
        ProfilAkcesoriumMeblowego?
    {
        KatalogRegulAkcesoriow
            .profil(
                id:
                    selectedProfileID
            )
    }

    private var allowedLengths:
        [Double]
    {
        selectedProfile?
            .dozwoloneDlugosciMM
        ?? []
    }

    private var parameters:
        ParametryAutomatycznegoUkladuSzuflad
    {
        ParametryAutomatycznegoUkladuSzuflad(
            liczba:
                liczba,
            wysokoscFrontuMM:
                max(
                    wysokoscFrontuMM,
                    1
                ),
            wysokoscSkrzynkiMM:
                max(
                    wysokoscSkrzynkiMM,
                    1
                ),
            nominalnaDlugoscMM:
                max(
                    nominalnaDlugoscMM,
                    1
                ),
            szczelinaMiedzyFrontamiMM:
                max(
                    szczelinaMM,
                    0
                ),
            marginesDolnyMM:
                max(
                    marginesDolnyMM,
                    0
                ),
            marginesGornyMM:
                max(
                    marginesGornyMM,
                    0
                ),
            typFrontu:
                typFrontu,
            profilID:
                selectedProfileID
        )
    }

    private var geometry:
        GeometriaWnetrzaSzafki
    {
        SzufladyModuluEngine
            .geometria(
                karty: karta
            )
    }

    private var maximumCount:
        Int
    {
        SzufladyModuluEngine
            .maksymalnaLiczba(
                parametry:
                    parameters,
                w: karta
            )
    }

    private var generatedDrawers:
        [SzufladaModulu]
    {
        SzufladyModuluEngine
            .generuj(
                parametry:
                    parameters,
                dla: karta
            )
    }

    private var innerDrawerSetbackMM:
        Double
    {
        generatedDrawers
            .first?
            .efektywneCofniecieOdFrontuMM
        ?? 0
    }

    private var collisions:
        [KolizjaSzuflady]
    {
        var values =
            SzufladyModuluEngine
                .waliduj(
                    szuflady:
                        generatedDrawers,
                    w: karta
                )

        if liczba > maximumCount {
            values.append(
                KolizjaSzuflady(
                    typ: .liczba,
                    poziom: .blad,
                    komunikat:
                        "Żądane \(liczba) szuflad nie mieści się w świetle korpusu. Maksymalnie: \(maximumCount)."
                )
            )
        }

        return values
    }

    private var hasBlockingCollision:
        Bool
    {
        collisions.contains {
            collision in

            guard collision.poziom
                == .blad
            else {
                return false
            }

            if collision.typ == .polka,
               usunKolidujacePolki {
                return false
            }

            return true
        }
    }

    private var drawerPreview:
        some View
    {
        GeometryReader { proxy in
            let inset: CGFloat = 28
            let cabinetRect =
                CGRect(
                    x: inset,
                    y: inset,
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
                cabinetRect.height
                / max(
                    geometry.wysokoscMM,
                    1
                )

            ZStack {
                RoundedRectangle(
                    cornerRadius: 18
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
                        width:
                            cabinetRect.width,
                        height:
                            cabinetRect.height
                    )
                    .position(
                        x:
                            cabinetRect.midX,
                        y:
                            cabinetRect.midY
                    )

                ForEach(
                    generatedDrawers
                ) { drawer in
                    let height =
                        max(
                            drawer
                                .wysokoscFrontuMM
                            * scale,
                            3
                        )

                    let y =
                        cabinetRect.maxY
                        - drawer
                            .pozycjaDolnaYMM
                            * scale
                        - height / 2

                    RoundedRectangle(
                        cornerRadius: 4
                    )
                    .fill(
                        Color.accentColor
                            .opacity(0.22)
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 4
                        )
                        .stroke(
                            Color.accentColor,
                            lineWidth: 1
                        )
                    }
                    .frame(
                        width:
                            cabinetRect.width
                            - 8,
                        height: height
                    )
                    .position(
                        x:
                            cabinetRect.midX,
                        y: y
                    )
                    .overlay {
                        Text(
                            drawer.etykieta
                        )
                        .font(
                            .caption2
                                .monospaced()
                                .weight(
                                    .semibold
                                )
                        )
                        .position(
                            x:
                                cabinetRect.midX,
                            y: y
                        )
                    }
                }
            }
        }
    }

    private func initialize() {
        guard !initialized else {
            return
        }

        initialized = true

        if let first =
            karta
                .efektywneSzuflady
                .first {
            selectedProfileID =
                first.profilID
            liczba =
                karta
                    .efektywneSzuflady
                    .count
            wysokoscFrontuMM =
                first.wysokoscFrontuMM
            wysokoscSkrzynkiMM =
                first.wysokoscSkrzynkiMM
            nominalnaDlugoscMM =
                first.nominalnaDlugoscMM
            typFrontu =
                first.typFrontu
        } else if let first =
            availableProfiles.first {
            selectedProfileID =
                first.id
            nominalnaDlugoscMM =
                first
                    .dozwoloneDlugosciMM
                    .contains(450)
                ? 450
                : (
                    first
                        .dozwoloneDlugosciMM
                        .first
                    ?? 450
                )
        }
    }

    private func normalizeLength() {
        guard !allowedLengths
            .isEmpty
        else {
            return
        }

        if !allowedLengths
            .contains(
                nominalnaDlugoscMM
            ) {
            nominalnaDlugoscMM =
                allowedLengths.min {
                    abs(
                        $0
                        - nominalnaDlugoscMM
                    )
                    < abs(
                        $1
                        - nominalnaDlugoscMM
                    )
                }
                ?? allowedLengths[0]
        }
    }

    private func apply() {
        guard let selectedProfile else {
            return
        }

        var updated = karta

        SzufladyModuluEngine
            .zastosuj(
                szuflady:
                    generatedDrawers,
                profil:
                    selectedProfile,
                usunKolidujacePolki:
                    usunKolidujacePolki,
                do: &updated
            )

        karta = updated
        KartaTechnicznaSzafkiStore
            .save(updated)
        dismiss()
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
            .frame(width: 90)

            Text("mm")
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private func collisionSymbol(
        _ level:
            PoziomKolizjiSzuflady
    ) -> String {
        switch level {
        case .informacja:
            return "checkmark.circle"
        case .ostrzezenie:
            return "exclamationmark.triangle"
        case .blad:
            return "xmark.octagon"
        }
    }

    private func collisionColor(
        _ level:
            PoziomKolizjiSzuflady
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

    private func mm(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
        + " mm"
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
}
