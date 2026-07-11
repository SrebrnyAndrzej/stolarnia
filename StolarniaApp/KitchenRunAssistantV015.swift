import DomainCore
import Foundation
import Persistence

enum KitchenRunKindV015: String, CaseIterable, Hashable, Sendable {
    case base
    case wall
    case tall

    var title: String {
        switch self {
        case .base:
            return "Ciąg dolny"
        case .wall:
            return "Szafki wiszące"
        case .tall:
            return "Wysoka zabudowa"
        }
    }

    var shortTitle: String {
        switch self {
        case .base:
            return "Dolny"
        case .wall:
            return "Wiszące"
        case .tall:
            return "Wysokie"
        }
    }

    var systemImage: String {
        switch self {
        case .base:
            return "cabinet"
        case .wall:
            return "square.topthird.inset.filled"
        case .tall:
            return "rectangle.portrait"
        }
    }
}

enum KitchenAddDirectionV015: String, CaseIterable, Hashable, Sendable {
    case left
    case right
    case above

    var title: String {
        switch self {
        case .left:
            return "Uzupełnij po lewej"
        case .right:
            return "Uzupełnij po prawej"
        case .above:
            return "Dodaj wiszącą nad ciągiem"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .left:
            return "Dodaj moduł po lewej"
        case .right:
            return "Dodaj moduł po prawej"
        case .above:
            return "Dodaj szafkę wiszącą nad ciągiem dolnym"
        }
    }

    var systemImage: String {
        switch self {
        case .left:
            return "arrow.left"
        case .right:
            return "arrow.right"
        case .above:
            return "arrow.up"
        }
    }
}

struct KitchenDirectionalAdditionV015: Hashable, Sendable {
    let sourceAssemblyID: FurnitureAssemblyID
    let direction: KitchenAddDirectionV015
}

struct KitchenRunV015: Identifiable, Hashable, Sendable {
    let id: String
    let kind: KitchenRunKindV015
    let wallID: WallID
    let assemblyIDs: [FurnitureAssemblyID]
    let startOffset: Millimeters
    let endOffset: Millimeters
    let bottomOffset: Millimeters
    let topOffset: Millimeters

    var width: Millimeters {
        endOffset - startOffset
    }

    func contains(
        _ assemblyID: FurnitureAssemblyID
    ) -> Bool {
        assemblyIDs.contains(assemblyID)
    }
}

enum KitchenFinishingKindV015: String, Hashable, Sendable {
    case leftFiller
    case rightFiller
    case topFiller
    case leftClosingPanel
    case rightClosingPanel

    var systemImage: String {
        switch self {
        case .leftFiller:
            return "rectangle.leftthird.inset.filled"
        case .rightFiller:
            return "rectangle.rightthird.inset.filled"
        case .topFiller:
            return "rectangle.topthird.inset.filled"
        case .leftClosingPanel:
            return "sidebar.left"
        case .rightClosingPanel:
            return "sidebar.right"
        }
    }
}

struct KitchenFinishingSuggestionV015: Identifiable, Hashable, Sendable {
    let id: String
    let kind: KitchenFinishingKindV015
    let templateKind: KitchenFinishingTemplateKindV015
    let runKind: KitchenRunKindV015
    let wallID: WallID
    let sourceAssemblyID: FurnitureAssemblyID
    let title: String
    let reason: String
    let offsetAlongWall: Millimeters
    let bottomOffset: Millimeters
    let width: Millimeters
    let height: Millimeters
    let depth: Millimeters
}

enum KitchenRunAnalyzerV015 {
    private struct Element {
        let assemblyID: FurnitureAssemblyID
        let kind: KitchenRunKindV015
        let x: Millimeters
        let width: Millimeters
        let bottom: Millimeters
        let height: Millimeters

        var right: Millimeters { x + width }
        var top: Millimeters { bottom + height }
    }

    private static let continuityTolerance: Millimeters = 30
    private static let wallLaneTolerance: Millimeters = 250

