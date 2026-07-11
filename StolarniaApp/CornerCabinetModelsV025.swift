import DomainCore
import Foundation

enum CornerCabinetKindV025:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case lShaped
    case diagonalFront
    case blindCorner
    /// Półnarożnik — skrócony blat wychodzący na sąsiednią ścianę,
    /// widoczna martwa przestrzeń po jednej stronie. Stosowany gdy nie
    /// ma miejsca na pełny moduł L.
    case halfBlind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lShaped:
            return "Narożna L"
        case .diagonalFront:
            return "Front skośny"
        case .blindCorner:
            return "Ślepy narożnik"
        case .halfBlind:
            return "Półnarożnik"
        }
    }

    var systemImage: String {
        switch self {
        case .lShaped:      return "arrow.turn.down.right"
        case .diagonalFront: return "arrow.triangle.turn.up.right.diamond"
        case .blindCorner:  return "rectangle.split.2x1"
        case .halfBlind:    return "rectangle.split.1x2"
        }
    }
}

enum CornerCabinetHandednessV025:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left:
            return "Lewy"
        case .right:
            return "Prawy"
        }
    }
}

struct CornerCabinetDefinitionV025:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var assemblyID:
        FurnitureAssemblyID
    var kind:
        CornerCabinetKindV025
    var handedness:
        CornerCabinetHandednessV025

    var leftArmMM: Double
    var rightArmMM: Double
    var depthMM: Double
    var frontWidthMM: Double
    var deadSpaceMM: Double
    var frontAngleDegrees: Double
    var shelfCount: Int

    init(
        id: UUID = UUID(),
        assemblyID:
            FurnitureAssemblyID,
        kind:
            CornerCabinetKindV025 =
                .lShaped,
        handedness:
            CornerCabinetHandednessV025 =
                .left,
        leftArmMM: Double = 900,
        rightArmMM: Double = 900,
        depthMM: Double = 560,
        frontWidthMM: Double = 450,
        deadSpaceMM: Double = 300,
        frontAngleDegrees: Double = 45,
        shelfCount: Int = 2
    ) {
        self.id = id
        self.assemblyID = assemblyID
        self.kind = kind
        self.handedness =
            handedness
        self.leftArmMM =
            max(leftArmMM, 300)
        self.rightArmMM =
            max(rightArmMM, 300)
        self.depthMM =
            max(depthMM, 300)
        self.frontWidthMM =
            max(frontWidthMM, 200)
        self.deadSpaceMM =
            max(deadSpaceMM, 0)
        self.frontAngleDegrees =
            min(
                max(
                    frontAngleDegrees,
                    20
                ),
                70
            )
        self.shelfCount =
            min(
                max(
                    shelfCount,
                    0
                ),
                8
            )
    }

    var validationMessages:
        [String]
    {
        var messages: [String] = []

        if leftArmMM < depthMM {
            messages.append(
                "Lewe ramię jest krótsze niż głębokość."
            )
        }

        if rightArmMM < depthMM {
            messages.append(
                "Prawe ramię jest krótsze niż głębokość."
            )
        }

        if kind == .blindCorner,
           deadSpaceMM < 150 {
            messages.append(
                "Ślepy narożnik wymaga martwej przestrzeni minimum 150 mm."
            )
        }

        if kind == .halfBlind,
           deadSpaceMM < 50 {
            messages.append(
                "Półnarożnik wymaga wysuniecia minimum 50 mm."
            )
        }

        if kind == .diagonalFront,
           !(20...70).contains(
                frontAngleDegrees
           ) {
            messages.append(
                "Kąt frontu skośnego musi mieścić się w zakresie 20–70°."
            )
        }

        return messages
    }
}
