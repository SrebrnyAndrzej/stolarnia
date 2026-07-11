import Foundation

public enum FurnitureFrontOpeningV020:
    String,
    Codable,
    CaseIterable,
    Sendable
{
    case leftHinged
    case rightHinged
    case liftUp
    case flapDown
    case drawer
    case sliding
    case fixed
}

public enum FurnitureFinishV020:
    String,
    Codable,
    CaseIterable,
    Sendable
{
    case whiteMatt
    case whiteGloss
    case cashmere
    case anthracite
    case blackMatt
    case oakNatural
    case oakLight
    case walnut
    case gray
}

public struct FurnitureFrontSpecificationV020:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    public var id: UUID
    public var segmentIndex: Int
    public var opening:
        FurnitureFrontOpeningV020
    public var openingAngleDegrees: Double
    public var finish:
        FurnitureFinishV020

    public init(
        id: UUID = UUID(),
        segmentIndex: Int,
        opening:
            FurnitureFrontOpeningV020,
        openingAngleDegrees: Double,
        finish:
            FurnitureFinishV020
    ) {
        self.id = id
        self.segmentIndex = segmentIndex
        self.opening = opening
        self.openingAngleDegrees =
            openingAngleDegrees
        self.finish = finish
    }
}

public struct SpaceTowerZoneSpecificationV020:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    public enum Kind:
        String,
        Codable,
        Hashable,
        Sendable
    {
        case lowerDrawers
        case middleDrawers
        case upperOpen
        case upperShelves
        case upperClosed
    }

    public var id: UUID
    public var kind: Kind
    public var heightMM: Double
    public var drawerCount: Int
    public var shelfCount: Int

    public init(
        id: UUID = UUID(),
        kind: Kind,
        heightMM: Double,
        drawerCount: Int,
        shelfCount: Int
    ) {
        self.id = id
        self.kind = kind
        self.heightMM = heightMM
        self.drawerCount = drawerCount
        self.shelfCount = shelfCount
    }
}

public struct FurnitureTechnicalSpecificationV020:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    public var id: UUID
    public var templateID:
        FurnitureTemplateID
    public var sourceDraftID: UUID
    public var segmentCount: Int
    public var fronts:
        [FurnitureFrontSpecificationV020]
    public var carcassFinish:
        FurnitureFinishV020
    public var frontFinish:
        FurnitureFinishV020
    public var targetWorktopHeightMM: Double
    public var legHeightMM: Double
    public var countertopThicknessMM: Double
    public var spaceTowerZones:
        [SpaceTowerZoneSpecificationV020]

    // Optional v0.21 fields keep old sidecar files decodable.
    public var constructionKindV021: String?
    public var wardrobeBayCountV021: Int?
    public var slidingDoorCountV021: Int?
    public var wardrobeShelfCountV021: Int?
    public var wardrobeDrawerCountV021: Int?
    public var hangingRailEnabledV021: Bool?

    public init(
        id: UUID = UUID(),
        templateID:
            FurnitureTemplateID,
        sourceDraftID: UUID,
        segmentCount: Int,
        fronts:
            [FurnitureFrontSpecificationV020],
        carcassFinish:
            FurnitureFinishV020,
        frontFinish:
            FurnitureFinishV020,
        targetWorktopHeightMM: Double,
        legHeightMM: Double,
        countertopThicknessMM: Double,
        spaceTowerZones:
            [SpaceTowerZoneSpecificationV020],
        constructionKindV021:
            String? = nil,
        wardrobeBayCountV021:
            Int? = nil,
        slidingDoorCountV021:
            Int? = nil,
        wardrobeShelfCountV021:
            Int? = nil,
        wardrobeDrawerCountV021:
            Int? = nil,
        hangingRailEnabledV021:
            Bool? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.sourceDraftID =
            sourceDraftID
        self.segmentCount =
            segmentCount
        self.fronts = fronts
        self.carcassFinish =
            carcassFinish
        self.frontFinish =
            frontFinish
        self.targetWorktopHeightMM =
            targetWorktopHeightMM
        self.legHeightMM =
            legHeightMM
        self.countertopThicknessMM =
            countertopThicknessMM
        self.spaceTowerZones =
            spaceTowerZones
        self.constructionKindV021 =
            constructionKindV021
        self.wardrobeBayCountV021 =
            wardrobeBayCountV021
        self.slidingDoorCountV021 =
            slidingDoorCountV021
        self.wardrobeShelfCountV021 =
            wardrobeShelfCountV021
        self.wardrobeDrawerCountV021 =
            wardrobeDrawerCountV021
        self.hangingRailEnabledV021 =
            hangingRailEnabledV021
    }
}