    static func kind(
        of assembly: FurnitureAssembly
    ) -> KitchenRunKindV015? {
        guard let placement = assembly.placement else {
            return nil
        }

        if placement.anchoringMode == .builtIn,
           assembly.size.height >= 1_200 {
            return .tall
        }

        if placement.bottomOffset <= 150,
           assembly.size.height >= 1_500 {
            return .tall
        }

        if placement.anchoringMode == .wallMounted
            || placement.bottomOffset >= 900 {
            return .wall
        }

        return .base
    }

    static func kind(
        anchoringMode: FurnitureAnchoringMode,
        height: Millimeters,
        bottomOffset: Millimeters
    ) -> KitchenRunKindV015 {
        if anchoringMode == .builtIn, height >= 1_200 {
            return .tall
        }

        if bottomOffset <= 150, height >= 1_500 {
            return .tall
        }

        if anchoringMode == .wallMounted || bottomOffset >= 900 {
            return .wall
        }

        return .base
    }

    static func runs(
        on wallID: WallID,
        assemblies: [FurnitureAssembly]
    ) -> [KitchenRunV015] {
        let elements = assemblies.compactMap { assembly -> Element? in
            guard let placement = assembly.placement,
                  placement.wallID == wallID,
                  let kind = kind(of: assembly) else {
                return nil
            }

            return Element(
                assemblyID: assembly.id,
                kind: kind,
                x: placement.offsetAlongWall,
                width: assembly.size.width,
                bottom: placement.bottomOffset,
                height: assembly.size.height
            )
        }

        var result: [KitchenRunV015] = []

        for kind in KitchenRunKindV015.allCases {
            let matching = elements.filter { $0.kind == kind }
            let lanes = verticalLanes(for: matching, kind: kind)

            for lane in lanes {
                result.append(contentsOf: horizontalRuns(
                    in: lane,
                    kind: kind,
                    wallID: wallID
                ))
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.bottomOffset == rhs.bottomOffset {
                return lhs.startOffset < rhs.startOffset
            }
            return lhs.bottomOffset < rhs.bottomOffset
        }
    }

    static func run(
        containing assemblyID: FurnitureAssemblyID,
        on wallID: WallID,
        assemblies: [FurnitureAssembly]
    ) -> KitchenRunV015? {
        runs(on: wallID, assemblies: assemblies).first {
            $0.contains(assemblyID)
        }
    }

    private static func verticalLanes(
        for elements: [Element],
        kind: KitchenRunKindV015
    ) -> [[Element]] {
        guard kind == .wall else {
            return elements.isEmpty ? [] : [elements]
        }

        var lanes: [[Element]] = []

        for element in elements.sorted(by: {
            if $0.bottom == $1.bottom {
                return $0.x < $1.x
            }
            return $0.bottom < $1.bottom
        }) {
            if let index = lanes.firstIndex(where: { lane in
                guard let reference = lane.first else {
                    return false
                }

                return absolute(
                    reference.bottom - element.bottom
                ) <= wallLaneTolerance
            }) {
                lanes[index].append(element)
            } else {
                lanes.append([element])
            }
        }

        return lanes
    }

    private static func horizontalRuns(
        in elements: [Element],
        kind: KitchenRunKindV015,
        wallID: WallID
    ) -> [KitchenRunV015] {
        let sorted = elements.sorted { lhs, rhs in
            if lhs.x == rhs.x {
                return lhs.bottom < rhs.bottom
            }
            return lhs.x < rhs.x
        }

        guard let first = sorted.first else {
            return []
        }

        var groups: [[Element]] = []
        var current = [first]
        var currentEnd = first.right

        for element in sorted.dropFirst() {
            let gap = element.x - currentEnd

            if gap <= continuityTolerance {
                current.append(element)
                currentEnd = max(currentEnd, element.right)
            } else {
                groups.append(current)
                current = [element]
                currentEnd = element.right
            }
        }

        groups.append(current)

        return groups.compactMap { group in
            guard let first = group.first else {
                return nil
            }

            let start = group.map(\.x).min() ?? first.x
            let end = group.map(\.right).max() ?? first.right
            let bottom = group.map(\.bottom).min() ?? first.bottom
            let top = group.map(\.top).max() ?? first.top

            return KitchenRunV015(
                id: [
                    wallID.description,
                    kind.rawValue,
                    first.assemblyID.description
                ].joined(separator: "-"),
                kind: kind,
                wallID: wallID,
                assemblyIDs: group.map(\.assemblyID),
                startOffset: start,
                endOffset: end,
                bottomOffset: bottom,
                topOffset: top
            )
        }
    }

    private static func absolute(
        _ value: Millimeters
    ) -> Millimeters {
        Millimeters(abs(value.rawValue))
    }
}


enum KitchenRunTemplateClassifierV015 {
    static func anchoringMode(
        for template: FurnitureTemplate
    ) -> FurnitureAnchoringMode {
        if let finishingMode =
            StandardKitchenFinishingTemplatesV015.anchoringMode(
                for: template
            ) {
            return finishingMode
        }

        if let catalogMode =
            StandardKitchenTemplatesV0143.anchoringMode(
                for: template
            ) {
            return catalogMode
        }

        switch template.category {
        case .kitchenWallCabinet:
            return .wallMounted
        case .kitchenTallCabinet:
            return .builtIn
        default:
            break
        }

        switch template.builderType {
        case .wallCabinet:
            return .wallMounted
        default:
            return .floorStanding
        }
    }

