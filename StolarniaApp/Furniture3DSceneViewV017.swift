import DomainCore
import RealityKit
import SwiftUI
import UIKit

enum Furniture3DCameraCommandV017: Equatable {
    case none
    case yaw(Float)
    case pitch(Float)
    case setOrientation(yaw: Float, pitch: Float)
}

struct Furniture3DPresentationStateV017: Equatable {
    var doorsOpen = false
    var drawersOpen = false
    var slidingDoorsOpen = false
    var accessoriesVisible = true
    var exploded = false
    var autoSequenceToken = 0
    var frontViewToken = 0
    var cameraCommand:
        Furniture3DCameraCommandV017 = .none
    var cameraCommandToken = 0
}

struct Furniture3DSceneViewV017: UIViewRepresentable {
    let assemblies: [FurnitureAssembly]
    let state: Furniture3DPresentationStateV017
    let globalneMaterialy:
        GlobalneMaterialyPomieszczenia
    let room: RoomDefinition?
    /// Lista materiałów z BazaMaterialow — używana do
    /// wczytywania kolorów per-moduł (korpus / front).
    let materialy: [MaterialStolarski]

    init(
        assemblies: [FurnitureAssembly],
        state: Furniture3DPresentationStateV017,
        globalneMaterialy:
            GlobalneMaterialyPomieszczenia,
        room: RoomDefinition? = nil,
        materialy: [MaterialStolarski] = []
    ) {
        self.assemblies = assemblies
        self.state = state
        self.globalneMaterialy =
            globalneMaterialy
        self.room = room
        self.materialy = materialy
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        view.environment.background = .color(.systemBackground)
        view.isOpaque = true
        context.coordinator.configure(
            view: view,
            assemblies: assemblies,
            globalneMaterialy:
                globalneMaterialy,
            room: room,
            materialy: materialy
        )
        return view
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {
        context.coordinator.update(
            state: state,
            globalneMaterialy:
                globalneMaterialy,
            assemblies: assemblies,
            room: room,
            materialy: materialy
        )
    }

    final class Coordinator: NSObject {
        private weak var view: ARView?
        private let root = Entity()
        private let modelRoot = Entity()
        private let camera = PerspectiveCamera()

        private var doorMotions: [Motion] = []
        private var drawerMotions: [Motion] = []
        private var slidingMotions: [Motion] = []
        private var accessoryEntities: [Entity] = []
        private var explodedMotions: [Motion] = []

        private var currentState =
            Furniture3DPresentationStateV017()
        private var currentGlobalneMaterialy =
            GlobalneMaterialyPomieszczenia
                .domyslne(roomID: "")
        private var currentMaterialy:
            [MaterialStolarski] = []
        private var lastAssemblies:
            [FurnitureAssembly] = []
        private var currentRoom:
            RoomDefinition?
        /// Kolory aktualnie budowanego modułu (korpus / front).
        /// Ustawiane przez prepareAssemblyColors przed każdym montażem.
        private var currentAssemblyKorpusColor: UIColor?
        private var currentAssemblyFrontColor: UIColor?

        private var cameraDistance: Float = 3.2
        private var cameraTarget = SIMD3<Float>.zero
        private var cameraYaw: Float = 0
        private var cameraPitch: Float = -(Float.pi * 0.10)

        private var meshCache: [MeshKey: MeshResource] = [:]
        /// Klucz: "<assemblyID>_<role.rawValue>" — każdy moduł ma własną paletę.
        private var materialCache: [String: SimpleMaterial] = [:]
        private var currentAssemblyIDString: String = ""

        private var lastCameraUpdateTime: CFTimeInterval = 0
        private let minimumCameraUpdateInterval:
            CFTimeInterval = 1.0 / 60.0

        private struct MeshKey: Hashable {
            let x: Int
            let y: Int
            let z: Int

            init(_ size: SIMD3<Float>) {
                x = Int((size.x * 10_000).rounded())
                y = Int((size.y * 10_000).rounded())
                z = Int((size.z * 10_000).rounded())
            }
        }

        private struct Motion {
            let entity: Entity
            let closed: Transform
            let open: Transform
        }

        @MainActor
        func configure(
            view: ARView,
            assemblies: [FurnitureAssembly],
            globalneMaterialy:
                GlobalneMaterialyPomieszczenia,
            room: RoomDefinition?,
            materialy: [MaterialStolarski]
        ) {
            self.view = view
            self.lastAssemblies = assemblies
            self.currentGlobalneMaterialy =
                globalneMaterialy
            self.currentMaterialy = materialy
            self.currentRoom = room

            root.addChild(modelRoot)
            view.scene.addAnchor(
                AnchorEntity(world: .zero)
            )
            guard let anchor =
                view.scene.anchors.first
            else {
                return
            }
            anchor.addChild(root)
            anchor.addChild(camera)

            view.cameraMode = .nonAR

            addLighting(to: anchor)
            buildScene(from: assemblies)
            installGestures(on: view)
            frameModel()
        }

        @MainActor
        func update(
            state:
                Furniture3DPresentationStateV017,
            globalneMaterialy:
                GlobalneMaterialyPomieszczenia,
            assemblies: [FurnitureAssembly],
            room: RoomDefinition?,
            materialy: [MaterialStolarski]
        ) {
            let materialyIDs = materialy.map(\.id)
            let currentMaterialyIDs = currentMaterialy.map(\.id)
            let geometryChanged =
                assemblies != lastAssemblies
                || room != currentRoom
                || globalneMaterialy
                    != currentGlobalneMaterialy
                || materialyIDs != currentMaterialyIDs

            if geometryChanged {
                lastAssemblies = assemblies
                currentRoom = room
                currentGlobalneMaterialy =
                    globalneMaterialy
                currentMaterialy = materialy

                buildScene(
                    from: assemblies
                )
                frameModel()

                let desiredState = state
                currentState =
                    Furniture3DPresentationStateV017()
                applyPresentationState(
                    desiredState
                )
                return
            }

            applyPresentationState(
                state
            )
        }

        @MainActor
        private func applyPresentationState(
            _ state:
                Furniture3DPresentationStateV017
        ) {
            guard state != currentState else {
                return
            }

            let previous = currentState
            currentState = state

            if state.frontViewToken
                != previous.frontViewToken {
                resetCameraOrientation()
                frameModel()
            }

            if state.cameraCommandToken
                != previous.cameraCommandToken {
                applyCameraCommand(
                    state.cameraCommand
                )
            }

            if state.doorsOpen
                != previous.doorsOpen {
                animate(
                    doorMotions,
                    open: state.doorsOpen
                )
            }

            if state.drawersOpen
                != previous.drawersOpen {
                animate(
                    drawerMotions,
                    open: state.drawersOpen
                )
            }

            if state.slidingDoorsOpen
                != previous.slidingDoorsOpen {
                animate(
                    slidingMotions,
                    open:
                        state.slidingDoorsOpen
                )
            }

            if state.exploded
                != previous.exploded {
                animate(
                    explodedMotions,
                    open: state.exploded
                )
            }

            if state.accessoriesVisible
                != previous.accessoriesVisible {
                setAccessoriesVisible(
                    state.accessoriesVisible
                )
            }

            if state.autoSequenceToken
                != previous.autoSequenceToken {
                playAutomaticSequence()
            }
        }

        @MainActor
        private func buildScene(
            from assemblies: [FurnitureAssembly]
        ) {
            modelRoot.children.removeAll()
            doorMotions.removeAll()
            drawerMotions.removeAll()
            slidingMotions.removeAll()
            accessoryEntities.removeAll()
            explodedMotions.removeAll()
            meshCache.removeAll(keepingCapacity: true)
            materialCache.removeAll(keepingCapacity: true)
            currentAssemblyIDString = ""
            currentAssemblyKorpusColor = nil
            currentAssemblyFrontColor = nil

            let sorted = assemblies.sorted {
                ($0.placement?.offsetAlongWall.rawValue ?? 0)
                <
                ($1.placement?.offsetAlongWall.rawValue ?? 0)
            }
            for (index, assembly) in sorted.enumerated() {
                // Przygotuj kolory z BazaMaterialow dla tego modułu.
                prepareAssemblyColors(for: assembly)
                currentAssemblyIDString =
                    assembly.id.description

                let assemblyRoot = Entity()
                assemblyRoot.name = assembly.name

                let x = meters(
                    assembly.placement?.offsetAlongWall
                        ?? .zero
                )
                let y = meters(
                    assembly.placement?.bottomOffset
                        ?? .zero
                )
                let z = -meters(
                    assembly.placement?.offsetFromWall
                        ?? .zero
                )

                assemblyRoot.position = SIMD3<Float>(x, y, z)
                modelRoot.addChild(assemblyRoot)

                let baseComponents =
                    assembly.components.isEmpty
                    ? fallbackComponents(
                        for: assembly
                    )
                    : assembly.components
                let components =
                    GeometriaSzuflad3DV068
                        .uzupelnioneKomponenty(
                            assembly:
                                assembly,
                            bazowe:
                                baseComponents
                        )

                let slopeProfile:
                    WallProfileDefinition?
                if
                    let room = currentRoom,
                    let wallID =
                        assembly
                            .placement?
                            .wallID
                {
                    slopeProfile =
                        SilnikSkosuPomieszczeniaV069
                            .profilSkosu(
                                dla: wallID,
                                w: room
                            )
                } else {
                    slopeProfile = nil
                }

                let activeSlopeProfile:
                    WallProfileDefinition?
                if
                    let slopeProfile,
                    let localContour =
                        PaneleProdukcyjneSkosuV0691
                            .lokalnyKonturZespolu(
                                assembly: assembly,
                                profil:
                                    slopeProfile
                            ),
                    PaneleProdukcyjneSkosuV0691
                        .jestKonturemScietym(
                            localContour,
                            oczekiwanaWysokoscMM:
                                assembly
                                    .size
                                    .height
                                    .rawValue
                        )
                {
                    activeSlopeProfile =
                        slopeProfile
                } else {
                    activeSlopeProfile = nil
                }

                for (componentIndex, component) in
                    components.enumerated() {
                    add(
                        component: component,
                        componentIndex: componentIndex,
                        allComponents:
                            components,
                        assembly: assembly,
                        assemblyRoot: assemblyRoot,
                        slopeProfile:
                            activeSlopeProfile
                    )
                }

                if let activeSlopeProfile {
                    addSlopedTopV0691(
                        assembly: assembly,
                        assemblyRoot:
                            assemblyRoot,
                        profile:
                            activeSlopeProfile
                    )
                }

                addGeneratedAccessoryIfNeeded(
                    to: assemblyRoot,
                    assembly: assembly
                )

                let closed = assemblyRoot.transform
                var exploded = closed
                exploded.translation += SIMD3<Float>(
                    Float(index % 3 - 1) * 0.08,
                    Float(index / 3) * 0.04,
                    Float(index % 2) * 0.08
                )
                explodedMotions.append(
                    Motion(
                        entity: assemblyRoot,
                        closed: closed,
                        open: exploded
                    )
                )
            }
        }

        @MainActor
        private func add(
            component: FurnitureComponent,
            componentIndex: Int,
            allComponents:
                [FurnitureComponent],
            assembly: FurnitureAssembly,
            assemblyRoot: Entity,
            slopeProfile:
                WallProfileDefinition?
        ) {
            if
                let slopeProfile,
                addSlopedComponentV0691(
                    component: component,
                    componentIndex:
                        componentIndex,
                    allComponents:
                        allComponents,
                    assembly: assembly,
                    assemblyRoot:
                        assemblyRoot,
                    profile:
                        slopeProfile
                )
            {
                return
            }

            if
                slopeProfile != nil,
                component.role == .top
            {
                // Górny wieniec pod skosem jest generowany jako
                // osobne odcinki o właściwym kącie.
                return
            }

            let size = SIMD3<Float>(
                meters(component.size.width),
                meters(component.size.height),
                meters(component.size.depth)
            )

            let safeSize = maxVector(
                size,
                minimum: 0.004
            )
            let mesh = cachedMesh(for: safeSize)
            let material = cachedMaterial(
                for: component.role
            )
            let model = ModelEntity(
                mesh: mesh,
                materials: [material]
            )
            model.name = component.code

            let center = inferredCenter(
                component: component,
                componentIndex: componentIndex,
                assembly: assembly
            )

            switch motionKind(
                component: component,
                assembly: assembly
            ) {
            case .hingedDoor:
                let opensRight = shouldOpenRight(
                    component: component,
                    componentIndex:
                        componentIndex,
                    assembly:
                        assembly
                )
                let pivot = Entity()
                pivot.position = SIMD3<Float>(
                    opensRight
                        ? center.x + size.x / 2
                        : center.x - size.x / 2,
                    center.y,
                    center.z
                )
                model.position = SIMD3<Float>(
                    opensRight
                        ? -size.x / 2
                        : size.x / 2,
                    0,
                    0
                )
                pivot.addChild(model)
                assemblyRoot.addChild(pivot)

                let closed = pivot.transform
                var opened = closed
                opened.rotation = simd_quatf(
                    angle:
                        (opensRight ? 1 : -1)
                        * .pi * 0.55,
                    axis: SIMD3<Float>(0, 1, 0)
                )
                doorMotions.append(
                    Motion(
                        entity: pivot,
                        closed: closed,
                        open: opened
                    )
                )

            case .liftUpDoor:
                let pivot = Entity()
                pivot.position = SIMD3<Float>(
                    center.x,
                    center.y + size.y / 2,
                    center.z
                )
                model.position = SIMD3<Float>(
                    0,
                    -size.y / 2,
                    0
                )
                pivot.addChild(model)
                assemblyRoot.addChild(pivot)

                let closed = pivot.transform
                var opened = closed
                opened.rotation = simd_quatf(
                    angle: -.pi * 0.52,
                    axis: SIMD3<Float>(1, 0, 0)
                )
                doorMotions.append(
                    Motion(
                        entity: pivot,
                        closed: closed,
                        open: opened
                    )
                )

            case .flapDownDoor:
                let pivot = Entity()
                pivot.position = SIMD3<Float>(
                    center.x,
                    center.y - size.y / 2,
                    center.z
                )
                model.position = SIMD3<Float>(
                    0,
                    size.y / 2,
                    0
                )
                pivot.addChild(model)
                assemblyRoot.addChild(pivot)

                let closed = pivot.transform
                var opened = closed
                opened.rotation = simd_quatf(
                    angle: .pi * 0.48,
                    axis: SIMD3<Float>(
                        1,
                        0,
                        0
                    )
                )
                doorMotions.append(
                    Motion(
                        entity: pivot,
                        closed: closed,
                        open: opened
                    )
                )

            case .drawer:
                model.position = center
                assemblyRoot.addChild(model)

                let closed = model.transform
                var opened = closed
                opened.translation.z +=
                    drawerOpenDistance(
                        component: component,
                        allComponents:
                            allComponents,
                        fallbackDepth:
                            size.z
                )
                drawerMotions.append(
                    Motion(
                        entity: model,
                        closed: closed,
                        open: opened
                    )
                )

            case .slidingDoor:
                model.position = center
                assemblyRoot.addChild(model)

                let closed = model.transform
                var opened = closed
                let direction: Float =
                    componentIndex.isMultiple(of: 2)
                    ? -1
                    : 1
                opened.translation.x +=
                    direction * size.x * 0.72
                opened.translation.z += 0.018
                slidingMotions.append(
                    Motion(
                        entity: model,
                        closed: closed,
                        open: opened
                    )
                )

            case .accessory:
                model.position = center
                assemblyRoot.addChild(model)
                accessoryEntities.append(model)

            case .fixed:
                model.position = center
                assemblyRoot.addChild(model)
            }
        }


        @MainActor
        private func addSlopedComponentV0691(
            component: FurnitureComponent,
            componentIndex: Int,
            allComponents:
                [FurnitureComponent],
            assembly: FurnitureAssembly,
            assemblyRoot: Entity,
            profile: WallProfileDefinition
        ) -> Bool {
            guard
                PaneleProdukcyjneSkosuV0691
                    .czyRolaPionowa(
                        component.role
                    )
            else {
                return false
            }

            let size = SIMD3<Float>(
                meters(component.size.width),
                meters(component.size.height),
                meters(component.size.depth)
            )
            let center = inferredCenter(
                component: component,
                componentIndex:
                    componentIndex,
                assembly: assembly
            )

            let xMM =
                Double(
                    center.x - size.x / 2
                ) * 1_000
            let yMM =
                Double(
                    center.y - size.y / 2
                ) * 1_000

            guard
                let contour =
                    PaneleProdukcyjneSkosuV0691
                        .konturPionowegoKomponentu(
                            assembly: assembly,
                            profil: profile,
                            xMM: xMM,
                            yMM: yMM,
                            szerokoscMM:
                                component
                                    .size
                                    .width
                                    .rawValue,
                            wysokoscMM:
                                component
                                    .size
                                    .height
                                    .rawValue
                        ),
                PaneleProdukcyjneSkosuV0691
                    .jestKonturemScietym(
                        contour,
                        oczekiwanaWysokoscMM:
                            component
                                .size
                                .height
                                .rawValue
                    ),
                let bounds =
                    contourBoundsV0691(
                        contour
                    ),
                let mesh =
                    extrudedMeshV0691(
                        contour:
                            contour.map {
                                PunktKonturuPaneluV0691(
                                    xMM:
                                        $0.xMM
                                        - bounds.minimumX,
                                    yMM:
                                        $0.yMM
                                        - bounds.minimumY
                                )
                            },
                        depth:
                            max(
                                size.z,
                                0.004
                            )
                    )
            else {
                return false
            }

            let material =
                cachedMaterial(
                    for: component.role
                )
            let model = ModelEntity(
                mesh: mesh,
                materials: [material]
            )
            model.name =
                component.code
                + "-SKOS-V0691"

            let width =
                Float(
                    bounds.maximumX
                    - bounds.minimumX
                ) / 1_000
            let height =
                Float(
                    bounds.maximumY
                    - bounds.minimumY
                ) / 1_000
            // xOrigin/yOrigin = dolny-lewy-przedni narożnik komponentu.
            // bounds.minimumX/Y są w układzie PANELU (0 = lewy/dolny brzeg),
            // więc dodajemy center ± size/2 żeby przeliczyć na układ assemblyRoot.
            let xOrigin =
                center.x - size.x / 2
                + Float(bounds.minimumX)
                    / 1_000
            let yOrigin =
                center.y - size.y / 2
                + Float(bounds.minimumY)
                    / 1_000
            // WAŻNE: zOrigin = PRZEDNIA ściana komponentu.
            // center.z + size.z/2 daje przód (mniej ujemne z = bliżej kamery).
            let zOrigin =
                center.z + size.z / 2

            switch motionKind(
                component: component,
                assembly: assembly
            ) {
            case .hingedDoor:
                let opensRight =
                    shouldOpenRight(
                        component: component,
                        componentIndex:
                            componentIndex,
                        assembly: assembly
                    )
                let pivot = Entity()
                pivot.position =
                    SIMD3<Float>(
                        opensRight
                            ? xOrigin + width
                            : xOrigin,
                        yOrigin,
                        zOrigin
                    )
                model.position =
                    SIMD3<Float>(
                        opensRight
                            ? -width
                            : 0,
                        0,
                        0
                    )
                pivot.addChild(model)
                assemblyRoot.addChild(pivot)

                let closed =
                    pivot.transform
                var opened = closed
                opened.rotation =
                    simd_quatf(
                        angle:
                            (opensRight ? 1 : -1)
                            * .pi * 0.55,
                        axis:
                            SIMD3<Float>(
                                0,
                                1,
                                0
                            )
                    )
                doorMotions.append(
                    Motion(
                        entity: pivot,
                        closed: closed,
                        open: opened
                    )
                )

            case .liftUpDoor:
                let pivot = Entity()
                pivot.position =
                    SIMD3<Float>(
                        xOrigin + width / 2,
                        yOrigin + height,
                        zOrigin
                    )
                model.position =
                    SIMD3<Float>(
                        -width / 2,
                        -height,
                        0
                    )
                pivot.addChild(model)
                assemblyRoot.addChild(pivot)

                let closed =
                    pivot.transform
                var opened = closed
                opened.rotation =
                    simd_quatf(
                        angle: -.pi * 0.52,
                        axis:
                            SIMD3<Float>(
                                1,
                                0,
                                0
                            )
                    )
                doorMotions.append(
                    Motion(
                        entity: pivot,
                        closed: closed,
                        open: opened
                    )
                )

            case .flapDownDoor:
                let pivot = Entity()
                pivot.position =
                    SIMD3<Float>(
                        xOrigin + width / 2,
                        yOrigin,
                        zOrigin
                    )
                model.position =
                    SIMD3<Float>(
                        -width / 2,
                        0,
                        0
                    )
                pivot.addChild(model)
                assemblyRoot.addChild(pivot)

                let closed =
                    pivot.transform
                var opened = closed
                opened.rotation =
                    simd_quatf(
                        angle: .pi * 0.48,
                        axis:
                            SIMD3<Float>(
                                1,
                                0,
                                0
                            )
                    )
                doorMotions.append(
                    Motion(
                        entity: pivot,
                        closed: closed,
                        open: opened
                    )
                )

            case .drawer:
                model.position =
                    SIMD3<Float>(
                        xOrigin,
                        yOrigin,
                        zOrigin
                    )
                assemblyRoot.addChild(model)

                let closed =
                    model.transform
                var opened = closed
                opened.translation.z +=
                    drawerOpenDistance(
                        component: component,
                        allComponents:
                            allComponents,
                        fallbackDepth:
                            size.z
                )
                drawerMotions.append(
                    Motion(
                        entity: model,
                        closed: closed,
                        open: opened
                    )
                )

            case .slidingDoor:
                model.position =
                    SIMD3<Float>(
                        xOrigin,
                        yOrigin,
                        zOrigin
                    )
                assemblyRoot.addChild(model)

                let closed =
                    model.transform
                var opened = closed
                let direction: Float =
                    componentIndex
                        .isMultiple(of: 2)
                    ? -1
                    : 1
                opened.translation.x +=
                    direction
                    * width
                    * 0.72
                opened.translation.z +=
                    0.018
                slidingMotions.append(
                    Motion(
                        entity: model,
                        closed: closed,
                        open: opened
                    )
                )

            case .accessory:
                model.position =
                    SIMD3<Float>(
                        xOrigin,
                        yOrigin,
                        zOrigin
                    )
                assemblyRoot.addChild(model)
                accessoryEntities.append(
                    model
                )

            case .fixed:
                model.position =
                    SIMD3<Float>(
                        xOrigin,
                        yOrigin,
                        zOrigin
                    )
                assemblyRoot.addChild(model)
            }

            return true
        }

        @MainActor
        private func addSlopedTopV0691(
            assembly: FurnitureAssembly,
            assemblyRoot: Entity,
            profile: WallProfileDefinition
        ) {
            guard
                let contour =
                    PaneleProdukcyjneSkosuV0691
                        .lokalnyKonturZespolu(
                            assembly: assembly,
                            profil: profile
                        )
            else {
                return
            }

            let segments =
                PaneleProdukcyjneSkosuV0691
                    .odcinkiGornejKrawedzi(
                        contour
                    )
            let thickness =
                Float(
                    PaneleProdukcyjneSkosuV0691
                        .domyslnaGruboscPlytyMM
                ) / 1_000
            let depth =
                max(
                    meters(
                        assembly.size.depth
                    ),
                    0.004
                )

            for (index, segment) in
                segments.enumerated()
            {
                let length =
                    Float(
                        segment.dlugoscMM
                    ) / 1_000
                guard length > 0.002 else {
                    continue
                }

                let dx =
                    Float(
                        segment.koniec.xMM
                        - segment.start.xMM
                    ) / 1_000
                let dy =
                    Float(
                        segment.koniec.yMM
                        - segment.start.yMM
                    ) / 1_000
                let unitNormal =
                    SIMD2<Float>(
                        dy / length,
                        -dx / length
                    )
                let midpoint =
                    SIMD2<Float>(
                        Float(
                            segment.start.xMM
                            + segment.koniec.xMM
                        ) / 2_000,
                        Float(
                            segment.start.yMM
                            + segment.koniec.yMM
                        ) / 2_000
                    )
                    + unitNormal
                    * thickness
                    / 2

                let mesh =
                    cachedMesh(
                        for:
                            SIMD3<Float>(
                                length,
                                thickness,
                                depth
                            )
                    )
                let model = ModelEntity(
                    mesh: mesh,
                    materials: [
                        cachedMaterial(
                            for: .top
                        )
                    ]
                )
                model.name =
                    "V0691-WIENIEC-SKOS-\(index + 1)"
                model.position =
                    SIMD3<Float>(
                        midpoint.x,
                        midpoint.y,
                        -depth / 2
                    )
                model.orientation =
                    simd_quatf(
                        angle:
                            Float(
                                segment
                                    .katStopnie
                            )
                            * .pi
                            / 180,
                        axis:
                            SIMD3<Float>(
                                0,
                                0,
                                1
                            )
                    )
                assemblyRoot.addChild(model)
            }
        }

        private struct ContourBoundsV0691 {
            var minimumX: Double
            var maximumX: Double
            var minimumY: Double
            var maximumY: Double
        }

        private func contourBoundsV0691(
            _ contour:
                [PunktKonturuPaneluV0691]
        ) -> ContourBoundsV0691? {
            guard
                let minimumX =
                    contour.map(\.xMM).min(),
                let maximumX =
                    contour.map(\.xMM).max(),
                let minimumY =
                    contour.map(\.yMM).min(),
                let maximumY =
                    contour.map(\.yMM).max(),
                maximumX - minimumX
                    > 0.001,
                maximumY - minimumY
                    > 0.001
            else {
                return nil
            }

            return ContourBoundsV0691(
                minimumX: minimumX,
                maximumX: maximumX,
                minimumY: minimumY,
                maximumY: maximumY
            )
        }

        @MainActor
        private func extrudedMeshV0691(
            contour: [PunktKonturuPaneluV0691],
            depth: Float
        ) -> MeshResource? {
            guard contour.count >= 3 else { return nil }

            if #available(iOS 18.0, *) {
                var path = Path()
                guard let first = contour.first else { return nil }
                path.move(to: CGPoint(x: first.xMM / 1_000, y: first.yMM / 1_000))
                for point in contour.dropFirst() {
                    path.addLine(to: CGPoint(x: point.xMM / 1_000, y: point.yMM / 1_000))
                }
                path.closeSubpath()
                var options = MeshResource.ShapeExtrusionOptions()
                options.extrusionMethod = .linear(depth: max(depth, 0.001))
                options.chamferRadius = 0
                if let mesh = try? MeshResource(extruding: path, extrusionOptions: options) {
                    return mesh
                }
            }

            // iOS 17 fallback: ręczna triangulacja przez MeshDescriptor
            return extrudedMeshManualV0691(
                contour: contour,
                depth: max(depth, 0.001)
            )
        }

        /// Triangulacja ręczna — działa na iOS 15+.
        /// Zakłada wielokąt wypukły (typowe dla ścięć skosem).
        private func extrudedMeshManualV0691(
            contour: [PunktKonturuPaneluV0691],
            depth: Float
        ) -> MeshResource? {
            let n = contour.count
            guard n >= 3 else { return nil }

            let pts: [(x: Float, y: Float)] = contour.map {
                (Float($0.xMM) / 1_000, Float($0.yMM) / 1_000)
            }

            // Shoelace — określenie orientacji (CCW = powierzchnia frontowa)
            var area: Float = 0
            for i in 0..<n {
                let j = (i + 1) % n
                area += pts[i].x * pts[j].y - pts[j].x * pts[i].y
            }
            let ordered: [(x: Float, y: Float)] = area > 0 ? pts : pts.reversed()

            var positions: [SIMD3<Float>] = []
            var normals:   [SIMD3<Float>] = []
            var indices:   [UInt32]       = []

            // Front face (z=0): CCW, normal +Z
            let frontBase = UInt32(positions.count)
            for p in ordered {
                positions.append(SIMD3<Float>(p.x, p.y, 0))
                normals.append(SIMD3<Float>(0, 0, 1))
            }
            for i in 1..<(n - 1) {
                indices += [frontBase,
                            frontBase + UInt32(i),
                            frontBase + UInt32(i + 1)]
            }

            // Back face (z=-depth): odwrócone CW, normal -Z
            let backBase = UInt32(positions.count)
            for p in ordered {
                positions.append(SIMD3<Float>(p.x, p.y, -depth))
                normals.append(SIMD3<Float>(0, 0, -1))
            }
            for i in 1..<(n - 1) {
                indices += [backBase,
                            backBase + UInt32(i + 1),
                            backBase + UInt32(i)]
            }

            // Ściany boczne — quad na każdą krawędź
            for i in 0..<n {
                let j = (i + 1) % n
                let dx = ordered[j].x - ordered[i].x
                let dy = ordered[j].y - ordered[i].y
                let len = max(sqrt(dx * dx + dy * dy), 1e-6)
                // Normalna na zewnątrz dla CCW wielokąta = prawy prostopadły do krawędzi
                let nx =  dy / len
                let ny = -dx / len
                let norm = SIMD3<Float>(nx, ny, 0)

                let base = UInt32(positions.count)
                positions += [
                    SIMD3<Float>(ordered[i].x, ordered[i].y,  0),
                    SIMD3<Float>(ordered[j].x, ordered[j].y,  0),
                    SIMD3<Float>(ordered[j].x, ordered[j].y, -depth),
                    SIMD3<Float>(ordered[i].x, ordered[i].y, -depth)
                ]
                normals += [norm, norm, norm, norm]
                // Dwa trójkąty na quad
                indices += [base, base + 1, base + 2,
                            base, base + 2, base + 3]
            }

            var descriptor = MeshDescriptor()
            descriptor.positions = MeshBuffer(positions)
            descriptor.normals   = MeshBuffer(normals)
            descriptor.primitives = .triangles(indices)
            return try? MeshResource.generate(from: [descriptor])
        }


        private enum MotionKind {
            case fixed
            case hingedDoor
            case liftUpDoor
            case flapDownDoor
            case slidingDoor
            case drawer
            case accessory
        }

        private func motionKind(
            component: FurnitureComponent,
            assembly: FurnitureAssembly
        ) -> MotionKind {
            if component.role == .rail {
                return .accessory
            }

            if GeometriaSzuflad3DV068
                .jestRuchomymElementemSzuflady(
                    component
                ) {
                return .drawer
            }

            guard component.role == .front else {
                return .fixed
            }

            if let opening =
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .efektywneOtwarcie(
                        dla: assembly
                    ) {
                switch opening {
                case .lewy, .prawy:
                    return .hingedDoor
                case .doGory:
                    return .liftUpDoor
                case .wDol:
                    return .flapDownDoor
                case .szuflada:
                    return .drawer
                case .przesuwny:
                    return .slidingDoor
                case .staly:
                    return .fixed
                }
            }

            if assembly.kind == .slidingWardrobe {
                return .slidingDoor
            }

            if component.size.height <= 360 {
                return .drawer
            }

            if isLiftUpFront(
                component: component,
                assembly: assembly
            ) {
                return .liftUpDoor
            }

            return .hingedDoor
        }

        private func drawerOpenDistance(
            component:
                FurnitureComponent,
            allComponents:
                [FurnitureComponent],
            fallbackDepth: Float
        ) -> Float {
            guard
                let drawerNumber =
                    GeometriaSzuflad3DV068
                    .numerSzuflady(
                        dla: component
                    )
            else {
                return max(
                    fallbackDepth * 0.78,
                    0.28
                )
            }

            let drawerDepthMM =
                allComponents
                .filter {
                    GeometriaSzuflad3DV068
                        .numerSzuflady(
                            dla: $0
                        )
                    == drawerNumber
                }
                .map {
                    $0.size
                        .depth
                        .rawValue
                }
                .max()
            ?? Double(fallbackDepth * 1_000)

            return max(
                Float(drawerDepthMM / 1_000) * 0.78,
                0.28
            )
        }

        private func inferredCenter(
            component: FurnitureComponent,
            componentIndex: Int,
            assembly: FurnitureAssembly
        ) -> SIMD3<Float> {
            let local = component.localPosition
            // Komponenty generowane przez V068 (szuflady) zawsze mają
            // jawną pozycję — nawet jeśli wynosi (0,0,0) — bo ich
            // logika jest inna niż role-based inferredCenter.
            let isV068Generated =
                component.code.hasPrefix("V068-DRAWER-FRONT-")
                || component.code.hasPrefix("V068-DRAWER-MOVING-")
                || component.code.hasPrefix("V068-DRAWER-RAIL-")
            let hasExplicitPosition =
                isV068Generated
                || local.x != .zero
                || local.y != .zero
                || local.z != .zero

            if hasExplicitPosition {
                return SIMD3<Float>(
                    meters(local.x)
                        + meters(component.size.width) / 2,
                    meters(local.y)
                        + meters(component.size.height) / 2,
                    -meters(local.z)
                        - meters(component.size.depth) / 2
                )
            }

            let width = meters(assembly.size.width)
            let height = meters(assembly.size.height)
            let depth = meters(assembly.size.depth)
            let componentWidth =
                meters(component.size.width)
            let componentHeight =
                meters(component.size.height)
            let componentDepth =
                meters(component.size.depth)

            switch component.role {
            case .side:
                let x: Float =
                    componentIndex.isMultiple(of: 2)
                    ? componentWidth / 2
                    : width - componentWidth / 2
                return SIMD3<Float>(
                    x,
                    height / 2,
                    -depth / 2
                )

            case .top:
                return SIMD3<Float>(
                    width / 2,
                    height - componentHeight / 2,
                    -depth / 2
                )

            case .bottom:
                return SIMD3<Float>(
                    width / 2,
                    componentHeight / 2,
                    -depth / 2
                )

            case .back:
                return SIMD3<Float>(
                    width / 2,
                    height / 2,
                    -depth + componentDepth / 2
                )

            case .front:
                return SIMD3<Float>(
                    width / 2,
                    componentHeight / 2,
                    componentDepth / 2 + 0.002
                )

            case .shelf:
                let index = Float(componentIndex + 1)
                let fraction = min(
                    max(index / 5, 0.18),
                    0.82
                )
                return SIMD3<Float>(
                    width / 2,
                    height * fraction,
                    -depth / 2
                )

            case .divider:
                return SIMD3<Float>(
                    width / 2,
                    height / 2,
                    -depth / 2
                )

            case .rail:
                return SIMD3<Float>(
                    width / 2,
                    height * 0.72,
                    -depth * 0.52
                )

            default:
                return SIMD3<Float>(
                    width / 2,
                    height / 2,
                    -depth / 2
                )
            }
        }

        private func fallbackComponents(
            for assembly: FurnitureAssembly
        ) -> [FurnitureComponent] {
            let thickness: Millimeters = 18
            let width = assembly.size.width
            let height = assembly.size.height
            let depth = assembly.size.depth

            var result: [FurnitureComponent] = []

            func append(
                code: String,
                role: FurnitureComponentRole,
                size: Size3MM,
                position: Point3MM
            ) {
                if let component = try? FurnitureComponent(
                    code: code,
                    role: role,
                    size: size,
                    localPosition: position
                ) {
                    result.append(component)
                }
            }

            append(
                code: "BOK-L",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: height,
                    depth: depth
                ),
                position: .zero
            )
            append(
                code: "BOK-P",
                role: .side,
                size: Size3MM(
                    width: thickness,
                    height: height,
                    depth: depth
                ),
                position: Point3MM(
                    x: width - thickness,
                    y: .zero,
                    z: .zero
                )
            )
            append(
                code: "WIENIEC-D",
                role: .bottom,
                size: Size3MM(
                    width: width,
                    height: thickness,
                    depth: depth
                ),
                position: .zero
            )
            append(
                code: "WIENIEC-G",
                role: .top,
                size: Size3MM(
                    width: width,
                    height: thickness,
                    depth: depth
                ),
                position: Point3MM(
                    x: .zero,
                    y: height - thickness,
                    z: .zero
                )
            )
            append(
                code: "FRONT",
                role: .front,
                size: Size3MM(
                    width: width - 4,
                    height: height - 4,
                    depth: 18
                ),
                position: Point3MM(
                    x: 2,
                    y: 2,
                    z: .zero
                )
            )

            return result
        }

