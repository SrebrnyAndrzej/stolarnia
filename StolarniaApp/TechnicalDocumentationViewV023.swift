import DomainCore
import SwiftUI

private enum TechnicalDocumentationSheetV023:
    String,
    Identifiable
{
    case installations
    case cornerCabinets
    case cornerProduction
    case productionExport
    case workshopSettings

    var id: String { rawValue }
}

struct TechnicalDocumentationViewV023: View {
    let room: RoomDefinition
    let wall: WallSegment
    let assemblies: [FurnitureAssembly]
    let allAssemblies:
        [FurnitureAssembly]

    init(
        room: RoomDefinition,
        wall: WallSegment,
        assemblies:
            [FurnitureAssembly],
        allAssemblies:
            [FurnitureAssembly]
    ) {
        self.room = room
        self.wall = wall
        self.assemblies =
            assemblies
        self.allAssemblies =
            allAssemblies
    }

    @Environment(\.dismiss)
    private var dismiss

    @State private var mode:
        TechnicalDrawingModeV023 = .dimensioned

    @State private var visibleLayers:
        Set<TechnicalDrawingLayerV023> = [
            .carcasses,
            .fronts,
            .dimensions,
            .labels,
            .installations
        ]

    @State private var installationPoints:
        [TechnicalInstallationPointV023] = []

    @State private var selectedInstallationPointID: UUID?
    @State private var selectedScale:
        DrawingScaleV023 = .automatic
    @State private var selectedFormat:
        DrawingSheetFormatV023 = .screen
    @State private var showTitleBlock = true
    @State private var selectedSettingsTab:
        SettingsTabV023 = .sheet

    @State private var projectionKindV024:
        DocumentationProjectionKindV024 =
            .elevation

    @State private var axonometricSettingsV024 =
        AxonometricSettingsV024()

    @State private var cornerDefinitionsV025:
        [CornerCabinetDefinitionV025] = []

    @State private var activeSheet:
        TechnicalDocumentationSheetV023?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                documentationHeader

                Divider()

                drawingArea
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

                Divider()

                inspectorPanel
                    .frame(
                        minHeight: 170,
                        maxHeight: 240
                    )