    static func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters {
        StandardKitchenFinishingTemplatesV015.defaultBottomOffset(
            for: template
        )
        ?? StandardKitchenTemplatesV0143.defaultBottomOffset(
            for: template
        )
        ?? (
            anchoringMode(for: template) == .wallMounted
            ? 1_400
            : .zero
        )
    }

    static func kind(
        for template: FurnitureTemplate
    ) -> KitchenRunKindV015 {
        if let finishingKind =
            StandardKitchenFinishingTemplatesV015.kind(
                for: template
            ) {
            return finishingKind.runKind
        }

        let height =
            (try? template.defaultParameters.millimeters(
                for: .height
            )) ?? 720

        return KitchenRunAnalyzerV015.kind(
            anchoringMode: anchoringMode(for: template),
            height: height,
            bottomOffset: defaultBottomOffset(
                for: template
            )
        )
    }
}

extension MeblePomieszczeniaViewModel {
    func kitchenRuns(
        on wall: WallSegment
    ) -> [KitchenRunV015] {
        KitchenRunAnalyzerV015.runs(
            on: wall.id,
            assemblies: assemblies
        )
    }

    func availableDirections(
        for stored: StoredFurnitureAssembly,
        wall: WallSegment,
        room: RoomDefinition
    ) -> Set<KitchenAddDirectionV015> {
        Set(
            KitchenAddDirectionV015.allCases.filter { direction in
                !directionalTemplates(
                    relativeTo: stored,
                    direction: direction,
                    wall: wall,
                    room: room
                ).isEmpty
            }
        )
    }

    func directionalTemplates(
        relativeTo stored: StoredFurnitureAssembly,
        direction: KitchenAddDirectionV015,
        wall: WallSegment,
        room: RoomDefinition
    ) -> [FurnitureTemplate] {
        templates.filter { template in
            guard !StandardKitchenFinishingTemplatesV015
                .isFinishingTemplate(template) else {
                return false
            }

            return directionalSuggestion(
                for: template,
                relativeTo: stored,
                direction: direction,
                wall: wall,
                room: room
            ) != nil
        }
    }

