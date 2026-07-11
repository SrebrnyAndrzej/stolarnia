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

    // v0.68.0: front, kierunek otwierania i okucia korzystają z jednej
    // konfiguracji zapisanej w karcie technicznej modułu.
    @State private var frontCountV068: Int
    @State private var frontOpeningV068:
        KierunekOtwarciaFrontuV068
    @State private var selectedFrontHardwareProfileIDV068:
        String
    @State private var selectedDrawerProfileIDV068:
        String
    @State private var showPresetSavedMessageV068 =
        false

    init(
        template: FurnitureTemplate,
        storedAssembly: StoredFurnitureAssembly? = nil,
        suggestedPlacement: SugerowanePolozenieModulu? = nil,
        poczatkowePoleWymiaru:
            PoleWymiaruModulu2D? = nil,
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

        _drawerCount = State(
            initialValue:
                initialDrawerCount
        )

        // Oblicz szerokość wcześniej, żeby domyslna() mogło
        // automatycznie wyliczyć poprawną liczbę frontów z reguły szerokości.
        let templateWidthForFronts =
            (try? parameters.millimeters(for: .width))
            ?? 600
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
            initialValue: Self.text(
                (try? parameters.millimeters(for: .height)) ?? 720
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
                       supports(.bottomShortening) {
                        PolePomiaroweMM(
                            "Podcięcie dna",
                            text: $bottomShorteningText
                        )
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

            Section("Położenie przy ścianie") {
                PolePomiaroweMM(
                    "Od początku ściany",
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
                    "Odsunięcie od ściany",
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
            }
        }
        .sheet(
            item: $technicalCard
        ) { card in
            KartaTechnicznaSzafkiView(
                card: card
            )
        }
        .interactiveDismissDisabled(isSaving)
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

    private func supports(
        _ key: FurnitureParameterKey
    ) -> Bool {
        supportedParameterKeys.contains(key)
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
            return "Podchwyt w dnie"
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
        heightText =
            height.formatted(
                .number.grouping(.never)
            )
        depthText =
            depth.formatted(
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

        return card
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
        let availableForFronts =
            geometry.wysokoscMM
            - verticalMargins
            - gap
                * Double(
                    max(
                        drawerCount - 1,
                        0
                    )
                )
        let frontHeight =
            availableForFronts
            / Double(drawerCount)

        guard frontHeight >= 60 else {
            return "W korpusie o tej wysokości nie mieści się \(drawerCount) szuflad z minimalnym frontem 60 mm."
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
                    drawerCount,
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
                    existing?
                        .typFrontu
                    ?? .zewnetrzny,
                profilID:
                    profile.id
            )

        let drawers =
            SzufladyModuluEngine
                .generuj(
                    parametry:
                        parameters,
                    dla: card
                )

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

        if storedAssembly == nil,
           let maximumWidth = suggestedPlacement?.maximumWidth,
           width > maximumWidth {
            validationMessage = "Dostępne miejsce ma maksymalnie \(Self.formatted(maximumWidth))."
            return
        }

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
                height: height,
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
            height: height,
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
            bottomOffset: bottomOffset
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

    private static func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters {
        StandardKitchenTemplatesV0143.defaultBottomOffset(for: template)
            ?? (template.builderType == .wallCabinet ? 1400 : .zero)
    }
}
