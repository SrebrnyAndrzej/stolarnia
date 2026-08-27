import DomainCore
import SwiftUI

struct ElewacjaScianyCanvasView: View {
    let room: RoomDefinition
    let wall: WallSegment
    let assemblies: [FurnitureAssembly]
    let numberedItems: [FurnitureCanvasItemV016]
    let runs: [KitchenRunV015]
    let availableDirections: Set<KitchenAddDirectionV015>
    let cornerDefinitions:
        [CornerCabinetDefinitionV025]
    let globalneMaterialy: GlobalneMaterialyPomieszczenia
    let poziomWymiarowania: PoziomWymiarowania2D
    /// Przekazywany z MeblePomieszczeniaViewModel.renderRevision.
    /// Zmiana wartości wyzwala odświeżenie cachedFurniture i cachedLabelMap.
    let renderRevision: Int
    @Binding var selectedFurnitureID: FurnitureAssemblyID?
    let zaznaczoneFurnitureIDsV066: Set<FurnitureAssemblyID>
    let trybWielokrotnegoZaznaczaniaV066: Bool
    let onToggleFurnitureSelectionV066: ((FurnitureAssemblyID) -> Void)?
    let onClearFurnitureSelectionV066: (() -> Void)?
    let onReplaceFurnitureSelectionV067:
        ((ZaznaczenieRamkaV067) -> Void)?
    let onAddDirection: (
        FurnitureAssemblyID,
        KitchenAddDirectionV015
    ) -> Void
    let collidingFurnitureIDs: Set<FurnitureAssemblyID>
    let onEditDimension: ((KontekstEdycjiWymiaru2D) -> Void)?
    let onMoveFurniture: ((KontekstPrzesunieciaModulu2D) -> Void)?

    // MARK: - Drag & selection ephemeral state

    @State private var draggedFurnitureID: FurnitureAssemblyID?
    @State private var furnitureDragTranslationX: CGFloat = 0
    @State private var furnitureDragTranslationY: CGFloat = 0
    @State private var highlightedSwapTargetID: FurnitureAssemblyID?
    @State private var aktywnePrzyciagniecie:
        PunktPrzyciagnieciaModulu2D?
    @State private var aktywnePrzyciagnieciePionowe:
        PunktPrzyciagnieciaPionowego2D?
    @State private var poczatekRamkiZaznaczeniaV067:
        CGPoint?
    @State private var ramkaZaznaczeniaV067:
        CGRect?

    // MARK: - Performance cache

    /// Geometria mebli przeliczona z MebelElewacjaScianyGeometry.furniture().
    /// Aktualizowana TYLKO gdy zmieni się renderRevision — nie na każdym
    /// evencie drag/selection, co eliminuje 60fps recompute.
    @State private var cachedFurniture: [MebelElewacjaScianyElement]

    /// Mapa numer-etykiety wyliczona raz per refresh.
    /// Poprzednio budowana N razy wewnątrz pętli drawFurniture.
    @State private var cachedLabelMap: [FurnitureAssemblyID: String]

    /// Otwory (okna, drzwi, wnęki) na ścianie. Obliczane raz per refresh —
    /// poprzednio wywoływane 2× per frame (drawOpenings + drawOpeningDimensions).
    @State private var cachedOpenings: [OtworElewacjaScianyElement]

    init(
        room: RoomDefinition,
        wall: WallSegment,
        assemblies: [FurnitureAssembly],
        numberedItems: [FurnitureCanvasItemV016],
        runs: [KitchenRunV015],
        availableDirections: Set<KitchenAddDirectionV015>,
        cornerDefinitions:
            [CornerCabinetDefinitionV025] = [],
        globalneMaterialy: GlobalneMaterialyPomieszczenia,
        poziomWymiarowania: PoziomWymiarowania2D,
        renderRevision: Int = 0,
        selectedFurnitureID: Binding<FurnitureAssemblyID?>,
        zaznaczoneFurnitureIDsV066: Set<FurnitureAssemblyID> = [],
        trybWielokrotnegoZaznaczaniaV066: Bool = false,
        onToggleFurnitureSelectionV066:
            ((FurnitureAssemblyID) -> Void)? = nil,
        onClearFurnitureSelectionV066: (() -> Void)? = nil,
        onReplaceFurnitureSelectionV067:
            ((ZaznaczenieRamkaV067) -> Void)? = nil,
        onAddDirection: @escaping (
            FurnitureAssemblyID,
            KitchenAddDirectionV015
        ) -> Void,
        collidingFurnitureIDs: Set<FurnitureAssemblyID> = [],
        onEditDimension: ((KontekstEdycjiWymiaru2D) -> Void)? = nil,
        onMoveFurniture: ((KontekstPrzesunieciaModulu2D) -> Void)? = nil
    ) {
        self.room = room
        self.wall = wall
        self.assemblies = assemblies
        self.numberedItems = numberedItems
        self.runs = runs
        self.availableDirections = availableDirections
        self.cornerDefinitions =
            cornerDefinitions
        self.globalneMaterialy = globalneMaterialy
        self.poziomWymiarowania = poziomWymiarowania
        self.renderRevision = renderRevision
        self._selectedFurnitureID = selectedFurnitureID
        self.collidingFurnitureIDs = collidingFurnitureIDs
        self.zaznaczoneFurnitureIDsV066 =
            zaznaczoneFurnitureIDsV066
        self.trybWielokrotnegoZaznaczaniaV066 =
            trybWielokrotnegoZaznaczaniaV066
        self.onToggleFurnitureSelectionV066 =
            onToggleFurnitureSelectionV066
        self.onClearFurnitureSelectionV066 =
            onClearFurnitureSelectionV066
        self.onReplaceFurnitureSelectionV067 =
            onReplaceFurnitureSelectionV067
        self.onAddDirection = onAddDirection
        self.onEditDimension = onEditDimension
        self.onMoveFurniture = onMoveFurniture

        // Inicjalizacja cache — obliczane raz przy tworzeniu widoku,
        // dalej aktualizowane wyłącznie przez onChange(of: renderRevision).
        let furniture = MebelElewacjaScianyGeometry.furniture(
            on: wall,
            room: room,
            assemblies: assemblies
        )
        _cachedFurniture = State(initialValue: furniture)
        _cachedLabelMap = State(
            initialValue: FurnitureCanvasNumberingV016.labelMap(
                from: numberedItems
            )
        )
        _cachedOpenings = State(
            initialValue: MebelElewacjaScianyGeometry.openings(
                on: wall,
                room: room
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let projection = projection(size: proxy.size)
            // PERF: używamy cachedFurniture zamiast przeliczać na każdym
            // evencie drag/tap. Cache jest aktualizowany tylko gdy zmieni się
            // renderRevision (zapis/edycja modułu), nie na 60fps podczas dragu.
            let furniture = cachedFurniture

            ZStack {
                Canvas { context, size in
                    draw(
                        context: context,
                        size: size,
                        projection: projection,
                        furniture: furniture
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            if let dimension =
                                dimensionEditContext(
                                    at: event.location,
                                    furniture: furniture,
                                    projection: projection
                                ) {
                                onEditDimension?(dimension)
                                return
                            }

                            let tappedID = furnitureID(
                                at: event.location,
                                furniture: furniture,
                                projection: projection
                            )
                            if let tappedID {
                                if trybWielokrotnegoZaznaczaniaV066,
                                   let onToggleFurnitureSelectionV066 {
                                    onToggleFurnitureSelectionV066(
                                        tappedID
                                    )
                                } else {
                                    selectedFurnitureID = tappedID
                                }
                            } else if trybWielokrotnegoZaznaczaniaV066 {
                                onClearFurnitureSelectionV066?()
                            } else {
                                selectedFurnitureID = nil
                            }
                        }
                )
                .simultaneousGesture(
                    furnitureMoveGesture(
                        furniture: furniture,
                        projection: projection
                    ),
                    including:
                        onMoveFurniture == nil
                        ? .none
                        : .all
                )
                .simultaneousGesture(
                    selectionMarqueeGestureV067(
                        furniture: furniture,
                        projection: projection
                    ),
                    including:
                        trybWielokrotnegoZaznaczaniaV066
                        && onReplaceFurnitureSelectionV067 != nil
                        ? .all
                        : .none
                )

                ramkaZaznaczeniaOverlayV067

                cornerProductionOverlayV086(
                    furniture: furniture,
                    projection: projection
                )

                if draggedFurnitureID == nil,
                   ramkaZaznaczeniaV067 == nil,
                   let selectedFurnitureID,
                   let selected = furniture.first(where: {
                       $0.id == selectedFurnitureID
                   }) {
                    directionalButtons(
                        for: selected,
                        projection: projection,
                        canvasSize: proxy.size
                    )
                }
            }
        }
        .background(StolarniaPalette.drawingDesk)
        .environment(\.colorScheme, .light)
        .onChange(of: renderRevision) { _, _ in
            refreshCache()
        }
    }

    // MARK: - Cache refresh

    private func refreshCache() {
        cachedFurniture = MebelElewacjaScianyGeometry.furniture(
            on: wall,
            room: room,
            assemblies: assemblies
        )
        cachedLabelMap = FurnitureCanvasNumberingV016.labelMap(
            from: numberedItems
        )
        cachedOpenings = MebelElewacjaScianyGeometry.openings(
            on: wall,
            room: room
        )
    }

    private func selectionMarqueeGestureV067(
        furniture: [MebelElewacjaScianyElement],
        projection: ElewacjaScianyProjection
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 6,
            coordinateSpace: .local
        )
        .onChanged { value in
            if poczatekRamkiZaznaczeniaV067 == nil {
                guard furnitureID(
                    at: value.startLocation,
                    furniture: furniture,
                    projection: projection
                ) == nil else {
                    return
                }
                poczatekRamkiZaznaczeniaV067 =
                    value.startLocation
            }

            guard let start =
                poczatekRamkiZaznaczeniaV067 else {
                return
            }

            ramkaZaznaczeniaV067 =
                znormalizowanaRamkaV067(
                    od: start,
                    do: value.location
                )
        }
        .onEnded { _ in
            defer {
                poczatekRamkiZaznaczeniaV067 = nil
                ramkaZaznaczeniaV067 = nil
            }

            guard let start =
                    poczatekRamkiZaznaczeniaV067,
                  let rect = ramkaZaznaczeniaV067,
                  rect.width >= 6,
                  rect.height >= 6 else {
                return
            }

            onReplaceFurnitureSelectionV067?(
                zaznaczenieRamkaV067(
                    rect: rect,
                    start: start,
                    furniture: furniture,
                    projection: projection
                )
            )
        }
    }