    func directionalSuggestion(
        for template: FurnitureTemplate,
        relativeTo stored: StoredFurnitureAssembly,
        direction: KitchenAddDirectionV015,
        wall: WallSegment,
        room: RoomDefinition
    ) -> SugerowanePolozenieModulu? {
        guard let sourcePlacement = stored.assembly.placement,
              sourcePlacement.wallID == wall.id,
              let wallGeometry =
                room.geometry.geometry(of: wall.id),
              case .line = wallGeometry,
              let sourceKind = KitchenRunAnalyzerV015.kind(
                  of: stored.assembly
              ) else {
            return nil
        }

        let targetKind: KitchenRunKindV015

        switch direction {
        case .left, .right:
            targetKind = sourceKind

        case .above:
            guard sourceKind == .base else {
                return nil
            }
            targetKind = .wall
        }

        guard KitchenRunTemplateClassifierV015.kind(
            for: template
        ) == targetKind else {
            return nil
        }

        let templateWidth =
            (try? template.defaultParameters.millimeters(
                for: .width
            )) ?? 600
        let templateHeight =
            (try? template.defaultParameters.millimeters(
                for: .height
            )) ?? 720
        let templateDepth =
            (try? template.defaultParameters.millimeters(
                for: .depth
            )) ?? 560

        let targetBottom: Millimeters
        let targetOffsetFromWall: Millimeters

        switch direction {
        case .left, .right:
            targetBottom = sourcePlacement.bottomOffset
            targetOffsetFromWall =
                sourcePlacement.offsetFromWall

        case .above:
            targetBottom =
                KitchenRunTemplateClassifierV015
                    .defaultBottomOffset(for: template)
            targetOffsetFromWall = .zero
        }

        let freeInterval: (
            start: Millimeters,
            width: Millimeters
        )?

        switch direction {
        case .left:
            let sourceStart =
                sourcePlacement.offsetAlongWall
            let boundary = runAssistantBoundary(
                before: sourceStart,
                wallID: wall.id,
                bottom: targetBottom,
                height: templateHeight,
                offsetFromWall: targetOffsetFromWall,
                depth: templateDepth,
                excluding: stored.id
            )
            let available = sourceStart - boundary

            guard available >= runAssistantMinimumWidth else {
                return nil
            }

            let initialWidth = min(
                templateWidth,
                available
            )
            freeInterval = (
                start: sourceStart - initialWidth,
                width: available
            )

        case .right:
            let sourceEnd =
                sourcePlacement.offsetAlongWall
                + stored.assembly.size.width
            let boundary = runAssistantBoundary(
                after: sourceEnd,
                wallID: wall.id,
                wallLength: wallGeometry.length,
                bottom: targetBottom,
                height: templateHeight,
                offsetFromWall: targetOffsetFromWall,
                depth: templateDepth,
                excluding: stored.id
            )
            let available = boundary - sourceEnd

            guard available >= runAssistantMinimumWidth else {
                return nil
            }

            freeInterval = (
                start: sourceEnd,
                width: available
            )

        case .above:
            guard let baseRun = KitchenRunAnalyzerV015.run(
                containing: stored.id,
                on: wall.id,
                assemblies: assemblies
            ),
            baseRun.kind == .base else {
                return nil
            }

            freeInterval = runAssistantFirstFreeInterval(
                within: baseRun.startOffset...baseRun.endOffset,
                wallID: wall.id,
                bottom: targetBottom,
                height: templateHeight,
                offsetFromWall: targetOffsetFromWall,
                depth: templateDepth,
                excluding: nil,
                room: room
            )
        }

        guard let freeInterval,
              freeInterval.width >= runAssistantMinimumWidth else {
            return nil
        }

        return SugerowanePolozenieModulu(
            offsetAlongWall: freeInterval.start,
            offsetFromWall: targetOffsetFromWall,
            bottomOffset: targetBottom,
            maximumWidth: freeInterval.width,
            requiredAnchoringMode: nil,
            requiredRunKind: targetKind,
            rightEdgeAnchor: direction == .left
                ? sourcePlacement.offsetAlongWall
                : nil
        )
    }