        @MainActor
        private func addGeneratedAccessoryIfNeeded(
            to assemblyRoot: Entity,
            assembly: FurnitureAssembly
        ) {
            let alreadyHasRail = assembly.components.contains {
                $0.role == .rail
            }
            guard !alreadyHasRail,
                  assembly.size.height >= 1_400,
                  isWardrobeLike(assembly) else {
                return
            }

            let width = max(
                meters(assembly.size.width) - 0.08,
                0.12
            )
            let railSize = SIMD3<Float>(
                width,
                0.018,
                0.018
            )
            let mesh = cachedMesh(for: railSize)
            let material = cachedMaterial(for: .rail)
            let rail = ModelEntity(
                mesh: mesh,
                materials: [material]
            )
            rail.name = "Drążek garderobiany"
            rail.position = SIMD3<Float>(
                meters(assembly.size.width) / 2,
                meters(assembly.size.height) * 0.72,
                -meters(assembly.size.depth) * 0.48
            )
            assemblyRoot.addChild(rail)
            accessoryEntities.append(rail)
        }

        @MainActor
        private func animate(
            _ motions: [Motion],
            open: Bool
        ) {
            for motion in motions {
                motion.entity.move(
                    to: open ? motion.open : motion.closed,
                    relativeTo: motion.entity.parent,
                    duration: 0.72,
                    timingFunction: .easeInOut
                )
            }
        }

