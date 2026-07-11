import Foundation

struct SpaceTowerZoneV019: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case lowerDrawers
        case middleDrawers
        case upperOpen
        case upperShelves
        case upperClosed
    }

    var id = UUID()
    var kind: Kind
    var heightMM: Double
    var drawerCount: Int
    var shelfCount: Int
}

struct FurnitureTechnicalMetadataV019:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var draftID: UUID
    var fronts: [FurnitureFrontDefinitionV018]
    var usage: FurnitureUsageKindV018
    var carcassFinish: FurnitureFinishPresetV018
    var frontFinish: FurnitureFinishPresetV018
    var supportSystem: KitchenBaseHeightSystemV018
    var spaceTowerZones: [SpaceTowerZoneV019]
}

enum FurnitureTechnicalMetadataStoreV019 {
    private static let key =
        "FurnitureTechnicalMetadataV019"

    static func save(
        _ value: FurnitureTechnicalMetadataV019
    ) {
        var all = load()
        all.removeAll {
            $0.draftID == value.draftID
        }
        all.append(value)

        guard let data = try? JSONEncoder().encode(all) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }

    static func load()
        -> [FurnitureTechnicalMetadataV019]
    {
        guard
            let data = UserDefaults.standard.data(
                forKey: key
            ),
            let values = try? JSONDecoder().decode(
                [FurnitureTechnicalMetadataV019].self,
                from: data
            )
        else {
            return []
        }

        return values
    }
}

extension FurnitureCreatorDraftV018 {
    var spaceTowerZonesV019:
        [SpaceTowerZoneV019]
    {
        guard isSpaceTower else {
            return []
        }

        let usableHeight = max(
            heightMM - 36,
            300
        )
        let upperHeight = usableHeight * 0.28
        let drawerHeight =
            usableHeight - upperHeight
        let lowerHeight =
            drawerHeight * 0.52
        let middleHeight =
            drawerHeight - lowerHeight

        let upperKind:
            SpaceTowerZoneV019.Kind

        switch spaceTower.upperZone {
        case .open:
            upperKind = .upperOpen
        case .shelves:
            upperKind = .upperShelves
        case .closed:
            upperKind = .upperClosed
        }

        return [
            SpaceTowerZoneV019(
                kind: .lowerDrawers,
                heightMM: lowerHeight,
                drawerCount:
                    spaceTower.lowerZoneDrawerCount,
                shelfCount: 0
            ),
            SpaceTowerZoneV019(
                kind: .middleDrawers,
                heightMM: middleHeight,
                drawerCount:
                    spaceTower.middleZoneDrawerCount,
                shelfCount: 0
            ),
            SpaceTowerZoneV019(
                kind: upperKind,
                heightMM: upperHeight,
                drawerCount: 0,
                shelfCount:
                    spaceTower.upperShelfCount
            )
        ]
    }

    var technicalMetadataV019:
        FurnitureTechnicalMetadataV019
    {
        FurnitureTechnicalMetadataV019(
            draftID: id,
            fronts: fronts,
            usage: usage,
            carcassFinish: carcassFinish,
            frontFinish: frontFinish,
            supportSystem: baseHeightSystem,
            spaceTowerZones:
                spaceTowerZonesV019
        )
    }
}