    func finishingSuggestions(
        for stored: StoredFurnitureAssembly?,
        wall: WallSegment,
        room: RoomDefinition
    ) -> [KitchenFinishingSuggestionV015] {
        guard let stored,
              let placement = stored.assembly.placement,
              placement.wallID == wall.id,
              let wallGeometry =
                room.geometry.geometry(of: wall.id),
              case .line = wallGeometry,
              let kind = KitchenRunAnalyzerV015.kind(
                  of: stored.assembly
              ) else {
            return []
        }

        let maximumSideFiller: Millimeters = 150
        let minimumFiller: Millimeters = 5
        let fillerDepth: Millimeters = 100
        let sourceStart = placement.offsetAlongWall
        let sourceEnd =
            sourceStart + stored.assembly.size.width
        let sourceBottom = placement.bottomOffset
        let sourceHeight = stored.assembly.size.height

        var result: [KitchenFinishingSuggestionV015] = []

        let leftBoundary = runAssistantBoundary(
            before: sourceStart,
            wallID: wall.id,
            bottom: sourceBottom,
            height: sourceHeight,
            offsetFromWall: placement.offsetFromWall,
            depth: fillerDepth,
            excluding: stored.id
        )
        let leftGap = sourceStart - leftBoundary

        if leftGap >= minimumFiller,
           leftGap <= maximumSideFiller,
           runAssistantAreaIsClearOfOpenings(
               wall: wall,
               room: room,
               x: leftBoundary,
               width: leftGap,
               bottom: sourceBottom,
               height: sourceHeight
           ) {
            result.append(
                KitchenFinishingSuggestionV015(
                    id:
                        "\(stored.id.description)-left-\(Int(leftGap.rawValue.rounded()))",
                    kind: .leftFiller,
                    templateKind:
                        runAssistantFinishingTemplateKind(
                            for: kind
                        ),
                    runKind: kind,
                    wallID: wall.id,
                    sourceAssemblyID: stored.id,
                    title:
                        "Dodaj blendę lewą \(runAssistantFormatted(leftGap))",
                    reason:
                        "Domknie szczelinę po lewej stronie modułu.",
                    offsetAlongWall: leftBoundary,
                    bottomOffset: sourceBottom,
                    width: leftGap,
                    height: sourceHeight,
                    depth: fillerDepth
                )
            )
        }

        let rightBoundary = runAssistantBoundary(
            after: sourceEnd,
            wallID: wall.id,
            wallLength: wallGeometry.length,
            bottom: sourceBottom,
            height: sourceHeight,
            offsetFromWall: placement.offsetFromWall,
            depth: fillerDepth,
            excluding: stored.id
        )
        let rightGap = rightBoundary - sourceEnd

        if rightGap >= minimumFiller,
           rightGap <= maximumSideFiller,
           runAssistantAreaIsClearOfOpenings(
               wall: wall,
               room: room,
               x: sourceEnd,
               width: rightGap,
               bottom: sourceBottom,
               height: sourceHeight
           ) {
            result.append(
                KitchenFinishingSuggestionV015(
                    id:
                        "\(stored.id.description)-right-\(Int(rightGap.rawValue.rounded()))",
                    kind: .rightFiller,
                    templateKind:
                        runAssistantFinishingTemplateKind(
                            for: kind
                        ),
                    runKind: kind,
                    wallID: wall.id,
                    sourceAssemblyID: stored.id,
                    title:
                        "Dodaj blendę prawą \(runAssistantFormatted(rightGap))",
                    reason:
                        "Domknie szczelinę po prawej stronie modułu.",
                    offsetAlongWall: sourceEnd,
                    bottomOffset: sourceBottom,
                    width: rightGap,
                    height: sourceHeight,
                    depth: fillerDepth
                )
            )
        }

        // Wieńce zamykające (closing side panels) — suggest at open run ends
        let closingPanelWidth: Millimeters = 18
        let closingPanelThreshold: Millimeters = 3
        if let run = KitchenRunAnalyzerV015.run(
            containing: stored.id,
            on: wall.id,
            assemblies: assemblies
        ) {
            let panelHeight = run.topOffset - run.bottomOffset
            let panelDepth = stored.assembly.size.depth

            if run.startOffset > closingPanelThreshold {
                let panelOffset = max(.zero, run.startOffset - closingPanelWidth)
                if !runAssistantHasClosingPanel(
                    at: panelOffset,
                    wallID: wall.id,
                    bottom: run.bottomOffset,
                    height: panelHeight
                ) {
                    result.append(
                        KitchenFinishingSuggestionV015(
                            id: "\(run.id)-left-closing-panel",
                            kind: .leftClosingPanel,
                            templateKind:
                                runAssistantClosingPanelTemplateKind(
                                    for: kind
                                ),
                            runKind: run.kind,
                            wallID: wall.id,
                            sourceAssemblyID: stored.id,
                            title: "Dodaj wieniec lewy",
                            reason:
                                "Domknie widoczną lewą stronę ciągu meblowego.",
                            offsetAlongWall: panelOffset,
                            bottomOffset: run.bottomOffset,
                            width: closingPanelWidth,
                            height: panelHeight,
                            depth: panelDepth
                        )
                    )
                }
            }

            if wallGeometry.length - run.endOffset > closingPanelThreshold {
                let panelOffset = run.endOffset
                if !runAssistantHasClosingPanel(
                    at: panelOffset,
                    wallID: wall.id,
                    bottom: run.bottomOffset,
                    height: panelHeight
                ) {
                    result.append(
                        KitchenFinishingSuggestionV015(
                            id: "\(run.id)-right-closing-panel",
                            kind: .rightClosingPanel,
                            templateKind:
                                runAssistantClosingPanelTemplateKind(
                                    for: kind
                                ),
                            runKind: run.kind,
                            wallID: wall.id,
                            sourceAssemblyID: stored.id,
                            title: "Dodaj wieniec prawy",
                            reason:
                                "Domknie widoczną prawą stronę ciągu meblowego.",
                            offsetAlongWall: panelOffset,
                            bottomOffset: run.bottomOffset,
                            width: closingPanelWidth,
                            height: panelHeight,
                            depth: panelDepth
                        )
                    )
                }
            }
        }

        if abs(
            wall.startHeight.rawValue
                - wall.endHeight.rawValue
        ) <= 0.1,
           let run = KitchenRunAnalyzerV015.run(
               containing: stored.id,
               on: wall.id,
               assemblies: assemblies
           ),
           run.kind != .base {
            let topGap =
                wall.startHeight - run.topOffset

            if topGap >= 10,
               topGap <= 250,
               runAssistantAreaIsClearOfOpenings(
                   wall: wall,
                   room: room,
                   x: run.startOffset,
                   width: run.width,
                   bottom: run.topOffset,
                   height: topGap
               ),
               runAssistantAreaIsClearOfFurniture(
                   wallID: wall.id,
                   x: run.startOffset,
                   width: run.width,
                   bottom: run.topOffset,
                   height: topGap,
                   depth: fillerDepth,
                   excluding: Set(run.assemblyIDs)
               ) {
                result.append(
                    KitchenFinishingSuggestionV015(
                        id:
                            "\(run.id)-top-\(Int(topGap.rawValue.rounded()))",
                        kind: .topFiller,
                        templateKind: .topFiller,
                        runKind: run.kind,
                        wallID: wall.id,
                        sourceAssemblyID: stored.id,
                        title:
                            "Dodaj blendę górną \(runAssistantFormatted(topGap))",
                        reason:
                            "Domknie zabudowę do sufitu na całej szerokości ciągu.",
                        offsetAlongWall: run.startOffset,
                        bottomOffset: run.topOffset,
                        width: run.width,
                        height: topGap,
                        depth: fillerDepth
                    )
                )
            }
        }

        return result
    }

