import DomainCore
import Foundation
import Persistence
import SwiftUI

struct KonfiguracjaModuluMeblowegoDane: Sendable {
    var name: String
    var width: Millimeters
    var height: Millimeters
    var depth: Millimeters
    var shelfCount: Int
    var drawerCount: Int
    var carcassThickness: Millimeters = 18
    var shelfFrontSetback: Millimeters = 20
    var backType: CabinetBackType = .inset
    var backThickness: Millimeters = 3
    var backInset: Millimeters = 10
    var topConstruction: CabinetTopConstruction = .fullPanel
    var topRailDepth: Millimeters = 100
    var frontEnabled: Bool = true
    var frontThickness: Millimeters = 18
    var frontGap: Millimeters = 2
    var frontInset: Millimeters = 0
    var openingTechnology: OpeningTechnology = .handle
    var bottomShortening: Millimeters = 0

    /// Identyfikator karty tworzonej przed zapisem modułu.
    /// ViewModel używa go do bezbłędnego powiązania karty z nową instancją.
    var technicalCardDraftID: UUID = UUID()

    var offsetAlongWall: Millimeters
    var offsetFromWall: Millimeters
    var bottomOffset: Millimeters
}

struct KonfiguracjaModuluMeblowegoView: View {
    @Environment(\.dismiss) private var dismiss

    let template: FurnitureTemplate
    let storedAssembly: StoredFurnitureAssembly?
    let suggestedPlacement: SugerowanePolozenieModulu?
    let poczatkowePoleWymiaru:
        PoleWymiaruModulu2D?
    private let kluczModulu: String?

    let onSave: (KonfiguracjaModuluMeblowegoDane) async -> Bool

    @State private var name: String
    @State private var widthText: String
    @State private var heightText: String
    @State private var depthText: String
    @State private var offsetAlongWallText: String
    @State private var offsetFromWallText: String
    @State private var bottomOffsetText: String
    @State private var shelfCount: Int
    @State private var drawerCount: Int
    @State private var carcassThicknessText: String
    @State private var shelfFrontSetbackText: String
    @State private var backType: CabinetBackType
    @State private var backThicknessText: String
    @State private var backInsetText: String
    @State private var topConstruction: CabinetTopConstruction
    @State private var topRailDepthText: String
    @State private var frontEnabled: Bool
    @State private var frontThicknessText: String
    @State private var frontGapText: String
    @State private var frontInsetText: String
    @State private var openingTechnology: OpeningTechnology
    @State private var bottomShorteningText: String
    @State private var isSaving = false
    @State private var validationMessage: String?
    @State private var technicalCard:
        KartaTechnicznaSzafki?
    @State private var moduleTechnicalID =
        UUID()
    @State private var selectedNormCategory:
        KategoriaNormySzafki
    @State private var frontTopGapMM = 2.0
    @State private var baseHeightSystemV084:
        KitchenBaseHeightSystemV018

    // v0.68.0: front, kierunek otwierania i okucia korzystają z jednej
    // konfiguracji zapisanej w karcie technicznej modułu.
    @State private var frontCountV068: Int
    @State private var frontOpeningV068:
        KierunekOtwarciaFrontuV068
    @State private var selectedFrontHardwareProfileIDV068:
        String
    @State private var selectedDrawerProfileIDV068:
        String
    @State private var drawerFrontTypeV068:
        TypFrontuSzuflady
    @State private var drawerLayoutPresetV068:
        RodzajPresetuUkladuSzuflad
    @State private var drawerSideInsetTextV068:
        String
    @State private var drawerCustomHeightsV068:
        [Double]
    @State private var lowerLedRailEnabledV083:
        Bool
    @State private var lowerLedRailLengthTextV083:
        String
    @State private var lowerLedRailDepthTextV083:
        String
    @State private var lowerLedRailThicknessTextV083:
        String
    @State private var showPresetSavedMessageV068 =
        false

    private static let lowerLedRailMarkerV083 =
        "AUTO-WIENIEC-LED-V083:"

