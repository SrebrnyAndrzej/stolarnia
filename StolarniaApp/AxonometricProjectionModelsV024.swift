import CoreGraphics
import Foundation

enum DocumentationProjectionKindV024:
    String,
    CaseIterable,
    Identifiable
{
    case elevation
    case axonometry
    case roomAxonometry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elevation:
            return "Elewacja"
        case .axonometry:
            return "Ściana 3D"
        case .roomAxonometry:
            return "Pomieszczenie 3D"
        }
    }

    var systemImage: String {
        switch self {
        case .elevation:
            return "rectangle.split.3x1"
        case .axonometry:
            return "cube"
        case .roomAxonometry:
            return "cube.transparent"
        }
    }
}

enum AxonometricDirectionV024:
    String,
    CaseIterable,
    Identifiable
{
    case frontLeft
    case frontRight
    case rearLeft
    case rearRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frontLeft:
            return "Lewy przód"
        case .frontRight:
            return "Prawy przód"
        case .rearLeft:
            return "Lewy tył"
        case .rearRight:
            return "Prawy tył"
        }
    }

    var xSign: CGFloat {
        switch self {
        case .frontLeft,
             .rearLeft:
            return 1
        case .frontRight,
             .rearRight:
            return -1
        }
    }

    var zSign: CGFloat {
        switch self {
        case .frontLeft,
             .frontRight:
            return 1
        case .rearLeft,
             .rearRight:
            return -1
        }
    }
}

struct AxonometricSettingsV024 {
    var direction:
        AxonometricDirectionV024 = .frontLeft
    var showFronts = true
    var showModuleNumbers = true
    var showDimensions = true
    var showHiddenEdges = false
    var showFloorPlane = true
    var depthScale = 0.72
    var verticalScale = 1.0
}

struct AxonometricPoint3DV024 {
    var x: Double
    var y: Double
    var z: Double
}

struct AxonometricBoxV024 {
    var minX: Double
    var minY: Double
    var minZ: Double
    var width: Double
    var height: Double
    var depth: Double
    var label: String
}

struct AxonometricProjectionV024 {
    let direction:
        AxonometricDirectionV024
    let depthScale: CGFloat
    let verticalScale: CGFloat

    init(
        direction:
            AxonometricDirectionV024,
        depthScale: Double,
        verticalScale: Double
    ) {
        self.direction = direction
        self.depthScale =
            CGFloat(depthScale)
        self.verticalScale =
            CGFloat(verticalScale)
    }

    func project(
        _ point:
            AxonometricPoint3DV024
    ) -> CGPoint {
        let angle = CGFloat.pi / 6
        let x =
            CGFloat(point.x)
            * direction.xSign
        let z =
            CGFloat(point.z)
            * direction.zSign
            * depthScale

        return CGPoint(
            x:
                (x - z)
                * cos(angle),
            y:
                -CGFloat(point.y)
                * verticalScale
                + (x + z)
                * sin(angle)
        )
    }
}
