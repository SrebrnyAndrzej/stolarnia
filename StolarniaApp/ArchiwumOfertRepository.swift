import Combine
import Foundation
import os

@MainActor
final class ArchiwumOfertRepository:
    ObservableObject
{
    @Published private(set) var offers:
        [ZarchiwizowanaOfertaKlienta] = []

    private let defaults:
        UserDefaults
    private let fileManager:
        FileManager

    private let metadataKey =
        "stolarnia.archiwum.ofert.v1"

    init(
        defaults:
            UserDefaults = .standard,
        fileManager:
            FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        load()
    }

    func offers(
        for projectName: String
    ) -> [ZarchiwizowanaOfertaKlienta] {
        offers
            .filter {
                $0.projectName
                    .localizedCaseInsensitiveCompare(
                        projectName
                    )
                == .orderedSame
            }
            .sorted {
                $0.createdAt > $1.createdAt
            }
    }

    @discardableResult
    func archive(
        sourceURL: URL,
        projectName: String,
        customerName: String,
        summary:
            PodsumowanieWariantuWyceny,
        validityDays: Int
    ) throws
        -> ZarchiwizowanaOfertaKlienta
    {
        let id = UUID()
        let fileName =
            "\(id.uuidString)-\(sourceURL.lastPathComponent)"

        let destination =
            try archiveDirectory()
                .appendingPathComponent(
                    fileName
                )

        if fileManager.fileExists(
            atPath: destination.path
        ) {
            try fileManager.removeItem(
                at: destination
            )
        }

        try fileManager.copyItem(
            at: sourceURL,
            to: destination
        )

        let validUntil =
            Calendar.current.date(
                byAdding: .day,
                value:
                    max(
                        validityDays,
                        1
                    ),
                to: Date()
            )
            ?? Date()

        let offer =
            ZarchiwizowanaOfertaKlienta(
                id: id,
                projectName:
                    projectName,
                customerName:
                    customerName,
                variantName:
                    summary.wariant.nazwa,
                grossPrice:
                    summary.cenaBrutto,
                netPrice:
                    summary.cenaNetto,
                vatAmount:
                    summary.vatKwota,
                status: .szkic,
                createdAt: Date(),
                modifiedAt: Date(),
                validUntil:
                    validUntil,
                fileName: fileName
            )

        offers.insert(
            offer,
            at: 0
        )

        save()
        return offer
    }

    func update(
        _ offer:
            ZarchiwizowanaOfertaKlienta
    ) {
        guard let index =
            offers.firstIndex(
                where: {
                    $0.id == offer.id
                }
            )
        else {
            return
        }

        var updated = offer
        updated.modifiedAt = Date()
        offers[index] = updated
        save()
    }

    func setStatus(
        id: UUID,
        status:
            StatusOfertyKlienta
    ) {
        guard let index =
            offers.firstIndex(
                where: {
                    $0.id == id
                }
            )
        else {
            return
        }

        offers[index].status =
            status
        offers[index].modifiedAt =
            Date()
        save()
    }

    func delete(
        id: UUID
    ) {
        guard let offer =
            offers.first(
                where: {
                    $0.id == id
                }
            )
        else {
            return
        }

        try? fileManager.removeItem(
            at:
                fileURL(
                    for: offer
                )
        )

        offers.removeAll {
            $0.id == id
        }

        save()
    }

    func fileURL(
        for offer:
            ZarchiwizowanaOfertaKlienta
    ) -> URL {
        let directory =
            (
                try? archiveDirectory()
            )
            ?? fileManager
                .temporaryDirectory

        return directory
            .appendingPathComponent(
                offer.fileName
            )
    }

    func reload() {
        load()
    }

    private func archiveDirectory()
        throws -> URL
    {
        let applicationSupport =
            try fileManager.url(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask,
                appropriateFor: nil,
                create: true
            )

        let directory =
            applicationSupport
                .appendingPathComponent(
                    "OfferArchive",
                    isDirectory: true
                )

        if !fileManager.fileExists(
            atPath: directory.path
        ) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories:
                    true
            )
        }

        return directory
    }

    private func load() {
        guard let data =
            defaults.data(
                forKey:
                    metadataKey
            )
        else {
            offers = []
            return
        }

        do {
            offers =
                try JSONDecoder()
                    .decode(
                        [ZarchiwizowanaOfertaKlienta].self,
                        from: data
                    )
        } catch {
            offers = []
        }
    }

    private func save() {
        do {
            let data =
                try JSONEncoder()
                    .encode(offers)

            defaults.set(
                data,
                forKey:
                    metadataKey
            )
        } catch {
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać archiwum ofert: \(error.localizedDescription)"
            )
        }
    }
}
