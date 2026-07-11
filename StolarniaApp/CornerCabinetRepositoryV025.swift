import DomainCore
import Foundation

enum CornerCabinetRepositoryV025 {
    private static let key =
        "CornerCabinetDefinitionsV025"

    static func loadAll()
        -> [CornerCabinetDefinitionV025]
    {
        guard
            let data =
                UserDefaults.standard.data(
                    forKey: key
                ),
            let values =
                try? JSONDecoder().decode(
                    [
                        CornerCabinetDefinitionV025
                    ].self,
                    from: data
                )
        else {
            return []
        }

        return values
    }

    static func load(
        assemblyID:
            FurnitureAssemblyID
    ) -> CornerCabinetDefinitionV025? {
        loadAll().first {
            $0.assemblyID
                == assemblyID
        }
    }

    static func save(
        _ definition:
            CornerCabinetDefinitionV025
    ) {
        var values = loadAll()
        values.removeAll {
            $0.assemblyID
                == definition.assemblyID
        }
        values.append(definition)

        guard let data =
            try? JSONEncoder().encode(
                values
            )
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }

    static func delete(
        assemblyID:
            FurnitureAssemblyID
    ) {
        var values = loadAll()
        values.removeAll {
            $0.assemblyID
                == assemblyID
        }

        guard let data =
            try? JSONEncoder().encode(
                values
            )
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }
}
