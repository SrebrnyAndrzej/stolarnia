import DomainCore
import SwiftUI

/// Rodzaj presetu wybierany w UI. Wersja bez associated values pozwalająca użyć jednego Pickera.
/// Konwertowana do domenowego `PresetUkladuSzuflad` z odpowiednimi stanami widoku.
enum RodzajPresetuUkladuSzuflad: String, CaseIterable, Identifiable, Hashable {
    case rowne
    case jednaWysokaDwieNiskie
    case wysokaNaDoleDwieNiskie
    case dwieWysokie
    case wysokosciNiestandardowe
    case cargo

    var id: String { rawValue }

    var etykieta: String {
        switch self {
        case .rowne:
            return "Równe"
        case .jednaWysokaDwieNiskie:
            return "2 niskie + wysoka u góry"
        case .wysokaNaDoleDwieNiskie:
            return "Wysoka na dole + 2 niskie"
        case .dwieWysokie:
            return "2 wysokie"
        case .wysokosciNiestandardowe:
            return "Niestandardowe"
        case .cargo:
            return "Cargo"
        }
    }
}

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
    /// Startowa fuga z konwencji warsztatu, nie wpisana liczbą.
    /// Pole zostaje edytowalne — zmienia się dla konkretnej szafki, ale
    /// domyślnie zgadza się z resztą aplikacji.
    @State private var szczelinaMM =
        ProductionRules.frontToFrontGap.rawValue
    @State private var marginesDolnyMM = 3.0
    @State private var marginesGornyMM = 3.0
    @State private var typFrontu:
        TypFrontuSzuflady =
            .zewnetrzny
    @State private var odsuniecieOdScianBocznychMM = 21.0
    @State private var usunKolidujacePolki = true
    @State private var initialized = false

    @State private var rodzajPresetu: RodzajPresetuUkladuSzuflad = .rowne
    @State private var wysokoscWysokiejSzufladyMM: Double = 280
    @State private var wysokosciNiestandardowe: [Double] = [180, 180, 180]

    // MARK: - Historia zmian (undo/redo)
    @State private var historia: [MigawkaKonfiguracjiSzuflad] = []
    @State private var pozycjaHistorii: Int = -1
    /// Flaga zapobiegająca zapisowi snapshotu podczas przywracania stanu (cofnij/przywróć).
    @State private var wstrzymajHistorie: Bool = false

    private struct MigawkaKonfiguracjiSzuflad: Equatable {
        var rodzajPresetu: RodzajPresetuUkladuSzuflad
        var liczba: Int
        var wysokoscFrontuMM: Double
        var wysokoscWysokiejSzufladyMM: Double
        var wysokosciNiestandardowe: [Double]
        var typFrontu: TypFrontuSzuflady
        var odsuniecieOdScianBocznychMM: Double
    }

    private var aktualnaMigawka: MigawkaKonfiguracjiSzuflad {
        MigawkaKonfiguracjiSzuflad(
            rodzajPresetu: rodzajPresetu,
            liczba: liczba,
            wysokoscFrontuMM: wysokoscFrontuMM,
            wysokoscWysokiejSzufladyMM: wysokoscWysokiejSzufladyMM,
            wysokosciNiestandardowe: wysokosciNiestandardowe,
            typFrontu: typFrontu,
            odsuniecieOdScianBocznychMM: odsuniecieOdScianBocznychMM
        )
    }

    private var mozeCofnac: Bool { pozycjaHistorii > 0 }
    private var mozePrzywrocic: Bool { pozycjaHistorii < historia.count - 1 }

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

                Section("Preset układu") {
                    Picker(
                        "Rodzaj",
                        selection: $rodzajPresetu
                    ) {
                        ForEach(
                            RodzajPresetuUkladuSzuflad.allCases
                        ) { rodzaj in
                            Text(rodzaj.etykieta)
                                .tag(rodzaj)
                        }
                    }
                    .pickerStyle(.menu)

                    presetHelpText
                }

                Section("Standardy wysokości") {
                    Text(
                        "Szybkie zestawy wg standardów stolarni. Nadpisują aktualny układ."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Button {
                        zastosujStandard(
                            wszystkieOWysokosci: .niska,
                            liczba: 3
                        )
                    } label: {
                        Label(
                            "3 × Niska (\(Int(StandardWysokoscSzuflady.niska.wysokoscFrontuMM)) mm)",
                            systemImage: "square.stack.3d.down.right"
                        )
                    }

                    Button {
                        zastosujStandard(
                            wszystkieOWysokosci: .wysoka,
                            liczba: 2
                        )
                    } label: {
                        Label(
                            "2 × Wysoka (\(Int(StandardWysokoscSzuflady.wysoka.wysokoscFrontuMM)) mm)",
                            systemImage: "square.stack.3d.up"
                        )
                    }

                    Button {
                        zastosujKombinacjeStandardow([
                            .niska, .niska, .wysoka
                        ])
                    } label: {
                        Label(
                            "2 × Niska + Wysoka u góry",
                            systemImage: "rectangle.stack"
                        )
                    }

                    Button {
                        zastosujKombinacjeStandardow([
                            .wysoka, .niska, .niska
                        ])
                    } label: {
                        Label(
                            "Wysoka na dole + 2 × Niska",
                            systemImage: "rectangle.stack.badge.plus"
                        )
                    }

                    Button {
                        zastosujKombinacjeStandardow([
                            .niska, .srednia, .wysoka
                        ])
                    } label: {
                        Label(
                            "Niska + Średnia + Wysoka",
                            systemImage: "rectangle.3.group"
                        )
                    }

                    Button {
                        rodzajPresetu = .cargo
                    } label: {
                        Label(
                            "Cargo (pełna wysokość)",
                            systemImage: "archivebox"
                        )
                    }
                }

                Section("Układ") {
                    if rodzajPresetu == .rowne {
                        Stepper(
                            "Liczba szuflad: \(liczba)",
                            value: $liczba,
                            in: 1...maksymalnaLiczbaFrontow
                        )
                    }

                    if rodzajPresetu == .jednaWysokaDwieNiskie
                        || rodzajPresetu == .wysokaNaDoleDwieNiskie {
                        numberField(
                            "Wysokość wysokiej szuflady",
                            value: $wysokoscWysokiejSzufladyMM
                        )
                    }

                    if rodzajPresetu == .wysokosciNiestandardowe {
                        wysokosciNiestandardoweEditor
                    }

                    if rodzajPresetu == .cargo {
                        LabeledContent(
                            "Wysokość frontu",
                            value: mm(uzytecznaWysokoscMM)
                        )
                    }

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
                    .disabled(rodzajPresetu == .cargo)

                    if typFrontu == .wewnetrzny {
                        LabeledContent(
                            "Cofnięcie za frontem",
                            value:
                                mm(
                                    innerDrawerSetbackMM
                                )
                        )

                        numberField(
                            "Odsunięcie od boków",
                            value:
                                $odsuniecieOdScianBocznychMM
                        )

                        Text(
                            "Szuflada wewnętrzna jest cofana za płaszczyznę frontu zewnętrznego. Odsunięcie od boków wynika z reguły zawiasu: 155° zero-protrusion wymaga tylko luzu bezpieczeństwa, zwykły 110° wymaga dystansu lub potwierdzenia SKU."
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
                                    "\(drawer.nazwa) • Y \(mm(drawer.pozycjaDolnaYMM)) • front \(mm(drawer.wysokoscFrontuMM)) • skrzynka \(mm(drawer.wysokoscSkrzynkiMM)) • cofnięcie \(mm(drawer.efektywneCofniecieOdFrontuMM)) • bok \(mm(drawer.efektywneOdsuniecieOdScianBocznychMM))"
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

                ToolbarItemGroup(
                    placement: .primaryAction
                ) {
                    Button {
                        cofnij()
                    } label: {
                        Label("Cofnij", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!mozeCofnac)
                    .help("Cofnij ostatnią zmianę (⌘Z)")
                    .keyboardShortcut("z", modifiers: [.command])

                    Button {
                        przywroc()
                    } label: {
                        Label("Przywróć", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!mozePrzywrocic)
                    .help("Przywróć cofniętą zmianę (⇧⌘Z)")
                    .keyboardShortcut("z", modifiers: [.command, .shift])
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
                if historia.isEmpty {
                    historia = [aktualnaMigawka]
                    pozycjaHistorii = 0
                }
            }
            .onChange(of: selectedProfileID) { _, _ in
                normalizeLength()
            }
            .onChange(of: rodzajPresetu) { _, _ in
                zapiszSnapshot()
            }
            .onChange(of: liczba) { _, _ in
                zapiszSnapshot()
            }
            .onChange(of: wysokoscFrontuMM) { _, _ in
                zapiszSnapshot()
            }
            .onChange(of: wysokoscWysokiejSzufladyMM) { _, _ in
                zapiszSnapshot()
            }
            .onChange(of: wysokosciNiestandardowe) { _, _ in
                zapiszSnapshot()
            }
            .onChange(of: typFrontu) { _, _ in
                if typFrontu == .wewnetrzny,
                   odsuniecieOdScianBocznychMM <= 0 {
                    odsuniecieOdScianBocznychMM = 21
                }
                if typFrontu == .zewnetrzny {
                    odsuniecieOdScianBocznychMM = 0
                }
                zapiszSnapshot()
            }
            .onChange(of: odsuniecieOdScianBocznychMM) { _, _ in
                zapiszSnapshot()
            }
        }
    }

    // MARK: - Standardy wysokości

    private func zastosujStandard(
        wszystkieOWysokosci standard: StandardWysokoscSzuflady,
        liczba noweLiczba: Int
    ) {
        wysokoscFrontuMM = standard.wysokoscFrontuMM
        liczba = noweLiczba
        rodzajPresetu = .rowne
    }

    private func zastosujKombinacjeStandardow(
        _ standardy: [StandardWysokoscSzuflady]
    ) {
        wysokosciNiestandardowe = standardy.map(\.wysokoscFrontuMM)
        rodzajPresetu = .wysokosciNiestandardowe
        liczba = standardy.count
    }

    // MARK: - Undo / Redo

    private func zapiszSnapshot() {
        guard !wstrzymajHistorie else { return }
        let migawka = aktualnaMigawka

        // Nie duplikuj identycznego stanu
        if pozycjaHistorii >= 0,
           pozycjaHistorii < historia.count,
           historia[pozycjaHistorii] == migawka {
            return
        }

        // Odetnij branch "future" po edycji w środku historii
        if pozycjaHistorii < historia.count - 1 {
            historia.removeSubrange(
                (pozycjaHistorii + 1)..<historia.count
            )
        }

        historia.append(migawka)
        pozycjaHistorii = historia.count - 1

        // Ograniczenie historii do 50 kroków
        if historia.count > 50 {
            historia.removeFirst(historia.count - 50)
            pozycjaHistorii = historia.count - 1
        }
    }

    private func cofnij() {
        guard mozeCofnac else { return }
        pozycjaHistorii -= 1
        przywrocStanZMigawki(historia[pozycjaHistorii])
    }

    private func przywroc() {
        guard mozePrzywrocic else { return }
        pozycjaHistorii += 1
        przywrocStanZMigawki(historia[pozycjaHistorii])
    }

    private func przywrocStanZMigawki(
        _ migawka: MigawkaKonfiguracjiSzuflad
    ) {
        wstrzymajHistorie = true
        rodzajPresetu = migawka.rodzajPresetu
        liczba = migawka.liczba
        wysokoscFrontuMM = migawka.wysokoscFrontuMM
        wysokoscWysokiejSzufladyMM = migawka.wysokoscWysokiejSzufladyMM
        wysokosciNiestandardowe = migawka.wysokosciNiestandardowe
        typFrontu = migawka.typFrontu
        odsuniecieOdScianBocznychMM =
            migawka.odsuniecieOdScianBocznychMM
        // Zwolnij flagę po zakończeniu propagacji zmian
        DispatchQueue.main.async {
            wstrzymajHistorie = false
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
                selectedProfileID,
            odsuniecieOdScianBocznychMM:
                typFrontu == .wewnetrzny
                ? max(odsuniecieOdScianBocznychMM, 0)
                : 0
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
            .generujZPresetu(
                preset: aktualnyPreset,
                parametryBazowe: parameters,
                dla: karta
            )
    }

    /// Ile frontów zmieści się w tej szafce.
    ///
    /// Wcześniej stało tu `1...30` przy liczniku i `>= 10` przy dodawaniu —
    /// dwie różne liczby wzięte z powietrza, w jednym oknie. Trzydzieści
    /// szuflad w szafce pod blatem oznacza fronty po kilkanaście milimetrów,
    /// czyli coś, czego nie da się zrobić.
    ///
    /// `DrawerFrontStack.maximumCount` liczy to z wysokości: front nie może
    /// zejść poniżej `minimumFrontHeight`, bo nie ma gdzie zmieścić uchwytu.
    /// Dzięki temu słupek 2000 mm pozwala na więcej niż szafka 720 mm,
    /// zamiast obu ograniczać tą samą wymyśloną liczbą.
    private var maksymalnaLiczbaFrontow: Int {
        max(
            DrawerFrontStack.maximumCount(
                zoneHeight: Millimeters(geometry.wysokoscMM),
                gap: Millimeters(szczelinaMM),
                bottomMargin: Millimeters(marginesDolnyMM),
                topMargin: Millimeters(marginesGornyMM)
            ),
            1
        )
    }

    private var uzytecznaWysokoscMM: Double {
        max(
            geometry.wysokoscMM
            - marginesDolnyMM
            - marginesGornyMM,
            0
        )
    }

    @ViewBuilder
    private var presetHelpText: some View {
        Text(presetOpis)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var presetOpis: String {
        switch rodzajPresetu {
        case .rowne:
            return "Wszystkie szuflady o tej samej wysokości frontu."
        case .jednaWysokaDwieNiskie:
            return "Wysoka szuflada u góry (np. na garnki), dwie niższe pod spodem. Wolna wysokość dzielona jest po równo."
        case .wysokaNaDoleDwieNiskie:
            return "Wysoka szuflada na dole, dwie niskie powyżej. To typowy układ dla garnków pod blatem i płytkich szuflad pomocniczych."
        case .dwieWysokie:
            return "Dwie szuflady dzielące strefę na równe połowy."
        case .wysokosciNiestandardowe:
            return "Ręczne proporcje frontów od dołu do góry. Wysokości są skalowane tak, żeby fronty wypełniły \(mm(uzytecznaWysokoscMM)) co do milimetra — liczy się stosunek między nimi, nie suma."
        case .cargo:
            return "Pojedynczy front zewnętrzny na całą użyteczną wysokość (\(mm(uzytecznaWysokoscMM))). Wewnątrz montowany jest kosz Cargo (np. Blum SPACE TOWER, Peka)."
        }
    }

    @ViewBuilder
    private var wysokosciNiestandardoweEditor: some View {
        ForEach(
            Array(wysokosciNiestandardowe.enumerated()),
            id: \.offset
        ) { pair in
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Szuflada \(pair.offset + 1)")
                    .font(.subheadline.weight(.semibold))

                HStack {
                    Picker(
                        "Standard",
                        selection: Binding(
                            get: {
                                najblizszyStandardSzuflady(
                                    dla:
                                        wysokosciNiestandardowe[
                                            pair.offset
                                        ]
                                )
                            },
                            set: {
                                wysokosciNiestandardowe[
                                    pair.offset
                                ] =
                                    $0.wysokoscFrontuMM
                            }
                        )
                    ) {
                        ForEach(
                            StandardWysokoscSzuflady.allCases
                        ) { standard in
                            Text(standard.opis)
                                .tag(standard)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    TextField(
                        "mm",
                        value: Binding(
                            get: { wysokosciNiestandardowe[pair.offset] },
                            set: { wysokosciNiestandardowe[pair.offset] = $0 }
                        ),
                        format: .number
                    )
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)

                    Text("mm")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onDelete { indexSet in
            wysokosciNiestandardowe.remove(atOffsets: indexSet)
        }

        HStack {
            Button {
                wysokosciNiestandardowe.append(140)
            } label: {
                Label("Dodaj szufladę", systemImage: "plus.circle")
            }
            .disabled(
                wysokosciNiestandardowe.count
                >= maksymalnaLiczbaFrontow
            )

            Spacer()

            Button(role: .destructive) {
                if wysokosciNiestandardowe.count > 1 {
                    wysokosciNiestandardowe.removeLast()
                }
            } label: {
                Label("Usuń ostatnią", systemImage: "minus.circle")
            }
            .disabled(wysokosciNiestandardowe.count <= 1)
        }

        podsumowanieWypelnieniaFrontow
    }

    /// Co naprawdę wyjdzie po przeliczeniu.
    ///
    /// Wcześniej stała tu sama „Suma wysokości" — liczba, której nic nie
    /// egzekwowało. Podane wysokości są **proporcjami**: silnik skaluje je tak,
    /// żeby fronty domknęły szafkę co do milimetra (`DrawerFrontStack`).
    /// Pokazujemy więc wynik, a nie wejście — inaczej projektant wpisuje
    /// 140/140/280 i nie wie, że dostanie 176/176/354.
    @ViewBuilder
    private var podsumowanieWypelnieniaFrontow: some View {
        let wynikowe = generatedDrawers.map(\.wysokoscFrontuMM)

        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(
                "Wpisane proporcje",
                value: wysokosciNiestandardowe
                    .map { mm($0) }
                    .joined(separator: " · ")
            )

            if !wynikowe.isEmpty {
                LabeledContent(
                    "Fronty po przeliczeniu",
                    value: wynikowe
                        .map { mm($0) }
                        .joined(separator: " · ")
                )
                .font(.body.weight(.semibold))

                Text(
                    "Wysokości skalują się do \(mm(uzytecznaWysokoscMM)) "
                    + "użytecznej wysokości, więc fronty zakrywają cały mebel. "
                    + "Zmiana proporcji zmienia podział, nie sumę."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aktualnyPreset: PresetUkladuSzuflad {
        switch rodzajPresetu {
        case .rowne:
            return .rowne(liczba: liczba)
        case .jednaWysokaDwieNiskie:
            return .jednaWysokaDwieNiskie(
                wysokaMM: wysokoscWysokiejSzufladyMM
            )
        case .wysokaNaDoleDwieNiskie:
            return .wysokaNaDoleDwieNiskie(
                wysokaMM: wysokoscWysokiejSzufladyMM
            )
        case .dwieWysokie:
            return .dwieWysokie
        case .wysokosciNiestandardowe:
            return .wysokosciNiestandardowe(
                wysokosciNiestandardowe
            )
        case .cargo:
            return .cargo
        }
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
                    let scaleX =
                        cabinetRect.width
                        / max(
                            geometry.szerokoscMM,
                            1
                        )
                    let sideInset =
                        min(
                            drawer
                                .efektywneOdsuniecieOdScianBocznychMM
                            * scaleX,
                            cabinetRect.width / 2
                        )
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
                            max(
                                cabinetRect.width
                                - 8
                                - sideInset * 2,
                                3
                            ),
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
            odsuniecieOdScianBocznychMM =
                typFrontu == .wewnetrzny
                ? (
                    first.odsuniecieOdScianBocznychMM
                    ?? 21
                )
                : 0
            odtworzUkladZIstniejacychSzuflad()
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

    private func odtworzUkladZIstniejacychSzuflad() {
        let drawers =
            karta
                .efektywneSzuflady
                .filter(\.aktywna)
                .sorted {
                    $0.pozycjaDolnaYMM
                    < $1.pozycjaDolnaYMM
                }

        guard !drawers.isEmpty else {
            return
        }

        wysokosciNiestandardowe =
            drawers.map(\.wysokoscFrontuMM)

        if drawers.count == 1,
           drawers.first?.efektywnyWariant == .cargo {
            rodzajPresetu = .cargo
            return
        }

        if Set(
            drawers.map {
                Int($0.wysokoscFrontuMM.rounded())
            }
        )
        .count == 1 {
            rodzajPresetu = .rowne
            return
        }

        rodzajPresetu = .wysokosciNiestandardowe
    }

    private func najblizszyStandardSzuflady(
        dla wysokoscMM: Double
    ) -> StandardWysokoscSzuflady {
        StandardWysokoscSzuflady
            .allCases
            .min {
                abs(
                    $0.wysokoscFrontuMM
                    - wysokoscMM
                )
                < abs(
                    $1.wysokoscFrontuMM
                    - wysokoscMM
                )
            }
        ?? .srednia
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