    func createFinishing(
        from suggestion: KitchenFinishingSuggestionV015,
        wall: WallSegment,
        room: RoomDefinition
    ) async -> Bool {
        guard suggestion.wallID == wall.id,
              let template =
                StandardKitchenFinishingTemplatesV015.template(
                    for: suggestion.templateKind,
                    in: templates
                ) else {
            errorMessage =
                "Nie znaleziono szablonu blendy."
            return false
        }

        let data = KonfiguracjaModuluMeblowegoDane(
            name: suggestion.templateKind.name,
            width: suggestion.width,
            height: suggestion.height,
            depth: suggestion.depth,
            shelfCount: 0,
            drawerCount: 0,
            offsetAlongWall: suggestion.offsetAlongWall,
            offsetFromWall: .zero,
            bottomOffset: suggestion.bottomOffset
        )

        return await createModule(
            template: template,
            data: data,
            wall: wall,
            room: room
        )
    }

    private var runAssistantMinimumWidth: Millimeters {
        150
    }

    private func runAssistantFinishingTemplateKind(
        for runKind: KitchenRunKindV015
    ) -> KitchenFinishingTemplateKindV015 {
        switch runKind {
        case .base:
            return .baseFiller
        case .wall:
            return .wallFiller
        case .tall:
            return .tallFiller
        }
    }