        @MainActor
        private func setAccessoriesVisible(
            _ visible: Bool
        ) {
            for entity in accessoryEntities {
                entity.isEnabled = visible
            }
        }

        @MainActor
        private func playAutomaticSequence() {
            currentState.doorsOpen = false
            currentState.drawersOpen = false
            currentState.slidingDoorsOpen = false
            animate(doorMotions, open: false)
            animate(drawerMotions, open: false)
            animate(slidingMotions, open: false)

            Task { @MainActor [weak self] in
                try? await Task.sleep(
                    for: .milliseconds(650)
                )
                guard let self else { return }
                self.animate(self.doorMotions, open: true)

                try? await Task.sleep(
                    for: .milliseconds(800)
                )
                self.animate(self.drawerMotions, open: true)

                try? await Task.sleep(
                    for: .milliseconds(800)
                )
                self.animate(
                    self.slidingMotions,
                    open: true
                )
            }
        }

        @MainActor
        private func addLighting(
            to anchor: Entity
        ) {
            // Key light: front-above-right → oświetla fronty i górę
            // Kierunek po rotacji ≈ (0.2, -0.68, -0.71) — w głąb sceny ✓
            let key = DirectionalLight()
            key.light.intensity = 1_100
            key.orientation = simd_quatf(
                angle: -.pi / 4,
                axis: SIMD3<Float>(1, 0.3, 0)
            )
            anchor.addChild(key)

            // Fill light: z lewej strony → oświetla prawą ścianę boczną
            // simd_quatf(from:to:) obraca -Z ku kierunkowi (-1, -0.4, -0.8)
            let fill = DirectionalLight()
            fill.light.intensity = 500
            fill.orientation = simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: normalize(SIMD3<Float>(-1, -0.4, -0.8))
            )
            anchor.addChild(fill)

