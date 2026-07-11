import Combine
import Foundation
import os

@MainActor
final class PomiarGarderobySkosyRepository:
    ObservableObject
{
    @Published private(set) var pomiary:
        [PomiarGarderobySkosy] = []

    private let defaults:
        UserDefaults
    private let key =
        "stolarnia.pomiary.garderoby.skosy.v1"

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults
        load()
    }

    func addNew(
        context:
            KontekstPomiaruPomieszczenia?
            = nil
    ) -> PomiarGarderobySkosy {
        var pomiar =
            PomiarGarderobySkosy()

        if let context {
            pomiar.projectID =
                context.projectID
            pomiar.roomID =
                context.roomID
            pomiar.projectName =
                context.projectName
            pomiar.roomName =
                context.roomName
            pomiar.nazwaPomieszczenia =
                context.roomName
            pomiar.klient =
                context.customerName
            pomiar.status =
                .rozpoczęty
            pomiar.lastModified =
                Date()
        }

        pomiary.insert(
            pomiar,
            at: 0
        )

        save()
        return pomiar
    }

    func upsert(
        _ pomiar:
            PomiarGarderobySkosy
    ) {
        var updated = pomiar
        updated.status =
            updated.automatycznyStatus
        updated.lastModified =
            Date()

        if let index =
            pomiary.firstIndex(
                where: {
                    $0.id == pomiar.id
                }
            ) {
            pomiary[index] = updated
        } else {
            pomiary.insert(
                updated,
                at: 0
            )
        }

        save()
    }

    func measurements(
        projectID: String,
        roomID: String
    ) -> [PomiarGarderobySkosy] {
        pomiary.filter {
            $0.projectID == projectID
            && $0.roomID == roomID
        }
    }

    func reload() {
        load()
    }

    func delete(
        id: UUID
    ) {
        pomiary.removeAll {
            $0.id == id
        }

        save()
    }

    private func load() {
        guard let data =
            defaults.data(
                forKey: key
            )
        else {
            pomiary = []
            return
        }

        do {
            pomiary =
                try JSONDecoder()
                    .decode(
                        [PomiarGarderobySkosy].self,
                        from: data
                    )
        } catch {
            pomiary = []
        }
    }

    private func save() {
        do {
            let data =
                try JSONEncoder()
                    .encode(pomiary)

            defaults.set(
                data,
                forKey: key
            )
        } catch {
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać pomiarów: \(error.localizedDescription)"
            )
        }
    }
}