    private func runAssistantClosingPanelTemplateKind(
        for runKind: KitchenRunKindV015
    ) -> KitchenFinishingTemplateKindV015 {
        switch runKind {
        case .base:
            return .baseClosingPanel
        case .wall:
            return .wallClosingPanel
        case .tall:
            return .tallClosingPanel
        }
    }

    private func runAssistantHasClosingPanel(
        at offsetAlongWall: Millimeters,
        wallID: WallID,
        bottom: Millimeters,
        height: Millimeters
    ) -> Bool {
        storedAssemblies.contains { stored in
            guard let placement = stored.assembly.placement,
                  placement.wallID == wallID,
                  stored.assembly.components.contains(
                      where: { $0.role == .decorativeSide }
                  ),
                  abs(
                      (placement.offsetAlongWall - offsetAlongWall).rawValue
                  ) < 22 else {
                return false
            }
            return runAssistantOverlaps(
                lhsStart: bottom,
                lhsLength: height,
                rhsStart: placement.bottomOffset,
                rhsLength: stored.assembly.size.height
            )
        }
    }

    private func runAssistantBoundary(
        before sourceStart: Millimeters,
        wallID: WallID,
        bottom: Millimeters,
        height: Millimeters,
        offsetFromWall: Millimeters,
        depth: Millimeters,
        excluding assemblyID: FurnitureAssemblyID?
    ) -> Millimeters {
        storedAssemblies.reduce(.zero) { boundary, stored in
            guard stored.id != assemblyID,
                  let placement = stored.assembly.placement,
                  placement.wallID == wallID,
                  runAssistantOverlaps(
                      lhsStart: bottom,
                      lhsLength: height,
                      rhsStart: placement.bottomOffset,
                      rhsLength: stored.assembly.size.height
                  ),
                  runAssistantOverlaps(
                      lhsStart: offsetFromWall,
                      lhsLength: depth,
                      rhsStart: placement.offsetFromWall,
                      rhsLength: stored.assembly.size.depth
                  ) else {
                return boundary
            }

            let otherEnd =
                placement.offsetAlongWall
                + stored.assembly.size.width

            guard otherEnd <= sourceStart + 0.1 else {
                return boundary
            }

            return max(boundary, otherEnd)
        }
    }

    private func runAssistantBoundary(
        after sourceEnd: Millimeters,
        wallID: WallID,
        wallLength: Millimeters,
        bottom: Millimeters,
        height: Millimeters,
        offsetFromWall: Millimeters,
        depth: Millimeters,
        excluding assemblyID: FurnitureAssemblyID?
    ) -> Millimeters {
        storedAssemblies.reduce(wallLength) { boundary, stored in
            guard stored.id != assemblyID,
                  let placement = stored.assembly.placement,
                  placement.wallID == wallID,
                  placement.offsetAlongWall
                    >= sourceEnd - 0.1,
                  runAssistantOverlaps(
                      lhsStart: bottom,
                      lhsLength: height,
                      rhsStart: placement.bottomOffset,
                      rhsLength: stored.assembly.size.height
                  ),
                  runAssistantOverlaps(
                      lhsStart: offsetFromWall,
                      lhsLength: depth,
                      rhsStart: placement.offsetFromWall,
                      rhsLength: stored.assembly.size.depth
                  ) else {
                return boundary
            }

            return min(
                boundary,
                placement.offsetAlongWall
            )
        }
    }