                statusBar
            }
            .navigationTitle(
                "Dokumentacja techniczna"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .stolarniaReadableInterface()
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
                        .primaryAction
                ) {
                    workshopSettingsButton

                    if projectionKindV024
                        == .roomAxonometry {
                        cornerActionsMenu
                    }

                    if mode == .installations,
                       projectionKindV024
                        == .elevation {
                        editInstallationsButton
                    }
                }
            }
        }
        .onAppear {
            installationPoints =
                TechnicalInstallationRepositoryV023
                    .load(
                        wallID: wall.id
                    )

            cornerDefinitionsV025 =
                CornerCabinetRepositoryV025
                    .loadAll()
        }
        .sheet(
            item: $activeSheet
        ) {
            sheet in

            activeSheetView(sheet)
        }
    }

    private var workshopSettingsButton:
        some View
    {
        Button {
            activeSheet =
                .workshopSettings
        } label: {
            Label(
                "Ustawienia stolarni",
                systemImage:
                    "gearshape"
            )
        }
    }

    private var editInstallationsButton:
        some View
    {
        Button {
            activeSheet =
                .installations
        } label: {
            Label(
                "Edytuj instalacje",
                systemImage:
                    "plus.circle"
            )
        }
    }

    private var cornerActionsMenu:
        some View
    {
        Menu {
            Button {
                activeSheet =
                    .cornerCabinets
            } label: {
                Label(
                    "Szafki narożne",
                    systemImage:
                        "square.split.diagonal.2x2"
                )
            }

            Button {
                activeSheet =
                    .cornerProduction
            } label: {
                Label(
                    "Produkcja narożników",
                    systemImage:
                        "list.bullet.clipboard"
                )
            }
            .disabled(
                cornerDefinitionsV025
                    .isEmpty
            )

            Button {
                activeSheet =
                    .productionExport
            } label: {
                Label(
                    "Eksport PDF/CSV",
                    systemImage:
                        "square.and.arrow.up"
                )
            }
            .disabled(
                cornerDefinitionsV025
                    .isEmpty
            )
        } label: {
            Label(
                "Narożniki",
                systemImage:
                    "square.split.diagonal.2x2"
            )
        }
    }

    @ViewBuilder
    private func activeSheetView(
        _ sheet: TechnicalDocumentationSheetV023
    ) -> some View {
        switch sheet {
        case .installations:
            TechnicalInstallationEditorV023(
                wallID: wall.id,
                points:
                    $installationPoints
            )

        case .cornerCabinets:
            CornerCabinetEditorV025(
                assemblies:
                    allAssemblies,
                definitions:
                    $cornerDefinitionsV025
            )

        case .cornerProduction:
            CornerCabinetProductionViewV026(
                assemblies:
                    allAssemblies,
                definitions:
                    cornerDefinitionsV025
            )

        case .productionExport:
            ProductionExportViewV027(
                projectName: room.name,
                assemblies:
                    allAssemblies,
                definitions:
                    cornerDefinitionsV025
            )

        case .workshopSettings:
            PanelUstawienStolarni()
        }
    }

    private var documentationHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text("Dokumentacja")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(room.name) • \(wall.name)")
                        .font(.headline)
                        .lineLimit(1)
                }
                .frame(
                    minWidth: 160,
                    alignment: .leading
                )

                Picker(
                    "Widok",
                    selection:
                        $projectionKindV024
                ) {
                    ForEach(
                        DocumentationProjectionKindV024
                            .allCases
                    ) { item in
                        Label(
                            item.title,
                            systemImage:
                                item.systemImage
                        )
                        .tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                if projectionKindV024
                    == .elevation {
                    Picker(
                        "Tryb",
                        selection: $mode
                    ) {
                        ForEach(
                            TechnicalDrawingModeV023
                                .allCases
                        ) { item in
                            Text(item.title)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                } else {
                    Picker(
                        "Kierunek",
                        selection:
                            $axonometricSettingsV024
                                .direction
                    ) {
                        ForEach(
                            AxonometricDirectionV024
                                .allCases
                        ) {
                            Text($0.title)
                                .tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                }

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    metadataChip(
                        title: "Skala",
                        value:
                            selectedScale.title,
                        systemImage: "ruler"
                    )

                    metadataChip(
                        title: "Format",
                        value:
                            selectedFormat.title,
                        systemImage:
                            "doc.text"
                    )

                    metadataChip(
                        title: "Moduły",
                        value:
                            "\(assemblies.count)",
                        systemImage:
                            "square.grid.3x3"
                    )

                    metadataChip(
                        title: "Instalacje",
                        value:
                            "\(installationPoints.count)",
                        systemImage:
                            "bolt"
                    )
                }
            }
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            8
        )
        .background(
            .regularMaterial
        )
    }

    private var drawingArea:
        some View
    {
        GeometryReader { proxy in
            ZStack {
                StolarniaPalette.drawingDesk

                drawingContent(
                    availableSize:
                        fittedAvailableSize(
                            proxy.size
                        )
                )
                .padding(12)
                .environment(\.colorScheme, .light)
            }
        }
    }

    @ViewBuilder
    private func drawingContent(
        availableSize: CGSize
    ) -> some View {
        switch projectionKindV024 {
        case .elevation:
            TechnicalSheetViewV023(
                document: document,
                mode: mode,
                visibleLayers:
                    visibleLayers,
                selectedInstallationPointID:
                    selectedInstallationPointID,
                scale: selectedScale,
                format: selectedFormat,
                showTitleBlock:
                    showTitleBlock,
                availableSize:
                    availableSize
            )

        case .axonometry:
            TechnicalAxonometricSheetV024(
                document: document,
                settings:
                    axonometricSettingsV024,
                scale: selectedScale,
                format: selectedFormat,
                showTitleBlock:
                    showTitleBlock,
                availableSize:
                    availableSize
            )

        case .roomAxonometry:
            RoomAxonometricSheetV025(
                room: room,
                wall: wall,
                assemblies:
                    allAssemblies,
                cornerDefinitions:
                    cornerDefinitionsV025,
                settings:
                    axonometricSettingsV024,
                scale: selectedScale,
                format: selectedFormat,
                showTitleBlock:
                    showTitleBlock,
                availableSize:
                    availableSize
            )
        }
    }

    private var inspectorPanel:
        some View
    {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Label(
                    "Ustawienia dokumentacji",
                    systemImage:
                        "slider.horizontal.3"
                )
                .font(.headline)

                Spacer()

                Picker(
                    "Ustawienia",
                    selection:
                        $selectedSettingsTab
                ) {
                    ForEach(
                        SettingsTabV023.allCases
                    ) { tab in
                        Label(
                            tab.title,
                            systemImage:
                                tab.systemImage
                        )
                        .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
            }
            .padding(.horizontal, 12)

            ScrollView(.vertical) {
                Group {
                    switch selectedSettingsTab {
                    case .sheet:
                        sheetSettings

                    case .layers:
                        layerSettings

                    case .information:
                        informationSettings
                    }
                }
                .frame(
                    maxWidth: .infinity
                )
            }
            .scrollIndicators(.visible)
        }
        .padding(.vertical, 8)
        .background(
            Color(
                uiColor:
                    .secondarySystemBackground
            )
        )
    }

    private var sheetSettings:
        some View
    {
        LazyVGrid(
            columns:
                inspectorGridColumns,
            spacing: 12
        ) {
            settingCard(
                title: "Skala",
                systemImage: "ruler"
            ) {
                Picker(
                    "Skala",
                    selection:
                        $selectedScale
                ) {
                    ForEach(
                        DrawingScaleV023
                            .allCases
                    ) {
                        Text($0.title)
                            .tag($0)
                    }
                }
                .pickerStyle(.menu)
            }

            settingCard(
                title: "Format",
                systemImage:
                    "doc.text"
            ) {
                Picker(
                    "Format",
                    selection:
                        $selectedFormat
                ) {
                    ForEach(
                        DrawingSheetFormatV023
                            .allCases
                    ) {
                        Text($0.title)
                            .tag($0)
                    }
                }
                .pickerStyle(.menu)
            }

            settingCard(
                title:
                    "Tabliczka rysunkowa",
                systemImage:
                    "rectangle.bottomthird.inset.filled"
            ) {
                Toggle(
                    "Pokaż",
                    isOn:
                        $showTitleBlock
                )
                .labelsHidden()
            }

            if mode == .installations {
                settingCard(
                    title: "Instalacje",
                    systemImage: "bolt"
                ) {
                    Button(
                        "Edytuj punkty"
                    ) {
                        activeSheet =
                            .installations
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(
            .horizontal,
            12
        )
    }

    private var layerSettings:
        some View
    {
        Group {
            if projectionKindV024
                == .elevation {
                LazyVGrid(
                    columns:
                        layerGridColumns,
                    spacing: 10
                ) {
                    ForEach(
                        TechnicalDrawingLayerV023
                            .allCases
                    ) { layer in
                        Toggle(
                            layer.title,
                            isOn:
                                layerBinding(
                                    layer
                                )
                        )
                        .toggleStyle(
                            .button
                        )
                        .buttonStyle(
                            .bordered
                        )
                    }
                }
            } else {
                LazyVGrid(
                    columns:
                        layerGridColumns,
                    spacing: 10
                ) {
                    Toggle(
                        "Fronty",
                        isOn:
                            $axonometricSettingsV024
                                .showFronts
                    )
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                    Toggle(
                        "Numery modułów",
                        isOn:
                            $axonometricSettingsV024
                                .showModuleNumbers
                    )
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                    Toggle(
                        "Wymiary",
                        isOn:
                            $axonometricSettingsV024
                                .showDimensions
                    )
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                    Toggle(
                        "Linie ukryte",
                        isOn:
                            $axonometricSettingsV024
                                .showHiddenEdges
                    )
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)

                    Toggle(
                        "Płaszczyzna podłogi",
                        isOn:
                            $axonometricSettingsV024
                                .showFloorPlane
                    )
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var informationSettings:
        some View
    {
        LazyVGrid(
            columns:
                inspectorGridColumns,
            spacing: 12
        ) {
            infoValue(
                title: "Ściana",
                value: wall.name
            )

            infoValue(
                title: "Moduły",
                value:
                    "\(assemblies.count)"
            )

            infoValue(
                title: "Wysokość",
                value:
                    "\(Int(max(wall.startHeight.rawValue, wall.endHeight.rawValue).rounded())) mm"
            )

            infoValue(
                title: "Instalacje",
                value:
                    "\(installationPoints.count)"
            )
        }
        .padding(
            .horizontal,
            12
        )
    }

    private var inspectorGridColumns:
        [GridItem]
    {
        [
            GridItem(
                .adaptive(
                    minimum: 190,
                    maximum: 280
                ),
                spacing: 12
            )
        ]
    }

    private var layerGridColumns:
        [GridItem]
    {
        [
            GridItem(
                .adaptive(
                    minimum: 150,
                    maximum: 220
                ),
                spacing: 10
            )
        ]
    }

    private var statusBar:
        some View
    {
        HStack(spacing: 12) {
            Label(
                projectionStatusTitle,
                systemImage:
                    projectionStatusIcon
            )

            Spacer()

            if projectionKindV024
                == .roomAxonometry {
                Text(
                    "\(cornerDefinitionsV025.count) definicji narożników"
                )

                Text("•")
            }

            Text(
                "Skala \(selectedScale.title)"
            )

            Text("•")

            Text(
                selectedFormat.title
            )

            Text("•")

            Text(
                "\(installationPoints.count) punktów instalacyjnych"
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial
        )
    }

    private var document:
        TechnicalDrawingDocumentV023
    {
        TechnicalDrawingDocumentV023(
            title:
                "\(mode.title) — \(wall.name)",
            wall: wall,
            assemblies: assemblies,
            dimensions: [],
            installationPoints:
                installationPoints
        )
    }

    private var projectionStatusTitle:
        String
    {
        switch projectionKindV024 {
        case .elevation:
            return mode.title
        case .axonometry:
            return "Aksonometria ściany"
        case .roomAxonometry:
            return "Aksonometria pomieszczenia"
        }
    }

    private var projectionStatusIcon:
        String
    {
        switch projectionKindV024 {
        case .elevation:
            return mode.systemImage
        case .axonometry:
            return "cube"
        case .roomAxonometry:
            return "cube.transparent"
        }
    }

    private func fittedAvailableSize(
        _ availableSize: CGSize
    ) -> CGSize {
        CGSize(
            width:
                max(
                    availableSize.width
                    - 32,
                    320
                ),
            height:
                max(
                    availableSize.height
                    - 24,
                    240
                )
        )
    }

    private func metadataChip(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(
                systemName:
                    systemImage
            )

            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )

                Text(value)
                    .font(.caption)
                    .fontWeight(
                        .semibold
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(
                cornerRadius: 8
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemBackground
                )
            )
        )
    }

    private func settingCard<
        Content: View
    >(
        title: String,
        systemImage: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(
                systemName:
                    systemImage
            )
            .font(.title3)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                content()
            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 8
            )
            .fill(
                Color(
                    uiColor:
                        .tertiarySystemBackground
                )
            )
        )
    }

    private func infoValue(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            Text(value)
                .font(.headline)
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 8
            )
            .fill(
                Color(
                    uiColor:
                        .tertiarySystemBackground
                )
            )
        )
    }

    private func layerBinding(
        _ layer:
            TechnicalDrawingLayerV023
    ) -> Binding<Bool> {
        Binding(
            get: {
                visibleLayers.contains(
                    layer
                )
            },
            set: {
                isVisible in

                if isVisible {
                    visibleLayers.insert(
                        layer
                    )
                } else {
                    visibleLayers.remove(
                        layer
                    )
                }
            }
        )
    }
}

private enum SettingsTabV023:
    String,
    CaseIterable,
    Identifiable
{
    case sheet
    case layers
    case information

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sheet:
            return "Arkusz"
        case .layers:
            return "Warstwy"
        case .information:
            return "Informacje"
        }
    }

    var systemImage: String {
        switch self {
        case .sheet:
            return "doc"
        case .layers:
            return "square.3.layers.3d"
        case .information:
            return "info.circle"
        }
    }
}

enum DrawingScaleV023:
    String,
    CaseIterable,
    Identifiable
{
    case automatic
    case oneToTen
    case oneToTwenty
    case oneToTwentyFive
    case oneToFifty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .oneToTen:
            return "1:10"
        case .oneToTwenty:
            return "1:20"
        case .oneToTwentyFive:
            return "1:25"
        case .oneToFifty:
            return "1:50"
        }
    }

    var factor: CGFloat? {
        switch self {
        case .automatic:
            return nil
        case .oneToTen:
            return 0.10
        case .oneToTwenty:
            return 0.05
        case .oneToTwentyFive:
            return 0.04
        case .oneToFifty:
            return 0.02
        }
    }
}

enum DrawingSheetFormatV023:
    String,
    CaseIterable,
    Identifiable
{
    case screen
    case a4Landscape
    case a3Landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screen:
            return "Ekran"
        case .a4Landscape:
            return "A4 poziomo"
        case .a3Landscape:
            return "A3 poziomo"
        }
    }

    var size: CGSize {
        switch self {
        case .screen:
            return CGSize(
                width: 1180,
                height: 760
            )
        case .a4Landscape:
            return CGSize(
                width: 1120,
                height: 792
            )
        case .a3Landscape:
            return CGSize(
                width: 1584,
                height: 1120
            )
        }
    }
}
