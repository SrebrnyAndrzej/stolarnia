import Foundation

enum FurnitureCreatorLocalStoreV018 {
    private static let key =
        "FurnitureCreatorDraftsV018"

    static func save(
        _ draft: FurnitureCreatorDraftV018
    ) {
        var drafts = load()
        drafts.removeAll {
            $0.id == draft.id
        }
        drafts.append(draft)

        guard let data = try? JSONEncoder().encode(
            drafts
        ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }

    static func load()
        -> [FurnitureCreatorDraftV018]
    {
        guard
            let data = UserDefaults.standard.data(
                forKey: key
            ),
            let drafts = try? JSONDecoder().decode(
                [FurnitureCreatorDraftV018].self,
                from: data
            )
        else {
            return []
        }

        return drafts
    }

    static func delete(
        id: UUID
    ) {
        var drafts = load()
        drafts.removeAll {
            $0.id == id
        }

        guard let data = try? JSONEncoder().encode(
            drafts
        ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }
}