    private func znormalizowanaRamkaV067(
        od start: CGPoint,
        do end: CGPoint
    ) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func zaznaczenieRamkaV067(
        rect: CGRect,
        start: CGPoint,
        furniture: [MebelElewacjaScianyElement],
        projection: ElewacjaScianyProjection
    ) -> ZaznaczenieRamkaV067 {
        let selected = furniture
            .compactMap {
                item
                -> (
                    id: FurnitureAssemblyID,
                    distance: CGFloat
                )? in
                let screenRect = projection.rect(item.rect)
                guard screenRect.intersects(rect) else {
                    return nil
                }

                let distance = hypot(
                    screenRect.midX - start.x,
                    screenRect.midY - start.y
                )
                return (item.id, distance)
            }
            .sorted { lhs, rhs in
                if abs(lhs.distance - rhs.distance) > 0.1 {
                    return lhs.distance < rhs.distance
                }
                return lhs.id.description < rhs.id.description
            }

        return ZaznaczenieRamkaV067(
            ids: Set(selected.map(\.id)),
            preferowaneGlowneID: selected.first?.id
        )
    }

    @ViewBuilder
    private var ramkaZaznaczeniaOverlayV067: some View {
        if let rect = ramkaZaznaczeniaV067 {
            Canvas { context, _ in
                let rounded = Path(
                    roundedRect: rect,
                    cornerRadius: 4
                )
                context.fill(
                    rounded,
                    with: .color(
                        Color.accentColor.opacity(0.10)
                    )
                )
                context.stroke(
                    rounded,
                    with: .color(Color.accentColor),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [6, 4]
                    )
                )

                let label = "Zaznaczenie"
                let labelRect = CGRect(
                    x: rect.minX,
                    y: max(4, rect.minY - 26),
                    width: 92,
                    height: 22
                )
                context.fill(
                    Path(
                        roundedRect: labelRect,
                        cornerRadius: 11
                    ),
                    with: .color(
                        StolarniaPalette.drawingLabelFill
                    )
                )
                context.stroke(
                    Path(
                        roundedRect: labelRect,
                        cornerRadius: 11
                    ),
                    with: .color(
                        Color.accentColor.opacity(0.72)
                    ),
                    lineWidth: 1
                )
                context.draw(
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.accentColor),
                    at: CGPoint(
                        x: labelRect.midX,
                        y: labelRect.midY
                    ),
                    anchor: .center
                )
            }
            .allowsHitTesting(false)
        }
    }

    private struct CornerProductionOverlayItemV086:
        Identifiable
    {
        let id:
            FurnitureAssemblyID
        let rect:
            CGRect
        let definition:
            CornerCabinetDefinitionV025
    }

    private func cornerProductionOverlayItemsV086(
        furniture:
            [MebelElewacjaScianyElement],
        projection:
            ElewacjaScianyProjection
    ) -> [CornerProductionOverlayItemV086] {
        furniture.compactMap { item in
            guard let definition =
                cornerDefinitions.first(
                    where: {
                        $0.assemblyID == item.id
                    }
                )
            else {
                return nil
            }

            return CornerProductionOverlayItemV086(
                id: item.id,
                rect:
                    projection.rect(
                        item.rect
                    ),
                definition:
                    definition
            )
        }
    }

    @ViewBuilder
    private func cornerProductionOverlayV086(
        furniture:
            [MebelElewacjaScianyElement],
        projection:
            ElewacjaScianyProjection
    ) -> some View {
        ForEach(
            cornerProductionOverlayItemsV086(
                furniture: furniture,
                projection: projection
            )
        ) { item in
            let definition =
                item.definition
            let rule =
                CornerCabinetRuleBookV086
                    .technologyRule(
                        for:
                            definition
                                .effectiveAccessTechnology
                    )
            let fillerW =
                min(
                    max(
                        item.rect.width * 0.10,
                        5
                    ),
                    22
                )
            let fillerX =
                definition.handedness == .left
                ? item.rect.minX + fillerW / 2
                : item.rect.maxX - fillerW / 2
            let deadW =
                definition.kind == .blindCorner
                || definition.kind == .halfBlind
                ? min(
                    item.rect.width * 0.28,
                    max(
                        item.rect.width
                        * CGFloat(
                            definition.deadSpaceMM
                            / max(
                                definition.leftArmMM,
                                definition.rightArmMM,
                                1
                            )
                        ),
                        10
                    )
                )
                : 0
            let deadX =
                definition.handedness == .left
                ? item.rect.maxX - deadW / 2
                : item.rect.minX + deadW / 2

            ZStack {
                if definition.effectiveFillerKind != .none {
                    Rectangle()
                        .fill(
                            Color.black
                                .opacity(0.16)
                        )
                        .frame(
                            width: fillerW,
                            height:
                                max(
                                    item.rect.height,
                                    1
                                )
                        )
                        .position(
                            x: fillerX,
                            y: item.rect.midY
                        )
                }

                if deadW > 0 {
                    Rectangle()
                        .fill(
                            Color.black
                                .opacity(0.10)
                        )
                        .overlay {
                            Rectangle()
                                .stroke(
                                    Color.black
                                        .opacity(0.32),
                                    style:
                                        StrokeStyle(
                                            lineWidth: 1,
                                            dash: [4, 3]
                                        )
                                )
                        }
                        .frame(
                            width: deadW,
                            height:
                                max(
                                    item.rect.height,
                                    1
                                )
                        )
                        .position(
                            x: deadX,
                            y: item.rect.midY
                        )
                }

                VStack(spacing: 2) {
                    Text(
                        definition
                            .effectiveAccessTechnology
                            .title
                    )
                    .font(
                        .caption2
                            .weight(.bold)
                    )
                    Text(
                        definition
                            .effectiveFillerKind
                            .title
                    )
                    .font(.caption2)
                    if rule.requiresManufacturerTemplate {
                        Text("wiercenia wg szablonu")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    Color.white.opacity(0.86),
                    in:
                        RoundedRectangle(
                            cornerRadius: 5
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            Color.black.opacity(0.22),
                            lineWidth: 0.7
                        )
                }
                .frame(
                    maxWidth:
                        max(
                            item.rect.width - 8,
                            1
                        )
                )
                .position(
                    x: item.rect.midX,
                    y:
                        max(
                            item.rect.minY - 20,
                            18
                        )
                )
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func directionalButtons(
        for selected: MebelElewacjaScianyElement,
        projection: ElewacjaScianyProjection,
        canvasSize: CGSize
    ) -> some View {
        let rect = projection.rect(selected.rect)

        ForEach(
            KitchenAddDirectionV015.allCases,
            id: \.self
        ) { direction in
            if availableDirections.contains(direction) {
                Button {
                    onAddDirection(selected.id, direction)
                } label: {
                    Image(systemName: direction.systemImage)
                }
                .buttonStyle(
                    StolarniaPrimaryIconButtonStyle(
                        size: 40
                    )
                )
                .accessibilityLabel(direction.accessibilityTitle)
                .position(
                    buttonPosition(
                        direction: direction,
                        furnitureRect: rect,
                        canvasSize: canvasSize
                    )
                )
            }
        }
    }

    private func buttonPosition(
        direction: KitchenAddDirectionV015,
        furnitureRect: CGRect,
        canvasSize: CGSize
    ) -> CGPoint {
        let proposed: CGPoint

        switch direction {
        case .left:
            proposed = CGPoint(
                x: furnitureRect.minX - 22,
                y: furnitureRect.midY
            )
        case .right:
            proposed = CGPoint(
                x: furnitureRect.maxX + 22,
                y: furnitureRect.midY
            )
        case .above:
            proposed = CGPoint(
                x: furnitureRect.midX,
                y: furnitureRect.minY - 22
            )
        }

        return CGPoint(
            x: min(
                max(proposed.x, 22),
                max(canvasSize.width - 22, 22)
            ),
            y: min(
                max(proposed.y, 22),
                max(canvasSize.height - 22, 22)
            )
        )
    }

    private func furnitureMoveGesture(
        furniture: [MebelElewacjaScianyElement],
        projection: ElewacjaScianyProjection
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 8,
            coordinateSpace: .local
        )
        .onChanged { value in
            if draggedFurnitureID == nil {
                guard let furnitureID = furnitureID(
                    at: value.startLocation,
                    furniture: furniture,
                    projection: projection
                ) else {
                    return
                }

                draggedFurnitureID = furnitureID
                selectedFurnitureID = furnitureID
            }

            guard let draggedFurnitureID else {
                return
            }

            guard let movement = movementContext(
                for: draggedFurnitureID,
                at: value.location,
                projection: projection
            ) else {
                furnitureDragTranslationX = 0
                furnitureDragTranslationY = 0
                highlightedSwapTargetID = nil
                aktywnePrzyciagniecie = nil
                aktywnePrzyciagnieciePionowe = nil
                return
            }

            furnitureDragTranslationX =
                translationForMovement(
                    movement,
                    furnitureID: draggedFurnitureID,
                    projection: projection
                )
            furnitureDragTranslationY =
                verticalTranslationForMovement(
                    movement,
                    furnitureID: draggedFurnitureID,
                    projection: projection
                )
            highlightedSwapTargetID =
                movement.celZamianyID
            aktywnePrzyciagniecie =
                movement.przyciagniecie
            aktywnePrzyciagnieciePionowe =
                movement.przyciagnieciePionowe
        }
        .onEnded { value in
            defer {
                draggedFurnitureID = nil
                furnitureDragTranslationX = 0
                furnitureDragTranslationY = 0
                highlightedSwapTargetID = nil
                aktywnePrzyciagniecie = nil
                aktywnePrzyciagnieciePionowe = nil
            }

            guard let draggedFurnitureID,
                  let movement = movementContext(
                      for: draggedFurnitureID,
                      at: value.location,
                      projection: projection
                  ) else {
                return
            }

            onMoveFurniture?(movement)
        }
    }

    private func translationForMovement(
        _ movement: KontekstPrzesunieciaModulu2D,
        furnitureID: FurnitureAssemblyID,
        projection: ElewacjaScianyProjection
    ) -> CGFloat {
        guard let assembly = assemblies.first(where: {
            $0.id == furnitureID
        }),
        let currentOffset =
            assembly.placement?.offsetAlongWall else {
            return 0
        }

        return projection.x(
            movement.proponowaneOdsuniecie
        ) - projection.x(currentOffset)
    }

    private func verticalTranslationForMovement(
        _ movement: KontekstPrzesunieciaModulu2D,
        furnitureID: FurnitureAssemblyID,
        projection: ElewacjaScianyProjection
    ) -> CGFloat {
        guard let assembly = assemblies.first(where: {
            $0.id == furnitureID
        }),
        let placement = assembly.placement,
        let proposedBottom =
            movement.proponowaneOdsuniecieOdDolu else {
            return 0
        }

        let currentTop =
            placement.bottomOffset + assembly.size.height
        let proposedTop =
            proposedBottom + assembly.size.height

        return projection.y(proposedTop)
            - projection.y(currentTop)
    }

    /// Wspólne z planem 2D — patrz `PrzyciaganieSasiadow2DV0102`.
    private func idsWykluczoneZeSnapuV066(
        sourceID: FurnitureAssemblyID
    ) -> Set<FurnitureAssemblyID> {
        PrzyciaganieSasiadow2DV0102.idsWykluczone(
            sourceID: sourceID,
            zaznaczone: zaznaczoneFurnitureIDsV066
        )
    }

    private func verticalSnapNeighbors(
        for assembly: FurnitureAssembly,
        placement: FurniturePlacement
    ) -> [ZakresPionowyModuluPrzyciagania2D] {
        let sourceLayer = MebelPlan2DGeometry.layer(
            for: assembly
        )
        let excludedIDs =
            idsWykluczoneZeSnapuV066(
                sourceID: assembly.id
            )
        let sourceStart =
            placement.offsetAlongWall.rawValue
        let sourceEnd =
            sourceStart + assembly.size.width.rawValue

        return assemblies.compactMap { candidate in
            guard !excludedIDs.contains(candidate.id),
                  let candidatePlacement =
                    candidate.placement,
                  candidatePlacement.wallID
                    == placement.wallID,
                  MebelPlan2DGeometry.layer(
                      for: candidate
                  ) == sourceLayer,
                  abs(
                      candidatePlacement
                          .offsetFromWall
                          .rawValue
                      - placement
                          .offsetFromWall
                          .rawValue
                  ) <= 1 else {
                return nil
            }

            let candidateStart =
                candidatePlacement.offsetAlongWall.rawValue
            let candidateEnd =
                candidateStart + candidate.size.width.rawValue
            let horizontalGap = max(
                max(
                    sourceStart - candidateEnd,
                    candidateStart - sourceEnd
                ),
                0
            )

            guard horizontalGap <= 80 else {
                return nil
            }

            return ZakresPionowyModuluPrzyciagania2D(
                furnitureID: candidate.id,
                bottom: candidatePlacement.bottomOffset,
                top:
                    candidatePlacement.bottomOffset
                    + candidate.size.height
            )
        }
    }

    /// Sąsiedzi do przyciągania — reguła wspólna z drugim płótnem.
    ///
    /// Ta funkcja miała identyczne ciało w planie 2D i w elewacji.
    /// Logika mieszka teraz w `PrzyciaganieSasiadow2DV0102`, żeby
    /// poprawka przyciągania działała w obu widokach naraz.
    private func snapNeighbors(
        for assembly: FurnitureAssembly,
        placement: FurniturePlacement
    ) -> [ZakresModuluPrzyciagania2D] {
        PrzyciaganieSasiadow2DV0102.sasiedzi(
            dla: assembly,
            placement: placement,
            wsrod: assemblies,
            zaznaczone: zaznaczoneFurnitureIDsV066
        )
    }

    private func movementContext(
        for furnitureID: FurnitureAssemblyID,
        at location: CGPoint,
        projection: ElewacjaScianyProjection
    ) -> KontekstPrzesunieciaModulu2D? {
        guard let assembly = assemblies.first(where: {
            $0.id == furnitureID
        }),
        let placement = assembly.placement,
        let wallID = placement.wallID,
        wallID == wall.id else {
            return nil
        }

        let wallStartX = projection.x(.zero)
        let wallEndX = projection.x(
            projection.wallWidth
        )
        let screenWidth = abs(wallEndX - wallStartX)

        guard screenWidth > 0.001 else {
            return nil
        }

        let dropAlongWall =
            min(
                max(
                    projection
                        .millimetersX(location.x),
                    0
                ),
                projection.wallWidth.rawValue
            )
        let maximumOffset = max(
            projection.wallWidth.rawValue
                - assembly.size.width.rawValue,
            0
        )
        let centeredOffset =
            dropAlongWall
            - assembly.size.width.rawValue / 2
        let rawOffset = Millimeters(
            min(max(centeredOffset, 0), maximumOffset)
        )

        let millimetersPerPoint =
            projection.wallWidth.rawValue
            / Double(screenWidth)
        let snapThreshold = Millimeters(
            min(
                max(
                    millimetersPerPoint
                    * PrzyciaganieModulow2D
                        .domyslnyProgEkranowy,
                    5
                ),
                80
            )
        )
        let neighbors = snapNeighbors(
            for: assembly,
            placement: placement
        )
        let snap = PrzyciaganieModulow2D
            .najlepszyPunkt(
                suroweOdsuniecie: rawOffset,
                szerokoscModulu: assembly.size.width,
                dlugoscSciany:
                    projection.wallWidth,
                sasiedzi: neighbors,
                prog: snapThreshold
            )

        let gridOffset = PrzyciaganieModulow2D
            .odsuniecieDoSiatki(rawOffset)
        let proposedOffset = snap?
            .proponowaneOdsuniecie
            ?? Millimeters(
                min(
                    max(gridOffset.rawValue, 0),
                    maximumOffset
                )
            )

        let swapTarget: FurnitureAssembly? =
            snap == nil
            ? assemblies.first { candidate in
                guard candidate.id != assembly.id,
                      let candidatePlacement =
                        candidate.placement,
                      candidatePlacement.wallID == wallID,
                      neighbors.contains(where: {
                          $0.furnitureID == candidate.id
                      }) else {
                    return false
                }

                let start =
                    candidatePlacement
                        .offsetAlongWall
                        .rawValue
                let width =
                    candidate.size.width.rawValue
                let end = start + width
                let inset = min(
                    max(width * 0.22, 35),
                    width * 0.42
                )

                return dropAlongWall >= start + inset
                    && dropAlongWall <= end - inset
            }
            : nil

        let rawBottom = Millimeters(
            projection.millimetersY(location.y)
                - assembly.size.height.rawValue / 2
        )
        let maximumBottom = max(
            projection.wallHeight.rawValue
                - assembly.size.height.rawValue,
            0
        )
        let clampedBottom = Millimeters(
            min(
                max(rawBottom.rawValue, 0),
                maximumBottom
            )
        )
        let verticalSnap =
            PrzyciaganieModulow2D
                .najlepszyPunktPionowy(
                    suroweOdsuniecieOdDolu:
                        clampedBottom,
                    wysokoscModulu:
                        assembly.size.height,
                    wysokoscSciany:
                        projection.wallHeight,
                    sasiedzi:
                        verticalSnapNeighbors(
                            for: assembly,
                            placement: placement
                        ),
                    prog: snapThreshold
                )
        let proposedBottom =
            verticalSnap?
                .proponowaneOdsuniecieOdDolu
            ?? PrzyciaganieModulow2D
                .odsuniecieDoSiatki(
                    clampedBottom,
                    krok: 10
                )

        return KontekstPrzesunieciaModulu2D(
            furnitureID: assembly.id,
            wallID: wallID,
            proponowaneOdsuniecie: proposedOffset,
            celZamianyID: swapTarget?.id,
            przyciagniecie: snap,
            proponowaneOdsuniecieOdDolu:
                Millimeters(
                    min(
                        max(
                            proposedBottom.rawValue,
                            0
                        ),
                        maximumBottom
                    )
                ),
            przyciagnieciePionowe: verticalSnap
        )
    }

    private func projection(
        size: CGSize
    ) -> ElewacjaScianyProjection {
        let wallWidth = MebelElewacjaScianyGeometry.wallLength(
            wall: wall,
            room: room
        ) ?? 1
        let wallHeight = MebelElewacjaScianyGeometry.wallMaximumHeight(
            wall: wall,
            room: room
        )

        return ElewacjaScianyProjection(
            wallWidth: wallWidth,
            wallHeight: wallHeight,
            size: size,
            isMirrored:
                MebelElewacjaScianyGeometry
                    .shouldMirrorElevation(
                        wall:
                            wall,
                        room:
                            room
                    )
        )
    }

    private func draw(
        context: GraphicsContext,
        size: CGSize,
        projection: ElewacjaScianyProjection,
        furniture: [MebelElewacjaScianyElement]
    ) {
        drawWall(
            context: context,
            projection: projection
        )
        // PERF: przekazujemy cachedOpenings zamiast wywoływać
        // MebelElewacjaScianyGeometry.openings() 2× per frame.
        drawOpenings(
            openings: cachedOpenings,
            context: context,
            projection: projection
        )

        // PERF: używamy cachedLabelMap zamiast budować słownik per-item.
        let labelMap = cachedLabelMap

        for item in furniture {
            let isDraggedSource =
                item.id == draggedFurnitureID
            let isGroupDrag =
                draggedFurnitureID != nil
                && zaznaczoneFurnitureIDsV066.count > 1
                && zaznaczoneFurnitureIDsV066.contains(
                    item.id
                )
                && draggedFurnitureID.map {
                    zaznaczoneFurnitureIDsV066.contains($0)
                } == true
            let isDragged = isDraggedSource || isGroupDrag

            if isDragged {
                drawOriginalFurnitureOutline(
                    item,
                    context: context,
                    projection: projection
                )
            }

            drawFurniture(
                item,
                label: labelMap[item.id] ?? "M?",
                context: context,
                projection: projection,
                isSelected:
                    item.id == selectedFurnitureID
                    || zaznaczoneFurnitureIDsV066.contains(
                        item.id
                    ),
                isPrimarySelection:
                    item.id == selectedFurnitureID,
                isSwapTarget:
                    item.id == highlightedSwapTargetID,
                isColliding:
                    collidingFurnitureIDs.contains(item.id),
                translationX:
                    isDragged
                    ? furnitureDragTranslationX
                    : 0,
                translationY:
                    isDragged
                    ? furnitureDragTranslationY
                    : 0
            )
        }

        drawActiveSnapGuide(
            context: context,
            projection: projection
        )
        drawActiveVerticalSnapGuide(
            context: context,
            projection: projection
        )

        drawDetectedRuns(
            context: context,
            projection: projection
        )

        guard poziomWymiarowania != .ukryte else {
            return
        }

        drawFurnitureDimensions(
            furniture: furniture,
            context: context,
            projection: projection
        )

        if poziomWymiarowania == .szczegolowe {
            drawSelectedRunDimensionChain(
                furniture: furniture,
                context: context,
                projection: projection
            )
        }

        if poziomWymiarowania == .szczegolowe {
            drawOpeningDimensions(
                openings: cachedOpenings,
                context: context,
                projection: projection
            )
        }

        drawWallDimensions(
            context: context,
            projection: projection
        )
    }

    private func elevationPathV069(
        _ points:
            [PunktElewacjiScianyV069],
        projection:
            ElewacjaScianyProjection
    ) -> Path {
        var path =
            Path()

        guard let first =
                points.first
        else {
            return path
        }

        path.move(
            to:
                projection.point(
                    x: first.x,
                    y: first.y
                )
        )

        for point in
            points.dropFirst() {
            path.addLine(
                to:
                    projection.point(
                        x: point.x,
                        y: point.y
                    )
            )
        }

        path.closeSubpath()
        return path
    }

    private func furniturePathV069(
        _ item:
            MebelElewacjaScianyElement,
        projection:
            ElewacjaScianyProjection
    ) -> Path {
        guard let contour =
                item.konturV069,
              contour.count >= 3
        else {
            return Path(
                projection.rect(
                    item.rect
                )
            )
        }

        return elevationPathV069(
            contour,
            projection:
                projection
        )
    }

    private func drawWall(
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        // Always draw the wall as a rectangle up to the maximum height so the
        // cabinet run is visible. The slope profile is drawn as an overlay line,
        // not as the wall background shape.
        let maxHeight = max(wall.startHeight, wall.endHeight)
        let rectContour = [
            PunktElewacjiScianyV069(x: .zero, y: .zero),
            PunktElewacjiScianyV069(x: projection.wallWidth, y: .zero),
            PunktElewacjiScianyV069(x: projection.wallWidth, y: maxHeight),
            PunktElewacjiScianyV069(x: .zero, y: maxHeight),
        ]

        let path =
            elevationPathV069(
                rectContour,
                projection:
                    projection
            )

        context.fill(
            path,
            with: .color(
                Color(
                    red: 0.965,
                    green: 0.956,
                    blue: 0.925
                )
            )
        )
        context.stroke(
            path,
            with:
                .color(
                    StolarniaPalette
                        .drawingInk
                        .opacity(0.82)
                ),
            lineWidth: 2
        )

        if let profile =
                MebelElewacjaScianyGeometry
                    .slopeProfile(
                        on: wall,
                        room: room
                    ) {
            let points =
                SilnikSkosuPomieszczeniaV069
                    .punktyProfilu(
                        profile
                    )

            if let first =
                    points.first {
                var slopePath =
                    Path()

                slopePath.move(
                    to:
                        projection.point(
                            x:
                                Millimeters(
                                    first.xMM
                                ),
                            y:
                                Millimeters(
                                    first
                                        .wysokoscMM
                                )
                        )
                )

                for point in
                    points.dropFirst() {
                    slopePath.addLine(
                        to:
                            projection.point(
                                x:
                                    Millimeters(
                                        point.xMM
                                    ),
                                y:
                                    Millimeters(
                                        point
                                            .wysokoscMM
                                    )
                            )
                    )
                }

                context.stroke(
                    slopePath,
                    with:
                        .color(
                            .purple
                        ),
                    style:
                        StrokeStyle(
                            lineWidth: 2.5,
                            dash: [8, 4]
                        )
                )

                // Per-segment angle labels and arc annotations.
                let segmenty =
                    MebelElewacjaScianyGeometry
                        .segmentySkosu(
                            profil: profile
                        )

                for seg in segmenty {
                    let lowScreen =
                        projection.point(
                            x:
                                Millimeters(
                                    seg.lowPunkt
                                        .xMM
                                ),
                            y:
                                Millimeters(
                                    seg.lowPunkt
                                        .wysokoscMM
                                )
                        )
                    let highScreen =
                        projection.point(
                            x:
                                Millimeters(
                                    seg.highPunkt
                                        .xMM
                                ),
                            y:
                                Millimeters(
                                    seg.highPunkt
                                        .wysokoscMM
                                )
                        )

                    // Arc at the low vertex between
                    // the horizontal floor direction
                    // and the slope line.
                    let slopeAngle =
                        atan2(
                            highScreen.y
                                - lowScreen.y,
                            highScreen.x
                                - lowScreen.x
                        )
                    let goesRight =
                        highScreen.x
                            >= lowScreen.x
                    let floorAngle:
                        Double =
                            goesRight ? 0 : .pi
                    // clockwise: true when slope goes
                    // left (arc opens toward the room
                    // interior on both slope sides).
                    let arcRadius: CGFloat = 28
                    var arcPath = Path()
                    arcPath.addArc(
                        center: lowScreen,
                        radius: arcRadius,
                        startAngle:
                            Angle(
                                radians:
                                    floorAngle
                            ),
                        endAngle:
                            Angle(
                                radians:
                                    Double(
                                        slopeAngle
                                    )
                            ),
                        clockwise: !goesRight
                    )
                    context.stroke(
                        arcPath,
                        with: .color(
                            .purple
                                .opacity(0.75)
                        ),
                        style: StrokeStyle(
                            lineWidth: 1.5
                        )
                    )

                    // Angle label placed along the
                    // bisector of the arc, offset a
                    // bit further than the arc radius.
                    let bisectorAngle =
                        (
                            floorAngle
                            + Double(slopeAngle)
                        ) / 2
                    let labelOffsetR:
                        CGFloat = arcRadius + 18
                    let labelCenter =
                        CGPoint(
                            x:
                                lowScreen.x
                                + labelOffsetR
                                * cos(bisectorAngle),
                            y:
                                lowScreen.y
                                + labelOffsetR
                                * sin(bisectorAngle)
                        )

                    let angleLabel =
                        seg.katStopnie
                            .formatted(
                                .number
                                    .precision(
                                        .fractionLength(
                                            1
                                        )
                                    )
                            )
                        + "°"

                    Wymiarowanie2DRenderer
                        .drawLabel(
                            in: context,
                            text: angleLabel,
                            at: labelCenter,
                            emphasis: .pomocnicze
                        )
                }

                // Overall label at midpoint of slope.
                if let middle =
                        points.count > 0
                        ? points[
                            points.count / 2
                          ]
                        : nil {
                    context.draw(
                        Text("SKOS")
                            .font(
                                .caption2
                                    .bold()
                            )
                            .foregroundColor(
                                .purple
                            ),
                        at:
                            projection.point(
                                x:
                                    Millimeters(
                                        middle.xMM
                                    ),
                                y:
                                    Millimeters(
                                        middle
                                            .wysokoscMM
                                    )
                            ),
                        anchor:
                            .bottom
                    )
                }
            }
        }

        var floor = Path()
        floor.move(
            to: projection.point(
                x: .zero,
                y: .zero
            )
        )
        floor.addLine(
            to: projection.point(
                x:
                    projection
                        .wallWidth,
                y: .zero
            )
        )
        context.stroke(
            floor,
            with: .color(StolarniaPalette.drawingInk),
            lineWidth: 3
        )
    }

    private func drawOpenings(
        openings: [OtworElewacjaScianyElement],
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        for opening in openings {
            let rect = projection.rect(opening.rect)
            let style = openingStyle(opening.kind)

            context.fill(
                Path(rect),
                with: .color(
                    style.color.opacity(style.fillOpacity)
                )
            )
            context.stroke(
                Path(rect),
                with: .color(style.color),
                style: StrokeStyle(
                    lineWidth: style.lineWidth,
                    dash: style.dash
                )
            )

            context.draw(
                Text(opening.symbol)
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundColor(style.color),
                at: CGPoint(
                    x: rect.midX,
                    y: rect.midY
                ),
                anchor: .center
            )
        }
    }

    private func openingStyle(
        _ kind: OtworElewacjaScianyElement.Kind
    ) -> ElevationOpeningVisualStyleV016 {
        switch kind {
        case .window:
            return ElevationOpeningVisualStyleV016(
                color: .blue,
                fillOpacity: 0.10,
                lineWidth: 1.5,
                dash: []
            )
        case .door:
            return ElevationOpeningVisualStyleV016(
                color: .brown,
                fillOpacity: 0.08,
                lineWidth: 1.5,
                dash: [6, 3]
            )
        case .recess:
            return ElevationOpeningVisualStyleV016(
                color: .purple,
                fillOpacity: 0.09,
                lineWidth: 1.5,
                dash: [5, 3]
            )
        case .bayOutward:
            return ElevationOpeningVisualStyleV016(
                color: .teal,
                fillOpacity: 0.08,
                lineWidth: 1.5,
                dash: []
            )
        case .bayInward:
            return ElevationOpeningVisualStyleV016(
                color: .red,
                fillOpacity: 0.08,
                lineWidth: 1.5,
                dash: []
            )
        }
    }

    private func drawOriginalFurnitureOutline(
        _ item: MebelElewacjaScianyElement,
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        let outline =
            furniturePathV069(
                item,
                projection:
                    projection
            )
        context.stroke(
            outline,
            with: .color(
                Color.accentColor.opacity(0.36)
            ),
            style: StrokeStyle(
                lineWidth: 2,
                dash: [6, 5]
            )
        )
    }

    private func drawFurniture(
        _ item: MebelElewacjaScianyElement,
        label: String,
        context: GraphicsContext,
        projection: ElewacjaScianyProjection,
        isSelected: Bool,
        isPrimarySelection: Bool,
        isSwapTarget: Bool,
        isColliding: Bool = false,
        translationX: CGFloat,
        translationY: CGFloat
    ) {
        var drawingContext = context
        drawingContext.translateBy(
            x: translationX,
            y: translationY
        )

        let furniturePath =
            furniturePathV069(
                item,
                projection:
                    projection
            )
        let fill: Color
        let stroke: Color

        if isColliding && !isSwapTarget {
            fill = Color.red.opacity(isSelected ? 0.25 : 0.18)
            stroke = Color.red
        } else if isSwapTarget {
            fill = Color.orange.opacity(0.22)
            stroke = Color.orange
        } else if isSelected {
            fill = Color(
                red: 0.72,
                green: 0.62,
                blue: 0.36
            )
            .opacity(0.25)
            stroke = Color(
                red: 0.72,
                green: 0.62,
                blue: 0.36
            )
        } else if item.isFinishing {
            fill = Color.purple.opacity(0.16)
            stroke = Color.purple.opacity(0.78)
        } else {
            fill = Color(
                stolarniaHEX:
                    globalneMaterialy.front.kolorHEX
            )
            .opacity(0.34)
            stroke = Color(
                stolarniaHEX:
                    globalneMaterialy.korpus.kolorHEX
            )
        }

        drawingContext.fill(
            furniturePath,
            with: .color(fill)
        )
        drawingContext.stroke(
            furniturePath,
            with: .color(stroke),
            lineWidth:
                isSwapTarget
                ? 3.5
                : (
                    isPrimarySelection
                        ? 3
                        : (isSelected ? 2.2 : 1.5)
                )
        )

        var contentContextV069 =
            drawingContext
        contentContextV069.clip(
            to: furniturePath
        )

        for y in item.componentLinesY {
            var line = Path()
            line.move(
                to: projection.point(
                    x: item.rect.x,
                    y: y
                )
            )
            line.addLine(
                to: projection.point(
                    x: item.rect.maxX,
                    y: y
                )
            )
            contentContextV069.stroke(
                line,
                with: .color(stroke.opacity(0.62)),
                lineWidth: 0.8
            )
        }

        for x in item.componentLinesX {
            var line = Path()
            line.move(
                to: projection.point(
                    x: x,
                    y: item.rect.y
                )
            )
            line.addLine(
                to: projection.point(
                    x: x,
                    y: item.rect.maxY
                )
            )
            contentContextV069.stroke(
                line,
                with: .color(stroke.opacity(0.62)),
                lineWidth: 0.8
            )
        }

        for front in item.frontsV068 {
            drawFrontOpeningV068(
                front,
                context:
                    contentContextV069,
                projection:
                    projection,
                color:
                    stroke
            )
        }

        if item.jestScietySkosemV069,
           let topPoint =
                item.gornaKrawedzV069
                    .min(
                        by: {
                            $0.y < $1.y
                        }
                    ) {
            drawingContext.draw(
                Text(
                    "SKOS −"
                    + item
                        .rezerwaSkosuMMV069
                        .formatted(
                            .number.precision(
                                .fractionLength(
                                    0...1
                                )
                            )
                        )
                    + " mm"
                )
                .font(
                    .caption2
                        .bold()
                )
                .foregroundColor(
                    .purple
                ),
                at:
                    projection.point(
                        x:
                            topPoint.x,
                        y:
                            topPoint.y
                    ),
                anchor:
                    .bottom
            )
        }

        // label pochodzi z cachedLabelMap obliczonego w draw() — nie budujemy tu słownika.
        let visibleBoundsV069 =
            furniturePath.boundingRect
        let center = CGPoint(
            x:
                visibleBoundsV069.midX,
            y:
                visibleBoundsV069.midY
        )
        let badgeRect = CGRect(
            x: center.x - 21,
            y: center.y - 12,
            width: 42,
            height: 24
        )

        drawingContext.fill(
            Path(
                roundedRect: badgeRect,
                cornerRadius: 8
            ),
            with: .color(
                isSwapTarget
                    ? Color.orange
                    : (
                        isSelected
                            ? Color.accentColor
                            : StolarniaPalette.drawingLabelFill
                    )
            )
        )
        drawingContext.stroke(
            Path(
                roundedRect: badgeRect,
                cornerRadius: 8
            ),
            with: .color(
                isSwapTarget
                    ? Color.orange
                    : (
                        isSelected
                            ? Color.accentColor
                            : stroke
                    )
            ),
            lineWidth: 1
        )
        drawingContext.draw(
            Text(label)
                .font(.caption.monospaced().weight(.bold))
                .foregroundColor(
                    isSelected || isSwapTarget
                        ? Color.white
                        : stroke
                ),
            at: center,
            anchor: .center
        )
    }

    private func drawFrontOpeningV068(
        _ front:
            FrontElewacjiModuluV068,
        context:
            GraphicsContext,
        projection:
            ElewacjaScianyProjection,
        color: Color
    ) {
        let rect =
            projection.rect(
                front.rect
            )

        guard
            rect.width >= 8,
            rect.height >= 8
        else {
            return
        }

        context.stroke(
            Path(rect),
            with:
                .color(
                    color
                        .opacity(0.78)
                ),
            lineWidth: 1.1
        )

        let inset =
            max(
                min(
                    rect.width,
                    rect.height
                ) * 0.12,
                4
            )
        let symbolRect =
            rect.insetBy(
                dx: inset,
                dy: inset
            )

        guard
            symbolRect.width > 4,
            symbolRect.height > 4
        else {
            return
        }

        var symbol = Path()
        let center =
            CGPoint(
                x:
                    symbolRect.midX,
                y:
                    symbolRect.midY
            )

        switch front.otwarcie {
        case .lewy:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            symbolRect.midY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            symbolRect.maxY
                    )
            )

        case .prawy:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            symbolRect.midY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            symbolRect.maxY
                    )
            )

        case .doGory:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.maxY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x - 5,
                        y:
                            symbolRect.minY + 7
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x + 5,
                        y:
                            symbolRect.minY + 7
                    )
            )

        case .wDol:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.maxY
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.maxY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x - 5,
                        y:
                            symbolRect.maxY - 7
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            symbolRect.maxY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x + 5,
                        y:
                            symbolRect.maxY - 7
                    )
            )

        case .szuflada:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            center.y
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            center.y
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            center.y - 5
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            center.x,
                        y:
                            center.y + 5
                    )
            )

        case .przesuwny:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            center.y
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            center.y
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            center.y
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX + 6,
                        y:
                            center.y - 4
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            center.y
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX + 6,
                        y:
                            center.y + 4
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            center.y
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX - 6,
                        y:
                            center.y - 4
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            center.y
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX - 6,
                        y:
                            center.y + 4
                    )
            )

        case .staly:
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            symbolRect.maxY
                    )
            )
            symbol.move(
                to:
                    CGPoint(
                        x:
                            symbolRect.maxX,
                        y:
                            symbolRect.minY
                    )
            )
            symbol.addLine(
                to:
                    CGPoint(
                        x:
                            symbolRect.minX,
                        y:
                            symbolRect.maxY
                    )
            )
        }

        context.stroke(
            symbol,
            with:
                .color(
                    color
                        .opacity(0.82)
                ),
            style:
                StrokeStyle(
                    lineWidth: 1.15,
                    lineCap:
                        .round,
                    lineJoin:
                        .round
                )
        )
    }

    private func drawActiveSnapGuide(
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        guard draggedFurnitureID != nil,
              let snap = aktywnePrzyciagniecie else {
            return
        }

        let x = projection.x(
            snap.liniaProwadzaca
        )
        let maximumHeight =
            MebelElewacjaScianyGeometry
                .wallMaximumHeight(wall: wall)
        let top = projection.point(
            x: snap.liniaProwadzaca,
            y: maximumHeight
        )
        let bottom = projection.point(
            x: snap.liniaProwadzaca,
            y: .zero
        )

        var path = Path()
        path.move(to: top)
        path.addLine(to: bottom)

        context.stroke(
            path,
            with: .color(Color.accentColor),
            style: StrokeStyle(
                lineWidth: 2,
                dash: [5, 4]
            )
        )

        let labelPoint = CGPoint(
            x: x,
            y: max(top.y - 18, 18)
        )
        let label = snap.rodzaj.tytul
        let labelWidth = max(
            CGFloat(label.count) * 6.6 + 16,
            88
        )
        let labelRect = CGRect(
            x: labelPoint.x - labelWidth / 2,
            y: labelPoint.y - 11,
            width: labelWidth,
            height: 22
        )
        context.fill(
            Path(
                roundedRect: labelRect,
                cornerRadius: 11
            ),
            with: .color(
                StolarniaPalette.drawingLabelFill
            )
        )
        context.stroke(
            Path(
                roundedRect: labelRect,
                cornerRadius: 11
            ),
            with: .color(
                Color.accentColor.opacity(0.72)
            ),
            lineWidth: 1
        )
        context.draw(
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Color.accentColor),
            at: labelPoint,
            anchor: .center
        )
    }

    private func drawActiveVerticalSnapGuide(
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        guard draggedFurnitureID != nil,
              let snap =
                aktywnePrzyciagnieciePionowe else {
            return
        }

        let y = projection.y(
            snap.liniaProwadzaca
        )
        let left = projection.point(
            x: .zero,
            y: snap.liniaProwadzaca
        )
        let right = projection.point(
            x: projection.wallWidth,
            y: snap.liniaProwadzaca
        )

        var path = Path()
        path.move(to: left)
        path.addLine(to: right)

        context.stroke(
            path,
            with: .color(Color.accentColor),
            style: StrokeStyle(
                lineWidth: 1.5,
                dash: [7, 5]
            )
        )

        let labelPosition = CGPoint(
            x: projection.x(
                projection.wallWidth / 2
            ),
            y: y - 14
        )
        let label = context.resolve(
            Text(snap.rodzaj.tytul)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Color.accentColor)
        )
        let measuredSize = label.measure(
            in: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        let backgroundRect = CGRect(
            x: labelPosition.x - measuredSize.width / 2 - 7,
            y: labelPosition.y - measuredSize.height / 2 - 4,
            width: measuredSize.width + 14,
            height: measuredSize.height + 8
        )
        context.fill(
            Path(
                roundedRect: backgroundRect,
                cornerRadius: 7
            ),
            with: .color(
                StolarniaPalette.drawingLabelFill
            )
        )
        context.draw(
            label,
            at: labelPosition,
            anchor: .center
        )
    }

    private func drawDetectedRuns(
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        for run in runs {
            let markerY = min(
                run.topOffset + 90,
                projection.wallHeight - 70
            )
            let start = projection.point(
                x: run.startOffset,
                y: markerY
            )
            let end = projection.point(
                x: run.endOffset,
                y: markerY
            )

            var line = Path()
            line.move(to: start)
            line.addLine(to: end)

            let color = runColor(run.kind)
            context.stroke(
                line,
                with: .color(color.opacity(0.80)),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    dash: [6, 4]
                )
            )

            context.draw(
                Text(
                    "\(run.kind.shortTitle) • \(formatted(run.width))"
                )
                .font(.caption2.weight(.semibold))
                .foregroundColor(color),
                at: CGPoint(
                    x: (start.x + end.x) / 2,
                    y: start.y - 10
                ),
                anchor: .center
            )
        }
    }

    private func runColor(
        _ kind: KitchenRunKindV015
    ) -> Color {
        switch kind {
        case .base:
            return .orange
        case .wall:
            return .blue
        case .upper:
            return .purple
        case .tall:
            return .green
        }
    }

    private func drawFurnitureDimensions(
        furniture: [MebelElewacjaScianyElement],
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        for item in furniture {
            let isSelected = item.id == selectedFurnitureID
            let showsDetailedWidth =
                poziomWymiarowania == .szczegolowe

            guard isSelected || showsDetailedWidth else {
                continue
            }

            let translationX =
                item.id == draggedFurnitureID
                ? furnitureDragTranslationX
                : 0
            let baseWidthStart = projection.point(
                x: item.rect.x,
                y: item.rect.y
            )
            let baseWidthEnd = projection.point(
                x: item.rect.maxX,
                y: item.rect.y
            )
            let widthStart = CGPoint(
                x: baseWidthStart.x + translationX,
                y: baseWidthStart.y
            )
            let widthEnd = CGPoint(
                x: baseWidthEnd.x + translationX,
                y: baseWidthEnd.y
            )
            let widthLabel = formatted(item.rect.width)
            let widthHasRoom =
                Wymiarowanie2DRenderer.hasRoomForLabel(
                    widthLabel,
                    start: widthStart,
                    end: widthEnd,
                    minimumPadding: 6
                )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: widthStart,
                sourceEnd: widthEnd,
                offset: CGVector(
                    dx: 0,
                    dy: 18
                ),
                label: widthLabel,
                emphasis: isSelected
                    ? .zaznaczone
                    : .pomocnicze,
                showsLabel: isSelected || widthHasRoom
            )

            guard isSelected else {
                continue
            }

            let baseHeightStart = projection.point(
                x: item.rect.maxX,
                y: item.rect.y
            )
            let baseHeightEnd = projection.point(
                x: item.rect.maxX,
                y: item.rect.maxY
            )
            let heightStart = CGPoint(
                x: baseHeightStart.x + translationX,
                y: baseHeightStart.y
            )
            let heightEnd = CGPoint(
                x: baseHeightEnd.x + translationX,
                y: baseHeightEnd.y
            )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: heightStart,
                sourceEnd: heightEnd,
                offset: CGVector(
                    dx: 22,
                    dy: 0
                ),
                label: formatted(item.rect.height),
                emphasis: .zaznaczone
            )
        }
    }

    private func drawSelectedRunDimensionChain(
        furniture: [MebelElewacjaScianyElement],
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        guard let selectedFurnitureID,
              let run = runs.first(where: {
                  $0.contains(selectedFurnitureID)
              }) else {
            return
        }

        let elements = furniture
            .filter {
                run.assemblyIDs.contains($0.id)
            }
            .sorted {
                $0.rect.x < $1.rect.x
            }

        guard !elements.isEmpty else {
            return
        }

        struct ChainSegment {
            let start: Millimeters
            let end: Millimeters
            let label: String
            let emphasis: WyroznienieWymiaru2D
        }

        var segments: [ChainSegment] = []
        var cursor: Millimeters = .zero

        for item in elements {
            if item.rect.x.rawValue - cursor.rawValue > 0.5 {
                segments.append(
                    ChainSegment(
                        start: cursor,
                        end: item.rect.x,
                        label: formatted(item.rect.x - cursor),
                        emphasis: .pomocnicze
                    )
                )
            }

            segments.append(
                ChainSegment(
                    start: item.rect.x,
                    end: item.rect.maxX,
                    label: formatted(item.rect.width),
                    emphasis:
                        item.id == selectedFurnitureID
                        ? .zaznaczone
                        : .standardowe
                )
            )
            cursor = maxMillimeters(
                cursor,
                item.rect.maxX
            )
        }

        if projection.wallWidth.rawValue - cursor.rawValue > 0.5 {
            segments.append(
                ChainSegment(
                    start: cursor,
                    end: projection.wallWidth,
                    label: formatted(projection.wallWidth - cursor),
                    emphasis: .pomocnicze
                )
            )
        }

        for segment in segments {
            let start = projection.point(
                x: segment.start,
                y: .zero
            )
            let end = projection.point(
                x: segment.end,
                y: .zero
            )
            let showsLabel =
                segment.emphasis == .zaznaczone
                || Wymiarowanie2DRenderer.hasRoomForLabel(
                    segment.label,
                    start: start,
                    end: end,
                    minimumPadding: 8
                )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: start,
                sourceEnd: end,
                offset: CGVector(dx: 0, dy: 54),
                label: segment.label,
                emphasis: segment.emphasis,
                showsLabel: showsLabel
            )
        }    }

    private func drawOpeningDimensions(
        openings: [OtworElewacjaScianyElement],
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        for opening in openings {
            let widthStart = projection.point(
                x: opening.rect.x,
                y: opening.rect.y
            )
            let widthEnd = projection.point(
                x: opening.rect.maxX,
                y: opening.rect.y
            )
            let heightStart = projection.point(
                x: opening.rect.maxX,
                y: opening.rect.y
            )
            let heightEnd = projection.point(
                x: opening.rect.maxX,
                y: opening.rect.maxY
            )
            let widthLabel = formatted(opening.rect.width)
            let heightLabel = formatted(opening.rect.height)

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: widthStart,
                sourceEnd: widthEnd,
                offset: CGVector(
                    dx: 0,
                    dy: -16
                ),
                label: widthLabel,
                emphasis: .pomocnicze,
                showsLabel:
                    Wymiarowanie2DRenderer.hasRoomForLabel(
                        widthLabel,
                        start: widthStart,
                        end: widthEnd
                    )
            )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: heightStart,
                sourceEnd: heightEnd,
                offset: CGVector(
                    dx: -18,
                    dy: 0
                ),
                label: heightLabel,
                emphasis: .pomocnicze,
                showsLabel:
                    Wymiarowanie2DRenderer.hasRoomForLabel(
                        heightLabel,
                        start: heightStart,
                        end: heightEnd
                    )
            )
        }
    }

    private func drawWallDimensions(
        context: GraphicsContext,
        projection: ElewacjaScianyProjection
    ) {
        let maximumHeight =
            MebelElewacjaScianyGeometry
                .wallMaximumHeight(wall: wall)
        let topStart = projection.point(
            x: .zero,
            y: maximumHeight
        )
        let topEnd = projection.point(
            x: projection.wallWidth,
            y: maximumHeight
        )

        Wymiarowanie2DRenderer.drawLinearDimension(
            in: context,
            sourceStart: topStart,
            sourceEnd: topEnd,
            offset: CGVector(
                dx: 0,
                dy: -30
            ),
            label: formatted(projection.wallWidth),
            emphasis: .standardowe
        )

        let heightStart = projection.point(
            x: projection.wallWidth,
            y: .zero
        )
        let heightEnd = projection.point(
            x: projection.wallWidth,
            y: maximumHeight
        )

        Wymiarowanie2DRenderer.drawLinearDimension(
            in: context,
            sourceStart: heightStart,
            sourceEnd: heightEnd,
            offset: CGVector(
                dx: 34,
                dy: 0
            ),
            label: formatted(maximumHeight),
            emphasis: .standardowe
        )

        context.draw(
            Text(wall.name)
                .font(.headline),
            at: CGPoint(
                x: projection.x(
                    projection.wallWidth / 2
                ),
                y: projection.y(maximumHeight) + 18
            ),
            anchor: .center
        )
    }

    private func dimensionEditContext(
        at location: CGPoint,
        furniture: [MebelElewacjaScianyElement],
        projection: ElewacjaScianyProjection
    ) -> KontekstEdycjiWymiaru2D? {
        guard poziomWymiarowania != .ukryte,
              onEditDimension != nil else {
            return nil
        }

        for item in furniture.reversed() {
            guard let assembly = assemblies.first(where: {
                $0.id == item.id
            }) else {
                continue
            }

            let isSelected = item.id == selectedFurnitureID
            let showsWidth =
                isSelected
                || poziomWymiarowania == .szczegolowe

            if showsWidth {
                let start = projection.point(
                    x: item.rect.x,
                    y: item.rect.y
                )
                let end = projection.point(
                    x: item.rect.maxX,
                    y: item.rect.y
                )
                let label = formatted(item.rect.width)
                let hasVisibleLabel =
                    isSelected
                    || Wymiarowanie2DRenderer.hasRoomForLabel(
                        label,
                        start: start,
                        end: end,
                        minimumPadding: 6
                    )

                if hasVisibleLabel,
                   Wymiarowanie2DRenderer.contains(
                       point: location,
                       label: label,
                       center:
                           Wymiarowanie2DRenderer.labelCenter(
                               sourceStart: start,
                               sourceEnd: end,
                               offset: CGVector(dx: 0, dy: 18)
                           )
                   ) {
                    return .szerokoscModulu(
                        furnitureID: assembly.id,
                        nazwa: assembly.name,
                        wartosc: assembly.size.width
                    )
                }
            }

            guard isSelected else {
                continue
            }

            let heightStart = projection.point(
                x: item.rect.maxX,
                y: item.rect.y
            )
            let heightEnd = projection.point(
                x: item.rect.maxX,
                y: item.rect.maxY
            )
            let heightLabel = formatted(item.rect.height)

            if Wymiarowanie2DRenderer.contains(
                point: location,
                label: heightLabel,
                center:
                    Wymiarowanie2DRenderer.labelCenter(
                        sourceStart: heightStart,
                        sourceEnd: heightEnd,
                        offset: CGVector(dx: 22, dy: 0)
                    )
            ) {
                return .wysokoscModulu(
                    furnitureID: assembly.id,
                    nazwa: assembly.name,
                    wartosc: assembly.size.height
                )
            }
        }

        let maximumHeight =
            MebelElewacjaScianyGeometry
                .wallMaximumHeight(wall: wall)
        let widthStart = projection.point(
            x: .zero,
            y: maximumHeight
        )
        let widthEnd = projection.point(
            x: projection.wallWidth,
            y: maximumHeight
        )
        let widthLabel = formatted(projection.wallWidth)

        if case .line? = room.geometry.geometry(of: wall.id),
           Wymiarowanie2DRenderer.contains(
               point: location,
               label: widthLabel,
               center:
                   Wymiarowanie2DRenderer.labelCenter(
                       sourceStart: widthStart,
                       sourceEnd: widthEnd,
                       offset: CGVector(dx: 0, dy: -30)
                   )
           ) {
            return .dlugoscSciany(
                wallID: wall.id,
                nazwa: wall.name,
                wartosc: projection.wallWidth
            )
        }

        let heightStart = projection.point(
            x: projection.wallWidth,
            y: .zero
        )
        let heightEnd = projection.point(
            x: projection.wallWidth,
            y: maximumHeight
        )
        let heightLabel = formatted(maximumHeight)

        if Wymiarowanie2DRenderer.contains(
            point: location,
            label: heightLabel,
            center:
                Wymiarowanie2DRenderer.labelCenter(
                    sourceStart: heightStart,
                    sourceEnd: heightEnd,
                    offset: CGVector(dx: 34, dy: 0)
                )
        ) {
            return .wysokoscSciany(
                wallID: wall.id,
                nazwa: wall.name,
                wartosc: maximumHeight
            )
        }

        return nil
    }

    private func maxMillimeters(
        _ lhs: Millimeters,
        _ rhs: Millimeters
    ) -> Millimeters {
        lhs.rawValue >= rhs.rawValue
            ? lhs
            : rhs
    }

    private func furnitureID(
        at location: CGPoint,
        furniture: [MebelElewacjaScianyElement],
        projection: ElewacjaScianyProjection
    ) -> FurnitureAssemblyID? {
        furniture.reversed().first {
            projection.rect($0.rect)
                .insetBy(dx: -8, dy: -8)
                .contains(location)
        }?.id
    }

    private func formatted(
        _ value: Millimeters
    ) -> String {
        let number = value.rawValue.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
        return "\(number) mm"
    }
}

