import Foundation

public enum ProfileDirection: String, Codable, CaseIterable, Sendable {
    case vertical
    case horizontal
}

public enum ProfileReferenceEdge: String, Codable, CaseIterable, Sendable {
    case wallStart
    case wallEnd
    case floor
    case ceiling
    case customReference
}

public struct WallProfilePoint: Identifiable, Codable, Hashable, Sendable {
    public let id: WallProfilePointID
    public var distanceAlongProfile: Millimeters
    public var offsetFromReference: Millimeters
    public var isConfirmed: Bool

    public init(
        id: WallProfilePointID = WallProfilePointID(),
        distanceAlongProfile: Millimeters,
        offsetFromReference: Millimeters,
        isConfirmed: Bool = false
    ) throws {
        guard distanceAlongProfile >= .zero else {
            throw DomainError.invariantViolation(
                "Położenie punktu profilu nie może być ujemne."
            )
        }

        self.id = id
        self.distanceAlongProfile = distanceAlongProfile
        self.offsetFromReference = offsetFromReference
        self.isConfirmed = isConfirmed
    }
}

public enum ScribeRecommendation: String, Codable, CaseIterable, Sendable {
    case standardGap
    case scribeElementRequired
    case addProductionAllowance
    case measureMultipointProfile
    case requireTemplate
}

/// Progi są konfigurowalne przez firmę. Wartości domyślne odpowiadają
/// zaakceptowanej regule 2 / 5 / 10 / 15 mm.
public struct ScribeThresholdProfile: Codable, Hashable, Sendable {
    public var activationThreshold: Millimeters
    public var allowanceThreshold: Millimeters
    public var multipointThreshold: Millimeters
    public var templateThreshold: Millimeters

    public init(
        activationThreshold: Millimeters,
        allowanceThreshold: Millimeters,
        multipointThreshold: Millimeters,
        templateThreshold: Millimeters
    ) throws {
        guard activationThreshold >= .zero,
              allowanceThreshold > activationThreshold,
              multipointThreshold > allowanceThreshold,
              templateThreshold > multipointThreshold else {
            throw DomainError.invariantViolation(
                "Progi trasowania muszą być dodatnie i rosnące."
            )
        }

        self.activationThreshold = activationThreshold
        self.allowanceThreshold = allowanceThreshold
        self.multipointThreshold = multipointThreshold
        self.templateThreshold = templateThreshold
    }

    public static var `default`: ScribeThresholdProfile {
        // Stałe są prawidłowe konstrukcyjnie, dlatego wymuszone rozpakowanie
        // nie może zakończyć się błędem.
        try! ScribeThresholdProfile(
            activationThreshold: 2,
            allowanceThreshold: 5,
            multipointThreshold: 10,
            templateThreshold: 15
        )
    }
}

/// Wielopunktowy profil nierówności ściany, sufitu, podłogi lub wnęki.
public struct WallProfileDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: WallProfileID
    public let wallID: WallID
    public var name: String
    public var direction: ProfileDirection
    public var referenceEdge: ProfileReferenceEdge
    public var referencePlaneOffset: Millimeters
    public private(set) var points: [WallProfilePoint]
    public var productionAllowance: Millimeters
    public var installationAllowance: Millimeters
    public var targetGap: Millimeters

    public init(
        id: WallProfileID = WallProfileID(),
        wallID: WallID,
        name: String,
        direction: ProfileDirection,
        referenceEdge: ProfileReferenceEdge,
        referencePlaneOffset: Millimeters = .zero,
        points: [WallProfilePoint],
        productionAllowance: Millimeters = .zero,
        installationAllowance: Millimeters = .zero,
        targetGap: Millimeters = .zero
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa profilu nie może być pusta.")
        }

        guard points.count >= 2 else {
            throw DomainError.invariantViolation(
                "Profil musi zawierać co najmniej dwa punkty."
            )
        }

        guard productionAllowance >= .zero,
              installationAllowance >= .zero,
              targetGap >= .zero else {
            throw DomainError.invariantViolation(
                "Naddatki i szczelina docelowa nie mogą być ujemne."
            )
        }

        let pointIDs = points.map(\.id)
        guard Set(pointIDs).count == pointIDs.count else {
            throw DomainError.invariantViolation(
                "Punkty profilu muszą mieć unikalne identyfikatory."
            )
        }

        let sortedPoints = points.sorted {
            $0.distanceAlongProfile < $1.distanceAlongProfile
        }

        guard Set(sortedPoints.map(\.distanceAlongProfile)).count == sortedPoints.count else {
            throw DomainError.invariantViolation(
                "Dwa punkty profilu nie mogą mieć tej samej pozycji."
            )
        }

        self.id = id
        self.wallID = wallID
        self.name = normalizedName
        self.direction = direction
        self.referenceEdge = referenceEdge
        self.referencePlaneOffset = referencePlaneOffset
        self.points = sortedPoints
        self.productionAllowance = productionAllowance
        self.installationAllowance = installationAllowance
        self.targetGap = targetGap
    }

    /// Pełny zakres nierówności, np. od -7 mm do +8 mm daje 15 mm.
    public var deviationRange: Millimeters {
        guard let minimum = points.map(\.offsetFromReference).min(),
              let maximum = points.map(\.offsetFromReference).max() else {
            return .zero
        }

        return maximum - minimum
    }

    public var maximumAbsoluteOffset: Millimeters {
        let maximum = points
            .map { abs($0.offsetFromReference.rawValue) }
            .max() ?? 0

        return Millimeters(maximum)
    }

    public func recommendation(
        thresholds: ScribeThresholdProfile = .default
    ) -> ScribeRecommendation {
        let deviation = deviationRange

        if deviation <= thresholds.activationThreshold {
            return .standardGap
        }

        if deviation <= thresholds.allowanceThreshold {
            return .scribeElementRequired
        }

        if deviation <= thresholds.multipointThreshold {
            return .addProductionAllowance
        }

        if deviation <= thresholds.templateThreshold {
            return .measureMultipointProfile
        }

        return .requireTemplate
    }
}
