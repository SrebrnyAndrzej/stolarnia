import DomainCore
import Foundation
import Persistence
import SwiftUI

enum SlidingWardrobeSystemMarkersV087 {
    static let namePrefix =
        "System drzwi przesuwnych"
    static let bindingSegment =
        "-ZAKRES-"
    static let upperTrackCode =
        "SYS-PRZESUW-TOR-GORNY-V087"
    static let lowerTrackCode =
        "SYS-PRZESUW-TOR-DOLNY-V087"
    static let closingWallCode =
        "SYS-PRZESUW-SCIANA-DOMYKOWA-V087"
    static let doorLeafCode =
        "SYS-PRZESUW-SKRZYDLO-V093"
    static let partitionDoorLeafCode =
        "SYS-PRZESUW-PRZEGRODA-SKRZYDLA-V092"
    static let partitionUpperTrackCode =
        "SYS-PRZESUW-PRZEGRODA-TOR-GORNY-V092"
    static let partitionLowerGuideCode =
        "SYS-PRZESUW-PRZEGRODA-PROWADZENIE-DOLNE-V092"
    static let partitionWardrobeJambCode =
        "SYS-PRZESUW-PRZEGRODA-PROFIL-SZAFA-V092"
    static let partitionWallJambCode =
        "SYS-PRZESUW-PRZEGRODA-PROFIL-SCIANA-V092"

    static func isSystemAssembly(
        _ assembly:
            FurnitureAssembly
    ) -> Bool {
        assembly.name.localizedCaseInsensitiveContains(
            namePrefix
        )
        || assembly.components.contains {
            isSystemCode($0.code)
        }
    }

    static func isSystemCode(
        _ code:
            String
    ) -> Bool {
        code.hasPrefix(upperTrackCode)
        || code.hasPrefix(lowerTrackCode)
        || code.hasPrefix(closingWallCode)
        || code.hasPrefix(doorLeafCode)
        || code.hasPrefix(partitionDoorLeafCode)
        || code.hasPrefix(partitionUpperTrackCode)
        || code.hasPrefix(partitionLowerGuideCode)
        || code.hasPrefix(partitionWardrobeJambCode)
        || code.hasPrefix(partitionWallJambCode)
    }

    static func isWardrobeSystemCode(
        _ code:
            String
    ) -> Bool {
        code.hasPrefix(upperTrackCode)
        || code.hasPrefix(lowerTrackCode)
        || code.hasPrefix(closingWallCode)
        || code.hasPrefix(doorLeafCode)
    }

    static func boundCode(
        _ code:
            String,
        bindingID:
            String
    ) -> String {
        "\(code)\(bindingSegment)\(bindingID)"
    }

    static func bindingID(
        for assemblyIDs:
            [FurnitureAssemblyID]
    ) -> String {
        let source =
            assemblyIDs
            .map(\.description)
            .sorted()
            .joined(separator: "|")
        var hash:
            UInt64 = 14_695_981_039_346_656_037

        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return String(
            hash,
            radix:
                36,
            uppercase:
                true
        )
    }

    static func bindingID(
        in assembly:
            FurnitureAssembly
    ) -> String? {
        assembly
            .components
            .compactMap {
                bindingID(inCode: $0.code)
            }
            .first
    }

    private static func bindingID(
        inCode code:
            String
    ) -> String? {
        guard let range =
            code.range(
                of:
                    bindingSegment
            )
        else {
            return nil
        }

        return String(
            code[range.upperBound...]
        )
    }
}

enum SlidingWardrobeDoorFillV093:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case solid
    case mirror

    var id:
        String
    {
        rawValue
    }

    var title:
        String
    {
        switch self {
        case .solid:
            return "Lite"
        case .mirror:
            return "Lustro"
        }
    }

    var codeSuffix:
        String
    {
        switch self {
        case .solid:
            return "LITE"
        case .mirror:
            return "LUSTRO"
        }
    }

    var systemImage:
        String
    {
        switch self {
        case .solid:
            return "rectangle.fill"
        case .mirror:
            return "sparkles.rectangle.stack"
        }
    }

    var canvasColor:
        Color
    {
        switch self {
        case .solid:
            return Color(
                red:
                    0.38,
                green:
                    0.30,
                blue:
                    0.22
            )
        case .mirror:
            return Color(
                red:
                    0.74,
                green:
                    0.84,
                blue:
                    0.92
            )
        }
    }
}

struct SlidingWardrobeModulePreviewV093:
    Identifiable,
    Hashable
{
    let id:
        FurnitureAssemblyID
    let name:
        String
    let width:
        Millimeters
    let height:
        Millimeters
    let depth:
        Millimeters
    let shelfCount:
        Int
    let components:
        [FurnitureComponent]
}