private struct ElevationOpeningVisualStyleV016 {
    let color: Color
    let fillOpacity: Double
    let lineWidth: CGFloat
    let dash: [CGFloat]
}

private struct ElewacjaScianyProjection {
    let wallWidth: Millimeters
    let wallHeight: Millimeters
    let size: CGSize
    let isMirrored: Bool

    private let horizontalPadding: CGFloat = 70
    private let verticalPadding: CGFloat = 70

    private var scale: CGFloat {
        let usableWidth = max(
            size.width - horizontalPadding * 2,
            1
        )
        let usableHeight = max(
            size.height - verticalPadding * 2,
            1
        )
        let scaleX =
            usableWidth
            / max(CGFloat(wallWidth.rawValue), 1)
        let scaleY =
            usableHeight
            / max(CGFloat(wallHeight.rawValue), 1)
        return min(scaleX, scaleY)
    }

    private var originX: CGFloat {
        (
            size.width
            - CGFloat(wallWidth.rawValue) * scale
        ) / 2
    }

    private var floorY: CGFloat {
        (
            size.height
            + CGFloat(wallHeight.rawValue) * scale
        ) / 2
    }

    func x(
        _ value: Millimeters
    ) -> CGFloat {
        let modelX =
            isMirrored
            ? wallWidth.rawValue - value.rawValue
            : value.rawValue
        return originX + CGFloat(modelX) * scale
    }

    func y(
        _ value: Millimeters
    ) -> CGFloat {
        floorY - CGFloat(value.rawValue) * scale
    }

    func millimetersY(
        _ screenY: CGFloat
    ) -> Double {
        Double((floorY - screenY) / scale)
    }

    func millimetersX(
        _ screenX: CGFloat
    ) -> Double {
        let visualX =
            Double((screenX - originX) / scale)
        return isMirrored
            ? wallWidth.rawValue - visualX
            : visualX
    }

    func point(
        x: Millimeters,
        y: Millimeters
    ) -> CGPoint {
        CGPoint(
            x: self.x(x),
            y: self.y(y)
        )
    }

    func rect(
        _ value: ElewacjaScianyProstokatMM
    ) -> CGRect {
        let startX =
            x(value.x)
        let endX =
            x(value.maxX)
        return CGRect(
            x: min(startX, endX),
            y: y(value.maxY),
            width: CGFloat(value.width.rawValue) * scale,
            height: CGFloat(value.height.rawValue) * scale
        )
    }
}