            // Ambient / bounce: z tyłu-dołu → spód i plecy nie są czarne
            let ambient = DirectionalLight()
            ambient.light.intensity = 280
            ambient.orientation = simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: normalize(SIMD3<Float>(0.2, -0.5, 0.85))
            )
            anchor.addChild(ambient)
        }

        @MainActor
        private func frameModel() {
            let bounds = modelRoot.visualBounds(
                relativeTo: nil
            )
            cameraTarget = bounds.center

            let size = bounds.extents
            let maximum = max(
                max(size.x, size.y),
                max(size.z, 0.5)
            )
            cameraDistance = max(
                maximum * 2.15,
                2.2
            )
            applyCamera(force: true)
        }

        @MainActor
        private func installGestures(
            on view: ARView
        ) {
            let pan = UIPanGestureRecognizer(
                target: self,
                action: #selector(handlePan(_:))
            )
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)

            let pinch = UIPinchGestureRecognizer(
                target: self,
                action: #selector(handlePinch(_:))
            )
            view.addGestureRecognizer(pinch)
        }

        @objc
        private func handlePan(
            _ gesture: UIPanGestureRecognizer
        ) {
            guard gesture.state == .changed,
                  let targetView = gesture.view else {
                return
            }

            let translation = gesture.translation(in: targetView)
            cameraYaw -= Float(translation.x) * 0.008
            cameraPitch += Float(translation.y) * 0.006
            cameraPitch = min(
                max(cameraPitch, -(Float.pi * 0.42)),
                Float.pi * 0.32
            )
            gesture.setTranslation(.zero, in: targetView)
            applyCamera()
        }

        @objc
        private func handlePinch(
            _ gesture: UIPinchGestureRecognizer
        ) {
            guard gesture.state == .changed else {
                return
            }
            cameraDistance /= Float(gesture.scale)
            cameraDistance = min(
                max(cameraDistance, 0.8),
                12
            )
            gesture.scale = 1
            applyCamera()
        }

        private func resetCameraOrientation() {
            cameraYaw = 0
            cameraPitch = -(Float.pi * 0.10)
        }

        @MainActor
        private func applyCameraCommand(
            _ command: Furniture3DCameraCommandV017
        ) {
            switch command {
            case .none:
                return

            case .yaw(let delta):
                cameraYaw += delta
                applyCamera(force: true)

            case .pitch(let delta):
                cameraPitch += delta
                cameraPitch = min(
                    max(cameraPitch, -(Float.pi * 0.42)),
                    Float.pi * 0.32
                )
                applyCamera(force: true)

            case .setOrientation(let yaw, let pitch):
                cameraYaw = yaw
                cameraPitch = min(
                    max(pitch, -(Float.pi * 0.42)),
                    Float.pi * 0.32
                )
                applyCamera(force: true)
            }
        }

        @MainActor
        private func applyCamera(
            force: Bool = false
        ) {
            let now = CACurrentMediaTime()

            if !force,
               now - lastCameraUpdateTime
                    < minimumCameraUpdateInterval {
                return
            }

            lastCameraUpdateTime = now

            let clampedPitch = min(
                max(cameraPitch, -(Float.pi * 0.42)),
                Float.pi * 0.32
            )
            cameraPitch = clampedPitch

            let horizontalDistance = cosf(clampedPitch)
            let offset = SIMD3<Float>(
                sinf(cameraYaw) * horizontalDistance * cameraDistance,
                sinf(clampedPitch) * cameraDistance,
                cosf(cameraYaw) * horizontalDistance * cameraDistance
            )
            let position = cameraTarget + offset

            camera.position = position
            camera.look(
                at: cameraTarget,
                from: position,
                relativeTo: nil
            )
        }

        private func isWardrobeLike(
            _ assembly: FurnitureAssembly
        ) -> Bool {
            let text = assembly.name
                .folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: .current
                )
                .lowercased()

            return text.contains("szafa")
                || text.contains("garder")
                || text.contains("wardrobe")
                || text.contains("pantograf")
        }

        private func isLiftUpFront(
            component: FurnitureComponent,
            assembly: FurnitureAssembly
        ) -> Bool {
            let text = (assembly.name + " " + component.code)
                .folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: .current
                )
                .lowercased()

            return text.contains("okap")
                || text.contains("lift")
                || text.contains("uchyln")
                || (
                    component.size.height <= 500
                    && component.size.width
                        > component.size.height * 1.25
                )
        }

        private func shouldOpenRight(
            component: FurnitureComponent,
            componentIndex: Int,
            assembly:
                FurnitureAssembly
        ) -> Bool {
            if let opening =
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .efektywneOtwarcie(
                        dla: assembly
                    ) {
                switch opening {
                case .prawy:
                    return true
                case .lewy:
                    return false
                default:
                    break
                }
            }

            let code =
                component
                    .code
                    .lowercased()

            if code.contains("praw")
                || code.contains("right")
                || code.hasSuffix("-p") {
                return true
            }

            if code.contains("lew")
                || code.contains("left")
                || code.hasSuffix("-l") {
                return false
            }

            return !componentIndex
                .isMultiple(
                    of: 2
                )
        }

        private func cachedMesh(
            for size: SIMD3<Float>
        ) -> MeshResource {
            let key = MeshKey(size)

            if let cached = meshCache[key] {
                return cached
            }

            let mesh = MeshResource.generateBox(
                size: size
            )
            meshCache[key] = mesh
            return mesh
        }

        /// Ustawia currentAssemblyKorpusColor / currentAssemblyFrontColor na podstawie
        /// KartaTechnicznaSzafki i BazaMaterialow. Musi być wywołane przed budową każdego modułu.
        private func prepareAssemblyColors(
            for assembly: FurnitureAssembly
        ) {
            let moduleKey = StabilnyKluczDomenowy
                .utworz(dla: assembly.id, prefiks: "furniture")
            let card = KartaTechnicznaSzafkiStore
                .card(forModuleKey: moduleKey)

            // Korpus
            if let korpusID = card?.materialKorpusuID,
               let mat = currentMaterialy.first(where: { $0.id == korpusID }),
               let col = UIColor(stolarniaHEX: mat.kolorHEX)
            {
                currentAssemblyKorpusColor = col
            } else {
                currentAssemblyKorpusColor = nil  // fallback do globalnych
            }

            // Front
            if let frontID = card?.materialFrontuID,
               let mat = currentMaterialy.first(where: { $0.id == frontID }),
               let col = UIColor(stolarniaHEX: mat.kolorHEX)
            {
                currentAssemblyFrontColor = col
            } else {
                currentAssemblyFrontColor = nil  // fallback do globalnych
            }
        }

        private func cachedMaterial(
            for role: FurnitureComponentRole
        ) -> SimpleMaterial {
            let cacheKey =
                "\(currentAssemblyIDString)_\(role.rawValue)"
            if let cached = materialCache[cacheKey] {
                return cached
            }

            let material: SimpleMaterial

            if role == .rail {
                material = SimpleMaterial(
                    color: .darkGray,
                    roughness: 0.32,
                    isMetallic: true
                )
            } else {
                material = SimpleMaterial(
                    color: color(for: role),
                    roughness: 0.78,
                    isMetallic: false
                )
            }

            materialCache[cacheKey] = material
            return material
        }

        private func color(
            for role: FurnitureComponentRole
        ) -> UIColor {
            let globalKorpus =
                UIColor(
                    stolarniaHEX:
                        currentGlobalneMaterialy
                            .korpus
                            .kolorHEX
                )
                ?? UIColor(
                    red: 0.76,
                    green: 0.63,
                    blue: 0.49,
                    alpha: 1
                )
            let globalFront =
                UIColor(
                    stolarniaHEX:
                        currentGlobalneMaterialy
                            .front
                            .kolorHEX
                )
                ?? UIColor(
                    red: 0.93,
                    green: 0.92,
                    blue: 0.94,
                    alpha: 1
                )

            // Per-moduł kolory z BazaMaterialow (jeśli przypisane)
            let carcass =
                currentAssemblyKorpusColor
                ?? globalKorpus
            let front =
                currentAssemblyFrontColor
                ?? globalFront

            switch role {
            case .front,
                 .filler,
                 .maskingPanel,
                 .decorativeSide:
                return front
            case .back:
                return carcass.withAlphaComponent(
                    0.72
                )
            case .rail:
                return .darkGray
            default:
                return carcass
            }
        }

        private func meters(
            _ value: Millimeters
        ) -> Float {
            Float(value.rawValue / 1_000)
        }

        private func maxVector(
            _ value: SIMD3<Float>,
            minimum: Float
        ) -> SIMD3<Float> {
            SIMD3<Float>(
                max(value.x, minimum),
                max(value.y, minimum),
                max(value.z, minimum)
            )
        }
    }
}
