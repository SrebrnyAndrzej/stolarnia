import DomainCore
import Foundation

enum TechnicalInstallationRepositoryV023 {
    private static let storageKey =
        "TechnicalInstallationPointsV023"

    static func load(
        wallID: WallID
    ) -> [TechnicalInstallationPointV023] {
        loadAll().filter {
            $0.wallID == wallID
        }
    }

    static func save(
        _ points:
            [TechnicalInstallationPointV023],
        wallID: WallID
    ) {
        var all = loadAll()
        all.removeAll {
            $0.wallID == wallID
        }
        all.append(contentsOf: points)

        guard let data =
            try? JSONEncoder().encode(all)
        else {
            return
        }
        UserDefaults.standard.set(
            data,
            forKey: storageKey
        )
    }

    static func delete(
        id: UUID,
        wallID: WallID
    ) {
        var points = load(
            wallID: wallID
        )

        points.removeAll {
            $0.id == id
        }

        save(
            points,
            wallID: wallID
        )
    }

    private static func loadAll()
        -> [TechnicalInstallationPointV023]
    {
        guard
            let data = UserDefaults.standard.data(
                forKey: storageKey
            ),
            let points =
                try? JSONDecoder().decode(
                    [
                        TechnicalInstallationPointV023
                    ].self,
                    from: data
                )
        else {
            return []
        }

        return points
    }
}
