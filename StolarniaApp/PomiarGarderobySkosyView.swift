import DomainCore
import SwiftUI

struct PomiarGarderobySkosyView:
    View
{
    @StateObject private var repository =
        PomiarGarderobySkosyRepository()

    @State private var selectedID:
        UUID?
    @State private var draft =
        PomiarGarderobySkosy()
    @State private var workingRoomV069:
        RoomDefinition?
    @State private var isSavingV069 =
        false
    @State private var saveMessageV069:
        String?
    @State private var saveErrorV069:
        String?

    @State private var showingHOTOPanelV0692 =
        false

    // MARK: - Generator profilu liniowego Typ 2
    @State private var genWysScianaMM: Double = 0
    @State private var genWysFrontMM: Double = 0

    private let context:
        KontekstPomiaruPomieszczenia?
    private let initialMeasurementID:
        UUID?
    private let onSaveRoomV069:
        ((RoomDefinition) async -> Bool)?

    init(
        context:
            KontekstPomiaruPomieszczenia?
            = nil,
        initialMeasurementID:
            UUID?
            = nil,
        room:
            RoomDefinition?
            = nil,
        onSaveRoom:
            ((RoomDefinition) async -> Bool)?
            = nil
    ) {
        self.context = context
        self.initialMeasurementID =
            initialMeasurementID
        self.onSaveRoomV069 =
            onSaveRoom
        self._workingRoomV069 =
            State(
                initialValue: room
            )
    }

    private var visibleMeasurements:
        [PomiarGarderobySkosy]
    {
        guard let context else {
            return repository.pomiary
        }

        return repository.measurements(
            projectID:
                context.projectID,
            roomID:
                context.roomID
        )
    }

    private var availableWallsV069:
        [WallSegment]
    {
        workingRoomV069?
            .geometry
            .walls
        ?? []
    }

    private var selectedWallV069:
        WallSegment?
    {
        guard let raw =
                draft.wallIDRawValueV069,
              let wallID =
                WallID(raw)
        else {
            return nil
        }

        return workingRoomV069?
            .geometry
            .wall(
                id: wallID
            )
    }

    var body: some View {
        NavigationSplitView {
            List(
                selection:
                    $selectedID
            ) {
                ForEach(
                    visibleMeasurements
                ) { pomiar in
                    Button {
                        select(pomiar)
                    } label: {
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(
                                pomiar
                                    .nazwaPomieszczenia
                            )
                            .font(.headline)

                            Text(
                                pomiar.klient
                                    .isEmpty
                                ? "Bez klienta"
                                : pomiar.klient
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(
                    perform: delete
                )
            }
            .navigationTitle(
                "Pomiary skosów"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .primaryAction
                ) {
                    Button {
                        let new =
                            repository
                                .addNew(
                                    context:
                                        context
                                )
                        select(new)
                    } label: {
                        Label(
                            "Nowy pomiar",
                            systemImage: "plus"
                        )
                    }
                }
            }
        } detail: {
            if selectedID == nil {
                ContentUnavailableView(
                    "Rozpocznij pomiar skosu",
                    systemImage:
                        "triangle.righthalf.filled",
                    description: Text(
                        "Naciśnij „Nowy pomiar”, wybierz ścianę i uzupełniaj profil od lewej do prawej."
                    )
                )
            } else {
                measurementForm
            }
        }
        .navigationSplitViewStyle(
            .balanced
        )
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .onAppear {
            repository.reload()

            if let initialMeasurementID,
               let measurement =
                    visibleMeasurements
                        .first(
                            where: {
                                $0.id
                                    == initialMeasurementID
                            }
                        ) {
                select(measurement)
            } else if selectedID == nil,
                      visibleMeasurements.count == 1,
                      let measurement =
                        visibleMeasurements.first {
                select(measurement)
            }
        }
        .sheet(
            isPresented:
                $showingHOTOPanelV0692
        ) {
            PanelDalmierzaHOTOV0692(
                draft: $draft
            )
        }
        .alert(
            "Zapisano pomiar skosu",
            isPresented:
                Binding(
                    get: {
                        saveMessageV069
                            != nil
                    },
                    set: {
                        if !$0 {
                            saveMessageV069 =
                                nil
                        }
                    }
                )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                saveMessageV069 =
                    nil
            }
        } message: {
            Text(
                saveMessageV069
                ?? ""
            )
        }
        .alert(
            "Nie udało się zapisać skosu",
            isPresented:
                Binding(
                    get: {
                        saveErrorV069
                            != nil
                    },
                    set: {
                        if !$0 {
                            saveErrorV069 =
                                nil
                        }
                    }
                )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                saveErrorV069 =
                    nil
            }
        } message: {
            Text(
                saveErrorV069
                ?? "Nieznany błąd"
            )
        }
    }

    private var measurementForm:
        some View
    {
        Form {
            Section("Zlecenie") {
                TextField(
                    "Nazwa pomieszczenia",
                    text:
                        $draft
                            .nazwaPomieszczenia
                )

                TextField(
                    "Klient",
                    text:
                        $draft.klient
                )

                TextField(
                    "Adres",
                    text:
                        $draft.adres
                )

                DatePicker(
                    "Data pomiaru",
                    selection:
                        $draft.dataPomiaru,
                    displayedComponents:
                        .date
                )
            }

            Section("Powiązanie z pomieszczeniem") {
                if workingRoomV069 == nil {
                    Label(
                        "Pomiar nie jest otwarty z poziomu konkretnego pomieszczenia. Zostanie zapisany jako formularz bez profilu ściany.",
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .foregroundStyle(
                        .orange
                    )
                } else {
                    Picker(
                        "Ściana",
                        selection:
                            Binding(
                                get: {
                                    draft
                                        .wallIDRawValueV069
                                    ?? ""
                                },
                                set: {
                                    updateSelectedWallV069(
                                        rawValue: $0
                                    )
                                }
                            )
                    ) {
                        Text(
                            "Wybierz ścianę"
                        )
                        .tag("")

                        ForEach(
                            availableWallsV069
                        ) { wall in
                            Text(wall.name)
                                .tag(
                                    wall.id
                                        .description
                                )
                        }
                    }

                    if let wall =
                            selectedWallV069,
                       let geometry =
                            workingRoomV069?
                                .geometry
                                .geometry(
                                    of: wall.id
                                ) {
                        LabeledContent(
                            "Długość ściany",
                            value:
                                mm(
                                    geometry
                                        .length
                                        .rawValue
                                )
                        )

                        LabeledContent(
                            "Wysokość bazowa",
                            value:
                                mm(
                                    max(
                                        wall.startHeight,
                                        wall.endHeight
                                    )
                                    .rawValue
                                )
                        )
                    }

                    Toggle(
                        "Zapisz profil w geometrii pomieszczenia",
                        isOn:
                            Binding(
                                get: {
                                    draft
                                        .zastosujDoPomieszczeniaV069
                                },
                                set: {
                                    draft
                                        .zastosujDoPomieszczeniaV069 =
                                            $0
                                }
                            )
                    )
                }
            }

            Section("Dalmierz HOTO") {
                Button {
                    draft.producentUrzadzeniaV069 = "HOTO"
                    draft.zrodloPomiaruV069 = .bluetooth
                    showingHOTOPanelV0692 = true
                } label: {
                    Label(
                        "Połącz i odbierz pomiar z HOTO",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(.borderedProminent)

                if let date = draft.bleLastMeasurementAtV0692 {
                    LabeledContent(
                        "Ostatni pomiar BLE",
                        value: date.formatted(
                            date: .abbreviated,
                            time: .standard
                        )
                    )
                }

                Label(
                    "Włącz dalmierz HOTO D50, naciśnij przycisk BT na urządzeniu aż dioda zacznie migać, a następnie kliknij przycisk powyżej.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Źródło i wiarygodność pomiaru") {
                Picker(
                    "Źródło",
                    selection:
                        Binding(
                            get: { draft.zrodloPomiaruV069 },
                            set: { draft.zrodloPomiaruV069 = $0 }
                        )
                ) {
                    ForEach(ZrodloPomiaruSkosuV069.allCases) { source in
                        Label(source.nazwa, systemImage: source.systemImage)
                            .tag(source)
                    }
                }

                if draft.zrodloPomiaruV069 == .bluetooth {
                    TextField(
                        "Model dalmierza",
                        text: optionalTextBindingV069(\.modelUrzadzeniaV069)
                    )
                    TextField(
                        "Numer seryjny (opcjonalnie)",
                        text: optionalTextBindingV069(\.numerSeryjnyUrzadzeniaV069)
                    )
                }

                dimension(
                    "Tolerancja pomiaru",
                    value:
                        Binding(
                            get: {
                                draft
                                    .tolerancjaDomyslnaV069
                            },
                            set: {
                                draft
                                    .tolerancjaDomyslnaV069 =
                                        $0
                            }
                        )
                )

                Toggle(
                    "Pomiar zweryfikowany ręcznie",
                    isOn:
                        Binding(
                            get: {
                                draft
                                    .profilZweryfikowanyV069
                            },
                            set: {
                                draft
                                    .profilZweryfikowanyV069 =
                                        $0
                            }
                        )
                )

                if let date =
                        draft
                            .dataWeryfikacjiV069 {
                    LabeledContent(
                        "Weryfikacja",
                        value:
                            date.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                    )
                }
            }

            Section("Podgląd profilu") {
                ProfilSkosuCanvasView(
                    pomiar: draft
                )
                .listRowInsets(
                    EdgeInsets()
                )
                .listRowBackground(
                    Color.clear
                )

                if draft.profilJestKompletny {
                    Label(
                        "Profil zawiera wszystkie podstawowe dane.",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        .green
                    )
                } else {
                    ForEach(
                        draft.ostrzezeniaPomiarowe,
                        id: \.self
                    ) { warning in
                        Label(
                            warning,
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            .orange
                        )
                    }
                }
            }

            Section("Geometria bazowa") {
                // MARK: Kierunek profilu (Typ 1 vs Typ 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rodzaj skosu").font(.subheadline)
                    Picker(
                        "Rodzaj skosu",
                        selection:
                            Binding(
                                get: { draft.kierunekProfiluV069 },
                                set: { draft.kierunekProfiluV069 = $0 }
                            )
                    ) {
                        ForEach(KierunekProfiluSkosuV069.allCases) { kierunek in
                            Text(kierunek.nazwa).tag(kierunek)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch draft.kierunekProfiluV069 {
                    case .wzdluzSciany:
                        Label(
                            "Typ 1 — skos wzdłuż ściany: sufit opada w lewo lub w prawo. Szafa jest skośnie ścięta od góry. Stosuj w garderobach na poddaszu z niską ścianką kolankową.",
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    case .wGlabPomieszczenia:
                        Label(
                            "Typ 2 — skos w głąb mebla: sufit obniża się od frontu szafy ku ścianie. Szafa stoi prosto, ale ma ucięty tył. Stosuj gdy mebel wchodzi pod pochyły strop (np. garderoba pod schodami lub skośnym stropem).",
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.tint)
                    }
                }

                if draft.kierunekProfiluV069 == .wzdluzSciany {
                    dimension(
                        "Szerokość ściany",
                        value: $draft.szerokoscScianyMM
                    )
                }

                dimension(
                    "Wysokość maksymalna",
                    value:
                        $draft
                            .wysokoscMaksymalnaMM
                )

                if draft.kierunekProfiluV069 == .wzdluzSciany {
                    dimension(
                        "Ścianka kolankowa",
                        value:
                            $draft
                                .wysokoscSciankiKolankowejMM
                    )
                }

                dimension(
                    "Docelowa głębokość",
                    value:
                        $draft
                            .glebokoscDocelowaMM
                )

                if draft.kierunekProfiluV069 == .wzdluzSciany {
                    Picker(
                        "Układ skosu",
                        selection:
                            $draft.stronaSkosu
                    ) {
                        ForEach(
                            StronaSkosu
                                .allCases
                        ) { value in
                            Text(value.nazwa)
                                .tag(value)
                        }
                    }
                }

                if draft.kierunekProfiluV069 == .wzdluzSciany {
                HStack {
                    Text("Kąt skosu")

                    Spacer()

                    TextField(
                        "np. 35",
                        value:
                            Binding(
                                get: {
                                    draft
                                        .katRecznyStopniV069
                                    ?? 0
                                },
                                set: {
                                    draft
                                        .katRecznyStopniV069 =
                                            $0 > 0
                                            ? $0
                                            : nil
                                }
                            ),
                        format:
                            .number
                            .grouping(.never)
                            .precision(
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
                    .frame(width: 110)

                    Text("°")
                        .foregroundStyle(
                            .secondary
                        )
                }

                if let entered = draft.katRecznyStopniV069,
                   entered > 0 {
                    let maxKat = SilnikSkosuPomieszczeniaV069.maksymalnyKatStopnie(
                        szerokoscScianyMM: draft.szerokoscScianyMM,
                        wysokoscMaksymalnaMM: draft.wysokoscMaksymalnaMM
                    )
                    if entered > maxKat {
                        Label(
                            "Kąt \(entered.formatted(.number.precision(.fractionLength(1))))° jest zbyt stromy. Maksymalny kąt dla tej ściany: \(maxKat.formatted(.number.precision(.fractionLength(1))))°.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                }

                Button {
                    applyManualAngleV069()
                } label: {
                    Label(
                        "Przelicz profil z kąta",
                        systemImage: "angle"
                    )
                }
                .disabled(
                    (
                        draft
                            .katRecznyStopniV069
                        ?? 0
                    ) <= 0
                )

                Button {
                    rebuildBaseProfileV069()
                } label: {
                    Label(
                        "Utwórz profil z wymiarów bazowych",
                        systemImage:
                            "wand.and.stars"
                    )
                }
                } // end if wzdluzSciany
            }

            Section(
                draft.kierunekProfiluV069 == .wGlabPomieszczenia
                    ? "Punkty profilu głębokości (0 = przy ścianie)"
                    : "Punkty profilu skosu"
            ) {
                // MARK: Generator Typ 2
                if draft.kierunekProfiluV069 == .wGlabPomieszczenia {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Generator profilu liniowego — wpisz dwa pomiary stropu i wygeneruj gotowy 2-punktowy profil. Zastępuje istniejące punkty.",
                            systemImage: "wand.and.stars"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        dimension(
                            "Wys. stropu przy ścianie [mm]",
                            value: $genWysScianaMM
                        )

                        dimension(
                            "Wys. stropu przy froncie [mm]",
                            value: $genWysFrontMM
                        )

                        Button {
                            generateLinearProfilTyp2V069()
                        } label: {
                            Label(
                                "Wygeneruj profil 2-punktowy",
                                systemImage: "wand.and.rays"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(
                            genWysScianaMM <= 0
                            || genWysFrontMM <= 0
                            || draft.glebokoscDocelowaMM <= 0
                        )
                    }
                    .padding(.vertical, 4)

                    Divider()
                }

                ForEach(
                    $draft.punktySkosu
                ) { $punkt in
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        dimension(
                            draft.kierunekProfiluV069 == .wGlabPomieszczenia
                                ? "Od ściany (głębokość)"
                                : "Od lewej",
                            value:
                                $punkt
                                    .odlegloscOdLewejMM
                        )

                        dimension(
                            "Wysokość",
                            value:
                                $punkt
                                    .wysokoscMM
                        )

                        TextField(
                            "Uwagi",
                            text:
                                $punkt.uwagi
                        )

                        Picker(
                            "Źródło punktu",
                            selection:
                                Binding(
                                    get: {
                                        punkt
                                            .zrodloV069
                                    },
                                    set: {
                                        punkt
                                            .zrodloV069 =
                                                $0
                                    }
                                )
                        ) {
                            ForEach(
                                ZrodloPomiaruSkosuV069
                                    .allCases
                            ) { source in
                                Text(source.nazwa)
                                    .tag(source)
                            }
                        }

                        Toggle(
                            "Punkt potwierdzony",
                            isOn:
                                Binding(
                                    get: {
                                        punkt
                                            .potwierdzonyV069
                                    },
                                    set: {
                                        punkt
                                            .potwierdzonyV069 =
                                                $0
                                    }
                                )
                        )
                    }
                }
                .onDelete {
                    draft.punktySkosu
                        .remove(
                            atOffsets: $0
                        )
                }

                Button {
                    if draft.kierunekProfiluV069 == .wGlabPomieszczenia {
                        // Typ 2: nowy punkt na połowie głębokości
                        let existingX = draft.punktySkosu
                            .map(\.odlegloscOdLewejMM)
                        let nextX = stride(
                            from: 0.0,
                            through: draft.glebokoscDocelowaMM,
                            by: max(50, draft.glebokoscDocelowaMM / 10)
                        )
                        .first { x in !existingX.contains(where: { abs($0 - x) < 1 }) }
                        ?? draft.glebokoscDocelowaMM / 2

                        draft.punktySkosu.append(
                            PunktPomiarowySkosu(
                                odlegloscOdLewejMM: nextX,
                                wysokoscMM: draft.wysokoscMaksymalnaMM,
                                uwagi: ""
                            )
                        )
                    } else {
                        draft.punktySkosu
                            .append(
                                PunktPomiarowySkosu(
                                    odlegloscOdLewejMM:
                                        draft
                                            .szerokoscScianyMM,
                                    wysokoscMM:
                                        draft
                                            .wysokoscSciankiKolankowejMM,
                                    uwagi: ""
                                )
                            )
                    }
                } label: {
                    Label(
                        "Dodaj punkt skosu",
                        systemImage: "plus"
                    )
                }
            }

            Section("Kontrola pionów i poziomów") {
                dimension(
                    "Odchylenie podłogi",
                    value:
                        $draft
                            .odchyleniePodlogiMM
                )

                dimension(
                    "Odchylenie lewej ściany",
                    value:
                        $draft
                            .odchylenieLewejScianyMM
                )

                dimension(
                    "Odchylenie prawej ściany",
                    value:
                        $draft
                            .odchyleniePrawejScianyMM
                )

                Toggle(
                    "Nierówna podłoga",
                    isOn:
                        $draft
                            .maNierownaPodloge
                )

                Toggle(
                    "Nierówne ściany",
                    isOn:
                        $draft
                            .maNierowneSciany
                )
            }

            Section("Przeszkody i instalacje") {
                Toggle(
                    "Listwy przypodłogowe",
                    isOn:
                        $draft
                            .maListwyPrzypodlogowe
                )

                Toggle(
                    "Gniazda",
                    isOn:
                        $draft.maGniazda
                )

                Toggle(
                    "Grzejnik",
                    isOn:
                        $draft.maGrzejnik
                )

                Toggle(
                    "Okno dachowe",
                    isOn:
                        $draft
                            .maOknoDachowe
                )

                Toggle(
                    "Drzwi",
                    isOn:
                        $draft.maDrzwi
                )

                Toggle(
                    "Belki konstrukcyjne",
                    isOn:
                        $draft.maBelki
                )

                ForEach(
                    $draft.przeszkody
                ) { $item in
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        TextField(
                            "Nazwa przeszkody",
                            text:
                                $item.nazwa
                        )

                        dimension(
                            "Od lewej",
                            value:
                                $item.odLewejMM
                        )

                        dimension(
                            "Od podłogi",
                            value:
                                $item.odPodlogiMM
                        )

                        dimension(
                            "Szerokość",
                            value:
                                $item.szerokoscMM
                        )

                        dimension(
                            "Wysokość",
                            value:
                                $item.wysokoscMM
                        )

                        dimension(
                            "Głębokość",
                            value:
                                $item.glebokoscMM
                        )
                    }
                }
                .onDelete {
                    draft.przeszkody
                        .remove(
                            atOffsets: $0
                        )
                }

                Button {
                    draft.przeszkody
                        .append(
                            PrzeszkodaPomiarowa(
                                nazwa: "Nowa przeszkoda",
                                odLewejMM: 0,
                                odPodlogiMM: 0,
                                szerokoscMM: 0,
                                wysokoscMM: 0,
                                glebokoscMM: 0,
                                uwagi: ""
                            )
                        )
                } label: {
                    Label(
                        "Dodaj przeszkodę",
                        systemImage:
                            "plus.rectangle.on.rectangle"
                    )
                }
            }

            Section("Podsumowanie") {
                LabeledContent(
                    "Minimalna wysokość",
                    value:
                        mm(
                            draft
                                .minimalnaWysokoscMM
                        )
                )

                LabeledContent(
                    "Maksymalna wysokość",
                    value:
                        mm(
                            draft
                                .maksymalnaWysokoscZMiarMM
                        )
                )

                if let angle =
                    draft
                        .przyblizonyKatSkosuStopnie {
                    LabeledContent(
                        "Przybliżony kąt",
                        value:
                            angle.formatted(
                                .number.precision(
                                    .fractionLength(1)
                                )
                            )
                            + "°"
                    )
                }

                LabeledContent(
                    "Rezerwa montażowa",
                    value:
                        mm(
                            draft
                                .wymaganaRezerwaMontazowaMM
                        )
                )
            }

            Section("Lista kontrolna") {
                checklist(
                    "Zmierzono ścianę przy podłodze, w połowie i przy suficie"
                )

                checklist(
                    "Sprawdzono oba narożniki kątownikiem lub laserem"
                )

                checklist(
                    "Zapisano profil skosu w minimum dwóch punktach; trzeci punkt służy do kontroli"
                )

                checklist(
                    "Zmierzono głębokość na kilku wysokościach"
                )

                checklist(
                    "Zaznaczono gniazda, grzejnik, listwy, belki i okno dachowe"
                )

                checklist(
                    "Wykonano zdjęcie całej ściany i każdego narożnika"
                )

                checklist(
                    "Sprawdzono drogę wniesienia gotowych elementów"
                )
            }

            Section("Notatki") {
                TextEditor(
                    text:
                        $draft.notatki
                )
                .frame(
                    minHeight: 140
                )
            }
        }
        .navigationTitle(
            draft.nazwaPomieszczenia
        )
        .toolbar {
            ToolbarItemGroup(
                placement:
                    .primaryAction
            ) {
                Button {
                    sortProfilePoints()
                } label: {
                    Label(
                        "Uporządkuj punkty",
                        systemImage:
                            "arrow.up.arrow.down"
                    )
                }
                .disabled(
                    draft.punktySkosu.count < 2
                )

                Button {
                    saveMeasurementV069()
                } label: {
                    Label(
                        isSavingV069
                        ? "Zapisywanie…"
                        : "Zapisz",
                        systemImage:
                            isSavingV069
                            ? "hourglass"
                            : "checkmark"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    isSavingV069
                )
            }
        }
    }

    private func optionalTextBindingV069(
        _ keyPath:
            WritableKeyPath<
                PomiarGarderobySkosy,
                String?
            >
    ) -> Binding<String> {
        Binding(
            get: {
                draft[
                    keyPath: keyPath
                ]
                ?? ""
            },
            set: {
                let value =
                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

                draft[
                    keyPath: keyPath
                ] =
                    value.isEmpty
                    ? nil
                    : value
            }
        )
    }

    private func updateSelectedWallV069(
        rawValue: String
    ) {
        guard !rawValue.isEmpty,
              let wallID =
                WallID(rawValue),
              let room =
                workingRoomV069,
              let wall =
                room.geometry.wall(
                    id: wallID
                ),
              let geometry =
                room.geometry.geometry(
                    of: wallID
                )
        else {
            draft.wallIDRawValueV069 =
                nil
            draft.wallNameV069 =
                nil
            return
        }

        draft.wallIDRawValueV069 =
            wall.id.description
        draft.wallNameV069 =
            wall.name
        draft.szerokoscScianyMM =
            geometry.length.rawValue
        draft.wysokoscMaksymalnaMM =
            max(
                wall.startHeight,
                wall.endHeight
            )
            .rawValue

        if draft.punktySkosu.count < 2 {
            rebuildBaseProfileV069()
        }
    }

    private func applyManualAngleV069() {
        guard let angle =
                draft.katRecznyStopniV069,
              angle > 0,
              angle < 90
        else {
            return
        }

        draft.punktySkosu =
            SilnikSkosuPomieszczeniaV069
                .przygotujProfilZKata(
                    katStopnie:
                        angle,
                    szerokoscScianyMM:
                        draft
                            .szerokoscScianyMM,
                    wysokoscMaksymalnaMM:
                        draft
                            .wysokoscMaksymalnaMM,
                    strona:
                        draft.stronaSkosu
                )
                .map {
                    var point = $0
                    point.zrodloV069 =
                        .reczny
                    point.tolerancjaMMV069 =
                        draft
                            .tolerancjaDomyslnaV069
                    return point
                }

        // Keep kneewall height in sync with
        // the computed low point.
        if let low =
            draft.punktySkosu
                .map(\.wysokoscMM)
                .min() {
            draft
                .wysokoscSciankiKolankowejMM =
                    low
        }
    }

    private func rebuildBaseProfileV069() {
        draft.punktySkosu =
            SilnikSkosuPomieszczeniaV069
                .przygotujProfilDwupunktowy(
                    szerokoscScianyMM:
                        draft
                            .szerokoscScianyMM,
                    wysokoscMaksymalnaMM:
                        draft
                            .wysokoscMaksymalnaMM,
                    wysokoscNiskaMM:
                        draft
                            .wysokoscSciankiKolankowejMM,
                    strona:
                        draft
                            .stronaSkosu
                )
                .map {
                    var point = $0
                    point.zrodloV069 =
                        draft
                            .zrodloPomiaruV069
                    point.tolerancjaMMV069 =
                        draft
                            .tolerancjaDomyslnaV069
                    point.nazwaUrzadzeniaV069 =
                        draft
                            .opisUrzadzeniaV069
                            .isEmpty
                        ? nil
                        : draft
                            .opisUrzadzeniaV069
                    return point
                }
    }

    // MARK: - Generator profilu Typ 2

    private func generateLinearProfilTyp2V069() {
        guard
            draft.glebokoscDocelowaMM > 0,
            genWysScianaMM > 0,
            genWysFrontMM > 0
        else { return }

        let p1 = PunktPomiarowySkosu(
            odlegloscOdLewejMM: 0,
            wysokoscMM: genWysScianaMM,
            uwagi: "Przy ścianie (x=0)"
        )
        var p1Copy = p1
        p1Copy.zrodloV069 = draft.zrodloPomiaruV069
        p1Copy.tolerancjaMMV069 = draft.tolerancjaDomyslnaV069

        let p2 = PunktPomiarowySkosu(
            odlegloscOdLewejMM: draft.glebokoscDocelowaMM,
            wysokoscMM: genWysFrontMM,
            uwagi: "Przy froncie (x=głębokość)"
        )
        var p2Copy = p2
        p2Copy.zrodloV069 = draft.zrodloPomiaruV069
        p2Copy.tolerancjaMMV069 = draft.tolerancjaDomyslnaV069

        draft.punktySkosu = [p1Copy, p2Copy]

        // Synchronizuj wysokość maksymalną
        draft.wysokoscMaksymalnaMM =
            max(genWysScianaMM, genWysFrontMM)
    }

    private func saveMeasurementV069() {
        guard !isSavingV069 else {
            return
        }

        sortProfilePoints()

        let defaultSourceV069 =
            draft.zrodloPomiaruV069
        let defaultToleranceV069 =
            draft.tolerancjaDomyslnaV069
        let deviceDescriptionV069 =
            draft.opisUrzadzeniaV069
        let measurementDateV069 =
            Date()

        for index in draft
            .punktySkosu
            .indices {
            if draft
                .punktySkosu[index]
                .zrodloRawValueV069 == nil {
                draft
                    .punktySkosu[index]
                    .zrodloV069 =
                        defaultSourceV069
            }

            if draft
                .punktySkosu[index]
                .tolerancjaMMV069 == nil {
                draft
                    .punktySkosu[index]
                    .tolerancjaMMV069 =
                        defaultToleranceV069
            }

            if draft
                .punktySkosu[index]
                .nazwaUrzadzeniaV069 == nil,
               !deviceDescriptionV069
                    .isEmpty {
                draft
                    .punktySkosu[index]
                    .nazwaUrzadzeniaV069 =
                        deviceDescriptionV069
            }

            if draft
                .punktySkosu[index]
                .zmierzonoAtV069 == nil {
                draft
                    .punktySkosu[index]
                    .zmierzonoAtV069 =
                        measurementDateV069
            }
        }

        repository.upsert(draft)

        guard draft
                .zastosujDoPomieszczeniaV069,
              let room =
                workingRoomV069,
              let onSaveRoomV069
        else {
            saveMessageV069 =
                "Formularz pomiarowy został zapisany."
            return
        }

        isSavingV069 = true
        saveErrorV069 = nil

        Task {
            do {
                let updatedRoom =
                    try SilnikSkosuPomieszczeniaV069
                        .zastosuj(
                            pomiar: draft,
                            do: room
                        )

                let saved =
                    await onSaveRoomV069(
                        updatedRoom
                    )

                await MainActor.run {
                    isSavingV069 = false

                    if saved {
                        workingRoomV069 =
                            updatedRoom
                        saveMessageV069 =
                            "Profil został zapisany w pomieszczeniu i jest używany w elewacji 2D."
                    } else {
                        saveErrorV069 =
                            "Repozytorium nie potwierdziło zapisu pomieszczenia."
                    }
                }
            } catch {
                await MainActor.run {
                    isSavingV069 = false
                    saveErrorV069 =
                        error
                            .localizedDescription
                }
            }
        }
    }

    private func sortProfilePoints() {
        draft.punktySkosu.sort {
            $0.odlegloscOdLewejMM
            < $1.odlegloscOdLewejMM
        }
    }

    private func select(
        _ pomiar:
            PomiarGarderobySkosy
    ) {
        var selected =
            pomiar

        if selected
                .wallIDRawValueV069 == nil,
           let room =
                workingRoomV069,
           let wall =
                room.geometry
                    .walls
                    .first,
           let geometry =
                room.geometry.geometry(
                    of: wall.id
                ) {
            selected
                .wallIDRawValueV069 =
                    wall.id.description
            selected
                .wallNameV069 =
                    wall.name
            selected
                .szerokoscScianyMM =
                    geometry.length.rawValue
            selected
                .wysokoscMaksymalnaMM =
                    max(
                        wall.startHeight,
                        wall.endHeight
                    )
                    .rawValue

            if selected
                .punktySkosu
                .count < 2 {
                selected
                    .punktySkosu =
                        SilnikSkosuPomieszczeniaV069
                            .przygotujProfilDwupunktowy(
                                szerokoscScianyMM:
                                    selected
                                        .szerokoscScianyMM,
                                wysokoscMaksymalnaMM:
                                    selected
                                        .wysokoscMaksymalnaMM,
                                wysokoscNiskaMM:
                                    selected
                                        .wysokoscSciankiKolankowejMM,
                                strona:
                                    selected
                                        .stronaSkosu
                            )
            }
        }

        selectedID =
            selected.id
        draft = selected
    }

    private func delete(
        at offsets:
            IndexSet
    ) {
        let ids =
            offsets.map {
                visibleMeasurements[$0]
                    .id
            }

        for id in ids {
            repository.delete(
                id: id
            )

            if selectedID == id {
                selectedID = nil
            }
        }

        guard let room =
                workingRoomV069,
              let onSaveRoomV069
        else {
            return
        }

        Task {
            do {
                var updatedRoom =
                    room

                for id in ids {
                    updatedRoom =
                        try SilnikSkosuPomieszczeniaV069
                            .usunProfil(
                                measurementID: id,
                                z: updatedRoom
                            )
                }

                guard updatedRoom != room
                else {
                    return
                }

                let saved =
                    await onSaveRoomV069(
                        updatedRoom
                    )

                if saved {
                    await MainActor.run {
                        workingRoomV069 =
                            updatedRoom
                    }
                }
            } catch {
                await MainActor.run {
                    saveErrorV069 =
                        error
                            .localizedDescription
                }
            }
        }
    }

    private func dimension(
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
                    .number
                    .grouping(.never)
                    .precision(
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
            .frame(width: 110)
            .toolbar {
                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {
                    Spacer()
                    Button("Gotowe") {
                        UIApplication
                            .shared
                            .sendAction(
                                #selector(
                                    UIResponder
                                        .resignFirstResponder
                                ),
                                to: nil,
                                from: nil,
                                for: nil
                            )
                    }
                }
            }

            Text("mm")
                .foregroundStyle(
                    .secondary
                )
        }
    }

    private func checklist(
        _ text: String
    ) -> some View {
        Label(
            text,
            systemImage:
                "checkmark.circle"
        )
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
}
