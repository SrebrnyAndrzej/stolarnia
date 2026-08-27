import DomainCore
import SwiftUI

/// Wspólny obszar rysowania planu 2D używany przez widok standardowy
/// i pełnoekranową prezentację dla klienta.
struct Plan2DCanvasView: View {
    let room: RoomDefinition
    let assemblies: [FurnitureAssembly]
    let numberedItems: [FurnitureCanvasItemV016]
    let globalneMaterialy: GlobalneMaterialyPomieszczenia
    let poziomWymiarowania: PoziomWymiarowania2D
    @Binding var selectedWallID: WallID?
    @Binding var selectedFurnitureID: FurnitureAssemblyID?
    let zaznaczoneFurnitureIDsV066: Set<FurnitureAssemblyID>
    let trybWielokrotnegoZaznaczaniaV066: Bool
    let onToggleFurnitureSelectionV066: ((FurnitureAssemblyID) -> Void)?
    let onClearFurnitureSelectionV066: (() -> Void)?
    let onReplaceFurnitureSelectionV067:
        ((ZaznaczenieRamkaV067) -> Void)?
    let allowsViewportGestures: Bool
    let onEditDimension: ((KontekstEdycjiWymiaru2D) -> Void)?
    let onMoveFurniture: ((KontekstPrzesunieciaModulu2D) -> Void)?
    let slidingPartitionDraftV092:
        SlidingRoomPartitionCandidateV092?
    let onChangeSlidingPartitionDraftEndV092:
        ((Point2MM) -> Void)?
    /// Przekazywany z MeblePomieszczeniaViewModel.renderRevision.
    /// Zmiana wartości wyzwala odświeżenie cachedFootprints i cachedLabelByID,
    /// eliminując przeliczanie geometrii na każdym evencie pan/zoom/drag (60fps).
    let renderRevision: Int

    @State private var zoomScale: CGFloat = 1
    @State private var committedZoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var committedPanOffset: CGSize = .zero
    @State private var draggedFurnitureID: FurnitureAssemblyID?
    @State private var furnitureDragTranslation: CGSize = .zero
    @State private var highlightedSwapTargetID: FurnitureAssemblyID?
    @State private var aktywnePrzyciagniecie:
        PunktPrzyciagnieciaModulu2D?
    @State private var poczatekRamkiZaznaczeniaV067:
        CGPoint?
    @State private var ramkaZaznaczeniaV067:
        CGRect?

    // MARK: - Performance cache

    /// Geometria stopek mebli przeliczona z MebelPlan2DGeometry.footprints().
    /// Aktualizowana TYLKO gdy zmieni się renderRevision — nie na każdym
    /// evencie pan/zoom/drag, co eliminuje 60fps recompute geometrii.
    @State private var cachedFootprints: [MebelPlan2DFootprint]

    /// Mapa etykiet numerycznych. Budowana raz per refresh.
    @State private var cachedLabelByID: [FurnitureAssemblyID: String]

    /// Słownik assembly po ID. Używany w drawFurnitureDimensions.
    @State private var cachedAssemblyByID: [FurnitureAssemblyID: FurnitureAssembly]

