import DomainCore
import Foundation
import SwiftUI

enum TechnicalDrawingModeV023:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case simplified
    case dimensioned
    case technical
    case production
    case installations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplified:
            return "Uproszczona"
        case .dimensioned:
            return "Wymiarowa"
        case .technical:
            return "Techniczna"
        case .production:
            return "Produkcyjna"
        case .installations:
            return "Instalacje"
        }
    }

    var systemImage: String {
        switch self {
        case .simplified:
            return "rectangle.3.group"
        case .dimensioned:
            return "ruler"
        case .technical:
            return "square.grid.3x3"
        case .production:
            return "hammer"
        case .installations:
            return "bolt"
        }
    }
}

enum TechnicalDrawingLayerV023:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case carcasses
    case fronts
    case dimensions
    case labels
    case hiddenLines
    case installations
    case hardware

    var id: String { rawValue }

    var title: String {
        switch self {
        case .carcasses:
            return "Korpusy"
        case .fronts:
            return "Fronty"
        case .dimensions:
            return "Wymiary"
        case .labels:
            return "Opisy"
        case .hiddenLines:
            return "Linie ukryte"
        case .installations:
            return "Instalacje"
        case .hardware:
            return "Okucia"
        }
    }
}

enum DimensionKindV023:
    String,
    Codable,
    CaseIterable
{
    case horizontal
    case vertical
    case aligned
    case angular
    case elevationLevel
    case chain
    case overall
}

struct TechnicalPoint2DV023:
    Codable,
    Hashable
{
    var xMM: Double
    var yMM: Double
}

struct DimensionAnnotationV023:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var start: TechnicalPoint2DV023
    var end: TechnicalPoint2DV023
    var offsetMM: Double
    var kind: DimensionKindV023
    var customText: String?
    var layer:
        TechnicalDrawingLayerV023 = .dimensions

    var measuredValueMM: Double {
        let dx = end.xMM - start.xMM
        let dy = end.yMM - start.yMM
        return hypot(dx, dy)
    }

    var displayText: String {
        if let customText,
           !customText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty {
            return customText
        }

        return "\(Int(measuredValueMM.rounded()))"
    }
}

enum TechnicalInstallationKindV023:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case electricalSocket
    case appliancePower
    case lightingPower
    case waterCold
    case waterHot
    case drain
    case gas
    case ventilation
    case network
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .electricalSocket:
            return "Gniazdko"
        case .appliancePower:
            return "Zasilanie AGD"
        case .lightingPower:
            return "Zasilanie oświetlenia"
        case .waterCold:
            return "Zimna woda"
        case .waterHot:
            return "Ciepła woda"
        case .drain:
            return "Odpływ"
        case .gas:
            return "Gaz"
        case .ventilation:
            return "Wentylacja"
        case .network:
            return "Sieć"
        case .custom:
            return "Inny punkt"
        }
    }

    var symbol: String {
        switch self {
        case .electricalSocket:
            return "◉"
        case .appliancePower:
            return "⚡"
        case .lightingPower:
            return "✦"
        case .waterCold:
            return "C"
        case .waterHot:
            return "H"
        case .drain:
            return "Ø"
        case .gas:
            return "G"
        case .ventilation:
            return "V"
        case .network:
            return "N"
        case .custom:
            return "•"
        }
    }
}

struct TechnicalInstallationPointV023:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var wallID: WallID
    var kind:
        TechnicalInstallationKindV023
    var offsetAlongWallMM: Double
    var heightFromFloorMM: Double
    var widthMM: Double
    var note: String
    var linkedAssemblyID:
        FurnitureAssemblyID?

    init(
        id: UUID = UUID(),
        wallID: WallID,
        kind:
            TechnicalInstallationKindV023,
        offsetAlongWallMM: Double,
        heightFromFloorMM: Double,
        widthMM: Double = 0,
        note: String = "",
        linkedAssemblyID:
            FurnitureAssemblyID? = nil
    ) {
        self.id = id
        self.wallID = wallID
        self.kind = kind
        self.offsetAlongWallMM =
            max(offsetAlongWallMM, 0)
        self.heightFromFloorMM =
            max(heightFromFloorMM, 0)
        self.widthMM = max(widthMM, 0)
        self.note = note
        self.linkedAssemblyID =
            linkedAssemblyID
    }
}

struct TechnicalDrawingStyleV023 {
    var majorLineWidth: CGFloat = 1.6
    var minorLineWidth: CGFloat = 0.9
    var hiddenLineWidth: CGFloat = 0.7
    var dimensionLineWidth: CGFloat = 0.8
    var labelFontSize: CGFloat = 11
    var dimensionFontSize: CGFloat = 10
    var margin: CGFloat = 54
    var arrowSize: CGFloat = 5
}

struct TechnicalDrawingDocumentV023 {
    var title: String
    var wall: WallSegment
    var assemblies: [FurnitureAssembly]
    var dimensions:
        [DimensionAnnotationV023]
    var installationPoints:
        [TechnicalInstallationPointV023]

    var contentWidthMM: Double {
        let furnitureExtent =
            assemblies.compactMap {
                assembly -> Double? in

                guard let placement =
                    assembly.placement
                else {
                    return nil
                }

                return placement
                    .offsetAlongWall
                    .rawValue
                    + assembly.size
                        .width.rawValue
            }
            .max() ?? 0

        let installationExtent =
            installationPoints.map {
                $0.offsetAlongWallMM
                + max($0.widthMM, 1)
            }
            .max() ?? 0

        return max(
            furnitureExtent,
            installationExtent,
            1_000
        )
    }

    var contentHeightMM: Double {
        max(
            wall.startHeight.rawValue,
            wall.endHeight.rawValue,
            2_000
        )
    }
}
