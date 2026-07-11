import Combine
import Foundation
import os

@MainActor
final class PomiaryNietypoweRepository:
    ObservableObject
{
    @Published private(set) var pomiary:
        [PomiarNietypowy] = []

    private let defaults:
        UserDefaults
    private let key =
        "stolarnia.pomiary.nietypowe.v1"

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        load()
    }

    func add(
        type:
            TypPomiaruNietypowego,
        context:
            KontekstPomiaruPomieszczenia?
            = nil
    ) -> PomiarNietypowy {
        var measurement =
            PomiarNietypowy()

        measurement.typ = type
        measurement.nazwa = type.nazwa

        if let context {
            measurement.projectID =
                context.projectID
            measurement.roomID =
                context.roomID
            measurement.projectName =
                context.projectName
            measurement.roomName =
                context.roomName
            measurement.klient =
                context.customerName
            measurement.pomieszczenie =
                context.roomName
            measurement.status =
                .rozpoczęty
            measurement.lastModified =
                Date()
        }

        pomiary.insert(
            measurement,
            at: 0
        )

        save()
        return measurement
    }

    func upsert(
        _ measurement: PomiarNietypowy
    ) {
        var updated = measurement
        updated.status =
            updated.automatycznyStatus
        updated.lastModified =
            Date()

        if let index = pomiary.firstIndex(
            where: {
                $0.id == measurement.id
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
    ) -> [PomiarNietypowy] {
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
                try JSONDecoder().decode(
                    [PomiarNietypowy].self,
                    from: data
                )
        } catch {
            pomiary = []
        }
    }

    private func save() {
        do {
            let data =
                try JSONEncoder().encode(
                    pomiary
                )

            defaults.set(
                data,
                forKey: key
            )
        } catch {
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać pomiarów nietypowych: \(error.localizedDescription)"
            )
        }
    }
}