    init(
        room: RoomDefinition,
        assemblies: [FurnitureAssembly] = [],
        numberedItems: [FurnitureCanvasItemV016] = [],
        globalneMaterialy: GlobalneMaterialyPomieszczenia = .domyslne(roomID: ""),
        poziomWymiarowania: PoziomWymiarowania2D = .podstawowe,
        selectedWallID: Binding<WallID?>,
        selectedFurnitureID: Binding<FurnitureAssemblyID?> = .constant(nil),
        zaznaczoneFurnitureIDsV066: Set<FurnitureAssemblyID> = [],
        trybWielokrotnegoZaznaczaniaV066: Bool = false,
        onToggleFurnitureSelectionV066:
            ((FurnitureAssemblyID) -> Void)? = nil,
        onClearFurnitureSelectionV066: (() -> Void)? = nil,
        onReplaceFurnitureSelectionV067:
            ((ZaznaczenieRamkaV067) -> Void)? = nil,
        allowsViewportGestures: Bool = false,
        onEditDimension: ((KontekstEdycjiWymiaru2D) -> Void)? = nil,
        onMoveFurniture: ((KontekstPrzesunieciaModulu2D) -> Void)? = nil,
        slidingPartitionDraftV092:
            SlidingRoomPartitionCandidateV092? = nil,
        onChangeSlidingPartitionDraftEndV092:
            ((Point2MM) -> Void)? = nil,
        renderRevision: Int = 0
    ) {
        self.room = room
        self.assemblies = assemblies
        self.numberedItems = numberedItems
        self.globalneMaterialy = globalneMaterialy
        self.poziomWymiarowania = poziomWymiarowania
        self._selectedWallID = selectedWallID
        self._selectedFurnitureID = selectedFurnitureID
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
        self.allowsViewportGestures = allowsViewportGestures
        self.onEditDimension = onEditDimension
        self.onMoveFurniture = onMoveFurniture
        self.slidingPartitionDraftV092 =
            slidingPartitionDraftV092
        self.onChangeSlidingPartitionDraftEndV092 =
            onChangeSlidingPartitionDraftEndV092
        self.renderRevision = renderRevision

        // Inicjalizacja cache — obliczane raz przy tworzeniu widoku,
        // dalej aktualizowane wyłącznie przez onChange(of: renderRevision).
        _cachedFootprints = State(
            initialValue: MebelPlan2DGeometry.footprints(
                for: assemblies,
                in: room
            )
        )
        _cachedLabelByID = State(
            initialValue: FurnitureCanvasNumberingV016.labelMap(
                from: numberedItems
            )
        )
        _cachedAssemblyByID = State(
            initialValue: Dictionary(
                assemblies.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawRoom(
                    in: context,
                    size: size
                )
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        if slidingPartitionDraftV092 != nil,
                           let point =
                            modelPoint(
                                at:
                                    event.location,
                                size:
                                    proxy.size
                            ) {
                            onChangeSlidingPartitionDraftEndV092?(
                                point
                            )
                            return
                        }

                        if let dimension =
                            dimensionEditContext(
                                at: event.location,
                                size: proxy.size
                            ) {
                            onEditDimension?(dimension)
                            return
                        }

                        if let furnitureID = furnitureID(
                            at: event.location,
                            size: proxy.size
                        ) {
                            if trybWielokrotnegoZaznaczaniaV066,
                               let onToggleFurnitureSelectionV066 {
                                onToggleFurnitureSelectionV066(
                                    furnitureID
                                )
                            } else {
                                selectedFurnitureID = furnitureID
                            }

                            // Zachowujemy kontekst ściany mebla. Dzięki temu po
                            // zaznaczeniu dolnego ciągu przycisk „Dodaj mebel”
                            // nadal pozwala dodać na tej samej ścianie szafki
                            // wiszące albo zabudowę wysoką.
                            selectedWallID = assemblies.first(where: {
                                $0.id == furnitureID
                            })?.placement?.wallID
                        } else {
                            selectedWallID = wallID(
                                at: event.location,
                                size: proxy.size
                            )
                            if trybWielokrotnegoZaznaczaniaV066 {
                                onClearFurnitureSelectionV066?()
                            } else {
                                selectedFurnitureID = nil
                            }
                        }
                    }
            )
            .simultaneousGesture(
                dragGesture,
                including:
                    allowsViewportGestures
                    && slidingPartitionDraftV092 == nil
                    && !trybWielokrotnegoZaznaczaniaV066
                    ? .all
                    : .none
            )
            .simultaneousGesture(
                furnitureMoveGesture(size: proxy.size),
                including:
                    onMoveFurniture == nil
                    || slidingPartitionDraftV092 != nil
                    ? .none
                    : .all
            )
            .simultaneousGesture(
                slidingPartitionDraftGestureV092(
                    size:
                        proxy.size
                ),
                including:
                    slidingPartitionDraftV092 == nil
                    ? .none
                    : .all
            )
            .simultaneousGesture(
                selectionMarqueeGestureV067(size: proxy.size),
                including:
                    trybWielokrotnegoZaznaczaniaV066
                    && slidingPartitionDraftV092 == nil
                    && onReplaceFurnitureSelectionV067 != nil
                    ? .all
                    : .none
            )
            .simultaneousGesture(
                magnificationGesture,
                including:
                    allowsViewportGestures
                    && slidingPartitionDraftV092 == nil
                    ? .all
                    : .none
            )
            .background(StolarniaPalette.drawingDesk)
            .environment(\.colorScheme, .light)
            .onChange(of: renderRevision) { _, _ in
                refreshPlan2DCache()
            }
            .overlay {
                ramkaZaznaczeniaOverlayV067
            }
            .overlay(alignment: .trailing) {
                if allowsViewportGestures {
                    viewportControls
                        .padding(.trailing, 16)
                }
            }
            .overlay(alignment: .bottomLeading) {
                furnitureLegend
                    .padding(12)
            }
        }
    }

    private var projectionPadding: CGFloat {
        switch poziomWymiarowania {
        case .ukryte:
            return 56
        case .podstawowe:
            return 82
        case .szczegolowe:
            return 104
        }
    }

    private var viewportControls: some View {
        VStack(spacing: 8) {
            Button {
                setZoom(zoomScale * 1.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("Powiększ plan")

            Text("\(Int((zoomScale * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 48)

            Button {
                setZoom(zoomScale / 1.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("Pomniejsz plan")

            Divider()
                .frame(width: 28)

            Button {
                resetViewport()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .accessibilityLabel("Dopasuj plan do ekranu")
        }
        .buttonStyle(.bordered)
        .padding(10)
        .stolarniaMaterial(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                panOffset = CGSize(
                    width: committedPanOffset.width + value.translation.width,
                    height: committedPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                committedPanOffset = panOffset
            }
    }

    private func selectionMarqueeGestureV067(
        size: CGSize
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 6,
            coordinateSpace: .local
        )
        .onChanged { value in
            if poczatekRamkiZaznaczeniaV067 == nil {
                guard furnitureID(
                    at: value.startLocation,
                    size: size
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
                    size: size
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
        size: CGSize
    ) -> ZaznaczenieRamkaV067 {
        let allPoints = room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }
        guard !allPoints.isEmpty else {
            return ZaznaczenieRamkaV067(
                ids: [],
                preferowaneGlowneID: nil
            )
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )

        let selected = MebelPlan2DGeometry
            .footprints(for: assemblies, in: room)
            .compactMap {
                footprint
                -> (
                    id: FurnitureAssemblyID,
                    distance: CGFloat
                )? in
                guard let first = footprint.points.first else {
                    return nil
                }

                var path = Path()
                path.move(to: projection.screenPoint(first))
                for point in footprint.points.dropFirst() {
                    path.addLine(
                        to: projection.screenPoint(point)
                    )
                }
                path.closeSubpath()

                guard path.boundingRect.intersects(rect) else {
                    return nil
                }

                let center = projection.screenPoint(
                    footprint.center
                )
                let distance = hypot(
                    center.x - start.x,
                    center.y - start.y
                )
                return (footprint.id, distance)
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
                let labelWidth: CGFloat = 92
                let labelRect = CGRect(
                    x: rect.minX,
                    y: max(4, rect.minY - 26),
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

    private func furnitureMoveGesture(
        size: CGSize
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 8,
            coordinateSpace: .local
        )
        .onChanged { value in
            if draggedFurnitureID == nil {
                guard let furnitureID = furnitureID(
                    at: value.startLocation,
                    size: size
                ) else {
                    return
                }

                draggedFurnitureID = furnitureID
                selectedFurnitureID = furnitureID
                selectedWallID = assemblies.first(where: {
                    $0.id == furnitureID
                })?.placement?.wallID
            }

            guard let draggedFurnitureID else {
                return
            }

            let movement = movementContext(
                for: draggedFurnitureID,
                at: value.location,
                size: size
            )

            if let movement {
                furnitureDragTranslation =
                    translationForMovement(
                        movement,
                        furnitureID: draggedFurnitureID,
                        size: size
                    )
                highlightedSwapTargetID =
                    movement.celZamianyID
                aktywnePrzyciagniecie =
                    movement.przyciagniecie
            } else {
                furnitureDragTranslation =
                    constrainedFurnitureTranslation(
                        for: draggedFurnitureID,
                        translation: value.translation,
                        size: size
                    )
                highlightedSwapTargetID = nil
                aktywnePrzyciagniecie = nil
            }
        }
        .onEnded { value in
            defer {
                draggedFurnitureID = nil
                furnitureDragTranslation = .zero
                highlightedSwapTargetID = nil
                aktywnePrzyciagniecie = nil
            }

            guard let draggedFurnitureID,
                  let movement = movementContext(
                      for: draggedFurnitureID,
                      at: value.location,
                      size: size
                  ) else {
                return
            }

            onMoveFurniture?(movement)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = clampedZoom(committedZoomScale * value)
            }
            .onEnded { _ in
                committedZoomScale = zoomScale
            }
    }

    private func slidingPartitionDraftGestureV092(
        size:
            CGSize
    ) -> some Gesture {
        DragGesture(
            minimumDistance:
                0,
            coordinateSpace:
                .local
        )
        .onChanged {
            value in

            guard let point =
                modelPoint(
                    at:
                        value.location,
                    size:
                        size
                )
            else {
                return
            }

            onChangeSlidingPartitionDraftEndV092?(
                point
            )
        }
    }

    private func setZoom(_ value: CGFloat) {
        let newValue = clampedZoom(value)
        zoomScale = newValue
        committedZoomScale = newValue
    }

    private func resetViewport() {
        zoomScale = 1
        committedZoomScale = 1
        panOffset = .zero
        committedPanOffset = .zero
    }

    private func modelPoint(
        at location:
            CGPoint,
        size:
            CGSize
    ) -> Point2MM? {
        let allPoints =
            room.geometry.boundary.segments.flatMap {
                Plan2DGeometryAdapter
                    .sampledPoints(
                        for:
                            $0
                    )
            }

        guard !allPoints.isEmpty else {
            return nil
        }

        let projection =
            Plan2DProjection(
                points:
                    allPoints,
                size:
                    size,
                padding:
                    projectionPadding,
                zoomScale:
                    zoomScale,
                panOffset:
                    panOffset
            )

        return projection.modelPoint(
            location
        )
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.5), 4)
    }

    // MARK: - Cache refresh

    private func refreshPlan2DCache() {
        cachedFootprints = MebelPlan2DGeometry.footprints(
            for: assemblies,
            in: room
        )
        cachedLabelByID = FurnitureCanvasNumberingV016.labelMap(
            from: numberedItems
        )
        cachedAssemblyByID = Dictionary(
            assemblies.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func drawRoom(
        in context: GraphicsContext,
        size: CGSize
    ) {
        let sampledSegments = room.geometry.boundary.segments.map {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }

        let allPoints = sampledSegments.flatMap { $0 }
        guard let firstPoint = allPoints.first else {
            return
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )
        let screenPoints = allPoints.map(projection.screenPoint)
        let centroid = centroid(of: screenPoints)

        var roomPath = Path()
        roomPath.move(to: projection.screenPoint(firstPoint))

        for segmentPoints in sampledSegments {
            for point in segmentPoints.dropFirst() {
                roomPath.addLine(to: projection.screenPoint(point))
            }
        }

        roomPath.closeSubpath()

        context.fill(
            roomPath,
            with: .color(StolarniaPalette.drawingPaper)
        )
        context.stroke(
            roomPath,
            with: .color(StolarniaPalette.drawingMutedInk.opacity(0.62)),
            lineWidth: 1
        )

        drawArchitecturalFeatures(
            projection: projection,
            in: context
        )

        // PERF: używamy cachedFootprints zamiast przeliczać geometrię na każdym
        // evencie pan/zoom/drag. Cache jest aktualizowany tylko gdy zmieni się
        // renderRevision (zapis/edycja modułu), nie na 60fps podczas interakcji.
        drawFurniture(
            footprints: cachedFootprints,
            labelByID: cachedLabelByID,
            projection: projection,
            in: context
        )

        for wall in room.geometry.walls {
            guard let segment = room.geometry.geometry(of: wall.id) else {
                continue
            }

            drawWall(
                wall,
                segment: segment,
                projection: projection,
                centroid: centroid,
                in: context
            )
        }

        drawActiveSnapGuide(
            projection: projection,
            in: context
        )

        if let slidingPartitionDraftV092 {
            drawSlidingPartitionDraftV092(
                slidingPartitionDraftV092,
                projection:
                    projection,
                in:
                    context
            )
        }

        drawFurnitureDimensions(
            footprints: cachedFootprints,
            assemblyByID: cachedAssemblyByID,
            projection: projection,
            in: context
        )

        if poziomWymiarowania == .szczegolowe {
            drawSelectedWallDimensionChain(
                projection: projection,
                roomCentroid: centroid,
                in: context
            )
        }
    }

    private func drawSlidingPartitionDraftV092(
        _ draft:
            SlidingRoomPartitionCandidateV092,
        projection:
            Plan2DProjection,
        in context:
            GraphicsContext
    ) {
        let start =
            projection.screenPoint(
                draft.start
            )
        let end =
            projection.screenPoint(
                draft.end
            )
        let dx =
            end.x - start.x
        let dy =
            end.y - start.y
        let length =
            max(
                hypot(dx, dy),
                0.001
            )
        let normal =
            CGVector(
                dx:
                    -dy / length,
                dy:
                    dx / length
            )
        let trackHalf:
            CGFloat = 4
        let railAStart =
            CGPoint(
                x:
                    start.x + normal.dx * trackHalf,
                y:
                    start.y + normal.dy * trackHalf
            )
        let railAEnd =
            CGPoint(
                x:
                    end.x + normal.dx * trackHalf,
                y:
                    end.y + normal.dy * trackHalf
            )
        let railBStart =
            CGPoint(
                x:
                    start.x - normal.dx * trackHalf,
                y:
                    start.y - normal.dy * trackHalf
            )
        let railBEnd =
            CGPoint(
                x:
                    end.x - normal.dx * trackHalf,
                y:
                    end.y - normal.dy * trackHalf
            )

        var centerPath = Path()
        centerPath.move(to: start)
        centerPath.addLine(to: end)

        context.stroke(
            centerPath,
            with:
                .color(
                    Color.accentColor.opacity(0.92)
                ),
            style:
                StrokeStyle(
                    lineWidth:
                        3,
                    lineCap:
                        .round,
                    dash:
                        [9, 5]
                )
        )

        for points in [
            (railAStart, railAEnd),
            (railBStart, railBEnd)
        ] {
            var rail = Path()
            rail.move(to: points.0)
            rail.addLine(to: points.1)
            context.stroke(
                rail,
                with:
                    .color(
                        StolarniaPalette
                            .drawingMutedInk
                            .opacity(0.72)
                    ),
                lineWidth:
                    1.2
            )
        }

        drawSlidingPartitionHandleV092(
            at:
                start,
            title:
                "START",
            color:
                .secondary,
            in:
                context
        )
        drawSlidingPartitionHandleV092(
            at:
                end,
            title:
                "KONIEC",
            color:
                .accentColor,
            in:
                context
        )

        let mid =
            CGPoint(
                x:
                    (start.x + end.x) / 2,
                y:
                    (start.y + end.y) / 2
            )
        let label =
            "\(draft.lengthLabel) / \(draft.doorCount) skrzydła"
        let labelRect =
            CGRect(
                x:
                    mid.x - 96,
                y:
                    mid.y - 16,
                width:
                    192,
                height:
                    32
            )

        context.fill(
            Path(
                roundedRect:
                    labelRect,
                cornerRadius:
                    8
            ),
            with:
                .color(
                    StolarniaPalette
                        .drawingLabelFill
                        .opacity(0.96)
                )
        )
        context.stroke(
            Path(
                roundedRect:
                    labelRect,
                cornerRadius:
                    8
            ),
            with:
                .color(
                    Color.accentColor.opacity(0.56)
                ),
            lineWidth:
                1
        )
        context.draw(
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(
                    Color.accentColor
                ),
            at:
                CGPoint(
                    x:
                        labelRect.midX,
                    y:
                        labelRect.midY
                ),
            anchor:
                .center
        )
    }

    private func drawSlidingPartitionHandleV092(
        at point:
            CGPoint,
        title:
            String,
        color:
            Color,
        in context:
            GraphicsContext
    ) {
        let handleRect =
            CGRect(
                x:
                    point.x - 11,
                y:
                    point.y - 11,
                width:
                    22,
                height:
                    22
            )

        context.fill(
            Path(
                ellipseIn:
                    handleRect
            ),
            with:
                .color(
                    color.opacity(0.92)
                )
        )
        context.stroke(
            Path(
                ellipseIn:
                    handleRect.insetBy(
                        dx:
                            -2,
                        dy:
                            -2
                    )
            ),
            with:
                .color(
                    Color.white.opacity(0.92)
                ),
            lineWidth:
                2
        )

        context.draw(
            Text(title)
                .font(.caption2.monospaced().bold())
                .foregroundColor(color),
            at:
                CGPoint(
                    x:
                        point.x,
                    y:
                        point.y + 24
                ),
            anchor:
                .center
        )
    }

    private func drawFurniture(
        footprints: [MebelPlan2DFootprint],
        labelByID: [FurnitureAssemblyID: String],
        projection: Plan2DProjection,
        in context: GraphicsContext
    ) {
        // PERF: labelByID pochodzi z cachedLabelByID obliczonego raz per
        // renderRevision — nie buildujemy słownika na każdej klatce.
        for footprint in footprints {
            let originalPoints = footprint.points.map(
                projection.screenPoint
            )
            guard !originalPoints.isEmpty else {
                continue
            }

            let isDraggedSource =
                footprint.id == draggedFurnitureID
            let isGroupDrag =
                draggedFurnitureID != nil
                && zaznaczoneFurnitureIDsV066.count > 1
                && zaznaczoneFurnitureIDsV066.contains(
                    footprint.id
                )
                && draggedFurnitureID.map {
                    zaznaczoneFurnitureIDsV066.contains($0)
                } == true
            let isDragged = isDraggedSource || isGroupDrag
            let isSwapTarget =
                footprint.id == highlightedSwapTargetID
            let translation = isDragged
                ? furnitureDragTranslation
                : .zero
            let screenPoints = originalPoints.map {
                CGPoint(
                    x: $0.x + translation.width,
                    y: $0.y + translation.height
                )
            }

            if isDragged {
                var originalPath = Path()
                originalPath.move(to: originalPoints[0])
                for point in originalPoints.dropFirst() {
                    originalPath.addLine(to: point)
                }
                originalPath.closeSubpath()

                context.stroke(
                    originalPath,
                    with: .color(
                        Color.accentColor.opacity(0.38)
                    ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [6, 5]
                    )
                )
            }

            var path = Path()
            path.move(to: screenPoints[0])
            for point in screenPoints.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()

            let isPrimarySelection =
                footprint.id == selectedFurnitureID
            let isSelected =
                isPrimarySelection
                || zaznaczoneFurnitureIDsV066.contains(
                    footprint.id
                )
            let visualStyle = furnitureStyle(for: footprint.layer)
            let label = labelByID[footprint.id] ?? "M?"

            context.fill(
                path,
                with: .color(
                    visualStyle.color.opacity(
                        isDragged
                            ? 0.48
                            : (
                                isSelected
                                    ? 0.34
                                    : visualStyle.fillOpacity
                            )
                    )
                )
            )
            context.stroke(
                path,
                with: .color(
                    isSwapTarget
                        ? .orange
                        : (
                            isSelected || isDragged
                                ? .accentColor
                                : visualStyle.color
                        )
                ),
                style: StrokeStyle(
                    lineWidth:
                        isSwapTarget || isPrimarySelection || isDragged
                            ? 4
                            : (
                                isSelected
                                    ? 2.5
                                    : visualStyle.lineWidth
                            ),
                    dash:
                        isSwapTarget
                            ? [7, 4]
                            : visualStyle.dash
                )
            )

            if let opening =
                footprint
                    .frontOpeningV068 {
                drawFrontOpeningOnPlanV068(
                    opening:
                        opening,
                    points:
                        screenPoints,
                    color:
                        isSelected
                        || isDragged
                        ? .accentColor
                        : visualStyle
                            .color,
                    in: context
                )
            }

            let originalLabelPoint = projection.screenPoint(
                footprint.center
            )
            let labelPoint = CGPoint(
                x: originalLabelPoint.x + translation.width,
                y: originalLabelPoint.y + translation.height
            )
            let badgeRect = CGRect(
                x: labelPoint.x - 19,
                y: labelPoint.y - 11,
                width: 38,
                height: 22
            )

            context.fill(
                Path(
                    roundedRect: badgeRect,
                    cornerRadius: 7
                ),
                with: .color(
                    isSwapTarget
                        ? Color.orange
                        : (
                            isSelected || isDragged
                                ? Color.accentColor
                                : StolarniaPalette.drawingLabelFill
                        )
                )
            )
            context.stroke(
                Path(
                    roundedRect: badgeRect,
                    cornerRadius: 7
                ),
                with: .color(
                    isSwapTarget
                        ? Color.orange
                        : (
                            isSelected || isDragged
                                ? Color.accentColor
                                : visualStyle.color
                        )
                ),
                lineWidth: 1
            )
            context.draw(
                Text(label)
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(
                        isSelected || isDragged || isSwapTarget
                            ? Color.white
                            : visualStyle.color
                    ),
                at: labelPoint
            )
        }
    }

    private func drawFrontOpeningOnPlanV068(
        opening:
            KierunekOtwarciaFrontuV068,
        points:
            [CGPoint],
        color: Color,
        in context:
            GraphicsContext
    ) {
        guard points.count >= 4 else {
            return
        }

        let backStart = points[0]
        let frontEnd = points[2]
        let frontStart = points[3]
        let inwardVector =
            CGVector(
                dx:
                    frontStart.x
                    - backStart.x,
                dy:
                    frontStart.y
                    - backStart.y
            )
        let inwardLength =
            hypot(
                inwardVector.dx,
                inwardVector.dy
            )
        let frontVector =
            CGVector(
                dx:
                    frontEnd.x
                    - frontStart.x,
                dy:
                    frontEnd.y
                    - frontStart.y
            )
        let frontLength =
            hypot(
                frontVector.dx,
                frontVector.dy
            )

        guard
            inwardLength > 0.5,
            frontLength > 4
        else {
            return
        }

        let inward =
            CGVector(
                dx:
                    inwardVector.dx
                    / inwardLength,
                dy:
                    inwardVector.dy
                    / inwardLength
            )
        let frontDirection =
            CGVector(
                dx:
                    frontVector.dx
                    / frontLength,
                dy:
                    frontVector.dy
                    / frontLength
            )
        let leafLength =
            min(
                frontLength,
                max(
                    inwardLength,
                    26
                )
            )
        let center =
            CGPoint(
                x:
                    (
                        frontStart.x
                        + frontEnd.x
                    ) / 2,
                y:
                    (
                        frontStart.y
                        + frontEnd.y
                    ) / 2
            )
        let strokeColor =
            color.opacity(0.88)

        switch opening {
        case .lewy, .prawy:
            let hinge =
                opening == .lewy
                ? frontStart
                : frontEnd
            let closedEnd =
                opening == .lewy
                ? frontEnd
                : frontStart
            let openEnd =
                CGPoint(
                    x:
                        hinge.x
                        + inward.dx
                            * leafLength,
                    y:
                        hinge.y
                        + inward.dy
                            * leafLength
                )

            var leaf = Path()
            leaf.move(to: hinge)
            leaf.addLine(to: openEnd)
            context.stroke(
                leaf,
                with:
                    .color(
                        strokeColor
                    ),
                lineWidth: 1.4
            )

            var sweep = Path()
            sweep.move(
                to: closedEnd
            )
            sweep.addQuadCurve(
                to: openEnd,
                control:
                    CGPoint(
                        x:
                            hinge.x
                            + frontDirection.dx
                                * leafLength
                                * (
                                    opening
                                        == .lewy
                                    ? 0.55
                                    : -0.55
                                )
                            + inward.dx
                                * leafLength
                                * 0.55,
                        y:
                            hinge.y
                            + frontDirection.dy
                                * leafLength
                                * (
                                    opening
                                        == .lewy
                                    ? 0.55
                                    : -0.55
                                )
                            + inward.dy
                                * leafLength
                                * 0.55
                    )
            )
            context.stroke(
                sweep,
                with:
                    .color(
                        strokeColor
                            .opacity(0.62)
                    ),
                style:
                    StrokeStyle(
                        lineWidth: 1,
                        dash: [
                            4,
                            3
                        ]
                    )
            )

        case .szuflada:
            let offset =
                min(
                    max(
                        inwardLength
                            * 0.72,
                        20
                    ),
                    70
                )
            var path = Path()
            let start =
                CGPoint(
                    x:
                        frontStart.x
                        + inward.dx
                            * offset,
                    y:
                        frontStart.y
                        + inward.dy
                            * offset
                )
            let end =
                CGPoint(
                    x:
                        frontEnd.x
                        + inward.dx
                            * offset,
                    y:
                        frontEnd.y
                        + inward.dy
                            * offset
                )
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with:
                    .color(
                        strokeColor
                    ),
                style:
                    StrokeStyle(
                        lineWidth: 1.2,
                        dash: [
                            5,
                            3
                        ]
                    )
            )

            drawArrowHeadOnPlanV068(
                at:
                    CGPoint(
                        x:
                            center.x
                            + inward.dx
                                * offset,
                        y:
                            center.y
                            + inward.dy
                                * offset
                    ),
                direction:
                    inward,
                color:
                    strokeColor,
                in: context
            )

        case .doGory, .wDol:
            let direction =
                opening == .doGory
                ? inward
                : CGVector(
                    dx:
                        -inward.dx,
                    dy:
                        -inward.dy
                )
            let end =
                CGPoint(
                    x:
                        center.x
                        + direction.dx
                            * 28,
                    y:
                        center.y
                        + direction.dy
                            * 28
                )
            var path = Path()
            path.move(to: center)
            path.addLine(to: end)
            context.stroke(
                path,
                with:
                    .color(
                        strokeColor
                    ),
                lineWidth: 1.3
            )
            drawArrowHeadOnPlanV068(
                at: end,
                direction:
                    direction,
                color:
                    strokeColor,
                in: context
            )

        case .przesuwny:
            let start =
                CGPoint(
                    x:
                        center.x
                        - frontDirection.dx
                            * frontLength
                            * 0.34,
                    y:
                        center.y
                        - frontDirection.dy
                            * frontLength
                            * 0.34
                )
            let end =
                CGPoint(
                    x:
                        center.x
                        + frontDirection.dx
                            * frontLength
                            * 0.34,
                    y:
                        center.y
                        + frontDirection.dy
                            * frontLength
                            * 0.34
                )
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with:
                    .color(
                        strokeColor
                    ),
                lineWidth: 1.3
            )
            drawArrowHeadOnPlanV068(
                at: end,
                direction:
                    frontDirection,
                color:
                    strokeColor,
                in: context
            )
            drawArrowHeadOnPlanV068(
                at: start,
                direction:
                    CGVector(
                        dx:
                            -frontDirection.dx,
                        dy:
                            -frontDirection.dy
                    ),
                color:
                    strokeColor,
                in: context
            )

        case .staly:
            break
        }
    }

    private func drawArrowHeadOnPlanV068(
        at point:
            CGPoint,
        direction:
            CGVector,
        color: Color,
        in context:
            GraphicsContext
    ) {
        let normal =
            CGVector(
                dx:
                    -direction.dy,
                dy:
                    direction.dx
            )
        let back =
            CGPoint(
                x:
                    point.x
                    - direction.dx
                        * 7,
                y:
                    point.y
                    - direction.dy
                        * 7
            )
        var path = Path()
        path.move(
            to:
                CGPoint(
                    x:
                        back.x
                        + normal.dx
                            * 4,
                    y:
                        back.y
                        + normal.dy
                            * 4
                )
        )
        path.addLine(to: point)
        path.addLine(
            to:
                CGPoint(
                    x:
                        back.x
                        - normal.dx
                            * 4,
                    y:
                        back.y
                        - normal.dy
                            * 4
                )
        )
        context.stroke(
            path,
            with:
                .color(color),
            style:
                StrokeStyle(
                    lineWidth: 1.2,
                    lineCap: .round,
                    lineJoin: .round
                )
        )
    }

    private func drawArchitecturalFeatures(
        projection: Plan2DProjection,
        in context: GraphicsContext
    ) {
        for feature in WallFeatureGeometryV016.elements(
            in: room
        ) {
            let style = wallFeatureStyle(feature.kind)

            if let first = feature.linePoints.first {
                var path = Path()
                path.move(
                    to: projection.screenPoint(first)
                )
                for point in feature.linePoints.dropFirst() {
                    path.addLine(
                        to: projection.screenPoint(point)
                    )
                }
                context.stroke(
                    path,
                    with: .color(style.color),
                    style: StrokeStyle(
                        lineWidth: style.lineWidth,
                        lineCap: .round,
                        dash: style.dash
                    )
                )
            }

            if let first = feature.polygonPoints.first {
                var path = Path()
                path.move(
                    to: projection.screenPoint(first)
                )
                for point in feature.polygonPoints.dropFirst() {
                    path.addLine(
                        to: projection.screenPoint(point)
                    )
                }
                path.closeSubpath()

                context.fill(
                    path,
                    with: .color(
                        style.color.opacity(style.fillOpacity)
                    )
                )
                context.stroke(
                    path,
                    with: .color(style.color),
                    style: StrokeStyle(
                        lineWidth: style.lineWidth,
                        dash: style.dash
                    )
                )
            }

            let labelPoint = projection.screenPoint(
                feature.labelPoint
            )
            context.draw(
                Text(feature.code)
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(style.color),
                at: labelPoint
            )
        }
    }

    private func wallFeatureStyle(
        _ kind: WallFeaturePlanKindV016
    ) -> WallFeaturePlanVisualStyleV016 {
        switch kind {
        case .window:
            return WallFeaturePlanVisualStyleV016(
                color: .blue,
                lineWidth: 7,
                dash: [],
                fillOpacity: 0
            )
        case .door:
            return WallFeaturePlanVisualStyleV016(
                color: .brown,
                lineWidth: 5,
                dash: [7, 4],
                fillOpacity: 0
            )
        case .recess:
            return WallFeaturePlanVisualStyleV016(
                color: .purple,
                lineWidth: 2,
                dash: [5, 3],
                fillOpacity: 0.10
            )
        case .bayOutward:
            return WallFeaturePlanVisualStyleV016(
                color: .teal,
                lineWidth: 2.5,
                dash: [],
                fillOpacity: 0.12
            )
        case .bayInward:
            return WallFeaturePlanVisualStyleV016(
                color: .red,
                lineWidth: 2.5,
                dash: [],
                fillOpacity: 0.10
            )
        }
    }

    private func drawWall(
        _ wall: WallSegment,
        segment: ContourSegment2D,
        projection: Plan2DProjection,
        centroid: CGPoint,
        in context: GraphicsContext
    ) {
        let modelPoints = Plan2DGeometryAdapter.sampledPoints(for: segment)
        let points = modelPoints.map(projection.screenPoint)
        guard let start = points.first, let end = points.last else {
            return
        }

        let isSelected = wall.id == selectedWallID
        var wallPath = Path()
        wallPath.move(to: start)

        for point in points.dropFirst() {
            wallPath.addLine(to: point)
        }

        context.stroke(
            wallPath,
            with: .color(
                isSelected
                    ? Color.accentColor
                    : StolarniaPalette.drawingInk
            ),
            lineWidth: isSelected ? 6 : 3
        )

        let midpoint = points[points.count / 2]
        let outwardNormal = outwardNormal(
            start: start,
            end: end,
            midpoint: midpoint,
            centroid: centroid
        )
        let inwardNormal = CGVector(
            dx: -outwardNormal.dx,
            dy: -outwardNormal.dy
        )

        let wallNamePoint = offset(
            midpoint,
            by: inwardNormal,
            distance: 22
        )

        context.draw(
            Text(wall.name)
                .font(.caption.bold())
                .foregroundStyle(
                    isSelected
                        ? Color.accentColor
                        : StolarniaPalette.drawingMutedInk
                ),
            at: wallNamePoint
        )

        if let profile =
                SilnikSkosuPomieszczeniaV069
                    .profilSkosu(
                        dla: wall.id,
                        w: room
                    ) {
            let markerPoint =
                offset(
                    wallNamePoint,
                    by:
                        inwardNormal,
                    distance: 24
                )

            var marker =
                Path()
            marker.move(
                to:
                    CGPoint(
                        x:
                            markerPoint.x
                            - 10,
                        y:
                            markerPoint.y
                            + 7
                    )
            )
            marker.addLine(
                to:
                    CGPoint(
                        x:
                            markerPoint.x
                            + 10,
                        y:
                            markerPoint.y
                            + 7
                    )
            )
            marker.addLine(
                to:
                    CGPoint(
                        x:
                            markerPoint.x
                            + 10,
                        y:
                            markerPoint.y
                            - 7
                    )
            )
            marker.closeSubpath()

            context.fill(
                marker,
                with:
                    .color(
                        .purple.opacity(
                            0.18
                        )
                    )
            )
            context.stroke(
                marker,
                with:
                    .color(
                        .purple
                    ),
                style:
                    StrokeStyle(
                        lineWidth: 1.5,
                        dash: [4, 2]
                    )
            )

            context.draw(
                Text(
                    "SKOS \(profile.points.count)p"
                )
                .font(
                    .caption2
                        .bold()
                )
                .foregroundColor(
                    .purple
                ),
                at:
                    CGPoint(
                        x:
                            markerPoint.x,
                        y:
                            markerPoint.y
                            + 17
                    ),
                anchor:
                    .top
            )

            if let angle =
                    MebelElewacjaScianyGeometry
                        .katSkosuStopnie(
                            profil: profile
                        ) {
                let angleLabel =
                    angle.formatted(
                        .number.precision(
                            .fractionLength(1)
                        )
                    ) + "°"

                context.draw(
                    Text(angleLabel)
                        .font(
                            .caption2
                                .monospacedDigit()
                                .bold()
                        )
                        .foregroundColor(
                            .purple
                        ),
                    at:
                        CGPoint(
                            x:
                                markerPoint.x,
                            y:
                                markerPoint.y
                                + 30
                        ),
                    anchor:
                        .top
                )
            }
        }

        guard poziomWymiarowania != .ukryte else {
            return
        }

        switch segment {
        case .line:
            drawLinearDimension(
                length: segment.length,
                start: start,
                end: end,
                outwardNormal: outwardNormal,
                emphasis: isSelected
                    ? .zaznaczone
                    : .standardowe,
                in: context
            )

        case .arc:
            let labelPoint = offset(
                midpoint,
                by: outwardNormal,
                distance: 38
            )

            Wymiarowanie2DRenderer.drawLabel(
                in: context,
                text: formattedMillimeters(segment.length),
                at: labelPoint,
                emphasis: wall.id == selectedWallID
                    ? .zaznaczone
                    : .standardowe
            )
        }
    }

    private func drawLinearDimension(
        length: Millimeters,
        start: CGPoint,
        end: CGPoint,
        outwardNormal: CGVector,
        emphasis: WyroznienieWymiaru2D,
        in context: GraphicsContext
    ) {
        Wymiarowanie2DRenderer.drawLinearDimension(
            in: context,
            sourceStart: start,
            sourceEnd: end,
            offset: CGVector(
                dx: outwardNormal.dx * 40,
                dy: outwardNormal.dy * 40
            ),
            label: formattedMillimeters(length),
            emphasis: emphasis
        )
    }

    private func drawFurnitureDimensions(
        footprints: [MebelPlan2DFootprint],
        assemblyByID: [FurnitureAssemblyID: FurnitureAssembly],
        projection: Plan2DProjection,
        in context: GraphicsContext
    ) {
        guard poziomWymiarowania != .ukryte else {
            return
        }

        for footprint in footprints {
            guard let assembly = assemblyByID[footprint.id] else {
                continue
            }

            let isSelected =
                footprint.id == selectedFurnitureID
            let showsAllWidths =
                poziomWymiarowania == .szczegolowe
                && zoomScale >= 0.72

            guard isSelected || showsAllWidths else {
                continue
            }

            let translation =
                footprint.id == draggedFurnitureID
                ? furnitureDragTranslation
                : .zero
            let points = footprint.points
                .map(projection.screenPoint)
                .map {
                    CGPoint(
                        x: $0.x + translation.width,
                        y: $0.y + translation.height
                    )
                }
            guard points.count == 4 else {
                continue
            }

            let originalCenter = projection.screenPoint(
                footprint.center
            )
            let center = CGPoint(
                x: originalCenter.x + translation.width,
                y: originalCenter.y + translation.height
            )
            let widthStart = points[3]
            let widthEnd = points[2]
            let widthOffset = edgeOffset(
                start: widthStart,
                end: widthEnd,
                center: center,
                distance:
                    18 + CGFloat(footprint.layer.rawValue) * 10
            )
            let widthLabel = formattedMillimeters(
                assembly.size.width
            )
            let widthHasRoom =
                Wymiarowanie2DRenderer.hasRoomForLabel(
                    widthLabel,
                    start: widthStart,
                    end: widthEnd
                )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: widthStart,
                sourceEnd: widthEnd,
                offset: widthOffset,
                label: widthLabel,
                emphasis: isSelected
                    ? .zaznaczone
                    : .pomocnicze,
                showsLabel: isSelected || widthHasRoom
            )

            guard isSelected else {
                continue
            }

            let depthStart = points[1]
            let depthEnd = points[2]
            let depthOffset = edgeOffset(
                start: depthStart,
                end: depthEnd,
                center: center,
                distance: 20
            )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: depthStart,
                sourceEnd: depthEnd,
                offset: depthOffset,
                label: formattedMillimeters(
                    assembly.size.depth
                ),
                emphasis: .zaznaczone
            )
        }
    }

    private func drawSelectedWallDimensionChain(
        projection: Plan2DProjection,
        roomCentroid: CGPoint,
        in context: GraphicsContext
    ) {
        let activeWallID =
            selectedWallID
            ?? assemblies.first(where: {
                $0.id == selectedFurnitureID
            })?.placement?.wallID

        guard let activeWallID,
              let wall = room.geometry.wall(id: activeWallID),
              let segment = room.geometry.geometry(of: activeWallID),
              case .line = segment else {
            return
        }

        let wallPoints = Plan2DGeometryAdapter
            .sampledPoints(for: segment)
            .map(projection.screenPoint)

        guard let wallStart = wallPoints.first,
              let wallEnd = wallPoints.last,
              segment.length.rawValue > 0 else {
            return
        }

        let midpoint = CGPoint(
            x: (wallStart.x + wallEnd.x) / 2,
            y: (wallStart.y + wallEnd.y) / 2
        )
        let normal = outwardNormal(
            start: wallStart,
            end: wallEnd,
            midpoint: midpoint,
            centroid: roomCentroid
        )

        let selectedAssembly = assemblies.first {
            $0.id == selectedFurnitureID
        }
        let assembliesOnWall = assemblies.filter {
            $0.placement?.wallID == wall.id
        }
        let selectedKind = selectedAssembly.flatMap {
            KitchenRunAnalyzerV015.kind(of: $0)
        }
        let resolvedKind =
            selectedKind
            ?? [
                KitchenRunKindV015.base,
                .tall,
                .wall,
                .upper
            ]
            .first { kind in
                assembliesOnWall.contains {
                    KitchenRunAnalyzerV015.kind(of: $0)
                        == kind
                }
            }

        let wallAssemblies = assembliesOnWall
            .filter {
                guard let resolvedKind else {
                    return false
                }

                return KitchenRunAnalyzerV015.kind(of: $0)
                    == resolvedKind
            }
            .sorted {
                ($0.placement?.offsetAlongWall ?? .zero)
                    < ($1.placement?.offsetAlongWall ?? .zero)
            }

        guard !wallAssemblies.isEmpty else {
            return
        }

        struct ChainSegment {
            let start: Millimeters
            let end: Millimeters
            let label: String
            let emphasis: WyroznienieWymiaru2D
            let isFurniture: Bool
        }

        var chain: [ChainSegment] = []
        var cursor: Millimeters = .zero

        for assembly in wallAssemblies {
            guard let placement = assembly.placement else {
                continue
            }

            let start = clamped(
                placement.offsetAlongWall,
                lower: .zero,
                upper: segment.length
            )
            let end = clamped(
                placement.offsetAlongWall + assembly.size.width,
                lower: .zero,
                upper: segment.length
            )

            if start.rawValue - cursor.rawValue > 0.5 {
                chain.append(
                    ChainSegment(
                        start: cursor,
                        end: start,
                        label: formattedMillimeters(start - cursor),
                        emphasis: .pomocnicze,
                        isFurniture: false
                    )
                )
            }

            if end > start {
                chain.append(
                    ChainSegment(
                        start: start,
                        end: end,
                        label: formattedMillimeters(end - start),
                        emphasis:
                            assembly.id == selectedFurnitureID
                            ? .zaznaczone
                            : .standardowe,
                        isFurniture: true
                    )
                )
                cursor = maxMillimeters(cursor, end)
            }
        }

        if segment.length.rawValue - cursor.rawValue > 0.5 {
            chain.append(
                ChainSegment(
                    start: cursor,
                    end: segment.length,
                    label: formattedMillimeters(segment.length - cursor),
                    emphasis: .pomocnicze,
                    isFurniture: false
                )
            )
        }

        for item in chain {
            let sourceStart = point(
                along: wallStart,
                end: wallEnd,
                offset: item.start,
                totalLength: segment.length
            )
            let sourceEnd = point(
                along: wallStart,
                end: wallEnd,
                offset: item.end,
                totalLength: segment.length
            )
            let dimensionOffset = CGVector(
                dx: normal.dx * 78,
                dy: normal.dy * 78
            )
            let showsLabel =
                item.emphasis == .zaznaczone
                || Wymiarowanie2DRenderer.hasRoomForLabel(
                    item.label,
                    start: sourceStart,
                    end: sourceEnd,
                    minimumPadding: item.isFurniture ? 8 : 12
                )

            Wymiarowanie2DRenderer.drawLinearDimension(
                in: context,
                sourceStart: sourceStart,
                sourceEnd: sourceEnd,
                offset: dimensionOffset,
                label: item.label,
                emphasis: item.emphasis,
                showsLabel: showsLabel
            )
        }
    }

    private func point(
        along start: CGPoint,
        end: CGPoint,
        offset: Millimeters,
        totalLength: Millimeters
    ) -> CGPoint {
        let progress = min(
            max(
                offset.rawValue
                    / max(totalLength.rawValue, 0.001),
                0
            ),
            1
        )

        return CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private func clamped(
        _ value: Millimeters,
        lower: Millimeters,
        upper: Millimeters
    ) -> Millimeters {
        Millimeters(
            min(
                max(value.rawValue, lower.rawValue),
                upper.rawValue
            )
        )
    }

    private func maxMillimeters(
        _ lhs: Millimeters,
        _ rhs: Millimeters
    ) -> Millimeters {
        lhs >= rhs ? lhs : rhs
    }

    private func edgeOffset(
        start: CGPoint,
        end: CGPoint,
        center: CGPoint,
        distance: CGFloat
    ) -> CGVector {
        let midpoint = CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
        let fromCenter = CGVector(
            dx: midpoint.x - center.x,
            dy: midpoint.y - center.y
        )
        let length = max(
            hypot(fromCenter.dx, fromCenter.dy),
            0.001
        )

        return CGVector(
            dx: fromCenter.dx / length * distance,
            dy: fromCenter.dy / length * distance
        )
    }

    private func dimensionEditContext(
        at location: CGPoint,
        size: CGSize
    ) -> KontekstEdycjiWymiaru2D? {
        guard poziomWymiarowania != .ukryte,
              onEditDimension != nil else {
            return nil
        }

        let sampledSegments = room.geometry.boundary.segments.map {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }
        let allPoints = sampledSegments.flatMap { $0 }

        guard !allPoints.isEmpty else {
            return nil
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )
        let screenPoints = allPoints.map(projection.screenPoint)
        let roomCentroid = centroid(of: screenPoints)
        let footprints = MebelPlan2DGeometry.footprints(
            for: assemblies,
            in: room
        )
        let assemblyByID: [FurnitureAssemblyID: FurnitureAssembly] =
            Dictionary(
                assemblies.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )

        // Wymiary zaznaczonego mebla mają pierwszeństwo przed ścianą.
        for footprint in footprints.reversed() {
            guard let assembly = assemblyByID[footprint.id] else {
                continue
            }

            let isSelected =
                footprint.id == selectedFurnitureID
            let showsAllWidths =
                poziomWymiarowania == .szczegolowe
                && zoomScale >= 0.72

            guard isSelected || showsAllWidths else {
                continue
            }

            let points = footprint.points.map(
                projection.screenPoint
            )
            guard points.count == 4 else {
                continue
            }

            let center = projection.screenPoint(
                footprint.center
            )
            let widthStart = points[3]
            let widthEnd = points[2]
            let widthOffset = edgeOffset(
                start: widthStart,
                end: widthEnd,
                center: center,
                distance:
                    18 + CGFloat(footprint.layer.rawValue) * 10
            )
            let widthLabel = formattedMillimeters(
                assembly.size.width
            )
            let widthHasRoom =
                Wymiarowanie2DRenderer.hasRoomForLabel(
                    widthLabel,
                    start: widthStart,
                    end: widthEnd
                )

            if (isSelected || widthHasRoom),
               Wymiarowanie2DRenderer.contains(
                   point: location,
                   label: widthLabel,
                   center:
                       Wymiarowanie2DRenderer.labelCenter(
                           sourceStart: widthStart,
                           sourceEnd: widthEnd,
                           offset: widthOffset
                       )
               ) {
                return .szerokoscModulu(
                    furnitureID: assembly.id,
                    nazwa: assembly.name,
                    wartosc: assembly.size.width
                )
            }

            guard isSelected else {
                continue
            }

            let depthStart = points[1]
            let depthEnd = points[2]
            let depthOffset = edgeOffset(
                start: depthStart,
                end: depthEnd,
                center: center,
                distance: 20
            )
            let depthLabel = formattedMillimeters(
                assembly.size.depth
            )

            if Wymiarowanie2DRenderer.contains(
                point: location,
                label: depthLabel,
                center:
                    Wymiarowanie2DRenderer.labelCenter(
                        sourceStart: depthStart,
                        sourceEnd: depthEnd,
                        offset: depthOffset
                    )
            ) {
                return .glebokoscModulu(
                    furnitureID: assembly.id,
                    nazwa: assembly.name,
                    wartosc: assembly.size.depth
                )
            }
        }

        for wall in room.geometry.walls.reversed() {
            guard let segment = room.geometry.geometry(
                of: wall.id
            ),
            case .line = segment else {
                continue
            }

            let points = Plan2DGeometryAdapter
                .sampledPoints(for: segment)
                .map(projection.screenPoint)

            guard let start = points.first,
                  let end = points.last else {
                continue
            }

            let midpoint = points[points.count / 2]
            let normal = outwardNormal(
                start: start,
                end: end,
                midpoint: midpoint,
                centroid: roomCentroid
            )
            let dimensionOffset = CGVector(
                dx: normal.dx * 40,
                dy: normal.dy * 40
            )
            let label = formattedMillimeters(
                segment.length
            )

            if Wymiarowanie2DRenderer.contains(
                point: location,
                label: label,
                center:
                    Wymiarowanie2DRenderer.labelCenter(
                        sourceStart: start,
                        sourceEnd: end,
                        offset: dimensionOffset
                    )
            ) {
                return .dlugoscSciany(
                    wallID: wall.id,
                    nazwa: wall.name,
                    wartosc: segment.length
                )
            }
        }

        return nil
    }

    private func constrainedFurnitureTranslation(
        for furnitureID: FurnitureAssemblyID,
        translation: CGSize,
        size: CGSize
    ) -> CGSize {
        guard let assembly = assemblies.first(where: {
            $0.id == furnitureID
        }),
        let placement = assembly.placement else {
            return translation
        }

        guard placement.anchoringMode != .freestanding,
              let wallID = placement.wallID,
              let segment = room.geometry.geometry(of: wallID),
              case .line = segment else {
            return translation
        }

        let allPoints = room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }
        guard !allPoints.isEmpty else {
            return translation
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )
        let wallPoints = Plan2DGeometryAdapter
            .sampledPoints(for: segment)
            .map(projection.screenPoint)

        guard let start = wallPoints.first,
              let end = wallPoints.last else {
            return translation
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.001 else {
            return translation
        }

        let unitX = dx / length
        let unitY = dy / length
        let scalar =
            translation.width * unitX
            + translation.height * unitY

        return CGSize(
            width: unitX * scalar,
            height: unitY * scalar
        )
    }

    private func translationForMovement(
        _ movement: KontekstPrzesunieciaModulu2D,
        furnitureID: FurnitureAssemblyID,
        size: CGSize
    ) -> CGSize {
        guard let assembly = assemblies.first(where: {
            $0.id == furnitureID
        }),
        let placement = assembly.placement else {
            return .zero
        }

        let allPoints = room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }
        guard !allPoints.isEmpty else {
            return .zero
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )

        if placement.anchoringMode == .freestanding
            || placement.wallID == nil {
            let currentCenter = Point2MM(
                x: placement.offsetAlongWall
                    + assembly.size.width / 2,
                y: placement.offsetFromWall
                    + assembly.size.depth / 2
            )
            let proposedCenter = Point2MM(
                x: movement.proponowaneOdsuniecie
                    + assembly.size.width / 2,
                y: (movement.proponowaneOdsuniecieOdSciany
                    ?? placement.offsetFromWall)
                    + assembly.size.depth / 2
            )
            let currentPoint =
                projection.screenPoint(currentCenter)
            let proposedPoint =
                projection.screenPoint(proposedCenter)

            return CGSize(
                width: proposedPoint.x - currentPoint.x,
                height: proposedPoint.y - currentPoint.y
            )
        }

        guard let wallID = placement.wallID,
              let segment = room.geometry.geometry(of: wallID),
              case .line = segment else {
            return .zero
        }

        let wallPoints = Plan2DGeometryAdapter
            .sampledPoints(for: segment)
            .map(projection.screenPoint)

        guard let start = wallPoints.first,
              let end = wallPoints.last else {
            return .zero
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let screenLength = hypot(dx, dy)
        guard screenLength > 0.001,
              segment.length.rawValue > 0.001 else {
            return .zero
        }

        let unitX = dx / screenLength
        let unitY = dy / screenLength
        let pixelsPerMillimeter =
            screenLength / CGFloat(segment.length.rawValue)
        let deltaMillimeters =
            movement.proponowaneOdsuniecie.rawValue
            - placement.offsetAlongWall.rawValue
        let scalar =
            CGFloat(deltaMillimeters) * pixelsPerMillimeter

        return CGSize(
            width: unitX * scalar,
            height: unitY * scalar
        )
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
        size: CGSize
    ) -> KontekstPrzesunieciaModulu2D? {
        guard let assembly = assemblies.first(where: {
            $0.id == furnitureID
        }),
        let placement = assembly.placement else {
            return nil
        }

        let allPoints = room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }
        guard !allPoints.isEmpty else {
            return nil
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )

        if placement.anchoringMode == .freestanding
            || placement.wallID == nil {
            return freestandingMovementContext(
                for: assembly,
                at: location,
                projection: projection,
                roomPoints: allPoints
            )
        }

        guard let wallID = placement.wallID,
              let segment = room.geometry.geometry(of: wallID),
              case .line = segment else {
            return nil
        }

        let wallPoints = Plan2DGeometryAdapter
            .sampledPoints(for: segment)
            .map(projection.screenPoint)

        guard let wallStart = wallPoints.first,
              let wallEnd = wallPoints.last else {
            return nil
        }

        let dx = wallEnd.x - wallStart.x
        let dy = wallEnd.y - wallStart.y
        let squaredLength = dx * dx + dy * dy
        let screenLength = sqrt(squaredLength)

        guard squaredLength > 0.001,
              screenLength > 0.001 else {
            return nil
        }

        let rawProgress =
            (
                (location.x - wallStart.x) * dx
                + (location.y - wallStart.y) * dy
            )
            / squaredLength
        let progress = min(max(rawProgress, 0), 1)
        let dropAlongWall =
            segment.length.rawValue * Double(progress)

        let maximumOffset = max(
            segment.length.rawValue
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
            segment.length.rawValue / Double(screenLength)
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
                dlugoscSciany: segment.length,
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

        // Zamiana jest aktywowana dopiero w środkowej strefie modułu.
        // Krawędzie pozostają zarezerwowane dla precyzyjnego snapu.
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

        return KontekstPrzesunieciaModulu2D(
            furnitureID: assembly.id,
            wallID: wallID,
            proponowaneOdsuniecie: proposedOffset,
            celZamianyID: swapTarget?.id,
            przyciagniecie: snap
        )
    }

    private func freestandingMovementContext(
        for assembly: FurnitureAssembly,
        at location: CGPoint,
        projection: Plan2DProjection,
        roomPoints: [Point2MM]
    ) -> KontekstPrzesunieciaModulu2D? {
        guard !roomPoints.isEmpty else {
            return nil
        }

        let bounds = modelBounds(roomPoints)
        let modelPoint = projection.modelPoint(location)
        let maximumX = max(
            bounds.maxX - assembly.size.width.rawValue,
            bounds.minX
        )
        let maximumY = max(
            bounds.maxY - assembly.size.depth.rawValue,
            bounds.minY
        )
        let centeredX =
            modelPoint.x.rawValue
            - assembly.size.width.rawValue / 2
        let centeredY =
            modelPoint.y.rawValue
            - assembly.size.depth.rawValue / 2
        let rawX = min(
            max(centeredX, bounds.minX),
            maximumX
        )
        let rawY = min(
            max(centeredY, bounds.minY),
            maximumY
        )

        return KontekstPrzesunieciaModulu2D(
            furnitureID: assembly.id,
            wallID: nil,
            proponowaneOdsuniecie:
                PrzyciaganieModulow2D.odsuniecieDoSiatki(
                    Millimeters(rawX)
                ),
            proponowaneOdsuniecieOdSciany:
                PrzyciaganieModulow2D.odsuniecieDoSiatki(
                    Millimeters(rawY)
                ),
            celZamianyID: nil,
            przyciagniecie: nil
        )
    }

    private func modelBounds(
        _ points: [Point2MM]
    ) -> (
        minX: Double,
        maxX: Double,
        minY: Double,
        maxY: Double
    ) {
        (
            minX: points.map(\.x.rawValue).min() ?? 0,
            maxX: points.map(\.x.rawValue).max() ?? 0,
            minY: points.map(\.y.rawValue).min() ?? 0,
            maxY: points.map(\.y.rawValue).max() ?? 0
        )
    }

    private func drawActiveSnapGuide(
        projection: Plan2DProjection,
        in context: GraphicsContext
    ) {
        guard let draggedFurnitureID,
              let snap = aktywnePrzyciagniecie,
              let assembly = assemblies.first(where: {
                  $0.id == draggedFurnitureID
              }),
              let wallID = assembly.placement?.wallID,
              let segment = room.geometry.geometry(of: wallID),
              case .line = segment else {
            return
        }

        let wallPoints = Plan2DGeometryAdapter
            .sampledPoints(for: segment)
            .map(projection.screenPoint)
        guard let start = wallPoints.first,
              let end = wallPoints.last,
              segment.length.rawValue > 0.001 else {
            return
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let screenLength = hypot(dx, dy)
        guard screenLength > 0.001 else {
            return
        }

        let progress = min(
            max(
                snap.liniaProwadzaca.rawValue
                / segment.length.rawValue,
                0
            ),
            1
        )
        let anchor = CGPoint(
            x: start.x + dx * CGFloat(progress),
            y: start.y + dy * CGFloat(progress)
        )
        let normal = CGVector(
            dx: -dy / screenLength,
            dy: dx / screenLength
        )
        let guideStart = CGPoint(
            x: anchor.x - normal.dx * 48,
            y: anchor.y - normal.dy * 48
        )
        let guideEnd = CGPoint(
            x: anchor.x + normal.dx * 48,
            y: anchor.y + normal.dy * 48
        )

        var path = Path()
        path.move(to: guideStart)
        path.addLine(to: guideEnd)
        context.stroke(
            path,
            with: .color(Color.accentColor),
            style: StrokeStyle(
                lineWidth: 2,
                dash: [5, 4]
            )
        )

        let labelPoint = CGPoint(
            x: guideEnd.x + normal.dx * 14,
            y: guideEnd.y + normal.dy * 14
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
                .foregroundStyle(Color.accentColor),
            at: labelPoint,
            anchor: .center
        )
    }

    private func furnitureID(
        at location: CGPoint,
        size: CGSize
    ) -> FurnitureAssemblyID? {
        let allPoints = room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }
        guard !allPoints.isEmpty else {
            return nil
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )

        for footprint in MebelPlan2DGeometry
            .footprints(for: assemblies, in: room)
            .reversed() {
            guard let first = footprint.points.first else {
                continue
            }

            var path = Path()
            path.move(to: projection.screenPoint(first))
            for point in footprint.points.dropFirst() {
                path.addLine(to: projection.screenPoint(point))
            }
            path.closeSubpath()

            if path.contains(location) {
                return footprint.id
            }
        }

        return nil
    }

    private func wallID(
        at location: CGPoint,
        size: CGSize
    ) -> WallID? {
        let allPoints = room.geometry.boundary.segments.flatMap {
            Plan2DGeometryAdapter.sampledPoints(for: $0)
        }

        guard !allPoints.isEmpty else {
            return nil
        }

        let projection = Plan2DProjection(
            points: allPoints,
            size: size,
            padding: projectionPadding,
            zoomScale: zoomScale,
            panOffset: panOffset
        )

        let candidates = room.geometry.walls.compactMap { wall -> (WallID, CGFloat)? in
            guard let segment = room.geometry.geometry(of: wall.id) else {
                return nil
            }

            let polyline = Plan2DGeometryAdapter
                .sampledPoints(for: segment)
                .map(projection.screenPoint)

            let distance = Plan2DGeometryAdapter.distance(
                from: location,
                to: polyline
            )

            return (wall.id, distance)
        }

        guard let nearest = candidates.min(by: { $0.1 < $1.1 }),
              nearest.1 <= 28 else {
            return nil
        }

        return nearest.0
    }

    private func outwardNormal(
        start: CGPoint,
        end: CGPoint,
        midpoint: CGPoint,
        centroid: CGPoint
    ) -> CGVector {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.001)

        let first = CGVector(
            dx: -dy / length,
            dy: dx / length
        )
        let second = CGVector(
            dx: -first.dx,
            dy: -first.dy
        )
        let awayFromCentroid = CGVector(
            dx: midpoint.x - centroid.x,
            dy: midpoint.y - centroid.y
        )

        let firstDot = first.dx * awayFromCentroid.dx
            + first.dy * awayFromCentroid.dy

        return firstDot >= 0 ? first : second
    }

    private func centroid(
        of points: [CGPoint]
    ) -> CGPoint {
        guard !points.isEmpty else {
            return .zero
        }

        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(
                x: partial.x + point.x,
                y: partial.y + point.y
            )
        }

        return CGPoint(
            x: sum.x / CGFloat(points.count),
            y: sum.y / CGFloat(points.count)
        )
    }

    private func offset(
        _ point: CGPoint,
        by vector: CGVector,
        distance: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: point.x + vector.dx * distance,
            y: point.y + vector.dy * distance
        )
    }

    private var furnitureLegend: some View {
        HStack(spacing: 10) {
            legendItem(layer: .dolna, title: "Dolne")
            legendItem(layer: .wiszaca, title: "Wiszące")
            legendItem(layer: .gorna, title: "Nadstawki")
            legendItem(layer: .wysoka, title: "Wysokie")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .stolarniaMaterial(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private func legendItem(
        layer: MebelPlan2DWarstwa,
        title: String
    ) -> some View {
        let style = furnitureStyle(for: layer)

        return HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(style.color.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(style.color, lineWidth: 1.5)
                }
                .frame(width: 15, height: 10)

            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private func furnitureStyle(
        for layer: MebelPlan2DWarstwa
    ) -> FurniturePlan2DVisualStyle {
        let materialColor = Color(
            stolarniaHEX:
                globalneMaterialy.korpus.kolorHEX
        )

        switch layer {
        case .dolna:
            return FurniturePlan2DVisualStyle(
                color: materialColor,
                fillOpacity: 0.28,
                lineWidth: 2,
                dash: []
            )

        case .wiszaca:
            return FurniturePlan2DVisualStyle(
                color: materialColor,
                fillOpacity: 0.20,
                lineWidth: 2,
                dash: [7, 4]
            )

        case .gorna:
            return FurniturePlan2DVisualStyle(
                color: materialColor,
                fillOpacity: 0.16,
                lineWidth: 2,
                dash: [3, 3]
            )

        case .wysoka:
            return FurniturePlan2DVisualStyle(
                color: materialColor,
                fillOpacity: 0.34,
                lineWidth: 2.5,
                dash: []
            )
        }
    }

    private func formattedMillimeters(
        _ value: Millimeters
    ) -> String {
        let formatted = value.rawValue.formatted(
            .number.precision(.fractionLength(0...1))
        )

        return "\(formatted) mm"
    }
}


private struct WallFeaturePlanVisualStyleV016 {
    let color: Color
    let lineWidth: CGFloat
    let dash: [CGFloat]
    let fillOpacity: Double
}

private struct FurniturePlan2DVisualStyle {
    let color: Color
    let fillOpacity: Double
    let lineWidth: CGFloat
    let dash: [CGFloat]
}
