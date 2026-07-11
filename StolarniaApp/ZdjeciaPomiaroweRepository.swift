import Combine
import Foundation
import os
import UIKit

@MainActor
final class ZdjeciaPomiaroweRepository:
    ObservableObject
{
    @Published private(set) var photos:
        [ZdjeciePomiarowe] = []

    private let defaults:
        UserDefaults
    private let metadataKey =
        "stolarnia.pomiary.zdjecia.metadata.v1"

    private let fileManager:
        FileManager

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

    func photos(
        projectID: String,
        roomID: String
    ) -> [ZdjeciePomiarowe] {
        photos
            .filter {
                $0.projectID == projectID
                && $0.roomID == roomID
            }
            .sorted {
                $0.createdAt > $1.createdAt
            }
    }

    func add(
        imageData: Data,
        context:
            KontekstPomiaruPomieszczenia,
        category:
            KategoriaZdjeciaPomiarowego,
        caption: String
    ) throws {
        guard let image =
            UIImage(data: imageData)
        else {
            throw PhotoStoreError.invalidImage
        }

        let id = UUID()
        let fileName =
            "\(id.uuidString).jpg"
        let thumbnailFileName =
            "\(id.uuidString)-thumb.jpg"

        let fullURL =
            try photosDirectory()
                .appendingPathComponent(
                    fileName
                )

        let thumbnailURL =
            try photosDirectory()
                .appendingPathComponent(
                    thumbnailFileName
                )

        guard let compressed =
            image.jpegData(
                compressionQuality: 0.88
            )
        else {
            throw PhotoStoreError.encodingFailed
        }

        let thumbnail =
            image.preparingThumbnail(
                of:
                    CGSize(
                        width: 420,
                        height: 420
                    )
            )
            ?? image

        guard let thumbnailData =
            thumbnail.jpegData(
                compressionQuality: 0.78
            )
        else {
            throw PhotoStoreError.encodingFailed
        }

        try compressed.write(
            to: fullURL,
            options: .atomic
        )

        try thumbnailData.write(
            to: thumbnailURL,
            options: .atomic
        )

        let photo =
            ZdjeciePomiarowe(
                id: id,
                projectID:
                    context.projectID,
                roomID:
                    context.roomID,
                projectName:
                    context.projectName,
                roomName:
                    context.roomName,
                customerName:
                    context.customerName,
                fileName: fileName,
                thumbnailFileName:
                    thumbnailFileName,
                category: category,
                caption: caption
            )

        photos.insert(
            photo,
            at: 0
        )

        save()
    }

    func update(
        _ photo:
            ZdjeciePomiarowe
    ) {
        guard let index =
            photos.firstIndex(
                where: {
                    $0.id == photo.id
                }
            )
        else {
            return
        }

        var updated = photo
        updated.modifiedAt = Date()
        photos[index] = updated
        save()
    }

    func delete(
        id: UUID
    ) {
        guard let photo =
            photos.first(
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
                    for:
                        photo.fileName
                )
        )

        if let thumbnailFileName =
            photo.thumbnailFileName {
            try? fileManager.removeItem(
                at:
                    fileURL(
                        for:
                            thumbnailFileName
                    )
            )
        }

        photos.removeAll {
            $0.id == id
        }

        save()
    }

    func image(
        for photo:
            ZdjeciePomiarowe
    ) -> UIImage? {
        UIImage(
            contentsOfFile:
                fileURL(
                    for:
                        photo.fileName
                ).path
        )
    }

    func thumbnail(
        for photo:
            ZdjeciePomiarowe
    ) -> UIImage? {
        let fileName =
            photo.thumbnailFileName
            ?? photo.fileName

        return UIImage(
            contentsOfFile:
                fileURL(
                    for:
                        fileName
                ).path
        )
    }

    func reload() {
        load()
    }

    private func photosDirectory()
        throws -> URL
    {
        let base =
            try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

        let directory =
            base.appendingPathComponent(
                "MeasurementPhotos",
                isDirectory: true
            )

        if !fileManager.fileExists(
            atPath: directory.path
        ) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        return directory
    }

    private func fileURL(
        for fileName: String
    ) -> URL {
        let base =
            (
                try? photosDirectory()
            )
            ?? fileManager
                .temporaryDirectory

        return base.appendingPathComponent(
            fileName
        )
    }

    private func load() {
        guard let data =
            defaults.data(
                forKey:
                    metadataKey
            )
        else {
            photos = []
            return
        }

        do {
            photos =
                try JSONDecoder()
                    .decode(
                        [ZdjeciePomiarowe].self,
                        from: data
                    )
        } catch {
            photos = []
        }
    }

    private func save() {
        do {
            let data =
                try JSONEncoder()
                    .encode(photos)

            defaults.set(
                data,
                forKey:
                    metadataKey
            )
        } catch {
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać metadanych zdjęć: \(error.localizedDescription)"
            )
        }
    }
}

enum PhotoStoreError:
    LocalizedError
{
    case invalidImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Wybrany plik nie jest prawidłowym zdjęciem."
        case .encodingFailed:
            return "Nie udało się przygotować zdjęcia do zapisu."
        }
    }
}
