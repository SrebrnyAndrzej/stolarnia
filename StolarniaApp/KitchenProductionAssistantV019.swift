import DomainCore
import Foundation

enum KitchenRunLaneV019: String, CaseIterable, Hashable {
    case base
    case wall
    case tall
    case wardrobe
    case shelving
    case desk
    case builtIn

    var title: String {
        switch self {
        case .base:
            return "Dolne / podblatowe"
        case .wall:
            return "Wiszące"
        case .tall:
            return "Wysokie"
        case .wardrobe:
            return "Garderoba"
        case .shelving:
            return "Regały"
        case .desk:
            return "Biurka"
        case .builtIn:
            return "Zabudowa wnękowa"
        }
    }

    var systemImage: String {
        switch self {
        case .base:
            return "cabinet"
        case .wall:
            return "rectangle.topthird.inset.filled"
        case .tall:
            return "rectangle.portrait"
        case .wardrobe:
            return "door.sliding.left.hand.closed"
        case .shelving:
            return "books.vertical"
        case .desk:
            return "table.furniture"
        case .builtIn:
            return "rectangle.inset.filled"
        }
    }

    var standardWidths: [Double] {
        switch self {
        case .base:
            return [1000, 900, 800, 700, 600, 500, 450, 400, 300, 200, 150]
        case .wall:
            return [1000, 900, 800, 700, 600, 500, 450, 400, 300]
        case .tall:
            return [900, 800, 700, 600, 500, 450, 400, 300]
        case .wardrobe,
             .builtIn:
            return [1200, 1000, 900, 800, 700, 600, 500, 450, 400, 300]
        case .shelving:
            return [1000, 900, 800, 700, 600, 500, 400, 300]
        case .desk:
            return [1600, 1400, 1200, 1000, 900, 800, 700]
        }
    }
}

enum KitchenGapRecommendationV019: Hashable {
    case fillerOnly
    case standardModules
    case customModule

    var title: String {
        switch self {
        case .fillerOnly:
            return "Blenda / maskownica"
        case .standardModules:
            return "Standardowe moduły"
        case .customModule:
            return "Moduł na wymiar"
        }
    }

    var systemImage: String {
        switch self {
        case .fillerOnly:
            return "rectangle.leadinghalf.inset.filled"
        case .standardModules:
            return "square.grid.3x3"
        case .customModule:
            return "slider.horizontal.3"
        }
    }
}

struct KitchenGapSuggestionV019: Identifiable, Hashable {
    let id: String
    let lane: KitchenRunLaneV019
    let start: Millimeters
    let width: Millimeters
    let proposedWidths: [Millimeters]
    let fillerWidth: Millimeters
    let recommendation: KitchenGapRecommendationV019

    var severity: Int {
        switch recommendation {
        case .fillerOnly:
            return 1
        case .standardModules:
            return 3
        case .customModule:
            return 2
        }
    }
}

struct KitchenCountertopSuggestionV019: Identifiable, Hashable {
    let id: String
    let start: Millimeters
    let width: Millimeters
    let bottomOffset: Millimeters
    let depth: Millimeters
    let thickness: Millimeters
}

struct KitchenBacksplashSuggestionV019: Identifiable, Hashable {
    let id: String
    let start: Millimeters
    let width: Millimeters
    let bottomOffset: Millimeters
    let height: Millimeters
    let thickness: Millimeters
}

struct KitchenProductionAnalysisV019 {
    let gaps: [KitchenGapSuggestionV019]
    let countertops: [KitchenCountertopSuggestionV019]
    let backsplashes: [KitchenBacksplashSuggestionV019]
}

enum KitchenProductionAnalyzerV019 {
    private static let mergeTolerance: Millimeters = 30
    private static let minimumTrackedGap: Millimeters = 25