struct SlidingWardrobeModuleRunV087:
    Identifiable,
    Hashable
{
    let id:
        String
    let wallID:
        WallID
    let assemblyIDs:
        [FurnitureAssemblyID]
    let moduleNames:
        [String]
    let moduleWidths:
        [Millimeters]
    let modulePreviews:
        [SlidingWardrobeModulePreviewV093]
    let bindingID:
        String
    let startOffset:
        Millimeters
    let endOffset:
        Millimeters
    let bottomOffset:
        Millimeters
    let topOffset:
        Millimeters
    let depth:
        Millimeters
    var hasUpperTrack:
        Bool
    var hasLowerTrack:
        Bool
    var hasClosingWall:
        Bool
    var hasDoorLeaves:
        Bool
    var hasBoundSystem:
        Bool = false
    var hasLegacySystemWithoutBinding:
        Bool = false
    var systemNeedsRefresh:
        Bool = false
    var forcedDoorCount:
        Int? = nil
    var scopeLabel:
        String? = nil

    var width:
        Millimeters
    {
        endOffset - startOffset
    }

    var height:
        Millimeters
    {
        topOffset - bottomOffset
    }

    var doorCount:
        Int
    {
        if let forcedDoorCount {
            return min(
                max(
                    forcedDoorCount,
                    2
                ),
                4
            )
        }

        return min(
            max(
                SilnikSzafyPrzesuwanejV075
                    .optymalnaLiczbaDrzwi(
                        szerokoscMM:
                            width.rawValue
                    ),
                2
            ),
            4
        )
    }

    var isComplete:
        Bool
    {
        hasUpperTrack
            && hasLowerTrack
            && hasClosingWall
            && hasDoorLeaves
    }

    var isProductionReady:
        Bool
    {
        isComplete
            && hasBoundSystem
            && !systemNeedsRefresh
    }

    var actionTitle:
        String
    {
        if isProductionReady {
            return "Gotowe"
        }
        if isComplete && !hasBoundSystem {
            return "Przepnij system"
        }
        if systemNeedsRefresh {
            return "Aktualizuj system"
        }
        return "Dodaj tor i drzwi"
    }

    var missingPartsLabel:
        String
    {
        var parts:
            [String] = []

        if !hasUpperTrack {
            parts.append("tor górny")
        }
        if !hasLowerTrack {
            parts.append("tor dolny")
        }
        if !hasClosingWall {
            parts.append("ściana domykowa")
        }
        if !hasDoorLeaves {
            parts.append("drzwi")
        }

        return parts.isEmpty
            ? (
                hasBoundSystem
                ? (
                    systemNeedsRefresh
                    ? "wymaga aktualizacji"
                    : "komplet"
                )
                : "brak przypięcia"
            )
            : parts.joined(separator: ", ")
    }

    var moduleDimensionLabel:
        String
    {
        modulePreviews
            .map {
                "\(Int($0.width.rawValue.rounded()))x\(Int($0.depth.rawValue.rounded()))"
            }
            .joined(separator: " / ")
    }

    var hasMixedDepths:
        Bool
    {
        Set(
            modulePreviews
                .map {
                    Int($0.depth.rawValue.rounded())
                }
        )
        .count > 1
    }

    func withDoorCountOverride(
        _ count:
            Int?
    ) -> SlidingWardrobeModuleRunV087 {
        var copy =
            self
        copy.forcedDoorCount =
            count.map {
                min(
                    max($0, 2),
                    4
                )
            }
        return copy
    }

    func withScopeLabel(
        _ label:
            String?
    ) -> SlidingWardrobeModuleRunV087 {
        var copy =
            self
        copy.scopeLabel =
            label
        return copy
    }

    func requiringFullSystemRebuild() -> SlidingWardrobeModuleRunV087 {
        var copy =
            self
        copy.hasUpperTrack =
            false
        copy.hasLowerTrack =
            false
        copy.hasClosingWall =
            false
        copy.hasDoorLeaves =
            false
        return copy
    }

    func slidingDefinition() -> SzafaPrzesuwnaDefinicjaV075 {
        var definition =
            SzafaPrzesuwnaDefinicjaV075()
        definition.szerokoscCalkowitaMM =
            width.rawValue
        definition.wysokoscCalkowitaMM =
            height.rawValue
        definition.glebokoscMM =
            depth.rawValue
        definition.liczbaDrzwi =
            doorCount
        definition.trybMontazu =
            .dostawionyDoSzafki
        definition.dodajDomyslnaListwePrzymykowaPrawą()
        definition.normalize()
        return definition
    }
}

