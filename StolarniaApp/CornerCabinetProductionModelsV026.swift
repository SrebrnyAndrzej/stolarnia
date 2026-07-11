import DomainCore
import Foundation

enum CornerProductionMaterialV026:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case carcassBoard
    case backPanel
    case frontBoard
    case solidWood
    case metal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .carcassBoard:
            return "Płyta korpusowa"
        case .backPanel:
            return "Płyta tylna"
        case .frontBoard:
            return "Płyta frontowa"
        case .solidWood:
            return "Drewno"
        case .metal:
            return "Metal"
        }
    }
}

enum EdgeBandingSideV026:
    String,
    Codable,
    CaseIterable,
    Hashable
{
    case top
    case bottom
    case left
    case right

    var title: String {
        switch self {
        case .top:
            return "góra"
        case .bottom:
            return "dół"
        case .left:
            return "lewa"
        case .right:
            return "prawa"
        }
    }
}

struct CornerProductionPartV026:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var name: String
    var quantity: Int
    var lengthMM: Double
    var widthMM: Double
    var thicknessMM: Double
    var material:
        CornerProductionMaterialV026
    var edgeBanding:
        Set<EdgeBandingSideV026>
    var note: String

    var areaSquareMeters: Double {
        (
            lengthMM
            * widthMM
            * Double(quantity)
        ) / 1_000_000
    }
}

struct CornerHardwareItemV026:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var name: String
    var quantity: Int
    var note: String
}

struct CornerProductionPackageV026:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var assemblyID:
        FurnitureAssemblyID
    var cornerDefinitionID: UUID
    var generatedAt = Date()
    var parts:
        [CornerProductionPartV026]
    var hardware:
        [CornerHardwareItemV026]
    var notes: [String]

    var totalBoardAreaSquareMeters: Double {
        parts.reduce(0) {
            $0 + $1.areaSquareMeters
        }
    }

    var totalPartCount: Int {
        parts.reduce(0) {
            $0 + $1.quantity
        }
    }
}