    static func analyze(
        wall: WallSegment,
        room: RoomDefinition,
        assemblies: [FurnitureAssembly]
    ) -> KitchenProductionAnalysisV019 {
        guard let geometry = room.geometry.geometry(of: wall.id),
              case .line = geometry else {
            return KitchenProductionAnalysisV019(
                gaps: [],
                countertops: [],
                backsplashes: []
            )
        }

        let placed = assemblies.compactMap {
            assembly -> (lane: KitchenRunLaneV019, start: Millimeters, end: Millimeters, assembly: FurnitureAssembly)? in
            guard let placement = assembly.placement,
                  placement.wallID == wall.id,
                  let lane = lane(for: assembly, placement: placement) else {
                return nil
            }

            return (
                lane,
                placement.offsetAlongWall,
                placement.offsetAlongWall + assembly.size.width,
                assembly
            )
        }
        .sorted {
            if $0.lane == $1.lane {
                return $0.start < $1.start
            }
            return laneSortIndex($0.lane) < laneSortIndex($1.lane)
        }

        let grouped =
            Dictionary(
                grouping: placed,
                by: { $0.lane }
            )

        var allGaps: [KitchenGapSuggestionV019] = []

        for lane in KitchenRunLaneV019.allCases {
            let laneIntervals =
                grouped[lane, default: []]
                    .map { ($0.start, $0.end) }
            guard !laneIntervals.isEmpty else {
                continue
            }

            let merged = merge(laneIntervals)
            allGaps += gapSuggestions(
                lane: lane,
                wallLength: geometry.length,
                occupied: merged
            )
        }

        let baseMerged = merge(
            grouped[.base, default: []]
                .map { ($0.start, $0.end) }
        )

        let countertops = baseMerged.enumerated().map { index, interval in
            KitchenCountertopSuggestionV019(
                id: "countertop-\(index)",
                start: interval.0,
                width: interval.1 - interval.0,
                bottomOffset: 900,
                depth: 620,
                thickness: 38
            )
        }

        let backsplashes = baseMerged.enumerated().map { index, interval in
            KitchenBacksplashSuggestionV019(
                id: "backsplash-\(index)",
                start: interval.0,
                width: interval.1 - interval.0,
                bottomOffset: 900,
                height: 500,
                thickness: 12
            )
        }

        return KitchenProductionAnalysisV019(
            gaps: allGaps.sorted {
                if $0.severity == $1.severity {
                    if $0.lane == $1.lane {
                        return $0.start < $1.start
                    }
                    return laneSortIndex($0.lane) < laneSortIndex($1.lane)
                }
                return $0.severity > $1.severity
            },
            countertops: countertops,
            backsplashes: backsplashes
        )
    }

    private static func merge(
        _ intervals: [(Millimeters, Millimeters)]
    ) -> [(Millimeters, Millimeters)] {
        guard let first = intervals.first else {
            return []
        }

        var result: [(Millimeters, Millimeters)] = []
        var current = first

        for interval in intervals.dropFirst() {
            if interval.0 <= current.1 + mergeTolerance {
                current.1 = max(current.1, interval.1)
            } else {
                result.append(current)
                current = interval
            }
        }

        result.append(current)
        return result
    }

    private static func gapSuggestions(
        lane: KitchenRunLaneV019,
        wallLength: Millimeters,
        occupied: [(Millimeters, Millimeters)]
    ) -> [KitchenGapSuggestionV019] {
        var result: [KitchenGapSuggestionV019] = []
        var cursor = Millimeters.zero

        for interval in occupied {
            let width = interval.0 - cursor
            if width >= minimumTrackedGap {
                result.append(
                    makeGap(
                        lane: lane,
                        start: cursor,
                        width: width
                    )
                )
            }
            cursor = max(cursor, interval.1)
        }

        let finalWidth = wallLength - cursor
        if finalWidth >= minimumTrackedGap {
            result.append(
                makeGap(
                    lane: lane,
                    start: cursor,
                    width: finalWidth
                )
            )
        }

        return result
    }

    private static func makeGap(
        lane: KitchenRunLaneV019,
        start: Millimeters,
        width: Millimeters
    ) -> KitchenGapSuggestionV019 {
        var remaining = width.rawValue
        var modules: [Millimeters] = []

        for standard in lane.standardWidths {
            while remaining >= standard {
                modules.append(Millimeters(standard))
                remaining -= standard
            }
        }

        let recommendation: KitchenGapRecommendationV019
        if width.rawValue < 150 {
            recommendation = .fillerOnly
            modules.removeAll()
            remaining = width.rawValue
        } else if modules.isEmpty {
            recommendation = .customModule
            remaining = 0
        } else {
            recommendation = .standardModules
        }

        return KitchenGapSuggestionV019(
            id: "\(lane.rawValue)-gap-\(Int(start.rawValue))-\(Int(width.rawValue))",
            lane: lane,
            start: start,
            width: width,
            proposedWidths: modules,
            fillerWidth: Millimeters(max(remaining, 0)),
            recommendation: recommendation
        )
    }

    private static func lane(
        for assembly: FurnitureAssembly,
        placement: FurniturePlacement
    ) -> KitchenRunLaneV019? {
        if assembly.components.contains(where: {
            $0.role == .worktop
                || $0.role == .plinth
                || $0.role == .maskingPanel
        }) && assembly.kind == .custom {
            return nil
        }

        switch assembly.kind {
        case .wardrobe,
             .slidingWardrobe:
            return .wardrobe
        case .recessBuiltIn:
            return .builtIn
        case .shelving:
            return .shelving
        case .desk:
            return .desk
        case .table:
            return nil
        case .cabinet,
             .custom:
            if placement.anchoringMode == .wallMounted
                || placement.bottomOffset.rawValue >= 1_050 {
                return .wall
            }

            if assembly.size.height.rawValue >= 1_500 {
                return .tall
            }

            return .base
        }
    }

    private static func laneSortIndex(
        _ lane: KitchenRunLaneV019
    ) -> Int {
        KitchenRunLaneV019.allCases.firstIndex(of: lane) ?? 0
    }
}