struct GarderobyDrzwiWorkspaceV086:
    View
{
    let room:
        RoomDefinition
    let assemblies:
        [StoredFurnitureAssembly]
    @Binding var selectedFurnitureID:
        FurnitureAssemblyID?
    let onAddSlidingWardrobe:
        () -> Void
    let onAddSlidingSystem:
        (
            SlidingWardrobeModuleRunV087,
            SlidingWardrobeDoorFillV093
        ) -> Void
    @State private var selectedRunID:
        String?
    @State private var selectedModuleID:
        FurnitureAssemblyID?
    @State private var selectedDoorFill:
        SlidingWardrobeDoorFillV093 = .solid
    @State private var showsDoorsPreview:
        Bool = false

    private var moduleRuns:
        [SlidingWardrobeModuleRunV087]
    {
        Self.moduleRuns(
            from:
                assemblies
        )
    }

    private var activeRun:
        SlidingWardrobeModuleRunV087?
    {
        if let selectedRunID,
           let selected =
            moduleRuns.first(
                where: {
                    $0.id == selectedRunID
                }
            ) {
            return selected
        }

        return moduleRuns.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            Divider()

            SlidingWardrobeDesignerCanvasV093(
                runs:
                    moduleRuns,
                selectedRunID:
                    Binding(
                        get: {
                            activeRun?.id
                        },
                        set: {
                            selectedRunID = $0
                        }
                    ),
                doorFill:
                    selectedDoorFill,
                showsDoorsPreview:
                    showsDoorsPreview,
                selectedModuleID:
                    $selectedModuleID,
                onAddModule:
                    onAddSlidingWardrobe
            )
            .frame(
                minHeight:
                    360
            )
            .layoutPriority(1)

            Divider()

            if let activeRun {
                SlidingWardrobeCanvasInspectorV093(
                    run:
                        activeRun,
                    doorFill:
                        $selectedDoorFill,
                    showsDoorsPreview:
                        $showsDoorsPreview
                ) {
                    onAddSlidingSystem(
                        activeRun,
                        selectedDoorFill
                    )
                }
                .padding(16)
            } else {
                emptyState
                    .padding(16)
            }
        }
        .background(
            StolarniaPalette.canvas
                .ignoresSafeArea()
        )
        .onAppear {
            ensureSelectedRunV093()
        }
        .onChange(
            of:
                moduleRuns.map(\.id)
        ) {
            _,
            _ in

            ensureSelectedRunV093()
        }
        .onChange(
            of:
                selectedRunID
        ) {
            _,
            _ in

            ensureSelectedModuleV093()
        }
    }

    private var header:
        some View
    {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text("Garderoby i drzwi")
                    .font(.title3.weight(.semibold))

                Text(room.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(
                action: onAddSlidingWardrobe
            ) {
                Label(
                    "Dodaj moduł pod przesuwne",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func ensureSelectedRunV093() {
        if let selectedRunID,
           moduleRuns.contains(
            where: {
                $0.id == selectedRunID
            }
           ) {
            ensureSelectedModuleV093()
            return
        }

        selectedRunID =
            moduleRuns.first?.id

        ensureSelectedModuleV093()
    }

    private func ensureSelectedModuleV093() {
        guard let activeRun else {
            selectedModuleID = nil
            return
        }

        if let selectedModuleID,
           activeRun.modulePreviews.contains(
            where: {
                $0.id == selectedModuleID
            }
           ) {
            return
        }

        selectedModuleID =
            activeRun.modulePreviews.first?.id
    }

    private var emptyState:
        some View
    {
        ContentUnavailableView {
            Label(
                "Brak modułów garderoby",
                systemImage: "cabinet"
            )
        } description: {
            Text(
                "Dodaj moduły garderoby lub szafy z biblioteki, a potem dopnij tory i ścianę domykową jako osobny system."
            )
        } actions: {
            Button(
                "Dodaj moduły z biblioteki",
                action: onAddSlidingWardrobe
            )
            .buttonStyle(.borderedProminent)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 280
        )
    }

    static func moduleRuns(
        from assemblies:
            [StoredFurnitureAssembly]
    ) -> [SlidingWardrobeModuleRunV087] {
        struct Candidate {
            let stored:
                StoredFurnitureAssembly
            let placement:
                FurniturePlacement

            var start:
                Millimeters
            {
                placement.offsetAlongWall
            }

            var end:
                Millimeters
            {
                placement.offsetAlongWall
                    + stored.assembly.size.width
            }

            var top:
                Millimeters
            {
                placement.bottomOffset
                    + stored.assembly.size.height
            }
        }

        let candidates =
            assemblies
                .compactMap {
                    stored -> Candidate? in

                    guard let placement =
                        stored.assembly.placement,
                          placement.wallID != nil,
                          isWardrobeModuleCandidate(
                              stored.assembly
                          )
                    else {
                        return nil
                    }

                    return Candidate(
                        stored:
                            stored,
                        placement:
                            placement
                    )
                }
                .sorted {
                    lhs,
                    rhs in

                    if lhs.placement.wallID
                        == rhs.placement.wallID {
                        if lhs.placement.bottomOffset
                            == rhs.placement.bottomOffset {
                            return lhs.start
                                < rhs.start
                        }

                        return lhs
                            .placement
                            .bottomOffset
                            < rhs
                            .placement
                            .bottomOffset
                    }

                    return (
                        lhs.placement.wallID?
                            .description
                        ?? ""
                    ) < (
                        rhs.placement.wallID?
                            .description
                        ?? ""
                    )
                }

        let systemAssemblies =
            assemblies.filter {
                SlidingWardrobeSystemMarkersV087
                    .isSystemAssembly(
                        $0.assembly
                    )
            }
        let continuityTolerance:
            Millimeters = 35
        let laneTolerance:
            Millimeters = 120
        var groups:
            [[Candidate]] = []

        for candidate in candidates {
            if let index =
                groups.firstIndex(
                    where: {
                        group in

                        guard let first =
                            group.first,
                              first.placement.wallID
                                == candidate
                                .placement
                                .wallID,
                              abs(
                                (
                                    first
                                        .placement
                                        .bottomOffset
                                    - candidate
                                        .placement
                                        .bottomOffset
                                )
                                .rawValue
                              ) <= laneTolerance.rawValue,
                              let lastEnd =
                                group.map(\.end).max()
                        else {
                            return false
                        }

                        return candidate.start
                            - lastEnd
                            <= continuityTolerance
                    }
                ) {
                groups[index].append(candidate)
            } else {
                groups.append([candidate])
            }
        }

        return groups
            .compactMap {
                group -> SlidingWardrobeModuleRunV087? in

                guard let first =
                    group.first,
                      let wallID =
                        first.placement.wallID
                else {
                    return nil
                }

                let start =
                    group.map(\.start).min()
                    ?? first.start
                let end =
                    group.map(\.end).max()
                    ?? first.end
                let bottom =
                    group
                        .map {
                            $0.placement.bottomOffset
                        }
                        .min()
                    ?? first.placement.bottomOffset
                let top =
                    group.map(\.top).max()
                    ?? first.top
                let depth =
                    group
                        .map {
                            $0.stored.assembly.size.depth
                        }
                        .max()
                    ?? first.stored.assembly.size.depth
                let assemblyIDs =
                    group.map {
                        $0.stored.id
                    }
                let bindingID =
                    SlidingWardrobeSystemMarkersV087
                    .bindingID(
                        for:
                            assemblyIDs
                    )
                let boundSystemAssemblies =
                    systemAssemblies.filter {
                        SlidingWardrobeSystemMarkersV087
                            .bindingID(
                                in:
                                    $0.assembly
                            ) == bindingID
                    }
                let hasBoundSystem =
                    !boundSystemAssemblies.isEmpty
                let hasLegacySystemWithoutBinding =
                    hasLegacySystemWithoutBinding(
                        in:
                            systemAssemblies,
                        wallID:
                            wallID,
                        start:
                            start,
                        end:
                            end,
                        bottom:
                            bottom,
                        top:
                            top
                    )
                let existingDoorCount =
                    existingDoorLeafCount(
                        in:
                            boundSystemAssemblies
                    )
                let runID =
                    [
                        wallID.description,
                        Int(start.rawValue.rounded())
                            .description,
                        Int(end.rawValue.rounded())
                            .description,
                        Int(bottom.rawValue.rounded())
                            .description
                    ]
                    .joined(separator: "-")

                guard end - start >= 800 else {
                    return nil
                }

                return SlidingWardrobeModuleRunV087(
                    id:
                        runID,
                    wallID:
                        wallID,
                    assemblyIDs:
                        assemblyIDs,
                    moduleNames:
                        group.map {
                            $0.stored.assembly.name
                        },
                    moduleWidths:
                        group.map {
                            $0.stored.assembly.size.width
                        },
                    modulePreviews:
                        group.map {
                            SlidingWardrobeModulePreviewV093(
                                id:
                                    $0.stored.id,
                                name:
                                    $0.stored.assembly.name,
                                width:
                                    $0.stored.assembly.size.width,
                                height:
                                    $0.stored.assembly.size.height,
                                depth:
                                    $0.stored.assembly.size.depth,
                                shelfCount:
                                    (
                                        try? $0.stored
                                            .parameters
                                            .integer(
                                                for:
                                                    .shelfCount
                                            )
                                    )
                                    ?? $0.stored.assembly.components
                                    .filter {
                                        $0.role == .shelf
                                    }
                                    .count,
                                components:
                                    $0.stored.assembly.components
                            )
                        },
                    bindingID:
                        bindingID,
                    startOffset:
                        start,
                    endOffset:
                        end,
                    bottomOffset:
                        bottom,
                    topOffset:
                        top,
                    depth:
                        depth,
                    hasUpperTrack:
                        hasSystemElement(
                            codePrefix:
                                SlidingWardrobeSystemMarkersV087
                                .upperTrackCode,
                            in:
                                systemAssemblies,
                            wallID:
                                wallID,
                            start:
                                start,
                            end:
                                end,
                            bottom:
                                bottom,
                            top:
                                top,
                            bindingID:
                                bindingID
                        ),
                    hasLowerTrack:
                        hasSystemElement(
                            codePrefix:
                                SlidingWardrobeSystemMarkersV087
                                .lowerTrackCode,
                            in:
                                systemAssemblies,
                            wallID:
                                wallID,
                            start:
                                start,
                            end:
                                end,
                            bottom:
                                bottom,
                            top:
                                top,
                            bindingID:
                                bindingID
                        ),
                    hasClosingWall:
                        hasSystemElement(
                            codePrefix:
                                SlidingWardrobeSystemMarkersV087
                                .closingWallCode,
                            in:
                                systemAssemblies,
                            wallID:
                                wallID,
                            start:
                                start,
                            end:
                                end,
                            bottom:
                                bottom,
                            top:
                                top,
                            bindingID:
                                bindingID
                        ),
                    hasDoorLeaves:
                        hasSystemElement(
                            codePrefix:
                                SlidingWardrobeSystemMarkersV087
                                .doorLeafCode,
                            in:
                                systemAssemblies,
                            wallID:
                                wallID,
                            start:
                                start,
                            end:
                                end,
                            bottom:
                                bottom,
                            top:
                                top,
                            bindingID:
                                bindingID
                        ),
                    hasBoundSystem:
                        hasBoundSystem,
                    hasLegacySystemWithoutBinding:
                        hasLegacySystemWithoutBinding,
                    systemNeedsRefresh:
                        systemNeedsRefresh(
                            boundSystemAssemblies:
                                boundSystemAssemblies,
                            start:
                                start,
                            width:
                                end - start,
                            bottom:
                                bottom,
                            top:
                                top
                        ),
                    forcedDoorCount:
                        existingDoorCount
                )
            }
            .sorted {
                if $0.wallID == $1.wallID {
                    return $0.startOffset
                        < $1.startOffset
                }

                return $0.wallID.description
                    < $1.wallID.description
            }
    }

    static func moduleRun(
        from assemblies:
            [StoredFurnitureAssembly],
        selectedIDs:
            Set<FurnitureAssemblyID>
    ) -> SlidingWardrobeModuleRunV087? {
        guard !selectedIDs.isEmpty else {
            return nil
        }

        let scopedAssemblies =
            assemblies.filter {
                selectedIDs.contains($0.id)
                    || SlidingWardrobeSystemMarkersV087
                        .isSystemAssembly(
                            $0.assembly
                        )
            }
        let selectedWardrobeIDs =
            Set(
                scopedAssemblies
                    .filter {
                        selectedIDs.contains($0.id)
                            && isWardrobeModuleCandidate(
                                $0.assembly
                            )
                    }
                    .map(\.id)
            )

        guard !selectedWardrobeIDs.isEmpty else {
            return nil
        }

        return moduleRuns(
            from:
                scopedAssemblies
        )
        .first {
            Set($0.assemblyIDs) == selectedWardrobeIDs
        }?
        .withScopeLabel(
            selectedWardrobeIDs.count > 1
            ? "zaznaczenie"
            : nil
        )
    }

    private static func isWardrobeModuleCandidate(
        _ assembly:
            FurnitureAssembly
    ) -> Bool {
        guard !SlidingWardrobeSystemMarkersV087
            .isSystemAssembly(
                assembly
            )
        else {
            return false
        }

        let normalizedName =
            assembly.name
                .folding(
                    options: [
                        .diacriticInsensitive,
                        .caseInsensitive
                    ],
                    locale:
                        .current
                )
                .lowercased()

        return assembly.kind == .wardrobe
            || assembly.kind == .recessBuiltIn
            || normalizedName.contains("szafa")
            || normalizedName.contains("garderoba")
            || normalizedName.contains("wnęk")
            || normalizedName.contains("wnek")
    }

    private static func existingDoorLeafCount(
        in assemblies:
            [StoredFurnitureAssembly]
    ) -> Int? {
        let count =
            assemblies
            .filter {
                $0.assembly.components.contains {
                    $0.code.hasPrefix(
                        SlidingWardrobeSystemMarkersV087
                            .doorLeafCode
                    )
                }
            }
            .count

        guard count >= 2 else {
            return nil
        }

        return min(
            max(
                count,
                2
            ),
            4
        )
    }

    private static func hasLegacySystemWithoutBinding(
        in assemblies:
            [StoredFurnitureAssembly],
        wallID:
            WallID,
        start:
            Millimeters,
        end:
            Millimeters,
        bottom:
            Millimeters,
        top:
            Millimeters
    ) -> Bool {
        assemblies.contains {
            stored in

            guard SlidingWardrobeSystemMarkersV087
                .bindingID(
                    in:
                        stored.assembly
                ) == nil,
                  stored.assembly.components.contains(
                    where: {
                        SlidingWardrobeSystemMarkersV087
                            .isWardrobeSystemCode(
                                $0.code
                            )
                    }
                  )
            else {
                return false
            }

            return systemAssemblyOverlapsRun(
                stored.assembly,
                wallID:
                    wallID,
                start:
                    start,
                end:
                    end,
                bottom:
                    bottom,
                top:
                    top
            )
        }
    }

    private static func systemNeedsRefresh(
        boundSystemAssemblies:
            [StoredFurnitureAssembly],
        start:
            Millimeters,
        width:
            Millimeters,
        bottom:
            Millimeters,
        top:
            Millimeters
    ) -> Bool {
        guard !boundSystemAssemblies.isEmpty else {
            return false
        }

        let tolerance =
            2.0

        func mismatches(
            _ lhs:
                Millimeters,
            _ rhs:
                Millimeters
        ) -> Bool {
            abs(
                lhs.rawValue - rhs.rawValue
            ) > tolerance
        }

        for stored in boundSystemAssemblies {
            guard let placement =
                stored.assembly.placement
            else {
                return true
            }

            if stored.assembly.components.contains(
                where: {
                    $0.code.hasPrefix(
                        SlidingWardrobeSystemMarkersV087
                            .upperTrackCode
                    )
                    || $0.code.hasPrefix(
                        SlidingWardrobeSystemMarkersV087
                            .lowerTrackCode
                    )
                }
            ) {
                if mismatches(
                    placement.offsetAlongWall,
                    start
                )
                || mismatches(
                    stored.assembly.size.width,
                    width
                ) {
                    return true
                }
            }

            if stored.assembly.components.contains(
                where: {
                    $0.code.hasPrefix(
                        SlidingWardrobeSystemMarkersV087
                            .upperTrackCode
                    )
                }
            ) {
                let expectedBottom =
                    max(
                        bottom,
                        top - stored.assembly.size.height
                    )
                if mismatches(
                    placement.bottomOffset,
                    expectedBottom
                ) {
                    return true
                }
            }
        }

        return false
    }

    private static func hasSystemElement(
        codePrefix:
            String,
        in assemblies:
            [StoredFurnitureAssembly],
        wallID:
            WallID,
        start:
            Millimeters,
        end:
            Millimeters,
        bottom:
            Millimeters,
        top:
            Millimeters,
        bindingID:
            String? = nil
    ) -> Bool {
        assemblies.contains {
            stored in

            guard let placement =
                stored.assembly.placement,
                  placement.wallID == wallID,
                  stored.assembly.components.contains(
                    where: {
                        $0.code.hasPrefix(
                            codePrefix
                        )
                    }
                  )
            else {
                return false
            }

            if let bindingID,
               SlidingWardrobeSystemMarkersV087
                .bindingID(
                    in:
                        stored.assembly
                ) == bindingID {
                return true
            }

            return systemAssemblyOverlapsRun(
                stored.assembly,
                wallID:
                    wallID,
                start:
                    start,
                end:
                    end,
                bottom:
                    bottom,
                top:
                    top
            )
        }
    }

    private static func systemAssemblyOverlapsRun(
        _ assembly:
            FurnitureAssembly,
        wallID:
            WallID,
        start:
            Millimeters,
        end:
            Millimeters,
        bottom:
            Millimeters,
        top:
            Millimeters
    ) -> Bool {
        guard let placement =
            assembly.placement,
              placement.wallID == wallID
        else {
            return false
        }

        let elementStart =
            placement.offsetAlongWall
        let elementEnd =
            placement.offsetAlongWall
            + assembly.size.width
        let elementTop =
            placement.bottomOffset
            + assembly.size.height

        let horizontalOverlap =
            min(
                end.rawValue,
                elementEnd.rawValue
            )
            - max(
                start.rawValue,
                elementStart.rawValue
            )
        let verticalOverlap =
            min(
                top.rawValue,
                elementTop.rawValue
            )
            - max(
                bottom.rawValue,
                placement.bottomOffset.rawValue
            )

        return horizontalOverlap > 10
            && verticalOverlap > 1
    }
}

private struct SlidingWardrobeDesignerCanvasV093:
    View
{
    let runs:
        [SlidingWardrobeModuleRunV087]
    @Binding var selectedRunID:
        String?
    let doorFill:
        SlidingWardrobeDoorFillV093
    let showsDoorsPreview:
        Bool
    @Binding var selectedModuleID:
        FurnitureAssemblyID?
    let onAddModule:
        () -> Void

    var body: some View {
        ZStack {
            Color.white

            if runs.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Biały canvas szafy",
                        systemImage:
                            "rectangle.dashed"
                    )
                } description: {
                    Text(
                        "Dodaj moduły garderoby, ustaw je w ciągu, a potem dopnij tor i drzwi."
                    )
                } actions: {
                    Button(
                        action:
                            onAddModule
                    ) {
                        Label(
                            "Dodaj moduł",
                            systemImage:
                                "plus"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            22
                    ) {
                        HStack {
                            Label(
                                "Elewacja szafy przesuwnej",
                                systemImage:
                                    "rectangle.split.3x1"
                            )
                            .font(.headline)

                            Spacer()

                            Button(
                                action:
                                    onAddModule
                            ) {
                                Label(
                                    "Dodaj moduł",
                                    systemImage:
                                        "plus"
                                )
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(runs) { run in
                            SlidingWardrobeCanvasRunRowV093(
                                run:
                                    run,
                                isSelected:
                                    selectedRunID == run.id,
                                doorFill:
                                    doorFill,
                                showsDoorsPreview:
                                    showsDoorsPreview,
                                selectedModuleID:
                                    $selectedModuleID
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRunID =
                                    run.id
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

private struct SlidingWardrobeCanvasRunRowV093:
    View
{
    let run:
        SlidingWardrobeModuleRunV087
    let isSelected:
        Bool
    let doorFill:
        SlidingWardrobeDoorFillV093
    let showsDoorsPreview:
        Bool
    @Binding var selectedModuleID:
        FurnitureAssemblyID?

    private var totalModuleWidth:
        Double
    {
        let sum =
            run.modulePreviews
                .map {
                    $0.width.rawValue
                }
                .reduce(0, +)

        return max(
            sum,
            run.width.rawValue,
            1
        )
    }

    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {
            HStack {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {
                    Text("Ciąg przy ścianie")
                        .font(.caption.weight(.semibold))
                    Text(
                        "\(Int(run.width.rawValue)) × \(Int(run.height.rawValue)) × \(Int(run.depth.rawValue)) mm"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                Spacer()

                Label(
                    run.isProductionReady
                    ? "gotowe"
                    : "brakuje: \(run.missingPartsLabel)",
                    systemImage:
                        run.isProductionReady
                        ? "checkmark.circle.fill"
                        : "plus.circle"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(
                    run.isProductionReady
                    ? .green
                    : Color.accentColor
                )
            }

            GeometryReader { proxy in
                let canvasWidth =
                    max(
                        proxy.size.width,
                        1
                    )
                let elevationHeight =
                    max(
                        proxy.size.height - 20,
                        160
                    )
                let drawingWidth =
                    max(
                        canvasWidth - 20,
                        1
                    )

                ZStack(
                    alignment:
                        .topLeading
                ) {
                    RoundedRectangle(
                        cornerRadius:
                            8,
                        style:
                            .continuous
                    )
                    .fill(Color.white)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius:
                                8,
                            style:
                                .continuous
                        )
                        .stroke(
                            isSelected
                            ? Color.accentColor
                            : Color.black.opacity(0.16),
                            lineWidth:
                                isSelected
                                ? 2
                                : 1
                        )
                    }

                    HStack(
                        alignment:
                            .top,
                        spacing:
                            0
                    ) {
                        ForEach(
                            Array(
                                run.modulePreviews
                                    .enumerated()
                            ),
                            id:
                                \.element.id
                        ) {
                            index,
                            module in

                            moduleBlock(
                                index:
                                    index,
                                module:
                                    module,
                                isSelected:
                                    selectedModuleID
                                    == module.id,
                                width:
                                    max(
                                        drawingWidth
                                        * CGFloat(
                                            module.width.rawValue
                                            / totalModuleWidth
                                        ),
                                        46
                                    ),
                                height:
                                    elevationHeight
                            )
                            .onTapGesture {
                                selectedModuleID =
                                    module.id
                            }
                        }
                    }
                    .frame(
                        width:
                            drawingWidth,
                        height:
                            elevationHeight
                    )
                    .offset(
                        x:
                            10,
                        y:
                            10
                    )

                    if run.hasUpperTrack
                        || run.hasLowerTrack
                        || run.hasDoorLeaves
                        || showsDoorsPreview {
                        elevationTrackLines(
                            width:
                                drawingWidth,
                            height:
                                elevationHeight
                        )
                        .offset(
                            x:
                                10,
                            y:
                                10
                        )
                    }

                    if showsDoorsPreview {
                        elevationDoors(
                            width:
                                drawingWidth,
                            height:
                                elevationHeight
                        )
                        .offset(
                            x:
                                10,
                            y:
                                10
                        )
                    }
                }
            }
            .frame(height: 360)
        }
        .padding(14)
        .background(
            Color.white,
            in: RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .shadow(
            color:
                Color.black.opacity(0.06),
            radius:
                12,
            x:
                0,
            y:
                5
        )
    }

    private func moduleBlock(
        index:
            Int,
        module:
            SlidingWardrobeModulePreviewV093,
        isSelected:
            Bool,
        width:
            CGFloat,
        height:
            CGFloat
    ) -> some View {
        GeometryReader { proxy in
            let innerWidth =
                max(
                    proxy.size.width,
                    1
                )
            let innerHeight =
                max(
                    proxy.size.height,
                    1
                )

            ZStack(
                alignment:
                    .topLeading
            ) {
                RoundedRectangle(
                    cornerRadius: 4,
                    style: .continuous
                )
                .fill(
                    Color(
                        uiColor:
                            .systemGray6
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                    .stroke(
                        isSelected
                        ? Color.accentColor
                        : Color.black.opacity(0.24),
                        lineWidth:
                            isSelected
                            ? 2
                            : 1
                    )
                }

                ForEach(
                    visibleComponents(
                        for:
                            module
                    ),
                    id:
                        \.id
                ) {
                    component in

                    componentElevationShape(
                        component:
                            component,
                        module:
                            module,
                        canvas:
                            CGSize(
                                width:
                                    innerWidth,
                                height:
                                    innerHeight
                            )
                    )
                }

                Text("M\(index + 1)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Color.white.opacity(0.86),
                        in: Capsule()
                    )
                    .padding(6)
            }
        }
        .frame(
            width:
                width,
            height:
                height
        )
        .padding(.trailing, 4)
    }

    private func visibleComponents(
        for module:
            SlidingWardrobeModulePreviewV093
    ) -> [FurnitureComponent] {
        module.components.filter {
            switch $0.role {
            case .shelf,
                 .divider,
                 .rail,
                 .front:
                return true
            // Skrzynka szuflady nie jest rysowana na elewacji garderoby —
            // widać ją dopiero po wysunięciu, a ten rzut pokazuje zamknięty
            // mebel. Front szuflady jest osobnym komponentem i ten widać.
            case .side,
                 .top,
                 .bottom,
                 .back,
                 .worktop,
                 .plinth,
                 .filler,
                 .maskingPanel,
                 .decorativeSide,
                 .reinforcement,
                 .drawerBox,
                 .leg,
                 .custom:
                return false
            }
        }
    }

    @ViewBuilder
    private func componentElevationShape(
        component:
            FurnitureComponent,
        module:
            SlidingWardrobeModulePreviewV093,
        canvas:
            CGSize
    ) -> some View {
        let safeWidth =
            max(
                module.width.rawValue,
                1
            )
        let safeHeight =
            max(
                module.height.rawValue,
                1
            )
        let scaleX =
            canvas.width
            / CGFloat(safeWidth)
        let scaleY =
            canvas.height
            / CGFloat(safeHeight)
        let x =
            CGFloat(
                component.localPosition.x.rawValue
            )
            * scaleX
        let y =
            canvas.height
            - CGFloat(
                component.localPosition.y.rawValue
                + component.size.height.rawValue
            )
            * scaleY
        let width =
            max(
                CGFloat(component.size.width.rawValue)
                * scaleX,
                component.role == .rail
                ? 18
                : 2
            )
        let height =
            max(
                CGFloat(component.size.height.rawValue)
                * scaleY,
                component.role == .rail
                ? 8
                : 2
            )

        switch component.role {
        case .shelf:
            Rectangle()
                .fill(Color.black.opacity(0.42))
                .frame(
                    width:
                        width,
                    height:
                        max(height, 3)
                )
                .offset(
                    x:
                        x,
                    y:
                        y
                )

        case .divider:
            Rectangle()
                .fill(Color.black.opacity(0.32))
                .frame(
                    width:
                        max(width, 3),
                    height:
                        max(height, 24)
                )
                .offset(
                    x:
                        x,
                    y:
                        y
                )

        case .rail:
            Capsule()
                .fill(Color.accentColor.opacity(0.72))
                .frame(
                    width:
                        width,
                    height:
                        max(height, 7)
                )
                .offset(
                    x:
                        x,
                    y:
                        y
                )

        case .front:
            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .fill(Color.orange.opacity(0.22))
            .frame(
                width:
                    width,
                height:
                    max(height, 16)
            )
            .offset(
                x:
                    x,
                y:
                    y
            )

        default:
            EmptyView()
        }
    }

    private func elevationTrackLines(
        width:
            CGFloat,
        height:
            CGFloat
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.orange.opacity(0.72))
                .frame(
                    width:
                        width,
                    height:
                        5
                )
                .offset(
                    y:
                        1
                )

            Rectangle()
                .fill(Color.orange.opacity(0.72))
                .frame(
                    width:
                        width,
                    height:
                        5
                )
                .offset(
                    y:
                        height - 6
                )
        }
        .frame(
            width:
                width,
            height:
                height,
            alignment:
                .topLeading
        )
    }

    private func elevationDoors(
        width:
            CGFloat,
        height:
            CGFloat
    ) -> some View {
        HStack(spacing: -18) {
            ForEach(
                0..<max(run.doorCount, 1),
                id:
                    \.self
            ) {
                index in

                RoundedRectangle(
                    cornerRadius: 5,
                    style: .continuous
                )
                .fill(
                    doorFill.canvasColor
                        .opacity(
                            doorFill == .mirror
                            ? 0.72
                            : 0.88
                        )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                    .stroke(
                        Color.black.opacity(0.24),
                        lineWidth: 1
                    )
                }
                .overlay {
                    Text(
                        "\(doorFill.title) \(index + 1)"
                    )
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 4)
                }
            }
        }
        .frame(
            width:
                width,
            height:
                height
        )
        .clipped()
    }
}

private struct SlidingWardrobeCanvasInspectorV093:
    View
{
    let run:
        SlidingWardrobeModuleRunV087
    @Binding var doorFill:
        SlidingWardrobeDoorFillV093
    @Binding var showsDoorsPreview:
        Bool
    let onAddSystem:
        () -> Void

    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing:
                    12
            ) {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        3
                ) {
                    Text("Aktywny ciąg")
                        .font(.headline)
                    Text(
                        "\(run.assemblyIDs.count) moduły · \(Int(run.width.rawValue)) mm frontu · \(run.doorCount) skrzydła"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                Spacer()

                Button(
                    action:
                        onAddSystem
                ) {
                    Label(
                        run.actionTitle,
                        systemImage:
                            run.isProductionReady
                            ? "checkmark.circle"
                            : "door.sliding.left.hand.closed"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(run.isProductionReady)
            }

            Picker(
                "Podgląd",
                selection:
                    $showsDoorsPreview
            ) {
                Text("Bez drzwi")
                    .tag(false)
                Text("Z drzwiami")
                    .tag(true)
            }
            .pickerStyle(.segmented)

            Picker(
                "Wypełnienie drzwi",
                selection:
                    $doorFill
            ) {
                ForEach(
                    SlidingWardrobeDoorFillV093
                        .allCases
                ) {
                    fill in

                    Label(
                        fill.title,
                        systemImage:
                            fill.systemImage
                    )
                    .tag(fill)
                }
            }
            .pickerStyle(.segmented)
            .disabled(run.isProductionReady)

            if !run.isProductionReady {
                Text(
                    "Akcja zapisze tory pełnej długości, skrzydła \(doorFill.title.lowercased()) oraz domknięcie dla wybranego ciągu."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            StolarniaPalette.canvasRaised,
            in: RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }
}

private struct WardrobeDoorItemV086:
    Identifiable
{
    let id:
        FurnitureAssemblyID
    let name:
        String
    let kind:
        FurnitureAssemblyKind
    let widthMM:
        Double
    let heightMM:
        Double
    let depthMM:
        Double
    let offsetMM:
        Double
    let wallID:
        WallID?
    let isSliding:
        Bool
    let bayCount:
        Int
    let doorCount:
        Int
    let hasInternalDrawers:
        Bool
    let report:
        RaportSzafyPrzesuwanejV075?
    let warnings:
        [String]

    init?(
        stored:
            StoredFurnitureAssembly
    ) {
        let assembly = stored.assembly
        let normalizedName =
            assembly.name
                .folding(
                    options: [
                        .diacriticInsensitive,
                        .caseInsensitive
                    ],
                    locale: .current
                )
                .lowercased()

        let looksLikeWardrobe =
            assembly.kind == .wardrobe
            || assembly.kind == .recessBuiltIn
            || assembly.kind == .slidingWardrobe
            || normalizedName.contains("szafa")
            || normalizedName.contains("garderoba")

        guard looksLikeWardrobe else {
            return nil
        }

        let frontCount =
            assembly.components.filter {
                $0.role == .front
            }
            .count
        let dividerCount =
            assembly.components.filter {
                $0.role == .divider
            }
            .count
        let componentText =
            assembly.components
                .map(\.code)
                .joined(separator: " ")
                .folding(
                    options: [
                        .diacriticInsensitive,
                        .caseInsensitive
                    ],
                    locale: .current
                )
                .lowercased()

        let sliding =
            assembly.kind == .slidingWardrobe
            || normalizedName.contains("przesuw")

        let inferredDoorCount =
            frontCount > 1
            ? frontCount
            : SilnikSzafyPrzesuwanejV075
                .optymalnaLiczbaDrzwi(
                    szerokoscMM:
                        assembly.size.width.rawValue
                )

        var definition =
            SzafaPrzesuwnaDefinicjaV075()
        definition.szerokoscCalkowitaMM =
            assembly.size.width.rawValue
        definition.wysokoscCalkowitaMM =
            assembly.size.height.rawValue
        definition.glebokoscMM =
            assembly.size.depth.rawValue
        definition.liczbaDrzwi =
            min(
                max(
                    inferredDoorCount,
                    2
                ),
                4
            )
        definition.normalize()

        let generatedReport =
            sliding
            ? SilnikSzafyPrzesuwanejV075
                .raport(dla: definition)
            : nil

        var issues =
            generatedReport?.ostrzezenia ?? []

        if sliding,
           definition.glebokoscMM < 600 {
            issues.insert(
                "Głębokość \(Int(definition.glebokoscMM)) mm jest krytycznie mała dla szafy przesuwnej z wieszaniem.",
                at: 0
            )
        } else if sliding,
                  definition.glebokoscMM < 650 {
            issues.insert(
                "Głębokość \(Int(definition.glebokoscMM)) mm wymaga kontroli torów, uchwytów i wieszaków.",
                at: 0
            )
        }

        let drawers =
            componentText.contains("szuf")
            || componentText.contains("drawer")
        if sliding,
           drawers {
            issues.append(
                "Szuflady wewnętrzne wymagają kontroli pełnego wysuwu przy pozycjach skrzydeł. Zalecane odsuniecie od boku/zakładki: \(Int(definition.zalecaneOdsuniecieSzufladOdBokuMM)) mm."
            )
        }

        if sliding,
           dividerCount + 1 != definition.liczbaDrzwi {
            issues.append(
                "Podział wnętrza nie pokrywa się 1:1 z liczbą skrzydeł; sprawdź realne światło dostępu."
            )
        }

        id = assembly.id
        name = assembly.name
        kind = assembly.kind
        widthMM = assembly.size.width.rawValue
        heightMM = assembly.size.height.rawValue
        depthMM = assembly.size.depth.rawValue
        offsetMM =
            assembly.placement?
                .offsetAlongWall
                .rawValue
            ?? 0
        wallID =
            assembly.placement?
                .wallID
        isSliding = sliding
        bayCount =
            max(
                dividerCount + 1,
                1
            )
        doorCount =
            sliding
            ? definition.liczbaDrzwi
            : max(frontCount, 0)
        hasInternalDrawers = drawers
        report = generatedReport
        warnings = issues
    }

    var sortKey:
        String
    {
        "\(wallID?.description ?? "wolne").\(Int(offsetMM)).\(name)"
    }

    var status:
        WardrobeDoorStatusV086
    {
        guard isSliding else {
            return .neutral
        }

        if depthMM < 600 {
            return .blocked
        }

        if !warnings.isEmpty {
            return .warning
        }

        return .ready
    }
}

private enum WardrobeDoorStatusV086 {
    case ready
    case warning
    case blocked
    case neutral

    var title: String {
        switch self {
        case .ready:
            return "OK"
        case .warning:
            return "Kontrola"
        case .blocked:
            return "Ryzyko"
        case .neutral:
            return "Garderoba"
        }
    }

    var color: Color {
        switch self {
        case .ready:
            return .green
        case .warning:
            return .orange
        case .blocked:
            return .red
        case .neutral:
            return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.octagon.fill"
        case .neutral:
            return "cabinet"
        }
    }
}