    init(
        template: FurnitureTemplate,
        storedAssembly: StoredFurnitureAssembly? = nil,
        suggestedPlacement: SugerowanePolozenieModulu? = nil,
        poczatkowePoleWymiaru:
            PoleWymiaruModulu2D? = nil,
        poczatkowaSzerokoscMM: Double? = nil,
        onSave: @escaping (KonfiguracjaModuluMeblowegoDane) async -> Bool
    ) {
        self.template = template
        self.storedAssembly = storedAssembly
        self.suggestedPlacement = suggestedPlacement
        self.poczatkowePoleWymiaru =
            poczatkowePoleWymiaru
        self.kluczModulu = storedAssembly.map {
            StabilnyKluczDomenowy.utworz(
                dla: $0.id,
                prefiks: "furniture"
            )
        }
        self.onSave = onSave

        let parameters = storedAssembly?.parameters ?? template.defaultParameters
        let placement = storedAssembly?.assembly.placement
        // Szerokość wybrana wprost na kaflu biblioteki wygrywa z domyślną
        // szerokością szablonu. Kafel pokazuje typowe podziałki katalogu, więc
        // stuknięcie w „800" ma otworzyć konfigurator już na 800 — inaczej
        // wybór byłby tylko sugestią, którą trzeba powtórzyć w polu.
        //
        // Tylko dla nowego modułu: przy edycji zapisanego zespołu obowiązuje
        // to, co faktycznie stoi na ścianie.
        let templateWidthMM: Double = {
            if storedAssembly == nil,
               let wybrana = poczatkowaSzerokoscMM {
                return wybrana
            }
            return (
                (try? parameters.millimeters(for: .width))
                ?? 600
            )
            .rawValue
        }()
        let templateHeight =
            (try? parameters.millimeters(for: .height))
            ?? 720
        let supportsBaseHeightSystem =
            Self.supportsBaseHeightSystemV084(
                for: template
            )

        let detectedNorm =
            NormySzafekCatalog.norma(
                dla: template.name,
                code: template.code,
                categoryName:
                    template.category.rawValue
            )

        _selectedNormCategory = State(
            initialValue:
                detectedNorm.kategoria
        )

        var initialBaseHeightSystem =
            KitchenBaseHeightSystemV018()
        if storedAssembly == nil,
           supportsBaseHeightSystem {
            initialBaseHeightSystem.recalculate()
        } else {
            initialBaseHeightSystem.carcassHeightMM =
                templateHeight.rawValue
            initialBaseHeightSystem
                .targetWorktopHeightMM =
                    templateHeight.rawValue
                    + initialBaseHeightSystem
                        .effectiveLegHeightMM
                    + initialBaseHeightSystem
                        .countertopThicknessMM
        }
        _baseHeightSystemV084 = State(
            initialValue:
                initialBaseHeightSystem
        )

        let initialName =
            storedAssembly?.assembly.name
            ?? template.name
        let savedTechnicalCard:
            KartaTechnicznaSzafki?

        if let kluczModulu {
            savedTechnicalCard =
                KartaTechnicznaSzafkiStore
                    .card(
                        forModuleKey:
                            kluczModulu
                    )
                ?? KartaTechnicznaSzafkiStore
                    .powiazNajstarszaKarteLegacy(
                        templateCode:
                            template.code,
                        moduleName:
                            initialName,
                        zKluczemModulu:
                            kluczModulu
                    )
        } else {
            // Nowa instancja zawsze otrzymuje własną kartę.
            // Nie przejmujemy karty innego modułu o tej samej nazwie.
            savedTechnicalCard = nil
        }

        _name = State(
            initialValue: initialName
        )
        _technicalCard = State(
            initialValue:
                savedTechnicalCard
        )
        _moduleTechnicalID = State(
            initialValue:
                savedTechnicalCard?.draftID
                ?? UUID()
        )
        let initialDrawerCount =
            savedTechnicalCard?
                .efektywneSzuflady
                .filter(\.aktywna)
                .count
            ?? 0
        let initialActiveDrawers =
            savedTechnicalCard?
                .efektywneSzuflady
                .filter(\.aktywna)
                .sorted {
                    $0.pozycjaDolnaYMM
                    < $1.pozycjaDolnaYMM
                }
            ?? []
        let initialDrawerFrontType =
            initialActiveDrawers
                .first?
                .typFrontu
            ?? .zewnetrzny
        let initialDrawerSideInset =
            initialDrawerFrontType == .wewnetrzny
            ? (
                initialActiveDrawers
                    .first?
                    .odsuniecieOdScianBocznychMM
                ?? 21
            )
            : 0
        let initialLedRail =
            savedTechnicalCard?
                .efektywneElementy
                .first {
                    $0.uwagi
                        .hasPrefix(
                            Self.lowerLedRailMarkerV083
                        )
                }

        _drawerCount = State(
            initialValue:
                initialDrawerCount
        )
        _drawerFrontTypeV068 = State(
            initialValue:
                initialDrawerFrontType
        )
        _drawerLayoutPresetV068 = State(
            initialValue:
                Self.initialDrawerLayoutPresetV068(
                    drawers:
                        initialActiveDrawers
                )
        )
        _drawerSideInsetTextV068 = State(
            initialValue:
                Self.text(
                    Millimeters(
                        initialDrawerSideInset
                    )
                )
        )
        _drawerCustomHeightsV068 = State(
            initialValue:
                initialActiveDrawers
                    .map(\.wysokoscFrontuMM)
        )
        _lowerLedRailEnabledV083 = State(
            initialValue:
                initialLedRail != nil
        )
        _lowerLedRailLengthTextV083 = State(
            initialValue:
                Self.text(
                    Millimeters(
                        initialLedRail?
                            .dlugoscMM
                        ?? templateWidthMM
                    )
                )
        )
        _lowerLedRailDepthTextV083 = State(
            initialValue:
                Self.text(
                    Millimeters(
                        initialLedRail?
                            .szerokoscMM
                        ?? 60
                    )
                )
        )
        _lowerLedRailThicknessTextV083 = State(
            initialValue:
                Self.text(
                    Millimeters(
                        initialLedRail?
                            .gruboscMM
                        ?? 18
                    )
                )
        )

        // Oblicz szerokość wcześniej, żeby domyslna() mogło
        // automatycznie wyliczyć poprawną liczbę frontów z reguły szerokości.
        let templateWidthForFronts =
            Millimeters(templateWidthMM)
        let initialWidthForFronts: Millimeters
        if storedAssembly == nil,
           let maximumWidth =
               suggestedPlacement?.maximumWidth
        {
            initialWidthForFronts =
                min(templateWidthForFronts, maximumWidth)
        } else {
            initialWidthForFronts =
                templateWidthForFronts
        }

        let initialFunctionalConfiguration =
            savedTechnicalCard?
                .konfiguracjaFunkcjonalnaV068
            ?? KonfiguracjaFunkcjonalnaModuluV068
                .domyslna(
                    template: template,
                    drawerCount: initialDrawerCount,
                    widthMM:
                        initialWidthForFronts
                            .rawValue
                )

        _frontCountV068 = State(
            initialValue:
                initialFunctionalConfiguration
                    .front
                    .bezpiecznaLiczbaFrontow
        )
        _frontOpeningV068 = State(
            initialValue:
                ProfilOkuciaResolverV068
                    .efektywneOtwarcie(
                        konfiguracja:
                            initialFunctionalConfiguration
                    )
        )
        _selectedFrontHardwareProfileIDV068 =
            State(
                initialValue:
                    initialFunctionalConfiguration
                        .front
                        .profilOkuciaID
            )
        _selectedDrawerProfileIDV068 =
            State(
                initialValue:
                    initialFunctionalConfiguration
                        .szuflady
                        .profilID
            )

        _widthText = State(
            initialValue: Self.text(initialWidthForFronts)
        )
        _heightText = State(
            initialValue:
                Self.text(
                    supportsBaseHeightSystem
                        && storedAssembly == nil
                    ? Millimeters(
                        initialBaseHeightSystem
                            .carcassHeightMM
                    )
                    : templateHeight
                )
        )
        _depthText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .depth)) ?? 560
            )
        )
        _shelfCount = State(
            initialValue: (try? parameters.integer(for: .shelfCount)) ?? 1
        )
        _carcassThicknessText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .carcassThickness))
                    ?? 18
            )
        )
        _shelfFrontSetbackText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .shelfFrontSetback))
                    ?? 20
            )
        )
        _backType = State(
            initialValue:
                (try? parameters.cabinetBackType(for: .backType))
                ?? .inset
        )
        _backThicknessText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .backThickness))
                    ?? 3
            )
        )
        _backInsetText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .backInset))
                    ?? 10
            )
        )
        _topConstruction = State(
            initialValue:
                (try? parameters.cabinetTopConstruction(
                    for: .topConstruction
                ))
                ?? .fullPanel
        )
        _topRailDepthText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .topRailDepth))
                    ?? 100
            )
        )
        _frontEnabled = State(
            initialValue:
                (try? parameters.boolean(for: .frontEnabled))
                ?? true
        )
        _frontThicknessText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .frontThickness))
                    ?? 18
            )
        )
        _frontGapText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .frontGap))
                    ?? 2
            )
        )
        _frontInsetText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .frontInset))
                    ?? 0
            )
        )
        _openingTechnology = State(
            initialValue:
                (try? parameters.openingTechnology(
                    for: .openingTechnology
                ))
                ?? .handle
        )
        _bottomShorteningText = State(
            initialValue: Self.text(
                (try? parameters.millimeters(for: .bottomShortening))
                    ?? 0
            )
        )
        _offsetAlongWallText = State(
            initialValue: Self.text(
                placement?.offsetAlongWall
                    ?? suggestedPlacement?.offsetAlongWall
                    ?? .zero
            )
        )
        _offsetFromWallText = State(
            initialValue: Self.text(
                placement?.offsetFromWall
                    ?? suggestedPlacement?.offsetFromWall
                    ?? .zero
            )
        )
        _bottomOffsetText = State(
            initialValue: Self.text(
                placement?.bottomOffset
                    ?? suggestedPlacement?.bottomOffset
                    ?? Self.defaultBottomOffset(for: template)
            )
        )
    }

    var body: some View {
        Form {
            Section("Moduł") {
                TextField("Nazwa modułu", text: $name)

                LabeledContent("Szablon", value: template.name)
                LabeledContent("Kod", value: template.code)
            }

            Section("Gabaryt") {
                PolePomiaroweMM(
                    "Szerokość",
                    text: $widthText,
                    autoFocus:
                        poczatkowePoleWymiaru
                        == .szerokosc
                )
                PolePomiaroweMM(
                    "Wysokość",
                    text: $heightText,
                    autoFocus:
                        poczatkowePoleWymiaru
                        == .wysokosc
                )
                .disabled(
                    supportsBaseHeightSystemV084
                )
                PolePomiaroweMM(
                    "Głębokość",
                    text: $depthText,
                    autoFocus:
                        poczatkowePoleWymiaru
                        == .glebokosc
                )

                if let maximumWidth = suggestedPlacement?.maximumWidth,
                   storedAssembly == nil {
                    LabeledContent(
                        "Maksymalna szerokość",
                        value: Self.formatted(maximumWidth)
                    )
                }

                Stepper(
                    "Liczba półek: \(shelfCount)",
                    value: $shelfCount,
                    in: 0...20
                )

                Stepper(
                    "Liczba szuflad: \(drawerCount)",
                    value: $drawerCount,
                    in: 0...12
                )

                Text(
                    "Zmiana liczby szuflad aktualizuje kartę techniczną, okucia, wiercenia i usuwa półki kolidujące z automatycznym układem."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                if supportsBaseHeightSystemV084 {
                    Text(
                        "Wysokość korpusu jest liczona z docelowej wysokości blatu, podstawy i grubości blatu."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            if supportsBaseHeightSystemV084 {
                Section("Wysokość robocza") {
                    Picker(
                        "Podstawa",
                        selection:
                            $baseHeightSystemV084
                                .supportKind
                    ) {
                        ForEach(
                            CabinetBaseSupportKindV018
                                .allCases
                        ) { supportKind in
                            Text(supportKind.title)
                                .tag(supportKind)
                        }
                    }

                    TextField(
                        "Docelowa wysokość blatu [mm]",
                        value:
                            $baseHeightSystemV084
                                .targetWorktopHeightMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(0...1)
                                )
                    )
                    .keyboardType(.decimalPad)

                    TextField(
                        "Wysokość nóżek/cokołu [mm]",
                        value:
                            $baseHeightSystemV084
                                .legHeightMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(0...1)
                                )
                    )
                    .keyboardType(.decimalPad)
                    .disabled(
                        baseHeightSystemV084
                            .supportKind
                        == .floorStanding
                    )

                    TextField(
                        "Grubość blatu [mm]",
                        value:
                            $baseHeightSystemV084
                                .countertopThicknessMM,
                        format:
                            .number
                                .precision(
                                    .fractionLength(0...1)
                                )
                    )
                    .keyboardType(.decimalPad)

                    LabeledContent(
                        "Wyliczony korpus",
                        value:
                            "\(Int(recalculatedBaseHeightSystemV084.carcassHeightMM.rounded())) mm"
                    )

                    LabeledContent(
                        "Gotowa wysokość",
                        value:
                            "\(Int(recalculatedBaseHeightSystemV084.finishedWorktopHeightMM.rounded())) mm"
                    )

                    Text(
                        "Zmiana nóg/cokołu albo blatu skraca lub wydłuża korpus. Moduł zostaje na podłodze."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            if supportsAnyConstructionParameter {
                Section("Konstrukcja") {
                    if supports(.carcassThickness) {
                        PolePomiaroweMM(
                            "Grubość płyty",
                            text: $carcassThicknessText
                        )
                    }

                    if supports(.shelfFrontSetback) {
                        PolePomiaroweMM(
                            "Cofnięcie półek",
                            text: $shelfFrontSetbackText
                        )
                    }

                    if supports(.backType) {
                        Picker(
                            "Plecy",
                            selection: $backType
                        ) {
                            ForEach(
                                CabinetBackType.allCases,
                                id: \.self
                            ) { type in
                                Text(backTypeLabel(type))
                                    .tag(type)
                            }
                        }
                    }

                    if backType == .inset {
                        if supports(.backThickness) {
                            PolePomiaroweMM(
                                "Grubość pleców",
                                text: $backThicknessText
                            )
                        }

                        if supports(.backInset) {
                            PolePomiaroweMM(
                                "Cofnięcie pleców",
                                text: $backInsetText
                            )
                        }
                    }

                    if supports(.topConstruction) {
                        Picker(
                            "Góra korpusu",
                            selection:
                                $topConstruction
                        ) {
                            ForEach(
                                CabinetTopConstruction
                                    .allCases,
                                id: \.self
                            ) { construction in
                                Text(
                                    topConstructionLabel(
                                        construction
                                    )
                                )
                                .tag(construction)
                            }
                        }
                    }

                    if topConstruction == .frontAndRearRails,
                       supports(.topRailDepth) {
                        PolePomiaroweMM(
                            "Głębokość rygli",
                            text: $topRailDepthText
                        )
                    }

                    if supports(.frontEnabled) {
                        Toggle(
                            "Front w module",
                            isOn: $frontEnabled
                        )
                    }

                    if frontEnabled {
                        if supports(.frontThickness) {
                            PolePomiaroweMM(
                                "Grubość frontu",
                                text: $frontThicknessText
                            )
                        }

                        if supports(.frontGap) {
                            PolePomiaroweMM(
                                "Luz frontu",
                                text: $frontGapText
                            )
                        }

                        if supports(.frontInset) {
                            PolePomiaroweMM(
                                "Cofnięcie frontu",
                                text: $frontInsetText
                            )
                        }
                    }

                    if supports(.openingTechnology) {
                        Picker(
                            "Otwieranie",
                            selection:
                                $openingTechnology
                        ) {
                            ForEach(
                                OpeningTechnology.allCases,
                                id: \.self
                            ) { technology in
                                Text(
                                    openingTechnologyLabel(
                                        technology
                                    )
                                )
                                .tag(technology)
                            }
                        }
                    }

                    if openingTechnology
                        == .shortenedBottomFingerPull,
                       !isWallCabinetV083,
                       supports(.bottomShortening) {
                        PolePomiaroweMM(
                            "Podcięcie dna",
                            text: $bottomShorteningText
                        )
                    }
                }
            }

            if isWallCabinetV083 {
                Section("Szafki wiszące") {
                    Toggle(
                        "Fronty z podchwytem",
                        isOn:
                            Binding(
                                get: {
                                    openingTechnology
                                    == .shortenedBottomFingerPull
                                },
                                set: { isEnabled in
                                    openingTechnology =
                                        isEnabled
                                        ? .shortenedBottomFingerPull
                                        : .handle

                                    if isEnabled,
                                       (millimeters(bottomShorteningText)?
                                        .rawValue
                                        ?? 0) <= 0 {
                                        bottomShorteningText =
                                            Self.text(
                                                Millimeters(30)
                                            )
                                    }
                                }
                            )
                    )

                    if openingTechnology == .shortenedBottomFingerPull,
                       supports(.bottomShortening) {
                        PolePomiaroweMM(
                            "Podcięcie pod palce",
                            text: $bottomShorteningText
                        )

                        Text(
                            "Dla wiszących traktujemy to jako podchwyt frontu: dolny wieniec jest cofnięty, żeby pod frontem powstał prześwit na palce."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Toggle(
                        "Dolny wieniec LED łączący ciąg",
                        isOn:
                            $lowerLedRailEnabledV083
                    )

                        if lowerLedRailEnabledV083 {
                            PolePomiaroweMM(
                                "Długość wieńca LED",
                                text:
                                    $lowerLedRailLengthTextV083
                            )

                            Button {
                                if let width =
                                    millimeters(widthText) {
                                    lowerLedRailLengthTextV083 =
                                        Self.text(width)
                                }
                            } label: {
                                Label(
                                    "Ustaw długość z szerokości modułu",
                                    systemImage:
                                        "arrow.left.and.right"
                                )
                            }

                            PolePomiaroweMM(
                                "Głębokość listwy",
                            text:
                                $lowerLedRailDepthTextV083
                        )

                        PolePomiaroweMM(
                            "Grubość listwy",
                            text:
                                $lowerLedRailThicknessTextV083
                        )

                        Text(
                            "Długość może obejmować cały ciąg szafek wiszących. Do karty trafi wieniec/listwa, profil LED, taśma i zasilacz."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Fronty i okucia") {
                Picker(
                    "Kierunek otwierania",
                    selection:
                        $frontOpeningV068
                ) {
                    ForEach(
                        KierunekOtwarciaFrontuV068
                            .allCases
                    ) { opening in
                        Label(
                            opening.nazwa,
                            systemImage:
                                opening
                                    .symbolSystemowy
                        )
                        .tag(opening)
                    }
                }

                if drawerCount > 0 {
                    LabeledContent(
                        "Liczba frontów szuflad",
                        value:
                            "\(drawerCount)"
                    )

                    Picker(
                        "System szuflad / prowadnic",
                        selection:
                            $selectedDrawerProfileIDV068
                    ) {
                        Text(
                            "Automatyczny preset"
                        )
                        .tag("")

                        ForEach(
                            drawerHardwareProfilesV068
                        ) { profile in
                            Text(
                                profileLabelV068(
                                    profile
                                )
                            )
                            .tag(profile.id)
                        }
                    }

                    Picker(
                        "Układ wysokości",
                        selection:
                            $drawerLayoutPresetV068
                    ) {
                        ForEach(
                            drawerLayoutOptionsV068
                        ) { layout in
                            Text(layout.etykieta)
                                .tag(layout)
                        }
                    }

                    if drawerLayoutPresetV068
                        == .wysokosciNiestandardowe {
                        drawerCustomHeightsEditorV068
                    } else if let heights =
                        previewDrawerHeightsV068 {
                        drawerHeightsPreviewV068(heights)
                    }

                    Picker(
                        "Typ szuflad",
                        selection:
                            $drawerFrontTypeV068
                    ) {
                        ForEach(
                            TypFrontuSzuflady
                                .allCases
                        ) { type in
                            Text(type.nazwa)
                                .tag(type)
                        }
                    }

                    if drawerFrontTypeV068 == .wewnetrzny {
                        PolePomiaroweMM(
                            "Odsunięcie od boków",
                            text:
                                $drawerSideInsetTextV068
                        )

                        Text(
                            "Odsunięcie szuflady za frontem jest liczone z reguły zawiasu. Zero-protrusion 155° dopuszcza układ z małym luzem, zwykły zawias wymaga dystansu albo potwierdzenia karty SKU."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Stepper(
                        "Liczba frontów: \(frontCountV068)",
                        value:
                            $frontCountV068,
                        in: 1...12
                    )
                }

                if frontOpeningV068
                    == .lewy
                    || frontOpeningV068
                        == .prawy
                    || frontOpeningV068
                        == .doGory {
                    Picker(
                        frontOpeningV068
                            == .doGory
                        ? "Podnośnik frontu"
                        : "Zawias",
                        selection:
                            $selectedFrontHardwareProfileIDV068
                    ) {
                        Text(
                            "Automatyczny preset"
                        )
                        .tag("")

                        ForEach(
                            frontHardwareProfilesV068
                        ) { profile in
                            Text(
                                profileLabelV068(
                                    profile
                                )
                            )
                            .tag(profile.id)
                        }
                    }
                }

                Button {
                    zapiszPresetOkucV068()
                } label: {
                    Label(
                        "Ustaw jako preset kuchni",
                        systemImage:
                            "square.and.arrow.down"
                    )
                }

                if showPresetSavedMessageV068 {
                    Label(
                        "Preset okuć został zapisany.",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)
                }

                Text(
                    "Wybrane okucia są zapisywane w karcie technicznej. AVENTOS i inne podnośniki automatycznie wymuszają otwieranie frontu do góry."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .onChange(
                of:
                    selectedFrontHardwareProfileIDV068
            ) { _, newValue in
                let profile =
                    ProfilOkuciaResolverV068
                        .profil(
                            id: newValue
                        )

                if ProfilOkuciaResolverV068
                    .jestAventos(profile) {
                    frontOpeningV068 =
                        .doGory
                }
            }
            .onChange(
                of: drawerCount
            ) { _, newValue in
                if newValue > 0 {
                    frontOpeningV068 =
                        .szuflada
                    frontCountV068 =
                        newValue
                    if drawerLayoutPresetV068
                        == .wysokosciNiestandardowe {
                        syncDrawerCustomHeightsCountV068(
                            newValue
                        )
                    }
                }
            }
            .onChange(
                of: drawerLayoutPresetV068
            ) { _, newValue in
                switch newValue {
                case .jednaWysokaDwieNiskie,
                     .wysokaNaDoleDwieNiskie:
                    drawerCount = 3
                    frontCountV068 = 3
                    drawerCustomHeightsV068 =
                        standardoweWysokosciDlaPresetuV068(
                            newValue
                        )
                        ?? drawerCustomHeightsV068
                case .dwieWysokie:
                    drawerCount = 2
                    frontCountV068 = 2
                    drawerCustomHeightsV068 =
                        standardoweWysokosciDlaPresetuV068(
                            newValue
                        )
                        ?? drawerCustomHeightsV068
                case .cargo:
                    drawerCount = 1
                    frontCountV068 = 1
                case .wysokosciNiestandardowe:
                    syncDrawerCustomHeightsCountV068(
                        drawerCount
                    )
                case .rowne:
                    break
                }
            }
            .onChange(
                of: drawerFrontTypeV068
            ) { _, newValue in
                if newValue == .wewnetrzny,
                   (millimeters(drawerSideInsetTextV068)?
                    .rawValue
                    ?? 0) <= 0 {
                    drawerSideInsetTextV068 =
                        Self.text(
                            Millimeters(21)
                        )
                }
            }

            Section("Norma szafki") {
                Picker(
                    "Typ szafki",
                    selection:
                        $selectedNormCategory
                ) {
                    ForEach(
                        KategoriaNormySzafki
                            .allCases
                    ) { category in
                        Text(category.nazwa)
                            .tag(category)
                    }
                }

                HStack {
                    Button {
                        applySelectedNorm()
                    } label: {
                        Label(
                            "Zastosuj normę",
                            systemImage:
                                "ruler"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )

                    Button {
                        applyNearestStandardWidth()
                    } label: {
                        Label(
                            "Najbliższa szerokość",
                            systemImage:
                                "arrow.left.and.right"
                        )
                    }
                    .disabled(
                        currentNorm
                            .typoweSzerokosciMM
                            .isEmpty
                    )
                }

                LabeledContent(
                    "Typowe szerokości",
                    value:
                        standardWidthsText
                )

                LabeledContent(
                    "Głębokość",
                    value:
                        rangeText(
                            currentNorm
                                .glebokoscMM
                        )
                )

                LabeledContent(
                    "Wysokość korpusu",
                    value:
                        rangeText(
                            currentNorm
                                .wysokoscKorpusuMM
                        )
                )

                if let pedestal =
                    currentNorm
                        .wysokoscCokoluMM {
                    LabeledContent(
                        "Cokół / nóżki",
                        value:
                            rangeText(
                                pedestal
                            )
                    )
                }

                if let worktop =
                    currentNorm
                        .gruboscBlatuMM {
                    LabeledContent(
                        "Grubość blatu",
                        value:
                            rangeText(
                                worktop
                            )
                    )
                }

                if let back =
                    currentNorm
                        .odsunPlecyOdTyluMM {
                    LabeledContent(
                        "Odsunięcie pleców",
                        value:
                            rangeText(
                                back
                            )
                    )
                }

                LabeledContent(
                    "Szerokość frontu",
                    value:
                        calculatedFrontWidthText
                )

                LabeledContent(
                    "Wysokość frontu",
                    value:
                        calculatedFrontHeightText
                )

                ForEach(
                    currentNormValidation
                ) { result in
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

            Section("Dokumentacja techniczna") {
                Button {
                    openTechnicalCard()
                } label: {
                    Label(
                        "Otwórz kartę techniczną modułu",
                        systemImage:
                            "doc.text.magnifyingglass"
                    )
                }

                Text(
                    "Karta obejmuje także gotowe moduły z biblioteki: rysunek, wiercenia, blendy, wieńce i ścianki boczne wysunięte przed front."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Section(
                isFreestandingModuleV083
                    ? "Położenie w pomieszczeniu"
                    : "Położenie przy ścianie"
            ) {
                PolePomiaroweMM(
                    isFreestandingModuleV083
                        ? "X w pomieszczeniu"
                        : "Od początku ściany",
                    text: $offsetAlongWallText
                )
                .disabled(
                    storedAssembly == nil
                        && suggestedPlacement?.rightEdgeAnchor != nil
                )

                if storedAssembly == nil,
                   let rightEdgeAnchor = suggestedPlacement?.rightEdgeAnchor {
                    Text(
                        "Moduł zostanie dosunięty prawą krawędzią do \(Self.formatted(rightEdgeAnchor))."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                PolePomiaroweMM(
                    isFreestandingModuleV083
                        ? "Y w pomieszczeniu"
                        : "Odsunięcie od ściany",
                    text: $offsetFromWallText
                )
                PolePomiaroweMM(
                    "Wysokość od podłogi",
                    text: $bottomOffsetText
                )
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(
            storedAssembly == nil ? "Dodaj moduł" : "Edytuj moduł"
        )
        .navigationBarTitleDisplayMode(.inline)
        .stolarniaReadableInterface()
            .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Anuluj") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Zapisz") {
                    save()
                }
                .disabled(isSaving)
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
        // Karta techniczna jest **wciśnięta w ten sam stos**, nie postawiona
        // jako kolejne okno. Konfigurator jest tu celem `NavigationLink`
        // z biblioteki, więc karta wchodzi jako trzeci ekran tej samej ścieżki
        // i wraca się z niej strzałką wstecz.
        //
        // Wcześniej był to `sheet` nad sheetem biblioteki, a karta stawiała
        // z siebie jeszcze jeden (szuflady, System 32, edycja parametrów) —
        // cztery poziomy do zamykania po kolei. Na ścieżce z elewacji zrobiła
        // to już `KartaModuluV097`; tu było to samo do zrobienia.
        .navigationDestination(
            item: $technicalCard
        ) { card in
            KartaTechnicznaSzafkiView(
                card: card,
                osadzona: true
            )
        }
        .interactiveDismissDisabled(isSaving)
        .onChange(
            of: baseHeightSystemV084
        ) { _, _ in
            applyBaseHeightSystemV084()
        }
    }

    private var supportedParameterKeys:
        Set<FurnitureParameterKey>
    {
        Set(
            template.supportedParameters
                .map(\.key)
        )
    }

    private var supportsAnyConstructionParameter: Bool {
        [
            FurnitureParameterKey.carcassThickness,
            .shelfFrontSetback,
            .backType,
            .backThickness,
            .backInset,
            .topConstruction,
            .topRailDepth,
            .frontEnabled,
            .frontThickness,
            .frontGap,
            .frontInset,
            .openingTechnology,
            .bottomShortening
        ]
        .contains {
            supports($0)
        }
    }

    private var supportsBaseHeightSystemV084:
        Bool
    {
        Self.supportsBaseHeightSystemV084(
            for: template
        )
    }

    private var recalculatedBaseHeightSystemV084:
        KitchenBaseHeightSystemV018
    {
        baseHeightSystemV084
            .recalculated()
    }

    private var isWallCabinetV083:
        Bool
    {
        template.builderType == .wallCabinet
        || template.category == .kitchenWallCabinet
        || StandardKitchenTemplatesV0143
            .anchoringMode(for: template)
            == .wallMounted
    }

    private var isFreestandingModuleV083:
        Bool
    {
        StandardKitchenTemplatesV0143
            .anchoringMode(for: template)
            == .freestanding
        || StandardFurnitureModuleCatalogV077
            .anchoringMode(for: template)
            == .freestanding
    }

    private func supports(
        _ key: FurnitureParameterKey
    ) -> Bool {
        supportedParameterKeys.contains(key)
    }

    private static func supportsBaseHeightSystemV084(
        for template: FurnitureTemplate
    ) -> Bool {
        if template.category == .kitchenBaseCabinet {
            return true
        }

        switch StandardFurnitureModuleCatalogV077
            .kind(for: template) {
        case .kitchenIsland,
             .kitchenDrawerBase,
             .sinkBase,
             .cornerBase,
             .bathroomVanity:
            return true
        default:
            return false
        }
    }

    private func applyBaseHeightSystemV084() {
        guard supportsBaseHeightSystemV084 else {
            return
        }

        let recalculated =
            baseHeightSystemV084
                .recalculated()

        if recalculated != baseHeightSystemV084 {
            baseHeightSystemV084 =
                recalculated
        }

        heightText =
            Self.text(
                Millimeters(
                    recalculated
                        .carcassHeightMM
                )
            )
        bottomOffsetText =
            Self.text(
                Millimeters.zero
            )
    }

    private func backTypeLabel(
        _ type: CabinetBackType
    ) -> String {
        switch type {
        case .none:
            return "Brak"
        case .inset:
            return "Wpuszczane"
        }
    }

    private func topConstructionLabel(
        _ construction: CabinetTopConstruction
    ) -> String {
        switch construction {
        case .fullPanel:
            return "Pełny wieniec"
        case .frontAndRearRails:
            return "Rygle przedni i tylny"
        }
    }

    private func openingTechnologyLabel(
        _ technology: OpeningTechnology
    ) -> String {
        switch technology {
        case .handle:
            return "Uchwyt"
        case .edgeHandle:
            return "Uchwyt krawędziowy"
        case .pushToOpen:
            return "Push to open"
        case .shortenedBottomFingerPull:
            return "Podchwyt / cofnięty dolny wieniec"
        case .gola:
            return "Gola"
        case .routedFront:
            return "Frezowany front"
        case .custom:
            return "Własne"
        }
    }

    private var frontHardwareProfilesV068:
        [ProfilAkcesoriumMeblowego]
    {
        switch frontOpeningV068 {
        case .doGory:
            return ProfilOkuciaResolverV068
                .profile(
                    kategorii: [
                        .podnosnikFrontu
                    ]
                )
        case .lewy, .prawy:
            return ProfilOkuciaResolverV068
                .profile(
                    kategorii: [
                        .zawias
                    ]
                )
        default:
            return []
        }
    }

    private var drawerHardwareProfilesV068:
        [ProfilAkcesoriumMeblowego]
    {
        ProfilOkuciaResolverV068
            .profile(
                kategorii: [
                    .systemSzuflady,
                    .prowadnica
                ]
            )
    }

    private var drawerLayoutOptionsV068:
        [RodzajPresetuUkladuSzuflad]
    {
        [
            .rowne,
            .jednaWysokaDwieNiskie,
            .wysokaNaDoleDwieNiskie,
            .dwieWysokie,
            .wysokosciNiestandardowe,
            .cargo
        ]
    }

    private var previewDrawerHeightsV068:
        [Double]?
    {
        standardoweWysokosciDlaPresetuV068(
            drawerLayoutPresetV068
        )
    }

    private func drawerHeightsPreviewV068(
        _ heights: [Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(
                Array(heights.enumerated()),
                id: \.offset
            ) { pair in
                HStack {
                    Text("Szuflada \(pair.offset + 1)")
                    Spacer()
                    Text("\(Int(pair.element.rounded())) mm")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var drawerCustomHeightsEditorV068:
        some View
    {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(
                Array(drawerCustomHeightsV068.indices),
                id: \.self
            ) { index in
                HStack(spacing: 10) {
                    Picker(
                        "Szuflada \(index + 1)",
                        selection: Binding(
                            get: {
                                najblizszyStandardSzufladyV068(
                                    drawerCustomHeightsV068[
                                        index
                                    ]
                                )
                            },
                            set: { standard in
                                drawerCustomHeightsV068[
                                    index
                                ] =
                                    standard
                                    .wysokoscFrontuMM
                            }
                        )
                    ) {
                        ForEach(
                            StandardWysokoscSzuflady
                                .allCases
                        ) { standard in
                            Text(standard.opis)
                                .tag(standard)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField(
                        "mm",
                        value: Binding(
                            get: {
                                drawerCustomHeightsV068[
                                    index
                                ]
                            },
                            set: { value in
                                drawerCustomHeightsV068[
                                    index
                                ] =
                                    min(
                                        max(
                                            value,
                                            60
                                        ),
                                        600
                                    )
                            }
                        ),
                        format: .number
                    )
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: 96)

                    Text("mm")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    drawerCustomHeightsV068.append(
                        StandardWysokoscSzuflady
                            .niska
                            .wysokoscFrontuMM
                    )
                    drawerCount =
                        drawerCustomHeightsV068.count
                    frontCountV068 =
                        drawerCustomHeightsV068.count
                } label: {
                    Label(
                        "Dodaj szufladę",
                        systemImage: "plus.circle"
                    )
                }
                .disabled(drawerCustomHeightsV068.count >= 10)

                Spacer()

                Button(role: .destructive) {
                    if drawerCustomHeightsV068.count > 1 {
                        drawerCustomHeightsV068.removeLast()
                        drawerCount =
                            drawerCustomHeightsV068.count
                        frontCountV068 =
                            drawerCustomHeightsV068.count
                    }
                } label: {
                    Label(
                        "Usuń ostatnią",
                        systemImage: "minus.circle"
                    )
                }
                .disabled(drawerCustomHeightsV068.count <= 1)
            }
            .font(.caption)

            LabeledContent(
                "Suma wysokości",
                value:
                    "\(Int(drawerCustomHeightsV068.reduce(0, +).rounded())) mm"
            )
        }
        .padding(.vertical, 4)
    }

    private func standardoweWysokosciDlaPresetuV068(
        _ preset: RodzajPresetuUkladuSzuflad
    ) -> [Double]? {
        let niska =
            StandardWysokoscSzuflady
                .niska
                .wysokoscFrontuMM
        let wysoka =
            StandardWysokoscSzuflady
                .wysoka
                .wysokoscFrontuMM

        switch preset {
        case .jednaWysokaDwieNiskie:
            return [niska, niska, wysoka]
        case .wysokaNaDoleDwieNiskie:
            return [wysoka, niska, niska]
        case .dwieWysokie:
            return [wysoka, wysoka]
        case .rowne,
             .wysokosciNiestandardowe,
             .cargo:
            return nil
        }
    }

    private func syncDrawerCustomHeightsCountV068(
        _ count: Int
    ) {
        let safeCount = max(count, 1)

        if drawerCustomHeightsV068.isEmpty {
            drawerCustomHeightsV068 =
                Array(
                    repeating:
                        StandardWysokoscSzuflady
                        .srednia
                        .wysokoscFrontuMM,
                    count: safeCount
                )
            return
        }

        while drawerCustomHeightsV068.count < safeCount {
            drawerCustomHeightsV068.append(
                drawerCustomHeightsV068.last
                ?? StandardWysokoscSzuflady
                    .srednia
                    .wysokoscFrontuMM
            )
        }

        if drawerCustomHeightsV068.count > safeCount {
            drawerCustomHeightsV068.removeLast(
                drawerCustomHeightsV068.count
                - safeCount
            )
        }
    }

    private func najblizszyStandardSzufladyV068(
        _ height: Double
    ) -> StandardWysokoscSzuflady {
        StandardWysokoscSzuflady
            .allCases
            .min {
                abs($0.wysokoscFrontuMM - height)
                < abs($1.wysokoscFrontuMM - height)
            }
        ?? .srednia
    }

    private func profileLabelV068(
        _ profile:
            ProfilAkcesoriumMeblowego
    ) -> String {
        [
            profile.producent,
            profile.rodzina,
            profile.model
        ]
        .filter {
            !$0.isEmpty
        }
        .joined(separator: " • ")
    }

    private func resolvedFrontHardwareProfileIDV068()
        -> String
    {
        if !selectedFrontHardwareProfileIDV068
            .isEmpty {
            return selectedFrontHardwareProfileIDV068
        }

        let preset =
            PresetOkucKuchniV068Store
                .wczytaj()

        switch frontOpeningV068 {
        case .doGory:
            return preset
                .profilPodnosnikaID
        case .lewy, .prawy:
            return preset
                .profilZawiasuID
        default:
            return ""
        }
    }

    private func resolvedDrawerProfileIDV068()
        -> String
    {
        if !selectedDrawerProfileIDV068
            .isEmpty {
            return selectedDrawerProfileIDV068
        }

        return PresetOkucKuchniV068Store
            .wczytaj()
            .profilSystemuSzufladID
    }

    private func currentFunctionalConfigurationV068()
        -> KonfiguracjaFunkcjonalnaModuluV068
    {
        var configuration =
            technicalCard?
                .konfiguracjaFunkcjonalnaV068
            ?? KonfiguracjaFunkcjonalnaModuluV068
                .domyslna(
                    template: template,
                    drawerCount:
                        drawerCount
                )

        configuration.wersjaSchematu = 1
        configuration.front.liczbaFrontow =
            drawerCount > 0
            ? max(drawerCount, 1)
            : max(frontCountV068, 1)
        configuration.front.otwarcie =
            drawerCount > 0
            ? .szuflada
            : frontOpeningV068
        configuration.front.profilOkuciaID =
            drawerCount > 0
            ? ""
            : resolvedFrontHardwareProfileIDV068()
        configuration.front.katOtwarciaStopnie =
            configuration
                .front
                .otwarcie
                == .doGory
            ? 95
            : 100
        configuration.szuflady.profilID =
            resolvedDrawerProfileIDV068()
        configuration
            .szuflady
            .pokazujUproszczonaGeometrie3D =
                true

        if ProfilOkuciaResolverV068
            .jestAventos(
                ProfilOkuciaResolverV068
                    .profil(
                        id:
                            configuration
                                .front
                                .profilOkuciaID
                    )
            ) {
            configuration.front.otwarcie =
                .doGory
        }

        return configuration
    }

    private func zapiszPresetOkucV068() {
        var preset =
            PresetOkucKuchniV068Store
                .wczytaj()

        let selectedFrontID =
            selectedFrontHardwareProfileIDV068
        let selectedFrontProfile =
            ProfilOkuciaResolverV068
                .profil(
                    id:
                        selectedFrontID
                )

        if selectedFrontProfile?
            .kategoria
            == .podnosnikFrontu {
            preset.profilPodnosnikaID =
                selectedFrontID
        } else if selectedFrontProfile?
            .kategoria
            == .zawias {
            preset.profilZawiasuID =
                selectedFrontID
        }

        if !selectedDrawerProfileIDV068
            .isEmpty {
            preset.profilSystemuSzufladID =
                selectedDrawerProfileIDV068
        }

        preset.dataAktualizacji =
            Date()

        PresetOkucKuchniV068Store
            .zapisz(preset)

        showPresetSavedMessageV068 =
            true
    }

    private var currentNorm:
        NormaSzafki
    {
        NormySzafekCatalog.norma(
            selectedNormCategory
        )
    }

    private var currentNormValidation:
        [WynikWalidacjiNormySzafki]
    {
        guard let width =
                millimeters(widthText),
              let height =
                millimeters(heightText),
              let depth =
                millimeters(depthText)
        else {
            return []
        }

        return NormySzafekValidator
            .validate(
                norma: currentNorm,
                widthMM:
                    width.rawValue,
                heightMM:
                    height.rawValue,
                depthMM:
                    depth.rawValue,
                frontHeightMM:
                    currentNorm
                        .wysokoscFrontu(
                            korpusMM:
                                height.rawValue,
                            szczelinaGornaMM:
                                frontTopGapMM
                        )
            )
    }

    private var standardWidthsText:
        String
    {
        guard !currentNorm
            .typoweSzerokosciMM
            .isEmpty
        else {
            return "Dowolna"
        }

        return currentNorm
            .typoweSzerokosciMM
            .map {
                $0.formatted(
                    .number.precision(
                        .fractionLength(0...1)
                    )
                )
            }
            .joined(
                separator: ", "
            )
            + " mm"
    }

    private var calculatedFrontWidthText:
        String
    {
        guard let width =
                millimeters(widthText)
        else {
            return "—"
        }

        return currentNorm
            .szerokoscFrontuJednoskrzydlowego(
                korpusMM:
                    width.rawValue
            )
            .formatted(
                .number.precision(
                    .fractionLength(0...1)
                )
            )
            + " mm"
    }

    private var calculatedFrontHeightText:
        String
    {
        guard let height =
                millimeters(heightText)
        else {
            return "—"
        }

        return currentNorm
            .wysokoscFrontu(
                korpusMM:
                    height.rawValue,
                szczelinaGornaMM:
                    frontTopGapMM
            )
            .formatted(
                .number.precision(
                    .fractionLength(0...1)
                )
            )
            + " mm"
    }

    private func applySelectedNorm() {
        let norm =
            currentNorm

        let width =
            norm.typoweSzerokosciMM
                .first
            ?? 600

        let height =
            norm.wysokoscKorpusuMM
                .minimum

        let depth =
            norm.glebokoscMM
                .minimum

        widthText =
            width.formatted(
                .number.grouping(.never)
            )
        depthText =
            depth.formatted(
                .number.grouping(.never)
            )

        if supportsBaseHeightSystemV084 {
            var system =
                baseHeightSystemV084

            if let pedestal =
                norm.wysokoscCokoluMM {
                system.legHeightMM =
                    pedestal.minimum
            }

            if let worktop =
                norm.gruboscBlatuMM {
                system.countertopThicknessMM =
                    worktop.minimum
            }

            system.recalculate()
            baseHeightSystemV084 =
                system
            heightText =
                Self.text(
                    Millimeters(
                        system.carcassHeightMM
                    )
                )
            bottomOffsetText =
                Self.text(
                    Millimeters.zero
                )
        } else {
            heightText =
                height.formatted(
                    .number.grouping(.never)
                )

            if let pedestal =
                norm.wysokoscCokoluMM {
                bottomOffsetText =
                    pedestal.minimum
                        .formatted(
                            .number.grouping(
                                .never
                            )
                        )
            }
        }
    }

    private func applyNearestStandardWidth() {
        guard let width =
                millimeters(widthText)
        else {
            return
        }

        let nearest =
            NormySzafekValidator
                .nearestWidth(
                    to:
                        width.rawValue,
                    in: currentNorm
                )

        widthText =
            nearest.formatted(
                .number.grouping(.never)
            )
    }

    private func rangeText(
        _ range:
            ZakresNormyMM
    ) -> String {
        "\(range.minimum.formatted(.number.precision(.fractionLength(0...1))))–\(range.maximum.formatted(.number.precision(.fractionLength(0...1)))) mm"
    }

    private func validationSymbol(
        _ level:
            PoziomWalidacjiNormySzafki
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
            PoziomWalidacjiNormySzafki
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

    private var normSummaryText:
        String
    {
        let norm =
            currentNorm

        var lines = [
            "Norma: \(norm.nazwa)",
            "Głębokość: \(rangeText(norm.glebokoscMM))",
            "Wysokość korpusu: \(rangeText(norm.wysokoscKorpusuMM))",
            "Luz boczny frontu: \(norm.luzFrontuBocznyMM.formatted(.number.precision(.fractionLength(0...1)))) mm",
            "Szczelina między frontami: \(rangeText(norm.szczelinaMiedzyFrontamiMM))"
        ]

        if let back =
            norm.odsunPlecyOdTyluMM {
            lines.append(
                "Odsunięcie pleców: \(rangeText(back))"
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }

    private func openTechnicalCard() {
        guard let width =
                millimeters(widthText),
              let height =
                millimeters(heightText),
              let depth =
                millimeters(depthText)
        else {
            validationMessage =
                "Najpierw podaj poprawne wymiary modułu."
            return
        }

        var card = makeTechnicalCard(
            width: width,
            height: height,
            depth: depth
        )

        if let error =
            synchronizujSzuflady(
                w: &card
            ) {
            validationMessage = error
            return
        }

        technicalCard = card
    }

    private func makeTechnicalCard(
        width: Millimeters,
        height: Millimeters,
        depth: Millimeters
    ) -> KartaTechnicznaSzafki {
        let trimmedName =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        var card:
            KartaTechnicznaSzafki

        if let technicalCard {
            card = technicalCard
        } else if let saved =
            zapisanaKartaTechniczna(
                moduleName: trimmedName
            ) {
            moduleTechnicalID =
                saved.draftID
            card = saved
        } else {
            card =
                KartaTechnicznaSzafkiBuilder
                    .build(
                        template:
                            template,
                        moduleName:
                            trimmedName,
                        width: width,
                        height: height,
                        depth: depth,
                        shelfCount:
                            shelfCount,
                        existingID:
                            moduleTechnicalID
                    )
        }

        card.nazwa = trimmedName
        card.szerokoscMM =
            width.rawValue
        card.wysokoscMM =
            height.rawValue
        card.glebokoscMM =
            depth.rawValue
        card.liczbaPolek =
            shelfCount
        card.dataAktualizacji =
            Date()
        card.kluczModulu =
            kluczModulu
        card.wersjaSchematu =
            2
        card.uwagi =
            normSummaryText

        synchronizujDolnyWieniecLEDV083(
            w: &card
        )

        uzupelnijWierceniaProdukcyjneV0101(
            w: &card,
            width: width,
            height: height,
            depth: depth
        )

        return card
    }

    /// Dokłada wiercenia produkcyjne do karty odtworzonej z zapisu.
    ///
    /// Karta modułu jest renderowana tym samym arkuszem `ArkuszTechnicznyA4V028`
    /// niezależnie od tego, czy otworzy się ją z elewacji, czy stąd — ale
    /// **przygotowanie danych różniło się między tymi drogami**.
    /// `KartyTechniczneModulowV028` (wejście z elewacji) i kreator mebla wołają
    /// `applyProductionDrillings`, a ta ścieżka nie wołała jej wcale.
    ///
    /// Skutek był taki, że karta zapisana kiedyś, a otwarta z biblioteki po
    /// zmianie wymiarów, pokazywała osie prowadnic i puszki zawiasów z poprzedniej
    /// geometrii albo nie pokazywała ich w ogóle. To jest rysunek, z którego
    /// wierci się bok korpusu.
    ///
    /// Merge, nie nadpisanie: `applyProductionDrillings` scala punkty świeżo
    /// wyliczone z zapisanymi, więc ręczne korekty w karcie nie znikają.
    private func uzupelnijWierceniaProdukcyjneV0101(
        w card: inout KartaTechnicznaSzafki,
        width: Millimeters,
        height: Millimeters,
        depth: Millimeters
    ) {
        let swieza =
            KartaTechnicznaSzafkiBuilder
                .build(
                    template: template,
                    moduleName: card.nazwa,
                    width: width,
                    height: height,
                    depth: depth,
                    shelfCount: shelfCount,
                    existingID: card.draftID
                )

        KartaTechnicznaSzafkiBuilder
            .applyProductionDrillings(
                to: &card,
                generated: swieza
            )
    }

    private func zapisanaKartaTechniczna(
        moduleName: String
    ) -> KartaTechnicznaSzafki? {
        if let kluczModulu {
            return KartaTechnicznaSzafkiStore
                .card(
                    forModuleKey:
                        kluczModulu
                )
                ?? KartaTechnicznaSzafkiStore
                    .powiazNajstarszaKarteLegacy(
                        templateCode:
                            template.code,
                        moduleName:
                            moduleName,
                        zKluczemModulu:
                            kluczModulu
                    )
        }

        return KartaTechnicznaSzafkiStore
            .card(
                for: moduleTechnicalID
            )
    }

    private func synchronizujDolnyWieniecLEDV083(
        w card:
            inout KartaTechnicznaSzafki
    ) {
        let marker =
            Self.lowerLedRailMarkerV083

        card.efektywneElementy
            .removeAll {
                $0.uwagi
                    .hasPrefix(marker)
            }

        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi
                    .hasPrefix(marker)
            }

        guard lowerLedRailEnabledV083 else {
            return
        }

        let lengthMM =
            max(
                millimeters(lowerLedRailLengthTextV083)?
                    .rawValue
                ?? card.szerokoscMM,
                1
            )
        let depthMM =
            max(
                millimeters(lowerLedRailDepthTextV083)?
                    .rawValue
                ?? 60,
                1
            )
        let thicknessMM =
            max(
                millimeters(lowerLedRailThicknessTextV083)?
                    .rawValue
                ?? 18,
                1
            )

        card.efektywneElementy
            .append(
                ElementTechnicznySzafki(
                    etykieta:
                        "\(card.numerSzafki)_LED_WD",
                    typ:
                        .wieniecDolny,
                    nazwa:
                        "Dolny wieniec LED łączący ciąg",
                    dlugoscMM:
                        lengthMM,
                    szerokoscMM:
                        depthMM,
                    gruboscMM:
                        thicknessMM,
                    ilosc: 1,
                    material:
                        card.materialKorpusu,
                    kierunek:
                        .poziomy,
                    uwagi:
                        "\(marker) długość \(lengthMM.formatted()) mm; głębokość \(depthMM.formatted()) mm; frez/kanał LED do potwierdzenia z profilem."
                )
            )

        dodajAkcesoriumLEDV083(
            profilID: "led.profile.generic",
            ilosc:
                max(
                    Int(
                        ceil(lengthMM / 1000)
                    ),
                    1
                ),
            target:
                "\(card.numerSzafki)_LED_WD",
            lengthMM:
                lengthMM,
            do: &card
        )

        dodajAkcesoriumLEDV083(
            profilID: "tasma.led.neutral",
            ilosc:
                max(
                    Int(
                        ceil(lengthMM / 1000)
                    ),
                    1
                ),
            target:
                "\(card.numerSzafki)_LED_WD",
            lengthMM:
                lengthMM,
            do: &card
        )

        dodajAkcesoriumLEDV083(
            profilID: "zasilacz.led.30w",
            ilosc:
                max(
                    Int(
                        ceil(lengthMM / 2500)
                    ),
                    1
                ),
            target:
                "\(card.numerSzafki)_LED_WD",
            lengthMM:
                lengthMM,
            do: &card
        )
    }

    private func dodajAkcesoriumLEDV083(
        profilID: String,
        ilosc: Int,
        target: String,
        lengthMM: Double,
        do card:
            inout KartaTechnicznaSzafki
    ) {
        guard let profile =
            KatalogRegulAkcesoriow
                .profil(id: profilID)
        else {
            return
        }

        let marketPrice =
            profile.cenaRynkowa

        card.efektywneAkcesoria
            .append(
                InstancjaAkcesoriumSzafki(
                    profilID:
                        profile.id,
                    producent:
                        profile.producent,
                    rodzina:
                        profile.rodzina,
                    model:
                        profile.model,
                    kategoria:
                        profile.kategoria,
                    ilosc:
                        max(ilosc, 1),
                    docelowaEtykietaElementu:
                        target,
                    cenaJednostkowaNettoPLN:
                        marketPrice?
                            .cenaSredniaNettoPLN,
                    cenaJednostkowaBruttoPLN:
                        marketPrice?
                            .cenaSredniaBruttoPLN,
                    jednostkaCeny:
                        marketPrice?
                            .jednostka
                            .skrot,
                    dataCeny:
                        marketPrice?
                            .dataResearchu,
                    liczbaProbekCeny:
                        marketPrice?
                            .liczbaProbek,
                    uwagi:
                        "\(Self.lowerLedRailMarkerV083) \(lengthMM.formatted()) mm; \(profile.rodzina) \(profile.model)"
                )
            )
    }

    private func synchronizujOkuciaFrontuV068(
        w card:
            inout KartaTechnicznaSzafki
    ) {
        let marker =
            "AUTO-FRONT-V068:"

        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi
                    .hasPrefix(
                        marker
                    )
            }

        card.punktyWiercenia
            .removeAll {
                $0.opis
                    .hasPrefix(
                        marker
                    )
            }

        for index in card
            .efektywneElementy
            .indices {
            card
                .efektywneElementy[
                    index
                ]
                .punktyWiercenia
                .removeAll {
                    $0.opis
                        .hasPrefix(
                            marker
                        )
                }
        }

        guard
            let configuration =
                card
                    .konfiguracjaFunkcjonalnaV068,
            !configuration
                .front
                .profilOkuciaID
                .isEmpty,
            let profile =
                ProfilOkuciaResolverV068
                    .profil(
                        id:
                            configuration
                                .front
                                .profilOkuciaID
                    )
        else {
            return
        }

        let opening =
            ProfilOkuciaResolverV068
                .efektywneOtwarcie(
                    konfiguracja:
                        configuration
                )
        let frontCount =
            configuration
                .front
                .bezpiecznaLiczbaFrontow
        let quantityPerFront: Int

        switch profile.kategoria {
        case .zawias:
            quantityPerFront =
                liczbaZawiasowNaFrontV068(
                    wysokoscMM:
                        card.wysokoscMM
                )
        case .podnosnikFrontu:
            quantityPerFront = 1
        default:
            quantityPerFront = 1
        }

        let quantity =
            max(
                frontCount
                * quantityPerFront,
                1
            )
        let marketPrice =
            profile.cenaRynkowa

        card.efektywneAkcesoria
            .append(
                InstancjaAkcesoriumSzafki(
                    profilID:
                        profile.id,
                    producent:
                        profile.producent,
                    rodzina:
                        profile.rodzina,
                    model:
                        profile.model,
                    kategoria:
                        profile.kategoria,
                    ilosc:
                        quantity,
                    docelowaEtykietaElementu:
                        "FRONT",
                    cenaJednostkowaNettoPLN:
                        marketPrice?
                            .cenaSredniaNettoPLN,
                    cenaJednostkowaBruttoPLN:
                        marketPrice?
                            .cenaSredniaBruttoPLN,
                    jednostkaCeny:
                        marketPrice?
                            .jednostka
                            .skrot,
                    dataCeny:
                        marketPrice?
                            .dataResearchu,
                    liczbaProbekCeny:
                        marketPrice?
                            .liczbaProbek,
                    uwagi:
                        "\(marker)\(opening.rawValue)"
                )
            )

        guard profile.kategoria
            == .zawias
        else {
            return
        }

        let frontHeight =
            max(
                card.wysokoscMM,
                1
            )
        let positions: [Double]

        switch quantityPerFront {
        case 2:
            positions = [
                100,
                max(
                    frontHeight - 100,
                    100
                )
            ]
        default:
            let lower = 100.0
            let upper =
                max(
                    frontHeight - 100,
                    lower
                )
            let step =
                quantityPerFront > 1
                ? (
                    upper - lower
                ) / Double(
                    quantityPerFront - 1
                )
                : 0

            positions =
                (0..<quantityPerFront)
                    .map {
                        lower
                        + Double($0)
                            * step
                    }
        }

        for frontIndex in
            0..<frontCount {
            for (
                hingeIndex,
                y
            ) in positions
                .enumerated() {
                card.punktyWiercenia
                    .append(
                        PunktWierceniaSzafki(
                            element:
                                "Front \(frontIndex + 1)",
                            typ:
                                .zawias,
                            strona:
                                opening
                                    == .prawy
                                ? .prawa
                                : .lewa,
                            xMM:
                                profile
                                    .srednicaPuszkiMM
                                    .map {
                                        max(
                                            $0 / 2
                                            + 4,
                                            21.5
                                        )
                                    }
                                ?? 21.5,
                            yMM: y,
                            srednicaMM:
                                profile
                                    .srednicaPuszkiMM
                                ?? 35,
                            glebokoscMM:
                                profile
                                    .glebokoscPuszkiMM
                                ?? 12,
                            opis:
                                "\(marker)Front \(frontIndex + 1), zawias \(hingeIndex + 1), \(profile.producent) \(profile.rodzina)"
                        )
                    )
            }
        }
    }

    private func liczbaZawiasowNaFrontV068(
        wysokoscMM: Double
    ) -> Int {
        switch wysokoscMM {
        case ..<900:
            return 2
        case ..<1_600:
            return 3
        case ..<2_100:
            return 4
        default:
            return 5
        }
    }

    private func standardoweWysokosciSzufladV068()
        -> [Double]?
    {
        let niska =
            StandardWysokoscSzuflady
                .niska
                .wysokoscFrontuMM
        let wysoka =
            StandardWysokoscSzuflady
                .wysoka
                .wysokoscFrontuMM

        switch drawerLayoutPresetV068 {
        case .jednaWysokaDwieNiskie:
            return [
                niska,
                niska,
                wysoka
            ]
        case .wysokaNaDoleDwieNiskie:
            return [
                wysoka,
                niska,
                niska
            ]
        case .dwieWysokie:
            return [
                wysoka,
                wysoka
            ]
        case .wysokosciNiestandardowe:
            return drawerCustomHeightsV068
                .isEmpty
                ? nil
                : drawerCustomHeightsV068
        case .rowne,
             .cargo:
            return nil
        }
    }

    private func synchronizujSzuflady(
        w card:
            inout KartaTechnicznaSzafki
    ) -> String? {
        guard drawerCount > 0 else {
            usunAutomatyczneSzuflady(
                z: &card
            )
            return nil
        }

        let geometry =
            SzufladyModuluEngine
                .geometria(
                    karty: card
                )

        let gap = 3.0
        let verticalMargins = 6.0
        let presetHeights =
            standardoweWysokosciSzufladV068()
        let effectiveDrawerCount =
            presetHeights?
                .count
            ?? drawerCount
        let availableForFronts =
            geometry.wysokoscMM
            - verticalMargins
            - gap
                * Double(
                    max(
                        effectiveDrawerCount - 1,
                        0
                    )
                )
        let frontHeight: Double
        if let presetHeights {
            let requiredFrontHeight =
                presetHeights
                    .reduce(0, +)
            guard requiredFrontHeight <= availableForFronts else {
                return "Standardowy układ szuflad wymaga \(requiredFrontHeight.formatted()) mm frontów, a dostępne jest \(availableForFronts.formatted()) mm."
            }

            frontHeight =
                presetHeights
                    .min()
                ?? 140
        } else {
            frontHeight =
                availableForFronts
                / Double(effectiveDrawerCount)
        }

        guard frontHeight >= 60 else {
            return "W korpusie o tej wysokości nie mieści się \(effectiveDrawerCount) szuflad z minimalnym frontem 60 mm."
        }

        guard let profile =
            profilDlaAutomatycznychSzuflad(
                w: card,
                glebokoscWnetrzaMM:
                    geometry.glebokoscMM
            )
        else {
            return "Brak profilu systemu szuflady pasującego do głębokości korpusu. Uzupełnij KatalogRegulAkcesoriow."
        }

        let existing =
            card.efektywneSzuflady
                .first {
                    $0.aktywna
                }

        let depthReserve =
            profile.formulaSzuflady?
                .zapasGlebokosciKorpusuMM
            ?? 3
        let maximumLength =
            max(
                geometry.glebokoscMM
                - depthReserve,
                0
            )

        let existingLength =
            existing.map {
                $0.nominalnaDlugoscMM
            }
        let nominalLength =
            existingLength
                .flatMap {
                    $0 <= maximumLength
                    ? $0
                    : nil
                }
            ?? profile
                .dozwoloneDlugosciMM
                .filter {
                    $0 <= maximumLength
                }
                .max()
            ?? 0

        guard nominalLength > 0 else {
            return "Dostępna głębokość \(geometry.glebokoscMM.formatted()) mm jest za mała dla systemu \(profile.producent) \(profile.rodzina)."
        }

        let maximumBoxHeight =
            max(
                frontHeight - 10,
                40
            )
        let existingBoxHeight =
            existing.map {
                $0.wysokoscSkrzynkiMM
            }
        let boxHeight =
            existingBoxHeight
                .flatMap {
                    $0 <= maximumBoxHeight
                    ? $0
                    : nil
                }
            ?? profile
                .dozwoloneWysokosciMM
                .filter {
                    $0 <= maximumBoxHeight
                }
                .max()
            ?? min(
                120,
                maximumBoxHeight
            )

        let parameters =
            ParametryAutomatycznegoUkladuSzuflad(
                liczba:
                    effectiveDrawerCount,
                wysokoscFrontuMM:
                    frontHeight,
                wysokoscSkrzynkiMM:
                    boxHeight,
                nominalnaDlugoscMM:
                    nominalLength,
                szczelinaMiedzyFrontamiMM:
                    gap,
                marginesDolnyMM:
                    3,
                marginesGornyMM:
                    3,
                typFrontu:
                    drawerFrontTypeV068,
                profilID:
                    profile.id,
                odsuniecieOdScianBocznychMM:
                    drawerFrontTypeV068 == .wewnetrzny
                    ? max(
                        millimeters(drawerSideInsetTextV068)?
                            .rawValue
                        ?? 21,
                        0
                    )
                    : 0
            )

        let drawers:
            [SzufladaModulu]
        if drawerLayoutPresetV068 == .cargo {
            drawers =
                SzufladyModuluEngine
                    .generujZPresetu(
                        preset: .cargo,
                        parametryBazowe:
                            parameters,
                        dla: card
                    )
        } else if let presetHeights {
            drawers =
                SzufladyModuluEngine
                    .generujZPresetu(
                        preset:
                            .wysokosciNiestandardowe(
                                presetHeights
                            ),
                        parametryBazowe:
                            parameters,
                        dla: card
                    )
        } else {
            drawers =
                SzufladyModuluEngine
                    .generuj(
                        parametry:
                            parameters,
                        dla: card
                    )
        }

        SzufladyModuluEngine
            .zastosuj(
                szuflady:
                    drawers,
                profil: profile,
                usunKolidujacePolki:
                    true,
                do: &card
            )

        let errors =
            SzufladyModuluEngine
                .waliduj(
                    szuflady:
                        card
                            .efektywneSzuflady,
                    w: card
                )
                .filter {
                    $0.poziom == .blad
                }

        if let first = errors.first {
            return first.komunikat
        }

        shelfCount =
            card.liczbaPolek
            ?? shelfCount
        return nil
    }

    private func profilDlaAutomatycznychSzuflad(
        w card:
            KartaTechnicznaSzafki,
        glebokoscWnetrzaMM:
            Double
    ) -> ProfilAkcesoriumMeblowego? {
        if let configuredProfileID =
            card
                .konfiguracjaFunkcjonalnaV068?
                .szuflady
                .profilID,
           !configuredProfileID.isEmpty,
           let configuredProfile =
            KatalogRegulAkcesoriow
                .profil(
                    id:
                        configuredProfileID
                ),
           profil(
                configuredProfile,
                pasujeDo:
                    glebokoscWnetrzaMM
           ) {
            return configuredProfile
        }

        if let profileID =
            card.efektywneSzuflady
                .first(where: \.aktywna)?
                .profilID,
           let profile =
            KatalogRegulAkcesoriow
                .profil(id: profileID),
           profil(
                profile,
                pasujeDo:
                    glebokoscWnetrzaMM
           ) {
            return profile
        }

        return KatalogRegulAkcesoriow
            .profile
            .filter {
                (
                    $0.kategoria
                        == .systemSzuflady
                    || $0.kategoria
                        == .prowadnica
                )
                && profil(
                    $0,
                    pasujeDo:
                        glebokoscWnetrzaMM
                )
            }
            .sorted {
                if $0.producent
                    != $1.producent {
                    return $0.producent
                        .localizedCaseInsensitiveCompare(
                            $1.producent
                        )
                        == .orderedAscending
                }
                return $0.rodzina
                    .localizedCaseInsensitiveCompare(
                        $1.rodzina
                    )
                    == .orderedAscending
            }
            .first
    }

    private func profil(
        _ profile:
            ProfilAkcesoriumMeblowego,
        pasujeDo glebokoscWnetrzaMM:
            Double
    ) -> Bool {
        let reserve =
            profile.formulaSzuflady?
                .zapasGlebokosciKorpusuMM
            ?? 3

        return profile
            .dozwoloneDlugosciMM
            .contains {
                $0 + reserve
                    <= glebokoscWnetrzaMM
            }
    }

    private func usunAutomatyczneSzuflady(
        z card:
            inout KartaTechnicznaSzafki
    ) {
        card.efektywneSzuflady = []
        card.efektywneElementy
            .removeAll {
                $0.typ == .szuflada
            }
        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi
                    .hasPrefix(
                        "AUTO-SZUFLADA:"
                    )
            }

        for index in card
            .efektywneElementy
            .indices {
            card
                .efektywneElementy[
                    index
                ]
                .punktyWiercenia
                .removeAll {
                    $0.opis
                        .hasPrefix(
                            "AUTO-SZUFLADA:"
                        )
                }
        }
    }

    private func save() {
        validationMessage = nil

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Nazwa modułu nie może być pusta."
            return
        }

        guard let width = millimeters(widthText), width > .zero,
              let height = millimeters(heightText), height > .zero,
              let depth = millimeters(depthText), depth > .zero,
              let enteredOffsetAlongWall = millimeters(offsetAlongWallText),
              enteredOffsetAlongWall >= .zero,
              let offsetFromWall = millimeters(offsetFromWallText),
              offsetFromWall >= .zero,
              let bottomOffset = millimeters(bottomOffsetText),
              bottomOffset >= .zero else {
            validationMessage = "Sprawdź wszystkie wartości podane w milimetrach."
            return
        }

        guard let carcassThickness =
                millimeters(carcassThicknessText),
              carcassThickness > .zero,
              let shelfFrontSetback =
                millimeters(shelfFrontSetbackText),
              shelfFrontSetback >= .zero,
              let backThickness =
                millimeters(backThicknessText),
              backThickness >= .zero,
              let backInset =
                millimeters(backInsetText),
              backInset >= .zero,
              let topRailDepth =
                millimeters(topRailDepthText),
              topRailDepth >= .zero,
              let frontThickness =
                millimeters(frontThicknessText),
              frontThickness > .zero,
              let frontGap =
                millimeters(frontGapText),
              frontGap >= .zero,
              let frontInset =
                millimeters(frontInsetText),
              frontInset >= .zero,
              let bottomShortening =
                millimeters(bottomShorteningText),
              bottomShortening >= .zero else {
            validationMessage =
                "Sprawdź wartości konstrukcji modułu."
            return
        }

        if backType == .inset,
           backThickness <= .zero {
            validationMessage =
                "Plecy wpuszczane muszą mieć dodatnią grubość."
            return
        }

        if topConstruction == .frontAndRearRails,
           topRailDepth <= .zero {
            validationMessage =
                "Rygle górne muszą mieć dodatnią głębokość."
            return
        }

        if openingTechnology == .shortenedBottomFingerPull,
           (bottomShortening <= .zero
            || bottomShortening >= depth) {
            validationMessage =
                "Podcięcie dna musi być większe od zera i mniejsze od głębokości modułu."
            return
        }

        if lowerLedRailEnabledV083 {
            guard let ledLength =
                    millimeters(
                        lowerLedRailLengthTextV083
                    ),
                  ledLength > .zero,
                  let ledDepth =
                    millimeters(
                        lowerLedRailDepthTextV083
                    ),
                  ledDepth > .zero,
                  let ledThickness =
                    millimeters(
                        lowerLedRailThicknessTextV083
                    ),
                  ledThickness > .zero else {
                validationMessage =
                    "Sprawdź długość, głębokość i grubość dolnego wieńca LED."
                return
            }
        }

        if storedAssembly == nil,
           let maximumWidth = suggestedPlacement?.maximumWidth,
           width > maximumWidth {
            validationMessage = "Dostępne miejsce ma maksymalnie \(Self.formatted(maximumWidth))."
            return
        }

        let resolvedBaseHeightSystemV084:
            KitchenBaseHeightSystemV018?
        if supportsBaseHeightSystemV084 {
            let recalculated =
                baseHeightSystemV084
                    .recalculated()

            guard recalculated
                .carcassHeightMM
                > 0
            else {
                validationMessage =
                    "Wysokość robocza musi dawać dodatnią wysokość korpusu."
                return
            }

            resolvedBaseHeightSystemV084 =
                recalculated
        } else {
            resolvedBaseHeightSystemV084 =
                nil
        }

        let effectiveHeight =
            resolvedBaseHeightSystemV084
                .map {
                    Millimeters(
                        $0.carcassHeightMM
                    )
                }
            ?? height

        let effectiveBottomOffset =
            resolvedBaseHeightSystemV084 == nil
            ? bottomOffset
            : Millimeters.zero

        let resolvedOffsetAlongWall: Millimeters
        if storedAssembly == nil,
           let rightEdgeAnchor = suggestedPlacement?.rightEdgeAnchor {
            resolvedOffsetAlongWall = rightEdgeAnchor - width

            guard resolvedOffsetAlongWall >= .zero else {
                validationMessage =
                    "Wybrany moduł jest zbyt szeroki, aby dodać go po lewej stronie."
                return
            }
        } else {
            resolvedOffsetAlongWall = enteredOffsetAlongWall
        }

        var currentCard =
            makeTechnicalCard(
                width: width,
                height: effectiveHeight,
                depth: depth
            )

        currentCard
            .konfiguracjaFunkcjonalnaV068 =
                currentFunctionalConfigurationV068()

        if let error =
            synchronizujSzuflady(
                w: &currentCard
            ) {
            validationMessage = error
            return
        }

        synchronizujOkuciaFrontuV068(
            w: &currentCard
        )

        KartaTechnicznaSzafkiStore
            .save(currentCard)
        technicalCard = currentCard

        let data = KonfiguracjaModuluMeblowegoDane(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            width: width,
            height: effectiveHeight,
            depth: depth,
            shelfCount:
                currentCard.liczbaPolek
                ?? shelfCount,
            drawerCount:
                currentCard
                    .efektywneSzuflady
                    .filter(\.aktywna)
                    .count,
            carcassThickness:
                carcassThickness,
            shelfFrontSetback:
                shelfFrontSetback,
            backType:
                backType,
            backThickness:
                backThickness,
            backInset:
                backInset,
            topConstruction:
                topConstruction,
            topRailDepth:
                topRailDepth,
            frontEnabled:
                frontEnabled,
            frontThickness:
                frontThickness,
            frontGap:
                frontGap,
            frontInset:
                frontInset,
            openingTechnology:
                openingTechnology,
            bottomShortening:
                bottomShortening,
            technicalCardDraftID:
                currentCard.draftID,
            offsetAlongWall: resolvedOffsetAlongWall,
            offsetFromWall: offsetFromWall,
            bottomOffset: effectiveBottomOffset
        )

        let savedCardDraftID =
            currentCard.draftID
        let isNewModule =
            storedAssembly == nil

        isSaving = true
        Task {
            let didSave = await onSave(data)
            await MainActor.run {
                isSaving = false
                if didSave {
                    dismiss()
                } else {
                    if isNewModule {
                        KartaTechnicznaSzafkiStore
                            .usunKarte(
                                forDraftID:
                                    savedCardDraftID
                            )
                    }

                    validationMessage = "Nie udało się zapisać modułu. Sprawdź komunikat błędu i położenie przy ścianie."
                }
            }
        }
    }

    private func millimeters(_ text: String) -> Millimeters? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        // Polskie ustawienia regionalne wyświetlają 2070 jako „2.070”.
        // Kropka jest wtedy separatorem tysięcy, a nie częścią ułamkową.
        // NumberFormatter odczytuje wartość zgodnie z bieżącym Locale.
        let localizedFormatter = NumberFormatter()
        localizedFormatter.locale = .current
        localizedFormatter.numberStyle = .decimal
        localizedFormatter.isLenient = false

        if let number = localizedFormatter.number(from: trimmed) {
            let value = number.doubleValue
            guard value.isFinite else {
                return nil
            }
            return Millimeters(value)
        }

        // Fallback pozwala wkleić wartość bez względu na spacje grupujące
        // oraz użyć przecinka jako separatora dziesiętnego.
        let normalized = trimmed
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized), value.isFinite else {
            return nil
        }

        return Millimeters(value)
    }

    private static func text(_ value: Millimeters) -> String {
        value.rawValue.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }

    private static func formatted(_ value: Millimeters) -> String {
        "\(text(value)) mm"
    }

    private static func initialDrawerLayoutPresetV068(
        drawers:
            [SzufladaModulu]
    ) -> RodzajPresetuUkladuSzuflad {
        guard !drawers.isEmpty else {
            return .rowne
        }

        if drawers.count == 1,
           drawers.first?.efektywnyWariant == .cargo {
            return .cargo
        }

        let heights =
            drawers.map {
                $0.wysokoscFrontuMM
            }

        if Set(
            heights.map {
                Int($0.rounded())
            }
        )
        .count == 1 {
            return .rowne
        }

        guard heights.count == 3 else {
            return .wysokosciNiestandardowe
        }

        let low =
            StandardWysokoscSzuflady
                .niska
                .wysokoscFrontuMM
        let high =
            StandardWysokoscSzuflady
                .wysoka
                .wysokoscFrontuMM

        if isClose(
            heights[0],
            high
        ),
           isClose(
            heights[1],
            low
           ),
           isClose(
            heights[2],
            low
           ) {
            return .wysokaNaDoleDwieNiskie
        }

        if isClose(
            heights[0],
            low
        ),
           isClose(
            heights[1],
            low
           ),
           isClose(
            heights[2],
            high
           ) {
            return .jednaWysokaDwieNiskie
        }

        return .wysokosciNiestandardowe
    }

    private static func isClose(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double = 12
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    private static func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters {
        StandardKitchenTemplatesV0143.defaultBottomOffset(for: template)
            ?? (template.builderType == .wallCabinet ? 1400 : .zero)
    }
}