    private func runAssistantFirstFreeInterval(
        within bounds: ClosedRange<Millimeters>,
        wallID: WallID,
        bottom: Millimeters,
        height: Millimeters,
        offsetFromWall: Millimeters,
        depth: Millimeters,
        excluding assemblyID: FurnitureAssemblyID?,
        room: RoomDefinition
    ) -> (
        start: Millimeters,
        width: Millimeters
    )? {
        var occupied: [(
            start: Millimeters,
            end: Millimeters
        )] = []

        for stored in storedAssemblies {
            guard stored.id != assemblyID,
                  let placement = stored.assembly.placement,
                  placement.wallID == wallID,
                  runAssistantOverlaps(
                      lhsStart: bottom,
                      lhsLength: height,
                      rhsStart: placement.bottomOffset,
                      rhsLength: stored.assembly.size.height
                  ),
                  runAssistantOverlaps(
                      lhsStart: offsetFromWall,
                      lhsLength: depth,
                      rhsStart: placement.offsetFromWall,
                      rhsLength: stored.assembly.size.depth
                  ) else {
                continue
            }

            let start = max(
                bounds.lowerBound,
                placement.offsetAlongWall
            )
            let end = min(
                bounds.upperBound,
                placement.offsetAlongWall
                    + stored.assembly.size.width
            )

            if end > start {
                occupied.append((start, end))
            }
        }

        if let wall = room.geometry.wall(id: wallID) {
            for opening in MebelElewacjaScianyGeometry.openings(
                on: wall,
                room: room
            ) {
                guard runAssistantOverlaps(
                    lhsStart: bottom,
                    lhsLength: height,
                    rhsStart: opening.rect.y,
                    rhsLength: opening.rect.height
                ) else {
                    continue
                }

                let start = max(
                    bounds.lowerBound,
                    opening.rect.x
                )
                let end = min(
                    bounds.upperBound,
                    opening.rect.maxX
                )

                if end > start {
                    occupied.append((start, end))
                }
            }
        }

        let sorted = occupied.sorted {
            $0.start < $1.start
        }
        var cursor = bounds.lowerBound

        for interval in sorted {
            let available =
                interval.start - cursor

            if available >= runAssistantMinimumWidth {
                return (
                    start: cursor,
                    width: available
                )
            }

            cursor = max(
                cursor,
                interval.end
            )
        }

        let remaining =
            bounds.upperBound - cursor

        guard remaining >= runAssistantMinimumWidth else {
            return nil
        }

        return (
            start: cursor,
            width: remaining
        )
    }

    private func runAssistantAreaIsClearOfOpenings(
        wall: WallSegment,
        room: RoomDefinition,
        x: Millimeters,
        width: Millimeters,
        bottom: Millimeters,
        height: Millimeters
    ) -> Bool {
        !MebelElewacjaScianyGeometry.openings(
            on: wall,
            room: room
        ).contains { opening in
            runAssistantOverlaps(
                lhsStart: x,
                lhsLength: width,
                rhsStart: opening.rect.x,
                rhsLength: opening.rect.width
            )
            && runAssistantOverlaps(
                lhsStart: bottom,
                lhsLength: height,
                rhsStart: opening.rect.y,
                rhsLength: opening.rect.height
            )
        }
    }

    private func runAssistantAreaIsClearOfFurniture(
        wallID: WallID,
        x: Millimeters,
        width: Millimeters,
        bottom: Millimeters,
        height: Millimeters,
        depth: Millimeters,
        excluding assemblyIDs: Set<FurnitureAssemblyID>
    ) -> Bool {
        !storedAssemblies.contains { stored in
            guard !assemblyIDs.contains(stored.id),
                  let placement = stored.assembly.placement,
                  placement.wallID == wallID else {
                return false
            }

            return runAssistantOverlaps(
                lhsStart: x,
                lhsLength: width,
                rhsStart: placement.offsetAlongWall,
                rhsLength: stored.assembly.size.width
            )
            && runAssistantOverlaps(
                lhsStart: bottom,
                lhsLength: height,
                rhsStart: placement.bottomOffset,
                rhsLength: stored.assembly.size.height
            )
            && runAssistantOverlaps(
                lhsStart: .zero,
                lhsLength: depth,
                rhsStart: placement.offsetFromWall,
                rhsLength: stored.assembly.size.depth
            )
        }
    }

    private func runAssistantOverlaps(
        lhsStart: Millimeters,
        lhsLength: Millimeters,
        rhsStart: Millimeters,
        rhsLength: Millimeters
    ) -> Bool {
        let overlapStart = max(
            lhsStart.rawValue,
            rhsStart.rawValue
        )
        let overlapEnd = min(
            (lhsStart + lhsLength).rawValue,
            (rhsStart + rhsLength).rawValue
        )

        return overlapEnd - overlapStart > 0.1
    }

    private func runAssistantFormatted(
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
